# Mood Rooms (F5) and the room safety flows (F9: report, block, mute).
# Loaded by tool/l10n_source.py.
# s(key, en, desc, te, te_Latn, ph=None) · edit(key, en=, te=, tl=, desc=)
#
# te / te_Latn are first drafts: NEEDS NATIVE REVIEW before alpha. The report
# reasons, the crisis-lane line and the guidelines also need the
# safe-messaging self-review (A9): no string names a method.
#
# Rules (PRD 06b, 18-localization): rooms are never "chat"; nobody's age is
# ever mentioned; pseudonyms come from the server and are never translated;
# room theme names stay English in Tenglish and are translated in Telugu
# script; gestures are localised for warmth (Warm Tea → "Oka cup chai").

# ---- Rooms tab ---------------------------------------------------------------
s("rooms_title", "Rooms", "Rooms tab title (mood rooms with preset gestures). Never 'chat'.", "రూమ్‌లు", "Rooms")
s("rooms_yourRooms", "Your rooms", "Heading over the rooms you are in (Rooms tab and the Home strip).", "మీ రూమ్‌లు", "Mee rooms")
s("rooms_memories", "Memories", "Heading over rooms that have become read-only memories (kept 7 days).", "జ్ఞాపకాలు", "Memories")
s("rooms_whatTitle", "What rooms are", "Rooms tab: heading of the short explanation card.", "రూమ్‌లు అంటే ఏమిటి", "Rooms ante enti")
s("rooms_whatBody", "A small room of people who feel like you do right now, for a day.", "Rooms tab: one-line explanation. Calm; never 'chat' or 'strangers'.", "ఇప్పుడు మీలాగే అనిపిస్తున్న కొంతమంది ఉండే ఒక చిన్న రూమ్, ఒక్క రోజు కోసం.", "Ippudu meelaage anipistunna konta mandi unde oka chinna room, oka roju kosam.")
s("rooms_pointName", "A fresh name in every room. Nobody sees your account.", "Rooms tab privacy point: a new pseudonym per room.", "ప్రతి రూమ్‌లో ఒక కొత్త పేరు. మీ అకౌంట్ ఎవరికీ కనిపించదు.", "Prati room lo oka kotha peru. Mee account evariki kanipinchadu.")
s("rooms_pointGestures", "No messages or DMs: only eight warm gestures.", "Rooms tab privacy point: gestures only.", "మెసేజ్‌లు, DMలు ఉండవు: ఎనిమిది ఆత్మీయ సంజ్ఞలు మాత్రమే.", "Messages, DMs undavu: enimidi warm gestures maatrame.")
s("rooms_pointTime", "Rooms last a day, then rest as a memory for 7 days.", "Rooms tab point: lifetime.", "రూమ్ ఒక రోజు ఉంటుంది, తర్వాత 7 రోజులు జ్ఞాపకంగా ఉంటుంది.", "Room oka roju untundi, tarvaatha 7 rojulu memory ga untundi.")
s("rooms_lanternNote", "Lantern Hour: every night from 9 to 11 on your region's clock, rooms light a shared lantern and more people drop in.", "Rooms tab: when Lantern Hour happens. No pressure.", "Lantern Hour: మీ ప్రాంతం సమయం ప్రకారం ప్రతి రాత్రి 9 నుంచి 11 వరకు, రూమ్‌లు కలిసి ఒక లాంతరు వెలిగిస్తాయి, ఎక్కువ మంది వస్తారు.", "Lantern Hour: mee region time prakaaram prati raatri 9 nundi 11 varaku, rooms kalisi oka lantern veligistaayi, ekkuva mandi vastaaru.")
s("rooms_lanternNow", "Lantern Hour is on now", "Label on a room card during Lantern Hour.", "ఇప్పుడు Lantern Hour నడుస్తోంది", "Ippudu Lantern Hour nadustondi")
s("rooms_checkInCta", "Check in to find a room", "Rooms tab button: rooms are found from a check-in.", "రూమ్ కోసం చెక్-ఇన్ చేయండి", "Room kosam check-in cheyandi")
s("rooms_empty", "You're not in a room right now. After a check-in you can join people who feel the same.", "Rooms tab when you are in no room.", "మీరు ఇప్పుడు ఏ రూమ్‌లోనూ లేరు. చెక్-ఇన్ తర్వాత, మీలాగే అనిపిస్తున్న వాళ్ళతో కలవొచ్చు.", "Meeru ippudu e room lonu leru. Check-in tarvaatha, meelaage anipistunna vaallatho kalavochu.")
s("rooms_offline", "Rooms need a connection. Your own check-ins still save on this phone.", "Rooms tab offline (no call is made).", "రూమ్‌లకు కనెక్షన్ కావాలి. మీ చెక్-ఇన్‌లు ఈ ఫోన్‌లో సేవ్ అవుతూనే ఉంటాయి.", "Rooms ki connection kaavaali. Mee check-ins ee phone lo save avutune untaayi.")
s("rooms_loadFailed", "We couldn't reach the rooms just now.", "A rooms call failed (server or network). No blame.", "ఇప్పుడు రూమ్‌లను చేరుకోలేకపోయాం.", "Ippudu rooms ni reach cheyyalekapoyaam.")
s("rooms_tryAgain", "Try again", "Retry a rooms call.", "మళ్ళీ ప్రయత్నించండి", "Malli try cheyandi")
s("rooms_signedOut", "Rooms open once you're signed in.", "Rooms need an account (signed out).", "సైన్ ఇన్ చేశాక రూమ్‌లు తెరుచుకుంటాయి.", "Sign in chesaaka rooms open avutaayi.")
s("rooms_signIn", "Sign in", "Button to sign in (rooms need an account).", "సైన్ ఇన్ చేయండి", "Sign in cheyandi")
s("rooms_suspended", "Rooms are paused for your account right now. Help is always here.", "The account's room access is paused (pending review). Calm, no blame.", "ప్రస్తుతం మీ అకౌంట్‌కు రూమ్‌లు ఆపి ఉంచాం. సహాయం ఎప్పుడూ ఇక్కడే ఉంటుంది.", "Prastutam mee account ki rooms aapi unchaam. Help eppudu ikkade untundi.")
s("rooms_suspendedUntil", "Rooms are paused for your account until {date}. Help is always here.", "The account's room access is suspended until a date.", "మీ అకౌంట్‌కు {date} వరకు రూమ్‌లు ఆపి ఉంచాం. సహాయం ఎప్పుడూ ఇక్కడే ఉంటుంది.", "Mee account ki {date} varaku rooms aapi unchaam. Help eppudu ikkade untundi.", STR("date"))
s("rooms_accountClosed", "This account was closed for breaking Aura's rules.", "The account was closed by moderation (contract wording).", "Aura నియమాలను ఉల్లంఘించినందుకు ఈ అకౌంట్ మూసివేయబడింది.", "Aura rules break chesinanduku ee account close chesaamu.")
s("rooms_profilePending", "Rooms open once your account finishes setting up. Try again in a moment.", "409 profile_required: onboarding hasn't reached the server yet.", "మీ అకౌంట్ సెటప్ పూర్తయ్యాక రూమ్‌లు తెరుచుకుంటాయి. కాసేపట్లో మళ్ళీ ప్రయత్నించండి.", "Mee account setup complete ayyaaka rooms open avutaayi. Kaasepatlo malli try cheyandi.")
s("rooms_openHint", "Opens the room", "Screen-reader hint on a room card or strip item.", "రూమ్ తెరుచుకుంటుంది", "Room open avutundi")
s("rooms_memoryUntil", "A memory until {date}", "Room card for a memory: when it closes for good.", "{date} వరకు జ్ఞాపకం", "{date} varaku memory", STR("date"))

