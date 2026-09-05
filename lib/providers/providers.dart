import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spellbee/core/data/word_facts.dart';
import 'package:spellbee/core/data/words_catalog.dart';
import 'package:spellbee/core/models/player_stats.dart';
import 'package:spellbee/core/models/premium_state.dart';
import 'package:spellbee/core/models/progression.dart';
import 'package:spellbee/core/models/test_result.dart';
import 'package:spellbee/core/models/word.dart';
import 'package:spellbee/core/models/word_list.dart';
import 'package:spellbee/core/services/ai_word_generator.dart';
import 'package:spellbee/core/services/iap_service.dart';
import 'package:spellbee/core/services/storage_service.dart';
import 'package:spellbee/core/services/stt_service.dart';
import 'package:spellbee/core/services/tts_service.dart';
export 'package:spellbee/core/services/openai_tts_service.dart'
    show OpenAiTtsService;
export 'package:spellbee/core/services/tts_service.dart'
    show
        StudioVoiceOption,
        VoiceQuality,
        VoiceQualityLabel,
        VoiceSpeed,
        kOpenAiStudioVoices;

// ─── Service providers (overridden in main.dart) ───────────────────────

final storageServiceProvider = Provider<StorageService>((ref) {
  throw UnimplementedError('Override storageServiceProvider in main.dart');
});

final iapServiceProvider = Provider<IapService>((ref) {
  throw UnimplementedError('Override iapServiceProvider in main.dart');
});

final ttsServiceProvider = Provider<TtsService>((ref) {
  final s = TtsService();
  final storage = ref.read(storageServiceProvider);
  final idx = storage.getVoiceSpeedIndex();
  s.setSpeed(VoiceSpeed.values[idx.clamp(0, VoiceSpeed.values.length - 1)]);
  final qualityIdx = storage.getVoiceQualityIndex();
  s.setQuality(
    VoiceQuality.values[qualityIdx.clamp(0, VoiceQuality.values.length - 1)],
  );
  s.setOpenAiVoice(storage.getOpenAiVoice());
  ref.listen<VoiceSpeed>(voiceSpeedProvider, (_, next) => s.setSpeed(next));
  ref.listen<VoiceQuality>(
    voiceQualityProvider,
    (_, next) => s.setQuality(next),
  );
  ref.listen<String>(openAiVoiceProvider, (_, next) => s.setOpenAiVoice(next));
  ref.onDispose(s.dispose);
  return s;
});

final voiceSpeedProvider = NotifierProvider<VoiceSpeedNotifier, VoiceSpeed>(
  VoiceSpeedNotifier.new,
);

class VoiceSpeedNotifier extends Notifier<VoiceSpeed> {
  @override
  VoiceSpeed build() {
    final idx = ref.read(storageServiceProvider).getVoiceSpeedIndex();
    return VoiceSpeed.values[idx.clamp(0, VoiceSpeed.values.length - 1)];
  }

  Future<void> set(VoiceSpeed s) async {
    state = s;
    await ref.read(storageServiceProvider).setVoiceSpeedIndex(s.index);
  }
}

final voiceQualityProvider =
    NotifierProvider<VoiceQualityNotifier, VoiceQuality>(
      VoiceQualityNotifier.new,
    );

class VoiceQualityNotifier extends Notifier<VoiceQuality> {
  @override
  VoiceQuality build() {
    final idx = ref.read(storageServiceProvider).getVoiceQualityIndex();
    return VoiceQuality.values[idx.clamp(0, VoiceQuality.values.length - 1)];
  }

  Future<void> set(VoiceQuality quality) async {
    state = quality;
    await ref.read(storageServiceProvider).setVoiceQualityIndex(quality.index);
  }
}

final openAiVoiceProvider = NotifierProvider<OpenAiVoiceNotifier, String>(
  OpenAiVoiceNotifier.new,
);

class OpenAiVoiceNotifier extends Notifier<String> {
  @override
  String build() => ref.read(storageServiceProvider).getOpenAiVoice();

  Future<void> set(String voice) async {
    state = voice;
    await ref.read(storageServiceProvider).setOpenAiVoice(voice);
  }
}

final sttServiceProvider = Provider<SttService>((ref) {
  final s = SttService();
  ref.onDispose(s.dispose);
  return s;
});

