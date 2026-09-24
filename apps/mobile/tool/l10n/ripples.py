# F7 Breath Ripples (Milestone B; PRD 06b "F7 Breath Ripples", 14-states
# "Breath Ripples lobby and session", 17-accessibility REQ-A11Y-07).
# Loaded by tool/l10n_source.py.
# s(key, en, desc, te, te_Latn, ph=None)
#
# te / te_Latn are first drafts: NEEDS NATIVE REVIEW before beta.
#
# Rules: no score, number of breaths, countdown or leaderboard; never
# "failed", "left", "disconnected" or "no one found". Echoes are always
# called echoes (recordings of people who breathed here before) and never
# counted as people; guide lights are never presented as people.
# "Breath Ripples" stays in Latin script in every locale (a product name).

NAME = STR("name")

# ---- entries ---------------------------------------------------------------------
s("ripples_title", "Breath Ripples", "Product name of the co-breathing game (brand, never translated).", "Breath Ripples", "Breath Ripples")
s("ripples_homeCard", "Breathe together", "Home card: start a 3-minute co-breath with a few strangers.", "కలిసి శ్వాస తీసుకుందాం", "Kalisi breathe cheddaam")
s("ripples_homeCardBody", "Three quiet minutes with a few others. No words, no score.", "Under the Home card. Calm; no pressure.", "మరికొందరితో కలిసి మూడు ప్రశాంతమైన నిమిషాలు. మాటలు లేవు, స్కోర్ లేదు.", "Marikondari tho kalisi moodu prashaanthamaina nimishaalu. Maatalu levu, score ledu.")
s("ripples_breatheTogether", "Breathe together", "Room button: invite the room's live members to a 3-minute co-breath.", "కలిసి శ్వాస తీసుకుందాం", "Kalisi breathe cheddaam")
s("ripples_invite", "{name} wants to breathe together · {count}/{capacity}", "In-room banner for 20 s: someone invited the room to Breath Ripples. name = a room pseudonym.", "{name} కలిసి శ్వాస తీసుకోవాలనుకుంటున్నారు · {count}/{capacity}", "{name} kalisi breathe cheyyalanukuntunnaru · {count}/{capacity}", {"name": {"type": "String"}, "count": {"type": "int"}, "capacity": {"type": "int"}})
s("ripples_inviteJoin", "Join", "Banner button: join the room's Breath Ripples invite.", "చేరండి", "Join avvandi")
s("ripples_inviteMine", "Your invite is open · {count}/{capacity}", "Banner for the person who invited the room.", "మీ ఆహ్వానం తెరిచి ఉంది · {count}/{capacity}", "Mee invite open ga undi · {count}/{capacity}", {"count": {"type": "int"}, "capacity": {"type": "int"}})

# ---- lobby -------------------------------------------------------------------------
s("ripples_lobby", "Looking for others to breathe with…", "Lobby while matching (at most 20 s). The pacer already runs.", "కలిసి శ్వాస తీసుకోవడానికి ఇతరుల కోసం చూస్తున్నాం…", "Kalisi breathe cheyadaaniki itharula kosam choostunnaam…")
s("ripples_lobbyHint", "Breathe along while you wait. You can leave any time.", "Under the lobby line.", "వేచి ఉన్నప్పుడు కూడా శ్వాసతో పాటు సాగండి. ఎప్పుడైనా వెళ్ళిపోవచ్చు.", "Wait chestunnappudu kooda breath tho paatu saagandi. Eppudaina vellipovachhu.")
s("ripples_holdHint", "Hold to breathe in, let go to breathe out", "Input hint (hold mode).", "లోపలికి శ్వాసకు పట్టుకోండి, బయటకు వదలడానికి వదిలేయండి", "Lopaliki breathe ki pattukondi, bayataki vadalataaniki vadileyandi")
s("ripples_tapHint", "Tap to switch between breathing in and out", "Input hint (accessible mode: tap to switch).", "లోపలికి, బయటకు మారడానికి ట్యాప్ చేయండి", "Lopaliki, bayataki maaradaaniki tap cheyandi")
s("ripples_breathArea", "Breathing area", "Screen-reader label of the large area you hold (or tap) to breathe.", "శ్వాస ప్రాంతం", "Breathing area")

