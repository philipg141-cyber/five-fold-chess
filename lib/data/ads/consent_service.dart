import 'dart:async';
import 'dart:developer' as dev;
import 'dart:io' show Platform;

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Handles the two privacy prompts that must run BEFORE the first ad
/// request:
///
///   1. iOS App Tracking Transparency (ATT) — required by Apple for
///      personalised ads on iOS 14.5+. No-op on Android.
///   2. Google UMP (User Messaging Platform) consent — required for
///      EU/UK/EEA traffic by GDPR. Google handles geolocation; the
///      consent form only appears for users where it's actually
///      required.
///
/// Wire this into main.dart before MobileAds.instance.initialize().
class ConsentService {
  ConsentService._();
  static final instance = ConsentService._();

  /// Run both consent flows. Safe to call multiple times — each step
  /// short-circuits if already handled.
  Future<void> ensureConsent() async {
    await _requestAttIfIos();
    await _requestUmpConsent();
  }

  // ---- iOS ATT ---------------------------------------------------------

  Future<void> _requestAttIfIos() async {
    if (!Platform.isIOS) return;
    try {
      final status =
          await AppTrackingTransparency.trackingAuthorizationStatus;
      if (status == TrackingStatus.notDetermined) {
        // Apple recommends a small delay between app launch and the
        // prompt so the system dialog renders reliably.
        await Future<void>.delayed(const Duration(milliseconds: 400));
        await AppTrackingTransparency.requestTrackingAuthorization();
      }
    } catch (e) {
      dev.log('ATT prompt failed: $e', name: 'consent');
    }
  }

  // ---- Google UMP ------------------------------------------------------

  Future<void> _requestUmpConsent() async {
    try {
      await _updateConsentInfo();
      final formAvailable =
          await ConsentInformation.instance.isConsentFormAvailable();
      if (formAvailable) {
        await _loadAndShowFormIfRequired();
      }
    } catch (e) {
      dev.log('UMP consent flow failed: $e', name: 'consent');
    }
  }

  Future<void> _updateConsentInfo() {
    final c = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () => c.complete(),
      (err) => c.completeError(err),
    );
    return c.future;
  }

  Future<void> _loadAndShowFormIfRequired() {
    final c = Completer<void>();
    ConsentForm.loadConsentForm(
      (ConsentForm form) async {
        final status =
            await ConsentInformation.instance.getConsentStatus();
        if (status == ConsentStatus.required) {
          form.show((FormError? _) => c.complete());
        } else {
          c.complete();
        }
      },
      (FormError err) => c.completeError(err),
    );
    return c.future;
  }
}
