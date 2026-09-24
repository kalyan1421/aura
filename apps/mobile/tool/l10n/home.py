# Home, habits and support-sheet copy (design-audit fixes). Loaded by
# tool/l10n_source.py.
# s(key, en, desc, te, te_Latn, ph=None, hi=, hl=) · edit(key, en=, te=, tl=, desc=, hi=, hl=)
# te / te_Latn / hi / hi_Latn (hl) are first drafts: NEEDS NATIVE REVIEW before alpha / beta.

# ---- Tenglish preset names: match Telugu శ్వాస / డైరీ ----------------------
edit("habit_breathe", tl="Shwaasa")
edit("habit_journal", tl="Diary")

# ---- Starlight row (F2 stages) -------------------------------------------
s("home_stageProgress", "{stage}, {count} of {target} Starlight toward {next}", "Screen-reader label for the thin progress bar toward the next avatar stage. Calm, no countdown or pressure.", "{stage}, {next} వైపు {target}లో {count} Starlight", "{stage}, {next} vaipu {target} lo {count} Starlight", {**STR("stage", "next"), **INT("count", "target")}, hi="{stage}, {next} की ओर {target} में से {count} Starlight", hl="{stage}, {next} ki taraf {target} mein se {count} Starlight")
s("home_constellationProgress", "{stage}, {count} of {max} stars in your constellation", "Screen-reader label for the constellation stars row (final stage).", "{stage}, మీ నక్షత్ర మండలంలో {max}లో {count} నక్షత్రాలు", "{stage}, mee constellation lo {max} lo {count} stars", {**STR("stage"), **INT("count", "max")}, hi="{stage}, आपके तारामंडल में {max} में से {count} तारे", hl="{stage}, aapke constellation mein {max} mein se {count} stars")

# ---- Glow card and rest days (F3) ----------------------------------------
s("home_glowTitle", "Your glow", "Glow card heading when the streak number is hidden (Settings → Hide streak number).", "మీ వెలుగు", "Mee glow", hi="आपकी चमक", hl="Aapka glow")
s("home_restDaysHint", "Learn how rest days work", "Screen-reader hint on the rest-day row (opens a short explainer).", "విశ్రాంతి రోజులు ఎలా పనిచేస్తాయో తెలుసుకోండి", "Rest days ela pani chestaayo telusukondi", hi="जानें कि आराम के दिन कैसे काम करते हैं", hl="Jaanein ki rest days kaise kaam karte hain")
s("home_restInfoTitle", "Rest days", "Title of the rest-day explainer sheet.", "విశ్రాంతి రోజులు", "Rest days", hi="आराम के दिन", hl="Rest days")
s("home_restInfoEarn", "Every {days} glow days earn a rest day. You can keep up to {max}.", "Rest-day explainer: how they are earned. Numbers come from the rules.", "ప్రతి {days} వెలుగు రోజులకు ఒక విశ్రాంతి రోజు వస్తుంది. {max} వరకు దాచుకోవచ్చు.", "Prati {days} glow days ki oka rest day vastundi. {max} varaku daachukovachu.", INT("days", "max"), hi="हर {days} चमक वाले दिनों पर एक आराम का दिन मिलता है। {max} तक जमा रखे जा सकते हैं।", hl="Har {days} glow days par ek rest day milta hai. {max} tak jama rakhe ja sakte hain.")
s("home_restInfoUse", "When you take a short break, they fill in those days on their own. There's nothing you need to do.", "Rest-day explainer: applied automatically, never prompted.", "మీరు కొంచెం విరామం తీసుకున్నప్పుడు, అవి ఆ రోజులను తమంతట తామే నింపుతాయి. మీరు ఏమీ చేయాల్సిన అవసరం లేదు.", "Meeru konchem break teesukunnappudu, avi aa rojulni vaatantha avey nimputaayi. Meeru emi cheyyalsina avasaram ledu.", hi="छोटे ब्रेक के दौरान ये उन दिनों को अपने-आप भर देते हैं। आपको कुछ नहीं करना है।", hl="Chhote break ke dauraan ye un dinon ko apne aap bhar dete hain. Aapko kuch nahi karna hai.")
s("home_restInfoKeep", "Every glow day you've had stays with you.", "Rest-day explainer: lifetime glow days never go down. No loss words.", "మీకు వచ్చిన ప్రతి వెలుగు రోజూ మీతోనే ఉంటుంది.", "Meeku vachina prati glow day meethone untundi.", hi="आपका हर चमक वाला दिन आपके साथ रहता है।", hl="Aapka har glow day aapke saath rehta hai.")

