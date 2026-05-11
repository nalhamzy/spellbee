import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Premium voice via OpenAI's /audio/speech endpoint.
///
/// Pass the API key at build time via:
///   flutter run --dart-define=OPENAI_API_KEY=sk-...
///
/// The service fetches MP3 bytes, caches them under the app's temporary
/// directory keyed by (text, voice), and plays via `audioplayers`. Every
/// method degrades gracefully — if the network call fails, callers should
/// fall back to on-device flutter_tts.
class OpenAiTtsService {
  static const _apiKey = String.fromEnvironment('OPENAI_API_KEY');
  static bool get hasKey => _apiKey.isNotEmpty;

  static const String _model = 'gpt-4o-mini-tts';   // newest cheap TTS tier
  static const String _defaultVoice = 'nova';       // young, clear, kid-friendly

  final _player = AudioPlayer();
  Directory? _cacheDir;

  Future<Directory> _dir() async {
    _cacheDir ??= await getTemporaryDirectory();
    return _cacheDir!;
  }

  String _keyFor(String text, String voice) {
    final safe = text.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    return 'sb_tts_${voice}_${safe.substring(0, safe.length.clamp(0, 40))}_${text.hashCode}.mp3';
  }

  /// Pronounce [text]. Returns true if the remote call + playback succeeded;
  /// false means the caller should fall back to native TTS.
  Future<bool> speak(String text, {String? voice, double speed = 1.0}) async {
    if (!hasKey) return false;
    try {
      final v = voice ?? _defaultVoice;
      final dir = await _dir();
      final speedTag = (speed * 100).round();
      final file = File(
          '${dir.path}/${_keyFor('${text}_$speedTag', v)}');
      if (!file.existsSync()) {
        final resp = await http
            .post(
              Uri.parse('https://api.openai.com/v1/audio/speech'),
              headers: {
                'Authorization': 'Bearer $_apiKey',
                'Content-Type': 'application/json',
              },
              body: jsonEncode({
                'model': _model,
                'voice': v,
                'input': text,
                'response_format': 'mp3',
                'speed': speed,
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
