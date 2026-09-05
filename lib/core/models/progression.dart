import 'dart:convert';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

/// ─── Bee ranks ─────────────────────────────────────────────────────────
///
/// Honey is the single number a kid watches grow. It is never spent — it is
/// lifetime score, and rank is a pure function of it, so nothing can ever
/// "go backwards" and disappoint a child.
class BeeRank {
  final int index;
  final String title;
  final int minHoney;
  final IconData icon;
  final Color color;

  const BeeRank(this.index, this.title, this.minHoney, this.icon, this.color);

  static const all = <BeeRank>[
    BeeRank(0, 'Egg', 0, Icons.egg_rounded, Color(0xFFE59D15)),
    BeeRank(1, 'Larva', 60, Icons.bug_report_rounded, Color(0xFF42B883)),
    BeeRank(2, 'Worker Bee', 180, Icons.emoji_nature_rounded, Color(0xFFFFC83D)),
    BeeRank(3, 'Scout Bee', 400, Icons.explore_rounded, Color(0xFF58A6FF)),
    BeeRank(4, 'Forager', 800, Icons.local_florist_rounded, Color(0xFFFF6B74)),
    BeeRank(5, 'Guard Bee', 1400, Icons.shield_rounded, Color(0xFF8D72FF)),
    BeeRank(6, 'Royal Bee', 2400, Icons.auto_awesome_rounded, Color(0xFFE59D15)),
    BeeRank(7, 'Queen Bee', 4000, Icons.workspace_premium_rounded, Color(0xFF8D72FF)),
  ];

  static BeeRank forHoney(int honey) {
    var rank = all.first;
    for (final r in all) {
      if (honey >= r.minHoney) rank = r;
    }
    return rank;
  }

  BeeRank? get next => index + 1 < all.length ? all[index + 1] : null;

  /// 0..1 progress from this rank toward the next; 1.0 at the top rank.
  double progressFor(int honey) {
    final n = next;
    if (n == null) return 1.0;
    final span = n.minHoney - minHoney;
    return ((honey - minHoney) / span).clamp(0.0, 1.0);
  }
}

/// ─── Quests ────────────────────────────────────────────────────────────

enum QuestType {
  correctWords,
  finishTests,
  perfectTest,
  streakInTest,
  useMic,
  useTiles,
  dailyWord,
  readFacts,
}

class QuestDef {
  final String id;
  final String title;
  final QuestType type;
  final int target;
  final int rewardHoney;

  /// Some quests also hand the free tier an extra AI pack credit — the
  /// earn-a-credit loop that keeps the free experience generous.
  final bool bonusCredit;
  final IconData icon;

  const QuestDef({
    required this.id,
    required this.title,
    required this.type,
    required this.target,
    required this.rewardHoney,
    required this.icon,
    this.bonusCredit = false,
  });
}

const kQuestPool = <QuestDef>[
  QuestDef(
    id: 'words10',
    title: 'Spell 10 words correctly',
    type: QuestType.correctWords,
    target: 10,
    rewardHoney: 15,
    icon: Icons.spellcheck_rounded,
  ),
  QuestDef(
    id: 'words20',
    title: 'Spell 20 words correctly',
    type: QuestType.correctWords,
    target: 20,
    rewardHoney: 30,
    icon: Icons.spellcheck_rounded,
    bonusCredit: true,
  ),
  QuestDef(
    id: 'tests2',
    title: 'Finish 2 practice rounds',
    type: QuestType.finishTests,
    target: 2,
    rewardHoney: 15,
    icon: Icons.flag_rounded,
  ),
  QuestDef(
    id: 'perfect1',
    title: 'Get a perfect round',
    type: QuestType.perfectTest,
    target: 1,
    rewardHoney: 25,
    icon: Icons.stars_rounded,
    bonusCredit: true,
  ),
  QuestDef(
    id: 'streak5',
    title: 'Hit a 5-word streak',
    type: QuestType.streakInTest,
    target: 5,
    rewardHoney: 15,
    icon: Icons.local_fire_department_rounded,
  ),
  QuestDef(
    id: 'mic5',
    title: 'Spell 5 words out loud',
    type: QuestType.useMic,
    target: 5,
    rewardHoney: 20,
    icon: Icons.mic_rounded,
  ),
  QuestDef(
    id: 'tiles5',
    title: 'Build 5 words with letter tiles',
    type: QuestType.useTiles,
    target: 5,
    rewardHoney: 15,
    icon: Icons.grid_view_rounded,
  ),
  QuestDef(
    id: 'daily',
    title: "Spell today's daily word",
    type: QuestType.dailyWord,
    target: 1,
    rewardHoney: 10,
    icon: Icons.wb_sunny_rounded,
  ),
  QuestDef(
    id: 'facts3',
    title: 'Read 3 word facts',
    type: QuestType.readFacts,
    target: 3,
    rewardHoney: 10,
    icon: Icons.lightbulb_rounded,
  ),
];

