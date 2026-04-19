import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spellbee/app.dart';
import 'package:spellbee/core/services/iap_service.dart';
import 'package:spellbee/core/services/storage_service.dart';
import 'package:spellbee/providers/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  final prefs = await SharedPreferences.getInstance();
  final storage = StorageService(prefs);

  final iap = IapService();
  iap.initialize().catchError((_) {});

  final container = ProviderContainer(overrides: [
    storageServiceProvider.overrideWithValue(storage),
    iapServiceProvider.overrideWithValue(iap),
  ]);

  // AdMob init — fire-and-forget.
  container.read(adServiceProvider).initialize().catchError((_) {});

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const SpellBeeApp(),
    ),
  );
}
