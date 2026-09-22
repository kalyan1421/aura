#!/usr/bin/env python3
"""Single source for Aura's UI copy -> lib/l10n/app_*.arb.

    python3 tool/l10n_source.py && flutter gen-l10n

Telugu (te) and Tenglish (te_Latn) copy is a first draft by the dev team:
NEEDS NATIVE REVIEW before alpha (see README "Localization").
Hindi (hi) and Hinglish (hi_Latn) are beta: the files exist so the pipeline
is ready, and every string falls back to English until translated (TODO).

Rules (PRD Localization): ICU plurals/placeholders only, no concatenation;
no gendered forms (respectful "meeru"); brand terms stay Latin (Aura,
Starlight). Room/quadrant theme names stay English in Tenglish.
"""
import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "lib", "l10n")

# key: (en, description, placeholders | None, te, te_Latn)
S = {}


def s(key, en, desc, te, tl, ph=None):
    S[key] = (en, desc, ph, te, tl)


INT = lambda *names: {n: {"type": "int"} for n in names}  # noqa: E731
STR = lambda *names: {n: {"type": "String"} for n in names}  # noqa: E731

# ---- common ---------------------------------------------------------------
s("appTitle", "Aura", "App name (brand, never translated).", "Aura", "Aura")
s("common_continue", "Continue", "Primary button to go to the next step. Calm.", "కొనసాగించండి", "Continue cheyandi")
s("common_back", "Back", "Back button label.", "వెనక్కి", "Venakki")
s("common_done", "Done", "Finish a flow.", "అయిపోయింది", "Aipoyindi")
s("common_notNow", "Not now", "Gentle dismiss.", "ఇప్పుడు కాదు", "Ippudu kaadu")
s("common_cancel", "Cancel", "Cancel an action.", "రద్దు చేయండి", "Cancel cheyandi")
s("common_close", "Close", "Close a sheet or screen.", "మూసివేయండి", "Close cheyandi")
s("common_comingSoon", "Coming soon", "Label on features not built yet. Warm, not a tease.", "త్వరలో వస్తుంది", "Tvaralo vastundi")

