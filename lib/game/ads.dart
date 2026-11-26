import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'music.dart';

/// الإعلانات (AdMob)
/// هسه شغالة بأرقام التجربة الرسمية مالت Google.
/// لما تسوي حسابك: بدّل useTestAds لـ false وحط أرقامك بـ realRewarded و realInterstitial،
/// وبدّل الـ App ID بملف build_apk.yml.
class Ads {
  static const bool useTestAds = true;

  static const String _testRewarded = 'ca-app-pub-3940256099942544/5224354917';
  static const String _testInterstitial = 'ca-app-pub-3940256099942544/1033173712';
  static const String realRewarded = '';
  static const String realInterstitial = '';

  static String get _rewardedId => useTestAds || realRewarded.isEmpty ? _testRewarded : realRewarded;
  static String get _interId => useTestAds || realInterstitial.isEmpty ? _testInterstitial : realInterstitial;

  static RewardedAd? _rewarded;
  static InterstitialAd? _inter;
  static bool _ready = false;
  static int _levelsSinceInter = 0;

  /// يتغير لما إعلان المكافأة يصير جاهز، حتى الزر يطلع
  static final ValueNotifier<bool> rewardedReady = ValueNotifier(false);

  static Future<void> init() async {
    try {
      await MobileAds.instance.initialize();
      // محتوى مناسب للكل (لعبة للأطفال والشباب)
      await MobileAds.instance.updateRequestConfiguration(RequestConfiguration(maxAdContentRating: MaxAdContentRating.g));
      _ready = true;
      _loadRewarded();
      _loadInter();
    } catch (_) {
      _ready = false;
    }
  }

  static void _loadRewarded() {
    if (!_ready) return;
    try {
      RewardedAd.load(
        adUnitId: _rewardedId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            _rewarded = ad;
            rewardedReady.value = true;
          },
          onAdFailedToLoad: (e) {
            _rewarded = null;
            rewardedReady.value = false;
            Timer(const Duration(seconds: 30), _loadRewarded);
          },
        ),
      );
    } catch (_) {}
  }

  static void _loadInter() {
    if (!_ready) return;
    try {
      InterstitialAd.load(
        adUnitId: _interId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) => _inter = ad,
          onAdFailedToLoad: (e) {
            _inter = null;
            Timer(const Duration(seconds: 60), _loadInter);
          },
        ),
      );
    } catch (_) {}
  }

  /// يعرض إعلان مكافأة. onReward تنادى بس إذا اللاعب كمّل الإعلان
  static void showRewarded(VoidCallback onReward) {
    final ad = _rewarded;
    if (ad == null) return;
    _rewarded = null;
    rewardedReady.value = false;
    Music.pause();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        Music.resume();
        _loadRewarded();
      },
      onAdFailedToShowFullScreenContent: (a, e) {
        a.dispose();
        Music.resume();
        _loadRewarded();
      },
    );
    ad.show(onUserEarnedReward: (_, __) => onReward());
  }

  /// إعلان بين المراحل: مرة كل 3 مراحل
  static void betweenLevels() {
    _levelsSinceInter++;
    final ad = _inter;
    if (_levelsSinceInter < 3 || ad == null) return;
    _levelsSinceInter = 0;
    _inter = null;
    Music.pause();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        Music.resume();
        _loadInter();
      },
      onAdFailedToShowFullScreenContent: (a, e) {
        a.dispose();
        Music.resume();
        _loadInter();
      },
    );
    ad.show();
  }
}
