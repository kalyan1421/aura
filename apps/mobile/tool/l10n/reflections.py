# Reflections (F6): short moderated posts in a mood room, answered only with
# gestures. Loaded by tool/l10n_source.py.
# s(key, en, desc, te, te_Latn, ph=None) · edit(key, en=, te=, tl=, desc=)
#
# te / te_Latn are first drafts: NEEDS NATIVE REVIEW before beta. The
# rejection, crisis and composer lines also need the safe-messaging
# self-review (A9): no string names a method; nothing blames the writer.
#
# Rules (PRD 06b F6, 14-states "Reflection composer"): never "post", "chat",
# "reply" or "comment"; nobody's age is ever mentioned; pseudonyms come from
# the server and are never translated; reflection text is shown as written.

# ---- Section in the room -------------------------------------------------------
s("reflections_title", "Reflections", "Room screen: heading over the reflections (short moderated posts answered only with gestures).", "మనసులో మాటలు", "Reflections")
s("reflections_intro", "A few words from people here. Answered only with gestures.", "Room screen: one line under the Reflections heading. No replies exist.", "ఇక్కడ ఉన్నవాళ్ళ కొన్ని మాటలు. వీటికి సంజ్ఞలతో మాత్రమే స్పందించవచ్చు.", "Ikkada unnavaalla konni maatalu. Veetiki gestures tho maatrame respond avvochu.")
s("reflections_share", "Share a reflection", "Button that opens the reflection composer.", "మీ మాట పంచుకోండి", "Oka reflection share cheyandi")
s("reflections_empty", "No reflections here yet. You can share one, or just read and send gestures.", "Reflections list is empty. No pressure to write.", "ఇక్కడ ఇంకా ఏ మాటలూ లేవు. మీరు ఒకటి పంచుకోవచ్చు, లేదా చదివి సంజ్ఞలు పంపవచ్చు.", "Ikkada inka e reflections levu. Meeru okati share cheyochu, leda chadivi gestures pampochu.")
s("reflections_emptyMemory", "No reflections were shared in this room.", "A memory room with no reflections.", "ఈ రూమ్‌లో ఏ మాటలూ పంచుకోలేదు.", "Ee room lo e reflections share cheyyaledu.")
s("reflections_loadFailed", "Reflections couldn't load just now.", "Loading reflections failed (server or network). No blame.", "ఇప్పుడు మాటలు లోడ్ కాలేదు.", "Ippudu reflections load kaaledu.")
s("reflections_offline", "Reflections need a connection. Anything you write stays on this phone.", "Offline: the list can't load; drafts are kept.", "మాటలకు కనెక్షన్ కావాలి. మీరు రాసింది ఈ ఫోన్‌లోనే ఉంటుంది.", "Reflections ki connection kaavaali. Meeru raasindi ee phone lone untundi.")
s("reflections_memory", "This room is a memory: its reflections can be read, not added to.", "A memory room: read-only list, no composer.", "ఈ రూమ్ ఒక జ్ఞాపకం: ఇందులోని మాటలు చదవవచ్చు, కొత్తవి జోడించలేరు.", "Ee room oka memory: indulo reflections chadavochu, kothavi add cheyyaleru.")
s("reflections_paused", "Reflections are resting for a bit. Gestures still work.", "Composer paused (kill switch / reduced mode). Contract wording.", "మాటలు కాసేపు విశ్రాంతి తీసుకుంటున్నాయి. సంజ్ఞలు పనిచేస్తూనే ఉంటాయి.", "Reflections konchem sepu rest teesukuntunnaayi. Gestures pani chestune untaayi.")
s("reflections_limit", "{count, plural, =1{That's 1 reflection for today. Gestures are always open.} other{That's {count} reflections for today. Gestures are always open.}}", "Daily cap reached (3 per room, or 10 across rooms, rolling 24 h). Calm; not a punishment.", "{count, plural, =1{ఈ రోజుకు 1 మాట అయిపోయింది. సంజ్ఞలు ఎప్పుడూ తెరిచే ఉంటాయి.} other{ఈ రోజుకు {count} మాటలు అయిపోయాయి. సంజ్ఞలు ఎప్పుడూ తెరిచే ఉంటాయి.}}", "{count, plural, =1{Ee roju ki 1 reflection ayipoyindi. Gestures eppudu open ae untaayi.} other{Ee roju ki {count} reflections ayipoyaayi. Gestures eppudu open ae untaayi.}}", INT("count"))
s("reflections_slow", "Reflections are slower right now", "The automatic check is degraded: sending may take longer.", "ప్రస్తుతం మాటలు కొంచెం నెమ్మదిగా వెళ్తున్నాయి", "Ippudu reflections konchem slow ga velthunnaayi")
s("reflections_left", "{remaining} of {total} left today", "Composer / section: reflections left in this room today (rolling 24 h).", "ఈ రోజు {total}లో {remaining} మిగిలాయి", "Ee roju {total} lo {remaining} migilaayi", INT("remaining", "total"))