# ---- Room themes (by quadrant) ------------------------------------------------
s("rooms_theme_lighthouse", "The Lighthouse", "Room theme for Storm (high energy, unpleasant). Never 'bad'.", "దీపస్తంభం", "The Lighthouse")
s("rooms_theme_rain_sanctuary", "The Rain Sanctuary", "Room theme for Rain (low energy, unpleasant).", "వాన నిలయం", "The Rain Sanctuary")
s("rooms_theme_midnight_observatory", "The Midnight Observatory", "Room theme for Moonlight (low energy, pleasant).", "అర్ధరాత్రి నక్షత్రశాల", "The Midnight Observatory")
s("rooms_theme_sunrise_deck", "The Sunrise Deck", "Room theme for Sunrise (high energy, pleasant).", "సూర్యోదయ వేదిక", "The Sunrise Deck")

# ---- Gestures (the 8 presets) --------------------------------------------------
for key, en, te, tl, desc in [
    ("warm_tea", "Warm Tea", "వెచ్చని టీ", "Oka cup chai", "a cup of tea offered"),
    ("light_a_candle", "Light a Candle", "ఒక దీపం", "Oka deepam", "a small light lit for someone"),
    ("hug", "Hug", "కౌగిలింత", "Hug", "a hug"),
    ("me_too", "Me Too", "నాకూ అంతే", "Naaku kooda", "'I feel it too'"),
    ("soft_rain", "Soft Rain", "చిరుజల్లు", "Chiru jallu", "a gentle, calming rain"),
    ("stargaze", "Stargaze", "నక్షత్రాలు చూద్దాం", "Stars choodham", "looking at the stars together"),
    ("deep_breath", "Deep Breath", "దీర్ఘ శ్వాస", "Deep breath", "breathe slowly together"),
    ("youre_not_alone", "You're Not Alone", "మీరు ఒంటరి కాదు", "Meeru okkaru kaadu", "reassurance"),
]:
    s(f"rooms_gesture_{key}", en, f"Preset room gesture ({desc}). Warm, short; a name, not a sentence to translate literally.", te, tl)