final aiGeneratorProvider = Provider<AiWordGenerator>(
  (ref) => AiWordGenerator(),
);

// ─── Tabs ───────────────────────────────────────────────────────────────

enum AppTab { home, practice, lists, stats, settings }

final tabProvider = NotifierProvider<TabNotifier, AppTab>(TabNotifier.new);

class TabNotifier extends Notifier<AppTab> {
  @override
  AppTab build() => AppTab.home;
  void go(AppTab t) => state = t;
}

// ─── Daily word ─────────────────────────────────────────────────────────

/// The current epoch day, refreshed when the app returns to the foreground
/// (see the lifecycle observer in app.dart). Kids' tablets keep apps
/// resident for days; without this tick the daily word, its "done" flag,
/// and the AI credit were all frozen at whatever day the process started.
final dayTickProvider = NotifierProvider<DayTickNotifier, int>(
  DayTickNotifier.new,
);

class DayTickNotifier extends Notifier<int> {
  @override
  int build() => _todayEpochDay();

  /// Re-reads the clock; only changes state (and thus dependents) when the
  /// date actually rolled over.
  void refresh() {
    final today = _todayEpochDay();
    if (today != state) state = today;
  }
}

/// All catalog words flattened into a single list, sorted deterministically.
/// Computed once — same order every app session.
List<Word> _allCatalogWords() {
  final words = <Word>[];
  for (final level in (kWordsCatalog.keys.toList()..sort())) {
    words.addAll(kWordsCatalog[level] ?? []);
  }
  return words;
}

/// Returns today's Word of the Day — deterministic by date so every device
/// shows the same word. Uses epochDay % catalog-size.
final dailyWordProvider = Provider<Word>((ref) {
  final allWords = _allCatalogWords();
  final epochDay = ref.watch(dayTickProvider);
  return allWords[epochDay % allWords.length];
});

/// Today's epoch-day integer (days since 1970-01-01).
int _todayEpochDay() =>
    DateTime.now().millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;

/// True when the user has already completed today's daily word.
final dailyWordDoneProvider = Provider<bool>((ref) {
  final stats = ref.watch(playerStatsProvider);
  return stats.lastDailyEpochDay == ref.watch(dayTickProvider);
});

/// Today's "did you know?" line for the dashboard — same on every device.
final dailyFactProvider = Provider<String>(
  (ref) => dailyBeeFact(ref.watch(dayTickProvider)),
);

// ─── Progression: honey, ranks, quests, badges ──────────────────────────

final progressionProvider =
    NotifierProvider<ProgressionNotifier, Progression>(
      ProgressionNotifier.new,
    );

/// The three quests for today, with their live progress.
final dailyQuestsProvider = Provider<List<QuestDef>>(
  (ref) => dailyQuestsFor(ref.watch(dayTickProvider)),
);

class ProgressionNotifier extends Notifier<Progression> {
  @override
  Progression build() {
    final today = ref.watch(dayTickProvider);
    return _rolled(ref.read(storageServiceProvider).loadProgression(), today);
  }

  /// Quest counters belong to one calendar day; anything older is wiped the
  /// first time the day is observed so a kid never wakes up to yesterday's
  /// half-done quests.
  static Progression _rolled(Progression p, int today) {
    if (p.questDay == today) return p;
    return p.copyWith(
      questDay: today,
      questProgress: const {},
      questsRewarded: const {},
    );
  }

  static const _honeyPerCorrect = 2;
  static const _honeyPerfectBonus = 5;
  static const _honeyDailyWord = 3;

