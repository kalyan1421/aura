# F16 Quiet Together + the Lantern Hour wind-down (PRD 06b "F16 Quiet
# Together", "Lantern Hour wind-down (Milestone C)"; 14-states "Quiet
# Together (F16)"). Loaded by tool/l10n_source.py.
# s(key, en, desc, te, te_Latn, ph=None, hi=, hl=)
#
# te / te_Latn / hi / hi_Latn (hl) are first drafts: NEEDS NATIVE REVIEW before launch.
#
# Rules: counts only — never a name, a list of people or a mood. Leaving costs
# nothing: never "left early", "streak", "lost", "stay focused" or any
# pressure. The rhythm shows the next change as a clock time, never a
# countdown. Gestures are unnamed ("Someone lit a candle"). "Quiet Together"
# and "Lantern Hour" stay English in te / te-Latn; Hindi and Hinglish name it
# "साथ में शांति" / "Saath mein shaanti" ("Lantern Hour" is a PRD 18 brand term). Hindi: no
# gendered verb forms (imperatives, nouns, impersonal forms).

# ---- entry (Rooms tab) -----------------------------------------------------------
s("quiet_title", "Quiet Together", "Feature name. Rooms tab card title. Not a PRD 18 brand term: Hindi / Hinglish use their own words.", "Quiet Together", "Quiet Together", hi="साथ में शांति", hl="Saath mein shaanti")
s("quiet_cardBody", "Study, read or rest alongside others. Just a count, a shared sound and gestures.", "Rooms tab card body: what Quiet Together is. Calm, no pressure.", "ఇతరులతో కలిసి చదువుకోండి, పుస్తకం చదవండి లేదా విశ్రాంతి తీసుకోండి. ఒక సంఖ్య, ఒకే శబ్దం, సంజ్ఞలు మాత్రమే.", "Itarulatho kalisi study cheyandi, chadavandi leda rest teesukondi. Oka count, oke sound, gestures maatrame.", hi="दूसरों के साथ पढ़ाई करें, किताब पढ़ें या आराम करें। बस एक गिनती, एक साझा आवाज़ और भाव।", hl="Doosron ke saath padhai karein, kitaab padhein ya aaram karein. Bas ek ginti, ek shared awaaz aur gestures.")
s("quiet_modeStudy", "Study", "Mode button: study together.", "చదువు", "Study", hi="पढ़ाई", hl="Padhai")
s("quiet_modeRead", "Read", "Mode button: read together.", "పఠనం", "Read", hi="पढ़ना", hl="Padhna")
s("quiet_modeRest", "Rest", "Mode button: rest together.", "విశ్రాంతి", "Rest", hi="आराम", hl="Aaram")
s("quiet_titleStudy", "Study together", "Screen title for the Study session.", "కలిసి చదువుకుందాం", "Kalisi study cheddam", hi="साथ में पढ़ाई", hl="Saath mein padhai")
s("quiet_titleRead", "Read together", "Screen title for the Read session.", "కలిసి చదువుదాం", "Kalisi chaduvudam", hi="साथ में पढ़ना", hl="Saath mein padhna")
s("quiet_titleRest", "Rest together", "Screen title for the Rest session.", "కలిసి విశ్రాంతి తీసుకుందాం", "Kalisi rest teesukundam", hi="साथ में आराम", hl="Saath mein aaram")

