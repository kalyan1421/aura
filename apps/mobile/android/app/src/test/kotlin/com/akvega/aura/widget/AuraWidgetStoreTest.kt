package com.akvega.aura.widget

import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import java.time.Instant
import java.time.ZoneId

/** F11 widget store logic (mirrors ios/AuraWidgetCore tests). */
class AuraWidgetStoreTest {
    private class MemoryKV : WidgetKeyValue {
        val values = mutableMapOf<String, String>()
        override fun getString(key: String) = values[key]
        override fun putString(key: String, value: String?) {
            if (value == null) values.remove(key) else values[key] = value
        }
    }

    private val ist = ZoneId.of("Asia/Kolkata")
    private val afternoon = Instant.parse("2026-10-08T10:00:00Z") // 15:30 IST

    private fun display(
        ready: Boolean = true,
        discreet: Boolean = false,
        day: String = "2026-10-08",
        checkedIn: Boolean = false,
        triggers: List<String> = emptyList(),
    ): String = JSONObject()
        .put("v", 1).put("ready", ready).put("discreet", discreet)
        .apply { if (ready) put("owner", "owner-1") }
        .put("auraDay", day).put("checkedInToday", checkedIn)
        .put("awardsToday", JSONArray(if (checkedIn) listOf(2, 2, 0, 0) else listOf(10, 2, 2, 0)))
        .put("awardsFresh", JSONArray(listOf(10, 2, 2, 0)))
        .put("savedAward", JSONObject().put("10", "Saved · +10 Starlight").put("2", "Saved · +2 Starlight"))
        .put("s", JSONObject().put("saved", "Saved").put("capsuleWaiting", "Something from past you is waiting"))
        .put("triggerMoods", JSONArray(triggers))
        .put(
            "quadrants",
            JSONArray()
                .put(
                    JSONObject().put("id", "moonlight").put("label", "Moonlight").put(
                        "moods",
                        JSONArray()
                            .put(JSONObject().put("id", "calm").put("label", "Calm"))
                            .put(JSONObject().put("id", "content").put("label", "Content")),
                    ),
                )
                .put(
                    JSONObject().put("id", "storm").put("label", "Storm").put(
                        "moods", JSONArray().put(JSONObject().put("id", "anxious").put("label", "Anxious")),
                    ),
                ),
        )
        .toString()

    private fun store(json: String?): Pair<AuraWidgetStore, MemoryKV> {
        val kv = MemoryKV()
        if (json != null) kv.values[AuraWidgetKeys.DISPLAY] = json
        return AuraWidgetStore(kv) to kv
    }

    /** contracts/rules/vectors/aura_day.json: the same cases Dart and TS pass. */
    @Test
    fun auraDayVectors() {
        var dir: File? = File("").absoluteFile
        var vectors: File? = null
        while (dir != null && vectors == null) {
            vectors = File(dir, "contracts/rules/vectors/aura_day.json").takeIf { it.exists() }
            dir = dir.parentFile
        }
        val cases = JSONObject(vectors!!.readText()).getJSONArray("cases")
        assertTrue(cases.length() > 0)
        for (i in 0 until cases.length()) {
            val c = cases.getJSONObject(i)
            assertEquals(
                c.getString("name"),
                c.getString("expect"),
                AuraDay.of(Instant.parse(c.getString("utc")), ZoneId.of(c.getString("tz"))),
            )
        }
    }

    @Test
    fun nextRolloverIs0400Local() {
        assertEquals(Instant.parse("2026-10-08T22:30:00Z"), AuraDay.nextRollover(afternoon, ist))
    }

    @Test
    fun uuidV7Shape() {
        val id = UuidV7.make(afternoon.toEpochMilli())
        assertTrue(id, Regex("^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$").matches(id))
    }

    @Test
    fun notSetUpDisablesInput() {
        val (s, kv) = store(display(ready = false))
        assertEquals(WidgetState.Phase.NOT_READY, s.state(afternoon, ist).phase)
        assertNull(s.save("calm", afternoon, ist))
        assertNull(kv.values[AuraWidgetKeys.PENDING])
        assertEquals(WidgetState.Phase.NOT_READY, store(null).first.state(afternoon, ist).phase)
    }

    @Test
    fun discreetHasNoInput() {
        val (s, _) = store(display(discreet = true))
        assertEquals(WidgetState.Phase.DISCREET, s.state(afternoon, ist).phase)
        assertNull(s.save("calm", afternoon, ist))
    }