# ---- Counts (real members only, never inflated) ------------------------------
s("rooms_hereNow", "{count, plural, =0{Nobody here right now} =1{1 here now} other{{count} here now}}", "Room header: current members seen in the last 2 min.", "{count, plural, =0{ఇప్పుడు ఎవరూ లేరు} =1{ఇప్పుడు 1 ఉన్నారు} other{ఇప్పుడు {count} మంది ఉన్నారు}}", "{count, plural, =0{Ippudu evaru leru} =1{Ippudu 1 unnaru} other{Ippudu {count} mandi unnaru}}", INT("count"))
s("rooms_today", "{count, plural, =1{1 person has been here today} other{{count} people have been here today}}", "Room header: everyone who has been a member today.", "{count, plural, =1{ఈ రోజు 1 వ్యక్తి ఇక్కడికి వచ్చారు} other{ఈ రోజు {count} మంది ఇక్కడికి వచ్చారు}}", "{count, plural, =1{Ee roju 1 person ikkadiki vachaaru} other{Ee roju {count} mandi ikkadiki vachaaru}}", INT("count"))
s("rooms_countsSemantic", "{now, plural, =1{1 person here now} other{{now} people here now}}, {today, plural, =1{1 today} other{{today} today}}", "Screen reader: the room header ('7 people here now, 31 today', REQ-A11Y-06).", "{now, plural, =1{ఇప్పుడు 1 వ్యక్తి} other{ఇప్పుడు {now} మంది}}, {today, plural, =1{ఈ రోజు 1} other{ఈ రోజు {today}}}", "{now, plural, =1{Ippudu 1 person} other{Ippudu {now} mandi}}, {today, plural, =1{ee roju 1} other{ee roju {today}}}", INT("now", "today"))
s("rooms_stripSemantic", "{theme}, {count, plural, =1{1 person here now} other{{count} people here now}}", "Screen reader: a room in the Home 'Your rooms' strip.", "{theme}, {count, plural, =1{ఇప్పుడు 1 వ్యక్తి} other{ఇప్పుడు {count} మంది}}", "{theme}, {count, plural, =1{Ippudu 1 person} other{Ippudu {count} mandi}}", {"theme": {"type": "String"}, "count": {"type": "int"}})