# ---- the session -------------------------------------------------------------------
s("quiet_count", "{count, plural, =1{1 here} other{{count} here}}", "How many people are in this session right now. A number only, never names.", "{count, plural, =1{ఇక్కడ 1} other{ఇక్కడ {count}}}", "{count, plural, =1{Ikkada 1} other{Ikkada {count}}}", INT("count"), hi="{count, plural, =1{यहाँ 1} other{यहाँ {count}}}", hl="{count, plural, =1{Yahan 1} other{Yahan {count}}}")
s("quiet_justYou", "Just you right now. Others drop in through the hour.", "Shown when the count is 1 (never faked). PRD 14-states copy.", "ప్రస్తుతం మీరు మాత్రమే. గంటలో ఇతరులు వచ్చి చేరుతుంటారు.", "Prastutam meeru maatrame. Gantalo itarulu vachi cherutuntaaru.", hi="अभी सिर्फ़ आप हैं। घंटे भर में और लोग आते रहते हैं।", hl="Abhi sirf aap hain. Ghante bhar mein aur log aate rehte hain.")
s("quiet_joining", "Finding your quiet place…", "While joining a session.", "మీ నిశ్శబ్ద చోటు వెతుకుతున్నాం…", "Mee quiet chotu vetukutunnaam…", hi="आपकी शांत जगह ढूँढी जा रही है…", hl="Aapki shaant jagah dhoondhi ja rahi hai…")
s("quiet_reconnecting", "Reconnecting…", "Chip when the realtime link dropped. Never a failure; the shared sound keeps playing.", "మళ్ళీ కనెక్ట్ అవుతోంది…", "Malli connect avutondi…", hi="फिर से जुड़ रहा है…", hl="Phir se jud raha hai…")
s("quiet_offline", "Quiet Together needs a connection. Sanctuary works offline.", "Offline state. PRD 14-states copy.", "Quiet Together కి కనెక్షన్ కావాలి. Sanctuary ఆఫ్‌లైన్‌లో కూడా పనిచేస్తుంది.", "Quiet Together ki connection kaavali. Sanctuary offline lo kooda pani chestundi.", hi="साथ में शांति के लिए कनेक्शन चाहिए। Sanctuary ऑफ़लाइन भी चलता है।", hl="Saath mein shaanti ke liye connection chahiye. Sanctuary offline bhi chalta hai.")
s("quiet_openSanctuary", "Open Sanctuary", "Button from the offline / paused state to the Sanctuary tab.", "Sanctuary తెరవండి", "Sanctuary open cheyandi", hi="Sanctuary खोलें", hl="Sanctuary kholein")
s("quiet_paused", "Quiet Together is resting for a bit. The Sanctuary is always open.", "Kill switch on for this region. Calm, no blame.", "Quiet Together కాసేపు విశ్రాంతిలో ఉంది. Sanctuary ఎప్పుడూ తెరిచే ఉంటుంది.", "Quiet Together kaasepu vishraanti lo undi. Sanctuary eppudu terichi untundi.", hi="साथ में शांति थोड़ी देर आराम कर रहा है। Sanctuary हमेशा खुला है।", hl="Saath mein shaanti thodi der aaram kar raha hai. Sanctuary hamesha khula hai.")
s("quiet_failed", "Quiet Together couldn't open just now. Please try again.", "The join failed for another reason (not offline). No blame.", "Quiet Together ఇప్పుడు తెరుచుకోలేదు. దయచేసి మళ్ళీ ప్రయత్నించండి.", "Quiet Together ippudu teruchukoledu. Dayachesi malli try cheyandi.", hi="साथ में शांति अभी खुल नहीं पाया। कृपया फिर से कोशिश करें।", hl="Saath mein shaanti abhi khul nahi paaya. Please phir se try karein.")
s("quiet_tryAgain", "Try again", "Retry button.", "మళ్ళీ ప్రయత్నించండి", "Malli try cheyandi", hi="फिर से कोशिश करें", hl="Phir se try karein")
s("quiet_nextBlock", "The next session starts at {time}.", "Near the end of a 60-minute block. A clock time, never a countdown; the next block follows by itself.", "తర్వాతి సెషన్ {time}కి మొదలవుతుంది.", "Tarvaathi session {time} ki modalavutundi.", STR("time"), hi="अगला सेशन {time} बजे शुरू होगा।", hl="Agla session {time} baje shuru hoga.")
s("quiet_leave", "Leave", "Leave the session. Leaving costs nothing: no confirmation, no loss copy.", "వెళ్ళిపోండి", "Vellipondi", hi="निकलें", hl="Niklein")
s("quiet_leaveNote", "Leave whenever you like. Nothing is lost.", "Small line near Leave: leaving costs nothing.", "మీకు ఎప్పుడు కావాలంటే అప్పుడు వెళ్ళిపోవచ్చు. ఏదీ పోదు.", "Meeku eppudu kaavalante appudu vellipovachu. Edi podu.", hi="जब चाहें निकल सकते हैं। कुछ नहीं खोता।", hl="Jab chahein nikal sakte hain. Kuch nahi khota.")

