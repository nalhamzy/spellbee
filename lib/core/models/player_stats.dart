import 'dart:convert';
import 'package:equatable/equatable.dart';

/// Lifetime stats for a single on-device user.
class PlayerStats extends Equatable {
  final int totalTests;
  final int totalWordsAsked;
  final int totalWordsCorrect;
  final int bestStreak;       // longest correct streak within a test
  final int currentStreak;
  final int? lastPlayedEpochMs;

  const PlayerStats({
    this.totalTests = 0,
    this.totalWordsAsked = 0,
    this.totalWordsCorrect = 0,
    this.bestStreak = 0,
    this.currentStreak = 0,
    this.lastPlayedEpochMs,
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
  }) =>
      PlayerStats(
        totalTests: totalTests ?? this.totalTests,
        totalWordsAsked: totalWordsAsked ?? this.totalWordsAsked,
        totalWordsCorrect: totalWordsCorrect ?? this.totalWordsCorrect,
        bestStreak: bestStreak ?? this.bestStreak,
        currentStreak: currentStreak ?? this.currentStreak,
        lastPlayedEpochMs: lastPlayedEpochMs ?? this.lastPlayedEpochMs,
      );

  Map<String, dynamic> toJson() => {
        'totalTests': totalTests,
        'totalWordsAsked': totalWordsAsked,
        'totalWordsCorrect': totalWordsCorrect,
        'bestStreak': bestStreak,
        'currentStreak': currentStreak,
        'lastPlayedEpochMs': lastPlayedEpochMs,
      };

  factory PlayerStats.fromJson(Map<String, dynamic> j) => PlayerStats(
        totalTests: j['totalTests'] as int? ?? 0,
        totalWordsAsked: j['totalWordsAsked'] as int? ?? 0,
        totalWordsCorrect: j['totalWordsCorrect'] as int? ?? 0,
        bestStreak: j['bestStreak'] as int? ?? 0,
        currentStreak: j['currentStreak'] as int? ?? 0,
        lastPlayedEpochMs: j['lastPlayedEpochMs'] as int?,
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
      ];
}
