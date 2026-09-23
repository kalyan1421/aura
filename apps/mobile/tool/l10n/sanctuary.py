# Sanctuary v1 (breathing, grounding, Today's minute), the companion response
# and "A minute for you" after a check-in, guided prompts, Journal
# auto-complete and the F1 backfill. Loaded by tool/l10n_source.py.
# s(key, en, desc, te, te_Latn, ph=None) · edit(key, en=, te=, tl=, desc=)
# te / te_Latn are first drafts: NEEDS NATIVE REVIEW before alpha.
#
# Voice: warm, never clinical. No advice, diagnosis, "why" questions, scores
# or toxic positivity. Every quadrant gets the same warmth and the same
# number of lines.

# ---- Sanctuary tab -------------------------------------------------------------
s("sanctuary_title", "Sanctuary", "Title of the Sanctuary tab: a private, calm space (breathing, grounding).", "ప్రశాంత నిలయం", "Sanctuary")
s("sanctuary_intro", "A quiet place, just for you. Go at your own pace. Nothing here is scored.", "Intro line at the top of the Sanctuary. Calm; nothing is timed against you or scored.", "మీ కోసమే ఒక ప్రశాంతమైన చోటు. మీ వేగంతోనే వెళ్ళండి. ఇక్కడ దేనికీ స్కోర్ లేదు.", "Mee kosame oka prashaanthamaina chotu. Mee speed lone vellandi. Ikkada deeniki score ledu.")
s("sanctuary_todayTitle", "Today's minute", "Section header: one gentle suggestion for today (changes each day).", "ఈరోజు ఒక నిమిషం", "Ee roju oka nimisham")
s("sanctuary_breatheSection", "Breathe", "Section header and title of the breathing session.", "శ్వాస", "Shwaasa")
s("sanctuary_breatheCard", "Breathe with your Aura", "Card that opens the breathing session.", "మీ Auraతో కలిసి శ్వాస తీసుకోండి", "Mee Aura tho kalisi breathe cheyandi")
s("sanctuary_breatheCardBody", "Calm, box or 4-7-8 breathing, for as long as you like.", "Under the breathing card: the three rhythms, any length.", "ప్రశాంతమైన, బాక్స్ లేదా 4-7-8 శ్వాస. మీకు ఎంతసేపు కావాలంటే అంతసేపు.", "Calm, box leda 4-7-8 breathing. Meeku entasepu kaavaalante antasepu.")
s("sanctuary_groundingSection", "Grounding", "Section header: short grounding activities (five senses, hand on heart, three small things).", "మనసు నిలకడకు", "Grounding")
s("sanctuary_begin", "Begin", "Button that opens an optional activity (Today's minute, A minute for you).", "మొదలుపెట్టండి", "Modalupettandi")
s("sanctuary_start", "Start", "Starts a timed activity (breathing, hand on heart).", "మొదలుపెట్టండి", "Start cheyandi")
s("sanctuary_pause", "Pause", "Pauses an activity. Nothing is lost.", "ఆపండి", "Aapandi")
s("sanctuary_resume", "Resume", "Resumes a paused activity.", "మళ్ళీ కొనసాగించండి", "Malli continue cheyandi")
s("sanctuary_finish", "Finish", "Ends an activity early, gently (no penalty).", "ముగించండి", "Muginchandi")
s("sanctuary_next", "Next", "Next step of a step-by-step activity.", "తర్వాత", "Next")
s("sanctuary_progress", "Progress through this session", "Screen-reader label of the quiet progress ring (no numbers, no countdown).", "ఈ సెషన్‌లో ఎంతవరకు వచ్చారు", "Ee session lo entavaraku vachaaru")
s("sanctuary_progressBegun", "Just begun", "Progress ring value: first third.", "ఇప్పుడే మొదలైంది", "Ippude modalaindi")
s("sanctuary_progressHalf", "About halfway", "Progress ring value: middle third.", "దాదాపు సగం", "Daadaapu sagam")
s("sanctuary_progressNearly", "Nearly through", "Progress ring value: last third. Never pressure.", "దాదాపు పూర్తయింది", "Daadaapu purtayindi")
s("sanctuary_progressDone", "Complete", "Progress ring value: finished.", "పూర్తయింది", "Purtayindi")
s("habits_autoLogged", "{habit} is marked done for today.", "After a breathing session or a long note ticks off a habit automatically (F2). habit = the habit's name (Breathe, Journal).", "ఈరోజు {habit} అయినట్టు గుర్తించాం.", "Ee roju {habit} ayyindani mark chesaam.", STR("habit"))

