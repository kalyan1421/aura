package com.akvega.aura.widget

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

/**
 * The app's side of the widget store (F11; lib/src/features/widget
 * `ChannelWidgetHost`, channel `com.akvega.aura/widget`):
 * `readPending`, `writeAcked(json)`, `publish({display, avatar})`. The
 * widget's own saves call back `pendingChanged` while the engine runs.
 * Never logs what it moves (mood ids live in these strings).
 */
object AuraWidgetBridge {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)

    fun register(context: Context, messenger: BinaryMessenger) {
        val app = context.applicationContext
        val channel = MethodChannel(messenger, "com.akvega.aura/widget")
        val prefs = SharedPrefsKeyValue(app.getSharedPreferences(AuraWidgetKeys.PREFS, Context.MODE_PRIVATE))
        val main = Handler(Looper.getMainLooper())
        AuraWidgetEnv.onPending = { main.post { channel.invokeMethod("pendingChanged", null) } }
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "readPending" -> result.success(prefs.getString(AuraWidgetKeys.PENDING))
                "writeAcked" -> {
                    prefs.putString(AuraWidgetKeys.ACKED, call.arguments as? String)
                    result.success(null)
                }
                "publish" -> {
                    val args = call.arguments as? Map<*, *>
                    prefs.putString(AuraWidgetKeys.DISPLAY, args?.get("display") as? String)
                    val file = AuraWidgetEnv.avatarFile(app)
                    val png = args?.get("avatar") as? ByteArray
                    try {
                        if (png != null) file.writeBytes(png) else file.delete()
                    } catch (e: Exception) {
                        // The widget then shows the star.
                    }
                    scope.launch { AuraWidgetEnv.refreshAll(app) }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
