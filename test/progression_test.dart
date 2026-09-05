import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spellbee/core/data/word_facts.dart';
import 'package:spellbee/core/models/progression.dart';
import 'package:spellbee/core/models/test_result.dart';
import 'package:spellbee/core/models/word.dart';
import 'package:spellbee/core/services/iap_service.dart';
import 'package:spellbee/core/services/storage_service.dart';
import 'package:spellbee/core/utils/number_words.dart';
import 'package:spellbee/providers/providers.dart';
import 'package:spellbee/widgets/letter_tiles.dart';

TestResult _round({
  int correct = 10,
  int total = 10,
  RoundKind kind = RoundKind.practice,
  int longestStreak = 0,
  int micCorrect = 0,
  int tilesCorrect = 0,
  int? level,
}) {
  return TestResult(
    items: [
      for (var i = 0; i < total; i++)
        AskedItem(target: 'word$i', submitted: 'word$i', isCorrect: i < correct),
    ],
    elapsed: const Duration(seconds: 30),
    endedAt: DateTime.now(),
    kind: kind,
    longestStreak: longestStreak,
    micCorrect: micCorrect,
    tilesCorrect: tilesCorrect,
    level: level,
  );
}

Future<ProviderContainer> _container() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final c = ProviderContainer(
    retry: (_, _) => null,
    overrides: [
      storageServiceProvider.overrideWithValue(StorageService(prefs)),
      iapServiceProvider.overrideWithValue(IapService()),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('number words', () {
    test('spells 0..999 the way schools teach them', () {
      expect(numberToWords(0), 'zero');
      expect(numberToWords(13), 'thirteen');
      expect(numberToWords(20), 'twenty');
      expect(numberToWords(42), 'forty-two');
      expect(numberToWords(100), 'one hundred');
      expect(numberToWords(307), 'three hundred seven');
      expect(numberToWords(999), 'nine hundred ninety-nine');
    });

    test('number round shows digits and spells the word', () {
      final words = NumberBee.numberRound(
        NumberRange.big,
        random: math.Random(7),
      );
      expect(words, hasLength(8));
      expect(words.map((w) => w.display).toSet(), hasLength(8));
      for (final w in words) {
        final n = int.parse(w.display!);
        expect(n, inInclusiveRange(0, 100));
        expect(w.text, numberToWords(n));
        expect(w.letters, isNot(contains('-')));
        expect(w.prompt, isNull);
      }
    });

    test('math round asks the question and hides the answer from hints', () {
      final words = NumberBee.mathRound(
        NumberRange.little,
        random: math.Random(3),
      );
      expect(words, hasLength(8));
      for (final w in words) {
        final m = RegExp(r'^(\d+) ([+−]) (\d+) = \?$').firstMatch(w.display!);
        expect(m, isNotNull, reason: w.display);
        final a = int.parse(m!.group(1)!);
        final b = int.parse(m.group(3)!);
        final answer = m.group(2) == '+' ? a + b : a - b;
        expect(answer, inInclusiveRange(0, 20));
        expect(w.text, numberToWords(answer));
        expect(w.prompt, contains('Spell the answer'));
        expect(w.definition, isNot(contains(w.text)));
        expect(w.example, isNot(contains(w.text)));
      }
    });

    test('spoken digits are understood as number words', () {
      expect(NumberBee.digitsToWords('38'), 'thirty-eight');
      expect(NumberBee.digitsToWords(' 7 '), 'seven');
      expect(NumberBee.digitsToWords('thirty eight'), isNull);
      expect(NumberBee.digitsToWords('1000'), isNull);
    });

    test('range follows the level bands', () {
      expect(NumberRange.forLevel(1), NumberRange.little);
      expect(NumberRange.forLevel(3), NumberRange.big);
      expect(NumberRange.forLevel(8), NumberRange.giant);
    });
  });

  group('word model', () {
    test('letters strips hyphens and spaces for grading', () {
      const w = Word('thirty-eight', '', '');
      expect(w.letters, 'thirtyeight');
      expect(const Word('one hundred', '', '').letters, 'onehundred');
    });

    test('prompt and display survive json round-trip', () {
      const w = Word('twelve', 'd', 'e', prompt: 'p', display: '7 + 5 = ?');
      expect(Word.fromJson(w.toJson()), w);
      final plain = Word.fromJson(const Word('cat', 'a', 'b').toJson());
      expect(plain.prompt, isNull);
      expect(plain.display, isNull);
    });
  });

  group('tile board', () {
    test('tray holds every answer letter plus decoys not in the word', () {
      final board = TileBoard.forWord('bridge', random: math.Random(1));
      expect(board.tray.length, 6 + 3);
      final counts = <String, int>{};
      for (final c in board.tray) {
        counts[c] = (counts[c] ?? 0) + 1;
      }
      for (final c in 'bridge'.split('')) {
        expect(counts[c], greaterThanOrEqualTo(1));
      }
      // No decoy duplicates an answer letter.
      for (final c in board.tray) {
        if (!'bridge'.contains(c)) expect(counts[c], 1);
      }
      expect(board.tray.take(6).join(), isNot('bridge'));
    });

    test('place and remove build the word in order', () {
      final board = TileBoard.forWord('cat', random: math.Random(2));
      final c = board.tray.indexOf('c');
      final a = board.tray.indexOf('a');
      final t = board.tray.indexOf('t');
      board.place(c);
      board.place(a);
      expect(board.built, 'ca');
      expect(board.isFull, isFalse);
      board.removeSlot(0);
      expect(board.built, 'a');
      board.place(c);
      board.place(t);
      expect(board.built, 'act');
      expect(board.isFull, isTrue);
      board.place(a); // full: ignored
      expect(board.built, 'act');
      board.clear();
      expect(board.isEmpty, isTrue);
    });
  });

  group('ranks, quests, badges', () {
    test('rank is a pure function of honey and never goes backwards', () {
      expect(BeeRank.forHoney(0).title, 'Egg');
      expect(BeeRank.forHoney(59).title, 'Egg');
      expect(BeeRank.forHoney(60).title, 'Larva');
      expect(BeeRank.forHoney(180).title, 'Worker Bee');
      expect(BeeRank.forHoney(4000).title, 'Queen Bee');
      expect(BeeRank.forHoney(99999).title, 'Queen Bee');
      expect(BeeRank.forHoney(4000).next, isNull);
      expect(BeeRank.forHoney(4000).progressFor(9000), 1.0);
      expect(BeeRank.forHoney(60).progressFor(120), closeTo(0.5, 0.001));
    });

    test('daily quests are three distinct quests, stable per day', () {
      for (var day = 20000; day < 20400; day++) {
        final quests = dailyQuestsFor(day);
        expect(quests, hasLength(3));
        expect(quests.map((q) => q.id).toSet(), hasLength(3), reason: '$day');
        expect(quests.first.type, QuestType.correctWords);
        expect(dailyQuestsFor(day), quests);
      }
    });

    test('every badge id resolves and is unique', () {
      expect(kBadges.map((b) => b.id).toSet(), hasLength(kBadges.length));
      for (final b in kBadges) {
        expect(badgeById(b.id), b);
      }
    });

    test('progression survives a json round-trip', () {
      const p = Progression(
        honey: 123,
        badges: {'first_test': 1},
        questDay: 20000,
        questProgress: {'correctWords': 4},
        questsRewarded: {'words10'},
        totalMicWords: 3,
        totalTilesWords: 2,
        factsRead: 1,
        questMasterDays: 1,
      );
      expect(Progression.decode(p.encode()), p);
    });
  });

  group('progression notifier', () {
    test('a round earns honey, advances quests and awards first badges', () async {
      final c = await _container();
      await c
          .read(playerStatsProvider.notifier)
          .recordTestComplete(asked: 10, correct: 10, longestStreak: 10);
      final outcome = await c
          .read(progressionProvider.notifier)
          .recordRound(_round(longestStreak: 10, micCorrect: 2, tilesCorrect: 1));

      // 10 correct × 2 + perfect 5, plus the "spell N words" quest reward
      // that 10 correct words completes on even days (target 10).
      expect(outcome.honeyEarned, greaterThanOrEqualTo(25));
      expect(outcome.newBadges.map((b) => b.id), contains('first_test'));
      expect(outcome.newBadges.map((b) => b.id), contains('perfect_test'));
      expect(outcome.newBadges.map((b) => b.id), contains('streak_10'));
      expect(outcome.newBadges.map((b) => b.id), contains('mic_first'));
      expect(outcome.newBadges.map((b) => b.id), contains('tiles_first'));

      final p = c.read(progressionProvider);
      expect(p.honey, outcome.honeyEarned);
      expect(p.progressFor(kQuestPool[0]), 10);
      expect(p.totalMicWords, 2);
      expect(p.totalTilesWords, 1);
      expect(p.questDay, c.read(dayTickProvider));

      // Persisted: a fresh read from storage matches.
      final stored = c.read(storageServiceProvider).loadProgression();
      expect(stored, p);
    });

    test('quest rewards are granted once and can hand out a pack credit', () async {
      final c = await _container();
      final quests = c.read(dailyQuestsProvider);
      final core = quests.first;
      final creditsBefore = c.read(aiCreditsProvider);

      final first = await c
          .read(progressionProvider.notifier)
          .recordRound(_round(correct: core.target, total: core.target));
      expect(first.questsCompleted.map((q) => q.id), contains(core.id));
      if (core.bonusCredit) {
        expect(c.read(aiCreditsProvider), creditsBefore + 1);
      }

      final second = await c
          .read(progressionProvider.notifier)
          .recordRound(_round(correct: core.target, total: core.target));
      expect(second.questsCompleted.map((q) => q.id), isNot(contains(core.id)));
    });

    test('quest counters reset when the day rolls over', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = StorageService(prefs);
      final yesterday =
          DateTime.now().millisecondsSinceEpoch ~/ Duration.millisecondsPerDay -
          1;
      await storage.saveProgression(
        Progression(
          honey: 50,
          questDay: yesterday,
          questProgress: const {'correctWords': 9},
          questsRewarded: const {'tests2'},
        ),
      );
      final c = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          storageServiceProvider.overrideWithValue(storage),
          iapServiceProvider.overrideWithValue(IapService()),
        ],
      );
      addTearDown(c.dispose);
      final p = c.read(progressionProvider);
      expect(p.honey, 50);
      expect(p.questProgress, isEmpty);
      expect(p.questsRewarded, isEmpty);
      expect(p.questDay, yesterday + 1);
    });

    test('rank-up is reported exactly on the crossing round', () async {
      final c = await _container();
      final n = c.read(progressionProvider.notifier);
      ProgressionOutcome? o;
      var rounds = 0;
      while (rounds++ < 20) {
        o = await n.recordRound(_round(correct: 8, total: 10));
        if (o.rankedUp) break;
      }
      expect(o!.rankedUp, isTrue);
      expect(o.rankBefore.title, 'Egg');
      expect(o.rankAfter.title, 'Larva');
    });

    test('reading facts counts toward the curious bee badge', () async {
      final c = await _container();
      final n = c.read(progressionProvider.notifier);
      ProgressionOutcome? last;
      for (var i = 0; i < 10; i++) {
        last = await n.recordFactRead();
      }
      expect(c.read(progressionProvider).factsRead, 10);
      expect(last!.newBadges.map((b) => b.id), contains('facts_10'));
    });

    test('math bee daily cap counts per day and persists', () async {
      final c = await _container();
      expect(c.read(mathRoundsTodayProvider), 0);
      await c.read(mathRoundsTodayProvider.notifier).increment();
      expect(c.read(mathRoundsTodayProvider), 1);
      expect(c.read(storageServiceProvider).getDailyCount('mathbee'), 1);
    });
  });

  group('facts', () {
    test('daily bee fact is deterministic and cycles the whole bank', () {
      expect(dailyBeeFact(20000), dailyBeeFact(20000));
      final seen = <String>{};
      for (var d = 0; d < kBeeFacts.length; d++) {
        seen.add(dailyBeeFact(d));
      }
      expect(seen, hasLength(kBeeFacts.length));
    });

    test('word facts are short enough to be read in one breath', () {
      expect(factFor('cat'), isNotNull);
      expect(factFor('nonexistentword'), isNull);
      for (final f in kWordFacts.values) {
        expect(f.length, lessThan(200), reason: f);
      }
      for (final f in kBeeFacts) {
        expect(f.length, lessThan(200), reason: f);
      }
    });
  });
}