# ---- Room screen ------------------------------------------------------------------
s("rooms_opening", "Opening the room…", "Room screen while it loads.", "రూమ్ తెరుస్తున్నాం…", "Room open chestunnaam…")
s("rooms_youAre", "You're {pseudonym} here", "Your pseudonym in this room (fresh per room; never translated).", "ఇక్కడ మీరు {pseudonym}", "Ikkada meeru {pseudonym}", STR("pseudonym"))
s("rooms_coldStart", "{count, plural, =1{You're the first here today. Leave a light for the next one.} other{{count} people have been here today. Leave a light for the next one.}}", "Room with nobody else here right now (cold start). Honest counts, never fake presence.", "{count, plural, =1{ఈ రోజు ఇక్కడికి వచ్చిన మొదటివారు మీరే. తర్వాత వచ్చేవారి కోసం ఒక దీపం వదిలి వెళ్ళండి.} other{ఈ రోజు {count} మంది ఇక్కడికి వచ్చారు. తర్వాత వచ్చేవారి కోసం ఒక దీపం వదిలి వెళ్ళండి.}}", "{count, plural, =1{Ee roju ikkadiki vachina modativaaru meere. Tarvaatha vacchevaari kosam oka deepam vadili vellandi.} other{Ee roju {count} mandi ikkadiki vachaaru. Tarvaatha vacchevaari kosam oka deepam vadili vellandi.}}", INT("count"))
s("rooms_lanternOn", "Lantern Hour · until {time}", "Room header during Lantern Hour (the shared evening window).", "Lantern Hour · {time} వరకు", "Lantern Hour · {time} varaku", STR("time"))
s("rooms_closing", "This room becomes a memory at {time}.", "Room in its last hours (no new members; gestures still work).", "ఈ రూమ్ {time}కి జ్ఞాపకంగా మారుతుంది.", "Ee room {time} ki memory ga maarutundi.", STR("time"))
s("rooms_memory", "This room has become a memory. You can look back for 7 days.", "Room became read-only (24 h). Calm, not a loss.", "ఈ రూమ్ ఇప్పుడు ఒక జ్ఞాపకం. 7 రోజుల పాటు వెనక్కి చూసుకోవచ్చు.", "Ee room ippudu oka memory. 7 rojula paatu venakki choosukovachu.")
s("rooms_findNew", "Find a new room", "From a memory: start a check-in to find a new room.", "కొత్త రూమ్ వెతకండి", "Kotha room vetakandi")
s("rooms_reconnecting", "Reconnecting…", "Chip while the live connection to the room is restored (gestures wait up to 30 s).", "మళ్ళీ కనెక్ట్ అవుతోంది…", "Malli connect avutondi…")
s("rooms_membersTitle", "Here with you", "Room screen: heading over the members.", "మీతో ఇక్కడ", "Meetho ikkada")
s("rooms_you", "You", "Your own tile among the members.", "మీరు", "Meeru")
s("rooms_memberHereNow", "here now", "Screen reader: a member seen in the last 2 min.", "ఇప్పుడు ఇక్కడ ఉన్నారు", "ippudu ikkada unnaru")
s("rooms_memberAway", "away for now", "Screen reader: a member not seen for a while (still in the room).", "ప్రస్తుతం దూరంగా ఉన్నారు", "prastutam dooranga unnaru")
s("rooms_memberMuted", "muted for you", "A member you muted (their gestures don't reach you).", "మీ కోసం మ్యూట్ చేశారు", "meekosam mute chesaaru")
s("rooms_memberLabel", "{pseudonym}, {mood}, {status}", "Screen reader: a member tile (pseudonym, mood at join, here now / away).", "{pseudonym}, {mood}, {status}", "{pseudonym}, {mood}, {status}", STR("pseudonym", "mood", "status"))
s("rooms_youLabel", "You, {pseudonym}, {mood}", "Screen reader: your own tile.", "మీరు, {pseudonym}, {mood}", "Meeru, {pseudonym}, {mood}", STR("pseudonym", "mood"))
s("rooms_memberHint", "Opens options", "Screen-reader hint on a member tile (gestures, report, block, mute).", "ఆప్షన్లు తెరుచుకుంటాయి", "Options open avutaayi")
s("rooms_recentTitle", "Warmth in this room", "Room screen: heading over recent gestures.", "ఈ రూమ్‌లో ఆత్మీయత", "Ee room lo warmth")
s("rooms_receivedLine", "{pseudonym} sent you {gesture}", "A gesture you received ('Quiet Comet sent you Warm Tea'); also announced.", "{pseudonym} మీకు {gesture} పంపారు", "{pseudonym} meeku {gesture} pampaaru", STR("pseudonym", "gesture"))
s("rooms_sentToMember", "{gesture} sent to {pseudonym}", "Announcement after you send a gesture to a member (REQ-A11Y-06).", "{pseudonym}కి {gesture} పంపారు", "{pseudonym} ki {gesture} pampaaru", STR("gesture", "pseudonym"))
s("rooms_sentToRoom", "{gesture} sent to everyone here", "Announcement after you send a gesture to the room.", "ఇక్కడ అందరికీ {gesture} పంపారు", "Ikkada andariki {gesture} pampaaru", STR("gesture"))
s("rooms_someoneSent", "Someone sent {gesture}", "Someone else's gesture (unnamed, to a member).", "ఎవరో {gesture} పంపారు", "Evaro {gesture} pampaaru", STR("gesture"))
s("rooms_someoneSentRoom", "Someone sent {gesture} to everyone here", "Someone else's gesture to the whole room (unnamed).", "ఎవరో ఇక్కడ అందరికీ {gesture} పంపారు", "Evaro ikkada andariki {gesture} pampaaru", STR("gesture"))
s("rooms_youSentMember", "You sent {gesture} to {pseudonym}", "Your gesture in the room's list.", "మీరు {pseudonym}కి {gesture} పంపారు", "Meeru {pseudonym} ki {gesture} pampaaru", STR("gesture", "pseudonym"))
s("rooms_youSentRoom", "You sent {gesture} to everyone here", "Your gesture to the room in the room's list.", "మీరు ఇక్కడ అందరికీ {gesture} పంపారు", "Meeru ikkada andariki {gesture} pampaaru", STR("gesture"))
s("rooms_trayTitle", "Send warmth to everyone here", "Gesture tray heading (tap a member to send to one person).", "ఇక్కడ అందరికీ ఆత్మీయత పంపండి", "Ikkada andariki warmth pampandi")
s("rooms_trayHint", "Sends to everyone here", "Screen-reader hint on a tray gesture.", "ఇక్కడ అందరికీ పంపుతుంది", "Ikkada andariki pamputundi")
s("rooms_trayResting", "Gestures rest in a memory. You can still report, block or mute.", "Memory rooms are read-only.", "జ్ఞాపకంలో సంజ్ఞలు విశ్రాంతిలో ఉంటాయి. రిపోర్ట్, బ్లాక్, మ్యూట్ ఇంకా పనిచేస్తాయి.", "Memory lo gestures rest lo untaayi. Report, block, mute inka panichestaayi.")
s("rooms_roomOptions", "Room options", "Tooltip of the room menu button (report a problem, leave).", "రూమ్ ఆప్షన్లు", "Room options")
s("rooms_reportRoom", "Report a problem here", "Room menu: report something in this room (F9).", "ఇక్కడ ఒక సమస్యను రిపోర్ట్ చేయండి", "Ikkada oka problem report cheyandi")
s("rooms_leave", "Leave this room", "Room menu: leave for good.", "ఈ రూమ్ నుంచి వెళ్ళిపోండి", "Ee room nundi vellipondi")
s("rooms_removeMemory", "Remove from my rooms", "Room menu on a memory: leave it.", "నా రూమ్‌ల నుంచి తీసేయండి", "Naa rooms nundi teeseyandi")
s("rooms_leaveTitle", "Leave this room?", "Leave confirmation title. Calm.", "ఈ రూమ్ నుంచి వెళ్ళిపోతారా?", "Ee room nundi vellipotaara?")
s("rooms_leaveBody", "You won't be able to come back to it, and your seat opens up for someone else. Your next check-in can find you a new room.", "Leave confirmation: no rejoining; the slot frees up.", "మళ్ళీ ఈ రూమ్‌కి రాలేరు, మీ సీటు ఇంకొకరికి దొరుకుతుంది. మీ తర్వాతి చెక్-ఇన్ మీకు కొత్త రూమ్ వెతికిపెడుతుంది.", "Malli ee room ki raaleru, mee seat inkokariki dorukutundi. Mee next check-in meeku kotha room vetiki pedutundi.")
s("rooms_leaveConfirm", "Leave room", "Leave confirmation button.", "వెళ్ళిపోతాను", "Vellipotaanu")
s("rooms_stay", "Stay", "Keep the room (the safe choice).", "ఇక్కడే ఉంటాను", "Ikkade untaanu")
s("rooms_removeTitle", "Remove this memory?", "Leaving a memory room: confirmation title.", "ఈ జ్ఞాపకాన్ని తీసేయాలా?", "Ee memory ni teeseyaala?")
s("rooms_removeBody", "It leaves your rooms now. Memories close for good after 7 days anyway.", "Leaving a memory room: explanation.", "ఇది ఇప్పుడే మీ రూమ్‌ల నుంచి వెళ్ళిపోతుంది. ఎలాగూ 7 రోజుల తర్వాత జ్ఞాపకాలు పూర్తిగా మూసుకుపోతాయి.", "Idi ippude mee rooms nundi vellipotundi. Elaagu 7 rojula tarvaatha memories poortiga moosukupotaayi.")
s("rooms_removeConfirm", "Remove", "Leaving a memory room: confirm.", "తీసేయండి", "Teeseyandi")
s("rooms_keep", "Keep it", "Keep a memory room (the safe choice).", "ఉంచండి", "Unchandi")
s("rooms_leaveFailed", "That didn't go through. You're still in the room.", "Leaving failed (e.g. offline).", "అది జరగలేదు. మీరు ఇంకా రూమ్‌లోనే ఉన్నారు.", "Adi jaragaledu. Meeru inka room lone unnaru.")
s("rooms_gone", "This room has closed. Rooms rest for 7 days as memories, then they're gone.", "The room no longer exists for you (purged or left).", "ఈ రూమ్ మూసుకుపోయింది. రూమ్‌లు 7 రోజులు జ్ఞాపకాలుగా ఉండి, తర్వాత పోతాయి.", "Ee room moosukupoyindi. Rooms 7 rojulu memories ga undi, tarvaatha potaayi.")
s("rooms_backToRooms", "Back to your rooms", "Go to the Rooms tab.", "మీ రూమ్‌లకు వెళ్ళండి", "Mee rooms ki vellandi")
s("rooms_offlineRoom", "Rooms need a connection. This room opens again when you're back online.", "Opening a room while offline (no call is made).", "రూమ్‌లకు కనెక్షన్ కావాలి. మీరు మళ్ళీ ఆన్‌లైన్‌కి రాగానే ఈ రూమ్ తెరుచుకుంటుంది.", "Rooms ki connection kaavaali. Meeru malli online ki raagaane ee room open avutundi.")

