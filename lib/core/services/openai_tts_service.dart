import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Premium voice via the studio TTS gateway.
///
/// The mobile app must never ship an OpenAI/AWS provider key. Instead, pass a
/// studio gateway URL and optional short-lived client token at build time:
///   flutter run --dart-define=TTS_GATEWAY_URL=https://.../spellbeeTts
///   flutter run --dart-define=TTS_GATEWAY_TOKEN=...
///
/// The gateway should call OpenAI's Speech endpoint server-side, enforce
/// entitlement/quota/rate limits, and return MP3 bytes. Every method degrades
/// gracefully; if the gateway fails, callers fall back to on-device TTS.
class OpenAiTtsService {
  static const _gatewayUrl = String.fromEnvironment('TTS_GATEWAY_URL');
  static const _gatewayToken = String.fromEnvironment('TTS_GATEWAY_TOKEN');
  static bool get hasKey => _gatewayUrl.isNotEmpty;

  static const String _model = 'gpt-4o-mini-tts';
  static const String _defaultVoice = 'marin';

  final _player = AudioPlayer();
  Directory? _cacheDir;

  Future<Directory> _dir() async {
    _cacheDir ??= await getTemporaryDirectory();
    return _cacheDir!;
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
    try {
      final v = voice ?? _defaultVoice;
      final dir = await _dir();
      final speedTag = (speed * 100).round();
      final file = File('${dir.path}/${_keyFor('${text}_$speedTag', v)}');
      if (!file.existsSync()) {
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
                'voice': v,
                'input': text,
                'response_format': 'mp3',
                'speed': speed,
                'purpose': 'spellbee-pronunciation',
              }),
            )
            .timeout(const Duration(seconds: 20));
        if (resp.statusCode != 200) return false;
        await file.writeAsBytes(resp.bodyBytes, flush: true);
      }
      await _player.stop();
      await _player.play(DeviceFileSource(file.path));
      return true;
    } catch (_) {
      return false;
    }
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
