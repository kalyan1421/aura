import java.util.Properties

plugins {
    id("com.android.application")
    // Glance home-screen widget (F11, com.akvega.aura.widget).
    id("org.jetbrains.kotlin.plugin.compose")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing (docs/setup/android-release-signing.md).
// A release build is signed with the upload key named in android/key.properties
// (git-ignored; see android/key.properties.example). Without that file a
// release build FAILS: it never falls back to the debug key. Debug and profile
// builds are unaffected. For a throwaway local release build (e.g. to inspect
// the merged manifest) set AURA_DEBUG_SIGNED_RELEASE=1: it is debug-signed,
// logs a Gradle warning (shown with `flutter build … -v` or ./gradlew), and
// Play refuses it.
val keystorePropertiesFile: File = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.isFile) keystorePropertiesFile.inputStream().use { load(it) }
}
val releaseSigningKeys = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
val missingReleaseSigningKeys: List<String> =
    if (!keystorePropertiesFile.isFile) releaseSigningKeys
    else releaseSigningKeys.filter { keystoreProperties.getProperty(it).isNullOrBlank() }
val releaseStoreFile: File? =
    keystoreProperties.getProperty("storeFile")?.takeIf { it.isNotBlank() }?.let { rootProject.file(it) }
val allowDebugSignedRelease: Boolean =
    providers.environmentVariable("AURA_DEBUG_SIGNED_RELEASE").orNull == "1"
val releaseSigningProblem: String? = when {
    !keystorePropertiesFile.isFile ->
        "android/key.properties is missing."
    missingReleaseSigningKeys.isNotEmpty() ->
        "android/key.properties is missing: ${missingReleaseSigningKeys.joinToString()}."
    releaseStoreFile == null || !releaseStoreFile.isFile ->
        "the keystore named by storeFile in android/key.properties does not exist (paths are relative to android/)."
    else -> null
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

    signingConfigs {
        if (releaseSigningProblem == null) {
            create("release") {
                storeFile = releaseStoreFile
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = when {
                releaseSigningProblem == null -> signingConfigs.getByName("release")
                allowDebugSignedRelease -> signingConfigs.getByName("debug")
                // No signing config: the verifyReleaseSigning check below
                // fails the build before anything is packaged.
                else -> null
            }
        }
    }
}

// Fails every release variant task graph (assembleRelease, bundleRelease,
// `flutter build apk|appbundle --release`, `flutter run --release`) when the
// upload key isn't configured. Debug and profile never depend on it.
val verifyReleaseSigning by tasks.registering {
    group = "verification"
    description = "Fails a release build that has no upload key configured."
    val problem = releaseSigningProblem
    val debugSignedOk = allowDebugSignedRelease
    doLast {
        if (problem != null && !debugSignedOk) {
            throw GradleException(
                "Aura release signing is not configured: $problem\n" +
                    "Create android/key.properties from android/key.properties.example " +
                    "(see docs/setup/android-release-signing.md). Release builds never fall " +
                    "back to the debug key. Use `flutter build apk --debug` for local builds, " +
                    "or AURA_DEBUG_SIGNED_RELEASE=1 for a throwaway debug-signed release build.",
            )
        }
        if (problem != null) {
            logger.warn(
                "WARNING: AURA_DEBUG_SIGNED_RELEASE=1: this release build is signed with the DEBUG key " +
                    "($problem). Do not distribute it; Play rejects it.",
            )
        }
    }
}
tasks.matching { it.name == "preReleaseBuild" }.configureEach { dependsOn(verifyReleaseSigning) }

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
    // F11 background refresh: after a widget save, WidgetSyncWorker imports and syncs once online with the battery
    // not low, without opening the app (widget/WidgetSyncWorker.kt).
    implementation("androidx.work:work-runtime:2.10.5")
    // Unit tests of the widget store logic (app/src/test): the JVM needs a
    // real org.json (Android's is a stub there).
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.json:json:20250517")
}
