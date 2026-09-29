# W03: habit commitments (editor) and per-habit plants in the personal universe.
# Loaded by tool/l10n_source.py after recovery.py (the fragments load in name order).
# s(key, en, desc, te, te_Latn, ph=None, hi=, hl=) · edit(key, en=, te=, tl=, desc=, hi=, hl=)
# te / te_Latn / hi / hi_Latn (hl) are first drafts: NEED NATIVE REVIEW before alpha / beta.
# Voice: warm and descriptive. A resting plant is "resting", never dead, lost or a count of
# missed days (RULES.md section 13).

# ---- Habits editor: commitments (adults only) -----------------------------
s("habits_commitmentsTitle", "Commitments", "Habits editor section title for the opt-in world commitments (adults only).", "సంకల్పాలు", "Sankalpaalu", hi="संकल्प", hl="Sankalp")
s("habits_commitmentsBody", "Pick the habits you want to keep close. If you miss a few days, that habit's plant in your world rests. One log wakes it. Your Starlight and glow days are never touched.", "Explains commitments before the switches. Must say plainly that Starlight and glow days are never affected and that one log restores the plant.", "మీరు దగ్గరగా ఉంచుకోవాలనుకునే అలవాట్లను ఎంచుకోండి. కొన్ని రోజులు మిస్ అయితే, మీ ప్రపంచంలో ఆ అలవాటు మొక్క విశ్రాంతి తీసుకుంటుంది. ఒక్క లాగ్‌తో అది మళ్లీ మేల్కొంటుంది. మీ Starlight, glow days ఎప్పటికీ తగ్గవు.", "Meeru daggaraga unchukovaalanukune alavaatlanu enchukondi. Konni rojulu miss aite, mee prapancham lo aa alavaatu mokka vishraanti teesukuntundi. Okka log tho adi malli melukuntundi. Mee Starlight, glow days eppatiki taggavu.", hi="जिन आदतों को आप अपने पास रखना चाहते हैं, उन्हें चुनें। कुछ दिन छूट जाएँ तो आपकी दुनिया में उस आदत का पौधा आराम करता है। एक लॉग उसे जगा देता है। आपकी Starlight और glow days को कभी कुछ नहीं होता।", hl="Jin aadaton ko aap apne paas rakhna chahte hain, unhein chunein. Kuch din chhoot jayein to aapki duniya mein us aadat ka paudha aaraam karta hai. Ek log use jaga deta hai. Aapki Starlight aur glow days ko kabhi kuch nahi hota.")
s("habits_commitmentSwitch", "Treat as a commitment", "Subtitle under a habit's name on the commitment switch. Read by screen readers after the habit name.", "సంకల్పంగా పరిగణించండి", "Sankalpam ga pariganinchandi", hi="संकल्प की तरह लें", hl="Sankalp ki tarah lein")
s("habits_pauseSemantic", "Pause {name}", "Tooltip and screen-reader label for the pause menu of a committed habit.", "{name}కు విరామం ఇవ్వండి", "{name} ki viraamam ivvandi", STR("name"), hi="{name} को विराम दें", hl="{name} ko viraam dein")
s("habits_pausedUntil", "Paused until {date}", "Subtitle of a committed habit while a pause is on. {date} is a short local date.", "{date} వరకు విరామం", "{date} varaku viraamam", STR("date"), hi="{date} तक विराम", hl="{date} tak viraam")
s("habits_pauseDays", "{count, plural, one{{count} day} other{{count} days}}", "Pause length choice in the pause menu.", "{count, plural, one{{count} రోజు} other{{count} రోజులు}}", "{count, plural, one{{count} roju} other{{count} rojulu}}", INT("count"), hi="{count, plural, one{{count} दिन} other{{count} दिन}}", hl="{count, plural, one{{count} din} other{{count} din}}")
s("habits_pauseEnd", "End pause", "Pause menu item that ends a pause early.", "విరామం ముగించండి", "Viraamam mugimchandi", hi="विराम खत्म करें", hl="Viraam khatam karein")