# ---- unavailable (always with a solo option; never an error screen) -----------------------
s("ripples_offline", "Breathing together needs a connection. Breathe solo instead?", "PRD 14 Offline state.", "కలిసి శ్వాస తీసుకోవడానికి కనెక్షన్ కావాలి. ఒంటరిగా శ్వాస తీసుకుంటారా?", "Kalisi breathe cheyadaaniki connection kaavali. Solo ga breathe chestaara?")
s("ripples_paused", "Breath Ripples is resting for a bit. Breathe solo instead?", "Kill switch on (ripples_paused). Calm.", "Breath Ripples కాసేపు విశ్రాంతి తీసుకుంటోంది. ఒంటరిగా శ్వాస తీసుకుంటారా?", "Breath Ripples kaasepu vishraanti teesukuntondi. Solo ga breathe chestaara?")
s("ripples_suspended", "Breathing together is paused for this account right now. You can still breathe on your own.", "The account's social access is paused (sanction). Never says why.", "ఈ ఖాతాకు కలిసి శ్వాస తీసుకోవడం ప్రస్తుతం ఆగింది. మీరు ఒంటరిగా శ్వాస తీసుకోవచ్చు.", "Ee account ki kalisi breathe cheyadam prasthutham aagindi. Meeru solo ga breathe cheyochhu.")
s("ripples_closed", "This account can't breathe together with others. You can still breathe on your own.", "The account is closed (banned).", "ఈ ఖాతా ఇతరులతో కలిసి శ్వాస తీసుకోలేదు. మీరు ఒంటరిగా శ్వాస తీసుకోవచ్చు.", "Ee account itharula tho kalisi breathe cheyaledu. Meeru solo ga breathe cheyochhu.")
s("ripples_guidelines", "The community guidelines come first. Open Rooms to read them, or breathe on your own for now.", "409 guidelines_required: the guidelines are accepted in Rooms.", "ముందుగా కమ్యూనిటీ మార్గదర్శకాలు. వాటిని చదవడానికి Rooms తెరవండి, లేదా ఇప్పటికి ఒంటరిగా శ్వాస తీసుకోండి.", "Mundu community guidelines. Vaatini chadavadaaniki Rooms open cheyandi, leda ippatiki solo ga breathe cheyandi.")
s("ripples_breatheSolo", "Breathe solo", "Opens the Sanctuary's Breathe pacer.", "ఒంటరిగా శ్వాస", "Solo ga breathe")

