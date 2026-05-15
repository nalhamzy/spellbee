import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spellbee/app.dart';
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
