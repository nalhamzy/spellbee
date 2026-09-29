import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spellbee/core/data/words_catalog.dart';
import 'package:spellbee/core/models/adventure.dart';
import 'package:spellbee/core/models/test_result.dart';
import 'package:spellbee/core/services/storage_service.dart';
import 'package:spellbee/core/services/tts_service.dart';
import 'package:spellbee/providers/adventure_provider.dart';
import 'package:spellbee/providers/providers.dart';
import 'package:spellbee/screens/adventures_screen.dart';
import 'package:spellbee/screens/results_screen.dart';

class _SilentVoice extends TtsService {
  @override
  Future<void> speakText(String text, {bool premium = false}) async {}
  @override
  Future<void> playPhrase(String stub, {bool premium = false}) async {}
  @override
  Future<void> stop() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    for (final name in [
      'flutter_tts',
      'xyz.luan/audioplayers',
      'xyz.luan/audioplayers.global',
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(name), (_) async => null);
    }
  });

  test(
    'free journey progresses sequentially, replay is idempotent, paid stays locked',
    () {
      final meadow = adventureWorlds.first;
      var p = AdventureProgress();
      expect(p.finish(meadow, 1, premium: false).completed, isEmpty);
      expect(
        p.finish(adventureWorlds[1], 0, premium: false).completed,
        isEmpty,
      );
      expect(p.canPlay(meadow, -1, premium: true), false);
      expect(p.canPlay(meadow, 4, premium: true), false);
      for (var stop = 0; stop < 4; stop++) {
        p = p.finish(meadow, stop, premium: false);
        expect(p.count(meadow), stop + 1);
      }
      expect(p.finish(meadow, 0, premium: false).count(meadow), 4);
      p = p.finish(adventureWorlds[1], 0, premium: true);
      expect(p.count(adventureWorlds[1]), 1);
      expect(p.canPlay(adventureWorlds[1], 0, premium: false), false);
      expect(p.count(meadow), 4);
    },
  );

  test(
    'every level has unique four-word rounds, stable today and rotating tomorrow',
    () {
      final day = DateTime(2026, 9, 29);
      for (final world in adventureWorlds) {
        for (final level in kWordsCatalog.keys) {
          for (var stop = 0; stop < 4; stop++) {
            final words = adventureWords(world, stop, level, day);
            expect(words.map((w) => w.text).toSet(), hasLength(4));
            expect(words.every(kWordsCatalog[level]!.contains), true);
            expect(adventureWords(world, stop, level, day), words);
            expect(
              adventureWords(
                world,
                stop,
                level,
                day.add(const Duration(days: 1)),
              ),
              isNot(words),
            );
          }
        }
      }
    },
  );

  test(
    'progress persists across launches without changing learning or paid access',
    () async {
      final storage = StorageService(await SharedPreferences.getInstance());
      final container = ProviderContainer(
        overrides: [storageServiceProvider.overrideWithValue(storage)],
      );
      await container
          .read(adventureProvider.notifier)
          .complete(adventureWorlds.first, 0);
      container.dispose();
      final reopened = ProviderContainer(
        overrides: [storageServiceProvider.overrideWithValue(storage)],
      );
      addTearDown(reopened.dispose);
      expect(reopened.read(adventureProvider).count(adventureWorlds.first), 1);
      expect(storage.loadLearning(), isEmpty);
      expect(storage.loadPremium().isPremium, false);
      expect(
        AdventureProgress(['meadow.0', 'rainbow.99', 'unknown']).completed,
        {'meadow.0'},
      );
    },
  );

  for (final size in [const Size(320, 740), const Size(800, 1100)]) {
    testWidgets(
      'paid-world preview at $size keeps rounds locked and has no overflow',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final storage = StorageService(await SharedPreferences.getInstance());
        final voice = _SilentVoice();
        addTearDown(voice.dispose);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              storageServiceProvider.overrideWithValue(storage),
              ttsServiceProvider.overrideWithValue(voice),
            ],
            child: MaterialApp(
              home: AdventureWorldScreen(world: adventureWorlds[1]),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Moonlight Garden'), findsOneWidget);
        expect(find.textContaining('Start stop'), findsNothing);
        await tester.scrollUntilVisible(
          find.text('For grown-ups • explore Premium'),
          200,
        );
        expect(find.text('For grown-ups • explore Premium'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets('results return to the adventure route, not the home route', (
    tester,
  ) async {
    final storage = StorageService(await SharedPreferences.getInstance());
    final voice = _SilentVoice();
    addTearDown(voice.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(storage),
          ttsServiceProvider.overrideWithValue(voice),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ResultsScreen(
                      result: TestResult(
                        items: const [],
                        elapsed: Duration.zero,
                        endedAt: DateTime.now(),
                      ),
                      title: 'Story stop',
                      returnLabel: 'Back to adventure',
                      completionMessage: 'The meadow is blooming!',
                    ),
                  ),
                ),
                child: const Text('Adventure map'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Adventure map'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Back to adventure'), 250);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Back to adventure'));
    await tester.pumpAndSettle();
    expect(find.text('Adventure map'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
