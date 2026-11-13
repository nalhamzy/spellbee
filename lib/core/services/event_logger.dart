import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:spellbee/core/constants/app_version.dart';

/// Funnel event names. The ingest endpoint only counts these.
class FunnelEvent {
  FunnelEvent._();

  static const paywallView = 'paywall_view';
  static const parentGatePass = 'parent_gate_pass';
  static const checkoutStart = 'checkout_start';
  static const purchaseVerified = 'purchase_verified';
  static const purchaseVerifyFailed = 'purchase_verify_failed';
  static const restoreResult = 'restore_result';
  static const reviewPromptShown = 'review_prompt_shown';
  static const reminderEnabled = 'reminder_enabled';
  static const promoOpen = 'promo_open';

  static const all = {
    paywallView,
    parentGatePass,
    checkoutStart,
    purchaseVerified,
    purchaseVerifyFailed,
    restoreResult,
    reviewPromptShown,
    reminderEnabled,
    promoOpen,
  };
}

/// Privacy-safe funnel counters, OFF unless the build sets
/// `--dart-define=EVENTS_URL=<shared studio events endpoint>`.
///
/// Each event is one anonymous POST of
/// `{app, event, props, app_version, platform, locale}`: no user, device,
/// install or purchase identifiers, no timestamps beyond arrival, no
/// batching or retry queue, nothing stored on the device. `props` carries
/// only short enum-like values (paywall source, product id, restore
/// outcome). Unset URL = every call is a no-op.
class EventLogger {
  EventLogger({
    this.endpoint,
    http.Client? client,
    String? platform,
    String? locale,
    this.appVersion = kAppVersion,
  }) : _client = client,
       platform = platform ?? _platformName(),
       locale = locale ?? _localeTag();

  /// Reads EVENTS_URL from the build. Empty or invalid means disabled.
  factory EventLogger.fromEnvironment() {
    const raw = String.fromEnvironment('EVENTS_URL');
    final uri = raw.isEmpty ? null : Uri.tryParse(raw);
    final usable = uri != null && uri.scheme == 'https' && uri.host.isNotEmpty;
    return EventLogger(endpoint: usable ? uri : null);
  }

  static const app = 'spellbee';
  static const _allowedProps = {'source', 'product', 'outcome'};
  static final _safeValue = RegExp(r'^[a-z0-9_.]{1,48}$');

  final Uri? endpoint;
  final http.Client? _client;
  final String appVersion;
  final String platform;
  final String locale;

  bool get enabled => endpoint != null;

  /// The JSON body for [event], or null when the event or a prop is not
  /// allowed. Props outside the allow-list are dropped, never sent.
  Map<String, Object>? payload(String event, [Map<String, String>? props]) {
    if (!FunnelEvent.all.contains(event)) return null;
    final safe = <String, String>{};
    props?.forEach((key, value) {
      final v = value.toLowerCase();
      if (_allowedProps.contains(key) && _safeValue.hasMatch(v)) safe[key] = v;
    });
    return {
      'app': app,
      'event': event,
      'props': safe,
      'app_version': appVersion,
      'platform': platform,
      'locale': locale,
    };
  }

  /// Fire-and-forget. Never throws, never blocks the UI.
  void log(String event, [Map<String, String>? props]) {
    final url = endpoint;
    if (url == null) return;
    final body = payload(event, props);
    if (body == null) return;
    unawaited(_send(url, body));
  }

  Future<void> _send(Uri url, Map<String, Object> body) async {
    final client = _client ?? http.Client();
    try {
      await client
          .post(
            url,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      // Analytics must never affect the app.
    } finally {
      if (_client == null) client.close();
    }
  }

  static String _platformName() {
    if (kIsWeb) return 'web';
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      _ => 'other',
    };
  }

  /// Language and region only, e.g. "en-US", "id-ID", "hi-IN".
  static String _localeTag() {
    final l = ui.PlatformDispatcher.instance.locale;
    final region = l.countryCode;
    return region == null || region.isEmpty
        ? l.languageCode
        : '${l.languageCode}-$region';
  }
}