# ---- help / crisis (F9) ---------------------------------------------------
s("help_button", "I need help now", "Always-visible help button on Home and other screens. Must feel safe to tap.", "నాకు ఇప్పుడే సహాయం కావాలి", "Naaku ippude help kaavali")
s("help_title", "Help is here", "Support sheet title when opened from the help button.", "సహాయం ఇక్కడే ఉంది", "Help ikkade undi")
s("help_subtitle", "You don't have to carry this alone. Reach out now, or take a minute to breathe.", "Support sheet subtitle. Warm, never clinical.", "దీన్ని మీరు ఒంటరిగా మోయాల్సిన అవసరం లేదు. ఇప్పుడే ఎవరినైనా సంప్రదించండి, లేదా ఒక నిమిషం శ్వాస మీద ధ్యాస పెట్టండి.", "Idi meeru okkare moyyalsina avasaram ledu. Ippude evarinaina contact cheyandi, leda oka nimisham breath meeda dhyaasa pettandi.")
s("help_crisisTitle", "It sounds like a lot right now.", "Support sheet title after a note matched the crisis lexicon. Never alarming.", "ఇప్పుడు చాలా భారంగా ఉన్నట్టుంది.", "Ippudu chaala bhaaranga unnattundi.")
s("help_crisisSubtitle", "You don't have to carry it alone. Your check-in is saved.", "Support sheet subtitle after a crisis-lexicon match.", "దీన్ని మీరు ఒంటరిగా మోయాల్సిన అవసరం లేదు. మీ చెక్-ఇన్ సేవ్ అయింది.", "Idi meeru okkare moyyalsina avasaram ledu. Mee check-in save ayyindi.")
s("help_teleManas", "Tele-MANAS · free, 24×7", "India national mental-health helpline 14416.", "Tele-MANAS · ఉచితం, 24×7", "Tele-MANAS · free, 24×7")
s("help_teleManasTollFree", "Tele-MANAS toll-free", "India Tele-MANAS toll-free number 1-800-891-4416.", "Tele-MANAS టోల్-ఫ్రీ", "Tele-MANAS toll-free")
s("help_emergency112", "Emergency", "India emergency number 112 (the number is shown separately).", "అత్యవసరం", "Emergency")
s("help_childline", "Childline · for under-18s", "India Childline 1098, shown to under-18s (number shown separately).", "Childline · 18 ఏళ్ల లోపు వారికి", "Childline · 18 ella lopu vaallaki")
s("help_us988", "Suicide & Crisis Lifeline · call or text", "US crisis line 988 (number shown separately).", "Suicide & Crisis Lifeline · కాల్ లేదా మెసేజ్", "Suicide & Crisis Lifeline · call leda text")
s("help_otherEmergency", "If you're in danger right now, please call your local emergency number.", "Shown in countries without a listed helpline. Never an empty list.", "మీరు ఇప్పుడు ప్రమాదంలో ఉంటే, దయచేసి మీ ప్రాంతంలోని అత్యవసర నంబర్‌కు కాల్ చేయండి.", "Meeru ippudu danger lo unte, dayachesi mee local emergency number ki call cheyandi.")
s("help_callSemantic", "Call {name}, {number}", "Screen-reader label for a tap-to-call helpline row.", "{name}కి కాల్ చేయండి, {number}", "{name} ki call cheyandi, {number}", STR("name", "number"))
s("help_groundingTitle", "Sixty seconds to land", "Title of the 60-second grounding exercise.", "అరవై సెకన్లు, మెల్లగా", "Sixty seconds, mellaga")
s("help_groundingBody", "Breathe with the circle. Everything else can wait a minute.", "Grounding exercise intro.", "ఈ వృత్తంతో పాటు శ్వాస తీసుకోండి. మిగతావన్నీ ఒక్క నిమిషం ఆగవచ్చు.", "Ee circle tho paatu breathe cheyandi. Migathavanni oka nimisham aagochu.")
s("help_groundingStart", "Start", "Start grounding.", "మొదలుపెట్టండి", "Start cheyandi")
s("help_groundingPause", "Pause", "Pause grounding.", "ఆపండి", "Aapandi")
s("help_groundingResume", "Resume", "Resume grounding.", "మళ్ళీ కొనసాగించండి", "Malli continue cheyandi")
s("help_breatheIn", "Breathe in", "Grounding pacer, inhale.", "శ్వాస లోపలికి", "Lopaliki breathe cheyandi")
s("help_breatheOut", "Breathe out", "Grounding pacer, exhale.", "శ్వాస బయటకు", "Bayataki vadalandi")
s("help_ground1", "Feel your feet on the ground.", "Grounding prompt 1.", "మీ పాదాలు నేలను తాకుతున్నట్టు గమనించండి.", "Mee paadaalu nelani taakutunnattu gamaninchandi.")
s("help_ground2", "Notice five things you can see.", "Grounding prompt 2.", "మీకు కనిపిస్తున్న ఐదు వస్తువులను గమనించండి.", "Meeku kanipistunna aidu vastuvulni gamaninchandi.")
s("help_ground3", "Notice three sounds around you.", "Grounding prompt 3.", "మీ చుట్టూ వినిపిస్తున్న మూడు శబ్దాలను గమనించండి.", "Mee chuttu vinipistunna moodu sounds gamaninchandi.")
s("help_ground4", "Let your shoulders drop.", "Grounding prompt 4.", "భుజాలను వదులుగా వదిలేయండి.", "Bhujaalu loose ga vadileyandi.")
s("help_ground5", "You're here. That's enough for now.", "Grounding prompt 5.", "మీరు ఇక్కడే ఉన్నారు. ఇప్పటికి అది చాలు.", "Meeru ikkade unnaru. Ippatiki adi chaalu.")
s("help_groundingDone", "Well done. Stay as long as you need.", "Grounding finished.", "బాగా చేశారు. మీకు కావలసినంత సేపు ఇక్కడే ఉండండి.", "Baaga chesaru. Meeku kaavalsinanta sepu ikkade undandi.")
s("help_secondsLeft", "{seconds, plural, =1{1 second left} other{{seconds} seconds left}}", "Grounding countdown (also read by screen readers).", "{seconds, plural, =1{1 సెకను మిగిలింది} other{{seconds} సెకన్లు మిగిలాయి}}", "{seconds, plural, =1{1 second migilindi} other{{seconds} seconds migilaayi}}", INT("seconds"))
s("help_disclaimer", "Aura is not a medical device or an emergency service.", "Legal disclaimer (Play health policy, Apple 1.4.1).", "Aura వైద్య పరికరం కాదు, అత్యవసర సేవ కూడా కాదు.", "Aura medical device kaadu, emergency service kooda kaadu.")
s("help_backToCheckin", "Back to my check-in", "Close the crisis sheet after saving.", "నా చెక్-ఇన్‌కి తిరిగి వెళ్ళండి", "Naa check-in ki tirigi vellandi")

