import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spellbee/core/models/player_stats.dart';
import 'package:spellbee/core/models/premium_state.dart';
import 'package:spellbee/core/models/word_list.dart';
import 'package:spellbee/core/services/ad_service.dart';
import 'package:spellbee/core/services/ai_word_generator.dart';
import 'package:spellbee/core/services/iap_service.dart';
import 'package:spellbee/core/services/storage_service.dart';
import 'package:spellbee/core/services/stt_service.dart';
import 'package:spellbee/core/services/tts_service.dart';

// ─── Service providers (overridden in main.dart) ───────────────────────

final storageServiceProvider = Provider<StorageService>((ref) {
  throw UnimplementedError('Override storageServiceProvider in main.dart');
});

final iapServiceProvider = Provider<IapService>((ref) {
  throw UnimplementedError('Override iapServiceProvider in main.dart');
});

final adServiceProvider = Provider<AdService>((ref) {
  final s = AdService();
  ref.onDispose(s.dispose);
  return s;
});

final ttsServiceProvider = Provider<TtsService>((ref) {
  final s = TtsService();
  ref.onDispose(s.dispose);
  return s;
});

final sttServiceProvider = Provider<SttService>((ref) => SttService());

final aiGeneratorProvider = Provider<AiWordGenerator>((ref) => AiWordGenerator());

// ─── Tabs ───────────────────────────────────────────────────────────────

enum AppTab { home, practice, lists, stats, settings }

final tabProvider =
    NotifierProvider<TabNotifier, AppTab>(TabNotifier.new);

class TabNotifier extends Notifier<AppTab> {
  @override
  AppTab build() => AppTab.home;
  void go(AppTab t) => state = t;
}

// ─── Player stats ───────────────────────────────────────────────────────

final playerStatsProvider =
    NotifierProvider<PlayerStatsNotifier, PlayerStats>(PlayerStatsNotifier.new);

class PlayerStatsNotifier extends Notifier<PlayerStats> {
  @override
  PlayerStats build() => ref.read(storageServiceProvider).loadStats();

  Future<void> recordTestComplete({
    required int asked,
    required int correct,
    required int longestStreak,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final bestStreak =
        longestStreak > state.bestStreak ? longestStreak : state.bestStreak;
    state = state.copyWith(
      totalTests: state.totalTests + 1,
      totalWordsAsked: state.totalWordsAsked + asked,
      totalWordsCorrect: state.totalWordsCorrect + correct,
      bestStreak: bestStreak,
      currentStreak: correct == asked
          ? state.currentStreak + 1
          : 0, // reset streak if the test wasn't perfect
      lastPlayedEpochMs: now,
    );
    await ref.read(storageServiceProvider).saveStats(state);
  }
}

// ─── Premium ────────────────────────────────────────────────────────────

final premiumProvider =
    NotifierProvider<PremiumNotifier, PremiumState>(PremiumNotifier.new);

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

final isPremiumProvider = Provider<bool>(
  (ref) => ref.watch(premiumProvider).isPremium,
);

final iapProductsProvider =
    FutureProvider<List<IapProduct>>((ref) async {
  try {
    return await ref.read(iapServiceProvider).loadProducts();
  } catch (_) {
    return const [];
  }
});

// ─── Custom word lists ──────────────────────────────────────────────────

final wordListsProvider =
    NotifierProvider<WordListsNotifier, List<WordList>>(WordListsNotifier.new);

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

final selectedLevelProvider =
    NotifierProvider<SelectedLevelNotifier, int>(SelectedLevelNotifier.new);

class SelectedLevelNotifier extends Notifier<int> {
  @override
  int build() => ref.read(storageServiceProvider).getSelectedLevel();

  Future<void> set(int v) async {
    state = v.clamp(1, 8);
    await ref.read(storageServiceProvider).setSelectedLevel(state);
  }
}

// ─── Daily AI credits (free tier) ──────────────────────────────────────

final aiCreditsProvider =
    NotifierProvider<AiCreditsNotifier, int>(AiCreditsNotifier.new);

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