# ---- session -----------------------------------------------------------------------------
s("ripples_settle", "Settle in", "Phase word during the 10 s settle-in before the first breath.", "స్థిరపడండి", "Settle avvandi")
s("ripples_fade", "Let it fade", "Phase word during the 10 s fade-out after the last breath.", "మెల్లగా ముగియనివ్వండి", "Mellaga mugiyanivvandi")
s("ripples_together", "{count, plural, =1{Just you and the ocean} other{{count} people breathing together}}", "Intro line: the people who started this session (never echoes or guides).", "{count, plural, =1{మీరు, ఈ సముద్రం మాత్రమే} other{{count} మంది కలిసి శ్వాస తీసుకుంటున్నారు}}", "{count, plural, =1{Meeru, ee samudram maatrame} other{{count} mandi kalisi breathe chestunnaru}}", INT("count"))
s("ripples_echoesJoined", "{count, plural, =1{1 echo joined. It's a recording of a real person who breathed here before.} other{{count} echoes joined. They're recordings of real people who breathed here before.}}", "PRD 14: echoes fill empty seats. Honest: they are recordings, never counted as people.", "{count, plural, =1{1 ప్రతిధ్వని చేరింది. ఇంతకు ముందు ఇక్కడ శ్వాస తీసుకున్న ఒక నిజమైన వ్యక్తి రికార్డింగ్ ఇది.} other{{count} ప్రతిధ్వనులు చేరాయి. ఇంతకు ముందు ఇక్కడ శ్వాస తీసుకున్న నిజమైన వ్యక్తుల రికార్డింగ్‌లు ఇవి.}}", "{count, plural, =1{1 echo join ayyindi. Idi intaku mundu ikkada breathe chesina oka nijamaina vyakti recording.} other{{count} echoes join ayyaayi. Ivi intaku mundu ikkada breathe chesina nijamaina vyaktula recordings.}}", INT("count"))
s("ripples_guides", "{count, plural, =1{A guide light breathes with you.} other{{count} guide lights breathe with you.}}", "Guide lights fill seats while the echo library is small. Never presented as people.", "{count, plural, =1{ఒక గైడ్ వెలుగు మీతో శ్వాస తీసుకుంటుంది.} other{{count} గైడ్ వెలుగులు మీతో శ్వాస తీసుకుంటాయి.}}", "{count, plural, =1{Oka guide light meetho breathe chestundi.} other{{count} guide lights meetho breathe chestaayi.}}", INT("count"))
s("ripples_solo", "Breathing on your own this time. The ocean still listens.", "PRD 14: no echoes available; a solo pacer.", "ఈసారి మీరు ఒంటరిగా శ్వాస తీసుకుంటున్నారు. సముద్రం ఇంకా వింటోంది.", "Ee saari meeru solo ga breathe chestunnaru. Samudram inka vintondi.")
s("ripples_linkLost", "You're breathing on your own for a moment.", "PRD 14: the connection dropped; the pacer continues locally. Never an error.", "కాసేపు మీరు ఒంటరిగా శ్వాస తీసుకుంటున్నారు.", "Kaasepu meeru solo ga breathe chestunnaru.")
s("ripples_alone", "Keep breathing. The ocean is still here.", "After the rejoin window: the session finishes on this phone, gently.", "శ్వాస కొనసాగించండి. సముద్రం ఇంకా ఇక్కడే ఉంది.", "Breathe continue cheyandi. Samudram inka ikkade undi.")
s("ripples_leave", "Leave", "Tooltip of ✕: leave quietly at any time (no penalty, nothing is said to others).", "వెళ్ళిపోండి", "Vellipondi")
s("ripples_accessibleMode", "Accessible mode", "Toggle: tap to switch, tones and stronger haptics when in step (on automatically with a screen reader).", "సులభ మోడ్", "Accessible mode")
s("ripples_accessibleModeHint", "Tap to switch between in and out. Tones and firmer haptics tell you when you're in step with the others.", "Explains accessible mode. Sync is never a number.", "లోపలికి, బయటకు మారడానికి ట్యాప్ చేయండి. మీరు ఇతరులతో కలిసి ఉన్నప్పుడు టోన్లు, గట్టి హ్యాప్టిక్స్ తెలియజేస్తాయి.", "Lopaliki, bayataki maaradaaniki tap cheyandi. Meeru itharula tho step lo unnappudu tones, konchem gattiga haptics cheptaayi.")

# ---- lights (screen reader) ---------------------------------------------------------------------
s("ripples_oceanSemantic", "{count, plural, =1{A night ocean with your light} other{A night ocean with {count} lights}}", "Screen-reader label of the ocean (the art itself is hidden).", "{count, plural, =1{మీ వెలుగుతో ఒక రాత్రి సముద్రం} other{{count} వెలుగులతో ఒక రాత్రి సముద్రం}}", "{count, plural, =1{Mee light tho oka raatri samudram} other{{count} lights tho oka raatri samudram}}", INT("count"))
s("ripples_lightMe", "Your light", "Screen-reader label of your own light.", "మీ వెలుగు", "Mee light")
s("ripples_lightHuman", "{name}'s light", "Screen-reader label of another person's light (tap for mute, block, report).", "{name} వెలుగు", "{name} light", NAME)
s("ripples_lightEcho", "An echo of someone who breathed here before", "Screen-reader label of an echo light (a recording, never a person here now).", "ఇంతకు ముందు ఇక్కడ శ్వాస తీసుకున్న ఒకరి ప్రతిధ్వని", "Intaku mundu ikkada breathe chesina okari echo")
s("ripples_lightGuide", "A guide light, breathing with the pacer", "Screen-reader label of a guide light (never a person).", "పేసర్‌తో శ్వాస తీసుకునే గైడ్ వెలుగు", "Pacer tho breathe chese guide light")
s("ripples_echo", "echo", "Tiny label under an echo light.", "ప్రతిధ్వని", "echo")
s("ripples_guide", "guide", "Tiny label under a guide light.", "గైడ్", "guide")
s("ripples_you", "you", "Tiny label under your own light.", "మీరు", "meeru")