# ---- History entry point -------------------------------------------------
s("home_checkInsToday", "{count, plural, =1{1 check-in today} other{{count} check-ins today}}", "Home line under the stats; opens check-in history.", "{count, plural, =1{ఈరోజు 1 చెక్-ఇన్} other{ఈరోజు {count} చెక్-ఇన్‌లు}}", "{count, plural, =1{Ee roju 1 check-in} other{Ee roju {count} check-ins}}", INT("count"), hi="{count, plural, =1{आज 1 चेक-इन} other{आज {count} चेक-इन}}", hl="{count, plural, =1{Aaj 1 check-in} other{Aaj {count} check-ins}}")
s("home_seeAll", "See all", "Link to check-in history, after today's count.", "అన్నీ చూడండి", "Anni choodandi", hi="सब देखें", hl="Sab dekhein")
s("home_yourCheckIns", "Your check-ins", "Home link to check-in history when there is none today.", "మీ చెక్-ఇన్‌లు", "Mee check-ins", hi="आपके चेक-इन", hl="Aapke check-ins")

# ---- Sync details sheet --------------------------------------------------
s("home_syncExplainIdle", "Everything is saved on this phone and in your account.", "Sync sheet: all synced.", "అన్నీ ఈ ఫోన్‌లో, మీ ఖాతాలో సేవ్ అయ్యాయి.", "Anni ee phone lo, mee account lo save ayyaayi.", hi="सब कुछ इस फ़ोन पर और आपके अकाउंट में सेव है।", hl="Sab kuch is phone par aur aapke account mein save hai.")
s("home_syncExplainPending", "They're safe on this phone and will sync on their own.", "Sync sheet: items waiting to sync.", "అవి ఈ ఫోన్‌లో భద్రంగా ఉన్నాయి, తమంతట తామే సింక్ అవుతాయి.", "Avi ee phone lo safe ga unnaayi, vaatante sync avutaayi.", hi="ये इस फ़ोन पर सुरक्षित हैं और अपने-आप सिंक हो जाएँगे।", hl="Ye is phone par safe hain aur apne aap sync ho jayenge.")
s("home_syncExplainOffline", "You're offline. Everything is safe on this phone and syncs when you're back online.", "Sync sheet: offline.", "మీరు ఆఫ్‌లైన్‌లో ఉన్నారు. అన్నీ ఈ ఫోన్‌లో భద్రంగా ఉన్నాయి, మళ్ళీ ఆన్‌లైన్ అయ్యాక సింక్ అవుతాయి.", "Meeru offline lo unnaru. Anni ee phone lo safe ga unnaayi, malli online ayyaaka sync avutaayi.", hi="आप ऑफ़लाइन हैं। सब कुछ इस फ़ोन पर सुरक्षित है और फिर से ऑनलाइन होने पर सिंक हो जाएगा।", hl="Aap offline hain. Sab kuch is phone par safe hai aur phir se online hone par sync ho jayega.")
s("home_syncExplainSignedOut", "You're not signed in, so everything stays on this phone for now.", "Sync sheet: signed out.", "మీరు సైన్ ఇన్ కాలేదు, కాబట్టి ప్రస్తుతానికి అన్నీ ఈ ఫోన్‌లోనే ఉంటాయి.", "Meeru sign in avvaledu, kabatti prastutaaniki anni ee phone lone untaayi.", hi="आपने साइन इन नहीं किया है, इसलिए अभी सब कुछ इसी फ़ोन पर रहेगा।", hl="Aapne sign in nahi kiya hai, isliye abhi sab kuch isi phone par rahega.")
s("home_syncExplainUnavailable", "This version keeps everything on this phone.", "Sync sheet: builds without a server.", "ఈ వెర్షన్ అన్నింటినీ ఈ ఫోన్‌లోనే ఉంచుతుంది.", "Ee version anni ee phone lone unchutundi.", hi="यह वर्ज़न सब कुछ इसी फ़ोन पर रखता है।", hl="Ye version sab kuch isi phone par rakhta hai.")
s("home_syncNow", "Sync now", "Sync sheet button (online and signed in).", "ఇప్పుడే సింక్ చేయండి", "Ippude sync cheyandi", hi="अभी सिंक करें", hl="Abhi sync karein")
s("home_syncing", "Syncing…", "Sync sheet button while a sync runs.", "సింక్ అవుతోంది…", "Sync avutondi…", hi="सिंक हो रहा है…", hl="Sync ho raha hai…")
s("home_syncHint", "Show sync details", "Screen-reader hint on the sync indicator.", "సింక్ వివరాలు చూపించండి", "Sync details choopinchandi", hi="सिंक की जानकारी देखें", hl="Sync details dekhein")