# ---- onboarding (F8) ------------------------------------------------------
s("welcome_title", "Welcome to Aura", "Welcome screen title.", "Auraకి స్వాగతం", "Aura ki swaagatam")
s("welcome_body", "A quiet place to notice how you feel. Your check-ins stay private, and your Aura grows a little each time you show up.", "Welcome screen body. Calm, inviting.", "మీ మనసు ఎలా ఉందో ప్రశాంతంగా గమనించుకునే చోటు. మీ చెక్-ఇన్‌లు మీకు మాత్రమే, మీరు వచ్చిన ప్రతిసారీ మీ Aura కొంచెం పెరుగుతుంది.", "Mee manasu ela undo prashaanthanga gamaninchukune chotu. Mee check-ins private ga untaayi, meeru vachina prati saari mee Aura konchem perugutundi.")
s("welcome_begin", "Begin", "Welcome CTA.", "మొదలుపెడదాం", "Modalupedadam")
s("dob_title", "When's your birthday?", "DOB gate title. Neutral; never mentions 13 or 18.", "మీ పుట్టినరోజు ఎప్పుడు?", "Mee birthday eppudu?")
s("dob_body", "We ask everyone. It stays private and is never shown to anyone.", "DOB gate body.", "అందరినీ ఇదే అడుగుతాం. ఇది గోప్యంగా ఉంటుంది, ఎవరికీ కనిపించదు.", "Andarini ide adugutaam. Idi private ga untundi, evariki kanipinchadu.")
s("dob_day", "Day", "DOB picker: day.", "రోజు", "Roju")
s("dob_month", "Month", "DOB picker: month.", "నెల", "Nela")
s("dob_year", "Year", "DOB picker: year.", "సంవత్సరం", "Samvatsaram")
s("dob_invalid", "That date doesn't exist. Could you check it?", "DOB validation (e.g. 30 Feb).", "ఆ తేదీ ఉండదు. ఒకసారి చూసుకుంటారా?", "Aa date undadu. Okasari choosukuntaara?")
s("dob_future", "That date hasn't happened yet. Could you check it?", "DOB validation (future date).", "ఆ తేదీ ఇంకా రాలేదు. ఒకసారి చూసుకుంటారా?", "Aa date inka raaledu. Okasari choosukuntaara?")
s("blocked_title", "Aura is made for people 13 and older.", "Under-13 block screen title. Kind.", "Aura 13 ఏళ్లు, ఆ పైబడిన వారి కోసం.", "Aura 13 ella paiga unna vaalla kosam.")
s("blocked_body", "We'd love to see you then.", "Under-13 block screen body.", "అప్పుడు మిమ్మల్ని తప్పకుండా కలుస్తాం.", "Appudu mimmalni tappakunda kalustaam.")
s("blocked_helpIndia", "If you want to talk to someone now, Childline is free on 1098. In an emergency, call 112.", "Under-13 help line, India.", "ఇప్పుడే ఎవరితోనైనా మాట్లాడాలనిపిస్తే, Childline 1098కి ఉచితంగా కాల్ చేయండి. అత్యవసరమైతే 112కి కాల్ చేయండి.", "Ippude evaritho ainaa maatlaadaalanipiste, Childline 1098 ki free ga call cheyandi. Emergency aite 112 ki call cheyandi.")
s("blocked_helpOther", "If you want to talk to someone now, please reach out to an adult you trust.", "Under-13 help line, other countries.", "ఇప్పుడే ఎవరితోనైనా మాట్లాడాలనిపిస్తే, మీరు నమ్మే పెద్దవాళ్ళతో మాట్లాడండి.", "Ippude evaritho ainaa maatlaadaalanipiste, meeru namme peddavaalla tho maatlaadandi.")
s("language_title", "Which language feels like home?", "Language picker title.", "ఏ భాష మీకు సొంతంగా అనిపిస్తుంది?", "Ye bhaasha meeku sontham anipistundi?")
s("language_body", "You can change this any time in Settings.", "Language picker body.", "దీన్ని సెట్టింగ్‌లలో ఎప్పుడైనా మార్చుకోవచ్చు.", "Deenni Settings lo eppudaina maarchukovachu.")
s("language_teLatnHint", "Telugu in English letters", "Explains Tenglish.", "తెలుగు, ఇంగ్లీష్ అక్షరాల్లో", "Telugu, English aksharaallo")
s("language_hiLatnHint", "Hindi in English letters", "Explains Hinglish.", "హిందీ, ఇంగ్లీష్ అక్షరాల్లో", "Hindi, English aksharaallo")
s("language_beta", "Beta", "Badge on beta languages.", "బీటా", "Beta")
s("signin_title", "Keep your Aura safe", "Sign-in title.", "మీ Auraని భద్రంగా ఉంచండి", "Mee Aura ni safe ga unchandi")
s("signin_body", "Sign in with your email so your Aura can follow you to a new phone. No name, no phone number, no password.", "Sign-in body. Reassuring about privacy.", "మీ ఈమెయిల్‌తో సైన్ ఇన్ చేయండి, అప్పుడు కొత్త ఫోన్‌లో కూడా మీ Aura మీతోనే ఉంటుంది. పేరు, ఫోన్ నంబర్, పాస్‌వర్డ్ ఏవీ అక్కర్లేదు.", "Mee email tho sign in cheyandi, appudu kotta phone lo kooda mee Aura meetho untundi. Peru, phone number, password edee akkarledu.")
s("signin_emailLabel", "Email", "Email field label.", "ఈమెయిల్", "Email")
s("signin_sendCode", "Email me a code", "Send OTP button.", "నాకు కోడ్ పంపండి", "Naaku code pampandi")
s("signin_codeSent", "We sent a 6-digit code to {email}. You can also tap the link in that email.", "After sending the OTP.", "{email}కి 6 అంకెల కోడ్ పంపాం. ఆ ఈమెయిల్‌లోని లింక్‌ను కూడా నొక్కవచ్చు.", "{email} ki 6-digit code pampaam. Aa email lo unna link ni kooda tap cheyochu.", STR("email"))
s("signin_codeLabel", "6-digit code", "OTP field label.", "6 అంకెల కోడ్", "6-digit code")
s("signin_verify", "Continue", "Verify OTP button.", "కొనసాగించండి", "Continue cheyandi")
s("signin_resend", "Send a fresh code", "Resend OTP.", "కొత్త కోడ్ పంపండి", "Kotta code pampandi")
s("signin_changeEmail", "Use a different email", "Go back to the email step.", "వేరే ఈమెయిల్ వాడండి", "Vere email vaadandi")
s("signin_error", "That didn't go through. Try again, or sign in another way.", "Sign-in failed. No blame, no exclamation.", "అది జరగలేదు. మళ్ళీ ప్రయత్నించండి, లేదా వేరే విధంగా సైన్ ఇన్ చేయండి.", "Adi jaragaledu. Malli try cheyandi, leda vere vidhamga sign in cheyandi.")
s("signin_codeExpired", "This code has timed out. We'll send a fresh one.", "OTP expired.", "ఈ కోడ్ గడువు ముగిసింది. కొత్తది పంపుతాం.", "Ee code time aipoyindi. Kottadi pamputaam.")
s("signin_invalidCode", "That code doesn't match. Could you check it?", "Wrong OTP.", "ఆ కోడ్ సరిపోలలేదు. ఒకసారి చూసుకుంటారా?", "Aa code match avvaledu. Okasari choosukuntaara?")
s("signin_invalidEmail", "That email doesn't look quite right.", "Invalid email.", "ఆ ఈమెయిల్ సరిగ్గా ఉన్నట్టు లేదు.", "Aa email correct ga unnattu ledu.")
s("signin_apple", "Continue with Apple", "Sign in with Apple (disabled until enabled by flag).", "Appleతో కొనసాగించండి", "Apple tho continue cheyandi")
s("signin_google", "Continue with Google", "Sign in with Google (disabled until enabled by flag).", "Googleతో కొనసాగించండి", "Google tho continue cheyandi")
s("signin_offline", "You're offline. Pick your first mood now. We'll finish setting up when you're connected.", "Offline at first launch (PRD States).", "మీరు ఆఫ్‌లైన్‌లో ఉన్నారు. ముందు మీ మొదటి మూడ్ ఎంచుకోండి. కనెక్ట్ అయ్యాక మిగతా సెటప్ పూర్తి చేస్తాం.", "Meeru offline lo unnaru. Mundu mee first mood select cheyandi. Connect ayyaaka migataa setup complete chestaam.")
s("signin_offlineContinue", "Check in now", "Continue offline to the first check-in.", "ఇప్పుడే చెక్-ఇన్ చేయండి", "Ippude check-in cheyandi")
s("signin_unavailable", "Sign-in isn't set up in this build yet. Your check-ins will stay on this phone for now.", "Dev builds without Supabase config.", "ఈ బిల్డ్‌లో సైన్-ఇన్ ఇంకా సెట్ కాలేదు. ప్రస్తుతానికి మీ చెక్-ఇన్‌లు ఈ ఫోన్‌లోనే ఉంటాయి.", "Ee build lo sign-in inka set avvaledu. Prastutaaniki mee check-ins ee phone lone untaayi.")
s("signin_continueLocal", "Continue on this phone", "Skip sign-in when unavailable.", "ఈ ఫోన్‌లోనే కొనసాగించండి", "Ee phone lone continue cheyandi")