# ---- the shared sound ------------------------------------------------------------
s("quiet_soundTitle", "The shared sound", "Section title: a soundscape everyone plays on their own phone from the same start.", "అందరి శబ్దం", "Andari sound", hi="साझा आवाज़", hl="Shared awaaz")
s("quiet_soundBody", "Everyone hears the same moment, played on your own phone. No microphone, nothing recorded.", "Explains the shared sound: local playback, same point in the mix, no user audio.", "అందరూ ఒకే క్షణాన్ని వింటారు, మీ ఫోన్‌లోనే ప్లే అవుతుంది. మైక్రోఫోన్ లేదు, ఏదీ రికార్డ్ కాదు.", "Andaru oke kshanaanni vintaaru, mee phone lone play avutundi. Microphone ledu, edi record kaadu.", hi="सब एक ही पल सुनते हैं, आपके अपने फ़ोन पर। कोई माइक्रोफ़ोन नहीं, कुछ रिकॉर्ड नहीं होता।", hl="Sab ek hi pal sunte hain, aapke apne phone par. Koi microphone nahi, kuch record nahi hota.")
s("quiet_soundPlay", "Play the shared sound", "Button: start the shared sound. Nothing plays until this tap.", "అందరి శబ్దం ప్లే చేయండి", "Andari sound play cheyandi", hi="साझा आवाज़ चलाएँ", hl="Shared awaaz chalayein")
s("quiet_soundStop", "Stop the sound", "Button: stop the shared sound on this phone.", "శబ్దం ఆపండి", "Sound aapandi", hi="आवाज़ रोकें", hl="Awaaz rokein")
s("quiet_soundVolume", "Volume", "Slider label: this person's own volume for the shared sound.", "వాల్యూమ్", "Volume", hi="आवाज़ का स्तर", hl="Volume")
s("quiet_soundDownload", "The shared sound needs a one-time download.", "A base recording isn't on the phone yet. The session works silently meanwhile. PRD 14-states copy.", "అందరి శబ్దానికి ఒక్కసారి డౌన్‌లోడ్ కావాలి.", "Andari sound ki okkasaari download kaavali.", hi="साझा आवाज़ के लिए एक बार डाउनलोड चाहिए।", hl="Shared awaaz ke liye ek baar download chahiye.")
s("quiet_soundDownloadCta", "Download", "Button: download the base recordings.", "డౌన్‌లోడ్ చేయండి", "Download cheyandi", hi="डाउनलोड करें", hl="Download karein")
s("quiet_soundUnavailable", "The sound can't play on this phone right now. Being here is enough.", "No stem of the mix can play. Calm.", "ఈ ఫోన్‌లో ఇప్పుడు శబ్దం ప్లే కావడం లేదు. ఇక్కడ ఉండటమే చాలు.", "Ee phone lo ippudu sound play kaavadam ledu. Ikkada undatame chaalu.", hi="इस फ़ोन पर अभी आवाज़ नहीं चल पा रही। यहाँ होना ही काफ़ी है।", hl="Is phone par abhi awaaz nahi chal pa rahi. Yahan hona hi kaafi hai.")

# ---- the focus rhythm (Study) -------------------------------------------------------
s("quiet_rhythm", "Focus rhythm (25 / 5)", "Switch, off by default: follow the shared 25-minute focus / 5-minute break blocks.", "ఫోకస్ రిథమ్ (25 / 5)", "Focus rhythm (25 / 5)", hi="फ़ोकस रिदम (25 / 5)", hl="Focus rhythm (25 / 5)")
s("quiet_rhythmBody", "Optional. Everyone's breaks line up.", "Under the rhythm switch. No pressure.", "ఐచ్ఛికం. అందరి విరామాలు ఒకేసారి వస్తాయి.", "Optional. Andari breaks okesaari vastaayi.", hi="अपनी मर्ज़ी से। सबके ब्रेक एक साथ आते हैं।", hl="Apni marzi se. Sabke break ek saath aate hain.")
s("quiet_rhythmFocus", "Focus · break at {time}", "Rhythm on, in a focus stretch: the next change as a clock time (never a countdown).", "ఫోకస్ · {time}కి విరామం", "Focus · {time} ki break", STR("time"), hi="फ़ोकस · {time} बजे ब्रेक", hl="Focus · {time} baje break")
s("quiet_rhythmBreak", "Break · focus again at {time}", "Rhythm on, in a break: the next change as a clock time.", "విరామం · {time}కి మళ్ళీ ఫోకస్", "Break · {time} ki malli focus", STR("time"), hi="ब्रेक · {time} बजे फिर फ़ोकस", hl="Break · {time} baje phir focus")
s("quiet_rhythmToBreak", "Break time.", "Announced (politely) when the shared break begins.", "విరామ సమయం.", "Break time.", hi="ब्रेक का समय।", hl="Break ka samay.")
s("quiet_rhythmToFocus", "Focus time.", "Announced (politely) when the shared focus stretch begins.", "ఫోకస్ సమయం.", "Focus time.", hi="फ़ोकस का समय।", hl="Focus ka samay.")

