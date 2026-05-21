import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spellbee/core/data/themed_word_packs.dart';
import 'package:spellbee/core/data/voice_phrase_bank.dart';
import 'package:spellbee/core/models/player_stats.dart';
import 'package:spellbee/core/services/stt_service.dart';
import 'package:spellbee/core/services/ai_word_generator.dart';
import 'package:spellbee/core/services/iap_service.dart';
import 'package:spellbee/core/services/storage_service.dart';
import 'package:spellbee/core/services/tts_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('AI word generator returns related local space words', () async {
    final pack = findThemedWordPack('space')!;
    final words = await AiWordGenerator().generate(
      count: 10,
      level: 3,
      theme: 'space',
    );

    expect(words, hasLength(10));
    expect(words.map((w) => w.text).toSet(), hasLength(10));
    expect(words.every(pack.matchesWord), isTrue);
  });

  test('AI word generator supports suggested themes offline', () async {
    for (final theme in ['animals', 'sports', 'dinosaurs']) {
      final pack = findThemedWordPack(theme)!;
      final words = await AiWordGenerator().generate(
        count: 6,
        level: 4,
        theme: theme,
      );

      expect(words, hasLength(6), reason: theme);
      expect(words.every(pack.matchesWord), isTrue, reason: theme);
    }
  });

  test('AI word generator still falls back for unknown themes', () async {
    final words = await AiWordGenerator().generate(
      count: 5,
      level: 3,
      theme: 'made up parent theme',
    );

    expect(words, hasLength(5));
    expect(words.every((w) => w.text.isNotEmpty), isTrue);
  });

  test('speech spelling normalizes common letter names', () {
    expect(SttService.normalize('C A T'), 'cat');
    expect(SttService.normalize('see ay tee'), 'cat');
    expect(SttService.normalize('double you ay vee ee'), 'wave');
    expect(SttService.normalize('queue you eye zee'), 'quiz');
  });

  test('voice quality setting persists', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = StorageService(prefs);

    expect(storage.getVoiceSpeedIndex(), VoiceSpeed.calm.index);
    expect(storage.getVoiceQualityIndex(), 0);

    await storage.setVoiceQualityIndex(1);

    expect(storage.getVoiceQualityIndex(), 1);
  });

  test('player stats persist missed word coach data', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = StorageService(prefs);

    await storage.saveStats(
      const PlayerStats(
        totalTests: 1,
        totalWordsAsked: 3,
        totalWordsCorrect: 2,
        missedWordCounts: {'bridge': 2, 'giraffe': 1},
      ),
    );

    final stats = storage.loadStats();

    expect(stats.missedWordCounts['bridge'], 2);
    expect(stats.missedWordCounts['giraffe'], 1);
  });

  test('player stats persist custom list score summaries', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = StorageService(prefs);

    const score = ListScoreSummary(
      attempts: 2,
      lastCorrect: 4,
      lastTotal: 5,
      bestCorrect: 5,
      bestTotal: 5,
      lastPlayedEpochMs: 12345,
    );

    await storage.saveStats(
      const PlayerStats(listScores: {'school-list': score}),
    );

    final stats = storage.loadStats();

    expect(stats.listScores['school-list'], score);
    expect(stats.listScores['school-list']?.bestAccuracy, 1);
  });

  test('list score summary keeps the strongest result', () {
    final first = const ListScoreSummary().record(
      correct: 4,
      total: 5,
      playedAtEpochMs: 100,
    );
    final second = first.record(correct: 3, total: 5, playedAtEpochMs: 200);

    expect(second.attempts, 2);
    expect(second.lastCorrect, 3);
    expect(second.lastTotal, 5);
    expect(second.bestCorrect, 4);
    expect(second.bestTotal, 5);
    expect(second.lastPlayedEpochMs, 200);
  });

  test('device voice picker prefers natural English voices', () {
    final best = TtsService.chooseBestDeviceVoice([
      {'name': 'com.samsung.SMT.lang_en_us_l03', 'locale': 'en-US'},
      {'name': 'en-gb-x-gbb-local', 'locale': 'en-GB'},
      {
        'name': 'en-us-x-iom-network',
        'locale': 'en-US',
        'quality': 'network neural',
      },
    ]);

    expect(best?['name'], 'en-us-x-iom-network');
    expect(
      TtsService.deviceVoiceScore({
        'name': 'en-us-x-iom-network',
        'locale': 'en-US',
        'quality': 'network neural',
      }),
      greaterThan(
        TtsService.deviceVoiceScore({
          'name': 'com.samsung.SMT.lang_en_us_l03',
          'locale': 'en-US',
        }),
      ),
    );
  });

  test('device voice label explains bundled natural clips', () {
    expect(VoiceQuality.device.description, contains('Natural bundled clips'));
  });

  test('spoken word prompt is only the target word', () {
    final prompts = [
      for (var i = 0; i < TtsService.wordPromptVariantCount; i++)
        TtsService.buildWordPrompt('rocket', variant: i),
    ];

    expect(prompts, ['rocket']);
  });

  test('definition, example, and spell-out prompts remain clear', () {
    final definition = TtsService.buildDefinitionPrompt(
      'bridge',
      'A structure that crosses water.',
      variant: 2,
    );
    final example = TtsService.buildExamplePrompt(
      'bridge',
      'We crossed the bridge slowly.',
      variant: 1,
    );
    final spellOut = TtsService.buildSpellOutPrompt(
      'bridge',
      'B, R, I, D, G, E',
      variant: 0,
    );

    expect(definition, contains('bridge'));
    expect(definition, contains('crosses water'));
    expect(example, contains('bridge'));
    expect(example, contains('crossed the bridge'));
    expect(spellOut, contains('bridge'));
    expect(spellOut, contains('B, R, I, D, G, E'));
  });

  test('IAP service can dispose when the store was never initialized', () {
    expect(() => IapService().dispose(), returnsNormally);
  });

  test('feedback picker can avoid immediate repeats', () {
    const stubs = ['great', 'excellent', 'wonderful'];
    for (var i = 0; i < 20; i++) {
      expect(VoicePhraseBank.pick(stubs, avoid: 'great'), isNot('great'));
    }
  });
}
