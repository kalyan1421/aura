package com.akvega.aura.widget

import org.json.JSONArray
import org.json.JSONObject
import java.security.SecureRandom
import java.time.Instant
import java.time.ZoneId
import java.time.ZonedDateTime
import java.time.format.DateTimeFormatter

// Aura home-screen widget (F11): the store logic, plain JVM (unit-tested in
// app/src/test). Mirrors ios/AuraWidgetCore and
// lib/src/features/widget/widget_store.dart. App-private shared preferences
// `aura_widget` hold three JSON strings, each with one writer:
//   aura.widget.display  the app: what to show (copy already in its language)
//   aura.widget.pending  the widget: mood-only check-ins
//   aura.widget.acked    the app: ids it has handled
// plus aura.widget.ui (widget only: the picked group, the last save).
// The widget never talks to the network or to Supabase.

object AuraWidgetKeys {
    const val PREFS = "aura_widget"
    const val DISPLAY = "aura.widget.display"
    const val PENDING = "aura.widget.pending"
    const val ACKED = "aura.widget.acked"
    const val UI = "aura.widget.ui"
    const val AVATAR_FILE = "aura-widget-avatar.png"
    const val STORE_VERSION = 1
    const val MAX_PENDING = 200
    const val SAVED_MS = 60_000L
    const val PICK_MS = 60_000L
}

/** Key/value storage: SharedPreferences on device, a map in tests. */
interface WidgetKeyValue {
    fun getString(key: String): String?
    fun putString(key: String, value: String?)
}

data class WidgetMood(val id: String, val label: String)

data class WidgetQuadrant(val id: String, val label: String, val moods: List<WidgetMood>)

/** `aura.widget.display` as the app published it. */
class WidgetDisplay(val json: JSONObject) {
    val ready get() = json.optBoolean("ready", false)
    val discreet get() = json.optBoolean("discreet", false)
    val owner: String? get() = json.optString("owner", "").ifEmpty { null }
    val auraDay: String? get() = json.optString("auraDay", "").ifEmpty { null }
    val checkedInToday get() = json.optBoolean("checkedInToday", false)
    val avatar get() = json.optBoolean("avatar", false)
    val capsuleWaiting get() = json.optBoolean("capsuleWaiting", false)
    val streak: String? get() = json.optString("streak", "").ifEmpty { null }
    val lastMoodText: String? get() = json.optJSONObject("lastMood")?.optString("text", "")?.ifEmpty { null }

    fun text(key: String): String? = json.optJSONObject("s")?.optString(key, "")?.ifEmpty { null }

    fun ints(key: String): List<Int> {
        val a = json.optJSONArray(key) ?: return emptyList()
        return (0 until a.length()).map { a.optInt(it, 0) }
    }

    fun savedAward(award: Int): String? =
        json.optJSONObject("savedAward")?.optString("$award", "")?.ifEmpty { null }

    val triggerMoods: Set<String>
        get() {
            val a = json.optJSONArray("triggerMoods") ?: return emptySet()
            return (0 until a.length()).map { a.optString(it) }.toSet()
        }

    val quadrants: List<WidgetQuadrant>
        get() {
            val a = json.optJSONArray("quadrants") ?: return emptyList()
            return (0 until a.length()).mapNotNull { i ->
                val q = a.optJSONObject(i) ?: return@mapNotNull null
                val m = q.optJSONArray("moods") ?: JSONArray()
                WidgetQuadrant(
                    q.optString("id"),
                    q.optString("label"),
                    (0 until m.length()).mapNotNull { j ->
                        m.optJSONObject(j)?.let { WidgetMood(it.optString("id"), it.optString("label")) }
                    },
                )
            }
        }

    fun quadrant(id: String?): WidgetQuadrant? = quadrants.firstOrNull { it.id == id }

    fun hasMood(id: String) = quadrants.any { q -> q.moods.any { it.id == id } }

    companion object {
        fun decode(raw: String?): WidgetDisplay? =
            try {
                raw?.let { WidgetDisplay(JSONObject(it)) }
            } catch (e: Exception) {
                null
            }
    }
}

/** A mood-only check-in: client UUIDv7 + day stamp (F11 "Data path"). */
data class PendingCheckIn(
    val id: String,
    val moodId: String,
    val deviceTs: String,
    val tzOffsetMinutes: Int,
    val tz: String,
    val localDay: String,
    val owner: String,
    val v: Int = AuraWidgetKeys.STORE_VERSION,
) {
    fun toJson(): JSONObject = JSONObject()
        .put("v", v).put("id", id).put("moodId", moodId).put("deviceTs", deviceTs)
        .put("tzOffsetMinutes", tzOffsetMinutes).put("tz", tz).put("localDay", localDay)
        .put("owner", owner)

    companion object {
        fun fromJson(o: JSONObject): PendingCheckIn? = try {
            PendingCheckIn(
                id = o.getString("id"), moodId = o.getString("moodId"),
                deviceTs = o.getString("deviceTs"), tzOffsetMinutes = o.optInt("tzOffsetMinutes", 0),
                tz = o.getString("tz"), localDay = o.optString("localDay", ""),
                owner = o.optString("owner", ""), v = o.optInt("v", AuraWidgetKeys.STORE_VERSION),
            )
        } catch (e: Exception) {
            null
        }
    }
}

