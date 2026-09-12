import 'dart:convert';
import 'package:equatable/equatable.dart';
import 'package:spellbee/core/constants/iap_ids.dart';

class PremiumState extends Equatable {
  final String? activeProductId;
  final DateTime? activatedAt;
  final DateTime? expiresAt;
  final DateTime? verifiedAt;
  final bool verifiedActive;
  final String? verificationSource;
  final String? verificationCredential;
  final String? verificationProductId;

  const PremiumState({
    this.activeProductId,
    this.activatedAt,
    this.expiresAt,
    this.verifiedAt,
    this.verifiedActive = false,
    this.verificationSource,
    this.verificationCredential,
    this.verificationProductId,
  });

  /// Old installs retain their ORIGINAL cached access while migrating through
  /// restore. These dates are never reset by a purchase/restore event.
  /// Verified subscriptions expire exactly when the store says they do.
  bool get isPremium => isPremiumAt(DateTime.now());
  bool isPremiumAt(DateTime now) {
    if (!IapProductIds.all.contains(activeProductId)) return false;
    if (verifiedAt != null) {
      if (!verifiedActive) return false;
      return isLifetime || (expiresAt != null && now.isBefore(expiresAt!));
    }
    if (isLifetime) return true;
    if (activatedAt == null) return false;
    final validity = Duration(
      days: activeProductId == IapProductIds.premiumYearly ? 370 : 35,
    );
    return now.isBefore(activatedAt!.add(validity));
  }

  bool get needsRefresh => activeProductId != null;
  bool get isLifetime => activeProductId == IapProductIds.premiumLifetime;
  bool get isSubscription =>
      IapProductIds.subscriptionIds.contains(activeProductId);
  bool get canRefresh =>
      verificationCredential != null && verificationSource != null;

  Map<String, dynamic> toJson({bool includeCredential = true}) => {
    'activeProductId': activeProductId,
    'activatedAt': activatedAt?.toIso8601String(),
    'expiresAt': expiresAt?.toIso8601String(),
    'verifiedAt': verifiedAt?.toIso8601String(),
    'verifiedActive': verifiedActive,
    'verificationSource': verificationSource,
    if (includeCredential) 'verificationCredential': verificationCredential,
    'verificationProductId': verificationProductId,
  };
  factory PremiumState.fromJson(Map<String, dynamic> j) => PremiumState(
    activeProductId: j['activeProductId'] as String?,
    activatedAt: DateTime.tryParse(j['activatedAt'] as String? ?? ''),
    expiresAt: DateTime.tryParse(j['expiresAt'] as String? ?? ''),
    verifiedAt: DateTime.tryParse(j['verifiedAt'] as String? ?? ''),
    verifiedActive: j['verifiedActive'] == true,
    verificationSource: j['verificationSource'] as String?,
    verificationCredential: j['verificationCredential'] as String?,
    verificationProductId: j['verificationProductId'] as String?,
  );
  String encode() => jsonEncode(toJson());
  factory PremiumState.decode(String raw) =>
      PremiumState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  @override
  List<Object?> get props => [
    activeProductId,
    activatedAt,
    expiresAt,
    verifiedAt,
    verifiedActive,
    verificationSource,
    verificationCredential,
    verificationProductId,
  ];
}
