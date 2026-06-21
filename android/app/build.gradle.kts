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
    namespace = "com.doit"
    // Bumped from flutter.compileSdkVersion (34) to 36: the
    // file_picker plugin (used by onboarding) transitively
    // pulls in flutter_plugin_android_lifecycle, whose AAR
    // metadata requires compileSdk 36+. The minSdk was
    // bumped in lockstep (28 -> 30, see `defaultConfig` below)
    // because the only CallScreeningService API that compiles
    // against compileSdk = 36 — `CallResponse.Builder` — was
    // introduced in API 30 and the older `Call.Response.Builder`
    // was removed in API 31. targetSdk still follows Flutter's
    // default.
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
        // Application id is com.doit per v0.5 (rename from
        // "Streak" to "do it" in v0.5a). The v0.5a pin test in
        // test/release_signing_test.dart asserts this exact
        // value. The earlier v0.5a draft picked a longer
        // namespace, but `package` is a Java reserved keyword
        // and AGP rejected it. The v0.5a test guard
        // additionally asserts no remnants of the bad
        // namespace reappear; see the test for the full
        // v0.5e-fix history.
        applicationId = "com.doit"
        // App's floor is API 30 (Android 11) — bumped from
        // 28 alongside the compileSdk = 36 bump. Two related
        // constraints make API 28 untenable against the new
        // SDK:
        //   1. `CallScreeningService.CallResponse.Builder`
        //      was added in API 30; the legacy
        //      `android.telecom.Call.Response.Builder` was
        //      removed in API 31, so the modern API is the
        //      only one that compiles against compileSdk = 36
        //      AND runs at runtime on the same surface.
        //   2. Several transitive plugin AARs (file_picker,
        //      flutter_plugin_android_lifecycle) require
        //      compileSdk 36+ which, combined with the
        //      deprecation table above, leaves API 30 as the
        //      effective floor.
        // The previous floor (API 28) is a negligible slice
        // of active devices in 2026; no in-app features
        // depend on API 28/29 behavior. The home / settings
        // / onboarding / reminder flow is unchanged by this
        // bump.
        minSdk = 30
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
