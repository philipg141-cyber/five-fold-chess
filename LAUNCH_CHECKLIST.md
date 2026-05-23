# Fivefold Chess — Launch Checklist

End-to-end runbook for getting the app from "works on my phone" to "live
on the Play Store and App Store." Items are grouped by what's blocking
what; do them in order top-to-bottom.

The Firebase backend deploy is the only thing that needs your terminal
right now. Everything else is on the path to actual store submission.

---

## A. Backend deploy (do now — 10 minutes)

### A.1 — Firestore rules and indexes (free, Spark-tier OK)

From the project root in PowerShell:

```
firebase deploy --only firestore:rules,firestore:indexes
```

Activates `firestore.rules` and `firestore.indexes.json` on your
`five-fold-chess` project. After this:

- `/games/{gameId}` is only readable/writable by the two listed players
- History is enforced append-only (clients can't rewrite past moves)
- `/users/{uid}` is owner-only writes; anyone signed in can read
- `/queue/{variant}/waiting/{uid}` is owner-managed waiter slots

### A.2 — Cloud Functions (Blaze tier required, you have it)

```
cd functions
npm install
cd ..
firebase deploy --only functions
```

First deploy takes 2–4 minutes (provisions Cloud Build). Activates two
functions:

- **`submitMove`** — HTTPS callable. Validates auth, ownership, turn order,
  and in-bounds squares before appending each move. The Flutter client
  already prefers this callable and falls back to direct Firestore writes
  when it isn't deployed, so this is a transparent upgrade with no client
  changes needed.
- **`finalizeGame`** — Firestore trigger on `/games/{id}`. Fires when the
  `result` field flips from null to "white" / "black" / "draw" and runs
  the standard ELO calculation (K=24) on both players.

### A.3 — Verify

In Firebase Console:

- **Build → Firestore → Rules** — should show your rules timestamp under
  "Last published"
- **Build → Functions** — should list `submitMove` and `finalizeGame` as
  v2 functions in your region (default `us-central1`)

To test end-to-end:

1. Sign up two test accounts on two devices (or one device + the emulator)
2. Both tap **Play Online** → pick the same variant
3. Watch the Firebase Console's Firestore tab — you should see a
   `games/{id}` document appear with both UIDs
4. Make a move on each device; the other should reflect within a second
5. Force a checkmate; check the Firestore docs for both users — their
   ELO should have updated automatically

---

## B. Mandatory before Play Store submission

### B.1 — Change the application ID

`com.example.fivefold_chess` is rejected by Play Console. Pick a real
reverse-DNS namespace you control. Suggestions: `com.fivefoldchess.app`
or `app.fivefoldchess.android`.

**This change requires three coordinated updates** because the package
name is referenced in Firebase, AdMob, and your Gradle config:

1. **Edit `android/app/build.gradle.kts`** — change both `namespace` and
   `applicationId` to the new value.
2. **Edit `android/app/src/main/kotlin/com/example/fivefold_chess/MainActivity.kt`** —
   move the file to a folder matching the new package, and update the
   `package com.example.fivefold_chess` declaration at the top.
3. **Re-register with Firebase**: Firebase Console → Project settings →
   Add app → Android → enter the new package name → download the new
   `google-services.json` → replace `android/app/google-services.json`.
   Then re-run `flutterfire configure --project=five-fold-chess` to
   refresh `lib/firebase_options.dart`.
4. **Re-register with AdMob**: admob.google.com → Apps → your Android
   app → App settings → "Linked Store ID" — update to match the new
   package name.

After all four, `flutter clean && flutter run` should still launch and
sign in. If Firebase init fails, you missed step 3.

### B.2 — Generate a real upload keystore

Follow `android/KEY_SETUP.md`. You need:

- `android/app/upload-keystore.jks` (gitignored — keep an offline backup)
- `android/key.properties` (gitignored — fill in from the template)

Verify with `flutter build appbundle --release` and then
`keytool -printcert -jarfile build\app\outputs\bundle\release\app-release.aab` —
the owner field should be your name, not "Android Debug".

### B.3 — Bump version

In `pubspec.yaml`:

```
version: 1.0.0+1
```

The format is `<semver>+<buildNumber>`. Play Store's "version code"
comes from the `+N` suffix and must increase with every upload.

### B.4 — AdMob — UMP consent flow (required for EU/UK traffic)

The code is wired (see `lib/data/ads/consent_service.dart`), but the UMP
form configuration lives in your AdMob account:

- admob.google.com → **Privacy & messaging** → **GDPR** → **Create message**
- Pick "TCF v2.2" template, accept all the defaults
- Publish

Without this step, `ConsentInformation.isConsentFormAvailable()` returns
false and the prompt never appears. Once published, EU users see it on
first launch automatically.

### B.5 — Live AdMob unit IDs sanity check

Already wired to your live IDs in `lib/data/ads/admob_service.dart`. Verify:

- admob.google.com → **Apps** → Fivefold Chess (Android) → **App settings**
  — confirm the App ID matches what's in `AndroidManifest.xml`
  (`ca-app-pub-4551943137024878~2802634219`)
- The four live unit IDs (banner + interstitial × Android + iOS) are
  in the `_liveBannerAndroid` etc. constants. Match them against your
  AdMob unit pages.
- Add your test device's advertising ID to AdMob's test devices list
  (admob.google.com → Settings → Test devices) so your own taps don't
  generate invalid traffic during release-build testing.

### B.6 — Privacy policy URL

Both stores require a public URL. Cheap options:

- **GitHub Pages** — push a `privacy.html` to a public repo, enable Pages
  in Settings, the URL is `https://<you>.github.io/<repo>/privacy.html`
- **Notion public page** — Share → Publish to web; the URL works as long
  as you don't unpublish it
- **A simple HTML on a domain you own**

Content needs to disclose:

- AdMob (advertising IDs, served ads, Google's DoubleClick cookies)
- Firebase Authentication (email, displayName, anonymous IDs)
- Firestore (game state, ELO, username — disclose what you collect)
- App Tracking Transparency (iOS — what tracking is for; matches your
  `NSUserTrackingUsageDescription` in `Info.plist`)
- Children-under-13 statement (Play Store family policy if you mark the
  app for "everyone"; you almost certainly want to disallow under-13)

There are templates online — search "AdMob privacy policy template" and
"Firestore privacy policy template" and combine.

---

## C. Play Store submission

### C.1 — Build the AAB

```
flutter build appbundle --release
```

Output: `build/app/outputs/bundle/release/app-release.aab` (typically
20–40 MB). This is what you upload, NOT an APK.

### C.2 — Play Console listing

[play.google.com/console](https://play.google.com/console) — sign up if
you haven't ($25 one-time fee).

- **Create app** → name "Fivefold Chess", default language English (US),
  category Game → Board, free, contains ads = yes (you have AdMob).
- **Main store listing**:
  - Short description (80 chars): "Five chess variants in one app — Classic,
    Long, Silent, Reverse, Barbarian." (78 chars, fits.)
  - Full description (4000 chars): write 200-400 words explaining each
    variant, the AI difficulty levels, online play.
  - App icon (512×512 PNG) — `assets/fivefold_chess_icon.png` works.
  - Feature graphic (1024×500 PNG) — needs separate creation.
  - Phone screenshots: 4-8 PNG/JPG, each 1080×1920 or 1080×2400 portrait.
    Capture from emulator: `flutter run --release` then take screenshots
    via the emulator's camera button.
- **App content**:
  - Privacy policy URL (from step B.6)
  - App access — note that online play requires sign-in (test creds for
    Google's reviewer)
  - Ads — declare "Yes, my app contains ads"
  - Content rating — fill out the IARC questionnaire; chess gets
    "Everyone" with "ad-supported" disclosure
  - Target audience and content — exclude under-13 unless you really want
    to deal with COPPA compliance
  - News app — no
  - Data safety form — disclose: AdvertisingId (for ads), email (for auth),
    User IDs (for accounts), App interactions (for game state)

### C.3 — Internal testing track

Don't go straight to production. Set up an internal testing track:

- **Testing → Internal testing** → Create release → upload your AAB
- Add testers (up to 100, by Gmail address — your own email + a couple
  friends)
- Roll out — Google takes ~30 minutes to process, then testers get an
  opt-in URL. They install via Play Store, you all play games.
- Once everything works, promote the same release to **Production**.

First-time submissions can take up to 7 days for Play review. Updates
are usually under 24 hours.

---

## D. App Store submission

This entire section requires a Mac. Detailed runbook in
`ios/IOS_LAUNCH_CHECKLIST.md`. Summary:

- Apple Developer account ($99/year)
- On the Mac: `flutterfire configure --platforms=ios` to drop
  `GoogleService-Info.plist` into `ios/Runner/`
- Open `ios/Runner.xcworkspace` in Xcode, set Bundle Identifier to match
  the new applicationId from B.1, set up signing
- `cd ios && pod install`
- `flutter build ipa --release`
- Upload via Transporter or `xcrun altool`
- App Store Connect listing (parallel to Play Console listing — name,
  description, screenshots, privacy data declarations)
- TestFlight internal testing first, then submit for review
- Apple review typically 24–48 hours

---

## E. Post-launch

- **Crash monitoring** — wire up Firebase Crashlytics (free, ~30 min
  to add the package and call `FirebaseCrashlytics.instance.recordError`
  in your top-level error zone).
- **Analytics** — Firebase Analytics is auto-enabled once
  `firebase_core` is initialized; you'll see opens, sessions, etc. in
  the Console. Add custom events for "game_started" / "game_finished"
  to track engagement.
- **App update prompts** — `package_info_plus` + a Firestore-backed
  "minimum required version" doc lets you force-update users on a major
  release. Optional v1.

---

## What's NOT done that you may want before launch

These are noted in the codebase as TODOs but aren't shipped:

- **TypeScript port of the rule engines** — `submitMove` does
  structural validation only, not chess-rules validation. Cheaters can't
  win against honest opponents (the other client rejects the bogus move
  and they desync), but it's a real gap. Plan ~1-2 days of work, see
  `functions/README.md` for the porting plan.
- **iOS — full Mac-side setup** — see `ios/IOS_LAUNCH_CHECKLIST.md`.
- **R8 minification on Android release builds** — currently disabled to
  avoid breaking native plugins (Stockfish, Firebase, AdMob). Adds about
  2-3 MB to your AAB. Enable later with proper ProGuard rules.
- **Crashlytics** — see Section E above.
- **Force-update mechanism** — see Section E above.
