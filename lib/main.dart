import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app.dart';
import 'data/ads/admob_service.dart';
import 'data/ads/consent_service.dart';
import 'data/sounds/sound_service.dart';

/// Entry point for Fivefold Chess.
///
/// Initializes Hive (for saved games and ad-frequency counters), runs
/// the privacy consent flows (iOS App Tracking Transparency + Google
/// UMP for EU/UK), then initializes the Google Mobile Ads SDK and our
/// AdMob wrapper before starting the Flutter UI.
///
/// Firebase is initialized lazily from the account / online-lobby paths
/// so cold-start stays fast for offline users.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  await Hive.openBox<dynamic>('app');
  await Hive.openBox<dynamic>('saved_games');

  // Ask the user (or rather: the OS, which then asks the user) before
  // making any ad request. ATT + UMP both no-op outside the regions
  // where they apply.
  await ConsentService.instance.ensureConsent();

  await MobileAds.instance.initialize();
  await AdMobService.instance.init();
  await SoundService.instance.init();

  runApp(const ProviderScope(child: FivefoldChessApp()));
}
