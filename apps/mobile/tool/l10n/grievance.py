# Grievance Officer in-app form (PRD F9 "ticketed form, auto-acknowledged", PRD 19 "the in-app form and email both
# open a console ticket"; REQ-SAFE-11) and the in-app way to ask for a review of a moderation decision. Loaded by
# tool/l10n_source.py.
# s(key, en, desc, te, te_Latn, ph=None, hi=, hl=) · edit(key, en=, te=, tl=, desc=, hi=, hl=)
# Telugu / Tenglish / Hindi / Hinglish: first drafts, NEED NATIVE REVIEW.
#
# Rules: plain and calm; the statutory timelines are facts (IT Rules 2021), not promises about the outcome; a failure
# always says the words are still in the form; nothing asks why someone was sanctioned (no tipping off).

s("grievance_title", "Contact the Grievance Officer",
  "Title of the in-app grievance form (Settings › Help & Safety, the closed-account and banned-device screens).",
  "గ్రీవెన్స్ ఆఫీసర్‌ను సంప్రదించండి",
  "Grievance Officer ni contact cheyandi", hi="शिकायत अधिकारी से संपर्क करें", hl="Grievance Officer se contact karein")
s("grievance_intro", "Tell us about a complaint, content that worries you, your data, or a decision about your account. You get a ticket number right away.",
  "Intro of the grievance form when no officer name is configured.",
  "ఏదైనా ఫిర్యాదు, మిమ్మల్ని ఇబ్బంది పెట్టిన కంటెంట్, మీ డేటా, లేదా మీ ఖాతా గురించి తీసుకున్న నిర్ణయం గురించి మాకు చెప్పండి. మీకు వెంటనే ఒక టికెట్ నంబర్ వస్తుంది.",
  "Edaina complaint, mimmalni ibbandi pettina content, mee data, leda mee account gurinchi teesukunna decision gurinchi maaku cheppandi. Meeku ventane oka ticket number vastundi.",
  hi="किसी शिकायत, परेशान करने वाले कंटेंट, आपके डेटा, या आपके अकाउंट पर लिए गए किसी फ़ैसले के बारे में हमें बताएँ। आपको तुरंत एक टिकट नंबर मिलेगा।",
  hl="Kisi shikayat, pareshan karne wale content, aapke data, ya aapke account par liye gaye kisi faisle ke baare mein humein batayein. Aapko turant ek ticket number milega.")
s("grievance_introNamed", "{name} is Aura's Grievance Officer. Tell us about a complaint, content that worries you, your data, or a decision about your account. You get a ticket number right away.",
  "Intro of the grievance form with the officer's name (from the build's AURA_GRIEVANCE_NAME).",
  "{name} Aura గ్రీవెన్స్ ఆఫీసర్. ఏదైనా ఫిర్యాదు, మిమ్మల్ని ఇబ్బంది పెట్టిన కంటెంట్, మీ డేటా, లేదా మీ ఖాతా గురించి తీసుకున్న నిర్ణయం గురించి మాకు చెప్పండి. మీకు వెంటనే ఒక టికెట్ నంబర్ వస్తుంది.",
  "{name} Aura Grievance Officer. Edaina complaint, mimmalni ibbandi pettina content, mee data, leda mee account gurinchi teesukunna decision gurinchi maaku cheppandi. Meeku ventane oka ticket number vastundi.",
  STR("name"),
  hi="{name} Aura के शिकायत अधिकारी हैं। किसी शिकायत, परेशान करने वाले कंटेंट, आपके डेटा, या आपके अकाउंट पर लिए गए किसी फ़ैसले के बारे में हमें बताएँ। आपको तुरंत एक टिकट नंबर मिलेगा।",
  hl="{name} Aura ke Grievance Officer hain. Kisi shikayat, pareshan karne wale content, aapke data, ya aapke account par liye gaye kisi faisle ke baare mein humein batayein. Aapko turant ek ticket number milega.")
s("grievance_categoryTitle", "What is it about?",
  "Heading over the category choices of the grievance form.",
  "ఇది దేని గురించి?", "Idi deni gurinchi?", hi="यह किस बारे में है?", hl="Yeh kis baare mein hai?")
s("grievance_catGeneral", "Something someone posted or did",
  "Grievance category `general` (complaint about content or conduct; resolved within 7 days).",
  "ఎవరో పెట్టిన పోస్ట్ లేదా వారి ప్రవర్తన", "Evaro pettina post leda vaari pravartana",
  hi="किसी की पोस्ट या बर्ताव", hl="Kisi ki post ya bartaav")
