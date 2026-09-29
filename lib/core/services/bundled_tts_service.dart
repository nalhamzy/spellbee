import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:spellbee/core/services/speech_audio_player.dart';

/// Included Bee Buddy recordings work offline for every learner.
class BundledTtsService {
  final SpeechAudioPlayer _player;
  final Future<List<String>> Function() _assets;
  final Future<String> Function() _manifest;
  Future<void>? _indexing;
  int _generation = 0;
  final _words = <String, String>{};
  final _phrases = <String, String>{};
  final _texts = <String, String>{};
  BundledTtsService({
    SpeechAudioPlayer? player,
    Future<List<String>> Function()? assetLoader,
    Future<String> Function()? manifestLoader,
  }) : _player = player ?? SpeechAudioPlayer(),
       _assets =
           assetLoader ??
           (() async => (await AssetManifest.loadFromAssetBundle(
             rootBundle,
           )).listAssets()),
       _manifest =
           manifestLoader ??
           (() => rootBundle.loadString(
             'assets/audio/phrases/voice_manifest.json',
           ));
  Future<void> _ensureIndexed() => _indexing ??= _index();
  Future<void> _index() async {
    try {
      // Flutter 3.32+ no longer bundles AssetManifest.json.
      for (final path in await _assets()) {
        if (!path.endsWith('.mp3')) continue;
        final stub = path.split('/').last.replaceFirst('.mp3', '');
        if (path.startsWith('assets/audio/words/')) {
          _words[stub] = path.substring(7);
        }
        if (path.startsWith('assets/audio/phrases/')) {
          _phrases[stub] = path.substring(7);
        }
      }
      try {
        final manifest = jsonDecode(await _manifest()) as Map<String, dynamic>;
        _texts.addAll((manifest['texts'] as Map).cast<String, String>());
        _phrases.addAll((manifest['phrases'] as Map).cast<String, String>());
      } catch (_) {
        // Legacy recordings remain usable if a new manifest is unavailable.
      }
    } catch (_) {
      _indexing = null;
    }
  }

  Future<bool> hasWord(String word) async {
    await _ensureIndexed();
    return _texts.containsKey(word.trim().toLowerCase()) ||
        _words.containsKey(word.trim().toLowerCase());
  }

  Future<bool> hasPhrase(String stub) async {
    await _ensureIndexed();
    return _phrases.containsKey(stub);
  }

  Future<bool> hasText(String text) async {
    await _ensureIndexed();
    return _texts.containsKey(text.trim());
  }

  Future<bool> playWord(String word, {double speed = 1}) async {
    final token = ++_generation;
    await _ensureIndexed();
    if (token != _generation) return true;
    final key = word.trim().toLowerCase();
    return _play(_texts[key] ?? _words[key], speed);
  }

  Future<bool> playPhrase(String stub, {double speed = 1}) async {
    final token = ++_generation;
    await _ensureIndexed();
    if (token != _generation) return true;
    return _play(_phrases[stub], speed);
  }

  Future<bool> playText(String text, {double speed = 1}) async {
    final token = ++_generation;
    await _ensureIndexed();
    if (token != _generation) return true;
    return _play(_texts[text.trim()], speed);
  }

  Future<bool> _play(String? path, double speed) async =>
      path == null ? false : _player.play(AssetSource(path), speed: speed);
  Future<void> stop() {
    ++_generation;
    return _player.stop();
  }

  void dispose() {
    ++_generation;
    _player.dispose();
  }
}
