import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

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