s("grievance_catUnlawful", "Content that may be unlawful",
  "Grievance category `unlawful_content` (36 h).",
  "చట్టవిరుద్ధం కావచ్చు అనిపించే కంటెంట్", "Illegal ayyi undochu anipinche content",
  hi="ऐसा कंटेंट जो गैरकानूनी हो सकता है", hl="Aisa content jo illegal ho sakta hai")
s("grievance_catNudity", "Nudity, sexual content or child sexual abuse material",
  "Grievance category `nudity_csam` (2 h, pages the officer 24x7). Plain, factual wording.",
  "నగ్నత్వం, లైంగిక కంటెంట్ లేదా పిల్లలపై లైంగిక వేధింపుల కంటెంట్", "Nudity, sexual content leda pillala meeda sexual abuse content",
  hi="नग्नता, यौन कंटेंट या बच्चों के यौन शोषण से जुड़ा कंटेंट", hl="Nudity, sexual content ya bachchon ke sexual abuse se juda content")
s("grievance_catNcii", "Intimate images shared without consent",
  "Grievance category `ncii` (2 h, pages the officer 24x7).",
  "అనుమతి లేకుండా పంచుకున్న వ్యక్తిగత చిత్రాలు", "Anumati lekunda share chesina private photos",
  hi="बिना सहमति के शेयर की गई निजी तस्वीरें", hl="Bina consent ke share ki gayi private photos")
s("grievance_catData", "My data or my account",
  "Grievance category `data_request` (7 days).",
  "నా డేటా లేదా నా ఖాతా", "Naa data leda naa account", hi="मेरा डेटा या मेरा अकाउंट", hl="Mera data ya mera account")
s("grievance_catAppeal", "Ask for a review of a decision",
  "Grievance category `moderation_appeal` (7 days): the in-app appeal (one appeal per action, PRD F9).",
  "ఒక నిర్ణయాన్ని మళ్ళీ పరిశీలించమని అడగడం", "Oka decision ni malli review cheyamani adagadam",
  hi="किसी फ़ैसले पर दोबारा विचार का अनुरोध", hl="Kisi faisle ka review maangna")
s("grievance_descriptionLabel", "What happened",
  "Label of the grievance description field (10 to 5,000 characters).",
  "ఏం జరిగింది", "Em jarigindi", hi="क्या हुआ", hl="Kya hua")
s("grievance_descriptionHint", "A few sentences are enough.",
  "Hint in the empty grievance description field.",
  "కొన్ని వాక్యాలు చాలు.", "Konni sentences chaalu.", hi="कुछ वाक्य काफ़ी हैं।", hl="Kuch sentences kaafi hain.")
s("grievance_appealHint", "Which decision, and why it should be looked at again.",
  "Hint in the description field when asking for a review. Never asks the person to explain what they did.",
  "ఏ నిర్ణయం, దాన్ని ఎందుకు మళ్ళీ చూడాలి.", "Ye decision, daanni enduku malli choodaali.",
  hi="कौन-सा फ़ैसला, और उसे दोबारा क्यों देखा जाए।", hl="Kaunsa faisla, aur use dobara kyun dekha jaye.")
s("grievance_whereLabel", "Where was it? (optional)",
  "Optional field: where the content was.",
  "ఎక్కడ? (ఐచ్ఛికం)", "Ekkada? (optional)", hi="कहाँ? (वैकल्पिक)", hl="Kahan? (optional)")
s("grievance_whereHint", "For example: a room, a reflection, or roughly when",
  "Hint in the optional 'where' field.",
  "ఉదాహరణకు: ఒక రూమ్, ఒక రిఫ్లెక్షన్, లేదా సుమారు ఎప్పుడు", "Udaharanaki: oka room, oka reflection, leda sumaaru eppudu",
  hi="जैसे: कोई रूम, कोई दिल की बात, या लगभग कब", hl="Jaise: koi room, koi reflection, ya lagbhag kab")
s("grievance_emailLabel", "Your email",
  "Label of the email field (pre-filled with the account's address when signed in).",
  "మీ ఈమెయిల్", "Mee email", hi="आपका ईमेल", hl="Aapka email")
s("grievance_emailHelp", "We send the acknowledgement and our reply here. Nobody else sees it.",
  "Helper under the email field.",
  "రసీదు, మా సమాధానం ఇక్కడికే పంపుతాం. ఇది వేరెవరికీ కనిపించదు.", "Acknowledgement, maa reply ikkadike pamputaam. Idi verevariki kanipinchadu.",
  hi="पावती और हमारा जवाब यहीं भेजा जाएगा। इसे कोई और नहीं देखता।", hl="Acknowledgement aur hamara jawaab yahin bheja jayega. Ise koi aur nahi dekhta.")
