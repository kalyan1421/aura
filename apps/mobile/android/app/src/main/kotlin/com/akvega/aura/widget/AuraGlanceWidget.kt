package com.akvega.aura.widget

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.longPreferencesKey
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.Image
import androidx.glance.ImageProvider
import androidx.glance.LocalContext
import androidx.glance.LocalSize
import androidx.glance.action.ActionParameters
import androidx.glance.action.actionParametersOf
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetManager
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.SizeMode
import androidx.glance.appwidget.action.ActionCallback
import androidx.glance.appwidget.action.actionRunCallback
import androidx.glance.appwidget.action.actionStartActivity
import androidx.glance.appwidget.cornerRadius
import androidx.glance.appwidget.provideContent
import androidx.glance.appwidget.state.updateAppWidgetState
import androidx.glance.background
import androidx.glance.currentState
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.Column
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxHeight
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.layout.size
import androidx.glance.layout.width
import androidx.glance.semantics.contentDescription
import androidx.glance.semantics.semantics
import androidx.glance.state.GlanceStateDefinition
import androidx.glance.state.PreferencesGlanceStateDefinition
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextAlign
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider
import com.akvega.aura.R
import java.io.File
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import java.time.Instant
import java.time.ZoneId

// Aura home-screen widget on Android (F11, Jetpack Glance).
// * 4x2 and wider: tap a group, then one of its 4 moods, saved through an
//   ActionCallback without launching the app (REQ-WID-01), plus "Need help".
// * 2x2: the avatar and "How are you feeling?"; a tap opens aura://checkin.
// * Discreet (Settings): a plain star, no "Aura", no mood words.
// The widget writes to app-private shared preferences only; the Flutter app
// imports on launch/resume, or at once when its engine is running
// (AuraWidgetBridge). Copy comes from the app in its language; the
// res/values*/widget_strings.xml fallbacks are generated from the ARB files.

class SharedPrefsKeyValue(private val prefs: SharedPreferences) : WidgetKeyValue {
    override fun getString(key: String): String? = prefs.getString(key, null)
    override fun putString(key: String, value: String?) {
        prefs.edit().apply { if (value == null) remove(key) else putString(key, value) }.commit()
    }
}

object AuraWidgetEnv {
    fun store(context: Context) = AuraWidgetStore(
        SharedPrefsKeyValue(context.getSharedPreferences(AuraWidgetKeys.PREFS, Context.MODE_PRIVATE)),
    )

    fun avatarFile(context: Context) = File(context.filesDir, AuraWidgetKeys.AVATAR_FILE)

    fun avatar(context: Context): Bitmap? = try {
        avatarFile(context).takeIf { it.exists() }?.let { BitmapFactory.decodeFile(it.path) }
    } catch (e: Exception) {
        null
    }

    fun link(context: Context, host: String) =
        Intent(Intent.ACTION_VIEW, Uri.parse("aura://$host")).setPackage(context.packageName)

    private val tick = longPreferencesKey("tick")

    /** Redraws every Aura widget (after a save, a publish, 04:00). */
    suspend fun refreshAll(context: Context) {
        val ids = GlanceAppWidgetManager(context).getGlanceIds(AuraGlanceWidget::class.java)
        for (id in ids) {
            updateAppWidgetState(context, PreferencesGlanceStateDefinition, id) { prefs ->
                prefs.toMutablePreferences().apply { this[tick] = System.currentTimeMillis() }
            }
            AuraGlanceWidget().update(context, id)
        }
        scheduleRedraw(context)
    }