# ---- gestures (to the whole session, unnamed) --------------------------------------------
s("quiet_gesturesTitle", "Send a gesture to everyone here", "Gesture tray title. Gestures go to the whole session, never to a person.", "ఇక్కడ అందరికీ ఒక సంజ్ఞ పంపండి", "Ikkada andariki oka gesture pampandi", hi="यहाँ सबको एक भाव भेजें", hl="Yahan sabko ek gesture bhejein")
s("quiet_gestureSent", "You sent {gesture}", "Your own gesture, shown only to you.", "మీరు {gesture} పంపారు", "Meeru {gesture} pampaaru", STR("gesture"), hi="आपने {gesture} भेजा", hl="Aapne {gesture} bheja")
for key, en, te, tl, hi, hl in [
    ("warm_tea", "Someone shared warm tea", "ఎవరో వెచ్చని టీ పంచుకున్నారు", "Evaro vechani chai panchukunnaru", "किसी ने गरम चाय बाँटी", "Kisi ne garam chai baanti"),
    ("light_a_candle", "Someone lit a candle", "ఎవరో ఒక దీపం వెలిగించారు", "Evaro oka deepam veliginchaaru", "किसी ने एक दीया जलाया", "Kisi ne ek diya jalaya"),
    ("hug", "Someone sent a hug", "ఎవరో ఒక హగ్ పంపారు", "Evaro oka hug pampaaru", "किसी ने एक झप्पी भेजी", "Kisi ne ek jhappi bheji"),
    ("me_too", "Someone said: me too", "ఎవరో అన్నారు: నేను కూడా", "Evaro annaru: nenu kooda", "किसी ने कहा: मैं भी", "Kisi ne kaha: main bhi"),
    ("soft_rain", "Someone sent soft rain", "ఎవరో చిరుజల్లు పంపారు", "Evaro chirujallu pampaaru", "किसी ने हल्की बारिश भेजी", "Kisi ne halki baarish bheji"),
    ("stargaze", "Someone is stargazing with you", "ఎవరో మీతో పాటు నక్షత్రాలు చూస్తున్నారు", "Evaro meetho paatu stars chustunnaru", "कोई आपके साथ तारे देख रहा है", "Koi aapke saath taare dekh raha hai"),
    ("deep_breath", "Someone took a deep breath", "ఎవరో దీర్ఘ శ్వాస తీసుకున్నారు", "Evaro deergha swaasa teesukunnaru", "किसी ने एक गहरी साँस ली", "Kisi ne ek gehri saans li"),
    ("youre_not_alone", "Someone says: you're not alone", "ఎవరో అంటున్నారు: మీరు ఒంటరి కాదు", "Evaro antunnaru: meeru ontari kaadu", "कोई कह रहा है: आप अकेले नहीं हैं", "Koi keh raha hai: aap akele nahi hain"),
]:
    s(f"quiet_moment_{key}", en, "An unnamed gesture in Quiet Together (also the Reduce Motion still line). Never who sent it.", te, tl, hi=hi, hl=hl)

