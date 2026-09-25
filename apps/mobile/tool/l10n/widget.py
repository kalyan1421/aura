# Home-screen widget (F11, Milestone C). Loaded by tool/l10n_source.py.
# s(key, en, desc, te, te_Latn, ph=None, hi=, hl=) · edit(key, en=, te=, tl=, desc=, hi=, hl=)
# te / te_Latn / hi / hi_Latn (hl) are first drafts: NEEDS NATIVE REVIEW before launch.
#
# The app renders these in its own language and hands them to the widget
# (features/widget/widget_display.dart), so the widget follows the app's
# language, Tenglish and Hinglish included. The keys in WIDGET_NATIVE_KEYS
# (tool/gen_widget_strings.py) are also compiled into the native widgets as
# fallbacks (before the app has run once, the widget gallery): iOS
# AuraWidget/Localizable.xcstrings, Android res/values*/widget_strings.xml.
# Rule: nothing here names a mood or says how someone feels, except the
# opt-in "last mood" line (PRD F11 privacy defaults).

# ---- the widget -------------------------------------------------------------
s("widget_prompt", "How are you feeling?", "Home-screen widget heading (F11). Same warmth as the check-in title.", "మీకు ఇప్పుడు ఎలా అనిపిస్తోంది?", "Meeku ippudu ela anipistondi?", hi="अभी कैसा लग रहा है?", hl="Abhi kaisa lag raha hai?")
s("widget_checkIn", "Check in", "Widget button / lock-screen star label that opens the check-in (F11). Short.", "చెక్-ఇన్", "Check-in", hi="चेक-इन", hl="Check-in")
s("widget_doneToday", "Checked in today", "Widget line once today has a check-in. Never says which mood.", "ఈరోజు చెక్-ఇన్ అయింది", "Ee roju check-in ayyindi", hi="आज चेक-इन हो गया", hl="Aaj check-in ho gaya")
s("widget_saved", "Saved", "Widget confirmation after a two-tap check-in that earned no Starlight (day's cap reached).", "సేవ్ అయింది", "Save ayyindi", hi="सेव हो गया", hl="Save ho gaya")
s("widget_savedStarlight", "Saved · +{amount} Starlight", "Widget confirmation after a two-tap check-in (F11 'Saved · +10 Starlight'). Provisional until the app imports it.", "సేవ్ అయింది · +{amount} Starlight", "Save ayyindi · +{amount} Starlight", INT("amount"), hi="सेव हो गया · +{amount} Starlight", hl="Save ho gaya · +{amount} Starlight")
s("widget_needHelp", "Need help", "Widget link to the Safety Center (F9) on the larger widget sizes. Must feel safe to tap.", "సహాయం కావాలి", "Help kaavali", hi="मदद चाहिए", hl="Madad chahiye")
s("widget_openApp", "Open Aura to continue", "Widget text while signed out or before setup (F11 edge case). Input is off.", "కొనసాగించడానికి Aura తెరవండి", "Continue cheyadaaniki Aura open cheyandi", hi="आगे बढ़ने के लिए Aura खोलें", hl="Aage badhne ke liye Aura kholein")
s("widget_openAppDiscreet", "Open the app to continue", "Discreet widget text while signed out: no app name (F11 Discreet widget).", "కొనసాగించడానికి యాప్ తెరవండి", "Continue cheyadaaniki app open cheyandi", hi="आगे बढ़ने के लिए ऐप खोलें", hl="Aage badhne ke liye app kholein")
s("widget_capsuleWaiting", "Something from past you is waiting", "Widget line when a time capsule is ready; it only opens in the app (F11).", "గతంలోని మీ నుండి ఒకటి ఎదురుచూస్తోంది", "Gatam lo mee nundi okati wait chestondi", hi="बीते समय के आप से कुछ इंतज़ार में है", hl="Past you se kuch intezaar mein hai")
s("widget_back", "Back", "Widget button: from the four moods back to the four groups.", "వెనక్కి", "Venakki", hi="वापस", hl="Wapas")
s("widget_lastMood", "Last: {mood}", "Widget line with the person's last mood. Only when 'Show my last mood' is on, home screen only.", "చివరిది: {mood}", "Last: {mood}", STR("mood"), hi="पिछला: {mood}", hl="Last: {mood}")

