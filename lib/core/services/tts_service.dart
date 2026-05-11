import 'package:flutter_tts/flutter_tts.dart';
import 'package:spellbee/core/services/aws_polly_tts_service.dart';
import 'package:spellbee/core/services/bundled_tts_service.dart';
import 'package:spellbee/core/services/openai_tts_service.dart';

/// Voice speed — three preset tiers. 'calm' is tuned for early readers who
/// need every syllable space.
enum VoiceSpeed { calm, normal, fast }

extension VoiceSpeedRate on VoiceSpeed {
  /// flutter_tts engine rate (0.0-1.0 on all platforms).
  double get ttsRate {
    switch (this) {
      case VoiceSpeed.calm:
        return 0.38;
      case VoiceSpeed.normal:
        return 0.48;
      case VoiceSpeed.fast:
        return 0.60;
    }
  }

  /// OpenAI speech "speed" param (0.25-4.0). Going below 1.0 produces
  /// stretched / slurry audio — keep everything at natural pace or above.
  double get openAiRate {
    switch (this) {
      case VoiceSpeed.calm:
        return 1.00;
      case VoiceSpeed.normal:
        return 1.10;
      case VoiceSpeed.fast:
        return 1.25;
    }
  }

  String get label {
    switch (this) {
      case VoiceSpeed.calm:
        return 'Calm';
      case VoiceSpeed.normal:
        return 'Normal';
      case VoiceSpeed.fast:
        return 'Fast';
    }
  }
}

/// Thin TTS wrapper that routes between:
///   - [OpenAiTtsService] when the user is premium AND an
///     OPENAI_API_KEY dart-define is present at build time
///   - [FlutterTts] (on-device) otherwise
///
/// Callers pass [premium] on every call so an expiring subscription silently
/// falls back without the service having to watch Riverpod.
class TtsService {
  final _tts = FlutterTts();
  final _openai = OpenAiTtsService();
  final _polly = AwsPollyTtsService();
  final _bundled = BundledTtsService();
  bool _ready = false;
  VoiceSpeed _speed = VoiceSpeed.calm;
  String _pollyVoice = AwsPollyTtsService.defaultVoice;

  bool get hasPremiumVoice =>
      AwsPollyTtsService.hasKey || OpenAiTtsService.hasKey;

  void setPollyVoice(String voice) {
    _pollyVoice = voice;
  }

  Future<void> setSpeed(VoiceSpeed s) async {
    _speed = s;
    if (_ready) await _tts.setSpeechRate(s.ttsRate);
  }

  Future<void> _ensureReady() async {
    if (_ready) return;
    await _tts.awaitSpeakCompletion(true);
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(_speed.ttsRate);
    await _tts.setPitch(1.05);
    await _tts.setVolume(1.0);
    _ready = true;
  }

  /// Say [sentence]. Premium priority: bundled asset → AWS Polly → OpenAI → device TTS.
  Future<void> _sayWithFallback(String sentence,
      {required bool premium}) async {
    if (premium && AwsPollyTtsService.hasKey) {
      final ok = await _polly.speak(sentence, voice: _pollyVoice);
      if (ok) return;
    }
    if (premium && OpenAiTtsService.hasKey) {
      final ok = await _openai.speak(sentence, speed: _speed.openAiRate);
      if (ok) return;
    }
    await _ensureReady();
    await _tts.setSpeechRate(_speed.ttsRate);
    await _tts.speak(sentence);
  }

  String _beeSentence(String word) => 'The word is, $word.';

  /// Pronounce a word. Premium + bundled asset → instant, offline. Otherwise
  /// falls through the premium/device chain.
  Future<void> speakWord(String word, {bool premium = false}) async {
    if (premium && await _bundled.hasWord(word)) {
      final played = await _bundled.playWord(word);
      if (played) return;
    }
    await _sayWithFallback(_beeSentence(word), premium: premium);
  }

  Future<void> speakDefinition(String word, String definition,
          {bool premium = false}) =>
      _sayWithFallback(
        '$word. Definition: $definition',
        premium: premium,
      );

  Future<void> speakExample(String word, String example,
          {bool premium = false}) =>
      _sayWithFallback(
        '$word. In a sentence: $example',
        premium: premium,
      );

  Future<void> spellOut(String word, {bool premium = false}) async {
    final spaced = word.toUpperCase().split('').join(', ');
    await _sayWithFallback('$word is spelled: $spaced.', premium: premium);
  }

  /// Play one of the pre-generated encouragement / connector phrases by its
  /// asset stub (e.g. 'great', 'new_best'). Falls back to flutter_tts using
  /// the stub with underscores turned into spaces.
  Future<void> playPhrase(String stub, {bool premium = false}) async {
    if (premium && await _bundled.hasPhrase(stub)) {
      final played = await _bundled.playPhrase(stub);
      if (played) return;
    }
    await _ensureReady();
    await _tts.speak(stub.replaceAll('_', ' '));
  }

  Future<void> stop() async {
    await _polly.stop();
    await _openai.stop();
    await _bundled.stop();
    if (!_ready) return;
    await _tts.stop();
  }

  void dispose() {
    _tts.stop();
    _polly.dispose();
    _openai.dispose();
    _bundled.dispose();
  }
}