    /** An inexact alarm at the next 04:00 (new Aura day) or when a save fades. */
    fun scheduleRedraw(context: Context) {
        val now = Instant.now()
        val rollover = AuraDay.nextRollover(now, ZoneId.systemDefault()).toEpochMilli()
        val fade = store(context).nextFade(now)
        val at = if (fade != null && fade < rollover) fade else rollover
        val intent = Intent(context, AuraWidgetReceiver::class.java).setAction(AuraWidgetReceiver.ACTION_REDRAW)
        val pending = PendingIntent.getBroadcast(
            context, 0, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val alarms = context.getSystemService(AlarmManager::class.java) ?: return
        alarms.set(AlarmManager.RTC, at, pending)
    }

    /** Set by the Flutter bridge while its engine runs: import right away. */
    @Volatile var onPending: (() -> Unit)? = null
}

private object Palette {
    val sky = Color(0xFF0A0C1D)
    val surface = Color(0xFF151935)
    val text = Color(0xFFF2F0FF)
    val textSoft = Color(0xFFBDB9E0)
    val starlight = Color(0xFFF7E6B5)

    fun accent(q: String) = when (q) {
        "sunrise" -> Color(0xFFF3BE67)
        "rain" -> Color(0xFF5ACBBE)
        "moonlight" -> Color(0xFFAFC3F0)
        else -> Color(0xFFAE93FA)
    }

    fun deep(q: String) = when (q) {
        "sunrise" -> Color(0xFF2E2213)
        "rain" -> Color(0xFF0E2A2B)
        "moonlight" -> Color(0xFF161F3A)
        else -> Color(0xFF221A43)
    }

    /** Lighthouse, raindrop, moon, sun: a group is never told by colour alone. */
    fun glyph(q: String) = when (q) {
        "sunrise" -> R.drawable.ic_widget_sunrise
        "rain" -> R.drawable.ic_widget_rain
        "moonlight" -> R.drawable.ic_widget_moonlight
        else -> R.drawable.ic_widget_storm
    }

    /** App grid order: more energy on top, unpleasant on the left. */
    val gridOrder = listOf("storm", "sunrise", "rain", "moonlight")
}

class AuraGlanceWidget : GlanceAppWidget() {
    companion object {
        private val SMALL = DpSize(110.dp, 110.dp)
        private val WIDE = DpSize(250.dp, 110.dp)
    }

    override val sizeMode = SizeMode.Responsive(setOf(SMALL, WIDE))
    override val stateDefinition: GlanceStateDefinition<*> = PreferencesGlanceStateDefinition

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        provideContent {
            // Read so a refresh (tick) recomposes with the store's new state.
            currentState<Preferences>()
            val ctx = LocalContext.current
            val store = AuraWidgetEnv.store(ctx)
            val state = store.state(Instant.now(), ZoneId.systemDefault())
            val avatar = if (state.display?.avatar == true && state.phase != WidgetState.Phase.DISCREET) {
                AuraWidgetEnv.avatar(ctx)
            } else {
                null
            }
            Content(state, avatar)
        }
    }

    @Composable
    private fun Content(state: WidgetState, avatar: Bitmap?) {
        val ctx = LocalContext.current
        val wide = LocalSize.current.width >= WIDE.width
        val interactive = wide && (state.phase == WidgetState.Phase.QUADRANTS || state.phase == WidgetState.Phase.MOODS)
        Box(
            modifier = GlanceModifier.fillMaxSize().background(Palette.surface).cornerRadius(20.dp)
                .padding(10.dp)
                .let { if (interactive) it else it.clickable(actionStartActivity(AuraWidgetEnv.link(ctx, "checkin"))) },
        ) {
            if (interactive) {
                Row(modifier = GlanceModifier.fillMaxSize(), verticalAlignment = Alignment.CenterVertically) {
                    Summary(state, avatar, modifier = GlanceModifier.defaultWeight().fillMaxHeight())
                    Spacer(GlanceModifier.width(8.dp))
                    Picker(state, modifier = GlanceModifier.width(170.dp).fillMaxHeight())
                }
            } else {
                Small(state, avatar)
            }
        }
    }

    @Composable
    private fun Mark(avatar: Bitmap?, size: Int) {
        if (avatar != null) {
            Image(ImageProvider(avatar), contentDescription = null, modifier = GlanceModifier.size(size.dp))
        } else {
            Image(
                ImageProvider(R.drawable.ic_widget_star), contentDescription = null,
                modifier = GlanceModifier.size((size / 2).dp),
            )
        }
    }