# ---- Habits (F2) ---------------------------------------------------------
s("habits_edit", "Edit", "Button next to the habits title; opens the habits editor.", "మార్చండి", "Edit cheyandi", hi="एडिट करें", hl="Edit karein")
s("habits_editSemantic", "Edit small things", "Screen-reader label of the habits Edit button.", "చిన్న పనులను మార్చండి", "Chinna panulni edit cheyandi", hi="छोटे काम एडिट करें", hl="Chhote kaam edit karein")
s("habits_sheetTitle", "Your small things", "Habits editor title.", "మీ చిన్న పనులు", "Mee chinna panulu", hi="आपके छोटे काम", hl="Aapke chhote kaam")
s("habits_sheetBody", "Choose what shows on Home. Check-ins grow your Aura either way.", "Habits editor intro.", "Homeలో ఏవి కనిపించాలో ఎంచుకోండి. ఎలాగైనా చెక్-ఇన్‌లతో మీ Aura పెరుగుతుంది.", "Home lo evi kanipinchaalo select cheyandi. Elaagaina check-ins tho mee Aura perugutundi.", hi="चुनें कि होम पर क्या दिखे। चेक-इन से आपका Aura हर हाल में बढ़ता है।", hl="Chunein ki Home par kya dikhe. Check-ins se aapka Aura har haal mein badhta hai.")
s("habits_presetsTitle", "Suggested", "Habits editor section: the six presets.", "సూచనలు", "Suggestions", hi="सुझाव", hl="Suggestions")
s("habits_customTitle", "Your own", "Habits editor section: custom habits.", "మీ సొంతవి", "Mee sontavi", hi="आपके अपने", hl="Aapke apne")
s("habits_addLabel", "Add your own", "Label of the custom-habit name field.", "మీ సొంతది జోడించండి", "Mee sontadi add cheyandi", hi="अपना जोड़ें", hl="Apna add karein")
s("habits_addHint", "For example, water the plants", "Hint in the custom-habit name field.", "ఉదాహరణకు, మొక్కలకు నీళ్ళు", "Udaaharanaki, mokkalaki neellu", hi="जैसे, पौधों को पानी देना", hl="Jaise, paudhon ko paani dena")
s("habits_add", "Add", "Adds the typed custom habit.", "జోడించండి", "Add cheyandi", hi="जोड़ें", hl="Add karein")
s("habits_limit", "You have {count} custom habits. Swap one to add another.", "Shown at the custom-habit limit (PRD States: Habits).", "మీకు {count} సొంత అలవాట్లు ఉన్నాయి. ఇంకొకటి జోడించడానికి ఒకదాన్ని మార్చండి.", "Meeku {count} custom habits unnaayi. Inkokati add cheyadaaniki okadaanni swap cheyandi.", INT("count"), hi="आपके पास {count} कस्टम आदतें हैं। नई जोड़ने के लिए किसी एक को बदलें।", hl="Aapke paas {count} custom habits hain. Nayi add karne ke liye kisi ek ko swap karein.")
s("habits_saveFailed", "That didn't save. Could you try again?", "A habit change failed to save locally.", "అది సేవ్ కాలేదు. మళ్ళీ ప్రయత్నిస్తారా?", "Adi save avvaledu. Malli try chestaara?", hi="यह सेव नहीं हुआ। फिर से कोशिश करें?", hl="Ye save nahi hua. Phir se try karein?")
s("habits_remove", "Remove {name}", "Tooltip / screen-reader label of a custom habit's remove button.", "{name} తీసేయండి", "{name} teeseyandi", STR("name"), hi="{name} हटाएँ", hl="{name} hatayein")
s("habits_removeTitle", "Remove {name}?", "Confirm dialog title before removing a custom habit.", "{name} తీసేయాలా?", "{name} teeseyaalaa?", STR("name"), hi="{name} हटाएँ?", hl="{name} hatayein?")
s("habits_removeBody", "It leaves your list. Starlight and glow days you earned with it stay.", "Confirm dialog body before removing a custom habit.", "ఇది మీ జాబితా నుండి వెళ్ళిపోతుంది. దీనితో వచ్చిన Starlight, వెలుగు రోజులు అలాగే ఉంటాయి.", "Idi mee list nundi vellipotundi. Deenitho vachina Starlight, glow days alaage untaayi.", hi="यह आपकी लिस्ट से हट जाएगा। इससे मिले Starlight और चमक वाले दिन बने रहेंगे।", hl="Ye aapki list se hat jayega. Isse mile Starlight aur glow days bane rahenge.")
s("habits_removeConfirm", "Remove", "Confirm removing a custom habit.", "తీసేయండి", "Teeseyandi", hi="हटाएँ", hl="Hatayein")
s("habits_empty", "Pick one small thing to start.", "Home when every habit is hidden (PRD States: Habits empty).", "మొదలుపెట్టడానికి ఒక చిన్న పని ఎంచుకోండి.", "Modalupettadaaniki oka chinna pani select cheyandi.", hi="शुरू करने के लिए एक छोटा काम चुनें।", hl="Shuru karne ke liye ek chhota kaam chunein.")

