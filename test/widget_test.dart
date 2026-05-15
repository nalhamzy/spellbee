import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spellbee/core/services/ai_word_generator.dart';
import 'package:spellbee/core/services/storage_service.dart';

void main() {
  test(
    'AI word generator falls back to local catalog without gateway',
    () async {
      final words = await AiWordGenerator().generate(
        count: 5,
        level: 3,
        theme: 'space',
      );

      expect(words, hasLength(5));
      expect(words.every((w) => w.text.isNotEmpty), isTrue);
    },
  );

  test('voice quality setting persists', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = StorageService(prefs);

    expect(storage.getVoiceQualityIndex(), 0);

    await storage.setVoiceQualityIndex(1);

    expect(storage.getVoiceQualityIndex(), 1);
  });
}