# ---- Breathe session -------------------------------------------------------------
s("breathe_rhythm", "Rhythm", "Header above the three breathing patterns.", "లయ", "Rhythm")
s("breathe_calm", "Calm", "Breathing pattern: in 4, out 6 (the default).", "ప్రశాంతం", "Calm")
s("breathe_calmBody", "In for 4, out for 6. Gentle and steady.", "Describes the calm pattern.", "4 లెక్కలు లోపలికి, 6 బయటకు. మెల్లగా, స్థిరంగా.", "4 counts lopaliki, 6 bayataki. Mellaga, sthiranga.")
s("breathe_box", "Box", "Breathing pattern: in 4, hold 4, out 4, hold 4.", "బాక్స్", "Box")
s("breathe_boxBody", "In, hold, out, hold. Four counts each.", "Describes box breathing.", "లోపలికి, ఆపి, బయటకు, ఆపి. ఒక్కోటి నాలుగు లెక్కలు.", "Lopaliki, aapi, bayataki, aapi. Okkokati naalugu counts.")
s("breathe_478", "4-7-8", "Breathing pattern: in 4, hold 7, out 8 (digits stay as they are).", "4-7-8", "4-7-8")
s("breathe_478Body", "In for 4, hold for 7, out for 8.", "Describes 4-7-8 breathing.", "4 లెక్కలు లోపలికి, 7 ఆపి, 8 బయటకు.", "4 counts lopaliki, 7 aapi, 8 bayataki.")
s("breathe_lightHeaded", "If you feel light-headed, stop and breathe normally.", "Gentle safety note with 4-7-8 breathing (long holds). Calm, not alarming.", "తల తిరుగుతున్నట్టు అనిపిస్తే, ఆపేసి మామూలుగా శ్వాస తీసుకోండి.", "Tala tirugutunnattu anipiste, aapesi maamooluga breathe cheyandi.")
s("breathe_length", "Length", "Header above the session lengths.", "ఎంతసేపు", "Entasepu")
s("breathe_minutes", "{count, plural, =1{1 minute} other{{count} minutes}}", "A session length choice.", "{count, plural, =1{1 నిమిషం} other{{count} నిమిషాలు}}", "{count, plural, =1{1 nimisham} other{{count} nimishaalu}}", INT("count"))
s("breathe_openEnded", "Until I stop", "Session length choice with no set end.", "నేను ఆపేవరకు", "Nenu aapevaraku")
s("breathe_in", "Breathe in", "Breathing cue: inhale. Also announced to screen readers when it begins.", "శ్వాస లోపలికి", "Lopaliki breathe cheyandi")
s("breathe_hold", "Hold", "Breathing cue: hold the breath (box, 4-7-8).", "ఆపి ఉంచండి", "Aapi unchandi")
s("breathe_out", "Breathe out", "Breathing cue: exhale.", "శ్వాస బయటకు", "Bayataki vadalandi")
s("breathe_paused", "Paused. Take your time.", "Shown (and announced) while a breathing session is paused.", "ఆగింది. మీకు కావలసినంత సమయం తీసుకోండి.", "Aagindi. Meeku kaavalsinanta time teesukondi.")
s("breathe_done", "That was time just for you.", "End of a breathing session. Acknowledged, never scored; leaving early is never mentioned.", "ఇది మీ కోసమే తీసుకున్న సమయం.", "Idi mee kosame teesukunna samayam.")
s("breathe_again", "Again", "Starts the same breathing session again.", "మళ్ళీ", "Malli")
s("breathe_land1", "Feel your feet on the ground.", "30-second grounding breath (after a Storm check-in), cue 1.", "మీ పాదాలు నేలను తాకుతున్నట్టు గమనించండి.", "Mee paadaalu nelani taakutunnattu gamaninchandi.")
s("breathe_land2", "Notice three sounds around you.", "30-second grounding breath, cue 2.", "మీ చుట్టూ వినిపిస్తున్న మూడు శబ్దాలను గమనించండి.", "Mee chuttu vinipistunna moodu sounds gamaninchandi.")
s("breathe_keepGoing", "Keep going", "After the 30-second grounding breath: opens the full breathing session.", "కొనసాగిద్దాం", "Continue cheddaam")
s("breathe_land3", "Let your shoulders drop.", "30-second grounding breath, cue 3.", "భుజాలను వదులుగా వదిలేయండి.", "Bhujaalu loose ga vadileyandi.")