# ---- Support sheet grounding (F9, REQ-A11Y-12) ---------------------------
s("help_groundingProgress", "Progress through the minute", "Screen-reader label of the grounding progress ring. No countdown.", "ఈ నిమిషంలో ఎంతవరకు వచ్చారు", "Ee nimisham lo entavaraku vachaaru", hi="इस एक मिनट में अब तक", hl="Is ek minute mein ab tak")
s("help_progressBegun", "Just begun", "Grounding ring value: first third.", "ఇప్పుడే మొదలైంది", "Ippude modalaindi", hi="अभी शुरू हुआ", hl="Abhi shuru hua")
s("help_progressHalf", "About halfway", "Grounding ring value: middle third.", "దాదాపు సగం", "Daadaapu sagam", hi="लगभग आधा", hl="Lagbhag aadha")
s("help_progressNearly", "Nearly through", "Grounding ring value: last third. Never pressure.", "దాదాపు పూర్తయింది", "Daadaapu purtayindi", hi="लगभग पूरा", hl="Lagbhag poora")
s("help_progressDone", "Complete", "Grounding ring value: finished.", "పూర్తయింది", "Purtayindi", hi="पूरा हुआ", hl="Poora hua")
s("help_breatheLogged", "{habit} is marked done for today.", "After the 60 s exercise auto-completes the Breathe habit (F2).", "ఈరోజు {habit} అయినట్టు గుర్తించాం.", "Ee roju {habit} ayyindani mark chesaam.", STR("habit"), hi="{habit} आज के लिए पूरा मार्क कर दिया गया है।", hl="{habit} aaj ke liye done mark kar diya gaya hai.")