  /// Apply a finished round. Must run AFTER playerStats and the daily-word
  /// callback so badge checks see the updated lifetime numbers.
  Future<ProgressionOutcome> recordRound(TestResult result) async {
    final stats = ref.read(playerStatsProvider);
    final before = state.rank;
    var p = _rolled(state, ref.read(dayTickProvider));

    var honey = result.correct * _honeyPerCorrect;
    if (result.isPerfect) honey += _honeyPerfectBonus;
    if (result.kind == RoundKind.daily && result.isPerfect) {
      honey += _honeyDailyWord;
    }

    final progress = Map<String, int>.from(p.questProgress);
    void bump(QuestType t, int by) {
      if (by <= 0) return;
      progress[t.name] = (progress[t.name] ?? 0) + by;
    }

    void high(QuestType t, int value) {
      if (value > (progress[t.name] ?? 0)) progress[t.name] = value;
    }

    bump(QuestType.correctWords, result.correct);
    bump(QuestType.finishTests, 1);
    if (result.isPerfect) bump(QuestType.perfectTest, 1);
    high(QuestType.streakInTest, result.longestStreak);
    bump(QuestType.useMic, result.micCorrect);
    bump(QuestType.useTiles, result.tilesCorrect);
    if (result.kind == RoundKind.daily && result.isPerfect) {
      bump(QuestType.dailyWord, 1);
    }

    p = p.copyWith(
      questProgress: progress,
      totalMicWords: p.totalMicWords + result.micCorrect,
      totalTilesWords: p.totalTilesWords + result.tilesCorrect,
    );

    // Quest rewards.
    final rewarded = Set<String>.from(p.questsRewarded);
    final completed = <QuestDef>[];
    var bonusCredits = 0;
    for (final q in ref.read(dailyQuestsProvider)) {
      if (rewarded.contains(q.id) || !p.isComplete(q)) continue;
      rewarded.add(q.id);
      completed.add(q);
      honey += q.rewardHoney;
      if (q.bonusCredit) bonusCredits++;
    }
    var masterDays = p.questMasterDays;
    if (completed.isNotEmpty &&
        ref.read(dailyQuestsProvider).every((q) => rewarded.contains(q.id))) {
      masterDays++;
    }
    p = p.copyWith(
      honey: p.honey + honey,
      questsRewarded: rewarded,
      questMasterDays: masterDays,
    );

    // Badges.
    final newBadges = <BadgeDef>[];
    final badges = Map<String, int>.from(p.badges);
    void award(String id, bool condition) {
      if (!condition || badges.containsKey(id)) return;
      final def = badgeById(id);
      if (def == null) return;
      badges[id] = DateTime.now().millisecondsSinceEpoch;
      newBadges.add(def);
    }

    award('first_test', stats.totalTests >= 1);
    award('perfect_test', result.isPerfect && result.total >= 3);
    award('streak_10', result.longestStreak >= 10 || stats.bestStreak >= 10);
    award('daily_3', stats.dailyStreak >= 3);
    award('daily_7', stats.dailyStreak >= 7);
    award('daily_30', stats.dailyStreak >= 30);
    award('words_100', stats.totalWordsCorrect >= 100);
    award('words_500', stats.totalWordsCorrect >= 500);
    award('words_1000', stats.totalWordsCorrect >= 1000);
    award('mic_first', p.totalMicWords >= 1);
    award('tiles_first', p.totalTilesWords >= 1);
    award('quests_day', masterDays >= 1);
    award('rank_worker', p.rank.index >= 2);
    award('rank_queen', p.rank.index >= 7);
    award(
      'champion_perfect',
      result.isPerfect && result.level == 8 && result.total >= 5,
    );
    p = p.copyWith(badges: badges);

    state = p;
    await ref.read(storageServiceProvider).saveProgression(p);
    if (bonusCredits > 0) {
      await ref.read(aiCreditsProvider.notifier).grant(bonusCredits);
    }
    return ProgressionOutcome(
      honeyEarned: honey,
      newBadges: newBadges,
      questsCompleted: completed,
      rankBefore: before,
      rankAfter: p.rank,
      bonusCredits: bonusCredits,
    );
  }