s("grievance_nameLabel", "Your name (optional)",
  "Optional name field.",
  "మీ పేరు (ఐచ్ఛికం)", "Mee peru (optional)", hi="आपका नाम (वैकल्पिक)", hl="Aapka naam (optional)")
s("grievance_send", "Send",
  "Button that sends the grievance.",
  "పంపండి", "Pampandi", hi="भेजें", hl="Bhejein")
s("grievance_timelines", "We acknowledge within 24 hours and resolve within 7 days. Nudity, sexual content involving a child, and intimate images shared without consent are handled within 2 hours.",
  "Statutory timelines under the Send button (IT Rules 2021). Facts only.",
  "24 గంటల్లో రసీదు ఇస్తాం, 7 రోజుల్లో పరిష్కరిస్తాం. నగ్నత్వం, పిల్లలకు సంబంధించిన లైంగిక కంటెంట్, అనుమతి లేకుండా పంచుకున్న వ్యక్తిగత చిత్రాలపై 2 గంటల్లో చర్య తీసుకుంటాం.",
  "24 gantallo acknowledge chestaam, 7 rojullo resolve chestaam. Nudity, pillalaki sambandhinchina sexual content, anumati lekunda share chesina private photos meeda 2 gantallo action teesukuntaam.",
  hi="हम 24 घंटे के अंदर पावती देते हैं और 7 दिनों के अंदर समाधान करते हैं। नग्नता, बच्चों से जुड़े यौन कंटेंट और बिना सहमति शेयर की गई निजी तस्वीरों पर 2 घंटे के अंदर कार्रवाई होती है।",
  hl="Hum 24 ghante ke andar acknowledge karte hain aur 7 din ke andar resolve karte hain. Nudity, bachchon se jude sexual content aur bina consent share ki gayi private photos par 2 ghante ke andar action hota hai.")
s("grievance_offline", "This needs a connection. Your words are still here.",
  "Sending failed with no connection. The form keeps everything.",
  "దీనికి కనెక్షన్ కావాలి. మీరు రాసినది ఇక్కడే ఉంది.", "Deeniki connection kaavali. Meeru raasindi ikkade undi.",
  hi="इसके लिए कनेक्शन चाहिए। आपने जो लिखा है, वह यहीं है।", hl="Iske liye connection chahiye. Aapne jo likha hai, woh yahin hai.")
s("grievance_rateLimited", "A lot of messages came from here in the last hour. Your words are still here; please try again later.",
  "429 from the grievance form (per-client or global hourly limit).",
  "గత గంటలో ఇక్కడి నుండి చాలా మెసేజ్‌లు వచ్చాయి. మీరు రాసినది ఇక్కడే ఉంది; దయచేసి కొంతసేపటి తర్వాత మళ్ళీ ప్రయత్నించండి.",
  "Gata gantalo ikkadi nundi chaala messages vachchaayi. Meeru raasindi ikkade undi; dayachesi konchem sepu tarvaata malli try cheyandi.",
  hi="पिछले एक घंटे में यहाँ से बहुत सारे संदेश आए हैं। आपने जो लिखा है, वह यहीं है; कृपया थोड़ी देर बाद फिर कोशिश करें।",
  hl="Pichhle ek ghante mein yahan se bahut saare messages aaye hain. Aapne jo likha hai, woh yahin hai; please thodi der baad phir try karein.")
s("grievance_checkFields", "Please check the email address and add a little more detail (at least 10 characters).",
  "400 from the grievance form.",
  "దయచేసి ఈమెయిల్ చిరునామాను సరిచూసి, కొంచెం ఎక్కువ వివరాలు రాయండి (కనీసం 10 అక్షరాలు).",
  "Dayachesi email address check chesi, konchem ekkuva details raayandi (kaneesam 10 characters).",
  hi="कृपया ईमेल पता जाँचें और थोड़ा और विवरण लिखें (कम से कम 10 अक्षर)।",
  hl="Please email address check karein aur thoda aur detail likhein (kam se kam 10 characters).")
s("grievance_failed", "That didn't go through. Your words are still here. Try again?",
  "Any other failure of the grievance form.",
  "అది వెళ్ళలేదు. మీరు రాసినది ఇక్కడే ఉంది. మళ్ళీ ప్రయత్నిస్తారా?", "Adi vellaledu. Meeru raasindi ikkade undi. Malli try chestaara?",
  hi="यह नहीं जा पाया। आपने जो लिखा है, वह यहीं है। फिर से कोशिश करें?", hl="Yeh nahi ja paaya. Aapne jo likha hai, woh yahin hai. Phir se try karein?")
