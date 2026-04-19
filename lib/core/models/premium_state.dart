import 'dart:convert';
import 'package:equatable/equatable.dart';
import 'package:spellbee/core/constants/iap_ids.dart';

class PremiumState extends Equatable {
  final String? activeProductId;
  final DateTime? activatedAt;

  const PremiumState({this.activeProductId, this.activatedAt});

  bool get isPremium => activeProductId != null;
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
