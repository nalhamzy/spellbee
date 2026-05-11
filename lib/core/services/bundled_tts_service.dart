import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

/// Plays bundled pre-generated MP3s for the premium voice. These assets were
/// produced once by `tools/pregenerate_tts.py` and live under
/// `assets/audio/` — a ~3 MB payload that covers the top 60 spoken items.
///
/// The service is silent on misses: callers check [hasWord]/[hasPhrase]
/// before calling [playWord]/[playPhrase] and fall back to live OpenAI or
/// device TTS otherwise.
class BundledTtsService {
  final _player = AudioPlayer();
  Set<String>? _wordIndex;
  Set<String>? _phraseIndex;

  /// Lazily scan the asset manifest once. Flutter's AssetManifest.json lists
  /// every bundled asset path, so we can answer hasWord() without a file-system
  /// existence check (which would always crash on a readonly bundle).
  Future<void> _ensureIndexed() async {
    if (_wordIndex != null && _phraseIndex != null) return;
    try {
      final manifest =
          await rootBundle.loadString('AssetManifest.json');
      _wordIndex = <String>{};
      _phraseIndex = <String>{};
      // Quick-and-dirty parse — we only need the keys.
      final matches = RegExp(r'"([^"]+)"\s*:').allMatches(manifest);
      for (final m in matches) {
        final path = m.group(1)!;
        if (path.startsWith('assets/audio/words/') &&
            path.endsWith('.mp3')) {
          _wordIndex!.add(_stubFrom(path));
        } else if (path.startsWith('assets/audio/phrases/') &&
            path.endsWith('.mp3')) {
          _phraseIndex!.add(_stubFrom(path));
        }
      }
    } catch (_) {
      _wordIndex = <String>{};
      _phraseIndex = <String>{};
    }
  }

  String _stubFrom(String path) {
    final f = path.split('/').last;
    return f.substring(0, f.length - 4); // strip .mp3
  }

  Future<bool> hasWord(String word) async {
    await _ensureIndexed();
    return _wordIndex!.contains(word.toLowerCase());
  }

  Future<bool> hasPhrase(String stub) async {
    await _ensureIndexed();
    return _phraseIndex!.contains(stub);
  }

  Future<bool> playWord(String word) =>
      _play('assets/audio/words/${word.toLowerCase()}.mp3');

  Future<bool> playPhrase(String stub) =>
      _play('assets/audio/phrases/$stub.mp3');

  Future<bool> _play(String assetPath) async {
    try {
      await _player.stop();
      // audioplayers treats AssetSource paths as relative to `assets/` so we
      // strip that prefix before handing it over.
      final rel = assetPath.startsWith('assets/')
          ? assetPath.substring('assets/'.length)
          : assetPath;
      await _player.play(AssetSource(rel));
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
