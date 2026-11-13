import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spellbee/core/models/test_result.dart';
import 'package:spellbee/core/services/results_offer.dart';
import 'package:spellbee/core/services/review_prompt.dart';
import 'package:spellbee/core/services/storage_service.dart';
import 'package:spellbee/core/services/tts_service.dart';
import 'package:spellbee/core/utils/day_key.dart';
import 'package:spellbee/providers/providers.dart';
import 'package:spellbee/screens/paywall_screen.dart';
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
  final today = localDayKey(DateTime(2026, 11, 14, 10));

  group('policy', () {
    bool offer({
      bool premium = false,
      int rounds = 3,
      double accuracy = 1,
      bool review = false,
      int? last,
    }) => ResultsOfferPolicy.shouldOffer(
      premium: premium,
      roundsFinished: rounds,
      accuracy: accuracy,
      reviewOffered: review,
      today: today,
      lastOfferDay: last,
    );

    test('a good round from the third round on, once, offers the card', () {
      expect(offer(), isTrue);
    });

    test('never during the first two rounds ever finished', () {
      expect(offer(rounds: 1), isFalse);
      expect(offer(rounds: 2), isFalse);
      expect(offer(rounds: 3), isTrue);
    });

    test('never for Premium', () => expect(offer(premium: true), isFalse));

    test('the rating card wins', () => expect(offer(review: true), isFalse));

    test('needs at least 60% correct on the first try', () {
      expect(offer(accuracy: 0.59), isFalse);
      expect(offer(accuracy: 0.6), isTrue);
      expect(offer(accuracy: 0), isFalse);
    });

    test('at most once per local day', () {
      expect(offer(last: today), isFalse);
      expect(offer(last: today - 1), isTrue);
    });
  });

  group('service', () {
    late SharedPreferences prefs;
    late DateTime now;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      now = DateTime(2026, 11, 14, 10);
    });

    ResultsOfferService service() =>
        ResultsOfferService(prefs, clock: () => now);

    bool round(
      ResultsOfferService s, {
      double accuracy = 1,
      bool review = false,
      bool premium = false,
    }) => s.recordRound(
      accuracy: accuracy,
      premium: premium,
      reviewOffered: review,
    );

    test('counts every round, offers from the third, then waits a day', () {
      final s = service();
      expect(round(s), isFalse);
      expect(round(s), isFalse);
      expect(round(s), isTrue);
      expect(round(s), isFalse, reason: 'already shown today');
      expect(service().roundsFinished, 4, reason: 'survives a restart');
      now = DateTime(2026, 11, 14, 23, 59);
      expect(round(service()), isFalse);
      now = DateTime(2026, 11, 15, 0, 1);
      expect(round(service()), isTrue);
    });

    test('a bad round, a Premium round and a review round still count', () {
      final s = service();
      expect(round(s, accuracy: 0.2), isFalse);
      expect(round(s, premium: true), isFalse);
      expect(round(s, review: true), isFalse);
      expect(s.roundsFinished, 3);
      expect(round(s), isTrue, reason: 'the review round did not use the day');
    });
  });

  group('results screen', () {
    Future<void> mount(
      WidgetTester tester, {
      Map<String, Object> prefsValues = const {},
      bool premium = false,
      int correct = 3,
    }) async {
      tester.view.physicalSize = const Size(430, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues(prefsValues);
      final prefs = await SharedPreferences.getInstance();
      final tts = _SilentTts();
      addTearDown(tts.dispose);
      final signals = SessionSignals();
      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          storageServiceProvider.overrideWithValue(StorageService(prefs)),
          ttsServiceProvider.overrideWithValue(tts),
          sessionSignalsProvider.overrideWithValue(signals),
          isPremiumProvider.overrideWithValue(premium),
          iapProductsProvider.overrideWith((ref) async => const []),
          whykeeperPromoProvider.overrideWith((ref) async => null),
        ],
      );
      addTearDown(container.dispose);
      final names = ['cat', 'dog', 'sun'];
      final result = TestResult(
        items: [
          for (var i = 0; i < 3; i++)
            AskedItem(
              target: names[i],
              submitted: i < correct ? names[i] : 'x',
              isCorrect: i < correct,
            ),
        ],
        elapsed: const Duration(seconds: 20),
        endedAt: DateTime.now(),
        longestStreak: 3,
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: ResultsScreen(result: result, title: 'Trial'),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 3));
    }

    final premiumCard = find.byKey(const Key('premium-ask'));
    final reviewCard = find.byKey(const Key('review-ask'));

    testWidgets('third good round shows the parent card, gate then paywall', (
      tester,
    ) async {
      await mount(tester, prefsValues: {'sb.offer.rounds': 2});
      expect(premiumCard, findsOneWidget);
      expect(find.text('FOR GROWN-UPS'), findsOneWidget);
      expect(find.textContaining(r'$'), findsNothing, reason: 'no price');
      expect(
        find.textContaining(RegExp('free', caseSensitive: false)),
        findsNothing,
        reason: 'no "free"',
      );

      await tester.ensureVisible(find.text('See Premium'));
      await tester.tap(find.text('See Premium'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('A moment for grown-ups'), findsOneWidget);
      expect(find.byType(PaywallScreen), findsNothing, reason: 'gate first');
    });

    testWidgets('not in the first two rounds', (tester) async {
      await mount(tester, prefsValues: {'sb.offer.rounds': 1});
      expect(premiumCard, findsNothing);
    });

    testWidgets('not after a poor round', (tester) async {
      await mount(tester, prefsValues: {'sb.offer.rounds': 5}, correct: 1);
      expect(premiumCard, findsNothing);
    });

    testWidgets('not for Premium', (tester) async {
      await mount(tester, prefsValues: {'sb.offer.rounds': 5}, premium: true);
      expect(premiumCard, findsNothing);
    });

    testWidgets('not twice on the same day', (tester) async {
      await mount(
        tester,
        prefsValues: {'sb.offer.rounds': 5, 'sb.offer.lastDay': localDayKey()},
      );
      expect(premiumCard, findsNothing);
    });

    testWidgets('the rating card wins when both would show', (tester) async {
      await mount(
        tester,
        prefsValues: {'sb.offer.rounds': 5, 'sb.review.perfectRounds': 2},
      );
      expect(reviewCard, findsOneWidget);
      expect(premiumCard, findsNothing);
    });
  });
}