# ---- Cards ------------------------------------------------------------------------
s("reflections_cardLabel", "Reflection by {pseudonym}", "Screen reader: a reflection card (the text follows).", "{pseudonym} రాసిన మాట", "{pseudonym} raasina reflection", STR("pseudonym"))
s("reflections_mine", "Your reflection", "Label on your own reflection card.", "మీ మాట", "Mee reflection")
s("reflections_onlyYou", "Only you can see this", "Your own reflection that is not published (checking, held, not posted, taken down).", "ఇది మీకు మాత్రమే కనిపిస్తుంది", "Idi meeku maatrame kanipistundi")
s("reflections_pending", "Still checking. You can keep reading.", "Your reflection is still being checked (moderation took longer than 2 s).", "ఇంకా చూస్తున్నాం. మీరు చదువుతూ ఉండొచ్చు.", "Inka chustunnaam. Meeru chaduvutu undochu.")
s("reflections_heldSoon", "Waiting for a quick check", "Your reflection is held for a human review (only you see it).", "ఒక చిన్న తనిఖీ కోసం ఎదురుచూస్తోంది", "Oka chinna check kosam wait chestondi")
s("reflections_heldOvernight", "Waiting for a quick check. This may take until morning.", "Held overnight (the reviewer's night).", "ఒక చిన్న తనిఖీ కోసం ఎదురుచూస్తోంది. ఉదయం వరకు పట్టొచ్చు.", "Oka chinna check kosam wait chestondi. Podduna varaku pattochu.")
s("reflections_rejectedCard", "This one didn't go up here.", "Your own rejected reflection in the list (a reason line follows).", "ఇది ఇక్కడ పెట్టలేకపోయాం.", "Idi ikkada pettalekapoyaam.")
s("reflections_removedCard", "This one was taken down after a review.", "Your own reflection removed after a report was upheld. Calm, no blame.", "ఒక సమీక్ష తర్వాత దీన్ని తీసేశాం.", "Oka review tarvaatha deenni teesesaam.")
s("reflections_gestureCount", "{count, plural, =0{No gestures yet} =1{1 gesture} other{{count} gestures}}", "Gestures on your own published reflection.", "{count, plural, =0{ఇంకా సంజ్ఞలు లేవు} =1{1 సంజ్ఞ} other{{count} సంజ్ఞలు}}", "{count, plural, =0{Inka gestures levu} =1{1 gesture} other{{count} gestures}}", INT("count"))
s("reflections_countPrivate", "Only you see this count", "Under the gesture count on your own reflection: counts are never public.", "ఈ సంఖ్య మీకు మాత్రమే కనిపిస్తుంది", "Ee count meeku maatrame kanipistundi")
s("reflections_options", "Reflection options", "Tooltip / screen reader: the ⋯ menu on a reflection card (report, block, mute, delete).", "మాట ఆప్షన్లు", "Reflection options")
s("reflections_gestureHint", "Sends to {pseudonym} for this reflection", "Screen-reader hint on a gesture under someone's reflection.", "ఈ మాట కోసం {pseudonym}కి పంపుతుంది", "Ee reflection kosam {pseudonym} ki pamputundi", STR("pseudonym"))
s("reflections_gestureSent", "{gesture} sent to {pseudonym}", "After sending a gesture on a reflection (announced).", "{pseudonym}కి {gesture} పంపారు", "{pseudonym} ki {gesture} pampaaru", STR("gesture", "pseudonym"))
s("reflections_delete", "Delete", "Delete your own published reflection (no editing exists).", "తొలగించు", "Delete")
s("reflections_withdraw", "Withdraw", "Withdraw your own reflection while it is checked or held.", "వెనక్కి తీసుకో", "Withdraw")
s("reflections_deleteTitle", "Delete this reflection?", "Delete confirmation title.", "ఈ మాటను తొలగించాలా?", "Ee reflection ni delete cheyaala?")
s("reflections_deleteBody", "It goes away for everyone here. Reflections can't be edited, but you can share a new one.", "Delete confirmation body.", "ఇది ఇక్కడ అందరికీ కనిపించదు. మాటలను మార్చలేరు, కానీ కొత్తది పంచుకోవచ్చు.", "Idi ikkada andariki kanipinchadu. Reflections edit cheyyaleru, kaani kothadi share cheyochu.")
s("reflections_withdrawTitle", "Withdraw this reflection?", "Withdraw confirmation title.", "ఈ మాటను వెనక్కి తీసుకోవాలా?", "Ee reflection ni withdraw cheyaala?")
s("reflections_withdrawBody", "It won't go up. You can share a new one any time.", "Withdraw confirmation body.", "ఇది పెట్టబడదు. మీరు ఎప్పుడైనా కొత్తది పంచుకోవచ్చు.", "Idi pettabadadu. Meeru eppudaina kothadi share cheyochu.")
s("reflections_deleted", "Your reflection is gone.", "After deleting or withdrawing your reflection.", "మీ మాట తీసేశాం.", "Mee reflection teesesaam.")
s("reflections_reportTitle", "Report this reflection", "Report sheet title for a reflection (F9).", "ఈ మాటను రిపోర్ట్ చేయండి", "Ee reflection ni report cheyandi")
s("reflections_reportHidden", "Thank you for telling us. That reflection is hidden for you now.", "After reporting a reflection (it hides for the reporter at once).", "చెప్పినందుకు ధన్యవాదాలు. ఆ మాట ఇప్పుడు మీకు కనిపించదు.", "Cheppinanduku thanks. Aa reflection ippudu meeku kanipinchadu.")

