package com.akvega.aura.widget

import android.content.Context
import android.os.Handler
import android.os.Looper
import androidx.work.Constraints
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequest
import androidx.work.WorkManager
import androidx.work.Worker
import androidx.work.WorkerParameters
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

/**
 * Widget background refresh (F11 "Data path": the app imports widget check-ins "on next launch or background
 * refresh, then syncs"; PRD 16-offline: the outbox drains "via WorkManager"). Enqueued by [SaveMoodAction] after
 * each widget save, it runs once a network is up and the battery isn't low:
 *
 *  - nothing unsent that a background run hasn't imported already → done, Flutter never starts;
 *  - the app's engine is alive ([AuraWidgetEnv.onPending] set) → it imports right away, as today;
 *  - otherwise a headless Flutter engine runs `widgetBackgroundMain` (lib/main.dart →
 *    lib/src/features/widget/widget_background.dart): import + push, no UI, nothing when signed out, before
 *    onboarding or under the under-13 lock. It answers `done` on `com.akvega.aura/widget_background`.
 *
 * Idempotent: the importer ignores ids it already has and acknowledges each one, so a repeat or overlapping run
 * changes nothing. Never logs what it moves.
 */
class WidgetSyncWorker(context: Context, params: WorkerParameters) : Worker(context, params) {
    private val main = Handler(Looper.getMainLooper())
    private val finished = CountDownLatch(1)

    @Volatile private var engine: FlutterEngine? = null

    override fun doWork(): Result {
        val app = applicationContext
        if (!AuraWidgetEnv.store(app).needsBackgroundImport) return Result.success()
        AuraWidgetEnv.onPending?.let {
            it()
            return Result.success()
        }
        main.post { start(app) }
        finished.await(MAX_RUN_MINUTES, TimeUnit.MINUTES)
        main.post { stopEngine() }
        // Never retried from here: anything left is imported at the next app open (or the next save's run).
        return Result.success()
    }

    override fun onStopped() {
        super.onStopped()
        finished.countDown()
    }

    private fun start(app: Context) {
        try {
            val loader = FlutterInjector.instance().flutterLoader()
            loader.startInitialization(app)
            loader.ensureInitializationCompleteAsync(app, null, main) {
                if (isStopped) {
                    finished.countDown()
                    return@ensureInitializationCompleteAsync
                }
                try {
                    val e = FlutterEngine(app) // registers the app's plugins
                    engine = e
                    AuraWidgetBridge.register(app, e.dartExecutor.binaryMessenger, notifySaves = false)
                    MethodChannel(e.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
                        if (call.method == "done") {
                            result.success(null)
                            finished.countDown()
                        } else {
                            result.notImplemented()
                        }
                    }
                    e.dartExecutor.executeDartEntrypoint(
                        DartExecutor.DartEntrypoint(loader.findAppBundlePath(), ENTRYPOINT),
                    )
                } catch (err: Exception) {
                    finished.countDown()
                }
            }
        } catch (err: Exception) {
            finished.countDown()
        }
    }

    private fun stopEngine() {
        engine?.destroy()
        engine = null
    }

    companion object {
        private const val CHANNEL = "com.akvega.aura/widget_background"
        private const val ENTRYPOINT = "widgetBackgroundMain"
        private const val UNIQUE_NAME = "aura.widget.sync"
        private const val MAX_RUN_MINUTES = 5L

        /** After a widget save: one run once online with the battery not low (appended behind a running one). */
        fun enqueue(context: Context) {
            val request = OneTimeWorkRequest.Builder(WidgetSyncWorker::class.java)
                .setConstraints(
                    Constraints.Builder()
                        .setRequiredNetworkType(NetworkType.CONNECTED)
                        .setRequiresBatteryNotLow(true)
                        .build(),
                )
                .build()
            WorkManager.getInstance(context.applicationContext)
                .enqueueUniqueWork(UNIQUE_NAME, ExistingWorkPolicy.APPEND_OR_REPLACE, request)
        }
    }
}
