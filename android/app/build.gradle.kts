import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release-signing material lives in `android/key.properties` (gitignored).
// The real file is owned by the user and is *not* in VCS. The build
// reads it via `java.util.Properties()`; if the file is absent (the
// common dev case), the `release` buildType falls back to the debug
// signingConfig so `flutter run --release` and `flutter build apk
// --debug` keep working. See `android/key.properties.example` for the
// four keys. The keystore file itself is referenced by `storeFile` and
// also gitignored.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.doit.package"
    // Bumped from flutter.compileSdkVersion (34) to 36: the
    // file_picker plugin (used by onboarding) transitively
    // pulls in flutter_plugin_android_lifecycle, whose AAR
    // metadata requires compileSdk 36+. minSdk stays at 28 (the
    // app's floor) and targetSdk still follows Flutter's
    // default — the bump is compile-time only.
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Core library desugaring is required by
        // flutter_local_notifications 17.x; without it the
        // `checkDebugAarMetadata` task fails. Set source/target to
        // 11 to match the desugar runtime (the desugar_jdk_libs
        // artifact back-ports java.time and friends to API 21+).
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    defaultConfig {
        // Application id is com.doit.package per v0.5 (rename
        // from "Streak" to "do it"). Future renames are a v0.6+
        // decision and require an ADR. The v0.5a pin test in
        // test/release_signing_test.dart asserts this exact value.
        applicationId = "com.doit.package"
        // App's floor is API 28 (Android 9) per
        // docs/v_model/requirements.md § Platform Constraints.
        // minSdk stays at 28. targetSdk follows Flutter's default
        // (currently 34); bumping it is a v0.3 decision because
        // it changes runtime behavior (notification permission
        // model, exact-alarm policy) and must be reviewed.
        minSdk = 28
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        // The release signingConfig reads the four keys from
        // `android/key.properties` when the file is present. When
        // it is absent (dev builds), the config has no keystore
        // attached, but the `buildTypes.release` block below falls
        // back to the debug signingConfig so the build still
        // succeeds. The release artifact will be debug-signed in
        // that case — which is the existing v0.1 / v0.2 behavior.
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            // v0.3 release signing. The user's keystore lives in
            // `android/key.properties` (gitignored). If that file
            // is present, the release artifact is signed with the
            // user's upload key. If it is absent, fall back to the
            // debug signingConfig so `flutter run --release` keeps
            // working for local dev.
            //
            // R8 / minify / resource-shrink is OFF for v0.3
            // (decision recorded in `docs/v_model/decision_record.md`
            // — minify-off is a v0.3 release-tier choice to keep
            // stack traces readable and avoid missing keep-rule
            // breaks in Flutter plugins). v0.4b-release-fix-2
            // (ADR-013 follow-up) pins both flags explicitly: AGP
            // defaults are version-dependent and a missing
            // explicit `false` can let R8 run, which strips
            // Room-generated classes (e.g. workmanager's
            // `WorkDatabase_Impl`) and crashes the app at
            // process start before any Dart code runs. The test
            // `test/release_signing_test.dart` pins the decision.
            isMinifyEnabled = false
            isShrinkResources = false
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        // Matches `sourceCompatibility` / `targetCompatibility` above
        // (11, for core-library desugaring). Mismatched targets
        // fail the build with "Inconsistent JVM Target Compatibility".
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Required by `isCoreLibraryDesugaringEnabled = true` above.
    // Pinned to 2.0.4; bump with `flutter pub outdated`.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}