# ---- Personal universe: per-habit plants ----------------------------------
edit("universe_groveBody",
     en="Each habit is a plant that grows as you log it. Plants you commit to rest when days are missed, and a single log wakes them.",
     te="ప్రతి అలవాటు మీరు లాగ్ చేసే కొద్దీ పెరిగే ఒక మొక్క. మీరు సంకల్పించినవి రోజులు మిస్ అయితే విశ్రాంతి తీసుకుంటాయి, ఒక్క లాగ్‌తో మేల్కొంటాయి.",
     tl="Prati alavaatu meeru log chese koddi perige oka mokka. Meeru sankalpinchinavi rojulu miss aite vishraanti teesukuntaayi, okka log tho melukuntaayi.",
     hi="हर आदत एक पौधा है जो लॉग करने पर बढ़ता है। जिन पौधों का आपने संकल्प लिया है, वे दिन छूटने पर आराम करते हैं, और एक लॉग उन्हें जगा देता है।",
     hl="Har aadat ek paudha hai jo log karne par badhta hai. Jin paudhon ka aapne sankalp liya hai, ve din chhootne par aaraam karte hain, aur ek log unhein jaga deta hai.")
s("universe_yourPlants", "Your plants", "Heading of the accessible list of habit plants in the Habit Grove card.", "మీ మొక్కలు", "Mee mokkalu", hi="आपके पौधे", hl="Aapke paudhe")
s("universe_plantsResting", "{count, plural, one{One plant is resting. A single log wakes it.} other{{count} plants are resting. A single log wakes each one.}}", "Grove summary when committed plants are resting. Warm; never a count of missed days, never 'dead' or 'lost'.", "{count, plural, one{ఒక మొక్క విశ్రాంతి తీసుకుంటోంది. ఒక్క లాగ్‌తో అది మేల్కొంటుంది.} other{{count} మొక్కలు విశ్రాంతి తీసుకుంటున్నాయి. ఒక్కో లాగ్‌తో ఒక్కొక్కటి మేల్కొంటుంది.}}", "{count, plural, one{Oka mokka vishraanti teesukuntondi. Okka log tho adi melukuntundi.} other{{count} mokkalu vishraanti teesukuntunnaayi. Okko log tho okkokkati melukuntundi.}}", INT("count"), hi="{count, plural, one{एक पौधा आराम कर रहा है। एक लॉग उसे जगा देता है।} other{{count} पौधे आराम कर रहे हैं। हर एक को एक लॉग जगा देता है।}}", hl="{count, plural, one{Ek paudha aaraam kar raha hai. Ek log use jaga deta hai.} other{{count} paudhe aaraam kar rahe hain. Har ek ko ek log jaga deta hai.}}")
s("universe_stage_seed", "Seed", "Growth stage of a habit plant: no logs yet.", "విత్తనం", "Vittanam", hi="बीज", hl="Beej")
s("universe_stage_sprout", "Sprout", "Growth stage of a habit plant.", "మొలక", "Molaka", hi="अंकुर", hl="Ankur")
s("universe_stage_young", "Growing", "Growth stage of a habit plant.", "పెరుగుతోంది", "Perugutondi", hi="बढ़ता हुआ", hl="Badhta hua")
s("universe_stage_grown", "Grown", "Growth stage of a habit plant.", "ఎదిగింది", "Edigindi", hi="पूरा बढ़ा", hl="Poora badha")
s("universe_stage_flourishing", "Flourishing", "Growth stage of a habit plant.", "పచ్చగా ఉంది", "Pacchaga undi", hi="हरा-भरा", hl="Hara-bhara")
s("universe_stage_ancient", "Ancient", "Growth stage of a habit plant after a long time of care.", "పురాతనం", "Puraatanam", hi="प्राचीन", hl="Praacheen")
s("universe_vitality_dimmed", "Resting", "State of a committed habit plant after a few missed days. Never negative.", "విశ్రాంతి", "Vishraanti", hi="आराम में", hl="Aaraam mein")
s("universe_vitality_wilting", "Drooping a little", "State of a committed habit plant after several missed days. Gentle.", "కొంచెం వాడింది", "Konchem vaadindi", hi="थोड़ा झुका हुआ", hl="Thoda jhuka hua")
s("universe_vitality_dormant", "Asleep, waiting for you", "State of a committed habit plant after a long break. It never disappears and one log wakes it.", "నిద్రలో, మీ కోసం ఎదురుచూస్తోంది", "Nidralo, mee kosam edurchoostondi", hi="सो रहा है, आपका इंतज़ार कर रहा है", hl="So raha hai, aapka intezaar kar raha hai")
s("universe_plantRow", "{name}, {stage}", "Screen-reader and visible label of one habit plant that is doing well.", "{name}, {stage}", "{name}, {stage}", STR("name", "stage"), hi="{name}, {stage}", hl="{name}, {stage}")
s("universe_plantRowResting", "{name}, {stage}, {state}", "Label of one habit plant that is resting, drooping or asleep. {state} is one of the vitality words.", "{name}, {stage}, {state}", "{name}, {stage}, {state}", STR("name", "stage", "state"), hi="{name}, {stage}, {state}", hl="{name}, {stage}, {state}")

