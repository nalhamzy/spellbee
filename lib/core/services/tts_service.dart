import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:spellbee/core/services/bundled_tts_service.dart';
import 'package:spellbee/core/services/openai_tts_service.dart';

/// Voice speed — three preset tiers. 'calm' is tuned for early readers who
/// need every syllable space.
enum VoiceSpeed { calm, normal, fast }

enum VoiceQuality { device, studio }

extension VoiceQualityLabel on VoiceQuality {
  String get label {
    switch (this) {
      case VoiceQuality.device:
        return 'Device';
      case VoiceQuality.studio:
        return 'Studio';
    }
  }

  String get description {
    switch (this) {
      case VoiceQuality.device:
        return 'Natural bundled clips with enhanced device fallback.';
      case VoiceQuality.studio:
        return 'Premium studio voice, with bundled and device fallback.';
    }
  }
}

class StudioVoiceOption {
  final String id;
  final String label;
  final String description;

  const StudioVoiceOption({
    required this.id,
    required this.label,
    required this.description,
  });
}

const kOpenAiStudioVoices = <StudioVoiceOption>[
  StudioVoiceOption(
    id: 'marin',
    label: 'Marin',
    description: 'Warm, clear teacher voice.',
  ),
  StudioVoiceOption(
    id: 'alloy',
    label: 'Alloy',
    description: 'Neutral and crisp.',
  ),
  StudioVoiceOption(
    id: 'nova',
    label: 'Nova',
    description: 'Bright and friendly.',
  ),
  StudioVoiceOption(
    id: 'sage',
    label: 'Sage',
    description: 'Gentle and patient.',
  ),
  StudioVoiceOption(
    id: 'verse',
    label: 'Verse',
    description: 'Expressive storyteller.',
  ),
];