# ---- check-in (F1) --------------------------------------------------------
s("checkin_title", "How are you feeling?", "Check-in screen title.", "మీకు ఇప్పుడు ఎలా అనిపిస్తోంది?", "Meeku ippudu ela anipistondi?")
s("checkin_subtitle", "Pick the closest one. There's no wrong answer.", "Check-in subtitle.", "దగ్గరగా ఉన్నదాన్ని ఎంచుకోండి. తప్పు సమాధానం అంటూ ఏదీ లేదు.", "Daggaraga unnadi select cheyandi. Tappu answer antu edi ledu.")
s("checkin_moreEnergy", "More energy", "Grid axis label (top).", "ఎక్కువ శక్తి", "Ekkuva energy")
s("checkin_lessEnergy", "Less energy", "Grid axis label (bottom).", "తక్కువ శక్తి", "Takkuva energy")
s("checkin_pleasant", "Pleasant", "Grid axis label (right).", "హాయిగా", "Haayiga")
s("checkin_unpleasant", "Unpleasant", "Grid axis label (left).", "ఇబ్బందిగా", "Ibbandiga")
s("quadrant_storm", "Storm", "High energy, unpleasant quadrant. Never 'bad'.", "తుఫాను", "Storm")
s("quadrant_rain", "Rain", "Low energy, unpleasant quadrant.", "వాన", "Rain")
s("quadrant_moonlight", "Moonlight", "Low energy, pleasant quadrant.", "వెన్నెల", "Moonlight")
s("quadrant_sunrise", "Sunrise", "High energy, pleasant quadrant.", "సూర్యోదయం", "Sunrise")
s("mood_semantic", "{mood}, {quadrant} group, {energy}, {feel}", "Screen-reader label for a mood tile (REQ-A11Y-04).", "{mood}, {quadrant} గుంపు, {energy}, {feel}", "{mood}, {quadrant} group, {energy}, {feel}", STR("mood", "quadrant", "energy", "feel"))
s("semantic_highEnergy", "high energy", "Screen-reader part.", "ఎక్కువ శక్తి", "ekkuva energy")
s("semantic_lowEnergy", "low energy", "Screen-reader part.", "తక్కువ శక్తి", "takkuva energy")
s("semantic_pleasant", "pleasant", "Screen-reader part.", "హాయిగా", "haayiga")
s("semantic_unpleasant", "unpleasant", "Screen-reader part.", "ఇబ్బందిగా", "ibbandiga")
s("checkin_addDetails", "Add a tag or a few words", "Optional details toggle.", "ఒక ట్యాగ్ లేదా కొన్ని మాటలు జోడించండి", "Oka tag leda konni maatalu add cheyandi")
s("checkin_tagsTitle", "What's it about?", "Tags section title.", "దేని గురించి?", "Deeni gurinchi?")
for key, en, te, tl in [
    ("study", "Study", "చదువు", "Chaduvu"),
    ("work", "Work", "పని", "Pani"),
    ("family", "Family", "కుటుంబం", "Family"),
    ("friends", "Friends", "స్నేహితులు", "Friends"),
    ("sleep", "Sleep", "నిద్ర", "Nidra"),
    ("health", "Health", "ఆరోగ్యం", "Health"),
    ("money", "Money", "డబ్బు", "Dabbu"),
    ("love", "Love", "ప్రేమ", "Prema"),
    ("alone", "Alone", "ఒంటరితనం", "Ontaritanam"),
    ("commute", "Commute", "ప్రయాణం", "Prayaanam"),
]:
    s(f"tag_{key}", en, f"Context tag '{key}'.", te, tl)
