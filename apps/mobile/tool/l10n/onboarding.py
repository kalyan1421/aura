# Onboarding & trust copy (F8, F9, REQ-SAFE-12). Loaded by tool/l10n_source.py.
# s(key, en, desc, te, te_Latn, ph=None) · edit(key, en=, te=, tl=, desc=)
# te / te_Latn are first drafts: NEEDS NATIVE REVIEW before alpha.

# ---- trust step: /onboarding/trust (privacy & boundaries) -------------------
# The "not a medical device or an emergency service" sentence reuses
# help_disclaimer verbatim. The SPDI consent text is pending the lawyer
# (TODO(legal) in trust_screen.dart); do not add consent wording here.
s("onb_trustTitle", "Before we begin", "Trust step title (privacy and boundaries). Calm.", "మొదలుపెట్టే ముందు", "Modalupette mundu")
s("onb_trustBody", "A few things to know about how Aura looks after you.", "Trust step intro under the title.", "Aura మిమ్మల్ని ఎలా చూసుకుంటుందో కొన్ని విషయాలు.", "Aura mimmalni ela choosukuntundo konni vishayaalu.")
s("onb_trustPrivateTitle", "Private by default", "Trust point heading: privacy.", "మొదటి నుంచీ గోప్యంగా", "Modati nunchi private ga")
s("onb_trustPrivateBody", "Your check-ins and notes are yours. Notes are encrypted, and nobody else sees how you feel unless you choose to share it.", "Trust point body: privacy. Must stay true: notes are encrypted; moods are shared only by the user's choice (e.g. joining a room).", "మీ చెక్-ఇన్‌లు, నోట్స్ మీవే. నోట్స్ ఎన్‌క్రిప్ట్ అవుతాయి. మీరు పంచుకోవాలని ఎంచుకుంటే తప్ప, మీకు ఎలా అనిపిస్తోందో వేరే ఎవరికీ కనిపించదు.", "Mee check-ins, notes meeve. Notes encrypt avutaayi. Meeru share cheyaalani enchukunte tappa, meeku ela anipistondo vere evariki kanipinchadu.")
s("onb_trustCareTitle", "Wellness support, not therapy", "Trust point heading: Aura is not therapy or diagnosis (F9 App Review positioning).", "ఇది వెల్‌నెస్ తోడు, థెరపీ కాదు", "Idi wellness support, therapy kaadu")
s("onb_trustCareBody", "Aura helps you notice how you feel. It doesn't diagnose or treat anything.", "Trust point body: no diagnosis. Followed by the help_disclaimer sentence as its own line.", "మీకు ఎలా అనిపిస్తోందో గమనించుకోవడానికి Aura సహాయపడుతుంది. ఇది ఏ రోగనిర్ధారణ గానీ, చికిత్స గానీ చేయదు.", "Meeku ela anipistondo gamaninchukovadaaniki Aura help chestundi. Idi e diagnosis gaani, treatment gaani cheyadu.")
s("onb_trustHelpTitle", "Help is always one tap away", "Trust point heading: the always-visible help button.", "సహాయం ఎప్పుడూ ఒక్క ట్యాప్ దూరంలోనే", "Help eppudu oka tap dooramlone")
s("onb_trustHelpBody", "Tap “{button}” any time to call a helpline or take a minute to breathe.", "Trust point body. {button} is the help button's label (help_button), quoted as it appears on screen.", "హెల్ప్‌లైన్‌కు కాల్ చేయడానికి లేదా ఒక నిమిషం శ్వాస మీద ధ్యాస పెట్టడానికి, ఎప్పుడైనా “{button}” నొక్కండి.", "Helpline ki call cheyadaaniki leda oka nimisham breath meeda dhyaasa pettadaaniki, eppudaina “{button}” tap cheyandi.", STR("button"))

# ---- DOB picker sheets (REQ-ACC-02: no default year, never mention 13/18) --
s("onb_dobYearType", "Type the year", "Label of the optional typed-year field at the top of the year picker. No example year.", "సంవత్సరం టైప్ చేయండి", "Samvatsaram type cheyandi")
s("onb_dobYearNoMatch", "No year in the list matches that. Could you check it?", "Typed year is not in the picker's range. Calm, no blame.", "దానికి సరిపోయే సంవత్సరం లిస్ట్‌లో లేదు. ఒకసారి చూసుకుంటారా?", "Daaniki saripoye samvatsaram list lo ledu. Okasari choosukuntaara?")

# ---- blocked: wrong date (F8 edge case) -------------------------------------
s("onb_blockedWrongDate", "Entered the wrong date?", "Text button on the under-13 screen; opens an email to support.", "తప్పు తేదీ ఇచ్చారా?", "Tappu date icchaara?")
s("onb_blockedWrongDateHint", "Opens your email app", "Screen-reader hint on the wrong-date button.", "మీ ఈమెయిల్ యాప్ తెరుచుకుంటుంది", "Mee email app open avutundi")
s("onb_blockedMailSubject", "Aura: I entered the wrong date", "Email subject only. Never add the date of birth or any personal data.", "Aura: నేను తప్పు తేదీ ఇచ్చాను", "Aura: nenu tappu date icchaanu")
s("onb_blockedMailFailed", "We couldn't open an email app. You can write to us at {email}.", "Shown when no email app opens. {email} is the support address.", "ఈమెయిల్ యాప్ తెరవలేకపోయాం. {email}కి మాకు రాయవచ్చు.", "Email app open cheyyalekapoyaam. {email} ki maaku raayochu.", STR("email"))
