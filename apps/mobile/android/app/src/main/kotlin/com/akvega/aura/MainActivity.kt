package com.akvega.aura

import android.content.Intent
import android.net.Uri
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
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
                    else -> result.notImplemented()
                }
            }
    }
}
