plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.common_games.streak"
    compileSdk = flutter.compileSdkVersion
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
        // Application id pinned to com.common_games.streak per AGENTS.md.
        // Any rename is a v0.2+ decision and requires an ADR.
        applicationId = "com.common_games.streak"
        // Streak floor is API 28 (Android 9) per
        // docs/v_model/requirements.md § Platform Constraints. The
        // compile/target SDKs follow Flutter's defaults, currently 34.
        minSdk = 28
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
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
