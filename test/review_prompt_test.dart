import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spellbee/core/models/progression.dart';
import 'package:spellbee/core/models/test_result.dart';
import 'package:spellbee/core/services/review_prompt.dart';
import 'package:spellbee/core/services/storage_service.dart';
import 'package:spellbee/core/services/tts_service.dart';
import 'package:spellbee/providers/providers.dart';
import 'package:spellbee/screens/results_screen.dart';

class _SilentTts extends TtsService {
  @override
  Future<void> speakText(String text, {bool premium = false}) async {}
  @override
  Future<void> playPhrase(String stub, {bool premium = false}) async {}
  @override
  Future<void> stop() async {}
}

void main() {
  final t0 = DateTime.utc(2026, 11, 7, 18);

  group('policy', () {
    test('success moments: 3rd perfect round or the first badge', () {
      bool moment({
        bool perfect = false,
        int rounds = 0,
        int newBadges = 0,
        int total = 0,
      }) => ReviewPromptPolicy.isSuccessMoment(
        roundPerfect: perfect,
        perfectRounds: rounds,
        newBadges: newBadges,
        totalBadges: total,
      );
      expect(moment(perfect: true, rounds: 2), isFalse);
      expect(moment(perfect: true, rounds: 3), isTrue);
      expect(moment(perfect: false, rounds: 5), isFalse);
      expect(moment(newBadges: 1, total: 1), isTrue, reason: 'first badge');
      expect(moment(newBadges: 1, total: 4), isFalse, reason: 'not the first');
    });

    test('never after an error or the paywall, at most every 120 days', () {
      bool offer({DateTime? last, bool error = false, bool paywall = false}) =>
          ReviewPromptPolicy.shouldOffer(
            successMoment: true,
            now: t0,
            lastAsked: last,
            errorSeen: error,
            paywallSeen: paywall,
          );
      expect(offer(), isTrue);
      expect(offer(error: true), isFalse);
      expect(offer(paywall: true), isFalse);
      expect(offer(last: t0.subtract(const Duration(days: 119))), isFalse);
      expect(offer(last: t0.subtract(const Duration(days: 120))), isTrue);
      expect(
        ReviewPromptPolicy.shouldOffer(successMoment: false, now: t0),
        isFalse,
      );
    });
  });

  group('service', () {
    late SharedPreferences prefs;
    late DateTime now;
    late int requests;
    late bool available;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      now = t0;
      requests = 0;
      available = true;
    });

    ReviewPromptService service([SessionSignals? signals]) =>
        ReviewPromptService(
          prefs,
          signals: signals,
          clock: () => now,
          isAvailable: () async => available,
          requestReview: () async => requests++,
        );

    test('counts perfect rounds and persists the last-asked date', () {
      final s = service();
      expect(
        s.recordRound(perfect: true, newBadges: 0, totalBadges: 0),
        isFalse,
      );
      expect(
        s.recordRound(perfect: false, newBadges: 0, totalBadges: 0),
        isFalse,
      );
      expect(
        s.recordRound(perfect: true, newBadges: 0, totalBadges: 0),
        isFalse,
      );
      expect(
        s.recordRound(perfect: true, newBadges: 0, totalBadges: 0),
        isTrue,
      );
      expect(s.perfectRounds, 3);
      expect(service().lastAsked, t0, reason: 'survives a restart');

      now = t0.add(const Duration(days: 30));
      expect(
        s.recordRound(perfect: true, newBadges: 0, totalBadges: 0),
        isFalse,
      );
      now = t0.add(const Duration(days: 121));
      expect(
        s.recordRound(perfect: true, newBadges: 0, totalBadges: 0),
        isTrue,
      );
    });

    test('a session that showed the paywall or an error never asks', () {
      final signals = SessionSignals()..paywallSeen = true;
      expect(
        service(
          signals,
        ).recordRound(perfect: false, newBadges: 1, totalBadges: 1),
        isFalse,
      );
      expect(service(signals).lastAsked, isNull);
      final errored = SessionSignals()..errorSeen = true;
      expect(
        service(
          errored,
        ).recordRound(perfect: false, newBadges: 1, totalBadges: 1),
        isFalse,
      );
    });

    test('opens the store sheet only when the platform supports it', () async {
      expect(await service().requestReview(), isTrue);
      expect(requests, 1);
      available = false;
      expect(await service().requestReview(), isFalse);
      expect(requests, 1);
    });
  });

  group('results screen', () {
    late int requests;

    Future<void> mount(
      WidgetTester tester, {
      required Map<String, Object> prefsValues,
      bool paywallSeen = false,
    }) async {
      tester.view.physicalSize = const Size(430, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues(prefsValues);
      final prefs = await SharedPreferences.getInstance();
      final storage = StorageService(prefs);
      final tts = _SilentTts();
      addTearDown(tts.dispose);
      requests = 0;
      final signals = SessionSignals()..paywallSeen = paywallSeen;
      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          storageServiceProvider.overrideWithValue(storage),
          ttsServiceProvider.overrideWithValue(tts),
          sessionSignalsProvider.overrideWithValue(signals),
          reviewPromptServiceProvider.overrideWithValue(
            ReviewPromptService(
              prefs,
              signals: signals,
              isAvailable: () async => true,
              requestReview: () async => requests++,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      final result = TestResult(
        items: const [
          AskedItem(target: 'cat', submitted: 'cat', isCorrect: true),
          AskedItem(target: 'dog', submitted: 'dog', isCorrect: true),
          AskedItem(target: 'sun', submitted: 'sun', isCorrect: true),
        ],
        elapsed: const Duration(seconds: 20),
        endedAt: DateTime.now(),
        longestStreak: 3,
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: ResultsScreen(
              result: result,
              title: 'Trial',
              outcome: ProgressionOutcome(
                honeyEarned: 11,
                newBadges: const [],
                questsCompleted: const [],
                rankBefore: BeeRank.all[0],
                rankAfter: BeeRank.all[0],
                bonusCredits: 0,
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 3));
    }

    testWidgets(
      'the 3rd perfect round offers the card; the sheet waits for the gate',
      (tester) async {
        await mount(tester, prefsValues: {'sb.review.perfectRounds': 2});
        final card = find.byKey(const Key('review-ask'));
        expect(card, findsOneWidget);

        await tester.ensureVisible(find.text('Rate SpellBee'));
        await tester.tap(find.text('Rate SpellBee'));
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.text('A moment for grown-ups'), findsOneWidget);
        expect(requests, 0, reason: 'nothing before the parent answers');

        final challenge = tester
            .widget<Text>(find.byKey(const Key('parent-challenge')))
            .data!;
        final n = RegExp(
          r'\d+',
        ).allMatches(challenge).map((m) => int.parse(m.group(0)!)).toList();
        await tester.enterText(
          find.byKey(const Key('parent-answer')),
          '${n[0] * n[1]}',
        );
        await tester.tap(find.text('Continue'));
        await tester.pump(const Duration(milliseconds: 500));
        expect(requests, 1);
        expect(card, findsNothing);
        await tester.pump(const Duration(seconds: 3));
      },
    );

    testWidgets('a wrong parent answer never opens the store sheet', (
      tester,
    ) async {
      await mount(tester, prefsValues: {'sb.review.perfectRounds': 2});
      await tester.ensureVisible(find.text('Rate SpellBee'));
      await tester.tap(find.text('Rate SpellBee'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('Not now').last);
      await tester.pump(const Duration(milliseconds: 500));
      expect(requests, 0);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('no card after the paywall was shown this session', (
      tester,
    ) async {
      await mount(
        tester,
        prefsValues: {'sb.review.perfectRounds': 2},
        paywallSeen: true,
      );
      expect(find.byKey(const Key('review-ask')), findsNothing);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('no card before the 3rd perfect round', (tester) async {
      await mount(tester, prefsValues: {});
      expect(find.byKey(const Key('review-ask')), findsNothing);
      await tester.pump(const Duration(seconds: 3));
    });
  });
}
