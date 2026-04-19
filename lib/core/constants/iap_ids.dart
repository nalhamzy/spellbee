/// App-namespaced product IDs — Apple team-scopes them, so generic names
/// like premium_monthly collide with other Ideal AI apps.
class IapProductIds {
  IapProductIds._();

  static const premiumMonthly  = 'spellbee_premium_monthly';  // $2.99/mo
  static const premiumYearly   = 'spellbee_premium_yearly';   // $19.99/yr (save 44%)
  static const premiumLifetime = 'spellbee_premium_lifetime'; // $39.99 one-time

  static const subscriptionIds = <String>{premiumMonthly, premiumYearly};
  static const nonConsumableIds = <String>{premiumLifetime};
  static const all = <String>{premiumMonthly, premiumYearly, premiumLifetime};
}