# ---- Joining (match) ----------------------------------------------------------
s("rooms_joinTitle", "Finding your room", "Title while matching into a room.", "మీ రూమ్ వెతుకుతున్నాం", "Mee room vetukutunnaam")
s("rooms_finding", "Finding people who feel this way right now…", "Loading while matching (≤ 5 s, PRD States).", "ఇప్పుడు ఇలాగే అనిపిస్తున్న వాళ్ళను వెతుకుతున్నాం…", "Ippudu ilaage anipistunna vaallani vetukutunnaam…")
s("rooms_offlineJoin", "Rooms need a connection. Your check-in is saved.", "Joining offline (PRD States: Room offline). No call is made.", "రూమ్‌లకు కనెక్షన్ కావాలి. మీ చెక్-ఇన్ సేవ్ అయింది.", "Rooms ki connection kaavaali. Mee check-in save ayyindi.")
s("rooms_joinFailed", "We couldn't reach the rooms just now. Your check-in is saved.", "Joining failed (server or network).", "ఇప్పుడు రూమ్‌లను చేరుకోలేకపోయాం. మీ చెక్-ఇన్ సేవ్ అయింది.", "Ippudu rooms ni reach cheyyalekapoyaam. Mee check-in save ayyindi.")
s("rooms_joinLimit", "That's 3 new rooms for this feeling today. The rooms you're in are still open to you.", "429 room_join_limit. Calm; returning to a room is always free.", "ఈ రోజు ఈ భావనకు ఇప్పటికే 3 కొత్త రూమ్‌లు అయ్యాయి. మీరు ఉన్న రూమ్‌లు ఇంకా మీ కోసం తెరిచే ఉన్నాయి.", "Ee roju ee feeling ki ippatike 3 kotha rooms ayyaayi. Meeru unna rooms inka meekosam open ga unnaayi.")
s("rooms_seeYourRooms", "See your rooms", "Go to the Rooms tab.", "మీ రూమ్‌లు చూడండి", "Mee rooms choodandi")
s("rooms_poolUnavailable", "Hindi and Hinglish rooms are opening soon. Join an English room for now?", "409 language_pool_unavailable (PRD States).", "హిందీ, హింగ్లిష్ రూమ్‌లు త్వరలో మొదలవుతాయి. ప్రస్తుతానికి ఇంగ్లీష్ రూమ్‌లో చేరతారా?", "Hindi, Hinglish rooms tvaralo modalavutaayi. Prastutaaniki English room lo cherataara?")
s("rooms_poolJoinEnglish", "Join English room", "Join an English room instead.", "ఇంగ్లీష్ రూమ్‌లో చేరండి", "English room lo cherandi")
s("rooms_poolNotify", "Tell me when they open", "Ask for an in-app note when Hindi + Hinglish rooms open.", "అవి మొదలైనప్పుడు చెప్పండి", "Avi modalainappudu cheppandi")
s("rooms_poolNotifyDone", "We'll let you know here when Hindi and Hinglish rooms open.", "Confirmation of 'Tell me when they open'.", "హిందీ, హింగ్లిష్ రూమ్‌లు మొదలైనప్పుడు ఇక్కడే చెబుతాం.", "Hindi, Hinglish rooms modalainappudu ikkade cheptaam.")
s("rooms_noRequest", "Rooms open from a check-in.", "The join screen was opened without a check-in.", "రూమ్‌లు చెక్-ఇన్ నుంచి తెరుచుకుంటాయి.", "Rooms check-in nundi open avutaayi.")