data class WidgetUi(
    val quadrant: String? = null,
    val pickedAt: Long? = null,
    val savedId: String? = null,
    val savedMood: String? = null,
    val savedAward: Int = 0,
    val savedAt: Long? = null,
) {
    fun toJson(): JSONObject = JSONObject().apply {
        quadrant?.let { put("quadrant", it) }
        pickedAt?.let { put("pickedAt", it) }
        savedId?.let { put("savedId", it) }
        savedMood?.let { put("savedMood", it) }
        put("savedAward", savedAward)
        savedAt?.let { put("savedAt", it) }
    }

    companion object {
        fun decode(raw: String?): WidgetUi = try {
            val o = JSONObject(raw ?: "{}")
            WidgetUi(
                quadrant = o.optString("quadrant", "").ifEmpty { null },
                pickedAt = if (o.has("pickedAt")) o.getLong("pickedAt") else null,
                savedId = o.optString("savedId", "").ifEmpty { null },
                savedMood = o.optString("savedMood", "").ifEmpty { null },
                savedAward = o.optInt("savedAward", 0),
                savedAt = if (o.has("savedAt")) o.getLong("savedAt") else null,
            )
        } catch (e: Exception) {
            WidgetUi()
        }
    }
}

object AuraDay {
    private val day = DateTimeFormatter.ofPattern("yyyy-MM-dd")

    /** The local date in [zone], minus a day before 04:00 (RULES.md §1). */
    fun of(instant: Instant, zone: ZoneId): String {
        val local = ZonedDateTime.ofInstant(instant, zone)
        val date = if (local.hour < 4) local.toLocalDate().minusDays(1) else local.toLocalDate()
        return date.format(day)
    }

    /** The next 04:00 local after [instant]. */
    fun nextRollover(instant: Instant, zone: ZoneId): Instant {
        val local = ZonedDateTime.ofInstant(instant, zone)
        var at = local.toLocalDate().atTime(4, 0).atZone(zone)
        if (!at.isAfter(local)) at = local.toLocalDate().plusDays(1).atTime(4, 0).atZone(zone)
        return at.toInstant()
    }
}

object UuidV7 {
    private val random = SecureRandom()

    /** RFC 9562 UUIDv7: 48-bit Unix ms, version 7, variant 10, random rest. */
    fun make(epochMs: Long, bytes: ByteArray = ByteArray(10).also { random.nextBytes(it) }): String {
        val b = ByteArray(16)
        for (i in 0 until 6) b[i] = ((epochMs shr (8 * (5 - i))) and 0xff).toByte()
        for (i in 6 until 16) b[i] = bytes[i - 6]
        b[6] = ((b[6].toInt() and 0x0f) or 0x70).toByte()
        b[8] = ((b[8].toInt() and 0x3f) or 0x80).toByte()
        val hex = b.joinToString("") { "%02x".format(it) }
        return "${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-" +
            "${hex.substring(16, 20)}-${hex.substring(20)}"
    }
}

/** What a render needs, computed from the store at a moment. */
data class WidgetState(
    val display: WidgetDisplay?,
    val phase: Phase,
    val picked: WidgetQuadrant?,
    val checkedInToday: Boolean,
    val savedText: String?,
    val capsuleText: String?,
) {
    enum class Phase { NOT_READY, DISCREET, QUADRANTS, MOODS }

    fun text(key: String, fallback: String) = display?.text(key) ?: fallback
}

/** The widget's logic over a key/value store. Thin: the app decided the rules. */
class AuraWidgetStore(private val kv: WidgetKeyValue) {
    val display: WidgetDisplay? get() = WidgetDisplay.decode(kv.getString(AuraWidgetKeys.DISPLAY))
    val ui: WidgetUi get() = WidgetUi.decode(kv.getString(AuraWidgetKeys.UI))

    val acked: Set<String>
        get() = try {
            val a = JSONArray(kv.getString(AuraWidgetKeys.ACKED) ?: "[]")
            (0 until a.length()).map { a.getString(it) }.toSet()
        } catch (e: Exception) {
            emptySet()
        }

    /** Check-ins saved here that the app hasn't handled yet. */
    val unsent: List<PendingCheckIn>
        get() {
            val done = acked
            val a = try {
                JSONArray(kv.getString(AuraWidgetKeys.PENDING) ?: "[]")
            } catch (e: Exception) {
                JSONArray()
            }
            return (0 until a.length())
                .mapNotNull { a.optJSONObject(it)?.let(PendingCheckIn::fromJson) }
                .filter { it.id !in done }
        }