s("checkin_customTag", "Your own tag", "Custom tag field.", "మీ సొంత ట్యాగ్", "Mee sontha tag")
s("checkin_customTagAdd", "Add tag", "Add custom tag button.", "ట్యాగ్ జోడించండి", "Tag add cheyandi")
s("checkin_noteLabel", "A few words, if you like", "Note field label.", "కావాలంటే, కొన్ని మాటలు", "Kaavaalante, konni maatalu")
s("checkin_noteHint", "Only you can read this.", "Note privacy hint.", "ఇది మీరు మాత్రమే చదవగలరు.", "Idi meeru maatrame chadavagalaru.")
s("checkin_save", "Save", "Save check-in (tap 2).", "సేవ్ చేయండి", "Save cheyandi")
s("checkin_saveFailed", "We couldn't save that. Your phone may be low on space.", "Local write failed. Selection is kept.", "దాన్ని సేవ్ చేయలేకపోయాం. మీ ఫోన్‌లో స్థలం తక్కువగా ఉండొచ్చు.", "Daanni save cheyalekapoyaam. Mee phone lo space takkuva undochu.")
s("checkin_savedStarlight", "+{amount} Starlight", "Reward moment after saving.", "+{amount} Starlight", "+{amount} Starlight", INT("amount"))
s("checkin_saved", "Saved", "Saved confirmation.", "సేవ్ అయింది", "Save ayyindi")
s("checkin_savedOffline", "Saved on this phone", "Saved while offline / before sync.", "ఈ ఫోన్‌లో సేవ్ అయింది", "Ee phone lo save ayyindi")
s("checkin_savedThanks", "Thank you for checking in.", "After saving.", "చెక్-ఇన్ చేసినందుకు ధన్యవాదాలు.", "Check-in chesinanduku thanks.")
s("checkin_savedFull", "You've gathered all of today's Starlight. Your check-in still counts.", "When the day's Starlight is already capped.", "ఈరోజు Starlight అంతా సేకరించేశారు. మీ చెక్-ఇన్ ఇప్పటికీ లెక్కలోకి వస్తుంది.", "Ee roju Starlight antaa sekarinchesaaru. Mee check-in ippatiki count avutundi.")
s("checkin_roomButton", "Join a room of people feeling this", "Room prompt after saving (F5, coming soon).", "ఇలాగే అనిపిస్తున్నవాళ్ళ గదిలో చేరండి", "Ilaane anipistunna vaalla room lo cherandi")

