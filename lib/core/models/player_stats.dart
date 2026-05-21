import 'dart:convert';
import 'package:equatable/equatable.dart';

class ListScoreSummary extends Equatable {
  final int attempts;
  final int lastCorrect;
  final int lastTotal;
  final int bestCorrect;
  final int bestTotal;
  final int? lastPlayedEpochMs;

  const ListScoreSummary({
    this.attempts = 0,
    this.lastCorrect = 0,
    this.lastTotal = 0,
    this.bestCorrect = 0,
    this.bestTotal = 0,
    this.lastPlayedEpochMs,
  });

  double get lastAccuracy => lastTotal == 0 ? 0 : lastCorrect / lastTotal;
  double get bestAccuracy => bestTotal == 0 ? 0 : bestCorrect / bestTotal;

  ListScoreSummary record({
    required int correct,
    required int total,
    required int playedAtEpochMs,
  }) {
    final isNewBest =
        bestTotal == 0 ||
        correct * bestTotal > bestCorrect * total ||
        (correct * bestTotal == bestCorrect * total && correct > bestCorrect);

    return ListScoreSummary(
      attempts: attempts + 1,
      lastCorrect: correct,
      lastTotal: total,
      bestCorrect: isNewBest ? correct : bestCorrect,
      bestTotal: isNewBest ? total : bestTotal,
      lastPlayedEpochMs: playedAtEpochMs,
    );
  }

  Map<String, dynamic> toJson() => {
    'attempts': attempts,
    'lastCorrect': lastCorrect,
    'lastTotal': lastTotal,
    'bestCorrect': bestCorrect,
    'bestTotal': bestTotal,
    'lastPlayedEpochMs': lastPlayedEpochMs,
  };

  factory ListScoreSummary.fromJson(Map<String, dynamic> j) => ListScoreSummary(
    attempts: j['attempts'] as int? ?? 0,
    lastCorrect: j['lastCorrect'] as int? ?? 0,
    lastTotal: j['lastTotal'] as int? ?? 0,
    bestCorrect: j['bestCorrect'] as int? ?? 0,
    bestTotal: j['bestTotal'] as int? ?? 0,
    lastPlayedEpochMs: j['lastPlayedEpochMs'] as int?,
  );

  @override
  List<Object?> get props => [
    attempts,
    lastCorrect,
    lastTotal,
    bestCorrect,
    bestTotal,
    lastPlayedEpochMs,
  ];
}

/// Lifetime stats for a single on-device user.
class PlayerStats extends Equatable {
  final int totalTests;
  final int totalWordsAsked;
  final int totalWordsCorrect;
  final int bestStreak; // longest correct streak within a test
  final int currentStreak;
  final int? lastPlayedEpochMs;

  /// Lowercase word -> number of recent misses. Used to recommend retry packs.
  final Map<String, int> missedWordCounts;

  /// Custom list id -> score history for that parent-created list.
  final Map<String, ListScoreSummary> listScores;

  /// Days since Unix epoch on which the user last completed a daily word.
  final int? lastDailyEpochDay;

  /// Consecutive days the user has completed a daily word or any test.
  final int dailyStreak;

  const PlayerStats({
    this.totalTests = 0,
    this.totalWordsAsked = 0,
    this.totalWordsCorrect = 0,
    this.bestStreak = 0,
    this.currentStreak = 0,
    this.lastPlayedEpochMs,
    this.missedWordCounts = const {},
    this.listScores = const {},
    this.lastDailyEpochDay,
    this.dailyStreak = 0,
  });

  double get accuracy =>
      totalWordsAsked == 0 ? 0 : totalWordsCorrect / totalWordsAsked;

  PlayerStats copyWith({
    int? totalTests,
    int? totalWordsAsked,
    int? totalWordsCorrect,
    int? bestStreak,
    int? currentStreak,
    int? lastPlayedEpochMs,
    Map<String, int>? missedWordCounts,
    Map<String, ListScoreSummary>? listScores,
    int? lastDailyEpochDay,
    int? dailyStreak,
  }) => PlayerStats(
    totalTests: totalTests ?? this.totalTests,
    totalWordsAsked: totalWordsAsked ?? this.totalWordsAsked,
    totalWordsCorrect: totalWordsCorrect ?? this.totalWordsCorrect,
    bestStreak: bestStreak ?? this.bestStreak,
    currentStreak: currentStreak ?? this.currentStreak,
    lastPlayedEpochMs: lastPlayedEpochMs ?? this.lastPlayedEpochMs,
    missedWordCounts: missedWordCounts ?? this.missedWordCounts,
    listScores: listScores ?? this.listScores,
    lastDailyEpochDay: lastDailyEpochDay ?? this.lastDailyEpochDay,
    dailyStreak: dailyStreak ?? this.dailyStreak,
  );

  Map<String, dynamic> toJson() => {
    'totalTests': totalTests,
    'totalWordsAsked': totalWordsAsked,
    'totalWordsCorrect': totalWordsCorrect,
    'bestStreak': bestStreak,
    'currentStreak': currentStreak,
    'lastPlayedEpochMs': lastPlayedEpochMs,
    'missedWordCounts': missedWordCounts,
    'listScores': listScores.map((key, value) => MapEntry(key, value.toJson())),
    'lastDailyEpochDay': lastDailyEpochDay,
    'dailyStreak': dailyStreak,
  };

  factory PlayerStats.fromJson(Map<String, dynamic> j) => PlayerStats(
    totalTests: j['totalTests'] as int? ?? 0,
    totalWordsAsked: j['totalWordsAsked'] as int? ?? 0,
    totalWordsCorrect: j['totalWordsCorrect'] as int? ?? 0,
    bestStreak: j['bestStreak'] as int? ?? 0,
    currentStreak: j['currentStreak'] as int? ?? 0,
    lastPlayedEpochMs: j['lastPlayedEpochMs'] as int?,
    missedWordCounts:
        (j['missedWordCounts'] as Map<String, dynamic>?)?.map(
          (key, value) => MapEntry(key, value as int? ?? 0),
        ) ??
        const {},
    listScores:
        (j['listScores'] as Map<String, dynamic>?)?.map(
          (key, value) => MapEntry(
            key,
            ListScoreSummary.fromJson(value as Map<String, dynamic>),
          ),
        ) ??
        const {},
    lastDailyEpochDay: j['lastDailyEpochDay'] as int?,
    dailyStreak: j['dailyStreak'] as int? ?? 0,
  );

  String encode() => jsonEncode(toJson());
  factory PlayerStats.decode(String raw) =>
      PlayerStats.fromJson(jsonDecode(raw) as Map<String, dynamic>);

  @override
  List<Object?> get props => [
    totalTests,
    totalWordsAsked,
    totalWordsCorrect,
    bestStreak,
    currentStreak,
    lastPlayedEpochMs,
    missedWordCounts,
    listScores,
    lastDailyEpochDay,
    dailyStreak,
  ];
}