extension VoiceSpeedRate on VoiceSpeed {
  /// flutter_tts engine rate (0.0-1.0 on all platforms).
  double get ttsRate {
    switch (this) {
      case VoiceSpeed.calm:
        return 0.42;
      case VoiceSpeed.normal:
        return 0.52;
      case VoiceSpeed.fast:
        return 0.62;
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

/// Thin TTS wrapper that routes between the studio voice gateway,
/// bundled MP3s, and on-device TTS. Callers pass [premium] on
/// every call so an expiring subscription silently falls back without the
/// service having to watch Riverpod.
class TtsService {
  static const _preferredAndroidEngine = 'com.google.android.tts';

  final _tts = FlutterTts();
  final _openai = OpenAiTtsService();
  final _bundled = BundledTtsService();
  final _promptRandom = math.Random();
  bool _ready = false;
  bool _deviceVoiceConfigured = false;
  VoiceSpeed _speed = VoiceSpeed.calm;
  VoiceQuality _quality = VoiceQuality.device;
  String _openAiVoice = OpenAiTtsService.defaultVoice;

  bool get hasPremiumVoice => true;
  bool get hasRemoteStudioVoice => OpenAiTtsService.hasKey;

  void setOpenAiVoice(String voice) {
    _openAiVoice = voice;
  }

  void setQuality(VoiceQuality quality) {
    _quality = quality;
  }

  Future<void> setSpeed(VoiceSpeed s) async {
    _speed = s;
    if (_ready) await _applyDeviceVoiceTuning();
  }

  Future<void> _ensureReady() async {
    if (_ready) return;
    await _tts.awaitSpeakCompletion(true);
    await _preferHumanAndroidEngine();
    await _tts.setLanguage('en-US');
    await _configureHumanDeviceVoice();
    await _applyDeviceVoiceTuning();
    _ready = true;
  }

  Future<void> _preferHumanAndroidEngine() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final engines = await _tts.getEngines;
      if (engines is Iterable &&
          engines.any(
            (engine) => engine.toString() == _preferredAndroidEngine,
          )) {
        await _tts.setEngine(_preferredAndroidEngine);
      }
      await _tts.setQueueMode(0);
    } catch (_) {
      // Best-effort only: pronunciation should continue with the OEM engine.
    }
  }

  Future<void> _configureHumanDeviceVoice() async {
    if (_deviceVoiceConfigured) return;
    _deviceVoiceConfigured = true;
    try {
      final bestVoice = chooseBestDeviceVoice(await _tts.getVoices);
      if (bestVoice != null) await _tts.setVoice(bestVoice);
    } catch (_) {
      // Some engines throw while listing voices; keep the current voice.
    }
  }

  Future<void> _applyDeviceVoiceTuning() async {
    await _tts.setSpeechRate(_speed.ttsRate);
    await _tts.setPitch(0.98);
    await _tts.setVolume(1.0);
  }

  static Map<String, String>? chooseBestDeviceVoice(dynamic voices) {
    if (voices is! Iterable) return null;

    Map<String, String>? best;
    var bestScore = -10000;
    for (final voice in voices) {
      final map = _stringVoiceMap(voice);
      if (map == null || !map.containsKey('name')) continue;
      final score = deviceVoiceScore(map);
      if (score > bestScore) {
        bestScore = score;
        best = map;
      }
    }

    final name = best?['name'];
    final locale = best?['locale'];
    if (name == null || locale == null) return null;
    return {'name': name, 'locale': locale};
  }

  static int deviceVoiceScore(Map<String, String> voice) {
    final name = (voice['name'] ?? '').toLowerCase();
    final locale = (voice['locale'] ?? '').replaceAll('_', '-').toLowerCase();
    final all = voice.values.join(' ').toLowerCase();

    var score = 0;
    if (locale == 'en-us') {
      score += 120;
    } else if (locale.startsWith('en-us')) {
      score += 105;
    } else if (locale == 'en-gb' || locale == 'en-au' || locale == 'en-ca') {
      score += 85;
    } else if (locale.startsWith('en')) {
      score += 65;
    } else {
      score -= 250;
    }

    if (name.contains('google') || all.contains('google')) score += 55;
    if (name.contains('network') || all.contains('network')) score += 45;
    if (all.contains('neural') ||
        all.contains('wavenet') ||
        all.contains('enhanced') ||
        all.contains('natural') ||
        all.contains('premium')) {
      score += 70;
    }
    if (name.contains('female') || name.contains('f00')) score += 18;
    if (name.contains('male') || name.contains('m00')) score += 10;

    if (name.contains('samsung') || name.contains('smt')) score -= 35;
    if (name.contains('pico') || name.contains('espeak')) score -= 120;
    if (all.contains('notinstalled') || all.contains('not installed')) {
      score -= 500;
    }

    return score;
  }

  static Map<String, String>? _stringVoiceMap(dynamic voice) {
    if (voice is! Map) return null;
    final mapped = <String, String>{};
    for (final entry in voice.entries) {
      final key = entry.key?.toString();
      final value = entry.value?.toString();
      if (key == null || value == null || value.isEmpty) continue;
      mapped[key] = value;
    }
    return mapped;
  }

  Future<bool> _tryStudio(String sentence) async {
    if (!OpenAiTtsService.hasKey) return false;
    return _openai.speak(
      sentence,
      voice: _openAiVoice,
      speed: _speed.openAiRate,
    );
  }

  /// Say [sentence]. Studio priority: cloud voice, then device TTS.
  Future<void> _sayWithFallback(
    String sentence, {
    required bool premium,
  }) async {
    final useStudio = premium && _quality == VoiceQuality.studio;
    if (useStudio) {
      final ok = await _tryStudio(sentence);
      if (ok) return;
    }
    await _ensureReady();
    await _applyDeviceVoiceTuning();
    await _tts.speak(sentence);
  }

  static const _wordPromptTemplates = ['{word}'];

  static const _definitionPromptTemplates = [
    '{word}. The meaning is: {definition}',
    'Here is what {word} means: {definition}',
    'A clue for {word}: {definition}',
    'Definition for {word}: {definition}',
    'Think about this meaning for {word}: {definition}',
  ];

  static const _examplePromptTemplates = [
    'Here is {word} in a sentence. {example}',
    'Listen for {word} in this sentence. {example}',
    'A sentence with {word}. {example}',
    'Here is one example for {word}. {example}',
    'In context, {word} sounds like this. {example}',
  ];

  static const _spellOutPromptTemplates = [
    '{word}. Spell it with me: {letters}.',
    'Here are the letters for {word}: {letters}.',
    'Listen letter by letter. {word}: {letters}.',
    '{word}. The letters are: {letters}.',
  ];

  @visibleForTesting
  static int get wordPromptVariantCount => _wordPromptTemplates.length;

  @visibleForTesting
  static int get definitionPromptVariantCount =>
      _definitionPromptTemplates.length;

  @visibleForTesting
  static int get examplePromptVariantCount => _examplePromptTemplates.length;

  @visibleForTesting
  static int get spellOutPromptVariantCount => _spellOutPromptTemplates.length;

  @visibleForTesting
  static String buildWordPrompt(String word, {int variant = 0}) =>
      _formatPrompt(_wordPromptTemplates, variant, word: word);

  @visibleForTesting
  static String buildDefinitionPrompt(
    String word,
    String definition, {
    int variant = 0,
  }) => _formatPrompt(
    _definitionPromptTemplates,
    variant,
    word: word,
    definition: definition,
  );

  @visibleForTesting
  static String buildExamplePrompt(
    String word,
    String example, {
    int variant = 0,
  }) => _formatPrompt(
    _examplePromptTemplates,
    variant,
    word: word,
    example: example,
  );

  @visibleForTesting
  static String buildSpellOutPrompt(
    String word,
    String letters, {
    int variant = 0,
  }) => _formatPrompt(
    _spellOutPromptTemplates,
    variant,
    word: word,
    letters: letters,
  );

  static String _formatPrompt(
    List<String> templates,
    int variant, {
    required String word,
    String? definition,
    String? example,
    String? letters,
  }) {
    final safeWord = word.trim();
    final template = templates[variant.abs() % templates.length];
    return template
        .replaceAll('{word}', safeWord)
        .replaceAll('{definition}', definition?.trim() ?? '')
        .replaceAll('{example}', example?.trim() ?? '')
        .replaceAll('{letters}', letters?.trim() ?? '');
  }

  int _nextVariant(int length) => _promptRandom.nextInt(length);

  String _wordPrompt(String word) =>
      buildWordPrompt(word, variant: _nextVariant(_wordPromptTemplates.length));

  String _definitionPrompt(String word, String definition) =>
      buildDefinitionPrompt(
        word,
        definition,
        variant: _nextVariant(_definitionPromptTemplates.length),
      );

  String _examplePrompt(String word, String example) => buildExamplePrompt(
    word,
    example,
    variant: _nextVariant(_examplePromptTemplates.length),
  );

  String _spellOutPrompt(String word, String letters) => buildSpellOutPrompt(
    word,
    letters,
    variant: _nextVariant(_spellOutPromptTemplates.length),
  );

  /// Pronounce a word. Studio builds try the selected cloud voice first so
  /// testers can hear voice differences on every word. Bundled assets and
  /// device TTS stay as graceful fallback.
  Future<void> speakWord(String word, {bool premium = false}) async {
    final useRemoteStudio =
        premium && _quality == VoiceQuality.studio && OpenAiTtsService.hasKey;
    final prompt = _wordPrompt(word);
    if (useRemoteStudio && await _tryStudio(prompt)) return;

    if (await _bundled.hasWord(word)) {
      final played = await _bundled.playWord(word);
      if (played) return;
    }
    await _sayWithFallback(prompt, premium: premium);
  }

  Future<void> speakDefinition(
    String word,
    String definition, {
    bool premium = false,
  }) => _sayWithFallback(_definitionPrompt(word, definition), premium: premium);

  Future<void> speakExample(
    String word,
    String example, {
    bool premium = false,
  }) => _sayWithFallback(_examplePrompt(word, example), premium: premium);

  Future<void> spellOut(String word, {bool premium = false}) async {
    final spaced = word.toUpperCase().split('').join(', ');
    await _sayWithFallback(_spellOutPrompt(word, spaced), premium: premium);
  }

  /// Play one of the pre-generated encouragement / connector phrases by its
  /// asset stub (e.g. 'great', 'new_best'). Falls back to flutter_tts using
  /// the stub with underscores turned into spaces.
  Future<void> playPhrase(String stub, {bool premium = false}) async {
    if (await _bundled.hasPhrase(stub)) {
      final played = await _bundled.playPhrase(stub);
      if (played) return;
    }
    await _ensureReady();
    await _tts.speak(stub.replaceAll('_', ' '));
  }

  Future<void> stop() async {
    await _openai.stop();
    await _bundled.stop();
    if (!_ready) return;
    await _tts.stop();
  }

  void dispose() {
    _tts.stop();
    _openai.dispose();
    _bundled.dispose();
  }
}
