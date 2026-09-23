# Sign-in, Settings and account deletion copy (F8 REQ-ACC-11, F9, F3,
# REQ-A11Y-08). Loaded by tool/l10n_source.py.
# s(key, en, desc, te, te_Latn, ph=None) · edit(key, en=, te=, tl=, desc=)
# Telugu / Tenglish: first drafts, NEED NATIVE REVIEW before alpha.

# ---- sign-in (F8) -----------------------------------------------------------
edit("signin_apple", desc="Sign in with Apple. Only shown when social sign-in is enabled for the build.")
edit("signin_google", desc="Sign in with Google. Only shown when social sign-in is enabled for the build.")
s("signin_busy", "One moment", "Screen-reader label of the small progress ring inside a button while sign-in or deletion work runs.", "ఒక్క క్షణం", "Oka kshanam")
s("signin_resendIn", "{seconds, plural, =1{You can ask for a fresh code in 1 s} other{You can ask for a fresh code in {seconds} s}}", "Quiet label on the disabled resend button during its 30-second cooldown. 's' = seconds.", "{seconds, plural, =1{1 సెకనులో కొత్త కోడ్ అడగవచ్చు} other{{seconds} సెకన్లలో కొత్త కోడ్ అడగవచ్చు}}", "{seconds, plural, =1{1 second lo kotta code adagochu} other{{seconds} seconds lo kotta code adagochu}}", INT("seconds"))
s("signin_freshSent", "A fresh code is on its way.", "Shown after the person asked for a fresh sign-in code and it was sent.", "కొత్త కోడ్ వస్తోంది.", "Kotta code vastondi.")

# ---- deletion pending: "Keep my account?" (contracts/api/v1.md) ------------
s("acct_pendingTitle", "Keep your account?", "Title of the choice shown when the signed-in account is scheduled for deletion (7-day grace).", "మీ ఖాతాను ఉంచుకుంటారా?", "Mee account ni unchukuntaara?")
s("acct_pendingBody", "Your account is set to be deleted on {date}. Keep it?", "Deletion is scheduled; {date} is a formatted date. Calm, no pressure.", "మీ ఖాతా {date}న తొలగించబడేలా సెట్ అయి ఉంది. దాన్ని ఉంచుకుంటారా?", "Mee account {date} na delete ayyela set ayyi undi. Daanni unchukuntaara?", STR("date"))
s("acct_pendingBodySoon", "Your account is set to be deleted soon. Keep it?", "Deletion is scheduled but the date isn't known yet (offline).", "మీ ఖాతా త్వరలో తొలగించబడేలా సెట్ అయి ఉంది. దాన్ని ఉంచుకుంటారా?", "Mee account tvaralo delete ayyela set ayyi undi. Daanni unchukuntaara?")
s("acct_keep", "Keep my account", "Cancels the scheduled deletion.", "నా ఖాతాను ఉంచండి", "Naa account ni unchandi")
s("acct_letGo", "Let it go", "Leaves the deletion scheduled and signs out of this phone (clears it).", "వదిలేయండి", "Vadileyandi")
s("acct_keepFailed", "That didn't go through, so nothing has changed yet. Try again when you're connected.", "Cancelling the deletion failed. No blame.", "అది జరగలేదు, కాబట్టి ఇంకా ఏమీ మారలేదు. కనెక్ట్ అయ్యాక మళ్ళీ ప్రయత్నించండి.", "Adi jaragaledu, kabatti inka emi maaraledu. Connect ayyaaka malli try cheyandi.")