# ---- home -------------------------------------------------------------------
s("home_checkIn", "Check in", "Primary Home button.", "చెక్-ఇన్ చేయండి", "Check in cheyandi")
s("home_todayStarlight", "{count} Starlight today", "Today's Starlight.", "ఈరోజు {count} Starlight", "Ee roju {count} Starlight", INT("count"))
s("home_totalStarlight", "{count} in all", "All-time Starlight.", "మొత్తం {count}", "Mottham {count}", INT("count"))
s("home_empty", "This is your Aura. Check in to give it light.", "New user empty state.", "ఇది మీ Aura. చెక్-ఇన్ చేసి దానికి వెలుగు ఇవ్వండి.", "Idi mee Aura. Check in chesi daaniki velugu ivvandi.")
s("home_resting", "Your Aura has been resting. Say hi when you're ready.", "Resting Nebula copy. No guilt.", "మీ Aura కొంచెం విశ్రాంతి తీసుకుంటోంది. మీకు వీలైనప్పుడు ఒక్క హాయ్ చెప్పండి.", "Mee Aura konchem rest teesukuntondi. Meeku veelainappudu oka hi cheppandi.")
s("home_glowStreak", "{count, plural, =1{Glow streak · 1 day} other{Glow streak · {count} days}}", "Current glow streak.", "{count, plural, =1{వెలుగు వరుస · 1 రోజు} other{వెలుగు వరుస · {count} రోజులు}}", "{count, plural, =1{Glow streak · 1 roju} other{Glow streak · {count} rojulu}}", INT("count"))
s("home_restDays", "{count, plural, =0{No rest days saved yet} =1{1 rest day saved} other{{count} rest days saved}}", "Rest-day bank.", "{count, plural, =0{ఇంకా విశ్రాంతి రోజులు లేవు} =1{1 విశ్రాంతి రోజు దాచి ఉంది} other{{count} విశ్రాంతి రోజులు దాచి ఉన్నాయి}}", "{count, plural, =0{Inka rest days levu} =1{1 rest day daachi undi} other{{count} rest days daachi unnaayi}}", INT("count"))
s("home_restingSafe", "Resting · your glow is safe", "Gap covered by rest days (F3). Never a countdown.", "విశ్రాంతి · మీ వెలుగు భద్రంగా ఉంది", "Rest · mee glow safe ga undi")
s("home_glowCarriesOn", "Your glow carries on", "Shown once when a new streak starts. No loss words.", "మీ వెలుగు కొనసాగుతుంది", "Mee glow continue avutundi")
s("home_lifetimeGlow", "{count, plural, =1{1 glow day in all} other{{count} glow days in all}}", "Lifetime glow days.", "{count, plural, =1{మొత్తం 1 వెలుగు రోజు} other{మొత్తం {count} వెలుగు రోజులు}}", "{count, plural, =1{Mottham 1 glow day} other{Mottham {count} glow days}}", INT("count"))
s("home_habitsTitle", "Small things today", "Habits section title.", "ఈరోజు చిన్న చిన్న పనులు", "Ee roju chinna chinna panulu")
s("home_habitDone", "{habit}, done today", "Screen-reader label, habit done.", "{habit}, ఈరోజు అయింది", "{habit}, ee roju ayyindi", STR("habit"))
s("home_habitNotYet", "{habit}, not yet today", "Screen-reader label, habit not done (no 'missed').", "{habit}, ఈరోజు ఇంకా లేదు", "{habit}, ee roju inka ledu", STR("habit"))
s("home_offline", "You're offline. Your own things still save here.", "Offline banner.", "మీరు ఆఫ్‌లైన్‌లో ఉన్నారు. మీ విషయాలు ఇక్కడ సేవ్ అవుతూనే ఉంటాయి.", "Meeru offline lo unnaru. Mee vishayaalu ikkada save avtune untaayi.")
s("home_finishSetup", "Finish setting up so your Aura is kept safe.", "Signed-out banner.", "మీ Aura భద్రంగా ఉండటానికి సెటప్ పూర్తి చేయండి.", "Mee Aura safe ga undadaaniki setup complete cheyandi.")
s("home_signIn", "Sign in", "Sign-in button.", "సైన్ ఇన్", "Sign in")
s("home_syncIdle", "All saved", "Sync indicator: synced.", "అన్నీ సేవ్ అయ్యాయి", "Anni save ayyaayi")
s("home_syncPending", "{count, plural, =1{1 thing waiting to sync} other{{count} things waiting to sync}}", "Sync indicator: pending.", "{count, plural, =1{1 సింక్ కోసం వేచి ఉంది} other{{count} సింక్ కోసం వేచి ఉన్నాయి}}", "{count, plural, =1{1 sync kosam wait chestondi} other{{count} sync kosam wait chestunnaayi}}", INT("count"))
s("home_syncLocal", "Saved on this phone", "Sync indicator: local only.", "ఈ ఫోన్‌లో సేవ్ అయింది", "Ee phone lo save ayyindi")
s("home_settings", "Settings", "Settings button.", "సెట్టింగ్‌లు", "Settings")
s("home_welcomeBack", "Welcome back. One small thing today is plenty.", "Wake-up moment micro-goal. Never a list of what was missed.", "మళ్ళీ స్వాగతం. ఈరోజు ఒక్క చిన్న పని చాలు.", "Malli swaagatam. Ee roju oka chinna pani chaalu.")
s("home_evolved", "Your Aura grew into {stage}.", "Evolution moment.", "మీ Aura {stage}గా ఎదిగింది.", "Mee Aura {stage} ga edigindi.", STR("stage"))