  /// A fact was opened (reveal card or dashboard). Small honey, counts
  /// toward the facts quest and the Curious Bee badge.
  Future<ProgressionOutcome> recordFactRead() async {
    final before = state.rank;
    var p = _rolled(state, ref.read(dayTickProvider));
    final progress = Map<String, int>.from(p.questProgress);
    progress[QuestType.readFacts.name] =
        (progress[QuestType.readFacts.name] ?? 0) + 1;
    var honey = 1;
    p = p.copyWith(questProgress: progress, factsRead: p.factsRead + 1);

    final rewarded = Set<String>.from(p.questsRewarded);
    final completed = <QuestDef>[];
    var bonusCredits = 0;
    for (final q in ref.read(dailyQuestsProvider)) {
      if (rewarded.contains(q.id) || !p.isComplete(q)) continue;
      rewarded.add(q.id);
      completed.add(q);
      honey += q.rewardHoney;
      if (q.bonusCredit) bonusCredits++;
    }
    var masterDays = p.questMasterDays;
    if (completed.isNotEmpty &&
        ref.read(dailyQuestsProvider).every((q) => rewarded.contains(q.id))) {
      masterDays++;
    }
    final badges = Map<String, int>.from(p.badges);
    final newBadges = <BadgeDef>[];
    if (p.factsRead >= 10 && !badges.containsKey('facts_10')) {
      badges['facts_10'] = DateTime.now().millisecondsSinceEpoch;
      newBadges.add(badgeById('facts_10')!);
    }
    if (masterDays >= 1 && !badges.containsKey('quests_day')) {
      badges['quests_day'] = DateTime.now().millisecondsSinceEpoch;
      newBadges.add(badgeById('quests_day')!);
    }
    p = p.copyWith(
      honey: p.honey + honey,
      questsRewarded: rewarded,
      questMasterDays: masterDays,
      badges: badges,
    );
    state = p;
    await ref.read(storageServiceProvider).saveProgression(p);
    if (bonusCredits > 0) {
      await ref.read(aiCreditsProvider.notifier).grant(bonusCredits);
    }
    return ProgressionOutcome(
      honeyEarned: honey,
      newBadges: newBadges,
      questsCompleted: completed,
      rankBefore: before,
      rankAfter: p.rank,
      bonusCredits: bonusCredits,
    );
  }
}

// ─── Number Bee free-tier cap ───────────────────────────────────────────

/// Math Bee rounds played today. Free tier gets [kFreeMathRoundsPerDay];
/// "Say the number" is never capped — counting is core learning.
const kFreeMathRoundsPerDay = 1;

final mathRoundsTodayProvider =
    NotifierProvider<MathRoundsTodayNotifier, int>(
      MathRoundsTodayNotifier.new,
    );

class MathRoundsTodayNotifier extends Notifier<int> {
  static const _name = 'mathbee';

  @override
  int build() {
    ref.watch(dayTickProvider);
    return ref.read(storageServiceProvider).getDailyCount(_name);
  }

  Future<void> increment() async {
    state = state + 1;
    await ref.read(storageServiceProvider).setDailyCount(_name, state);
  }
}

// ─── Hands-free spell-aloud ─────────────────────────────────────────────

final autoListenProvider = NotifierProvider<AutoListenNotifier, bool>(
  AutoListenNotifier.new,
);

class AutoListenNotifier extends Notifier<bool> {
  @override
  bool build() => ref.read(storageServiceProvider).getAutoListen();

  Future<void> set(bool v) async {
    state = v;
    await ref.read(storageServiceProvider).setAutoListen(v);
  }
}

// ─── Player stats ───────────────────────────────────────────────────────

final playerStatsProvider = NotifierProvider<PlayerStatsNotifier, PlayerStats>(
  PlayerStatsNotifier.new,
);

class PlayerStatsNotifier extends Notifier<PlayerStats> {
  @override
  PlayerStats build() => ref.read(storageServiceProvider).loadStats();

