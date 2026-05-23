import 'dart:developer' as dev;
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:hive/hive.dart';

/// Wrapper around google_mobile_ads that enforces our balanced ad
/// frequency policy:
///
///   * Banner ads are exposed via [bannerAdUnitId] and rendered by the
///     AdBanner widget on menu screens only — never during gameplay.
///
///   * Interstitials fire ONLY on the post-game screen, subject to two
///     caps (both must pass):
///       (a) at most one interstitial per 120 seconds
///       (b) at most one interstitial per 3 completed games
///     The counters are persisted to Hive so they survive app restart.
///
///   * The first game of a new session never triggers an interstitial.
///
/// ----------------------------------------------------------------
/// PRODUCTION CHECKLIST — do all of these before releasing to stores:
///
///   1. Replace the test ad unit IDs in [bannerAdUnitId] and
///      [_interstitialUnitId] with the unit IDs from your AdMob account
///      (admob.google.com → Apps → ad units). Keep the platform split.
///   2. Replace the APPLICATION_ID in `android/app/src/main/AndroidManifest.xml`
///      and `ios/Runner/Info.plist` with your AdMob app id.
///   3. Add a UMP consent flow before the first ad request — see
///      https://developers.google.com/admob/flutter/privacy
///      Required for any EU/UK traffic.
///   4. (iOS only) Add an App Tracking Transparency prompt; required by
///      Apple for personalized ads. See the same link.
///   5. Add your test device's IDFA / Advertising ID to RequestConfiguration
///      so you don't pollute live ad metrics during dev testing.
/// ----------------------------------------------------------------
class AdMobService {
  AdMobService._();
  static final instance = AdMobService._();

  static const Duration _minGap = Duration(seconds: 120);
  static const int _gameCadence = 3;
  static const Duration _retryBackoff = Duration(seconds: 30);

  Box<dynamic> get _box => Hive.box<dynamic>('app');

  InterstitialAd? _pending;
  bool _sessionFirstGame = true;
  bool _loadInFlight = false;

  Future<void> init() async {
    await _loadInterstitial();
  }

  // Google's universal TEST unit IDs. They always serve an "Ad" placeholder
  // and never bill anyone. Used in debug builds so development taps don't
  // pollute live AdMob metrics or risk an account-flag for invalid traffic.
  static const _testBannerAndroid       = 'ca-app-pub-3940256099942544/6300978111';
  static const _testBannerIos           = 'ca-app-pub-3940256099942544/2934735716';
  static const _testInterstitialAndroid = 'ca-app-pub-3940256099942544/1033173712';
  static const _testInterstitialIos     = 'ca-app-pub-3940256099942544/4411468910';

  // Live unit IDs from the Fivefold Chess AdMob account. Used in release
  // builds. To rotate or split-test: change here, no other changes needed.
  static const _liveBannerAndroid       = 'ca-app-pub-4551943137024878/2596644298';
  static const _liveBannerIos           = 'ca-app-pub-4551943137024878/5738736392';
  static const _liveInterstitialAndroid = 'ca-app-pub-4551943137024878/1228645748';
  static const _liveInterstitialIos     = 'ca-app-pub-4551943137024878/5494270376';

  /// Banner unit ID. Test in debug, live in release.
  String get bannerAdUnitId {
    if (kReleaseMode) {
      return Platform.isIOS ? _liveBannerIos : _liveBannerAndroid;
    }
    return Platform.isIOS ? _testBannerIos : _testBannerAndroid;
  }

  /// Interstitial unit ID. Test in debug, live in release.
  String get _interstitialUnitId {
    if (kReleaseMode) {
      return Platform.isIOS ? _liveInterstitialIos : _liveInterstitialAndroid;
    }
    return Platform.isIOS ? _testInterstitialIos : _testInterstitialAndroid;
  }

  /// Called by the game screen whenever a game ends. Increments the
  /// per-session game counter, then decides whether to show an
  /// interstitial based on the frequency caps above.
  Future<void> maybeShowPostGameInterstitial() async {
    final box = _box;
    final completed = (box.get('games_completed', defaultValue: 0) as int) + 1;
    await box.put('games_completed', completed);

    if (_sessionFirstGame) {
      _sessionFirstGame = false;
      return;
    }
    if (completed % _gameCadence != 0) return;

    final last = box.get('last_interstitial_ms', defaultValue: 0) as int;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - last < _minGap.inMilliseconds) return;

    final ad = _pending;
    if (ad == null) {
      // We were due for an interstitial but didn't have one ready.
      // Kick a load so we're prepared next time, then bail.
      dev.log('Interstitial not ready when due; reloading.', name: 'admob');
      await _loadInterstitial();
      return;
    }
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _pending = null;
        _loadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (ad, err) {
        dev.log('Interstitial failed to show: $err', name: 'admob');
        ad.dispose();
        _pending = null;
        _loadInterstitial();
      },
    );
    await ad.show();
    await box.put('last_interstitial_ms', now);
  }

  Future<void> _loadInterstitial() async {
    if (_loadInFlight || _pending != null) return;
    _loadInFlight = true;
    try {
      await InterstitialAd.load(
        adUnitId: _interstitialUnitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            _pending = ad;
            _loadInFlight = false;
          },
          onAdFailedToLoad: (err) {
            dev.log(
              'Interstitial load failed (code ${err.code}): ${err.message}. '
              'Retrying in ${_retryBackoff.inSeconds}s.',
              name: 'admob',
            );
            _pending = null;
            _loadInFlight = false;
            // Retry once after a delay; transient network errors are common
            // on cold start. Don't loop forever — a single retry covers
            // most real-world cases.
            Future<void>.delayed(_retryBackoff, _loadInterstitial);
          },
        ),
      );
    } catch (e) {
      dev.log('Interstitial load threw: $e', name: 'admob');
      _loadInFlight = false;
    }
  }
}
