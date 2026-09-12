import 'dart:convert';
import 'package:spellbee/core/models/test_result.dart';
import 'package:spellbee/core/models/word.dart';

/// Calendar dates, rather than elapsed 24-hour periods, define a review day.
int learningDay(DateTime date) =>
    DateTime.utc(date.year, date.month, date.day).millisecondsSinceEpoch ~/
    Duration.millisecondsPerDay;

String reviewKey(String text, String? listId) =>
    jsonEncode([listId, text.trim().toLowerCase()]);

/// Observations for the existing on-device learner. Historical aggregate
/// scores are deliberately not converted into independent-recall evidence.
class WordReview {
  final Word word;
  final String? sourceListId;
  final int practiced;
  final int firstAttemptCorrect;
  final int independentDays;
  final int? lastIndependentDay;
  final int lastDay;
  final int dueDay;
  final int intervalDays;
  final String lastInputMode;
  final int lastAttempts;
  final bool lastUsedHint;

  const WordReview({
    required this.word,
    this.sourceListId,
    this.practiced = 0,
    this.firstAttemptCorrect = 0,
    this.independentDays = 0,
    this.lastIndependentDay,
    required this.lastDay,
    required this.dueDay,
    this.intervalDays = 1,
    this.lastInputMode = 'keyboard',
    this.lastAttempts = 1,
    this.lastUsedHint = false,
  });

  String get key => reviewKey(word.text, sourceListId);

  WordReview record(AskedItem item, int day) {
    final separateDay =
        item.independentRecall && (practiced == 0 || lastDay < day);
    // Repeating an answer on the same date cannot extend its review interval.
    final interval = !item.independentRecall
        ? 1
        : separateDay
        ? (independentDays == 0 ? 1 : (intervalDays * 2).clamp(1, 14))
        : intervalDays;
    return WordReview(
      word: Word(item.target, item.definition, item.example),
      sourceListId: sourceListId,
      practiced: practiced + 1,
      firstAttemptCorrect:
          firstAttemptCorrect + (item.correctOnFirstAttempt ? 1 : 0),
      independentDays: independentDays + (separateDay ? 1 : 0),
      lastIndependentDay: separateDay ? day : lastIndependentDay,
      lastDay: day,
      dueDay: item.independentRecall && !separateDay ? dueDay : day + interval,
      intervalDays: interval,
      lastInputMode: item.inputMode,
      lastAttempts: item.attempts,
      lastUsedHint: item.usedHint,
    );
  }

  Map<String, dynamic> toJson() => {
    'word': word.toJson(),
    'sourceListId': sourceListId,
    'practiced': practiced,
    'firstAttemptCorrect': firstAttemptCorrect,
    'independentDays': independentDays,
    'lastIndependentDay': lastIndependentDay,
    'lastDay': lastDay,
    'dueDay': dueDay,
    'intervalDays': intervalDays,
    'lastInputMode': lastInputMode,
    'lastAttempts': lastAttempts,
    'lastUsedHint': lastUsedHint,
  };

  factory WordReview.fromJson(Map<String, dynamic> j) => WordReview(
    word: Word.fromJson(j['word'] as Map<String, dynamic>),
    sourceListId: j['sourceListId'] as String?,
    practiced: j['practiced'] as int? ?? 0,
    firstAttemptCorrect: j['firstAttemptCorrect'] as int? ?? 0,
    independentDays: j['independentDays'] as int? ?? 0,
    lastIndependentDay: j['lastIndependentDay'] as int?,
    lastDay: j['lastDay'] as int,
    dueDay: j['dueDay'] as int,
    intervalDays: j['intervalDays'] as int? ?? 1,
    lastInputMode: j['lastInputMode'] as String? ?? 'keyboard',
    lastAttempts: j['lastAttempts'] as int? ?? 1,
    lastUsedHint: j['lastUsedHint'] as bool? ?? false,
  );
}

/// Due reviews first, then a rotating slice of the chosen level. Every item
/// retains its list identity and original definition/example.
List<WordReview> buildDailyPractice({
  required Iterable<WordReview> history,
  required List<Word> levelWords,
  required int day,
  int limit = 8,
}) {
  final due = history.where((r) => r.dueDay <= day).toList()
    ..sort((a, b) {
      final byDate = a.dueDay.compareTo(b.dueDay);
      return byDate != 0 ? byDate : a.key.compareTo(b.key);
    });
  final selected = <WordReview>[];
  final seen = <String>{};
  void add(WordReview review) {
    if (selected.length < limit && seen.add(review.word.text.toLowerCase())) {
      selected.add(review);
    }
  }

  for (final review in due) {
    add(review);
  }
  for (var i = 0; i < levelWords.length; i++) {
    final word = levelWords[(day + i) % levelWords.length];
    add(WordReview(word: word, lastDay: day, dueDay: day));
  }
  return selected;
}
