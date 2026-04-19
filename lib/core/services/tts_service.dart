import 'package:flutter_tts/flutter_tts.dart';

/// Wraps flutter_tts with opinionated defaults for spelling-bee pronunciation:
/// slower rate, en-US voice, and a helpful "define / use in a sentence" helper
/// that mimics a real bee pronouncer.
class TtsService {
  final _tts = FlutterTts();
  bool _ready = false;

  Future<void> _ensureReady() async {
    if (_ready) return;
    await _tts.awaitSpeakCompletion(true);
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.42); // deliberate, clear
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);
    _ready = true;
  }

  /// Pronounce the word once, clearly.
  Future<void> speakWord(String word) async {
    await _ensureReady();
    await _tts.speak(word);
  }

  /// Say the word, then wait briefly, then read the definition.
  Future<void> speakDefinition(String word, String definition) async {
    await _ensureReady();
    await _tts.speak('$word. $definition');
  }

  /// Say the word, then read it in a sentence.
  Future<void> speakExample(String word, String example) async {
    await _ensureReady();
    await _tts.speak('$word. $example');
  }

  /// Spell the word one letter at a time. Used after a miss so the student
  /// hears the correct spelling.
  Future<void> spellOut(String word) async {
    await _ensureReady();
    final spaced = word.toUpperCase().split('').join(' ');
    await _tts.speak('$word is spelled $spaced');
  }

  Future<void> stop() async {
    if (!_ready) return;
    await _tts.stop();
  }

  void dispose() {
    _tts.stop();
  }
}