  Future<void> recordTestComplete({
    required int asked,
    required int correct,
    required int longestStreak,
    Iterable<String> missedWords = const [],
    Iterable<String> masteredWords = const [],
    String? listId,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final bestStreak = longestStreak > state.bestStreak
        ? longestStreak
        : state.bestStreak;
    final missedCounts = Map<String, int>.from(state.missedWordCounts);
    for (final word in missedWords) {
      final key = word.toLowerCase().trim();
      if (key.isEmpty) continue;
      missedCounts[key] = (missedCounts[key] ?? 0) + 1;
    }
    for (final word in masteredWords) {
      final key = word.toLowerCase().trim();
      if (key.isEmpty || !missedCounts.containsKey(key)) continue;
      final next = missedCounts[key]! - 1;
      if (next <= 0) {
        missedCounts.remove(key);
      } else {
        missedCounts[key] = next;
      }
    }
    final listScores = Map<String, ListScoreSummary>.from(state.listScores);
    final trimmedListId = listId?.trim();
    if (trimmedListId != null && trimmedListId.isNotEmpty) {
      listScores[trimmedListId] =
          (listScores[trimmedListId] ?? const ListScoreSummary()).record(
            correct: correct,
            total: asked,
            playedAtEpochMs: now,
          );
    }
    state = state.copyWith(
      totalTests: state.totalTests + 1,
      totalWordsAsked: state.totalWordsAsked + asked,
      totalWordsCorrect: state.totalWordsCorrect + correct,
      bestStreak: bestStreak,
      currentStreak: correct == asked
          ? state.currentStreak + 1
          : 0, // reset streak if the test wasn't perfect
      lastPlayedEpochMs: now,
      missedWordCounts: missedCounts,
      listScores: listScores,
    );
    await ref.read(storageServiceProvider).saveStats(state);
  }

  /// Call when the user correctly spells today's daily word.
  Future<void> recordDailyWordComplete() async {
    final today = _todayEpochDay();
    if (state.lastDailyEpochDay == today) return; // already counted

    final yesterday = today - 1;
    final newStreak = state.lastDailyEpochDay == yesterday
        ? state.dailyStreak + 1
        : 1; // streak broken — reset to 1

    state = state.copyWith(lastDailyEpochDay: today, dailyStreak: newStreak);
    await ref.read(storageServiceProvider).saveStats(state);
  }
}

// ─── Premium ────────────────────────────────────────────────────────────

final premiumProvider = NotifierProvider<PremiumNotifier, PremiumState>(
  PremiumNotifier.new,
);

class PremiumNotifier extends Notifier<PremiumState> {
  @override
  PremiumState build() => ref.read(storageServiceProvider).loadPremium();

  Future<void> activate(String productId) async {
    state = state.copyWith(
      activeProductId: productId,
      activatedAt: DateTime.now(),
    );
    await ref.read(storageServiceProvider).savePremium(state);
  }

  Future<void> clear() async {
    state = const PremiumState();
    await ref.read(storageServiceProvider).savePremium(state);
  }
}

final isPremiumProvider = Provider<bool>((ref) {
  const forcePremium = bool.fromEnvironment('FORCE_PREMIUM_UNLOCK');
  if (forcePremium) return true;
  return ref.watch(premiumProvider).isPremium;
});

final iapProductsProvider = FutureProvider<List<IapProduct>>((ref) async {
  try {
    return await ref.read(iapServiceProvider).loadProducts();
  } catch (_) {
    return const [];
  }
});

// ─── Custom word lists ──────────────────────────────────────────────────

final wordListsProvider = NotifierProvider<WordListsNotifier, List<WordList>>(
  WordListsNotifier.new,
);

class WordListsNotifier extends Notifier<List<WordList>> {
  @override
  List<WordList> build() => ref.read(storageServiceProvider).loadLists();

  Future<void> upsert(WordList list) async {
    final idx = state.indexWhere((l) => l.id == list.id);
    final next = [...state];
    if (idx >= 0) {
      next[idx] = list;
    } else {
      next.add(list);
    }
    state = next;
    await ref.read(storageServiceProvider).saveLists(state);
  }

  Future<void> delete(String id) async {
    state = state.where((l) => l.id != id).toList();
    await ref.read(storageServiceProvider).saveLists(state);
  }
}

// ─── Settings ──────────────────────────────────────────────────────────

final selectedLevelProvider = NotifierProvider<SelectedLevelNotifier, int>(
  SelectedLevelNotifier.new,
);

class SelectedLevelNotifier extends Notifier<int> {
  @override
  int build() => ref.read(storageServiceProvider).getSelectedLevel();

  Future<void> set(int v) async {
    state = v.clamp(1, 8);
    await ref.read(storageServiceProvider).setSelectedLevel(state);
  }
}

// ─── Daily AI credits (free tier) ──────────────────────────────────────

final aiCreditsProvider = NotifierProvider<AiCreditsNotifier, int>(
  AiCreditsNotifier.new,
);

class AiCreditsNotifier extends Notifier<int> {
  @override
  int build() {
    // Re-read storage when the date rolls over so the daily credit renews
    // without a process restart.
    ref.watch(dayTickProvider);
    return ref.read(storageServiceProvider).getAiCredits();
  }

  Future<void> consume() async {
    if (state <= 0) return;
    state = state - 1;
    await ref.read(storageServiceProvider).setAiCredits(state);
  }

  Future<void> grant(int amount) async {
    state = state + amount;
    await ref.read(storageServiceProvider).setAiCredits(state);
  }
}
