import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:unity_levelplay_mediation/unity_levelplay_mediation.dart';

/// The ironSource (Unity LevelPlay) keys for one platform, from the LevelPlay
/// dashboard: the app key and one ad unit per format.
class AdKeys {
  const AdKeys({
    required this.appKey,
    required this.rewarded,
    required this.interstitial,
    required this.banner,
  });

  final String appKey;
  final String rewarded;
  final String interstitial;
  final String banner;

  /// Ads stay off until the app key is filled in.
  bool get isSet => appKey.isNotEmpty;
}

// From the LevelPlay dashboard (Apps → Snowflakes → Ad units). Only the
// interstitial is used in the game, so the other units are left empty.
const _androidKeys = AdKeys(
  appKey: '29e04b3dd',
  rewarded: '',
  interstitial: 'z156z75y9kapp6vg',
  banner: '',
);
const _iosKeys = AdKeys(appKey: '', rewarded: '', interstitial: '', banner: '');

/// ironSource ads: rewarded video, interstitials between screens and a banner.
///
/// Nothing is shown until [init] has succeeded; with the keys left empty the
/// game runs as before, without ads.
class Ads with LevelPlayInitListener {
  Ads._();
  static final instance = Ads._();

  /// The shortest gap between two interstitials.
  static const interstitialGap = Duration(seconds: 90);

  static AdKeys get keys => Platform.isIOS ? _iosKeys : _androidKeys;

  /// True once the SDK is up and ads may be loaded.
  final ready = ValueNotifier<bool>(false);

  LevelPlayRewardedAd? _rewarded;
  LevelPlayInterstitialAd? _interstitial;
  final _rewardedListener = _RewardedListener();
  final _interstitialListener = _InterstitialListener();
  DateTime? _lastInterstitial;

  /// True for a player who has no interstitials: set in main to "has bought
  /// anything" (see [GameState.boughtAny]); the shop promises it.
  ValueGetter<bool> noInterstitials = () => false;

  Future<void> init() async {
    if (!(Platform.isAndroid || Platform.isIOS) || !keys.isSet) return;
    try {
      final request = LevelPlayInitRequest.builder(keys.appKey).build();
      await LevelPlay.init(initRequest: request, initListener: this);
    } on PlatformException catch (e) {
      debugPrint('Ads: init failed: $e');
    }
  }

  @override
  void onInitSuccess(LevelPlayConfiguration configuration) {
    debugPrint('Ads: init ok');
    if (keys.rewarded.isNotEmpty) {
      final ad = _rewarded = LevelPlayRewardedAd(adUnitId: keys.rewarded);
      _rewardedListener.retry.load = ad.loadAd;
      ad
        ..setListener(_rewardedListener)
        ..loadAd();
    }
    if (keys.interstitial.isNotEmpty) {
      final ad = _interstitial = LevelPlayInterstitialAd(adUnitId: keys.interstitial);
      _interstitialListener.retry.load = ad.loadAd;
      ad
        ..setListener(_interstitialListener)
        ..loadAd();
    }
    ready.value = true;
  }

  @override
  void onInitFailed(LevelPlayInitError error) {
    debugPrint('Ads: init failed: $error');
  }

  /// Whether a rewarded video can be shown right now (to grey out its button).
  Future<bool> rewardedReady() async => await _rewarded?.isAdReady() ?? false;

  /// Shows a rewarded video. True when the player watched it through and
  /// should get the reward; false when there was none or it was cut short.
  Future<bool> showRewarded({String? placement}) async {
    final ad = _rewarded;
    if (ad == null || !await ad.isAdReady()) return false;
    final done = _rewardedListener.start(onEnd: () => ad.loadAd());
    await ad.showAd(placementName: placement);
    return done;
  }

  /// Shows an interstitial if one is loaded, [interstitialGap] has passed
  /// since the last and the player is not [noInterstitials]; otherwise does
  /// nothing. Completes when it is closed.
  Future<void> maybeShowInterstitial({String? placement}) async {
    final ad = _interstitial;
    if (ad == null || noInterstitials()) return;
    final last = _lastInterstitial;
    if (last != null && DateTime.now().difference(last) < interstitialGap) return;
    if (!await ad.isAdReady()) return;
    _lastInterstitial = DateTime.now();
    final closed = _interstitialListener.start(onEnd: () => ad.loadAd());
    await ad.showAd(placementName: placement);
    // Never leave the game stuck if the SDK forgets to call back.
    await closed.timeout(const Duration(minutes: 2), onTimeout: () {});
  }
}

/// Loads an ad unit again after a failed load: 30 s on, then twice as long
/// each time it fails again, up to 5 minutes; back to 30 s once one loads.
/// Without it, one load with no ad to give would leave the unit empty for
/// the rest of the session.
class _Retry {
  VoidCallback? load;
  int _fails = 0;
  Timer? _timer;