# ---- Grounding activities -------------------------------------------------------
s("senses_title", "Five senses", "5-4-3-2-1 grounding: notice things with each sense, step by step.", "ఐదు ఇంద్రియాలు", "Aidu indriyaalu")
s("senses_card", "Notice what's around you, one sense at a time.", "Under the five-senses card.", "మీ చుట్టూ ఉన్నవాటిని ఒక్కో ఇంద్రియంతో గమనించండి.", "Mee chuttu unnavaatini okko indriyam tho gamaninchandi.")
s("senses_intro", "Let's notice what's around you, one sense at a time. Go at your own pace.", "Five senses: intro before the first step.", "మీ చుట్టూ ఉన్నవాటిని ఒక్కో ఇంద్రియంతో గమనిద్దాం. మీ వేగంతోనే వెళ్ళండి.", "Mee chuttu unnavaatini okko indriyam tho gamaniddaam. Mee speed lone vellandi.")
s("senses_see", "Five things you can see", "Five senses, step 1.", "మీకు కనిపిస్తున్న ఐదు వస్తువులు", "Meeku kanipistunna aidu vastuvulu")
s("senses_seeBody", "Look around slowly. Name them in your head or out loud.", "Five senses, step 1 hint.", "నెమ్మదిగా చుట్టూ చూడండి. మనసులో గానీ, పైకి గానీ వాటి పేర్లు చెప్పండి.", "Nemmadiga chuttu choodandi. Manasulo gaani, paiki gaani vaati perlu cheppandi.")
s("senses_touch", "Four things you can touch", "Five senses, step 2 (touch).", "మీరు తాకగలిగే నాలుగు విషయాలు", "Meeru taakagalige naalugu vishayaalu")
s("senses_touchBody", "The chair under you, your clothes, the air on your skin.", "Five senses, step 2 hint.", "మీ కింద కుర్చీ, మీ బట్టలు, మీ చర్మాన్ని తాకే గాలి.", "Mee kinda kurchi, mee battalu, mee charmaanni taake gaali.")
s("senses_hear", "Three things you can hear", "Five senses, step 3.", "మీకు వినిపిస్తున్న మూడు శబ్దాలు", "Meeku vinipistunna moodu sounds")
s("senses_hearBody", "Near or far, loud or soft.", "Five senses, step 3 hint.", "దగ్గరివైనా, దూరానివైనా, పెద్దవైనా, మెల్లనివైనా.", "Daggarivainaa, dooraanivainaa, peddavainaa, mellanivainaa.")
s("senses_smell", "Two things you can smell", "Five senses, step 4.", "మీకు వాసన తెలుస్తున్న రెండు విషయాలు", "Meeku vaasana telustunna rendu vishayaalu")
s("senses_smellBody", "Or two scents you like, if nothing is near.", "Five senses, step 4 hint.", "దగ్గర ఏమీ లేకపోతే, మీకు నచ్చిన రెండు వాసనలు గుర్తు చేసుకోండి.", "Daggara emi lekapote, meeku nachina rendu vaasanalu gurtu chesukondi.")
s("senses_taste", "One thing you can taste", "Five senses, step 5.", "మీకు రుచి తెలుస్తున్న ఒక్క విషయం", "Meeku ruchi telustunna okka vishayam")
s("senses_tasteBody", "Or take a sip of water and notice it.", "Five senses, step 5 hint.", "లేదా కొంచెం నీళ్ళు తాగి ఆ రుచిని గమనించండి.", "Leda konchem neellu taagi aa ruchini gamaninchandi.")
s("senses_step", "Step {step} of {total}", "Screen-reader text for the quiet step dots. Not a score.", "{total}లో {step}వ అడుగు", "{total} lo {step} va step", INT("step", "total"))
s("senses_done", "You're here, in this moment. Nicely done.", "After the fifth sense.", "మీరు ఇక్కడే, ఈ క్షణంలోనే ఉన్నారు. బాగా చేశారు.", "Meeru ikkade, ee kshanam lone unnaru. Baaga chesaaru.")

s("heart_title", "Hand on heart", "Self-compassion touch: a hand on the heart for a minute.", "గుండెపై చేయి", "Gunde meeda cheyyi")
s("heart_card", "A minute of warmth, just for you.", "Under the hand-on-heart card.", "మీ కోసమే ఒక నిమిషం వెచ్చదనం.", "Mee kosame oka nimisham vecchadanam.")
s("heart_intro", "Place a hand on your heart, or anywhere that feels comforting.", "Hand on heart: first cue, shown with the first slow breath. Gentle.", "మీ చేతిని గుండెపై, లేదా మీకు హాయిగా అనిపించే చోట ఉంచండి.", "Mee cheyyini gunde meeda, leda meeku haayiga anipinche chota unchandi.")
s("heart_1", "Feel the warmth of your hand.", "Hand on heart, phrase 1.", "మీ చేతి వెచ్చదనాన్ని గమనించండి.", "Mee cheti vecchadanaanni gamaninchandi.")
s("heart_2", "Breathe gently. There's no rush.", "Hand on heart, phrase 2.", "మెల్లగా శ్వాస తీసుకోండి. తొందర ఏమీ లేదు.", "Mellaga breathe cheyandi. Tondara emi ledu.")
s("heart_3", "Whatever you're feeling is allowed here.", "Hand on heart, phrase 3.", "మీకు ఏం అనిపిస్తున్నా, ఇక్కడ దానికి చోటు ఉంది.", "Meeku em anipistunnaa, ikkada daaniki chotu undi.")
s("heart_4", "Be as kind to yourself as you would be to a friend.", "Hand on heart, phrase 4. Gender-neutral 'friend'.", "స్నేహితుల పట్ల ఎంత దయగా ఉంటారో, మీ పట్ల కూడా అంతే దయగా ఉండండి.", "Friends patla entha dayaga untaaro, mee patla kooda ante dayaga undandi.")
s("heart_done", "Thank you for being gentle with yourself.", "After the hand-on-heart minute.", "మీ పట్ల మీరు మృదువుగా ఉన్నందుకు ధన్యవాదాలు.", "Mee patla meeru mruduvuga unnanduku thanks.")

