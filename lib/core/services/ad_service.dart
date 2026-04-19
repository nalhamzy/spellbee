import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:spellbee/core/constants/ad_ids.dart';

class AdService {
  BannerAd? _bannerAd;
  RewardedAd? _rewardedAd;
  bool _initialized = false;

  bool get initialized => _initialized;
  bool get hasRewardedAd => _rewardedAd != null;

  Future<void> initialize() async {
    if (_initialized) return;
    await MobileAds.instance.initialize();
    // Kids may use this app, target kid-safe content.
    await MobileAds.instance.updateRequestConfiguration(
      RequestConfiguration(
        maxAdContentRating: MaxAdContentRating.g,
        tagForChildDirectedTreatment: TagForChildDirectedTreatment.yes,
      ),
    );
    _initialized = true;
    _loadBanner();
    _loadRewarded();
  }

  Widget? buildBanner() {
    final ad = _bannerAd;
    if (ad == null) return null;
    return SizedBox(
      width: ad.size.width.toDouble(),
      height: ad.size.height.toDouble(),
      child: AdWidget(ad: ad),
    );
  }

  void _loadBanner() {
    _bannerAd?.dispose();
    _bannerAd = BannerAd(
      adUnitId: AdIds.bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => debugPrint('[AdService] Banner loaded'),
        onAdFailedToLoad: (ad, err) {
          debugPrint('[AdService] Banner failed: ${err.message}');
          ad.dispose();
          _bannerAd = null;
        },
      ),
    )..load();
  }

  Future<void> _loadRewarded() async {
    await RewardedAd.load(
      adUnitId: AdIds.rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) => _rewardedAd = ad,
        onAdFailedToLoad: (_) => _rewardedAd = null,
      ),
    );
  }

  Future<void> showRewardedAd({
    required void Function() onRewarded,
    void Function()? onUnavailable,
  }) async {
    if (_rewardedAd == null) {
      onUnavailable?.call();
      return;
    }
    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        _loadRewarded();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _rewardedAd = null;
        _loadRewarded();
        onUnavailable?.call();
      },
    );
    await _rewardedAd!.show(onUserEarnedReward: (_, _) => onRewarded());
  }

  void dispose() {
    _bannerAd?.dispose();
    _rewardedAd?.dispose();
  }
}