# ---- session menu, safety ------------------------------------------------------------
s("quiet_menu", "Session menu", "Tooltip for the session's overflow menu.", "సెషన్ మెనూ", "Session menu", hi="सेशन मेनू", hl="Session menu")
s("quiet_report", "Report a problem here", "Session menu: report (nobody is shown, so there is no per-person block or mute).", "ఇక్కడ ఒక సమస్యను రిపోర్ట్ చేయండి", "Ikkada oka problem report cheyandi", hi="यहाँ की किसी समस्या की रिपोर्ट करें", hl="Yahan ki kisi problem ki report karein")
s("quiet_hideGestures", "Hide gestures", "Session menu: hide gesture animations for yourself only.", "సంజ్ఞలు దాచండి", "Gestures daachandi", hi="भाव छिपाएँ", hl="Gestures chhupayein")
s("quiet_showGestures", "Show gestures", "Session menu: show gestures again.", "సంజ్ఞలు చూపించండి", "Gestures choopinchandi", hi="भाव दिखाएँ", hl="Gestures dikhayein")
s("quiet_gesturesHidden", "Gestures are hidden for you.", "Shown while you hid gestures (only for you).", "మీకు సంజ్ఞలు దాచబడ్డాయి.", "Meeku gestures daachabaddaayi.", hi="आपके लिए भाव छिपे हुए हैं।", hl="Aapke liye gestures chhupe hue hain.")
s("quiet_reportBody", "Nobody is shown here, so tell us what happened. A moderator looks at this session's recent gestures.", "Report sheet intro for Quiet Together.", "ఇక్కడ ఎవరూ కనిపించరు, కాబట్టి ఏం జరిగిందో చెప్పండి. ఈ సెషన్‌లోని ఇటీవలి సంజ్ఞలను ఒక మోడరేటర్ చూస్తారు.", "Ikkada evaru kanipincharu, kaabatti em jarigindo cheppandi. Ee session loni recent gestures ni oka moderator chustaaru.", hi="यहाँ कोई दिखाई नहीं देता, तो बताएँ क्या हुआ। एक मॉडरेटर इस सेशन के हाल के भाव देखेगा।", hl="Yahan koi dikhai nahi deta, to batayein kya hua. Ek moderator is session ke haal ke gestures dekhega.")
s("quiet_reportNote", "Anything else a moderator should know? (optional)", "Optional note field in the report sheet (moderators only).", "మోడరేటర్‌కు ఇంకేమైనా తెలియాలా? (ఐచ్ఛికం)", "Moderator ki inkemaina teliyaala? (optional)", hi="मॉडरेटर को और कुछ जानना चाहिए? (वैकल्पिक)", hl="Moderator ko aur kuch jaanna chahiye? (optional)")
s("quiet_reportSend", "Send report", "Report sheet button.", "రిపోర్ట్ పంపండి", "Report pampandi", hi="रिपोर्ट भेजें", hl="Report bhejein")
s("quiet_reportThanks", "Thank you. A moderator will take a look.", "After a report was sent.", "ధన్యవాదాలు. ఒక మోడరేటర్ పరిశీలిస్తారు.", "Dhanyavaadaalu. Oka moderator parisheelistaaru.", hi="धन्यवाद। एक मॉडरेटर इसे देखेगा।", hl="Dhanyavaad. Ek moderator ise dekhega.")
s("quiet_reportFailed", "That didn't go through. Please try again.", "Report failed (connection). No blame.", "అది జరగలేదు. దయచేసి మళ్ళీ ప్రయత్నించండి.", "Adi jaragaledu. Dayachesi malli try cheyandi.", hi="यह हो नहीं पाया। कृपया फिर से कोशिश करें।", hl="Yeh ho nahi paaya. Please phir se try karein.")