# ---- Room offer (check-in saved moment, REQ-ROOM-01) ---------------------------
s("rooms_offer", "Join a room of people feeling this", "After a saved check-in: the room offer. Identical at every age.", "ఇలాగే అనిపిస్తున్న వాళ్ళ రూమ్‌లో చేరండి", "Ilaage anipistunna vaalla room lo cherandi")
s("rooms_offerHint", "Opens a room, with a fresh name just for it", "Screen-reader hint on the room offer.", "దాని కోసమే కొత్త పేరుతో ఒక రూమ్ తెరుచుకుంటుంది", "Daani kosame kotha peruto oka room open avutundi")
s("rooms_offerOffline", "Rooms open when you're back online", "Room offer while offline (REQ-ROOM-01). No call is made.", "మీరు మళ్ళీ ఆన్‌లైన్‌కి వచ్చాక రూమ్‌లు తెరుచుకుంటాయి", "Meeru malli online ki vachaaka rooms open avutaayi")
s("rooms_offerLater", "Rooms are in the Rooms tab whenever you'd like company.", "First check-in (during onboarding): where rooms are.", "తోడు కావాలనిపించినప్పుడు, రూమ్‌లు Rooms ట్యాబ్‌లో ఉంటాయి.", "Thodu kaavaalanipinchinappudu, rooms Rooms tab lo untaayi.")

# ---- Community guidelines before the first room (REQ-SAFE-04) -----------------
s("rooms_guidelinesTitle", "Before your first room", "Guidelines sheet title, shown before the first room.", "మీ మొదటి రూమ్‌కి ముందు", "Mee first room ki mundu")
s("rooms_guidelinesIntro", "Rooms stay gentle because everyone keeps to a few simple things:", "Guidelines intro.", "అందరూ ఈ కొన్ని చిన్న విషయాలు పాటిస్తారు కాబట్టే రూమ్‌లు ప్రశాంతంగా ఉంటాయి:", "Andaru ee konni chinna vishayaalu paatistaaru kaabatte rooms prashaanthanga untaayi:")
s("rooms_rule1", "Be kind. Everyone here is having a real day.", "Guideline 1.", "దయగా ఉండండి. ఇక్కడ అందరూ నిజమైన రోజును గడుపుతున్నారు.", "Dayaga undandi. Ikkada andaru nijamaina rojuni gaduputunnaru.")
s("rooms_rule2", "No hate about caste, religion, gender, sexuality or anything else.", "Guideline 2.", "కులం, మతం, లింగం, లైంగికత లేదా మరేదైనా గురించి ద్వేషం వద్దు.", "Kulam, matham, gender, sexuality leda inkedaina gurinchi hate vaddu.")
s("rooms_rule3", "No sexual content.", "Guideline 3.", "లైంగిక కంటెంట్ వద్దు.", "Sexual content vaddu.")
s("rooms_rule4", "Never share or ask for contact details or meet-ups, or anyone's age, school, city or photos.", "Guideline 4 (grooming and contact-swap).", "కాంటాక్ట్ వివరాలు, కలవడాలు, లేదా ఎవరి వయసు, స్కూల్, ఊరు, ఫోటోలు అడగవద్దు, పంచుకోవద్దు.", "Contact details, meet-ups, leda evari vayasu, school, ooru, photos adagavaddu, share cheyyavaddu.")
s("rooms_rule5", "No selling or spam.", "Guideline 5.", "అమ్మకాలు, స్పామ్ వద్దు.", "Selling, spam vaddu.")
s("rooms_rule6", "Never encourage anyone to hurt themselves. Talking about how you feel is always okay.", "Guideline 6 (safe messaging: no method named).", "ఎవరినీ తమను తాము బాధపెట్టుకోమని ప్రోత్సహించవద్దు. మీకు ఎలా అనిపిస్తోందో మాట్లాడటం ఎప్పుడూ సరే.", "Evarini tamani taamu baadha pettukomani protsahinchavaddu. Meeku ela anipistondo maatlaadatam eppudu okay.")
s("rooms_guidelinesSafety", "You can report, block or mute anyone, and help is always one tap away.", "Guidelines footer.", "ఎవరినైనా రిపోర్ట్, బ్లాక్ లేదా మ్యూట్ చేయవచ్చు, సహాయం ఎప్పుడూ ఒక్క ట్యాప్ దూరంలో ఉంటుంది.", "Evarinaina report, block leda mute cheyochu, help eppudu oka tap dooram lo untundi.")
s("rooms_guidelinesAgree", "I'll keep to these", "Accept the guidelines and continue to the room.", "నేను వీటిని పాటిస్తాను", "Nenu veetini paatistaanu")
s("rooms_guidelinesUpdate", "Rooms have new community guidelines. Update Aura to read them before your next room.", "The server asks for guidelines newer than this app version carries (REQ-SAFE-04). Calm; no blame.", "రూమ్‌ల కమ్యూనిటీ మార్గదర్శకాలు మారాయి. మీ తర్వాతి రూమ్‌కి ముందు వాటిని చదవడానికి Auraని అప్‌డేట్ చేయండి.", "Rooms community guidelines maaraayi. Mee next room ki mundu vaatini chadavadaaniki Aura ni update cheyandi.")