s("grievance_noApi", "The form isn't available in this version. You can still write to the Grievance Officer by email.",
  "Shown on a build without an API (the email row in Settings still works).",
  "ఈ వెర్షన్‌లో ఈ ఫారం అందుబాటులో లేదు. గ్రీవెన్స్ ఆఫీసర్‌కు ఈమెయిల్ ద్వారా రాయవచ్చు.",
  "Ee version lo ee form available ledu. Grievance Officer ki email dwara raayochu.",
  hi="इस वर्ज़न में यह फ़ॉर्म उपलब्ध नहीं है। शिकायत अधिकारी को ईमेल से लिखा जा सकता है।",
  hl="Is version mein yeh form available nahi hai. Grievance Officer ko email se likha ja sakta hai.")
s("grievance_sentTitle", "Received",
  "Title after the grievance was filed (this screen is the acknowledgement).",
  "అందింది", "Andindi", hi="मिल गया", hl="Mil gaya")
s("grievance_ticket", "Your ticket: {ticket}",
  "The ticket id (e.g. GRV-7K2M9Q4D), selectable.",
  "మీ టికెట్: {ticket}", "Mee ticket: {ticket}", STR("ticket"), hi="आपका टिकट: {ticket}", hl="Aapka ticket: {ticket}")
s("grievance_sentBody", "We'll reply by {date} at the latest. A copy of this acknowledgement is on its way to {email}.",
  "Under the ticket: the resolve-by date (from the server, by category) and where the emailed copy goes.",
  "{date} లోపు సమాధానం ఇస్తాం. ఈ రసీదు కాపీ {email}కి వస్తుంది.",
  "{date} lopu reply istaam. Ee acknowledgement copy {email} ki vastundi.",
  STR("date", "email"),
  hi="हम {date} तक जवाब देंगे। इस पावती की एक कॉपी {email} पर भेजी जा रही है।",
  hl="Hum {date} tak jawaab denge. Is acknowledgement ki ek copy {email} par bheji ja rahi hai.")
s("grievance_gac", "If you're not satisfied with the reply, you can appeal to the Grievance Appellate Committee at gac.gov.in within 30 days.",
  "The statutory appeal route (IT Rules 2021, Rule 3A) [LEGAL wording to confirm].",
  "మా సమాధానం మీకు సంతృప్తి ఇవ్వకపోతే, 30 రోజుల్లోపు gac.gov.in లో Grievance Appellate Committeeకి అప్పీల్ చేయవచ్చు.",
  "Maa reply meeku satisfaction ivvakapote, 30 rojullopu gac.gov.in lo Grievance Appellate Committee ki appeal cheyochu.",
  hi="अगर जवाब से संतुष्टि न हो, तो 30 दिनों के अंदर gac.gov.in पर Grievance Appellate Committee में अपील की जा सकती है।",
  hl="Agar jawaab se santushti na ho, to 30 din ke andar gac.gov.in par Grievance Appellate Committee mein appeal ki ja sakti hai.")
s("set_grievanceForm", "Write to the Grievance Officer",
  "Settings › Help & Safety row that opens the in-app grievance form.",
  "గ్రీవెన్స్ ఆఫీసర్‌కు రాయండి", "Grievance Officer ki raayandi", hi="शिकायत अधिकारी को लिखें", hl="Grievance Officer ko likhein")
s("set_grievanceFormNote", "In the app, with a ticket number right away",
  "Subtitle of the Settings row that opens the grievance form.",
  "యాప్‌లోనే, వెంటనే టికెట్ నంబర్‌తో", "App lone, ventane ticket number tho",
  hi="ऐप में ही, तुरंत टिकट नंबर के साथ", hl="App mein hi, turant ticket number ke saath")
s("closed_askReviewInApp", "Ask for a review in the app",
  "Row on the closed-account and banned-device screens that opens the grievance form as an appeal.",
  "యాప్‌లోనే మళ్ళీ పరిశీలించమని అడగండి", "App lone review adagandi", hi="ऐप में ही रिव्यू माँगें", hl="App mein hi review maangein")
s("closed_askReviewInAppNote", "You get a ticket number right away.",
  "Subtitle of the in-app review row.",
  "మీకు వెంటనే టికెట్ నంబర్ వస్తుంది.", "Meeku ventane ticket number vastundi.",
  hi="आपको तुरंत एक टिकट नंबर मिलेगा।", hl="Aapko turant ek ticket number milega.")