# ---- contact -------------------------------------------------------------------------------------------
s("ripples_pulse", "Send a pulse", "One-tap haptic pulse to everyone in the session.", "పల్స్ పంపండి", "Pulse pampandi")
s("ripples_gestureHug", "Hug", "In-game gesture.", "హగ్", "Hug")
s("ripples_gestureDeepBreath", "Deep breath", "In-game gesture.", "గాఢమైన శ్వాస", "Deep breath")
s("ripples_gestureNotAlone", "You're not alone", "In-game gesture.", "మీరు ఒంటరి కాదు", "Meeru ontari kaadu")
s("ripples_pulseFrom", "{name} sent a pulse", "Announced (and shown) when someone pulses.", "{name} పల్స్ పంపారు", "{name} pulse pampaaru", NAME)
s("ripples_gestureFrom", "{name} · {gesture}", "Shown by a light and announced: who sent which gesture (gesture = its name).", "{name} · {gesture}", "{name} · {gesture}", STR("name", "gesture"))
s("ripples_contactTray", "Send something kind", "Screen-reader label of the pulse + gesture row.", "ఏదైనా మంచిది పంపండి", "Edaina manchidi pampandi")

# ---- a light's sheet (mute / block / report) --------------------------------------------------------------------
s("ripples_mute", "Mute", "Stop this light's pulses, gestures and haptics for you, for this session.", "మ్యూట్", "Mute")
s("ripples_unmute", "Unmute", "Undo mute.", "అన్‌మ్యూట్", "Unmute")
s("ripples_block", "Block", "Block this person: never matched again (they aren't told).", "బ్లాక్", "Block")
s("ripples_report", "Report", "Report this person (reasons, optional note).", "రిపోర్ట్", "Report")
s("ripples_blocked", "Blocked. You won't be matched together again.", "After block. The other person is never told.", "బ్లాక్ చేశారు. మీరిద్దరూ మళ్ళీ కలవరు.", "Block chesaaru. Meeriddaru malli match avvaru.")
s("ripples_reported", "Thank you. Someone from Aura will look at it.", "After a report.", "ధన్యవాదాలు. Aura నుండి ఎవరైనా దీన్ని చూస్తారు.", "Thanks. Aura nundi evaraina deenni choostaaru.")
s("ripples_actionFailed", "That didn't go through. Please try again.", "Mute/block/report failed (connection). No blame.", "అది జరగలేదు. దయచేసి మళ్ళీ ప్రయత్నించండి.", "Adi jaragaledu. Dayachesi malli try cheyandi.")

# ---- end ---------------------------------------------------------------------------------------------------------------
s("ripples_endTitle", "That was a few minutes together.", "End screen. Never a score or how well it went.", "ఇది కలిసి గడిపిన కొన్ని నిమిషాలు.", "Idi kalisi gadipina konni nimishaalu.")
s("ripples_again", "Breathe again", "End screen: start another session (same entry).", "మళ్ళీ శ్వాస తీసుకుందాం", "Malli breathe cheddaam")
s("ripples_backToRoom", "Back to room", "End screen (room sessions): back to the room.", "రూమ్‌కి తిరిగి", "Room ki tirigi")
s("ripples_feelNow", "How do you feel now?", "End screen, optional: opens a check-in (F1).", "ఇప్పుడు ఎలా అనిపిస్తోంది?", "Ippudu ela anipistondi?")
s("ripples_echoToggle", "Let my breathing become an echo", "Echo opt-out switch (on by default, per the privacy notice).", "నా శ్వాస ఒక ప్రతిధ్వనిగా మారనివ్వండి", "Naa breathing oka echo ga maaranivvandi")
s("ripples_echoToggleHint", "An echo keeps only the timing of your breaths, never who you are, so it can't be traced back to you. Turning this off stops future echoes.", "Under the echo switch. Honest about what is kept.", "ప్రతిధ్వని మీ శ్వాస సమయాలను మాత్రమే ఉంచుతుంది, మీరు ఎవరో కాదు, కాబట్టి అది మీ వరకు చేరదు. దీన్ని ఆపితే ఇకపై ప్రతిధ్వనులు రికార్డ్ కావు.", "Echo mee breaths timing maatrame unchutundi, meeru evaro kaadu, kaabatti adi mee varaku raadu. Idi off chesthe inka mundu echoes record kaavu.")
