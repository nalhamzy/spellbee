import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';

/// SpellBee AdMob unit IDs.
///
/// Two formats only:
///   - Banner: bottom of dashboard + practice/test screens (free users).
///   - Rewarded: "Watch ad to unlock 5 bonus AI-generated words" and
///               "Watch ad to skip this word during practice".
/// No interstitials — spelling is a focused activity; interrupting mid-flow
/// breaks the kid's concentration.
class AdIds {
  AdIds._();

  // Google's official test IDs — used in debug AND when prod IDs are placeholders.
  static const _testBannerAndroid       = 'ca-app-pub-3940256099942544/6300978111';
  static const _testBannerIos           = 'ca-app-pub-3940256099942544/2934735716';
  static const _testRewardedAndroid     = 'ca-app-pub-3940256099942544/5224354917';
  static const _testRewardedIos         = 'ca-app-pub-3940256099942544/1712485313';

  // TODO(spellbee): replace with real unit IDs from apps.admob.com.
  static const _prodBannerAndroid       = 'ca-app-pub-4401199263287951/XXXXXXXXXX';
  static const _prodBannerIos           = 'ca-app-pub-4401199263287951/XXXXXXXXXX';
  static const _prodRewardedAndroid     = 'ca-app-pub-4401199263287951/XXXXXXXXXX';
  static const _prodRewardedIos         = 'ca-app-pub-4401199263287951/XXXXXXXXXX';

  static bool get _useTest =>
      kDebugMode || _prodBannerAndroid.contains('XXXXXXXXXX');

  static String get bannerAdUnitId => _useTest
      ? (Platform.isIOS ? _testBannerIos : _testBannerAndroid)
      : (Platform.isIOS ? _prodBannerIos : _prodBannerAndroid);

  static String get rewardedAdUnitId => _useTest
      ? (Platform.isIOS ? _testRewardedIos : _testRewardedAndroid)
      : (Platform.isIOS ? _prodRewardedIos : _prodRewardedAndroid);
}