# ---- delete account screen (REQ-ACC-11, Apple 5.1.1(v)) --------------------
s("acct_deleteTitle", "Delete my account", "Settings row, screen title and the destructive button. Explicit, not softened.", "నా ఖాతాను తొలగించండి", "Naa account ni delete cheyandi")
s("acct_deleteIntro", "Deleting your account removes:", "Lead-in to the list of what is deleted.", "మీ ఖాతాను తొలగిస్తే ఇవి పోతాయి:", "Mee account delete cheste ivi pothaayi:")
s("acct_itemCheckIns", "Your check-ins and notes", "What is deleted (list item).", "మీ చెక్-ఇన్‌లు, నోట్స్", "Mee check-ins, notes")
s("acct_itemHabits", "Your habits", "What is deleted (list item).", "మీ అలవాట్లు", "Mee habits")
s("acct_itemProgress", "Your Starlight and your Aura's growth", "What is deleted (list item). Starlight and Aura are brand terms.", "మీ Starlight, మీ Aura ఎదుగుదల", "Mee Starlight, mee Aura edugudala")
s("acct_itemAccount", "Your account and the email you sign in with", "What is deleted (list item).", "మీ ఖాతా, మీరు సైన్ ఇన్ చేసే ఈమెయిల్", "Mee account, meeru sign in chese email")
s("acct_grace", "You have 7 days to change your mind. Sign in again before then and everything stays. After that it's deleted for good and can't be brought back.", "The 7-day grace period.", "మనసు మార్చుకోవడానికి మీకు 7 రోజులు ఉన్నాయి. ఆలోపు మళ్ళీ సైన్ ఇన్ చేస్తే అన్నీ అలాగే ఉంటాయి. ఆ తర్వాత అది శాశ్వతంగా తొలగిపోతుంది, తిరిగి తీసుకురాలేం.", "Manasu maarchukovadaaniki meeku 7 rojulu unnaayi. Aalopu malli sign in cheste anni alaage untaayi. Aa tarvaata adi shaashvatanga delete aipotundi, tirigi teesukuraalemu.")
s("acct_store", "If you pay for a subscription through the App Store or Google Play, deleting your account doesn't cancel it. Manage or cancel it in your store's subscription settings.", "Store subscription warning (Apple 5.1.1(v)). Store names stay in English.", "మీరు App Store లేదా Google Play ద్వారా సబ్‌స్క్రిప్షన్ చెల్లిస్తుంటే, ఖాతాను తొలగించినా అది రద్దు కాదు. దాన్ని మీ స్టోర్ సబ్‌స్క్రిప్షన్ సెట్టింగ్‌లలో నిర్వహించండి లేదా రద్దు చేయండి.", "Meeru App Store leda Google Play dwaara subscription pay chestunte, account delete chesina adi cancel avvadu. Daanni mee store subscription settings lo manage cheyandi leda cancel cheyandi.")
s("acct_phone", "This phone will be cleared and signed out straight away.", "What happens on this phone after the request.", "ఈ ఫోన్‌లోని మీ డేటా వెంటనే క్లియర్ అవుతుంది, సైన్ అవుట్ అవుతుంది.", "Ee phone lo mee data ventane clear avutundi, sign out avutundi.")
s("acct_needsConnection", "Deleting your account needs a connection. Connect to the internet, then try again.", "Offline: the delete button is disabled.", "ఖాతాను తొలగించడానికి ఇంటర్నెట్ కనెక్షన్ కావాలి. కనెక్ట్ అయ్యాక మళ్ళీ ప్రయత్నించండి.", "Account delete cheyadaaniki internet connection kaavali. Connect ayyaaka malli try cheyandi.")
s("acct_confirmTitle", "Delete your account?", "Confirmation dialog title.", "మీ ఖాతాను తొలగించాలా?", "Mee account ni delete cheyaalaa?")
s("acct_confirmBody", "Your account and everything in it will be deleted in 7 days. Sign in again before then to keep it. This phone will be cleared now.", "Confirmation dialog body.", "మీ ఖాతా, అందులోని ప్రతిదీ 7 రోజుల్లో తొలగించబడతాయి. దాన్ని ఉంచుకోవాలంటే ఆలోపు మళ్ళీ సైన్ ఇన్ చేయండి. ఈ ఫోన్ ఇప్పుడే క్లియర్ అవుతుంది.", "Mee account, andulo unna pratidi 7 rojullo delete avutaayi. Daanni unchukovaalante aalopu malli sign in cheyandi. Ee phone ippude clear avutundi.")
s("acct_failed", "That didn't go through, and nothing has been deleted. Try again in a moment.", "The deletion request failed. Nothing was wiped.", "అది జరగలేదు, ఏదీ తొలగించబడలేదు. కొద్దిసేపట్లో మళ్ళీ ప్రయత్నించండి.", "Adi jaragaledu, edi delete avvaledu. Koddisepatlo malli try cheyandi.")
s("acct_failedOffline", "We couldn't reach Aura, and nothing has been deleted. Check your connection and try again.", "The deletion request could not reach the server.", "Auraని చేరుకోలేకపోయాం, ఏదీ తొలగించబడలేదు. మీ కనెక్షన్ చూసుకుని మళ్ళీ ప్రయత్నించండి.", "Aura ni reach avvalekapoyaam, edi delete avvaledu. Mee connection choosukuni malli try cheyandi.")
s("acct_retry", "Try again", "Retry after a failed request.", "మళ్ళీ ప్రయత్నించండి", "Malli try cheyandi")
s("acct_scheduledTitle", "Your account is set to be deleted", "Shown after the deletion was scheduled.", "మీ ఖాతా తొలగింపుకు సెట్ అయింది", "Mee account delete ki set ayyindi")
s("acct_scheduledBody", "It will be deleted on {date}. Sign in again before then to keep it.", "{date} is a formatted date.", "అది {date}న తొలగించబడుతుంది. దాన్ని ఉంచుకోవాలంటే ఆలోపు మళ్ళీ సైన్ ఇన్ చేయండి.", "Adi {date} na delete avutundi. Daanni unchukovaalante aalopu malli sign in cheyandi.", STR("date"))
s("acct_phoneCleared", "This phone has been cleared and signed out.", "After the deletion was scheduled and the phone wiped.", "ఈ ఫోన్ క్లియర్ అయింది, సైన్ అవుట్ అయింది.", "Ee phone clear ayyindi, sign out ayyindi.")
s("acct_signedOut", "You're not signed in, so there's no account to delete. What you've saved lives only on this phone.", "Delete screen opened while signed out.", "మీరు సైన్ ఇన్ చేయలేదు, కాబట్టి తొలగించడానికి ఖాతా లేదు. మీరు సేవ్ చేసినవి ఈ ఫోన్‌లో మాత్రమే ఉన్నాయి.", "Meeru sign in cheyaledu, kabatti delete cheyadaaniki account ledu. Meeru save chesinavi ee phone lo maatrame unnaayi.")
s("acct_unavailable", "Account deletion isn't set up in this build.", "Dev builds without an API URL.", "ఈ బిల్డ్‌లో ఖాతా తొలగింపు ఇంకా సెట్ కాలేదు.", "Ee build lo account delete inka set avvaledu.")

