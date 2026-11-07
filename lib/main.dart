import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spellbee/app.dart';
import 'package:spellbee/core/data/words_catalog.dart';
import 'package:spellbee/core/models/player_stats.dart';
import 'package:spellbee/core/models/progression.dart';
import 'package:spellbee/core/models/word_list.dart';
import 'package:spellbee/core/services/access_refresher.dart';
import 'package:spellbee/core/services/event_logger.dart';
import 'package:spellbee/core/services/iap_service.dart';
import 'package:spellbee/core/services/purchase_verification_service.dart';
import 'package:spellbee/core/services/storage_service.dart';
import 'package:spellbee/core/utils/day_key.dart';
import 'package:spellbee/providers/providers.dart';

/// True only on phones because in_app_purchase has no desktop/web
/// implementation and throws MissingPluginException when called.
bool get _isMobile =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  final prefs = await SharedPreferences.getInstance();
  final storage = StorageService(prefs);
  // One local day boundary since 1.4.0: convert stored UTC day numbers once.
  await storage.migrateToLocalDayKeys().catchError((_) => false);
  await _seedScreenshotDataIfNeeded(storage);

  final iap = IapService(pendingStore: storage);
  final events = EventLogger.fromEnvironment();

  final container = ProviderContainer(
    // Riverpod 3's default auto-retry turns a throwing provider into a
    // loading<->error flicker loop (studio-wide rule after the Nabd
    // incident): never retry automatically.
    retry: (retryCount, error) => null,
    overrides: [
      storageServiceProvider.overrideWithValue(storage),
      iapServiceProvider.overrideWithValue(iap),
      eventLoggerProvider.overrideWithValue(events),
    ],
  );

  // The money path must exist before the purchase stream is subscribed:
  // launch-time transactions (Ask to Buy approvals, interrupted purchases,
  // restores) can arrive before any screen wires its callbacks.
  final verification = PurchaseVerificationService(storage)
    ..onChanged = () => container.invalidate(premiumProvider);
  iap.persistEntitlement = verification.verify;
  iap.refreshEntitlement = verification.refresh;
  iap.verifyPending = verification.verifyPending;
  iap.hasActiveEntitlement = () => storage.loadPremium().isPremium;
  iap.onPurchaseVerified = (id) =>
      events.log(FunnelEvent.purchaseVerified, {'product': id});
  iap.onVerificationHeld = (id) =>
      events.log(FunnelEvent.purchaseVerifyFailed, {'product': id});
  iap.onPendingChanged = () => container.invalidate(pendingPurchaseProvider);

  if (_isMobile) {
    await iap.initialize().catchError((_) {});
    final access = AccessRefresher(
      iap: iap,
      cachedPremium: storage.loadPremium,
      isAndroid: defaultTargetPlatform == TargetPlatform.android,
    );
    container.invalidate(premiumProvider);
    access.onLaunch();
    // Opted-in reminders are re-armed in the device's current time zone.
    container.read(dailyReminderServiceProvider).rescheduleIfEnabled();
    // Lifetime refunds are checked too; legacy paid users migrate through the
    // native store restore without losing their original cache on an outage.
    // Pending verifications retry on every return to the foreground.
    AppLifecycleListener(
      onResume: () {
        container.invalidate(premiumProvider);
        access.onResume();
      },
      onPause: access.onBackground,
    );
  }

  runApp(
    UncontrolledProviderScope(container: container, child: const SpellBeeApp()),
  );
}

Future<void> _seedScreenshotDataIfNeeded(StorageService storage) async {
  if (!kIsWeb || Uri.base.queryParameters['screenshot'] != '1') return;

  await storage.setSelectedLevel(3);
  await storage.saveStats(
    PlayerStats(
      totalTests: 18,
      totalWordsAsked: 180,
      totalWordsCorrect: 154,
      bestStreak: 11,
      currentStreak: 4,
      dailyStreak: 6,
      missedWordCounts: const {
        'bridge': 3,
        'giraffe': 2,
        'thunder': 2,
        'castle': 1,
      },
      listScores: const {
        'screenshot-school': ListScoreSummary(
          attempts: 3,
          lastCorrect: 7,
          lastTotal: 8,
          bestCorrect: 8,
          bestTotal: 8,
        ),
        'screenshot-bee': ListScoreSummary(
          attempts: 2,
          lastCorrect: 8,
          lastTotal: 10,
          bestCorrect: 9,
          bestTotal: 10,
        ),
      },
      lastPlayedEpochMs: DateTime.now().millisecondsSinceEpoch,
      // Yesterday, so the store shot shows the "Spell it now" call to action
      // instead of a finished card.
      lastDailyEpochDay: localDayKey() - 1,
    ),
  );
  await storage.saveProgression(
    Progression(
      honey: 215,
      badges: const {
        'first_test': 1,
        'perfect_test': 2,
        'mic_first': 3,
        'tiles_first': 4,
        'daily_3': 5,
      },
      questDay: localDayKey(),
      questProgress: const {
        'correctWords': 14,
        'finishTests': 1,
        'streakInTest': 5,
        'useMic': 3,
        'useTiles': 2,
        'readFacts': 1,
      },
      questsRewarded: const {'streak5'},
      totalMicWords: 9,
      totalTilesWords: 6,
      factsRead: 4,
    ),
  );

  final levelThree = kWordsCatalog[3] ?? const [];
  final levelFour = kWordsCatalog[4] ?? const [];
  await storage.saveLists([
    WordList(
      id: 'screenshot-school',
      name: 'School words',
      level: 3,
      words: levelThree.take(8).toList(),
      createdAt: DateTime(2026, 5, 15),
    ),
    WordList(
      id: 'screenshot-bee',
      name: 'Friday bee practice',
      level: 4,
      words: levelFour.take(10).toList(),
      createdAt: DateTime(2026, 5, 15),
    ),
  ]);
  await storage.setAiCredits(1);
}
