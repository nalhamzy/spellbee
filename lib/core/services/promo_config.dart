import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spellbee/core/utils/day_key.dart';

/// Remote on/off switch for the "Homework help for grown-ups" card that
/// recommends our other app, Whykeeper.
///
/// A static JSON file on the studio's GitHub Pages site carries the store
/// URLs: `{"whykeeper": {"ios": "<url or empty>", "android": "<url or empty>"}}`.
/// Until the file is published (404) or while a URL is empty the card stays
/// hidden. Privacy: one anonymous GET, no query string, no identifiers, at
/// most once per local day, no retries; the answer is kept in
/// SharedPreferences for that day only.
class PromoConfigService {
  PromoConfigService(
    this._prefs, {
    http.Client? client,
    DateTime Function()? clock,
    String? platform,
    bool? isWeb,
    Uri? source,
  }) : _client = client,
       _clock = clock ?? DateTime.now,
       _platform = platform ?? _platformName(),
       _isWeb = isWeb ?? kIsWeb,
       source = source ?? defaultSource;

  static final defaultSource = Uri.parse(
    'https://nalhamzy.github.io/spellbee/promo.json',
  );
  static const timeout = Duration(seconds: 5);
  static const _maxBytes = 4096;
  static const _kDay = 'sb.promo.day';
  static const _kUrl = 'sb.promo.whykeeper';

  /// The only hosts a store link may point to, per platform.
  static const _hosts = {'ios': 'apps.apple.com', 'android': 'play.google.com'};

  final SharedPreferences _prefs;
  final http.Client? _client;
  final DateTime Function() _clock;
  final String _platform;
  final bool _isWeb;
  final Uri source;

  Future<String?>? _inFlight;

  /// The validated Whykeeper store URL for this platform, or null (hide).
  /// Never throws.
  Future<String?> whykeeperUrl() {
    if (_isWeb || !_hosts.containsKey(_platform)) {
      return Future.value(null);
    }
    return _inFlight ??= _resolve().whenComplete(() => _inFlight = null);
  }

  Future<String?> _resolve() async {
    try {
      final today = localDayKey(_clock());
      if (_prefs.getInt(_kDay) == today) {
        return validateStoreUrl(_prefs.getString(_kUrl), _platform);
      }
      // Record the attempt first: success or failure, the next fetch is
      // tomorrow. A failure caches "hidden" for today only.
      await _prefs.setInt(_kDay, today);
      final url = await _fetch();
      await _prefs.setString(_kUrl, url ?? '');
      return url;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _fetch() async {
    final client = _client ?? http.Client();
    try {
      final response = await client.get(source).timeout(timeout);
      if (response.statusCode != 200 || response.bodyBytes.length > _maxBytes) {
        return null;
      }
      final json = jsonDecode(utf8.decode(response.bodyBytes));
      if (json is! Map) return null;
      final whykeeper = json['whykeeper'];
      if (whykeeper is! Map) return null;
      final value = whykeeper[_platform];
      return validateStoreUrl(value is String ? value : null, _platform);
    } catch (_) {
      return null;
    } finally {
      if (_client == null) client.close();
    }
  }

  /// [raw] when it is an https link whose host is exactly the platform's
  /// store, else null. No credentials, no custom port.
  static String? validateStoreUrl(String? raw, String platform) {
    final host = _hosts[platform];
    if (host == null || raw == null) return null;
    final text = raw.trim();
    final uri = Uri.tryParse(text);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host != host ||
        uri.hasPort ||
        uri.userInfo.isNotEmpty) {
      return null;
    }
    return text;
  }

  static String _platformName() => switch (defaultTargetPlatform) {
    TargetPlatform.android => 'android',
    TargetPlatform.iOS => 'ios',
    _ => 'other',
  };
}