  void failed() {
    _timer?.cancel();
    final wait = math.min(30 << _fails, 300);
    _fails = math.min(_fails + 1, 4);
    _timer = Timer(Duration(seconds: wait), () => load?.call());
  }

  void loaded() {
    _timer?.cancel();
    _fails = 0;
  }
}

class _RewardedListener with LevelPlayRewardedAdListener {
  final retry = _Retry();
  Completer<bool>? _done;
  VoidCallback? _onEnd;
  bool _earned = false;

  Future<bool> start({required VoidCallback onEnd}) {
    _earned = false;
    _onEnd = onEnd;
    return (_done = Completer<bool>()).future;
  }

  void _finish(bool earned) {
    final done = _done;
    _done = null;
    if (done == null || done.isCompleted) return;
    done.complete(earned);
    _onEnd?.call();
  }

  @override
  void onAdRewarded(LevelPlayReward reward, LevelPlayAdInfo adInfo) {
    _earned = true;
    // On some networks the reward comes after the close.
    if (_done != null && _closed) _finish(true);
  }

  bool _closed = false;

  @override
  void onAdClosed(LevelPlayAdInfo adInfo) {
    _closed = true;
    // Give a late reward a moment to arrive before settling.
    Future.delayed(const Duration(milliseconds: 500), () {
      _closed = false;
      _finish(_earned);
    });
  }

  @override
  void onAdDisplayed(LevelPlayAdInfo adInfo) => _closed = false;

  @override
  void onAdDisplayFailed(LevelPlayAdError error, LevelPlayAdInfo adInfo) => _finish(false);

  @override
  void onAdLoadFailed(LevelPlayAdError error) {
    debugPrint('Ads: rewarded load failed: $error');
    retry.failed();
  }

  @override
  void onAdLoaded(LevelPlayAdInfo adInfo) => retry.loaded();

  @override
  void onAdClicked(LevelPlayAdInfo adInfo) {}

  @override
  void onAdInfoChanged(LevelPlayAdInfo adInfo) {}
}

class _InterstitialListener with LevelPlayInterstitialAdListener {
  final retry = _Retry();
  Completer<void>? _done;
  VoidCallback? _onEnd;

  Future<void> start({required VoidCallback onEnd}) {
    _onEnd = onEnd;
    return (_done = Completer<void>()).future;
  }

  void _finish() {
    final done = _done;
    _done = null;
    if (done == null || done.isCompleted) return;
    done.complete();
    _onEnd?.call();
  }

  @override
  void onAdClosed(LevelPlayAdInfo adInfo) => _finish();

  @override
  void onAdDisplayFailed(LevelPlayAdError error, LevelPlayAdInfo adInfo) => _finish();

  @override
  void onAdLoadFailed(LevelPlayAdError error) {
    debugPrint('Ads: interstitial load failed: $error');
    retry.failed();
  }

  @override
  void onAdLoaded(LevelPlayAdInfo adInfo) {
    debugPrint('Ads: interstitial loaded');
    retry.loaded();
  }

  @override
  void onAdDisplayed(LevelPlayAdInfo adInfo) => debugPrint('Ads: interstitial shown');

  @override
  void onAdClicked(LevelPlayAdInfo adInfo) {}

  @override
  void onAdInfoChanged(LevelPlayAdInfo adInfo) {}
}

/// A standard 320×50 banner. Takes no room until ads are up and a banner unit
/// is set; then holds its 50 points while the ad loads.
class AdBanner extends StatefulWidget {
  const AdBanner({super.key, this.placement});
  final String? placement;

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> with LevelPlayBannerAdViewListener {
  final _key = GlobalKey<LevelPlayBannerAdViewState>();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: Ads.instance.ready,
      builder: (context, ready, _) {
        final unit = Ads.keys.banner;
        if (!ready || unit.isEmpty) return const SizedBox.shrink();
        return SizedBox(
          width: 320,
          height: 50,
          child: LevelPlayBannerAdView(
            key: _key,
            adUnitId: unit,
            adSize: LevelPlayAdSize.BANNER,
            listener: this,
            placementName: widget.placement,
            onPlatformViewCreated: () => _key.currentState?.loadAd(),
          ),
        );
      },
    );
  }

  @override
  void onAdLoaded(LevelPlayAdInfo adInfo) {}

  @override
  void onAdLoadFailed(LevelPlayAdError error) => debugPrint('Ads: banner load failed: $error');

  @override
  void onAdDisplayed(LevelPlayAdInfo adInfo) {}

  @override
  void onAdDisplayFailed(LevelPlayAdInfo adInfo, LevelPlayAdError error) {}

  @override
  void onAdClicked(LevelPlayAdInfo adInfo) {}

  @override
  void onAdExpanded(LevelPlayAdInfo adInfo) {}

  @override
  void onAdCollapsed(LevelPlayAdInfo adInfo) {}

  @override
  void onAdLeftApplication(LevelPlayAdInfo adInfo) {}
}
