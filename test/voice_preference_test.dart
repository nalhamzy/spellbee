import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spellbee/core/services/storage_service.dart';
import 'package:spellbee/providers/providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'a verified upgrade enables custom studio speech without a hidden setting',
    () async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService(await SharedPreferences.getInstance());
      final container = ProviderContainer(
        overrides: [
          storageServiceProvider.overrideWithValue(storage),
          isPremiumProvider.overrideWithValue(false),
        ],
      );
      addTearDown(container.dispose);
      final observed = <VoiceQuality>[];
      container.listen(
        voiceQualityProvider,
        (_, next) => observed.add(next),
        fireImmediately: true,
      );
      expect(container.read(voiceQualityProvider), VoiceQuality.device);
      container.updateOverrides([
        storageServiceProvider.overrideWithValue(storage),
        isPremiumProvider.overrideWithValue(true),
      ]);
      await container.pump();
      expect(container.read(voiceQualityProvider), VoiceQuality.studio);
      expect(observed, [VoiceQuality.device, VoiceQuality.studio]);
      container.updateOverrides([
        storageServiceProvider.overrideWithValue(storage),
        isPremiumProvider.overrideWithValue(false),
      ]);
      await container.pump();
      expect(container.read(voiceQualityProvider), VoiceQuality.device);
    },
  );

  test(
    'an explicit Bee Buddy preference is preserved on purchase and reload',
    () async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService(await SharedPreferences.getInstance());
      await storage.setVoiceQualityIndex(VoiceQuality.device.index);
      final container = ProviderContainer(
        overrides: [
          storageServiceProvider.overrideWithValue(storage),
          isPremiumProvider.overrideWithValue(true),
        ],
      );
      addTearDown(container.dispose);
      expect(container.read(voiceQualityProvider), VoiceQuality.device);
      expect(
        storage.getVoiceQualityIndex(premium: true),
        VoiceQuality.device.index,
      );
      await container
          .read(voiceQualityProvider.notifier)
          .set(VoiceQuality.studio);
      expect(storage.getVoiceQualityIndex(), VoiceQuality.studio.index);
    },
  );
}