# ---- Member sheet (tap a silhouette) --------------------------------------------
s("rooms_sendTo", "Send {pseudonym} some warmth", "Member sheet: the gestures for this one person.", "{pseudonym}కి కొంచెం ఆత్మీయత పంపండి", "{pseudonym} ki konchem warmth pampandi", STR("pseudonym"))
s("rooms_gestureHintMember", "Sends to {pseudonym}", "Screen-reader hint on a gesture in the member sheet.", "{pseudonym}కి పంపుతుంది", "{pseudonym} ki pamputundi", STR("pseudonym"))
s("rooms_report", "Report", "Member sheet action (F9).", "రిపోర్ట్", "Report")
s("rooms_block", "Block", "Member sheet action (F9): account-level, both ways.", "బ్లాక్", "Block")
s("rooms_mute", "Mute", "Member sheet action: hides their gestures for you in this room.", "మ్యూట్", "Mute")
s("rooms_unmute", "Unmute", "Member sheet action: undo a mute.", "అన్‌మ్యూట్", "Unmute")
s("rooms_safetyNote", "They're never told who reported, blocked or muted them.", "Member sheet reassurance under the safety actions.", "ఎవరు రిపోర్ట్, బ్లాక్ లేదా మ్యూట్ చేశారో వాళ్ళకు ఎప్పుడూ తెలియదు.", "Evaru report, block leda mute chesaaro vaallaki eppudu teliyadu.")
s("rooms_blockTitle", "Block {pseudonym}?", "Block confirmation title. Calm.", "{pseudonym}ని బ్లాక్ చేయాలా?", "{pseudonym} ni block cheyaala?", STR("pseudonym"))
s("rooms_blockBody", "You won't be placed in a room together again, and gestures between you stop. They won't be told.", "Block confirmation body (the blocked person sees no change).", "మీరిద్దరూ మళ్ళీ ఒకే రూమ్‌లో ఉండరు, మీ మధ్య సంజ్ఞలు ఆగిపోతాయి. వాళ్ళకు ఈ విషయం చెప్పము.", "Meeriddaru malli oke room lo undaru, mee madhya gestures aagipotaayi. Vaallaki ee vishayam cheppamu.")
s("rooms_blocked", "{pseudonym} is blocked. You won't share a room again.", "After blocking.", "{pseudonym}ని బ్లాక్ చేశారు. మీరు మళ్ళీ ఒకే రూమ్‌లో ఉండరు.", "{pseudonym} ni block chesaaru. Meeru malli oke room lo undaru.", STR("pseudonym"))
s("rooms_muted", "{pseudonym} is muted for you. Their gestures won't reach you here.", "After muting (per room, for you only).", "{pseudonym}ని మీ కోసం మ్యూట్ చేశాం. వాళ్ళ సంజ్ఞలు ఇక్కడ మీకు చేరవు.", "{pseudonym} ni meekosam mute chesaam. Vaalla gestures ikkada meeku cheravu.", STR("pseudonym"))
s("rooms_unmuted", "{pseudonym} is unmuted.", "After unmuting.", "{pseudonym}ని అన్‌మ్యూట్ చేశాం.", "{pseudonym} ni unmute chesaam.", STR("pseudonym"))
s("rooms_undo", "Undo", "Undo a mute.", "వెనక్కి తీసుకోండి", "Undo")
s("rooms_actionFailed", "That didn't go through. Try again in a moment.", "A room action failed (e.g. offline). No blame.", "అది జరగలేదు. కాసేపట్లో మళ్ళీ ప్రయత్నించండి.", "Adi jaragaledu. Kaasepatlo malli try cheyandi.")

