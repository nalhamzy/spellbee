import 'dart:convert';
import 'package:equatable/equatable.dart';
import 'package:spellbee/core/constants/iap_ids.dart';

class PremiumState extends Equatable {
  final String? activeProductId;
  final DateTime? activatedAt;

  const PremiumState({this.activeProductId, this.activatedAt});

  /// How long a locally-stored subscription entitlement stays valid without
  /// being refreshed by a store event (purchase/restore). The app has no
  /// server-side receipt validation, so this window — the billing period
  /// plus a generous offline grace — is what stops a cancelled $4.99
  /// monthly from being premium forever. A silent restore on launch renews
  /// [activatedAt] for anyone still subscribed.
  static const _monthlyValidity = Duration(days: 35);
  static const _yearlyValidity = Duration(days: 370);

  bool get isPremium {
    if (activeProductId == null) return false;
    if (isLifetime) return true;
    final at = activatedAt;
    if (at == null) return false;
    final validity = activeProductId == IapProductIds.premiumYearly
        ? _yearlyValidity
        : _monthlyValidity;
    return DateTime.now().difference(at) <= validity;
  }

  /// True when a subscription entitlement exists but is past its local
  /// validity window — the cue to attempt a silent restore.
  bool get needsRefresh => isSubscription && !isPremium;

  bool get isLifetime =>
      activeProductId == IapProductIds.premiumLifetime;
  bool get isSubscription =>
      activeProductId == IapProductIds.premiumMonthly ||
      activeProductId == IapProductIds.premiumYearly;

  PremiumState copyWith({String? activeProductId, DateTime? activatedAt}) =>
      PremiumState(
        activeProductId: activeProductId ?? this.activeProductId,
        activatedAt: activatedAt ?? this.activatedAt,
      );

  Map<String, dynamic> toJson() => {
        'activeProductId': activeProductId,
        'activatedAt': activatedAt?.toIso8601String(),
      };

  factory PremiumState.fromJson(Map<String, dynamic> j) => PremiumState(
        activeProductId: j['activeProductId'] as String?,
        activatedAt: j['activatedAt'] == null
            ? null
            : DateTime.tryParse(j['activatedAt'] as String),
      );

  String encode() => jsonEncode(toJson());
  factory PremiumState.decode(String raw) =>
      PremiumState.fromJson(jsonDecode(raw) as Map<String, dynamic>);

  @override
  List<Object?> get props => [activeProductId, activatedAt];
}
