import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spellbee/core/constants/theme.dart';
import 'package:spellbee/core/services/ai_word_generator.dart';
import 'package:spellbee/core/services/storage_service.dart';
import 'package:spellbee/core/services/tts_service.dart';
import 'package:spellbee/providers/providers.dart';
import 'package:spellbee/screens/practice_screen.dart';
import 'package:spellbee/screens/test_screen.dart';

class _SilentTts extends TtsService {
  @override
  Future<void> speakWord(
    String word, {
    bool premium = false,
    bool skipBundled = false,
  }) async {}
  @override
  Future<void> speakText(String text, {bool premium = false}) async {}
  @override
  Future<void> stop() async {}
}

void main() {
  testWidgets('zero online credits never block a local themed pack', (
    tester,
  ) async {
    expect(AiWordGenerator.canCallRemote, isFalse);
    tester.view.physicalSize = const Size(430, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugin.csdcorp.com/speech_to_text'),
          (_) async => null,
        );
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService(await SharedPreferences.getInstance());
    await storage.setAiCredits(0);
    final container = ProviderContainer(
      overrides: [
        storageServiceProvider.overrideWithValue(storage),
        isPremiumProvider.overrideWithValue(false),
        ttsServiceProvider.overrideWithValue(_SilentTts()),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: PracticeScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('space'));
    await tester.tap(find.text('space'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Make 10 words'));
    await tester.tap(find.text('Make 10 words'));
    await tester.pumpAndSettle();
    expect(find.byType(TestScreen), findsOneWidget);
    expect(container.read(aiCreditsProvider), 0);
    expect(find.text('More custom practice'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}