# ---- the Lantern Hour wind-down (in a room) ---------------------------------------------------
s("rooms_windDownTitle", "Wind down together", "Room card title and button during Lantern Hour from 22:30: a shared 20-minute wind-down.", "కలిసి నెమ్మదిద్దాం", "Kalisi nemmadiddaam", hi="साथ में सुकून से", hl="Saath mein sukoon se")
s("rooms_windDownBody", "Twenty quiet minutes to end the day: one shared sound, slow breathing and a few gentle words.", "Room card body for the wind-down. No narration, no pressure.", "రోజును ముగించడానికి ఇరవై నిశ్శబ్ద నిమిషాలు: ఒకే శబ్దం, నెమ్మదైన శ్వాస, కొన్ని మృదువైన మాటలు.", "Rojunu muginchadaaniki iravai nishabda nimishaalu: oke sound, nemmadaina swaasa, konni mruduvaina maatalu.", hi="दिन खत्म करने के लिए बीस शांत मिनट: एक साझा आवाज़, धीमी साँसें और कुछ नरम शब्द।", hl="Din khatam karne ke liye bees shaant minute: ek shared awaaz, dheemi saansein aur kuch narm shabd.")
s("rooms_windDownCount", "{count, plural, =0{Nobody winding down yet} =1{1 winding down} other{{count} winding down}}", "The room total winding down now (never who).", "{count, plural, =0{ఇంకా ఎవరూ నెమ్మదించలేదు} =1{1 నెమ్మదిస్తున్నారు} other{{count} మంది నెమ్మదిస్తున్నారు}}", "{count, plural, =0{Inka evaru nemmadinchaledu} =1{1 nemmadistunnaru} other{{count} mandi nemmadistunnaru}}", INT("count"), hi="{count, plural, =0{अभी कोई नहीं} =1{1 सुकून में} other{{count} सुकून में}}", hl="{count, plural, =0{Abhi koi nahi} =1{1 sukoon mein} other{{count} sukoon mein}}")
s("rooms_windDownBack", "Back to the wind-down", "Room card button after you joined the wind-down.", "నెమ్మదింపుకు తిరిగి వెళ్ళండి", "Wind-down ki tirigi vellandi", hi="वापस सुकून में", hl="Wapas sukoon mein")
s("rooms_windDownFailed", "That didn't go through. Please try again.", "Joining the wind-down failed (connection, or it just ended). No blame.", "అది జరగలేదు. దయచేసి మళ్ళీ ప్రయత్నించండి.", "Adi jaragaledu. Dayachesi malli try cheyandi.", hi="यह हो नहीं पाया। कृपया फिर से कोशिश करें।", hl="Yeh ho nahi paaya. Please phir se try karein.")
s("rooms_windDownEnded", "The wind-down has ended. Rest well.", "When the 20 minutes are over. Never 'finished early' or a score.", "నెమ్మదింపు ముగిసింది. హాయిగా విశ్రాంతి తీసుకోండి.", "Wind-down mugisindi. Haayiga rest teesukondi.", hi="सुकून का समय पूरा हुआ। अच्छे से आराम करें।", hl="Sukoon ka samay poora hua. Acche se aaram karein.")
s("rooms_windDownLeave", "Leave", "Leave the wind-down. Costs nothing.", "వెళ్ళిపోండి", "Vellipondi", hi="निकलें", hl="Niklein")
for key, en, te, tl, hi, hl in [
    ("arrive", "Arrive. There's nothing to do now.", "చేరుకోండి. ఇప్పుడు చేయాల్సింది ఏమీ లేదు.", "Cherukondi. Ippudu cheyaalsindi emi ledu.", "आ जाइए। अभी कुछ करने को नहीं है।", "Aa jaiye. Abhi kuch karne ko nahi hai."),
    ("day_quieter", "Let the day get quieter.", "రోజును నెమ్మదిగా నిశ్శబ్దం కానివ్వండి.", "Rojunu nemmadiga nishabdam kaanivvandi.", "दिन को धीरे-धीरे शांत होने दें।", "Din ko dheere-dheere shaant hone dein."),
    ("shoulders", "Let your shoulders soften.", "మీ భుజాలను మెత్తబడనివ్వండి.", "Mee bhujaalanu mettabadanivvandi.", "कंधों को ढीला होने दें।", "Kandhon ko dheela hone dein."),
    ("nothing_to_do", "Nothing needs you right now.", "ఇప్పుడు మీ అవసరం దేనికీ లేదు.", "Ippudu mee avasaram deniki ledu.", "अभी किसी चीज़ को आपकी ज़रूरत नहीं है।", "Abhi kisi cheez ko aapki zaroorat nahi hai."),
    ("slower", "Let each breath be a little slower.", "ప్రతి శ్వాసను కొంచెం నెమ్మదిగా కానివ్వండి.", "Prati swaasanu konchem nemmadiga kaanivvandi.", "हर साँस को थोड़ा और धीमा होने दें।", "Har saans ko thoda aur dheema hone dein."),
    ("rest_well", "Rest well. The night can hold the rest.", "హాయిగా విశ్రాంతి తీసుకోండి. మిగతాది రాత్రి చూసుకుంటుంది.", "Haayiga rest teesukondi. Migataadi raatri choosukuntundi.", "अच्छे से आराम करें। बाकी रात सँभाल लेगी।", "Acche se aaram karein. Baaki raat sambhaal legi."),
]:
    s(f"rooms_windDownCue_{key}", en, "A preset text cue of the Lantern Hour wind-down (shown on screen, never spoken). Gentle, no promises about sleep.", te, tl, hi=hi, hl=hl)