# ---- widget gallery (native only: shown by the OS when adding a widget) ------
s("widget_galleryName", "Aura check-in", "Name of the home-screen widget in the OS widget gallery.", "Aura చెక్-ఇన్", "Aura check-in", hi="Aura चेक-इन", hl="Aura check-in")
s("widget_galleryDescription", "Check in with two taps, right from your home screen.", "Description of the home-screen widget in the OS widget gallery.", "హోమ్ స్క్రీన్ నుండే రెండు ట్యాప్‌లతో చెక్-ఇన్ చేయండి.", "Home screen nunde rendu taps tho check-in cheyandi.", hi="होम स्क्रीन से ही दो टैप में चेक-इन करें।", hl="Home screen se hi do taps mein check-in karein.")
s("widget_lockGalleryName", "Quick check-in", "Name of the lock-screen widget (a star) in the iOS widget gallery.", "త్వరిత చెక్-ఇన్", "Quick check-in", hi="झटपट चेक-इन", hl="Jhatpat check-in")
s("widget_lockGalleryDescription", "A star that opens your check-in. It never shows how you feel.", "Description of the lock-screen widget in the iOS widget gallery (F11: lock screen shows only a star).", "మీ చెక్-ఇన్‌ను తెరిచే ఒక నక్షత్రం. మీకు ఎలా అనిపిస్తోందో అది ఎప్పుడూ చూపించదు.", "Mee check-in open chese oka star. Meeku ela anipistondo adi eppudu choopinchadu.", hi="एक तारा जो आपका चेक-इन खोलता है। यह कभी नहीं दिखाता कि आपका मन कैसा है।", hl="Ek taara jo aapka check-in kholta hai. Ye kabhi nahi dikhata ki aapka mann kaisa hai.")

# ---- Settings → Home-screen widget -------------------------------------------
s("widget_settingsTitle", "Home-screen widget", "Settings section for the widget (F11).", "హోమ్ స్క్రీన్ విడ్జెట్", "Home screen widget", hi="होम स्क्रीन विजेट", hl="Home screen widget")
s("widget_showLastMood", "Show my last mood", "Settings toggle (off by default): the widget shows the last mood (F11).", "నా చివరి మూడ్ చూపించు", "Naa last mood choopinchu", hi="मेरा पिछला मूड दिखाएँ", hl="Mera last mood dikhayein")
s("widget_showLastMoodNote", "On your home screen only. The lock screen never shows it.", "Note under 'Show my last mood' (F11 privacy: never on the lock screen or StandBy).", "మీ హోమ్ స్క్రీన్‌పై మాత్రమే. లాక్ స్క్రీన్ దీన్ని ఎప్పుడూ చూపించదు.", "Mee home screen meeda maatrame. Lock screen deenni eppudu choopinchadu.", hi="सिर्फ़ आपकी होम स्क्रीन पर। लॉक स्क्रीन पर यह कभी नहीं दिखता।", hl="Sirf aapki home screen par. Lock screen par ye kabhi nahi dikhta.")
s("widget_discreet", "Discreet widget", "Settings toggle (off by default) for the plain-star widget (F11 Discreet widget).", "గోప్యమైన విడ్జెట్", "Discreet widget", hi="सादा विजेट", hl="Discreet widget")
s("widget_discreetNote", "A plain star with no app name and no mood words. Tapping it opens the app.", "Note under 'Discreet widget'.", "యాప్ పేరు, మూడ్ మాటలు లేని ఒక సాదా నక్షత్రం. దాన్ని ట్యాప్ చేస్తే యాప్ తెరుచుకుంటుంది.", "App peru, mood maatalu leni oka simple star. Daanni tap cheste app open avutundi.", hi="बिना ऐप के नाम और बिना मूड वाले शब्दों का एक सादा तारा। इसे टैप करने पर ऐप खुलता है।", hl="Bina app ke naam aur bina mood words ka ek simple taara. Ise tap karne par app khulta hai.")
