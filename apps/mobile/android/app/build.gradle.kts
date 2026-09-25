plugins {
    id("com.android.application")
    // Glance home-screen widget (F11, com.akvega.aura.widget).
    id("org.jetbrains.kotlin.plugin.compose")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.akvega.aura"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // flutter_local_notifications (F4 capsule notices) needs Java 8+
        // library desugaring for its scheduling on older Android versions.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.akvega.aura"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Glance (Jetpack Compose) home-screen widget (F11).
    buildFeatures {
        compose = true
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
    // Play Age Signals (beta), read before sign-in (F8 REQ-ACC-04;
    // MainActivity "com.akvega.aura/age_signals"). Shows no UI.
    implementation("com.google.android.play:age-signals:0.0.4")
    // flutter_local_notifications (see compileOptions above).
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    // F11 home-screen widget: Jetpack Glance (a 4x2 two-tap check-in via
    // ActionCallback, 2x2 deep link). No network, no Supabase: it writes to
    // app-private shared preferences that the Flutter app imports.
    implementation("androidx.glance:glance-appwidget:1.2.0")
    // Unit tests of the widget store logic (app/src/test): the JVM needs a
    // real org.json (Android's is a stub there).
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.json:json:20250517")
}