s("gratitude_title", "Three small things", "Gratitude: think of (or type) three small things that went okay. Nothing is stored.", "మూడు చిన్న విషయాలు", "Moodu chinna vishayaalu")
s("gratitude_card", "Three small things that went okay today.", "Under the three-small-things card.", "ఈరోజు బాగానే జరిగిన మూడు చిన్న విషయాలు.", "Ee roju baagaane jarigina moodu chinna vishayaalu.")
s("gratitude_intro", "Bring three small things from today to mind, one at a time. There's nothing to write.", "Three small things: intro. Prompts only, no typing; nothing is stored.", "ఈరోజు జరిగిన మూడు చిన్న విషయాలను ఒక్కొక్కటిగా గుర్తు తెచ్చుకోండి. ఏమీ రాయనక్కర్లేదు.", "Ee roju jarigina moodu chinna vishayaalanu okkokkatiga gurtu techukondi. Emi raayanakkarledu.")
s("gratitude_1", "One small thing that went okay", "Three small things, step 1.", "బాగానే జరిగిన ఒక చిన్న విషయం", "Baagaane jarigina oka chinna vishayam")
s("gratitude_1Body", "It can be tiny, like a warm drink or a kind word.", "Three small things, step 1 hint.", "అది చాలా చిన్నదైనా పర్వాలేదు, ఒక వేడి పానీయం లేదా ఒక మంచి మాట లాంటిది.", "Adi chaala chinnadainaa parvaaledu, oka vedi drink leda oka manchi maata laantidi.")
s("gratitude_2", "Another small thing", "Three small things, step 2.", "ఇంకొక చిన్న విషయం", "Inkoka chinna vishayam")
s("gratitude_2Body", "Something you saw, heard or did.", "Three small things, step 2 hint.", "మీరు చూసినది, విన్నది లేదా చేసినది ఏదైనా.", "Meeru choosinadi, vinnadi leda chesinadi edainaa.")
s("gratitude_3", "One more small thing", "Three small things, step 3.", "మరొక్క చిన్న విషయం", "Marokka chinna vishayam")
s("gratitude_3Body", "Maybe something about yourself.", "Three small things, step 3 hint.", "బహుశా మీ గురించే ఏదైనా.", "Bahusha mee gurinche edainaa.")
s("gratitude_done", "Hold onto those for a moment. They're yours.", "After the third small thing.", "వాటిని ఒక క్షణం పట్టుకుని ఉండండి. అవి మీవే.", "Vaatini oka kshanam pattukuni undandi. Avi meeve.")

s("savour_intro", "Let's replay one good moment from today, slowly.", "Savour (Sunrise's minute; also in the library): intro. Prompts only.", "ఈరోజు జరిగిన ఒక మంచి క్షణాన్ని మెల్లగా మళ్ళీ గుర్తు చేసుకుందాం.", "Ee roju jarigina oka manchi kshanaanni mellaga malli gurtu chesukundaam.")
s("savour_1", "Bring one good moment from today to mind, however small.", "Savour, step 1.", "ఈరోజు జరిగిన ఒక మంచి క్షణాన్ని గుర్తు తెచ్చుకోండి, ఎంత చిన్నదైనా.", "Ee roju jarigina oka manchi kshanaanni gurtu techukondi, entha chinnadainaa.")
s("savour_2", "Where were you? What could you see and hear?", "Savour, step 2.", "అప్పుడు మీరు ఎక్కడ ఉన్నారు? ఏం కనిపించింది, ఏం వినిపించింది?", "Appudu meeru ekkada unnaru? Em kanipinchindi, em vinipinchindi?")
s("savour_3", "Notice how it feels to remember it now.", "Savour, step 3.", "ఇప్పుడు దాన్ని గుర్తు చేసుకుంటే ఎలా అనిపిస్తోందో గమనించండి.", "Ippudu daanni gurtu chesukunte ela anipistondo gamaninchandi.")
s("savour_done", "Let it stay with you a little longer.", "After the savour steps.", "అది మీతో ఇంకొంచెం సేపు ఉండనివ్వండి.", "Adi meetho inkonchem sepu undanivvandi.")

# ---- One-minute activities (Today's minute, A minute for you) -------------------
s("minute_forYou", "A minute for you", "Optional card in the check-in saved moment, for every quadrant. Never shown right after the crisis sheet.", "మీ కోసం ఒక నిమిషం", "Mee kosam oka nimisham")
s("minute_calmTitle", "One calm minute", "Today's minute: one minute of calm breathing.", "ఒక ప్రశాంత నిమిషం", "Oka prashaanta nimisham")
s("minute_boxTitle", "Box breathing", "Today's minute: one minute of box breathing.", "బాక్స్ శ్వాస", "Box breathing")
s("minute_478Title", "4-7-8 breathing", "Today's minute: 4-7-8 breathing.", "4-7-8 శ్వాస", "4-7-8 breathing")
s("minute_stillnessTitle", "A minute of stillness", "One minute of slow breathing (Moonlight's minute; also in Today's minute).", "ఒక నిమిషం నిశ్చలత", "Oka nimisham nishchalata")
s("minute_stillnessBody", "One quiet minute with the orb.", "Under 'A minute of stillness'.", "గోళంతో కలిసి ఒక నిశ్శబ్ద నిమిషం.", "Orb tho kalisi oka nishabda nimisham.")
s("minute_landTitle", "Thirty seconds to land", "30-second grounding breath (Storm's minute).", "నిలదొక్కుకోవడానికి ముప్పై సెకన్లు", "Niladokkukovadaaniki muppai seconds")
s("minute_landBody", "Three slow breaths with the orb.", "Under 'Thirty seconds to land' (Storm's minute).", "గోళంతో కలిసి మూడు నెమ్మది శ్వాసలు.", "Orb tho kalisi moodu nemmadi shwaasalu.")
s("minute_comfortTitle", "A little comfort", "Hand on heart, offered as Rain's minute.", "కొంచెం ఊరట", "Konchem oorata")
s("minute_comfortBody", "A hand on your heart, and a minute of warmth.", "Under 'A little comfort'.", "గుండెపై ఒక చేయి, ఒక నిమిషం వెచ్చదనం.", "Gunde meeda oka cheyyi, oka nimisham vecchadanam.")
s("minute_savourTitle", "Savour this", "Savouring what feels good (Sunrise's minute).", "దీన్ని ఆస్వాదించండి", "Deenni aaswaadinchandi")
s("minute_savourBody", "Replay one good moment from today.", "Under 'Savour this'.", "ఈరోజు జరిగిన ఒక మంచి క్షణాన్ని మళ్ళీ గుర్తు చేసుకోండి.", "Ee roju jarigina oka manchi kshanaanni malli gurtu chesukondi.")

