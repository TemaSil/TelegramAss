plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Development signing key, deliberately committed.
//
// Gradle invents a fresh debug keystore on every machine, so each CI build was
// signed with a different certificate and Android refused to install it over
// the previous one — you had to uninstall first. A fixed key makes every build
// an ordinary update.
//
// This is a DEVELOPMENT key with a known password: it must not be used to
// publish anything. A store release needs its own private keystore, kept in
// repository secrets.
val devKeystore = rootProject.file("keystore/dev.jks")

android {
    namespace = "com.telegramyou.telegram_liquid"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // flutter_local_notifications schedules against java.time, which does
        // not exist below API 26 — desugaring backports it.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.telegramyou.telegram_liquid"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // TDLib's shared library needs API 24+; Impeller wants a modern GPU
        // stack anyway.
        minSdk = maxOf(flutter.minSdkVersion, 24)
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("dev") {
            storeFile = devKeystore
            storePassword = "devdevdev"
            keyAlias = "dev"
            keyPassword = "devdevdev"
        }
    }

    buildTypes {
        // Both variants use the same fixed key, so a debug build and a release
        // build can replace one another without an uninstall.
        debug {
            signingConfig = signingConfigs.getByName("dev")
        }
        release {
            signingConfig = signingConfigs.getByName("dev")
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
