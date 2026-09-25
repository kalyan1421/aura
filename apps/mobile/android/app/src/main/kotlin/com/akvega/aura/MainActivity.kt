package com.akvega.aura

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import com.google.android.play.agesignals.AgeSignalsManagerFactory
import com.google.android.play.agesignals.AgeSignalsRequest
import com.akvega.aura.widget.AuraWidgetBridge
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// AudioServiceActivity (a FlutterActivity) shares this engine with the
// Sounds media-playback service, so lock-screen controls and background
// playback reach the Dart mixer (F15; audio_service).
class MainActivity : AudioServiceActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Home-screen widget store (F11; widget/AuraWidgetBridge.kt).
        AuraWidgetBridge.register(this, flutterEngine.dartExecutor.binaryMessenger)
        // App ↔ OS glue (lib/src/features/voice/voice_devices.dart,
        // ChannelAuraPlatform). No plugin needed for these two calls.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.akvega.aura/platform")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // Mic denied → "turn it on in Settings": this app's page.
                    "openAppSettings" -> {
                        try {
                            startActivity(
                                Intent(
                                    Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                                    Uri.fromParts("package", packageName, null),
                                ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                            )
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }
                    // Backup and device transfer are off for the whole app
                    // (AndroidManifest.xml, res/xml/data_extraction_rules.xml).
                    "excludeFromBackup" -> result.success(true)
                    // Forced update (MASVS F-6, lib/src/features/update): this
                    // install's pubspec version, as the OS knows it.
                    "appVersion" -> {
                        try {
                            val info = packageManager.getPackageInfo(packageName, 0)
                            val build =
                                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                                    info.longVersionCode
                                } else {
                                    @Suppress("DEPRECATION")
                                    info.versionCode.toLong()
                                }
                            result.success(
                                mapOf("version" to (info.versionName ?: ""), "build" to build.toString()),
                            )
                        } catch (e: Exception) {
                            result.success(null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        // Platform age signals (F8 REQ-ACC-04; lib/src/features/auth/age_signals.dart):
        // Play Age Signals answers where it applies (Brazil, Texas, …; beta) and
        // shows no UI. `read` answers {status: shared|declined|unavailable,
        // lower?, upper?} and never fails. Only used on device: never logged or sent.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.akvega.aura/age_signals")
            .setMethodCallHandler { call, result ->
                if (call.method != "read") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                try {
                    AgeSignalsManagerFactory.create(applicationContext)
                        .checkAgeSignals(AgeSignalsRequest.builder().build())
                        .addOnSuccessListener { r ->
                            val lower = r.ageLower()
                            val upper = r.ageUpper()
                            // Both null: not shared, verification required, or
                            // no signal for this person.
                            if (lower == null && upper == null) {
                                result.success(mapOf("status" to "declined"))
                            } else {
                                result.success(
                                    mapOf("status" to "shared", "lower" to lower, "upper" to upper),
                                )
                            }
                        }
                        .addOnFailureListener { result.success(mapOf("status" to "unavailable")) }
                } catch (e: Exception) {
                    result.success(mapOf("status" to "unavailable"))
                }
            }
    }
}
