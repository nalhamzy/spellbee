import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spellbee/core/constants/theme.dart';
import 'package:spellbee/core/data/words_catalog.dart';
import 'package:spellbee/core/models/player_stats.dart';
import 'package:spellbee/core/models/progression.dart';
import 'package:spellbee/core/models/test_result.dart';
import 'package:spellbee/core/services/iap_service.dart';
import 'package:spellbee/core/services/storage_service.dart';
import 'package:spellbee/core/utils/number_words.dart';
import 'package:spellbee/providers/providers.dart';
import 'package:spellbee/screens/dashboard_screen.dart';
import 'package:spellbee/screens/number_bee_screen.dart';
import 'package:spellbee/screens/results_screen.dart';
import 'package:spellbee/screens/stats_screen.dart';
import 'package:spellbee/screens/test_screen.dart';
import 'package:spellbee/widgets/letter_tiles.dart';

/// Pumps every new/changed screen at a small phone size and asserts no
/// RenderFlex overflow — the studio's automated stand-in for the on-device
/// smoke render when no test phone is attached.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // takeException() hands back the bare error; the widget chain that
  // overflowed only lives in its diagnostics, so print those before failing.
  void expectNoException(WidgetTester tester) {
    final e = tester.takeException();
    if (e is FlutterError) {
      // ignore: avoid_print
      print(e.toStringDeep());
    }
    expect(e, isNull);
  }

  // Plugins (flutter_tts, speech_to_text, audioplayers, path_provider) have
  // no host implementation under `flutter test`; every call must fail soft.
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

  Future<ProviderContainer> seeded({bool premium = false}) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = StorageService(prefs);
    await storage.saveStats(
      const PlayerStats(
        totalTests: 12,
        totalWordsAsked: 120,
        totalWordsCorrect: 101,
        bestStreak: 9,
        currentStreak: 2,
        dailyStreak: 4,
        missedWordCounts: {'bridge': 2, 'giraffe': 1},
      ),
    );
    await storage.saveProgression(
      Progression(
        honey: 215,
        badges: const {'first_test': 1, 'perfect_test': 2, 'mic_first': 3},
        questDay:
            DateTime.now().millisecondsSinceEpoch ~/
            Duration.millisecondsPerDay,
        questProgress: const {'correctWords': 6, 'finishTests': 1},
        totalMicWords: 4,
        totalTilesWords: 2,
        factsRead: 3,
      ),
    );
    final c = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        storageServiceProvider.overrideWithValue(storage),
        iapServiceProvider.overrideWithValue(IapService()),
        if (premium) isPremiumProvider.overrideWithValue(true),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Widget host(ProviderContainer c, Widget child) => UncontrolledProviderScope(
    container: c,
    child: MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: Container(
          decoration: const BoxDecoration(gradient: AppTheme.pageGradient),
          child: child,
        ),
      ),
    ),
  );

  Future<void> pumpAt(
    WidgetTester tester,
    Widget w, {
    Size size = const Size(360, 640),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    // The overflowing widget's creator chain only exists in the
    // FlutterErrorDetails' information collector, never in the exception
    // object takeException() returns — so tee the details to the log.
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      // ignore: avoid_print
      print(details.toString());
      previous?.call(details);
    };
    addTearDown(() => FlutterError.onError = previous);
    await tester.pumpWidget(w);
    await tester.pump(const Duration(milliseconds: 400));
    expectNoException(tester);
  }

  testWidgets('stats lists mode metrics below the fold', (tester) async {
    final c = await seeded();
    await pumpAt(tester, host(c, const StatsScreen()));
    await tester.dragUntilVisible(
      find.text('Spoken aloud'),
      find.byType(ListView),
      const Offset(0, -250),
    );
    expectNoException(tester);
    expect(find.text('Spoken aloud'), findsOneWidget);
  });

  testWidgets('dashboard renders with rank, quests, games and fact', (
    tester,
  ) async {
    final c = await seeded();
    await pumpAt(tester, host(c, const DashboardScreen()));
    expect(find.textContaining('Worker Bee'), findsWidgets);
    // The dashboard is a lazy ListView: scroll each section into view so
    // every card actually lays out at phone width (that is the point).
    for (final label in [
      "Today's quests",
      'Number Bee',
      'Tile builder',
      'Bee fact of the day',
      'Parent view',
    ]) {
      await tester.dragUntilVisible(
        find.text(label),
        find.byType(ListView),
        const Offset(0, -200),
      );
      expectNoException(tester);
      expect(find.text(label), findsOneWidget, reason: label);
    }
  });

  testWidgets('dashboard hides the premium banner for premium', (tester) async {
    final c = await seeded(premium: true);
    await pumpAt(tester, host(c, const DashboardScreen()));
    expect(find.text('Go Premium'), findsNothing);
  });

  testWidgets('stats renders badges grid and mode metrics', (tester) async {
    final c = await seeded();
    await pumpAt(tester, host(c, const StatsScreen()));
    expect(find.text('Badges'), findsOneWidget);
    expect(find.text('3 of ${kBadges.length} earned'), findsOneWidget);
  });

  testWidgets('number bee screen renders and gates math for free users', (
    tester,
  ) async {
    final c = await seeded();
    await c.read(mathRoundsTodayProvider.notifier).increment();
    await pumpAt(tester, host(c, const NumberBeeScreen()));
    expect(find.text('Say the number'), findsOneWidget);
    expect(find.text('Math Bee'), findsOneWidget);
    expect(find.text('Premium'), findsOneWidget);
  });

  testWidgets('test screen renders all three input modes', (tester) async {
    final c = await seeded();
    final words = (kWordsCatalog[3] ?? const []).take(3).toList();
    await pumpAt(
      tester,
      host(
        c,
        TestScreen(words: words, title: 'Level 3 trial', savesStats: false),
      ),
    );
    expect(find.text('Type'), findsOneWidget);
    await tester.ensureVisible(find.text('Tiles'));
    await tester.tap(find.text('Tiles'));
    await tester.pump(const Duration(milliseconds: 300));
    expectNoException(tester);
    expect(find.byType(LetterTilesInput), findsOneWidget);
    await tester.ensureVisible(find.text('Aloud'));
    await tester.tap(find.text('Aloud'));
    await tester.pump(const Duration(milliseconds: 300));
    expectNoException(tester);
    expect(find.textContaining('Hands-free'), findsOneWidget);
  });

  testWidgets('tiles mode builds a word and grades it', (tester) async {
    final c = await seeded();
    await c.read(autoListenProvider.notifier).set(false);
    final words = (kWordsCatalog[1] ?? const []).take(1).toList();
    await pumpAt(
      tester,
      host(
        c,
        TestScreen(
          words: words,
          title: 'Tile builder',
          savesStats: false,
          initialMode: InputMode.tiles,
        ),
      ),
    );
    final board = tester
        .widget<LetterTilesInput>(find.byType(LetterTilesInput))
        .board;
    // Tap the tiles in answer order via the board's tray.
    for (final letter in words.first.letters.split('')) {
      final idx = board.tray.indexWhere(
        (t) => t == letter && !board.isPlaced(board.tray.indexOf(t)),
      );
      // Find the specific tile widget by its uppercase text among unused.
      final candidates = find.text(letter.toUpperCase());
      expect(candidates, findsWidgets);
      board.place(idx);
    }
    // Force a rebuild so the check button sees a full board.
    await tester.ensureVisible(find.text('Tiles'));
    await tester.tap(find.text('Tiles'));
    await tester.pump();
    expect(board.built, words.first.letters);
    await tester.ensureVisible(find.text('Check my spelling'));
    await tester.tap(find.text('Check my spelling'));
    await tester.pump(const Duration(milliseconds: 300));
    expectNoException(tester);
    expect(find.text('Correct!'), findsOneWidget);
  });

  testWidgets('math round shows the equation and hides the answer', (
    tester,
  ) async {
    final c = await seeded();
    final words = NumberBee.mathRound(NumberRange.little).take(2).toList();
    await pumpAt(
      tester,
      host(
        c,
        TestScreen(
          words: words,
          title: 'Math Bee',
          savesStats: false,
          kind: RoundKind.math,
        ),
      ),
    );
    expect(find.text(words.first.display!), findsOneWidget);
    expect(find.text('Check my answer'), findsOneWidget);
    expect(find.text('How to'), findsOneWidget);
  });

  testWidgets('results screen renders rewards and confetti on a perfect round', (
    tester,
  ) async {
    final c = await seeded();
    final result = TestResult(
      items: const [
        AskedItem(target: 'cat', submitted: 'cat', isCorrect: true),
        AskedItem(target: 'dog', submitted: 'dog', isCorrect: true),
      ],
      elapsed: const Duration(seconds: 12),
      endedAt: DateTime.now(),
      longestStreak: 2,
    );
    final outcome = ProgressionOutcome(
      honeyEarned: 34,
      newBadges: [kBadges.first],
      questsCompleted: [kQuestPool.first],
      rankBefore: BeeRank.all[0],
      rankAfter: BeeRank.all[1],
      bonusCredits: 1,
    );
    await pumpAt(
      tester,
      host(
        c,
        ResultsScreen(result: result, title: 'Trial', outcome: outcome),
      ),
    );
    expect(find.text('+34 honey'), findsOneWidget);
    expect(find.textContaining('Rank up!'), findsOneWidget);
    expect(find.textContaining('Quest done'), findsOneWidget);
    expect(find.textContaining('New badge'), findsOneWidget);
    expect(find.text('PERFECT ROUND'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expectNoException(tester);
  });

  testWidgets('screens survive a tablet width', (tester) async {
    final c = await seeded();
    await pumpAt(
      tester,
      host(c, const DashboardScreen()),
      size: const Size(800, 1200),
    );
    await pumpAt(
      tester,
      host(c, const StatsScreen()),
      size: const Size(800, 1200),
    );
  });
}