    @Composable
    private fun Small(state: WidgetState, avatar: Bitmap?) {
        val ctx = LocalContext.current
        val line = when (state.phase) {
            WidgetState.Phase.NOT_READY -> state.text("openApp", ctx.getString(R.string.widget_openApp))
            WidgetState.Phase.DISCREET ->
                if (state.checkedInToday) state.text("doneToday", ctx.getString(R.string.widget_doneToday))
                else state.text("checkIn", ctx.getString(R.string.widget_checkIn))
            else -> state.savedText
                ?: if (state.checkedInToday) state.text("doneToday", ctx.getString(R.string.widget_doneToday))
                else state.text("prompt", ctx.getString(R.string.widget_prompt))
        }
        Column(
            modifier = GlanceModifier.fillMaxSize(),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Mark(avatar, 64)
            Spacer(GlanceModifier.height(6.dp))
            Text(
                line, maxLines = 3,
                style = TextStyle(
                    color = ColorProvider(Palette.text), fontSize = 14.sp,
                    fontWeight = FontWeight.Medium, textAlign = TextAlign.Center,
                ),
            )
            val streak = state.display?.streak
            if (streak != null && state.phase == WidgetState.Phase.QUADRANTS) {
                Text(streak, maxLines = 1, style = TextStyle(color = ColorProvider(Palette.textSoft), fontSize = 11.sp))
            }
        }
    }

    @Composable
    private fun Summary(state: WidgetState, avatar: Bitmap?, modifier: GlanceModifier) {
        val ctx = LocalContext.current
        Column(modifier = modifier) {
            Mark(avatar, 48)
            Text(
                state.savedText
                    ?: if (state.checkedInToday) state.text("doneToday", ctx.getString(R.string.widget_doneToday))
                    else state.text("prompt", ctx.getString(R.string.widget_prompt)),
                maxLines = 2,
                style = TextStyle(color = ColorProvider(Palette.text), fontSize = 14.sp, fontWeight = FontWeight.Medium),
            )
            val extra = state.capsuleText ?: state.display?.lastMoodText ?: state.display?.streak
            if (extra != null) {
                Text(
                    extra, maxLines = 2,
                    style = TextStyle(
                        color = ColorProvider(if (state.capsuleText != null) Palette.starlight else Palette.textSoft),
                        fontSize = 11.sp,
                    ),
                )
            }
            Spacer(GlanceModifier.defaultWeight())
            Text(
                state.text("needHelp", ctx.getString(R.string.widget_needHelp)),
                maxLines = 1,
                modifier = GlanceModifier.height(48.dp)
                    .clickable(actionStartActivity(AuraWidgetEnv.link(ctx, "safety"))),
                style = TextStyle(color = ColorProvider(Palette.starlight), fontSize = 12.sp, fontWeight = FontWeight.Bold),
            )
        }
    }

    @Composable
    private fun Picker(state: WidgetState, modifier: GlanceModifier) {
        val ctx = LocalContext.current
        val picked = state.picked
        Column(modifier = modifier) {
            if (picked != null) {
                Grid(
                    picked.moods.map { m ->
                        TileSpec(m.label, null, picked.id, actionRunCallback<SaveMoodAction>(actionParametersOf(MOOD to m.id)))
                    },
                    modifier = GlanceModifier.defaultWeight(),
                )
                Text(
                    "‹ " + state.text("back", ctx.getString(R.string.widget_back)),
                    maxLines = 1,
                    modifier = GlanceModifier.fillMaxWidth().height(24.dp).clickable(actionRunCallback<BackAction>()),
                    style = TextStyle(color = ColorProvider(Palette.textSoft), fontSize = 11.sp, textAlign = TextAlign.Center),
                )
            } else {
                val quadrants = Palette.gridOrder.mapNotNull { state.display?.quadrant(it) }
                Grid(
                    quadrants.map { q ->
                        TileSpec(q.label, Palette.glyph(q.id), q.id, actionRunCallback<PickQuadrantAction>(actionParametersOf(QUADRANT to q.id)))
                    },
                    modifier = GlanceModifier.fillMaxSize(),
                )
            }
        }
    }

