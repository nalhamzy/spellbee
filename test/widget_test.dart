import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spellbee/core/data/themed_word_packs.dart';
import 'package:spellbee/core/services/stt_service.dart';
import 'package:spellbee/core/services/ai_word_generator.dart';
import 'package:spellbee/core/services/iap_service.dart';
import 'package:spellbee/core/services/storage_service.dart';

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

    expect(storage.getVoiceQualityIndex(), 0);

    await storage.setVoiceQualityIndex(1);

    expect(storage.getVoiceQualityIndex(), 1);
  });

  test('IAP service can dispose when the store was never initialized', () {
    expect(() => IapService().dispose(), returnsNormally);
  });
}
