import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spellbee/core/data/words_catalog.dart';
import 'package:spellbee/core/models/player_stats.dart';
import 'package:spellbee/core/models/premium_state.dart';
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

final sttServiceProvider = Provider<SttService>((ref) => SttService());

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
  final epochDay =
      DateTime.now().millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;
  return allWords[epochDay % allWords.length];
});

/// Today's epoch-day integer (days since 1970-01-01).
int _todayEpochDay() =>
    DateTime.now().millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;

/// True when the user has already completed today's daily word.
final dailyWordDoneProvider = Provider<bool>((ref) {
  final stats = ref.watch(playerStatsProvider);
  return stats.lastDailyEpochDay == _todayEpochDay();
});

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
  int build() => ref.read(storageServiceProvider).getAiCredits();

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