    private data class TileSpec(
        val title: String,
        val glyph: Int?,
        val quadrant: String,
        val action: androidx.glance.action.Action,
    )

    @Composable
    private fun Grid(tiles: List<TileSpec>, modifier: GlanceModifier) {
        Column(modifier = modifier) {
            for (row in 0 until 2) {
                Row(modifier = GlanceModifier.fillMaxWidth().defaultWeight()) {
                    for (col in 0 until 2) {
                        val t = tiles.getOrNull(row * 2 + col)
                        Box(
                            modifier = GlanceModifier.defaultWeight().fillMaxHeight().padding(2.dp),
                            contentAlignment = Alignment.Center,
                        ) {
                            if (t != null) TileView(t)
                        }
                    }
                }
            }
        }
    }

    /** One tile: equal size and weight for every group (design system). */
    @Composable
    private fun TileView(t: TileSpec) {
        Row(
            modifier = GlanceModifier.fillMaxSize().background(Palette.deep(t.quadrant)).cornerRadius(12.dp)
                .padding(horizontal = 4.dp).clickable(t.action).semantics { contentDescription = t.title },
            verticalAlignment = Alignment.CenterVertically,
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            if (t.glyph != null) {
                Image(
                    ImageProvider(t.glyph), contentDescription = null,
                    modifier = GlanceModifier.size(14.dp),
                    colorFilter = androidx.glance.ColorFilter.tint(ColorProvider(Palette.accent(t.quadrant))),
                )
                Spacer(GlanceModifier.width(4.dp))
            }
            Text(
                t.title, maxLines = 2,
                style = TextStyle(
                    color = ColorProvider(Palette.text), fontSize = 12.sp,
                    fontWeight = FontWeight.Medium, textAlign = TextAlign.Center,
                ),
            )
        }
    }
}

val QUADRANT = ActionParameters.Key<String>("quadrant")
val MOOD = ActionParameters.Key<String>("mood")

/** Tap 1: a group. */
class PickQuadrantAction : ActionCallback {
    override suspend fun onAction(context: Context, glanceId: GlanceId, parameters: ActionParameters) {
        val q = parameters[QUADRANT] ?: return
        AuraWidgetEnv.store(context).pick(q, Instant.now())
        AuraWidgetEnv.refreshAll(context)
    }
}

/** Tap 2: a mood → a mood-only check-in, saved locally (never the network). */
class SaveMoodAction : ActionCallback {
    override suspend fun onAction(context: Context, glanceId: GlanceId, parameters: ActionParameters) {
        val mood = parameters[MOOD] ?: return
        val saved = AuraWidgetEnv.store(context).save(mood, Instant.now(), ZoneId.systemDefault())
        AuraWidgetEnv.refreshAll(context)
        if (saved != null) AuraWidgetEnv.onPending?.invoke()
    }
}

class BackAction : ActionCallback {
    override suspend fun onAction(context: Context, glanceId: GlanceId, parameters: ActionParameters) {
        AuraWidgetEnv.store(context).back()
        AuraWidgetEnv.refreshAll(context)
    }
}

class AuraWidgetReceiver : GlanceAppWidgetReceiver() {
    companion object {
        const val ACTION_REDRAW = "com.akvega.aura.widget.REDRAW"
    }

    override val glanceAppWidget: GlanceAppWidget = AuraGlanceWidget()

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == ACTION_REDRAW) {
            val pending = goAsync()
            CoroutineScope(Dispatchers.Default).launch {
                try {
                    AuraWidgetEnv.refreshAll(context)
                } finally {
                    pending.finish()
                }
            }
            return
        }
        super.onReceive(context, intent)
    }

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        AuraWidgetEnv.scheduleRedraw(context)
    }
}
