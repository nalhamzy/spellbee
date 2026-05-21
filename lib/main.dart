import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spellbee/app.dart';
import 'package:spellbee/core/data/words_catalog.dart';
import 'package:spellbee/core/models/player_stats.dart';
import 'package:spellbee/core/models/word_list.dart';
import 'package:spellbee/core/services/iap_service.dart';
import 'package:spellbee/core/services/storage_service.dart';
import 'package:spellbee/providers/providers.dart';

/// True only on phones — google_mobile_ads and in_app_purchase have no
/// desktop/web implementation and throw MissingPluginException when called.
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
  await _seedScreenshotDataIfNeeded(storage);

  final iap = IapService();
  if (_isMobile) {
    iap.initialize().catchError((_) {});
  }

  final container = ProviderContainer(
    overrides: [
      storageServiceProvider.overrideWithValue(storage),
      iapServiceProvider.overrideWithValue(iap),
    ],
  );

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
      lastDailyEpochDay:
          DateTime.now().millisecondsSinceEpoch ~/ Duration.millisecondsPerDay,
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
