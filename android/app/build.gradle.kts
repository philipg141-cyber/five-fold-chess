import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Read release-signing credentials from `android/key.properties` (which is
// gitignored). See android/KEY_SETUP.md for how to generate the keystore
// and populate this file. If the file is missing, release builds fall back
// to the debug keystore so `flutter run` keeps working — but Play Store
// will reject debug-signed AABs.
val keyPropertiesFile = rootProject.file("key.properties")
val keyProperties = Properties()
if (keyPropertiesFile.exists()) {
    keyProperties.load(FileInputStream(keyPropertiesFile))
}
val hasReleaseSigning =
    keyProperties.getProperty("storeFile") != null &&
    keyProperties.getProperty("storePassword") != null &&
    keyProperties.getProperty("keyAlias") != null &&
    keyProperties.getProperty("keyPassword") != null

android {
    namespace = "com.fivefoldchess.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.fivefoldchess.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = file(keyProperties.getProperty("storeFile"))
                storePassword = keyProperties.getProperty("storePassword")
                keyAlias = keyProperties.getProperty("keyAlias")
                keyPassword = keyProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseSigning)
                signingConfigs.getByName("release")
            else
                signingConfigs.getByName("debug")
            // R8 minification is OFF for v1 — Flutter's Dart-side
            // tree-shaking already cuts most of the dead code, and
            // turning on Kotlin/Java minification without complete
            // ProGuard rules can break Firebase, AdMob, or the
            // Stockfish native plugin at runtime. Enable later
            // (with a thorough QA pass) for slightly smaller AABs.
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}