# ---- Companion response (saved moment) ------------------------------------------
# One line per live check-in, from its quadrant's pool (8 each, same shape and
# warmth for all four), or from the neutral pool after a crisis sheet. Second
# person; the avatar *is* the person, so no line speaks as a separate friend.
# Never advice, diagnosis, cheerleading, "why" or promises (REQ-CMP-03).
_companion_desc = "Companion response after a check-in: one warm line, announced once. Second person, plain words. Never advice ('should', 'try'), diagnosis, cheerleading, a 'why' or a promise. Every quadrant's pool has the same size and warmth."
for key, en, te, tl in [
    ("storm1", "That's a lot at once. Your light is still here.", "ఒకేసారి చాలా అనిపిస్తోంది. మీ వెలుగు ఇంకా ఇక్కడే ఉంది.", "Okesaari chaala anipistondi. Mee velugu inka ikkade undi."),
    ("storm2", "Naming a storm takes courage. You showed up for yourself.", "తుఫానుకు పేరు పెట్టడానికి ధైర్యం కావాలి. మీరు మీ కోసం వచ్చారు.", "Storm ki peru pettadaaniki dhairyam kaavaali. Meeru mee kosam vachaaru."),
    ("storm3", "Big, loud feelings are welcome here. So are you.", "పెద్ద, గట్టి భావాలకు ఇక్కడ చోటు ఉంది. మీకు కూడా.", "Pedda, gatti feelings ki ikkada chotu undi. Meeku kooda."),
    ("storm4", "Stormy days matter too. Thank you for checking in.", "తుఫాను రోజులు కూడా ముఖ్యమైనవే. చెక్-ఇన్ చేసినందుకు ధన్యవాదాలు.", "Storm rojulu kooda mukhyamainave. Check-in chesinanduku thanks."),
    ("storm5", "You named this honestly. That matters.", "మీరు దీన్ని నిజాయితీగా చెప్పారు. అది ముఖ్యం.", "Meeru deenni nijaayiteega cheppaaru. Adi mukhyam."),
    ("storm6", "Storms are part of your sky too.", "తుఫానులు కూడా మీ ఆకాశంలో భాగమే.", "Storms kooda mee aakaasham lo bhaagame."),
    ("storm7", "Whatever is swirling, you noticed it. That counts.", "లోపల ఏం సుడులు తిరుగుతున్నా, మీరు దాన్ని గమనించారు. అది విలువైనది.", "Lopala em sudulu tirugutunnaa, meeru daanni gamaninchaaru. Adi viluvainadi."),
    ("storm8", "Even in a storm, your glow is yours.", "తుఫానులో కూడా, మీ వెలుగు మీదే.", "Storm lo kooda, mee velugu meede."),
    ("rain1", "That feels heavy. Your light is still with you.", "ఇది భారంగా అనిపిస్తోంది. మీ వెలుగు ఇంకా మీతోనే ఉంది.", "Idi bhaaranga anipistondi. Mee velugu inka meethone undi."),
    ("rain2", "Being honest about a low day takes courage. You showed up for yourself.", "నిరుత్సాహమైన రోజు గురించి నిజాయితీగా ఉండటానికి ధైర్యం కావాలి. మీరు మీ కోసం వచ్చారు.", "Low day gurinchi nijaayiteega undadaaniki dhairyam kaavaali. Meeru mee kosam vachaaru."),
    ("rain3", "Slow, heavy feelings are welcome here. So are you.", "నెమ్మదైన, బరువైన భావాలకు ఇక్కడ చోటు ఉంది. మీకు కూడా.", "Nemmadaina, baruvaina feelings ki ikkada chotu undi. Meeku kooda."),
    ("rain4", "Rainy days matter too. Thank you for checking in.", "వాన రోజులు కూడా ముఖ్యమైనవే. చెక్-ఇన్ చేసినందుకు ధన్యవాదాలు.", "Vaana rojulu kooda mukhyamainave. Check-in chesinanduku thanks."),
    ("rain5", "You were honest with yourself today. That matters.", "ఈరోజు మీతో మీరు నిజాయితీగా ఉన్నారు. అది ముఖ్యం.", "Ee roju meetho meeru nijaayiteega unnaru. Adi mukhyam."),
    ("rain6", "Rain is part of your sky too.", "వాన కూడా మీ ఆకాశంలో భాగమే.", "Vaana kooda mee aakaasham lo bhaagame."),
    ("rain7", "However heavy it is, you noticed it. That counts.", "ఎంత భారంగా ఉన్నా, మీరు దాన్ని గమనించారు. అది విలువైనది.", "Entha bhaaranga unnaa, meeru daanni gamaninchaaru. Adi viluvainadi."),
    ("rain8", "Even on grey days, your glow is yours.", "మబ్బు పట్టిన రోజుల్లో కూడా, మీ వెలుగు మీదే.", "Mabbu pattina rojullo kooda, mee velugu meede."),
    ("moonlight1", "A quiet, settled moment. Your light is resting easy.", "నిశ్శబ్దమైన, స్థిరమైన క్షణం. మీ వెలుగు హాయిగా విశ్రాంతి తీసుకుంటోంది.", "Nishabdamaina, sthiramaina kshanam. Mee velugu haayiga rest teesukuntondi."),
    ("moonlight2", "Noticing a quiet moment is worth something. You showed up for yourself.", "ఒక ప్రశాంత క్షణాన్ని గమనించడం విలువైనది. మీరు మీ కోసం వచ్చారు.", "Oka prashaanta kshanaanni gamaninchadam viluvainadi. Meeru mee kosam vachaaru."),
    ("moonlight3", "Soft, easy feelings are welcome here. So are you.", "మెత్తని, హాయైన భావాలకు ఇక్కడ చోటు ఉంది. మీకు కూడా.", "Mettani, haayaina feelings ki ikkada chotu undi. Meeku kooda."),
    ("moonlight4", "Gentle days matter too. Thank you for checking in.", "మెల్లని రోజులు కూడా ముఖ్యమైనవే. చెక్-ఇన్ చేసినందుకు ధన్యవాదాలు.", "Mellani rojulu kooda mukhyamainave. Check-in chesinanduku thanks."),
    ("moonlight5", "You took a moment to notice this. That matters.", "దీన్ని గమనించడానికి మీరు ఒక క్షణం తీసుకున్నారు. అది ముఖ్యం.", "Deenni gamaninchadaaniki meeru oka kshanam teesukunnaru. Adi mukhyam."),
    ("moonlight6", "Moonlight is part of your sky too.", "వెన్నెల కూడా మీ ఆకాశంలో భాగమే.", "Vennela kooda mee aakaasham lo bhaagame."),
    ("moonlight7", "However small this calm is, you noticed it. That counts.", "ఈ ప్రశాంతత ఎంత చిన్నదైనా, మీరు దాన్ని గమనించారు. అది విలువైనది.", "Ee prashaanthata entha chinnadainaa, meeru daanni gamaninchaaru. Adi viluvainadi."),
    ("moonlight8", "In the quiet, your glow is yours.", "ఈ నిశ్శబ్దంలో, మీ వెలుగు మీదే.", "Ee nishabdam lo, mee velugu meede."),
    ("sunrise1", "A bright moment. Your light is shining.", "వెలుగుతో నిండిన క్షణం. మీ వెలుగు ప్రకాశిస్తోంది.", "Velugu tho nindina kshanam. Mee velugu prakaashistondi."),
    ("sunrise2", "Noticing a good moment is worth something. You showed up for yourself.", "ఒక మంచి క్షణాన్ని గమనించడం విలువైనది. మీరు మీ కోసం వచ్చారు.", "Oka manchi kshanaanni gamaninchadam viluvainadi. Meeru mee kosam vachaaru."),
    ("sunrise3", "Big, bright feelings are welcome here. So are you.", "పెద్ద, ప్రకాశవంతమైన భావాలకు ఇక్కడ చోటు ఉంది. మీకు కూడా.", "Pedda, prakaashavantamaina feelings ki ikkada chotu undi. Meeku kooda."),
    ("sunrise4", "Bright days matter too. Thank you for checking in.", "వెలుగు రోజులు కూడా ముఖ్యమైనవే. చెక్-ఇన్ చేసినందుకు ధన్యవాదాలు.", "Velugu rojulu kooda mukhyamainave. Check-in chesinanduku thanks."),
    ("sunrise5", "You let yourself notice this. That matters.", "దీన్ని గమనించడానికి మీకు మీరు అవకాశం ఇచ్చారు. అది ముఖ్యం.", "Deenni gamaninchadaaniki meeku meeru chance ichaaru. Adi mukhyam."),
    ("sunrise6", "Sunrise is part of your sky too.", "సూర్యోదయం కూడా మీ ఆకాశంలో భాగమే.", "Sunrise kooda mee aakaasham lo bhaagame."),
    ("sunrise7", "However big or small this is, you noticed it. That counts.", "ఇది పెద్దదైనా, చిన్నదైనా, మీరు దాన్ని గమనించారు. అది విలువైనది.", "Idi peddadainaa, chinnadainaa, meeru daanni gamaninchaaru. Adi viluvainadi."),
    ("sunrise8", "In this brightness, your glow is yours.", "ఈ సంతోషంలో, మీ వెలుగు మీదే.", "Ee santosham lo, mee velugu meede."),
]:
    s(f"companion_{key}", en, _companion_desc, te, tl)