# ---- Settings ---------------------------------------------------------------
s("set_comfort", "Comfort", "Settings section: motion, haptics, streak number.", "సౌకర్యం", "Comfort")
s("set_reduceMotion", "Reduce motion", "Switch (REQ-A11Y-08).", "కదలికలు తగ్గించండి", "Motion tagginchandi")
s("set_reduceMotionNote", "Also follows your phone's setting", "Note under Reduce motion; when the phone already reduces motion the switch is on and locked.", "మీ ఫోన్ సెట్టింగ్‌ను కూడా అనుసరిస్తుంది", "Mee phone setting ni kooda follow avutundi")
s("set_haptics", "Haptics", "Switch for gentle vibration feedback.", "వైబ్రేషన్ స్పందన", "Haptics")
s("set_hapticsNote", "Soft taps when you choose something", "Note under Haptics.", "మీరు ఏదైనా ఎంచుకున్నప్పుడు మెల్లని వైబ్రేషన్", "Meeru edaina select chesinappudu mellani vibration")
s("set_hideStreak", "Hide streak number", "Switch (F3): hides the glow-streak day count on Home.", "వరుస సంఖ్యను దాచండి", "Streak number daachandi")
s("set_hideStreakNote", "Your glow still grows. Home just won't count the days.", "Note under Hide streak number. No loss framing.", "మీ వెలుగు పెరుగుతూనే ఉంటుంది. హోమ్‌లో రోజుల లెక్క మాత్రం కనిపించదు.", "Mee glow perugutune untundi. Home lo rojula lekka maatram kanipinchadu.")
s("set_signOutTitle", "Sign out of Aura?", "Title of the sign-out warning when items haven't synced.", "Aura నుండి సైన్ అవుట్ చేయాలా?", "Aura nundi sign out cheyaalaa?")
s("set_helpSafety", "Help & Safety", "Settings section: disclaimer, legal links, Grievance Officer, support.", "సహాయం & భద్రత", "Help & Safety")
s("set_grievanceOfficer", "Grievance Officer", "Row title (F9, IT Rules). Tapping writes an email.", "ఫిర్యాదుల అధికారి", "Grievance Officer")
s("set_grievanceSubject", "Grievance about Aura", "Email subject pre-filled when writing to the Grievance Officer.", "Aura గురించి ఫిర్యాదు", "Aura gurinchi complaint")
s("set_contactSupport", "Contact support", "Row title. Tapping writes an email.", "సపోర్ట్‌ను సంప్రదించండి", "Support ni contact cheyandi")
s("set_supportSubject", "Aura support", "Email subject pre-filled when writing to support.", "Aura సపోర్ట్", "Aura support")
s("set_opensEmail", "Opens your email app", "Screen-reader hint on email rows.", "మీ ఈమెయిల్ యాప్ తెరుచుకుంటుంది", "Mee email app open avutundi")
s("set_emailFailed", "We couldn't open an email app. You can write to {email}.", "No mail app could open a mailto link.", "ఈమెయిల్ యాప్‌ను తెరవలేకపోయాం. మీరు {email}కి రాయవచ్చు.", "Email app open cheyalekapoyaam. Meeru {email} ki raayochu.", STR("email"))
s("acct_inProgress", "This account is already being deleted, so it can't be kept any more. This phone will be cleared and signed out.", "\"Keep my account\" came too late: the 7-day grace is over and deletion has started. Calm, no blame. The only button is Sign out.", "ఈ ఖాతా తొలగింపు ఇప్పటికే మొదలైంది, కాబట్టి దాన్ని ఇక ఉంచలేం. ఈ ఫోన్ క్లియర్ అయి సైన్ అవుట్ అవుతుంది.", "Ee account delete avvadam ippatike modalaindi, kabatti daanni inka unchalemu. Ee phone clear ayyi sign out avutundi.")