    fun state(now: Instant, zone: ZoneId): WidgetState {
        val d = display
        val today = AuraDay.of(now, zone)
        val unsentAll = unsent
        val done = (d?.auraDay == today && d.checkedInToday) || unsentAll.any { it.localDay == today }
        if (d == null || !d.ready) return WidgetState(d, WidgetState.Phase.NOT_READY, null, false, null, null)
        if (d.discreet) return WidgetState(d, WidgetState.Phase.DISCREET, null, done, null, null)
        val u = ui
        val ms = now.toEpochMilli()
        var saved: String? = null
        val savedAt = u.savedAt
        if (savedAt != null && ms >= savedAt && ms - savedAt < AuraWidgetKeys.SAVED_MS) {
            saved = if (u.savedAward > 0) d.savedAward(u.savedAward) ?: d.text("saved") else d.text("saved")
        }
        val triggers = d.triggerMoods
        val capsule = if (d.capsuleWaiting || unsentAll.any { it.moodId in triggers }) d.text("capsuleWaiting") else null
        val picked = d.quadrant(u.quadrant)
        val pickedAt = u.pickedAt
        val moods = saved == null && picked != null && pickedAt != null &&
            ms >= pickedAt && ms - pickedAt < AuraWidgetKeys.PICK_MS
        return WidgetState(
            d,
            if (moods) WidgetState.Phase.MOODS else WidgetState.Phase.QUADRANTS,
            if (moods) picked else null,
            done,
            saved,
            capsule,
        )
    }

    /** Provisional Starlight for one more check-in now (the app's sequence). */
    fun nextAward(now: Instant, zone: ZoneId): Int {
        val d = display ?: return 0
        val today = AuraDay.of(now, zone)
        val seq = if (d.auraDay == today) d.ints("awardsToday") else d.ints("awardsFresh")
        if (seq.isEmpty()) return 0
        val index = unsent.count { it.localDay == today }
        return if (index < seq.size) seq[index] else seq.last()
    }

    /** When the widget should redraw next (a save or pick fades). */
    fun nextFade(now: Instant): Long? {
        val ms = now.toEpochMilli()
        val u = ui
        return listOfNotNull(
            u.savedAt?.plus(AuraWidgetKeys.SAVED_MS)?.takeIf { it > ms },
            u.pickedAt?.plus(AuraWidgetKeys.PICK_MS)?.takeIf { it > ms },
        ).minOrNull()
    }

    /** Tap 1: a group. */
    fun pick(quadrant: String, now: Instant) {
        val d = display ?: return
        if (!d.ready || d.discreet || d.quadrant(quadrant) == null) return
        writeUi(ui.copy(quadrant = quadrant, pickedAt = now.toEpochMilli(), savedAt = null, savedId = null))
    }

    /** "Back": from the moods to the groups. */
    fun back() = writeUi(ui.copy(quadrant = null, pickedAt = null))

    /**
     * Tap 2: a mood → a mood-only check-in in `pending`. Null when input is
     * off (not set up, discreet, unknown mood) or it is the same mood again
     * within 2 s (a double tap saves once, like F1).
     */
    fun save(moodId: String, now: Instant, zone: ZoneId, random: ByteArray? = null): PendingCheckIn? {
        val d = display ?: return null
        val owner = d.owner ?: return null
        if (!d.ready || d.discreet || !d.hasMood(moodId)) return null
        val u = ui
        val ms = now.toEpochMilli()
        if (u.savedMood == moodId && u.savedAt != null && kotlin.math.abs(ms - u.savedAt) < 2_000) return null
        val award = nextAward(now, zone)
        val record = PendingCheckIn(
            id = if (random != null) UuidV7.make(ms, random) else UuidV7.make(ms),
            moodId = moodId,
            deviceTs = DateTimeFormatter.ISO_INSTANT.format(Instant.ofEpochMilli(ms)),
            tzOffsetMinutes = zone.rules.getOffset(now).totalSeconds / 60,
            tz = zone.id,
            localDay = AuraDay.of(now, zone),
            owner = owner,
        )
        // The widget is the only writer of `pending`: drop what the app handled.
        val list = (unsent + record).takeLast(AuraWidgetKeys.MAX_PENDING)
        kv.putString(AuraWidgetKeys.PENDING, JSONArray(list.map { it.toJson() }).toString())
        writeUi(WidgetUi(savedId = record.id, savedMood = moodId, savedAward = award, savedAt = ms))
        return record
    }

    private fun writeUi(u: WidgetUi) = kv.putString(AuraWidgetKeys.UI, u.toJson().toString())
}