for key, en, te in [
    ("spark", "Spark", "రవ్వ"),
    ("ember", "Ember", "నిప్పు కణిక"),
    ("glow", "Glow", "వెలుగు"),
    ("radiance", "Radiance", "తేజస్సు"),
    ("constellation", "Constellation", "నక్షత్ర మండలం"),
]:
    s(f"stage_{key}", en, f"Avatar stage '{key}'.", te, en)

for key, en, te, tl in [
    ("hydrate", "Hydrate", "నీళ్ళు", "Neellu"),
    ("sleep_on_time", "Sleep on time", "సమయానికి నిద్ర", "Time ki nidra"),
    ("move", "Move", "కదలిక", "Kadalika"),
    ("breathe", "Breathe", "శ్వాస", "Breathe"),
    ("journal", "Journal", "డైరీ", "Journal"),
    ("go_outside", "Go outside", "బయటికి", "Bayataki"),
]:
    s(f"habit_{key}", en, f"Preset habit '{key}'.", te, tl)

# ---- avatar semantics (REQ-A11Y-05) --------------------------------------
s("avatar_semantic", "Your Aura, {stage} stage, {hue} glow", "Avatar description for screen readers.", "మీ Aura, {stage} దశ, {hue} వెలుగు", "Mee Aura, {stage} stage, {hue} glow", STR("stage", "hue"))
s("avatar_semanticResting", "resting in a soft nebula", "Appended when resting.", "మెత్తని నెబ్యులాలో విశ్రాంతి తీసుకుంటోంది", "mettani nebula lo rest teesukuntondi")
s("avatar_semanticRings", "{count, plural, =1{one orbiting light} other{{count} orbiting lights}}", "Rings trait for screen readers.", "{count, plural, =1{చుట్టూ తిరిగే ఒక వెలుగు} other{చుట్టూ తిరిగే {count} వెలుగులు}}", "{count, plural, =1{chuttu tirige oka velugu} other{chuttu tirige {count} velugulu}}", INT("count"))
s("avatar_semanticStars", "{count, plural, =1{one star in its constellation} other{{count} stars in its constellation}}", "Constellation stars for screen readers.", "{count, plural, =1{నక్షత్ర మండలంలో ఒక నక్షత్రం} other{నక్షత్ర మండలంలో {count} నక్షత్రాలు}}", "{count, plural, =1{constellation lo oka star} other{constellation lo {count} stars}}", INT("count"))
for key, en, te, tl in [
    ("gold", "golden", "బంగారు", "bangaaru"),
    ("green", "green", "ఆకుపచ్చ", "aakupacha"),
    ("teal", "teal", "నీలి-ఆకుపచ్చ", "teal"),
    ("silverBlue", "silver-blue", "వెండి-నీలి", "silver-blue"),
    ("violet", "violet", "ఊదా", "violet"),
    ("rose", "rose", "గులాబీ", "gulaabi"),
]:
    s(f"hue_{key}", en, f"Avatar hue name '{key}'.", te, tl)