# ---- Report flow (F9) -----------------------------------------------------------
s("rooms_reportMember", "Report {pseudonym}", "Report sheet title for a member.", "{pseudonym}ని రిపోర్ట్ చేయండి", "{pseudonym} ni report cheyandi", STR("pseudonym"))
s("rooms_reportGesture", "Report this gesture", "Report sheet title / button for a received gesture.", "ఈ సంజ్ఞను రిపోర్ట్ చేయండి", "Ee gesture ni report cheyandi")
s("rooms_reportWhy", "What's happening?", "Report sheet: pick one reason.", "ఏం జరుగుతోంది?", "Em jarugutondi?")
s("rooms_reason1", "Someone may be in danger or hurting themselves", "Report reason 1 (crisis lane: the reporter sees helplines). Safe messaging.", "ఎవరైనా ప్రమాదంలో ఉండొచ్చు లేదా తమను తాము బాధపెట్టుకుంటూ ఉండొచ్చు", "Evaraina danger lo undochu leda tamani taamu baadha pettukuntu undochu")
s("rooms_reason2", "Harassment or bullying", "Report reason 2.", "వేధింపులు లేదా బెదిరింపులు", "Harassment leda bullying")
s("rooms_reason3", "Sexual content or advances", "Report reason 3.", "లైంగిక కంటెంట్ లేదా ప్రవర్తన", "Sexual content leda advances")
s("rooms_reason4", "Hate or slurs", "Report reason 4.", "ద్వేషం లేదా దూషణలు", "Hate leda slurs")
s("rooms_reason5", "Contact details or personal info", "Report reason 5.", "కాంటాక్ట్ వివరాలు లేదా వ్యక్తిగత సమాచారం", "Contact details leda personal info")
s("rooms_reason6", "Spam or selling", "Report reason 6.", "స్పామ్ లేదా అమ్మకాలు", "Spam leda selling")
s("rooms_reason7", "Someone may be under 13", "Report reason 7 (never shows anyone's age).", "ఎవరైనా 13 ఏళ్ల లోపు వారు కావచ్చు", "Evaraina 13 ella lopu vaallu kaavochu")
s("rooms_reason8", "Something else", "Report reason 8.", "ఇంకేదైనా", "Inkedaina")
s("rooms_reason9", "Seems to be targeting a young person", "Report reason 9, shown before 'Something else' (Minors & grooming lane on the server, whatever anyone's age). Plain and warm; never mentions or asks anyone's age.", "చిన్న వయసు వారిని లక్ష్యంగా చేసుకుంటున్నట్టు అనిపిస్తోంది", "Chinna vayasu vaallani target chestunnattu anipistondi")
s("rooms_reportNoteLabel", "Anything a moderator should know? (optional)", "Report note field label (≤ 200 characters).", "మోడరేటర్‌కు తెలియాల్సింది ఏదైనా ఉందా? (ఐచ్ఛికం)", "Moderator ki teliyaalsindi edaina undaa? (optional)")
s("rooms_reportNoteHelp", "Only Aura's moderators read this. Please leave out phone numbers, links and handles.", "Report note helper text.", "దీన్ని Aura మోడరేటర్‌లు మాత్రమే చదువుతారు. దయచేసి ఫోన్ నంబర్లు, లింక్‌లు, హ్యాండిల్స్ రాయకండి.", "Deenni Aura moderators maatrame chaduvutaaru. Dayachesi phone numbers, links, handles raayakandi.")
s("rooms_reportNoteContact", "Phone numbers, links and handles can't be shared here. It keeps everyone safer.", "On-device PII check on the report note (PRD States wording). Nothing was sent.", "ఫోన్ నంబర్లు, లింక్‌లు, హ్యాండిల్స్ ఇక్కడ పంచుకోలేరు. ఇది అందరినీ సురక్షితంగా ఉంచుతుంది.", "Phone numbers, links, handles ikkada share cheyyaleru. Idi andarini safe ga unchutundi.")
s("rooms_reportSend", "Send report", "Submit a report.", "రిపోర్ట్ పంపండి", "Report pampandi")
s("rooms_reportThanks", "Thank you for telling us. A moderator will look at it, usually within a day.", "After a report (room or other).", "మాకు చెప్పినందుకు ధన్యవాదాలు. ఒక మోడరేటర్ సాధారణంగా ఒక రోజులో దీన్ని చూస్తారు.", "Maaku cheppinanduku thanks. Oka moderator saadhaaranamga oka roju lo deenni chustaaru.")
s("rooms_reportHidden", "Thank you for telling us. You won't get their gestures in this room while a moderator takes a look.", "After reporting a member (they are muted for you here).", "చెప్పినందుకు ధన్యవాదాలు. మోడరేటర్ చూసే వరకు ఈ రూమ్‌లో వాళ్ళ సంజ్ఞలు మీకు రావు.", "Cheppinanduku thanks. Moderator chuse varaku ee room lo vaalla gestures meeku raavu.")
s("rooms_reportGestureHidden", "Thank you for telling us. That gesture is hidden for you now.", "After reporting a gesture.", "చెప్పినందుకు ధన్యవాదాలు. ఆ సంజ్ఞ ఇప్పుడు మీకు కనిపించదు.", "Cheppinanduku thanks. Aa gesture ippudu meeku kanipinchadu.")
s("rooms_reportCrisis", "Thank you for telling us. A moderator will look soon, and help is always one tap away.", "After a report in the crisis lane (the Safety Center opens first). Safe messaging.", "చెప్పినందుకు ధన్యవాదాలు. ఒక మోడరేటర్ త్వరలో చూస్తారు, సహాయం ఎప్పుడూ ఒక్క ట్యాప్ దూరంలో ఉంటుంది.", "Cheppinanduku thanks. Oka moderator tvaralo chustaaru, help eppudu oka tap dooram lo untundi.")
s("rooms_reportLimit", "That's a lot of reports today. If someone is in danger, the help button is always here.", "429 report_limit (reason 1 is never limited).", "ఈ రోజు చాలా రిపోర్ట్‌లు వచ్చాయి. ఎవరైనా ప్రమాదంలో ఉంటే, సహాయం బటన్ ఎప్పుడూ ఇక్కడే ఉంటుంది.", "Ee roju chaala reports vachaayi. Evaraina danger lo unte, help button eppudu ikkade untundi.")
s("rooms_reportFailed", "That didn't go through, so nothing was sent. Try again in a moment.", "Report failed.", "అది జరగలేదు, కాబట్టి ఏదీ పంపలేదు. కాసేపట్లో మళ్ళీ ప్రయత్నించండి.", "Adi jaragaledu, kaabatti emi pampaledu. Kaasepatlo malli try cheyandi.")
s("rooms_reportOffline", "Reports need a connection. Nothing was sent yet.", "Report while offline (no call is made).", "రిపోర్ట్‌లకు కనెక్షన్ కావాలి. ఇంకా ఏదీ పంపలేదు.", "Reports ki connection kaavaali. Inka emi pampaledu.")

# ---- Exit micro-survey --------------------------------------------------------------
s("rooms_surveyTitle", "Did you feel less alone?", "Exit micro-survey (≥ 30 s in the room, at most once a day). Aggregate only.", "మీకు కొంచెం ఒంటరితనం తగ్గినట్టు అనిపించిందా?", "Meeku konchem ontaritanam taggindaa?")
s("rooms_surveyYes", "Yes", "Survey answer.", "అవును", "Avunu")
s("rooms_surveyNo", "Not really", "Survey answer.", "అంతగా లేదు", "Antaga ledu")
s("rooms_surveySkip", "Skip", "Skip the survey.", "వదిలేయండి", "Skip")