# After a crisis sheet: a small neutral pool, the same for every quadrant
# (REQ-CMP-04). Quiet and steady; no mood words.
for key, en, te, tl in [
    ("neutral1", "Thank you for checking in.", "చెక్-ఇన్ చేసినందుకు ధన్యవాదాలు.", "Check-in chesinanduku thanks."),
    ("neutral2", "You showed up for yourself.", "మీరు మీ కోసం వచ్చారు.", "Meeru mee kosam vachaaru."),
    ("neutral3", "Your light is still here.", "మీ వెలుగు ఇంకా ఇక్కడే ఉంది.", "Mee velugu inka ikkade undi."),
    ("neutral4", "There's no rush here.", "ఇక్కడ తొందర ఏమీ లేదు.", "Ikkada tondara emi ledu."),
]:
    s(f"companion_{key}", en, "Companion line after a check-in that showed the support sheet: neutral, the same for every quadrant. Never advice or a promise.", te, tl)

# ---- Guided prompts (check-in note, capsule composer) ---------------------------
# Shown as the empty field's hint only: optional, skippable, never required.
for key, en, te, tl in [
    ("note1", "What's one small thing that helped today?", "ఈరోజు కొంచెం సహాయపడిన ఒక చిన్న విషయం ఏది?", "Ee roju konchem help chesina oka chinna vishayam edi?"),
    ("note2", "What's on your mind right now?", "ఇప్పుడు మీ మనసులో ఏముంది?", "Ippudu mee manasulo emundi?"),
    ("note3", "What would you like to remember about today?", "ఈరోజు గురించి మీరు ఏం గుర్తుంచుకోవాలనుకుంటున్నారు?", "Ee roju gurinchi meeru em gurtunchukovaalanukuntunnaru?"),
    ("storm1", "What's taking up the most room right now?", "ఇప్పుడు మీ మనసులో ఎక్కువ చోటు తీసుకుంటున్నది ఏది?", "Ippudu mee manasulo ekkuva chotu teesukuntunnadi edi?"),
    ("storm2", "If this feeling could speak, what would it say?", "ఈ భావన మాట్లాడగలిగితే, అది ఏం చెబుతుంది?", "Ee feeling maatlaadagaligite, adi em chebutundi?"),
    ("storm3", "What's one thing you could set down, even for a minute?", "ఒక్క నిమిషమైనా పక్కన పెట్టగలిగే ఒక విషయం ఏది?", "Okka nimishamainaa pakkana pettagalige oka vishayam edi?"),
    ("rain1", "What would feel gentle right now?", "ఇప్పుడు మీకు ఏది హాయిగా అనిపిస్తుంది?", "Ippudu meeku edi haayiga anipistundi?"),
    ("rain2", "What's weighing on you today?", "ఈరోజు మీ మనసుపై బరువుగా ఉన్నది ఏది?", "Ee roju mee manasu meeda baruvuga unnadi edi?"),
    ("rain3", "Who or what has felt kind to you lately?", "ఈ మధ్య మీ పట్ల దయగా అనిపించింది ఎవరు, లేదా ఏది?", "Ee madhya mee patla dayaga anipinchindi evaru, leda edi?"),
    ("moonlight1", "What's helping you feel settled?", "మీరు స్థిరంగా ఉండటానికి ఏది సహాయపడుతోంది?", "Meeru sthiranga undadaaniki edi help chestondi?"),
    ("moonlight2", "What made today feel softer?", "ఈరోజు ఏది హాయిగా అనిపించేలా చేసింది?", "Ee roju edi haayiga anipinchela chesindi?"),
    ("moonlight3", "What would you like to keep from this moment?", "ఈ క్షణం నుంచి మీరు ఏం దాచుకోవాలనుకుంటున్నారు?", "Ee kshanam nunchi meeru em daachukovaalanukuntunnaru?"),
    ("sunrise1", "What's lighting you up today?", "ఈరోజు మీలో ఉత్సాహం నింపుతున్నది ఏది?", "Ee roju meelo utsaaham nimputunnadi edi?"),
    ("sunrise2", "What went well that you'd like to remember?", "బాగా జరిగిన ఏ విషయాన్ని మీరు గుర్తుంచుకోవాలనుకుంటున్నారు?", "Baaga jarigina e vishayaanni meeru gurtunchukovaalanukuntunnaru?"),
    ("sunrise3", "Who would you like to share this with?", "దీన్ని మీరు ఎవరితో పంచుకోవాలనుకుంటున్నారు?", "Deenni meeru evaritho panchukovaalanukuntunnaru?"),
    ("capsule1", "What do you want future you to know?", "భవిష్యత్తులోని మీకు మీరు ఏం తెలియజేయాలనుకుంటున్నారు?", "Future lo unna meeku meeru em teliyajeyaalanukuntunnaru?"),
    ("capsule2", "What's helping you right now that you might forget?", "ఇప్పుడు మీకు సహాయపడుతున్న, తర్వాత మర్చిపోయే అవకాశం ఉన్న విషయం ఏది?", "Ippudu meeku help chestunna, tarvaata marchipoye avakaasham unna vishayam edi?"),
    ("capsule3", "What would you say to yourself on a hard day?", "కష్టమైన రోజున మీకు మీరు ఏం చెప్పుకుంటారు?", "Kashtamaina roju na meeku meeru em cheppukuntaaru?"),
    ("capsuleStorm", "What helps when everything feels like too much?", "అంతా ఎక్కువైపోయినట్టు అనిపించినప్పుడు ఏది సహాయపడుతుంది?", "Antaa ekkuvaipoyinattu anipinchinappudu edi help chestundi?"),
    ("capsuleRain", "What would you want to hear on a heavy day?", "భారమైన రోజున మీరు ఏం వినాలనుకుంటారు?", "Bhaaramaina roju na meeru em vinaalanukuntaaru?"),
    ("capsuleMoonlight", "What helps you find this calm again?", "ఈ ప్రశాంతతను మళ్ళీ పొందడానికి ఏది సహాయపడుతుంది?", "Ee prashaanthatanu malli pondadaaniki edi help chestundi?"),
    ("capsuleSunrise", "What would you like to celebrate with future you?", "భవిష్యత్తులోని మీతో మీరు ఏ సంతోషాన్ని పంచుకోవాలనుకుంటున్నారు?", "Future lo unna meetho meeru e santoshaanni panchukovaalanukuntunnaru?"),
]:
    s(f"prompt_{key}", en, "Guided writing prompt, shown only as the empty field's hint (optional, skippable). Warm, open, never a 'why'.", te, tl)

