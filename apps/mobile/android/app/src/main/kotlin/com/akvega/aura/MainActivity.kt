package com.akvega.aura

import android.app.ActivityManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import com.google.android.play.agesignals.AgeSignalsManagerFactory
import com.google.android.play.agesignals.AgeSignalsRequest
import com.akvega.aura.widget.AuraWidgetBridge
import com.google.android.gms.auth.blockstore.Blockstore
import com.google.android.gms.auth.blockstore.DeleteBytesRequest
import com.google.android.gms.auth.blockstore.RetrieveBytesRequest
import com.google.android.gms.auth.blockstore.StoreBytesData
import com.ryanheise.audioservice.AudioServiceFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// AudioServiceFragmentActivity (a FlutterFragmentActivity) shares this engine
// with the Sounds media-playback service, so lock-screen controls and
// background playback reach the Dart mixer (F15; audio_service). It is the
// fragment variant because Health Connect's permission request (W06, the
// `health` plugin) uses registerForActivityResult.
class MainActivity : AudioServiceFragmentActivity() {
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
                    // Avatar quality tier at launch (PRD F2 tiers, REQ-AVA-07;
                    // lib/src/core/perf/device_profile.dart): total RAM and
                    // battery saver. Read on device only; never sent.
                    "deviceProfile" -> {
                        try {
                            val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                            val mem = ActivityManager.MemoryInfo()
                            am.getMemoryInfo(mem)
                            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
                            result.success(
                                mapOf("totalRamBytes" to mem.totalMem, "powerSave" to pm.isPowerSaveMode),
                            )
                        } catch (e: Exception) {
                            result.success(null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        // The under-13 device lock, Android copy (F8 REQ-ACC-03; lib/src/features/onboarding/age_gate.dart). Keystore-
        // backed prefs are wiped on uninstall; Block Store keeps these bytes outside the app's data, so the 30-day lock
        // can come back after a reinstall (PRD `[ASSUMPTION: confirm persistence across reinstall]`, spike A8). Only
        // "blocked until <ISO date>" is stored: nothing identifying, device-only (no cloud backup). Never fails:
        // `read` answers null and writes answer false when Block Store is unavailable.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.akvega.aura/device_lock")
            .setMethodCallHandler { call, result ->
                val key = "aura.age_block_until"
                try {
                    val client = Blockstore.getClient(applicationContext)
                    when (call.method) {
                        "read" -> client
                            .retrieveBytes(RetrieveBytesRequest.Builder().setKeys(listOf(key)).build())
                            .addOnSuccessListener { r ->
                                val bytes = r.blockstoreDataMap[key]?.bytes
                                result.success(bytes?.toString(Charsets.UTF_8))
                            }
                            .addOnFailureListener { result.success(null) }
                        "write" -> {
                            val value = call.arguments as? String
                            if (value == null) {
                                result.success(false)
                            } else {
                                client
                                    .storeBytes(
                                        StoreBytesData.Builder()
                                            .setKey(key)
                                            .setBytes(value.toByteArray(Charsets.UTF_8))
                                            .setShouldBackupToCloud(false)
                                            .build(),
                                    )
                                    .addOnSuccessListener { result.success(true) }
                                    .addOnFailureListener { result.success(false) }
                            }
                        }
                        "clear" -> client
                            .deleteBytes(DeleteBytesRequest.Builder().setKeys(listOf(key)).build())
                            .addOnSuccessListener { result.success(true) }
                            .addOnFailureListener { result.success(false) }
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    result.success(if (call.method == "read") null else false)
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
