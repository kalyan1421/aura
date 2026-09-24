# Room lanterns and Tonight's intention (F5, Milestone B; PRD 06b "Room
# lanterns and Tonight's intention", 14-states "Lantern Hour ends before the
# lantern is full"). Loaded by tool/l10n_source.py.
# s(key, en, desc, te, te_Latn, ph=None)
#
# te / te_Latn are first drafts: NEEDS NATIVE REVIEW before beta.
#
# Rules: the lantern is a room total. Never "failed", "missed", "almost" or
# any score; never who added light or how much (not even "your share").
# The intention: no pressure, no follow-up, never names who holds it.
# "Lantern Hour" stays English in every locale (a product name).

# ---- the lantern ---------------------------------------------------------------
s("rooms_lanternTitle", "Tonight's lantern", "Room card title: the room's shared lantern (lit together during Lantern Hour).", "ఈ రాత్రి లాంతరు", "Ee raatri lantern")
s("rooms_lanternStart", "Every gesture here adds a little light.", "Room lantern during Lantern Hour, not lit yet. Invitation, no pressure.", "ఇక్కడ ప్రతి సంజ్ఞ కొంచెం వెలుగు కలుపుతుంది.", "Ikkada prati gesture konchem velugu kaluputundi.")
s("rooms_lanternGlowing", "It glows brighter with every gesture here.", "Room lantern during Lantern Hour, partly lit. Never a count or a score.", "ఇక్కడి ప్రతి సంజ్ఞతో ఇది ఇంకా ప్రకాశిస్తుంది.", "Ikkadi prati gesture tho idi inka prakaashistundi.")
s("rooms_lanternFull", "Fully lit, together.", "Room lantern fully lit (all levels).", "అందరం కలిసి పూర్తిగా వెలిగించాం.", "Andaram kalisi poortiga veliginchaam.")
s("rooms_lanternKept", "Tonight's lantern glowed this bright.", "After Lantern Hour and in the room memory: the level the lantern reached. PRD 14-states copy; never 'failed', 'missed' or 'almost'.", "ఈ రాత్రి లాంతరు ఇంత ప్రకాశంగా వెలిగింది.", "Ee raatri lantern intha prakaasham ga veligindi.")
s("rooms_lanternSemantic", "Tonight's lantern, {level} of {max} lights lit", "Screen-reader label for the room lantern (a room total).", "ఈ రాత్రి లాంతరు, {max}లో {level} వెలుగులు", "Ee raatri lantern, {max} lo {level} velugulu", {"level": {"type": "int"}, "max": {"type": "int"}})
s("rooms_lanternRise", "The lantern is fully lit. Lanterns rise, together.", "The one shared moment when the room's lantern becomes fully lit (announced; shown as a line under Reduce Motion).", "లాంతరు పూర్తిగా వెలిగింది. లాంతర్లు కలిసి పైకి ఎగురుతున్నాయి.", "Lantern poortiga veligindi. Lanterns kalisi paiki egurutunnaayi.")

# ---- tonight's intention -----------------------------------------------------------
s("rooms_intentionTitle", "Tonight's intention", "Room card title: one preset intention the room can hold together during Lantern Hour.", "ఈ రాత్రి సంకల్పం", "Ee raatri intention")
s("rooms_intentionHold", "Hold this tonight", "Button: hold tonight's intention (one tap, can't be undone). No pressure.", "ఈ రాత్రి దీన్ని పట్టుకుంటాను", "Ee raatri idi pattukuntaanu")
s("rooms_intentionHolding", "You're holding this tonight", "After you held tonight's intention (only you see this).", "ఈ రాత్రి మీరు దీన్ని పట్టుకున్నారు", "Ee raatri meeru idi pattukunnaru")
s("rooms_intentionHolds", "{count, plural, =0{Hold it with one tap} =1{1 holding this tonight} other{{count} holding this tonight}}", "The room total holding tonight's intention (never who).", "{count, plural, =0{ఒక్క ట్యాప్‌తో పట్టుకోండి} =1{ఈ రాత్రి 1 దీన్ని పట్టుకున్నారు} other{ఈ రాత్రి {count} మంది దీన్ని పట్టుకున్నారు}}", "{count, plural, =0{Oka tap tho pattukondi} =1{Ee raatri 1 idi pattukunnaru} other{Ee raatri {count} mandi idi pattukunnaru}}", INT("count"))
s("rooms_intentionHeld", "{count, plural, =0{Resting until the next Lantern Hour} =1{1 held this tonight} other{{count} held this tonight}}", "After Lantern Hour: how many held tonight's intention. No failure copy.", "{count, plural, =0{తర్వాతి Lantern Hour వరకు విశ్రాంతి} =1{ఈ రాత్రి 1 దీన్ని పట్టుకున్నారు} other{ఈ రాత్రి {count} మంది దీన్ని పట్టుకున్నారు}}", "{count, plural, =0{Tarvaathi Lantern Hour varaku vishraanti} =1{Ee raatri 1 idi pattukunnaru} other{Ee raatri {count} mandi idi pattukunnaru}}", INT("count"))
s("rooms_intentionPrivate", "Nobody sees who holds it, and nobody will ask about it tomorrow.", "Under tonight's intention: holders are never named; no follow-up.", "ఎవరు పట్టుకున్నారో ఎవరికీ కనిపించదు, రేపు దీని గురించి ఎవరూ అడగరు.", "Evaru pattukunnaro evariki kanipinchadu, repu deeni gurinchi evaru adagaru.")
s("rooms_intentionFailed", "That didn't go through. Please try again.", "Holding tonight's intention failed (connection, or the hour ended). No blame.", "అది జరగలేదు. దయచేసి మళ్ళీ ప్రయత్నించండి.", "Adi jaragaledu. Dayachesi malli try cheyandi.")

# The preset list (server keys, contracts/api/v1-rooms.md §1.9). Rotated
# nightly; a key this build doesn't know hides the card.
for key, en, te, tl in [
    ("sleep_before_midnight", "Sleep before midnight", "అర్ధరాత్రి లోపు నిద్రపోవాలి", "Ardharaatri lopu nidrapovaali"),
    ("gentle_with_myself", "Be gentle with myself tonight", "ఈ రాత్రి నా పట్ల మృదువుగా ఉంటాను", "Ee raatri naa patla gentle ga untaanu"),
    ("phone_down_10", "Phone down for 10 minutes", "10 నిమిషాలు ఫోన్ పక్కన పెడతాను", "10 nimishaalu phone pakkana pedataanu"),
    ("water_before_bed", "A glass of water before bed", "పడుకునే ముందు ఒక గ్లాసు నీళ్ళు", "Padukune mundu oka glass neellu"),
    ("one_kind_thought", "One kind thought about today", "ఈ రోజు గురించి ఒక మంచి ఆలోచన", "Ee roju gurinchi oka manchi aalochana"),
    ("slow_breaths", "Three slow breaths before sleep", "నిద్రకు ముందు మూడు నెమ్మదైన శ్వాసలు", "Nidraku mundu moodu nemmadaina swaasalu"),
]:
    s(f"rooms_intention_{key}", en, "Tonight's intention preset (first person, gentle, never a goal to fail).", te, tl)
