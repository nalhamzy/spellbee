import 'dart:convert';
import 'dart:math' as math;

import 'package:in_app_purchase/in_app_purchase.dart';

/// The proof the verification server expects: Apple's transaction id, or the
/// Play purchase token.
String purchaseCredential(PurchaseDetails purchase) =>
    purchase.verificationData.source == 'app_store'
    ? purchase.purchaseID ?? ''
    : purchase.verificationData.serverVerificationData;

/// A store purchase the app received but our verification server has not
/// confirmed yet (outage, timeout, no network).
///
/// The native transaction is deliberately left un-completed while one of
/// these exists: on Android an unacknowledged purchase is re-delivered by
/// `queryPurchases` (and auto-refunded by Play after 3 days if it is never
/// acknowledged); on iOS StoreKit re-delivers unfinished transactions at the
/// next launch. The marker is what lets the app keep retrying in between and
/// show the parent "purchase received, confirming…" instead of an error.
class PendingVerification {
  final String productId;
  final String source;
  final String credential;
  final String? purchaseId;
  final DateTime firstSeen;
  final int attempts;
  final DateTime? lastAttempt;

  const PendingVerification({
    required this.productId,
    required this.source,
    required this.credential,
    this.purchaseId,
    required this.firstSeen,
    this.attempts = 0,
    this.lastAttempt,
  });

  /// Stable across re-deliveries: the purchase token (Play) or transaction id
  /// (App Store) does not change when the store hands the purchase back.
  String get key => keyFor(productId, credential);

  static String keyFor(String productId, String credential) =>
      '$productId:$credential';

  PendingVerification failedAttempt(DateTime at) => PendingVerification(
    productId: productId,
    source: source,
    credential: credential,
    purchaseId: purchaseId,
    firstSeen: firstSeen,
    attempts: attempts + 1,
    lastAttempt: at,
  );

  Map<String, dynamic> toJson() => {
    'productId': productId,
    'source': source,
    'credential': credential,
    'purchaseId': purchaseId,
    'firstSeen': firstSeen.toUtc().toIso8601String(),
    'attempts': attempts,
    'lastAttempt': lastAttempt?.toUtc().toIso8601String(),
  };

  static PendingVerification? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final productId = raw['productId'];
    final source = raw['source'];
    final credential = raw['credential'];
    final firstSeen = DateTime.tryParse(raw['firstSeen'] as String? ?? '');
    if (productId is! String ||
        source is! String ||
        credential is! String ||
        credential.isEmpty ||
        firstSeen == null) {
      return null;
    }
    return PendingVerification(
      productId: productId,
      source: source,
      credential: credential,
      purchaseId: raw['purchaseId'] as String?,
      firstSeen: firstSeen,
      attempts: (raw['attempts'] as num?)?.toInt() ?? 0,
      lastAttempt: DateTime.tryParse(raw['lastAttempt'] as String? ?? ''),
    );
  }

  static String encodeAll(List<PendingVerification> items) =>
      jsonEncode(items.map((p) => p.toJson()).toList());

  /// Unreadable entries are dropped one by one; a corrupt blob yields none.
  static List<PendingVerification> decodeAll(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw);
      if (list is! List) return const [];
      return list
          .map(PendingVerification.fromJson)
          .whereType<PendingVerification>()
          .toList();
    } catch (_) {
      return const [];
    }
  }
}

/// Retry spacing for verification. Short at first (a blip), then backing off
/// so a real outage costs one request every half hour per foregrounded app,
/// well inside the server's 120 requests/IP/hour quota.
class VerificationBackoff {
  VerificationBackoff._();

  static const steps = <Duration>[
    Duration(seconds: 30),
    Duration(minutes: 1),
    Duration(minutes: 2),
    Duration(minutes: 5),
    Duration(minutes: 10),
    Duration(minutes: 20),
    Duration(minutes: 30),
  ];

  /// Launch / resume retries skip the backoff, but never twice in this window.
  static const minimumGap = Duration(seconds: 10);

  /// Play auto-refunds unacknowledged purchases after 3 days; after a week a
  /// marker can only be stale (refunded, or verified on another path).
  static const maxAge = Duration(days: 7);

  static Duration delayAfter(int attempts) => attempts <= 0
      ? Duration.zero
      : steps[math.min(attempts - 1, steps.length - 1)];

  static DateTime nextAttemptAt(PendingVerification p) =>
      (p.lastAttempt ?? p.firstSeen).add(delayAfter(p.attempts));

  static bool isDue(PendingVerification p, DateTime now, {bool force = false}) {
    if (force) {
      final last = p.lastAttempt;
      return last == null || now.difference(last) >= minimumGap;
    }
    return !now.isBefore(nextAttemptAt(p));
  }

  static bool isExpired(PendingVerification p, DateTime now) =>
      now.difference(p.firstSeen) > maxAge;
}

/// Where pending markers live. [StorageService] persists them in
/// SharedPreferences; tests use [InMemoryPendingVerificationStore].
abstract class PendingVerificationStore {
  List<PendingVerification> loadPendingVerifications();
  Future<void> savePendingVerifications(List<PendingVerification> items);
}

class InMemoryPendingVerificationStore implements PendingVerificationStore {
  List<PendingVerification> _items = const [];

  @override
  List<PendingVerification> loadPendingVerifications() => List.of(_items);

  @override
  Future<void> savePendingVerifications(List<PendingVerification> items) async {
    _items = List.unmodifiable(items);
  }
}