/// Three quests per day, the same three on every device for that date
/// (kids compare with friends). The first slot is always a "spell N words"
/// quest so the core loop is always rewarded; the other two rotate.
List<QuestDef> dailyQuestsFor(int epochDay) {
  final core = epochDay.isEven ? kQuestPool[0] : kQuestPool[1];
  final rest = kQuestPool.where((q) => q.type != QuestType.correctWords).toList();
  final a = rest[epochDay % rest.length];
  final b = rest[(epochDay * 7 + 3) % rest.length];
  final second = a;
  final third = b.id == a.id ? rest[(epochDay + 1) % rest.length] : b;
  return [core, second, third];
}

/// ─── Badges ────────────────────────────────────────────────────────────

class BadgeDef {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  const BadgeDef({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}

const kBadges = <BadgeDef>[
  BadgeDef(
    id: 'first_test',
    title: 'First Flight',
    description: 'Finish your first practice round',
    icon: Icons.flight_takeoff_rounded,
    color: Color(0xFF58A6FF),
  ),
  BadgeDef(
    id: 'perfect_test',
    title: 'Perfect Round',
    description: 'Spell every word in a round',
    icon: Icons.stars_rounded,
    color: Color(0xFFFFC83D),
  ),
  BadgeDef(
    id: 'streak_10',
    title: 'On Fire',
    description: '10 correct words in a row',
    icon: Icons.local_fire_department_rounded,
    color: Color(0xFFFF6B74),
  ),
  BadgeDef(
    id: 'daily_3',
    title: 'Three Days Strong',
    description: '3-day daily word streak',
    icon: Icons.calendar_today_rounded,
    color: Color(0xFF42B883),
  ),
  BadgeDef(
    id: 'daily_7',
    title: 'Week of Bees',
    description: '7-day daily word streak',
    icon: Icons.date_range_rounded,
    color: Color(0xFF42B883),
  ),
  BadgeDef(
    id: 'daily_30',
    title: 'Hive Habit',
    description: '30-day daily word streak',
    icon: Icons.event_available_rounded,
    color: Color(0xFF8D72FF),
  ),
  BadgeDef(
    id: 'words_100',
    title: 'Century',
    description: '100 words spelled correctly',
    icon: Icons.looks_one_rounded,
    color: Color(0xFFE59D15),
  ),
  BadgeDef(
    id: 'words_500',
    title: 'Word Collector',
    description: '500 words spelled correctly',
    icon: Icons.collections_bookmark_rounded,
    color: Color(0xFFE59D15),
  ),
  BadgeDef(
    id: 'words_1000',
    title: 'Thousand Club',
    description: '1,000 words spelled correctly',
    icon: Icons.military_tech_rounded,
    color: Color(0xFF8D72FF),
  ),
  BadgeDef(
    id: 'mic_first',
    title: 'Out Loud',
    description: 'Spell a word with your voice',
    icon: Icons.mic_rounded,
    color: Color(0xFFFF6B74),
  ),
  BadgeDef(
    id: 'tiles_first',
    title: 'Tile Builder',
    description: 'Build a word with letter tiles',
    icon: Icons.grid_view_rounded,
    color: Color(0xFF58A6FF),
  ),
  BadgeDef(
    id: 'quests_day',
    title: 'Quest Master',
    description: 'Complete all 3 quests in one day',
    icon: Icons.emoji_events_rounded,
    color: Color(0xFFFFC83D),
  ),
  BadgeDef(
    id: 'rank_worker',
    title: 'Worker Bee',
    description: 'Reach the Worker Bee rank',
    icon: Icons.emoji_nature_rounded,
    color: Color(0xFFFFC83D),
  ),
  BadgeDef(
    id: 'rank_queen',
    title: 'Queen Bee',
    description: 'Reach the Queen Bee rank',
    icon: Icons.workspace_premium_rounded,
    color: Color(0xFF8D72FF),
  ),
  BadgeDef(
    id: 'champion_perfect',
    title: 'Champion',
    description: 'Perfect round at Champion level',
    icon: Icons.emoji_events_rounded,
    color: Color(0xFFE59D15),
  ),
  BadgeDef(
    id: 'facts_10',
    title: 'Curious Bee',
    description: 'Read 10 word facts',
    icon: Icons.lightbulb_rounded,
    color: Color(0xFF42B883),
  ),
];

BadgeDef? badgeById(String id) {
  for (final b in kBadges) {
    if (b.id == id) return b;
  }
  return null;
}

/// ─── Persisted state ───────────────────────────────────────────────────

class Progression extends Equatable {
  /// Lifetime honey — the rank score. Never decreases.
  final int honey;

  /// Badge id -> epoch ms earned.
  final Map<String, int> badges;

  /// Epoch day the quest counters below belong to; counters reset when the
  /// day rolls over.
  final int questDay;

  /// QuestType name -> progress count for [questDay].
  final Map<String, int> questProgress;

  /// Quest ids whose reward was already granted today.
  final Set<String> questsRewarded;

  final int totalMicWords;
  final int totalTilesWords;
  final int factsRead;

  /// Days on which all three quests were completed (for the Quest Master
  /// badge and future streak mechanics).
  final int questMasterDays;

  const Progression({
    this.honey = 0,
    this.badges = const {},
    this.questDay = 0,
    this.questProgress = const {},
    this.questsRewarded = const {},
    this.totalMicWords = 0,
    this.totalTilesWords = 0,
    this.factsRead = 0,
    this.questMasterDays = 0,
  });

  BeeRank get rank => BeeRank.forHoney(honey);

  int progressFor(QuestDef q) => questProgress[q.type.name] ?? 0;
  bool isComplete(QuestDef q) => progressFor(q) >= q.target;

  Progression copyWith({
    int? honey,
    Map<String, int>? badges,
    int? questDay,
    Map<String, int>? questProgress,
    Set<String>? questsRewarded,
    int? totalMicWords,
    int? totalTilesWords,
    int? factsRead,
    int? questMasterDays,
  }) => Progression(
    honey: honey ?? this.honey,
    badges: badges ?? this.badges,
    questDay: questDay ?? this.questDay,
    questProgress: questProgress ?? this.questProgress,
    questsRewarded: questsRewarded ?? this.questsRewarded,
    totalMicWords: totalMicWords ?? this.totalMicWords,
    totalTilesWords: totalTilesWords ?? this.totalTilesWords,
    factsRead: factsRead ?? this.factsRead,
    questMasterDays: questMasterDays ?? this.questMasterDays,
  );

  Map<String, dynamic> toJson() => {
    'honey': honey,
    'badges': badges,
    'questDay': questDay,
    'questProgress': questProgress,
    'questsRewarded': questsRewarded.toList(),
    'totalMicWords': totalMicWords,
    'totalTilesWords': totalTilesWords,
    'factsRead': factsRead,
    'questMasterDays': questMasterDays,
  };

  factory Progression.fromJson(Map<String, dynamic> j) => Progression(
    honey: j['honey'] as int? ?? 0,
    badges:
        (j['badges'] as Map<String, dynamic>?)?.map(
          (k, v) => MapEntry(k, v as int? ?? 0),
        ) ??
        const {},
    questDay: j['questDay'] as int? ?? 0,
    questProgress:
        (j['questProgress'] as Map<String, dynamic>?)?.map(
          (k, v) => MapEntry(k, v as int? ?? 0),
        ) ??
        const {},
    questsRewarded:
        (j['questsRewarded'] as List<dynamic>?)?.cast<String>().toSet() ??
        const {},
    totalMicWords: j['totalMicWords'] as int? ?? 0,
    totalTilesWords: j['totalTilesWords'] as int? ?? 0,
    factsRead: j['factsRead'] as int? ?? 0,
    questMasterDays: j['questMasterDays'] as int? ?? 0,
  );

  String encode() => jsonEncode(toJson());
  factory Progression.decode(String raw) =>
      Progression.fromJson(jsonDecode(raw) as Map<String, dynamic>);

  @override
  List<Object?> get props => [
    honey,
    badges,
    questDay,
    questProgress,
    questsRewarded,
    totalMicWords,
    totalTilesWords,
    factsRead,
    questMasterDays,
  ];
}

/// What just happened, so the UI can celebrate exactly the right things.
class ProgressionOutcome {
  final int honeyEarned;
  final List<BadgeDef> newBadges;
  final List<QuestDef> questsCompleted;
  final BeeRank rankBefore;
  final BeeRank rankAfter;
  final int bonusCredits;

  const ProgressionOutcome({
    this.honeyEarned = 0,
    this.newBadges = const [],
    this.questsCompleted = const [],
    required this.rankBefore,
    required this.rankAfter,
    this.bonusCredits = 0,
  });

  bool get rankedUp => rankAfter.index > rankBefore.index;
  bool get isEmpty =>
      honeyEarned == 0 &&
      newBadges.isEmpty &&
      questsCompleted.isEmpty &&
      !rankedUp;
}
