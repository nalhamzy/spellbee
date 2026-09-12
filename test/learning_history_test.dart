import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spellbee/core/models/learning_history.dart';
import 'package:spellbee/core/models/player_stats.dart';
import 'package:spellbee/core/models/test_result.dart';
import 'package:spellbee/core/models/word.dart';
import 'package:spellbee/core/services/storage_service.dart';
import 'package:spellbee/core/services/tts_service.dart';
import 'package:spellbee/providers/providers.dart';
import 'package:spellbee/screens/results_screen.dart';
import 'package:spellbee/screens/test_screen.dart';

const custom = Word('colour', 'Our spelling of color.', 'The colour is blue.');

/// Daily grading does not depend on the native audio engine's callbacks.
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
  Future<void> playPhrase(String stub, {bool premium = false}) async {}
  @override
  Future<void> stop() async {}
}

AskedItem answer({
  bool first = true,
  bool correct = true,
  bool hint = false,
  String mode = 'keyboard',
  bool repeat = false,
}) => AskedItem(
  target: custom.text,
  definition: custom.definition,
  example: custom.example,
  submitted: 'colour',
  isCorrect: correct,
  firstAttemptCorrect: first,
  attempts: first ? 1 : 2,
  usedHint: hint,
  inputMode: mode,
  immediateReview: repeat,
  sourceListId: 'school',
);
TestResult round(
  List<AskedItem> items, {
  DateTime? at,
  RoundKind kind = RoundKind.practice,
}) => TestResult(
  items: items,
  elapsed: const Duration(seconds: 30),
  endedAt: at ?? DateTime(2026, 9, 13),
  kind: kind,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    for (final channel in [
      'flutter_tts',
      'plugin.csdcorp.com/speech_to_text',
      'xyz.luan/audioplayers',
      'xyz.luan/audioplayers.global',
      'plugins.flutter.io/path_provider',
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(channel), (_) async => null);
    }
  });

  testWidgets(
    'retry screen preserves first attempt and custom review context',
    (tester) async {
      tester.view.physicalSize = const Size(500, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService(await SharedPreferences.getInstance());
      final container = ProviderContainer(
        overrides: [storageServiceProvider.overrideWithValue(storage)],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: TestScreen(
              words: [custom],
              title: 'School list',
              sourceListId: 'school',
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.enterText(find.byType(TextField), 'colur');
      await tester.ensureVisible(find.text('Check my spelling'));
      await tester.tap(find.text('Check my spelling'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.ensureVisible(find.text('Try again'));
      await tester.tap(find.text('Try again'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'colour');
      await tester.ensureVisible(find.text('Check my spelling'));
      await tester.tap(find.text('Check my spelling'));
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 1));
      final result = tester
          .widget<ResultsScreen>(find.byType(ResultsScreen))
          .result;
      expect(result.correct, 1);
      expect(result.firstAttemptCorrect, 0);
      expect(result.isPerfect, isFalse);
      expect(find.textContaining('0 of 1 on first try'), findsOneWidget);
      expect(find.text('PERFECT ROUND'), findsNothing);
      expect(storage.loadLearning().values.single.word, custom);
      expect(storage.loadLearning().values.single.lastAttempts, 2);
      expect(storage.loadLearning().values.single.independentDays, 0);
      await tester.pumpWidget(const SizedBox());
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(seconds: 13));
      }
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'corrected retry earns completion without perfect or first-try credit',
    () {
      final result = round([answer(first: false)]);
      expect(result.correct, 1);
      expect(result.firstAttemptCorrect, 0);
      expect(result.independentCorrect, 0);
      expect(result.accuracy, 0);
      expect(result.isPerfect, isFalse);
    },
  );

  testWidgets('daily word preserves completion but cannot establish recall', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(500, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService(await SharedPreferences.getInstance());
    final speech = _SilentTts();
    addTearDown(speech.dispose);
    final container = ProviderContainer(
      overrides: [
        storageServiceProvider.overrideWithValue(storage),
        ttsServiceProvider.overrideWithValue(speech),
      ],
    );
    addTearDown(container.dispose);
    var completed = false;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: TestScreen(
            words: const [custom],
            title: 'Daily word',
            kind: RoundKind.daily,
            // Deliberately omit immediateReview: protection belongs to the round.
            onComplete: () {
              completed = true;
            },
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(find.byType(TextField), 'colour');
    await tester.ensureVisible(find.text('Check my spelling'));
    await tester.tap(find.text('Check my spelling'));
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    final result = tester
        .widget<ResultsScreen>(find.byType(ResultsScreen))
        .result;
    expect(completed, isTrue);
    expect(result.correct, 1);
    expect(result.firstAttemptCorrect, 1);
    expect(result.items.single.immediateReview, isTrue);
    expect(result.independentCorrect, 0);
    expect(result.isPerfect, isFalse);
    expect(find.textContaining('1 of 1 on first try'), findsOneWidget);
    expect(find.text('PERFECT ROUND'), findsNothing);
    final review = storage.loadLearning().values.single;
    expect(review.independentDays, 0);
    expect(review.lastIndependentDay, isNull);
    expect(review.dueDay, learningDay(DateTime.now()) + 1);
    expect(
      container.read(progressionProvider).honey,
      greaterThanOrEqualTo(5),
      reason: 'Correct daily practice keeps completion and daily-word honey.',
    );
    await tester.pumpWidget(const SizedBox());
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(seconds: 13));
    }
    expect(tester.takeException(), isNull);
  });

  test('hints, tiles and same-day practice are distinguished from recall', () {
    for (final item in [
      answer(hint: true),
      answer(mode: 'tiles'),
      answer(repeat: true),
    ]) {
      expect(round([item]).firstAttemptCorrect, 1);
      expect(round([item]).independentCorrect, 0);
      expect(round([item]).isPerfect, isFalse);
    }
    expect(round([answer(mode: 'mic')]).isPerfect, isTrue);
  });

  test('miss returns tomorrow and only separate days extend the interval', () {
    var review = const WordReview(
      word: custom,
      sourceListId: 'school',
      lastDay: 100,
      dueDay: 100,
    ).record(answer(first: false), 100);
    expect(review.dueDay, 101);
    expect(review.independentDays, 0);
    review = review.record(answer(), 100);
    expect(review.independentDays, 0);
    expect(review.dueDay, 101);
    review = review.record(answer(), 101);
    expect(review.independentDays, 1);
    expect(review.dueDay, 102);
    review = review.record(answer(), 102);
    expect(review.independentDays, 2);
    expect(review.dueDay, 104);
    review = review.record(answer(), 102);
    expect(review.independentDays, 2);
    expect(review.dueDay, 104);
    review = review.record(answer(hint: true), 104);
    expect(review.dueDay, 105);
    expect(review.intervalDays, 1);
  });

  test(
    'routine prioritizes overdue custom context, excludes future reviews, deduplicates',
    () {
      final chosen = buildDailyPractice(
        history: [
          const WordReview(
            word: custom,
            sourceListId: 'school',
            lastDay: 90,
            dueDay: 95,
          ),
          const WordReview(
            word: Word('future', '', ''),
            lastDay: 99,
            dueDay: 105,
          ),
        ],
        levelWords: const [
          Word('colour', 'Catalog definition', ''),
          Word('cat', '', ''),
          Word('dog', '', ''),
        ],
        day: 100,
        limit: 3,
      );
      expect(chosen, hasLength(3));
      expect(chosen.first.word, custom);
      expect(chosen.first.sourceListId, 'school');
      expect(chosen.map((r) => r.word.text), ['colour', 'cat', 'dog']);
      expect(chosen.any((r) => r.word.text == 'future'), isFalse);
    },
  );

  test('calendar day changes at local midnight', () {
    expect(
      learningDay(DateTime(2026, 9, 14, 0, 1)) -
          learningDay(DateTime(2026, 9, 13, 23, 59)),
      1,
    );
  });

  test(
    'migration preserves scores and saved level without fabricating recall',
    () async {
      SharedPreferences.setMockInitialValues({
        'sb.stats.v1': const PlayerStats(
          totalTests: 12,
          totalWordsAsked: 60,
          totalWordsCorrect: 48,
        ).encode(),
        'sb.settings.level': 6,
      });
      final storage = StorageService(await SharedPreferences.getInstance());
      expect(storage.loadLearning(), isEmpty);
      expect(storage.loadStats().totalWordsCorrect, 48);
      expect(storage.getSelectedLevel(), 6);
    },
  );

  test(
    'new learners start gently; existing unsaved level remains level three',
    () async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService(await SharedPreferences.getInstance());
      expect(storage.getSelectedLevel(), 1);
      await storage.saveStats(const PlayerStats(totalTests: 1));
      expect(storage.getSelectedLevel(), 3);
    },
  );

  test(
    'persisted history survives reload and excludes number and math rounds',
    () async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService(await SharedPreferences.getInstance());
      final container = ProviderContainer(
        overrides: [storageServiceProvider.overrideWithValue(storage)],
      );
      addTearDown(container.dispose);
      await container
          .read(learningHistoryProvider.notifier)
          .record(round([answer()]));
      final restored = storage.loadLearning().values.single;
      expect(restored.word, custom);
      expect(restored.sourceListId, 'school');
      expect(restored.independentDays, 1);
      expect(restored.lastInputMode, 'keyboard');
      await container
          .read(learningHistoryProvider.notifier)
          .record(round([answer()], kind: RoundKind.math));
      expect(storage.loadLearning().values.single.practiced, 1);
      final nextContainer = ProviderContainer(
        overrides: [storageServiceProvider.overrideWithValue(storage)],
      );
      addTearDown(nextContainer.dispose);
      expect(
        nextContainer.read(learningHistoryProvider).values.single.word,
        custom,
      );
    },
  );

  test('same spelling in different school lists keeps separate context', () {
    expect(reviewKey('colour', 'one'), isNot(reviewKey('colour', 'two')));
    expect(reviewKey(' Colour ', 'one'), reviewKey('colour', 'one'));
  });
}
