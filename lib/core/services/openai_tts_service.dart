import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:spellbee/core/services/bundled_tts_service.dart'
    show waitForPlaybackEnd;

/// Premium voice through the SpellBee Firebase TTS gateway.
///
/// The OpenAI key lives in Firebase Secret Manager, never in the mobile app.
/// The default URL points at the studio Firebase project; use TTS_GATEWAY_URL
/// only when testing a different backend:
///   flutter run --dart-define=TTS_GATEWAY_URL=https://.../spellbeeTts
class OpenAiTtsService {
  static const _defaultGatewayUrl =
      'https://us-central1-rhyme-aa29b.cloudfunctions.net/spellbeeTts';
  static const _gatewayUrlOverride = String.fromEnvironment('TTS_GATEWAY_URL');
  static const _gatewayToken = String.fromEnvironment('TTS_GATEWAY_TOKEN');
  static String get _gatewayUrl =>
      _gatewayUrlOverride.isNotEmpty ? _gatewayUrlOverride : _defaultGatewayUrl;
  static bool get hasKey => _gatewayUrl.isNotEmpty;

  static const String _model = 'gpt-4o-mini-tts';
  static const String _defaultVoice = 'marin';
  static const String defaultVoice = _defaultVoice;

  final _player = AudioPlayer();
  Directory? _cacheDir;
  bool _swept = false;

  /// Set from a gateway 429's Retry-After: while active, speak() short-
  /// circuits straight to the fallback chain instead of paying a full POST
  /// per utterance against an already-throttled function (a test fires ~4
  /// of those per word).
  DateTime? _cooldownUntil;

  /// Monotonic token: only the latest speak() may start playback, so a slow
  /// gateway response can't talk over the fallback audio a second tap
  /// already started.
  int _playToken = 0;

  /// De-dupes concurrent fetches of the same utterance (triple-tapping the
  /// speaker used to fire three POSTs racing three writes to one file).
  final _inFlight = <String, Future<void>>{};

  Future<Directory> _dir() async {
    _cacheDir ??= await getTemporaryDirectory();
    if (!_swept) {
      _swept = true;
      _sweepOldCache(_cacheDir!); // fire-and-forget
    }
    return _cacheDir!;
  }

  /// Temp-dir cache files were written forever and never pruned; Android
  /// only clears them under storage pressure. Cap age instead.
  Future<void> _sweepOldCache(Directory dir) async {
    try {
      final cutoff = DateTime.now().subtract(const Duration(days: 30));
      await for (final f in dir.list()) {
        if (f is! File || !f.path.contains('sb_tts_')) continue;
        final stat = await f.stat();
        if (stat.modified.isBefore(cutoff)) {
          await f.delete();
        }
      }
    } catch (_) {
      // Cache hygiene must never break speech.
    }
  }

  String _keyFor(String text, String voice) {
    final safe = text.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final short = safe.substring(0, safe.length.clamp(0, 40));
    return 'sb_tts_${voice}_${short}_${text.hashCode}.mp3';
  }

  /// Pronounce [text]. Returns true if the gateway + playback succeeded;
  /// false means the caller should fall back to native TTS.
  Future<bool> speak(String text, {String? voice, double speed = 1.0}) async {
    if (!hasKey) return false;
    final cooldown = _cooldownUntil;
    if (cooldown != null && DateTime.now().isBefore(cooldown)) return false;
    final token = ++_playToken;
    try {
      final v = voice ?? _defaultVoice;
      final dir = await _dir();
      final speedTag = (speed * 100).round();
      final file = File('${dir.path}/${_keyFor('${text}_$speedTag', v)}');
      if (!file.existsSync()) {
        final ok = await (_inFlight[file.path] ??= _fetch(
          file: file,
          text: text,
          voice: v,
          speed: speed,
        ).whenComplete(() => _inFlight.remove(file.path))).then(
          (_) => file.existsSync(),
        );
        if (!ok) return false;
      }
      if (token != _playToken) {
        // A newer utterance superseded this one while we fetched; the bytes
        // are cached for next time, but playing now would double-talk.
        return true;
      }
      await _player.stop();
      await _player.play(DeviceFileSource(file.path));
      // Sentences (definitions, math questions) run longer than single
      // words; the timeout only matters if the player never reports an end.
      await waitForPlaybackEnd(_player, const Duration(seconds: 20));
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _fetch({
    required File file,
    required String text,
    required String voice,
    required double speed,
  }) async {
    final resp = await http
        .post(
          Uri.parse(_gatewayUrl),
          headers: {
            'Content-Type': 'application/json',
            if (_gatewayToken.isNotEmpty)
              'Authorization': 'Bearer $_gatewayToken',
          },
          body: jsonEncode({
            'model': _model,
            'voice': voice,
            'input': text,
            'response_format': 'mp3',
            'speed': speed,
            'purpose': 'spellbee-pronunciation',
          }),
        )
        .timeout(const Duration(seconds: 20));
    if (resp.statusCode == 429) {
      // The gateway meters spend; honor its Retry-After (default 10 min)
      // so a quota-exhausted day degrades to bundled/device voice silently
      // instead of hammering the function on every word.
      final retryAfter = int.tryParse(resp.headers['retry-after'] ?? '');
      _cooldownUntil = DateTime.now().add(
        Duration(seconds: retryAfter ?? 600),
      );
      return;
    }
    if (resp.statusCode != 200) return;
    await file.writeAsBytes(resp.bodyBytes, flush: true);
  }

  Future<void> stop() async {
    try {
      await _player.stop();
    } catch (_) {}
  }

  void dispose() {
    _player.dispose();
  }
}
