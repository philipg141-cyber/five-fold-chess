# Android release signing setup

This is a one-time setup. Once your release keystore exists and
`key.properties` is filled in, every `flutter build appbundle --release`
will be signed correctly for Play Store upload.

## 1. Generate the upload keystore

From the project root, in PowerShell:

```
keytool -genkey -v -keystore android\app\upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

`keytool` ships with the JDK, which Flutter installs. If `keytool` isn't
on PATH, find it under `C:\Program Files\Android\Android Studio\jbr\bin\`
(Android Studio bundles a JDK with Flutter).

Answer the prompts:

- **Keystore password** — pick a strong password and write it down. Save
  it in your password manager. **If you lose this, you cannot ship app
  updates** — Play Store requires the same upload key for every version.
- **First and last name** — your name or company name.
- **Organisational unit / organization / city / state / country code** —
  fill in real values; they're embedded in the certificate.
- **Key password** — when prompted "Enter key password for `<upload>`",
  press Enter to use the same password as the keystore (recommended for
  simplicity).

The file `android/app/upload-keystore.jks` now exists. **It is gitignored —
do not commit it.** Keep a backup somewhere offline (USB stick, encrypted
cloud folder).

## 2. Create `android/key.properties`

Copy `key.properties.template` to `key.properties` (no `.template`):

```
copy android\key.properties.template android\key.properties
```

Edit `android/key.properties` and fill in:

```
storeFile=/full/absolute/path/to/android/app/upload-keystore.jks
storePassword=<the password you just set>
keyAlias=upload
keyPassword=<same as storePassword unless you set a different one>
```

**Use a forward-slash path** even on Windows — Gradle prefers it. For a
project at `C:\Users\pgorm\Documents\GitHub\fivefold_chess`, the
`storeFile` line should be:

```
storeFile=C:/Users/pgorm/Documents/GitHub/fivefold_chess/android/app/upload-keystore.jks
```

`key.properties` is also gitignored.

## 3. Verify the build is signed

```
flutter build appbundle --release
```

Should produce `build/app/outputs/bundle/release/app-release.aab`. To
confirm it's signed with your upload key (and not the debug key), run:

```
keytool -printcert -jarfile build\app\outputs\bundle\release\app-release.aab
```

The owner/issuer field should show the name you entered when generating
the keystore — not "Android Debug, O=Android, C=US".

## 4. Upload to Play Console

The first time you upload an AAB to Play Console, you'll be prompted to
opt into Google Play App Signing. Accept it — Google then manages the
final app-signing key, while you keep using your upload key for every
upload. This is the recommended setup; it lets Google rotate signing
keys for you and protects against catastrophic key loss.

## What if I lose the upload key?

Google has a recovery flow: Play Console → App integrity → Reset upload
key → upload a brand-new keystore + a signed reset proof. Keep your
backup safe so you don't have to use this.