s("prompt_another", "Another prompt", "Shows a different guided prompt in the empty note (the prompt is only a hint, never saved).", "ఇంకో ప్రశ్న", "Inko prashna")
s("prompt_settingsTitle", "Writing prompts", "Settings switch: show a gentle guided prompt in the empty note field.", "రాయడానికి సూచనలు", "Raayadaaniki prompts")
s("prompt_settingsBody", "A gentle question in the empty note. Never saved.", "Under the Settings switch for guided prompts.", "ఖాళీ నోట్‌లో ఒక మృదువైన ప్రశ్న. ఇది ఎప్పుడూ సేవ్ అవ్వదు.", "Khaali note lo oka gentle prashna. Idi eppudu save avvadu.")

# ---- Backfill (F1: up to 7 days back; earns nothing) -----------------------------
s("backfill_add", "Add a past check-in", "History button: add a check-in for one of the last 7 days.", "గత చెక్-ఇన్ జోడించండి", "Past check-in add cheyandi")
s("backfill_pickTitle", "Which day?", "Title of the day picker for a past check-in.", "ఏ రోజు?", "Ye roju?")
s("backfill_pickBody", "{count, plural, =1{You can add a check-in for yesterday.} other{You can add a check-in for any of the last {count} days.}}", "Under the day picker title.", "{count, plural, =1{నిన్నటి కోసం చెక్-ఇన్ జోడించవచ్చు.} other{గత {count} రోజుల్లో ఏ రోజుకైనా చెక్-ఇన్ జోడించవచ్చు.}}", "{count, plural, =1{Ninnati kosam check-in add cheyochu.} other{Gata {count} rojullo ye roju kainaa check-in add cheyochu.}}", INT("count"))
s("backfill_title", "How were you feeling?", "Title of the check-in picker for a past day.", "అప్పుడు మీకు ఎలా అనిపించింది?", "Appudu meeku ela anipinchindi?")
s("backfill_forDay", "Check-in for {day}", "Screen-reader label of the day chip on a past check-in, e.g. 'Check-in for Tuesday, October 6'. Tapping it changes the day.", "{day} కోసం చెక్-ఇన్", "{day} kosam check-in", STR("day"))
s("backfill_changeDay", "Change day", "Screen-reader hint on the day of a past check-in.", "రోజు మార్చండి", "Roju maarchandi")
s("backfill_outOfRange", "Past check-ins can go up to a week back. Could you pick another day?", "When the picked day has moved out of the 7-day window (e.g. past 04:00). The selection is kept.", "గత చెక్-ఇన్‌లు ఒక వారం వెనక్కి వరకే జోడించగలం. వేరే రోజు ఎంచుకుంటారా?", "Past check-ins oka vaaram venakki varake add cheyagalam. Vere roju select chesukuntaara?")
s("backfill_savedTitle", "Added to your sky", "After saving a check-in for a past day (PRD 06d edge case).", "మీ ఆకాశంలో చేరింది", "Mee aakaasham lo cherindi")
s("backfill_savedDay", "Saved for {day}.", "Under 'Added to your sky': the day it was saved for, e.g. 'Saved for Tuesday, October 6.'", "{day} కోసం సేవ్ అయింది.", "{day} kosam save ayyindi.", STR("day"))
s("backfill_savedBody", "Starlight comes from check-ins made on the day itself.", "After saving a past check-in: why no Starlight shows (PRD F1: backfills earn nothing). Calm, no loss words.", "Starlight ఆ రోజే చేసిన చెక్-ఇన్‌ల నుంచి వస్తుంది.", "Starlight aa roje chesina check-ins nunchi vastundi.")
s("history_addedLater", "Added later", "Shown instead of the time on a check-in that was added for a past day.", "తర్వాత జోడించింది", "Tarvaata add chesindi")
s("history_whenAddedLater", "{day} · added later", "When a past-day check-in is for, on its page, e.g. 'Yesterday · added later'.", "{day} · తర్వాత జోడించింది", "{day} · tarvaata add chesindi", STR("day"))
