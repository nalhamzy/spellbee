import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:spellbee/core/constants/iap_ids.dart';
import 'package:spellbee/core/models/premium_state.dart';
import 'package:spellbee/core/services/storage_service.dart';

/// Server-owned store verification. No signing keys or service account secrets
/// are shipped in the binary. Offline failures never create or extend access.
class PurchaseVerificationService {
  PurchaseVerificationService(this.storage, {http.Client? client, Uri? endpoint})
    : _client = client ?? http.Client(),
      _endpoint =
          endpoint ??
          Uri.parse(
            'https://us-central1-rhyme-aa29b.cloudfunctions.net/spellbeeVerifyPurchase',
          );
  final StorageService storage;
  final http.Client _client;
  final Uri _endpoint;
  Future<void> _queue = Future<void>.value();
  void Function()? onChanged;

  Future<bool> verify(PurchaseDetails purchase) => _enqueue(
    () => _verify(
      purchase.productID,
      purchase.verificationData.source,
      purchase.verificationData.source == 'app_store'
          ? purchase.purchaseID ?? ''
          : purchase.verificationData.serverVerificationData,
    ),
  );

  /// Recheck the cached proof even when store restore omits a refunded item.
  /// Network/server failures leave the original cache untouched.
  Future<void> refresh() async {
    await _enqueue(() async {
      final cached = storage.loadPremium();
      if (!cached.canRefresh) return false;
      return _verify(
        cached.verificationProductId ?? cached.activeProductId!,
        cached.verificationSource!,
        cached.verificationCredential!,
      );
    });
  }

  Future<bool> _enqueue(Future<bool> Function() operation) {
    final result = _queue.then((_) => operation());
    _queue = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<bool> _verify(
    String productId,
    String source,
    String credential,
  ) async {
    if (credential.isEmpty) throw StateError('Purchase proof is unavailable');
    final response = await _client
        .post(
          _endpoint,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'productId': productId,
            'source': source,
            'credential': credential,
          }),
        )
        .timeout(const Duration(seconds: 55));
    if (response.statusCode != 200) {
      throw StateError('Store verification is unavailable');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final verifiedProduct = data['productId'] as String?;
    final verifiedAt = DateTime.tryParse(data['verifiedAt'] as String? ?? '');
    final expiry = DateTime.tryParse(data['expiresAt'] as String? ?? '');
    if (!IapProductIds.all.contains(verifiedProduct) ||
        verifiedAt == null ||
        data['active'] is! bool ||
        (data['active'] == true &&
            verifiedProduct != IapProductIds.premiumLifetime &&
            expiry == null)) {
      throw StateError('Invalid verification response');
    }
    final next = PremiumState(
      activeProductId: verifiedProduct,
      verifiedAt: verifiedAt,
      activatedAt: verifiedAt,
      expiresAt: expiry,
      verifiedActive: data['active'] == true,
      verificationSource: source,
      verificationCredential: credential,
      verificationProductId: productId,
    );
    final current = storage.loadPremium();
    final sameProof =
        current.verificationSource == source &&
        current.verificationCredential == credential;
    final migratingSameProduct =
        !current.canRefresh && current.activeProductId == verifiedProduct;
    // Historical restores must not overwrite a lifetime purchase or a newer,
    // still-active subscription. A revocation of the actual cached proof does.
    final replace =
        sameProof ||
        migratingSameProduct ||
        !current.isPremium ||
        (next.isPremium &&
            (next.isLifetime ||
                (!current.isLifetime &&
                    (current.expiresAt == null ||
                        (expiry != null &&
                            expiry.isAfter(current.expiresAt!))))));
    if (replace) {
      await storage.savePremium(next);
      onChanged?.call();
    }
    return next.isPremium;
  }
}