# ---- Composer ----------------------------------------------------------------------
s("reflections_composeTitle", "Share a reflection", "Composer sheet title.", "మీ మాట పంచుకోండి", "Oka reflection share cheyandi")
s("reflections_composeLabel", "What's on your mind?", "Composer text field label. Gentle; no pressure.", "మీ మనసులో ఏముంది?", "Mee manasulo emundi?")
s("reflections_composeNote", "A few words for this room. People can answer with gestures only, never replies.", "Composer helper line.", "ఈ రూమ్ కోసం కొన్ని మాటలు. ఇతరులు సంజ్ఞలతో మాత్రమే స్పందిస్తారు, జవాబులు ఉండవు.", "Ee room kosam konni maatalu. Itarulu gestures tho maatrame respond avutaaru, replies undavu.")
s("reflections_counter", "{count}/{max}", "Composer character counter (characters as a person sees them).", "{count}/{max}", "{count}/{max}", INT("count", "max"))
s("reflections_counterSemantic", "{count} of {max} characters", "Screen reader: the composer's character counter.", "{max}లో {count} అక్షరాలు", "{max} lo {count} characters", INT("count", "max"))
s("reflections_tooLong", "A little shorter, please: up to {max} characters.", "Composer over the limit (Send is disabled).", "కొంచెం చిన్నగా రాయండి: {max} అక్షరాల వరకు.", "Konchem chinnaga raayandi: {max} characters varaku.", INT("max"))
s("reflections_send", "Send", "Composer send button.", "పంపండి", "Pampandi")
s("reflections_sending", "Sending gently…", "Composer while the check takes longer than usual.", "నెమ్మదిగా పంపుతున్నాం…", "Nemmadiga pamputunnaam…")
s("reflections_contactBlocked", "Phone numbers, links and handles can't be shared here. It keeps everyone safer.", "On-device block: contact details or a link in the text. Nothing was sent (14-states wording).", "ఫోన్ నంబర్లు, లింక్‌లు, హ్యాండిల్స్ ఇక్కడ పంచుకోలేరు. ఇది అందరినీ సురక్షితంగా ఉంచుతుంది.", "Phone numbers, links, handles ikkada share cheyyaleru. Idi andarini safe ga unchutundi.")
s("reflections_draftKept", "Draft kept. You can send it once you're back online.", "Composer offline: Send is disabled, the text stays on this phone.", "డ్రాఫ్ట్ భద్రంగా ఉంది. మళ్ళీ ఆన్‌లైన్‌కి వచ్చాక పంపవచ్చు.", "Draft safe ga undi. Malli online ki vachaaka pampochu.")
s("reflections_sendFailed", "It didn't send just now. Your words are still here: try again in a moment.", "A send failed (network / server). The draft and its id are kept.", "ఇప్పుడు పంపలేకపోయాం. మీ మాటలు ఇక్కడే ఉన్నాయి: కాసేపట్లో మళ్ళీ ప్రయత్నించండి.", "Ippudu pampalekapoyaam. Mee maatalu ikkade unnaayi: kaasepatlo malli try cheyandi.")
s("reflections_rejectedContact", "Reflections can't include contact details. Want to try without it?", "Rejected by the server: contact details (PRD F6 wording). The text stays to edit.", "మాటల్లో కాంటాక్ట్ వివరాలు ఉండకూడదు. అవి లేకుండా మళ్ళీ ప్రయత్నిస్తారా?", "Reflections lo contact details undakoodadu. Avi lekunda malli try chestaara?")
s("reflections_rejectedLink", "Reflections can't include links. Want to try without it?", "Rejected by the server: a link. The text stays to edit.", "మాటల్లో లింక్‌లు ఉండకూడదు. అది లేకుండా మళ్ళీ ప్రయత్నిస్తారా?", "Reflections lo links undakoodadu. Adi lekunda malli try chestaara?")
s("reflections_rejectedPersonal", "Questions about someone's personal details can't go up here. Want to try without them?", "Rejected by the server: personal questions (age, school, where someone lives, photos, meeting). Never names the rule; never mentions anyone's age.", "ఎవరివైనా వ్యక్తిగత వివరాల గురించి ప్రశ్నలు ఇక్కడ పెట్టలేరు. అవి లేకుండా ప్రయత్నిస్తారా?", "Evarivaina personal details gurinchi questions ikkada pettaleru. Avi lekunda try chestaara?")
s("reflections_rejectedGeneral", "This one can't go up here. It may hurt someone or share personal details. Your words are still here to edit.", "Rejected by the server (hurtful, sexual, other). 14-states wording; no blame.", "ఇది ఇక్కడ పెట్టలేం. ఇది ఎవరినైనా బాధపెట్టొచ్చు లేదా వ్యక్తిగత వివరాలు పంచుకోవచ్చు. మీ మాటలు మార్చుకోవడానికి ఇక్కడే ఉన్నాయి.", "Idi ikkada pettalemu. Idi evarinaina baadha pettochu leda personal details share cheyochu. Mee maatalu edit cheyyadaniki ikkade unnaayi.")
s("reflections_supportSubtitle", "You don't have to carry it alone.", "Support sheet subtitle after a reflection was crisis-diverted (no rejection wording). Safe messaging.", "మీరు దీన్ని ఒంటరిగా మోయాల్సిన అవసరం లేదు.", "Meeru deenni okkare moyaalsina avasaram ledu.")
s("reflections_backToRoom", "Back to the room", "Support sheet button after a crisis-diverted reflection.", "రూమ్‌కి తిరిగి వెళ్ళండి", "Room ki tirigi vellandi")
