# iOS launch checklist

The Flutter / Dart side of the iOS build is fully wired. Everything below
needs a Mac (or a Mac CI service like Codemagic) because Apple toolchain.

## One-time setup (per Mac)

```
sudo gem install cocoapods
xcode-select --install     # if you don't have it
```

## Per-checkout setup

From the project root:

```
flutter pub get
cd ios
pod install
cd ..
```

`pod install` fetches the native iOS dependencies for AdMob, Firebase
Auth, Firestore, Cloud Functions, Stockfish, Hive, and the rest. The
first run takes 2–4 minutes; subsequent runs are seconds.

## Firebase iOS configuration  — DONE (verify in Xcode)

The iOS app is registered in Firebase under the production bundle ID
`com.fivefoldchess.app` (App ID `1:349058450896:ios:de9ac839bf64eeca1065d5`),
and `GoogleService-Info.plist` is checked in at `ios/Runner/`.
`firebase_options.dart` has been updated to match (iOS App ID + bundle
ID), so the Dart options and the plist agree.

One Xcode step remains on the Mac: open `ios/Runner.xcworkspace`, and if
`GoogleService-Info.plist` isn't already showing as a member of the
Runner target, drag it into the Runner group in the Project Navigator
and check the "Runner" target box during the drag. (If you re-run
`flutterfire configure --platforms=ios` on the Mac it will re-confirm
all of this automatically.)

## Bundle identifier  — DONE

Set to `com.fivefoldchess.app` (matching the Android applicationId) in
all six `PRODUCT_BUNDLE_IDENTIFIER` entries of
`ios/Runner.xcodeproj/project.pbxproj` (app targets =
`com.fivefoldchess.app`, test targets = `com.fivefoldchess.app.RunnerTests`).
Firebase and `firebase_options.dart` already reflect it (see above).

Still to do on the AdMob side: confirm the iOS app's Linked Store ID
(admob.google.com → Apps → iOS app → Settings) matches
`com.fivefoldchess.app`.

## Signing

You need an Apple Developer account ($99/year). In Xcode, open the
workspace, select Runner, **Signing & Capabilities**:

1. Check **Automatically manage signing**.
2. Pick your Team from the dropdown.
3. Xcode generates a development provisioning profile.

For App Store distribution, you'll create a separate distribution
provisioning profile and certificate; Xcode walks you through it.

## App icons and splash

Already configured via `flutter_launcher_icons` and
`flutter_native_splash` with `ios: true`. Run from project root:

```
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

These overwrite `ios/Runner/Assets.xcassets/AppIcon.appiconset/` and
the `LaunchImage.imageset/` with files generated from
`assets/fivefold_chess_icon.png`. Commit the generated files.

## AdMob

Live AdMob app ID is already in `ios/Runner/Info.plist` under
`GADApplicationIdentifier`. The `NSUserTrackingUsageDescription` string
is also in place — required by Apple before the App Tracking
Transparency prompt can be shown.

If you customise the ATT description text, edit the
`NSUserTrackingUsageDescription` value in `Info.plist`. Apple is
strict about this string actually describing how tracking will be used.

The `SKAdNetworkItems` block (50 identifiers from Google's official
list, for install attribution on iOS 14+) is already in `Info.plist`.
Google updates that list occasionally; refresh it from
developers.google.com/admob/ios/privacy/strategies before a major
release if you want the newest buyers. Not a review blocker.

## App Store submission

The `flutter build ipa` command produces an IPA. Upload via Transporter
(Mac App Store) or `xcrun altool`. Apple's review process typically
takes 24–48 hours for a first submission; later updates are usually
under 24 hours.

Required for first submission:

- App Store Connect listing (name, description, screenshots,
  keywords, age rating, privacy policy URL).
- Privacy nutrition labels — declare that you collect Identifiers (for
  ads) via AdMob, plus User Content (Firestore game data) and
  Identifiers (for analytics/crashlytics if you add those later).
- A privacy policy URL hosted somewhere (GitHub Pages works).

## Run locally on a Mac

```
flutter run -d "iPhone 15 Simulator"     # or any other simulator
flutter run -d <connected device id>     # once signing is set up
```

`flutter devices` lists what's available.
