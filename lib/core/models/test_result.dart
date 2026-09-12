import 'package:equatable/equatable.dart';

/// How a round was played — the progression layer rewards the modes it
/// wants kids to explore (mic, tiles) and the daily word separately.
enum RoundKind { practice, daily, numbers, math, focus }

class TestResult extends Equatable {
  /// Every word in the order asked, with what was typed/spoken.
  final List<AskedItem> items;
  final Duration elapsed;
  final DateTime endedAt;
  final RoundKind kind;

  /// Longest run of correct words inside this round.
  final int longestStreak;

  /// Correct words answered by voice / by building letter tiles.
  final int micCorrect;
  final int tilesCorrect;

  /// Catalog level when known (badges like "perfect at Champion level").
  final int? level;

  const TestResult({
    required this.items,
    required this.elapsed,
    required this.endedAt,
    this.kind = RoundKind.practice,
    this.longestStreak = 0,
    this.micCorrect = 0,
    this.tilesCorrect = 0,
    this.level,
  });

  int get correct => items.where((i) => i.isCorrect).length;
  int get firstAttemptCorrect =>
      items.where((i) => i.correctOnFirstAttempt).length;
  int get independentCorrect => items.where((i) => i.independentRecall).length;
  int get total => items.length;
  double get accuracy => total == 0 ? 0 : firstAttemptCorrect / total;
  bool get isPerfect => total > 0 && independentCorrect == total;

  @override
  List<Object?> get props => [
    items,
    elapsed,
    endedAt,
    kind,
    longestStreak,
    micCorrect,
    tilesCorrect,
    level,
  ];
}

class AskedItem extends Equatable {
  final String target;
  final String definition;
  final String example;
  final String submitted;
  final bool isCorrect;
  final bool? firstAttemptCorrect;
  final int attempts;
  final bool usedHint;
  final String inputMode;
  final bool immediateReview;
  final String? sourceListId;

  bool get correctOnFirstAttempt => firstAttemptCorrect ?? isCorrect;
  bool get independentRecall =>
      correctOnFirstAttempt &&
      !usedHint &&
      inputMode != 'tiles' &&
      !immediateReview;

  const AskedItem({
    required this.target,
    this.definition = '',
    this.example = '',
    required this.submitted,
    required this.isCorrect,
    this.firstAttemptCorrect,
    this.attempts = 1,
    this.usedHint = false,
    this.inputMode = 'keyboard',
    this.immediateReview = false,
    this.sourceListId,
  });

  @override
  List<Object?> get props => [
    target,
    definition,
    example,
    submitted,
    isCorrect,
    firstAttemptCorrect,
    attempts,
    usedHint,
    inputMode,
    immediateReview,
    sourceListId,
  ];
}