# ---- Personal universe: the welcome back card (W04) ----------------------
# Shown once per absence (RULES.md section 13, `welcome`). Never mentions days away, streaks,
# loss or what was missed; it works with Comfort > hide streak number because it shows no number.
s("universe_welcomeTitle", "Your world is here", "Title of the one-time card on returning to the personal universe after time away. Warm; no guilt, no numbers.", "మీ ప్రపంచం ఇక్కడే ఉంది", "Mee prapancham ikkade undi", hi="आपकी दुनिया यहीं है", hl="Aapki duniya yahin hai")
s("universe_welcomeBody", "Everything is right where you left it. Come back to it whenever you like, in any way that feels doable.", "Body of the welcome-back card. Must not mention days away, streaks or anything missed.", "అంతా మీరు వదిలిన చోటే ఉంది. మీకు వీలైనప్పుడు, మీకు సులభంగా అనిపించే విధంగా తిరిగి రండి.", "Anthaa meeru vadilina chote undi. Meeku veelainappudu, meeku sulabhanga anipinche vidhamga tirigi randi.", hi="सब कुछ वहीं है जहाँ आपने छोड़ा था। जब मन हो, जिस तरह आसान लगे, वैसे लौट आइए।", hl="Sab kuch wahin hai jahan aapne chhoda tha. Jab mann ho, jis tarah aasaan lage, waise laut aaiye.")
s("universe_welcomeCheckIn", "Check in", "Welcome-back card button that opens the ordinary quick check-in.", "చెక్-ఇన్ చేయండి", "Check-in cheyandi", hi="चेक-इन करें", hl="Check-in karein")
s("universe_welcomeExplore", "Just look around", "Welcome-back card button that dismisses the card; nothing is required.", "ఊరికే చూడండి", "Oorike choodandi", hi="बस आसपास देखें", hl="Bas aaspaas dekhein")

# ---- Personal universe: free roam (W05) ----------------------------------
# An optional mode beside tap-to-travel; every place stays reachable without it.
s("universe_freeRoam", "Free roam", "Label of the mode that lets you walk the companion around the island with a pad or arrows. Optional.", "స్వేచ్ఛగా తిరగండి", "Swechchaga tiragandi", hi="खुला घूमें", hl="Khula ghoomein")
s("universe_tapToTravel", "Tap to travel", "Label of the default mode: tap a place and the companion walks there.", "టాప్ చేసి వెళ్ళండి", "Tap chesi vellandi", hi="टैप करके चलें", hl="Tap karke chalein")
s("universe_roamHint", "Drag the pad or hold an arrow to walk. Get close to a place to choose it.", "Hint shown under the free-roam controls.", "నడవడానికి ప్యాడ్‌ను లాగండి లేదా బాణాన్ని నొక్కి ఉంచండి. ఒక చోటుకు దగ్గరగా వెళితే అది ఎంపికవుతుంది.", "Nadavadaniki pad ni laagandi leda baanaanni nokki unchandi. Oka chotuki daggaraga velite adi empikavutundi.", hi="चलने के लिए पैड खींचें या तीर को दबाए रखें। किसी जगह के पास पहुँचते ही वह चुन ली जाती है।", hl="Chalne ke liye pad kheenchein ya teer ko dabaye rakhein. Kisi jagah ke paas pahunchte hi woh chun li jaati hai.")
s("universe_walkForward", "Walk forward", "Screen-reader label of the free-roam up arrow. One activation takes one small step.", "ముందుకు నడవండి", "Munduku nadavandi", hi="आगे चलें", hl="Aage chalein")
s("universe_walkBack", "Walk back", "Screen-reader label of the free-roam down arrow.", "వెనక్కి నడవండి", "Venakki nadavandi", hi="पीछे चलें", hl="Peeche chalein")
s("universe_walkLeft", "Walk left", "Screen-reader label of the free-roam left arrow.", "ఎడమకు నడవండి", "Edamaku nadavandi", hi="बाएँ चलें", hl="Baayein chalein")
s("universe_walkRight", "Walk right", "Screen-reader label of the free-roam right arrow.", "కుడికి నడవండి", "Kudiki nadavandi", hi="दाएँ चलें", hl="Daayein chalein")