    @Test
    fun twoTapsSaveAMoodOnlyRecordWithTheDayStamp() {
        val (s, kv) = store(display())
        s.pick("moonlight", afternoon)
        val picked = s.state(afternoon, ist)
        assertEquals(WidgetState.Phase.MOODS, picked.phase)
        assertEquals("moonlight", picked.picked?.id)

        val r = s.save("calm", afternoon, ist)!!
        assertEquals("calm", r.moodId)
        assertEquals("owner-1", r.owner)
        assertEquals("2026-10-08", r.localDay)
        assertEquals("Asia/Kolkata", r.tz)
        assertEquals(330, r.tzOffsetMinutes)
        assertEquals("2026-10-08T10:00:00Z", r.deviceTs)
        val raw = kv.values[AuraWidgetKeys.PENDING]!!
        assertFalse(raw.contains("note"))
        assertFalse(raw.contains("tags"))

        val after = s.state(afternoon, ist)
        assertEquals(WidgetState.Phase.QUADRANTS, after.phase)
        assertTrue(after.checkedInToday)
        assertEquals("Saved · +10 Starlight", after.savedText)
        assertNull(s.state(afternoon.plusSeconds(61), ist).savedText)
    }

    @Test
    fun a0130TapIsStampedForThePreviousAuraDay() {
        val (s, _) = store(display(day = "2026-10-07"))
        val r = s.save("calm", Instant.parse("2026-10-07T20:00:00Z"), ist)!!
        assertEquals("2026-10-07", r.localDay)
    }

    @Test
    fun awardsFollowTheAppsSequence() {
        val (s, _) = store(display())
        assertEquals(10, s.nextAward(afternoon, ist))
        s.save("calm", afternoon, ist)
        assertEquals(2, s.nextAward(afternoon.plusSeconds(5), ist))
        val (stale, _) = store(display(day = "2026-10-07", checkedIn = true))
        assertEquals(10, stale.nextAward(afternoon, ist))
        assertFalse(stale.state(afternoon, ist).checkedInToday)
    }

    @Test
    fun acknowledgedRecordsAreDropped() {
        val (s, kv) = store(display())
        val first = s.save("calm", afternoon, ist)!!
        kv.values[AuraWidgetKeys.ACKED] = JSONArray(listOf(first.id)).toString()
        kv.values[AuraWidgetKeys.DISPLAY] = display(checkedIn = true)
        assertTrue(s.unsent.isEmpty())
        assertEquals(2, s.nextAward(afternoon.plusSeconds(10), ist))
        val second = s.save("content", afternoon.plusSeconds(10), ist)!!
        assertEquals(listOf(second.id), s.unsent.map { it.id })
        assertEquals(1, JSONArray(kv.values[AuraWidgetKeys.PENDING]).length())
    }

    @Test
    fun aDoubleTapSavesOnce() {
        val (s, _) = store(display())
        assertNotNull(s.save("calm", afternoon, ist))
        assertNull(s.save("calm", afternoon.plusMillis(500), ist))
        assertEquals(1, s.unsent.size)
    }

    @Test
    fun unknownMoodIsRefused() {
        assertNull(store(display()).first.save("ecstatic", afternoon, ist))
    }

    @Test
    fun aCapsuleMatchShowsTheWaitingLine() {
        val (s, _) = store(display(triggers = listOf("anxious")))
        assertNull(s.state(afternoon, ist).capsuleText)
        s.save("anxious", afternoon, ist)
        assertEquals("Something from past you is waiting", s.state(afternoon, ist).capsuleText)
    }

    @Test
    fun backgroundImportIsNeededOnlyForUnsentNotYetHandled() {
        val (s, kv) = store(display())
        assertFalse(s.needsBackgroundImport)
        val saved = s.save("calm", afternoon, ist)!!
        assertTrue(s.needsBackgroundImport)
        // A background run imported it without acknowledging: the widget still shows it, the worker skips it.
        kv.putString(AuraWidgetKeys.BG_HANDLED, JSONArray(listOf(saved.id)).toString())
        assertFalse(s.needsBackgroundImport)
        assertTrue(s.state(afternoon, ist).checkedInToday)
        s.save("anxious", afternoon.plusSeconds(10), ist)
        assertTrue(s.needsBackgroundImport)
    }

    @Test
    fun pendingIsCapped() {
        val (s, _) = store(display())
        for (i in 0 until AuraWidgetKeys.MAX_PENDING + 5) {
            s.save(if (i % 2 == 0) "calm" else "content", afternoon.plusSeconds(i * 3L), ist)
        }
        assertEquals(AuraWidgetKeys.MAX_PENDING, s.unsent.size)
    }
}
