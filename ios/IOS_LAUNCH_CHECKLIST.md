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

## Firebase iOS configuration

The Firebase project already has an iOS app registered (visible in
`firebase_options.dart` as `1:349058450896:ios:937d2c722138e40a1065d5`),
but the platform config file isn't checked in. Re-run flutterfire and
select iOS:

```
dart pub global activate flutterfire_cli   # if not installed
flutterfire configure --project=five-fold-chess --platforms=ios
```

This drops `GoogleService-Info.plist` into `ios/Runner/`. Open the
project once in Xcode and drag the file into the Runner group inside
the Project Navigator (the file needs to be a member of the Runner
target — Xcode handles this if you check the box during the drag).

## Bundle identifier

Currently `com.example.fivefoldChess` (the Flutter default). For App
Store submission you need a real reverse-DNS identifier you control.
In Xcode: open `ios/Runner.xcworkspace`, select the Runner project,
**Signing & Capabilities** tab, change **Bundle Identifier**.

When you change it, also update:
- The bundle ID in your Firebase iOS app config (Firebase Console →
  Project settings → Your apps → iOS app → Bundle ID), then re-run
  `flutterfire configure --platforms=ios` so the new
  `GoogleService-Info.plist` matches.
- The bundle ID for your AdMob iOS app (admob.google.com → Apps → iOS
  app → Settings → Linked store ID).

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