# ---- settings ---------------------------------------------------------------
s("settings_title", "Settings", "Settings title.", "సెట్టింగ్‌లు", "Settings")
s("settings_language", "Language", "Language row.", "భాష", "Bhaasha")
s("settings_account", "Account", "Account section.", "ఖాతా", "Account")
s("settings_signedInAs", "Signed in as {email}", "Account row.", "{email}తో సైన్ ఇన్ అయ్యారు", "{email} tho sign in ayyaru", STR("email"))
s("settings_signOut", "Sign out", "Sign out.", "సైన్ అవుట్", "Sign out")
s("settings_signOutPending", "{count, plural, =1{1 thing hasn't synced yet. Stay signed in until it does?} other{{count} things haven't synced yet. Stay signed in until they do?}}", "Unsynced warning on sign-out.", "{count, plural, =1{1 విషయం ఇంకా సింక్ కాలేదు. అది అయ్యే వరకు సైన్ ఇన్‌లోనే ఉంటారా?} other{{count} విషయాలు ఇంకా సింక్ కాలేదు. అవి అయ్యే వరకు సైన్ ఇన్‌లోనే ఉంటారా?}}", "{count, plural, =1{1 vishayam inka sync avvaledu. Adi ayye varaku sign in lone untaara?} other{{count} vishayaalu inka sync avvaledu. Avi ayye varaku sign in lone untaara?}}", INT("count"))
s("settings_stay", "Stay signed in", "Keep session.", "సైన్ ఇన్‌లోనే ఉంటాను", "Sign in lone untaanu")
s("settings_signOutAnyway", "Sign out anyway", "Confirm sign out.", "అయినా సైన్ అవుట్ చేయండి", "Ayinaa sign out cheyandi")
s("settings_signIn", "Sign in to keep your Aura safe", "Signed-out row.", "మీ Auraని భద్రంగా ఉంచడానికి సైన్ ఇన్ చేయండి", "Mee Aura ni safe ga unchadaaniki sign in cheyandi")
s("settings_avatarLab", "Avatar lab", "Debug-only entry.", "Avatar lab", "Avatar lab")
s("settings_about", "About", "About section.", "గురించి", "Gurinchi")
s("settings_version", "Version {version}", "App version.", "వెర్షన్ {version}", "Version {version}", STR("version"))


# ---- notifications soft ask (PRD 15-permissions: after the first check-in) --
# Shown before the OS prompt. "Not now" (common_notNow) never fires it.
s("push_title", "Want a gentle nudge each evening?", "Pre-permission explainer title, shown once after the first check-in. PRD copy. Warm, no pressure.", "ప్రతి సాయంత్రం ఒక మృదువైన గుర్తు కావాలా?", "Prati saayantram oka gentle nudge kaavaalaa?")
s("push_body", "One a day at most, and never about streaks. Nothing on your lock screen will say how you feel.", "Pre-permission explainer body. Must promise: at most one a day, never streaks, never a mood on the lock screen.", "రోజుకు ఒక్కటి మాత్రమే, streaks గురించి ఎప్పుడూ కాదు. మీరు ఎలా ఫీల్ అవుతున్నారో మీ లాక్ స్క్రీన్ ఎప్పుడూ చెప్పదు.", "Rojuki okkate, streaks gurinchi eppudu kaadu. Meeru ela feel avutunnaro mee lock screen eppudu cheppadu.")
s("push_allow", "Allow", "Explainer button that opens the system notification prompt.", "అనుమతించండి", "Allow cheyandi")

def arb(locale, idx):
    out = {"@@locale": locale}
    for key, (en, desc, ph, te, tl) in S.items():
        val = [en, None, None, te, tl][idx]
        out[key] = val
        if idx == 0:
            meta = {"description": desc}
            if ph:
                meta["placeholders"] = ph
            out["@" + key] = meta
    return out


def write(name, data):
    with open(os.path.join(OUT, name), "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write("\n")


os.makedirs(OUT, exist_ok=True)
write("app_en.arb", arb("en", 0))
write("app_te.arb", arb("te", 3))
write("app_te_Latn.arb", arb("te_Latn", 4))
# Beta: TODO(l10n-hi) translate. Until then gen-l10n falls back to English for
# every key missing here (listed in build/untranslated_messages.json).
write("app_hi.arb", {"@@locale": "hi", "appTitle": "Aura"})
write("app_hi_Latn.arb", {"@@locale": "hi_Latn", "appTitle": "Aura"})
print(f"wrote {len(S)} keys x 5 locales")
