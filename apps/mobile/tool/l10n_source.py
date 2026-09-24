#!/usr/bin/env python3
"""Single source for Aura's UI copy -> lib/l10n/app_*.arb.

    python3 tool/l10n_source.py && flutter gen-l10n

Telugu (te) and Tenglish (te_Latn) copy is a first draft by the dev team:
NEEDS NATIVE REVIEW before alpha (see README "Localization").
Hindi (hi) and Hinglish (hi_Latn) are drafts too (Milestone B): NEED NATIVE
REVIEW before beta (docs/l10n/hindi-review.md). Every key must carry all five
languages: a missing hi / hl stops the build instead of silently showing
English (keep English on purpose by writing it, e.g. hl="Aura Sky").

Rules (PRD Localization): ICU plurals/placeholders only, no concatenation;
no gendered forms (respectful "meeru" / "aap"; Hindi verbs agree with gender,
so use imperatives, nouns and impersonal forms); brand terms stay Latin (Aura,
Starlight). Room/quadrant theme names stay English in Tenglish and Hinglish.
"""
import json
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "lib", "l10n")

# key: (en, description, placeholders | None, te, te_Latn, hi, hi_Latn)
S = {}


def s(key, en, desc, te, tl, ph=None, hi=None, hl=None):
    S[key] = (en, desc, ph, te, tl, hi, hl)


INT = lambda *names: {n: {"type": "int"} for n in names}  # noqa: E731
STR = lambda *names: {n: {"type": "String"} for n in names}  # noqa: E731

# ---- common ---------------------------------------------------------------
s("appTitle", "Aura", "App name (brand, never translated).", "Aura", "Aura", hi="Aura", hl="Aura")
s("common_continue", "Continue", "Primary button to go to the next step. Calm.", "కొనసాగించండి", "Continue cheyandi", hi="आगे बढ़ें", hl="Aage badhein")
s("common_back", "Back", "Back button label.", "వెనక్కి", "Venakki", hi="वापस", hl="Wapas")
s("common_done", "Done", "Finish a flow.", "అయిపోయింది", "Aipoyindi", hi="हो गया", hl="Ho gaya")
s("common_notNow", "Not now", "Gentle dismiss.", "ఇప్పుడు కాదు", "Ippudu kaadu", hi="अभी नहीं", hl="Abhi nahi")
s("common_cancel", "Cancel", "Cancel an action.", "రద్దు చేయండి", "Cancel cheyandi", hi="रद्द करें", hl="Cancel karein")
s("common_close", "Close", "Close a sheet or screen.", "మూసివేయండి", "Close cheyandi", hi="बंद करें", hl="Band karein")
s("common_comingSoon", "Coming soon", "Label on features not built yet. Warm, not a tease.", "త్వరలో వస్తుంది", "Tvaralo vastundi", hi="जल्द आ रहा है", hl="Jald aa raha hai")

# ---- help / crisis (F9) ---------------------------------------------------
s("help_button", "I need help now", "Always-visible help button on Home and other screens. Must feel safe to tap.", "నాకు ఇప్పుడే సహాయం కావాలి", "Naaku ippude help kaavali", hi="मुझे अभी मदद चाहिए", hl="Mujhe abhi madad chahiye")
s("help_title", "Help is here", "Support sheet title when opened from the help button.", "సహాయం ఇక్కడే ఉంది", "Help ikkade undi", hi="मदद यहाँ है", hl="Madad yahan hai")
s("help_subtitle", "You don't have to carry this alone. Reach out now, or take a minute to breathe.", "Support sheet subtitle. Warm, never clinical.", "దీన్ని మీరు ఒంటరిగా మోయాల్సిన అవసరం లేదు. ఇప్పుడే ఎవరినైనా సంప్రదించండి, లేదా ఒక నిమిషం శ్వాస మీద ధ్యాస పెట్టండి.", "Idi meeru okkare moyyalsina avasaram ledu. Ippude evarinaina contact cheyandi, leda oka nimisham breath meeda dhyaasa pettandi.", hi="आपको इसे अकेले नहीं सहना है। अभी किसी से संपर्क करें, या एक मिनट रुककर साँस लें।", hl="Aapko ise akele nahi sehna hai. Abhi kisi se contact karein, ya ek minute ruk kar saans lein.")
s("help_crisisTitle", "It sounds like a lot right now.", "Support sheet title after a note matched the crisis lexicon. Never alarming.", "ఇప్పుడు చాలా భారంగా ఉన్నట్టుంది.", "Ippudu chaala bhaaranga unnattundi.", hi="लगता है अभी बहुत कुछ चल रहा है।", hl="Lagta hai abhi bahut kuch chal raha hai.")
s("help_crisisSubtitle", "You don't have to carry it alone. Your check-in is saved.", "Support sheet subtitle after a crisis-lexicon match.", "దీన్ని మీరు ఒంటరిగా మోయాల్సిన అవసరం లేదు. మీ చెక్-ఇన్ సేవ్ అయింది.", "Idi meeru okkare moyyalsina avasaram ledu. Mee check-in save ayyindi.", hi="आपको इसे अकेले नहीं सहना है। आपका चेक-इन सेव हो गया है।", hl="Aapko ise akele nahi sehna hai. Aapka check-in save ho gaya hai.")
s("help_teleManas", "Tele-MANAS · free, 24×7", "India national mental-health helpline 14416.", "Tele-MANAS · ఉచితం, 24×7", "Tele-MANAS · free, 24×7", hi="Tele-MANAS · मुफ़्त, 24×7", hl="Tele-MANAS · free, 24×7")
s("help_teleManasTollFree", "Tele-MANAS toll-free", "India Tele-MANAS toll-free number 1-800-891-4416.", "Tele-MANAS టోల్-ఫ్రీ", "Tele-MANAS toll-free", hi="Tele-MANAS टोल-फ़्री", hl="Tele-MANAS toll-free")
s("help_emergency112", "Emergency", "India emergency number 112 (the number is shown separately).", "అత్యవసరం", "Emergency", hi="इमरजेंसी", hl="Emergency")
s("help_childline", "Childline · for under-18s", "India Childline 1098, shown to under-18s (number shown separately).", "Childline · 18 ఏళ్ల లోపు వారికి", "Childline · 18 ella lopu vaallaki", hi="Childline · 18 साल से कम उम्र वालों के लिए", hl="Childline · 18 se kam umar walon ke liye")
s("help_us988", "Suicide & Crisis Lifeline · call or text", "US crisis line 988 (number shown separately).", "Suicide & Crisis Lifeline · కాల్ లేదా మెసేజ్", "Suicide & Crisis Lifeline · call leda text", hi="Suicide & Crisis Lifeline · कॉल या टेक्स्ट करें", hl="Suicide & Crisis Lifeline · call ya text karein")
s("help_otherEmergency", "If you're in danger right now, please call your local emergency number.", "Shown in countries without a listed helpline. Never an empty list.", "మీరు ఇప్పుడు ప్రమాదంలో ఉంటే, దయచేసి మీ ప్రాంతంలోని అత్యవసర నంబర్‌కు కాల్ చేయండి.", "Meeru ippudu danger lo unte, dayachesi mee local emergency number ki call cheyandi.", hi="अगर आप अभी खतरे में हैं, तो कृपया अपने इलाके के इमरजेंसी नंबर पर कॉल करें।", hl="Agar aap abhi khatre mein hain, to please apne local emergency number par call karein.")
s("help_callSemantic", "Call {name}, {number}", "Screen-reader label for a tap-to-call helpline row.", "{name}కి కాల్ చేయండి, {number}", "{name} ki call cheyandi, {number}", STR("name", "number"), hi="{name} को कॉल करें, {number}", hl="{name} ko call karein, {number}")
s("help_groundingTitle", "Sixty seconds to land", "Title of the 60-second grounding exercise.", "అరవై సెకన్లు, మెల్లగా", "Sixty seconds, mellaga", hi="ठहरने के लिए साठ सेकंड", hl="Thehrne ke liye sixty seconds")
s("help_groundingBody", "Breathe with the circle. Everything else can wait a minute.", "Grounding exercise intro.", "ఈ వృత్తంతో పాటు శ్వాస తీసుకోండి. మిగతావన్నీ ఒక్క నిమిషం ఆగవచ్చు.", "Ee circle tho paatu breathe cheyandi. Migathavanni oka nimisham aagochu.", hi="घेरे के साथ साँस लें। बाकी सब एक मिनट रुक सकता है।", hl="Circle ke saath saans lein. Baaki sab ek minute ruk sakta hai.")
s("help_groundingStart", "Start", "Start grounding.", "మొదలుపెట్టండి", "Start cheyandi", hi="शुरू करें", hl="Shuru karein")
s("help_groundingPause", "Pause", "Pause grounding.", "ఆపండి", "Aapandi", hi="रोकें", hl="Rokein")
s("help_groundingResume", "Resume", "Resume grounding.", "మళ్ళీ కొనసాగించండి", "Malli continue cheyandi", hi="फिर से शुरू करें", hl="Phir se shuru karein")
s("help_breatheIn", "Breathe in", "Grounding pacer, inhale.", "శ్వాస లోపలికి", "Lopaliki breathe cheyandi", hi="साँस अंदर लें", hl="Saans andar lein")
s("help_breatheOut", "Breathe out", "Grounding pacer, exhale.", "శ్వాస బయటకు", "Bayataki vadalandi", hi="साँस बाहर छोड़ें", hl="Saans bahar chhodein")
s("help_ground1", "Feel your feet on the ground.", "Grounding prompt 1.", "మీ పాదాలు నేలను తాకుతున్నట్టు గమనించండి.", "Mee paadaalu nelani taakutunnattu gamaninchandi.", hi="ज़मीन पर अपने पैरों को महसूस करें।", hl="Zameen par apne pairon ko mehsoos karein.")
s("help_ground2", "Notice five things you can see.", "Grounding prompt 2.", "మీకు కనిపిస్తున్న ఐదు వస్తువులను గమనించండి.", "Meeku kanipistunna aidu vastuvulni gamaninchandi.", hi="आसपास दिखने वाली पाँच चीज़ों पर ध्यान दें।", hl="Aas-paas dikhne wali paanch cheezon par dhyaan dein.")
s("help_ground3", "Notice three sounds around you.", "Grounding prompt 3.", "మీ చుట్టూ వినిపిస్తున్న మూడు శబ్దాలను గమనించండి.", "Mee chuttu vinipistunna moodu sounds gamaninchandi.", hi="आसपास की तीन आवाज़ों पर ध्यान दें।", hl="Aas-paas ki teen awaazon par dhyaan dein.")
s("help_ground4", "Let your shoulders drop.", "Grounding prompt 4.", "భుజాలను వదులుగా వదిలేయండి.", "Bhujaalu loose ga vadileyandi.", hi="अपने कंधों को ढीला छोड़ दें।", hl="Apne kandhon ko dheela chhod dein.")
s("help_ground5", "You're here. That's enough for now.", "Grounding prompt 5.", "మీరు ఇక్కడే ఉన్నారు. ఇప్పటికి అది చాలు.", "Meeru ikkade unnaru. Ippatiki adi chaalu.", hi="आप यहाँ हैं। अभी के लिए इतना काफ़ी है।", hl="Aap yahan hain. Abhi ke liye itna kaafi hai.")
s("help_groundingDone", "Well done. Stay as long as you need.", "Grounding finished.", "బాగా చేశారు. మీకు కావలసినంత సేపు ఇక్కడే ఉండండి.", "Baaga chesaru. Meeku kaavalsinanta sepu ikkade undandi.", hi="बहुत अच्छा। जितनी देर ज़रूरत हो, यहीं रहें।", hl="Bahut accha. Jitni der zaroorat ho, yahin rahein.")
s("help_secondsLeft", "{seconds, plural, =1{1 second left} other{{seconds} seconds left}}", "Grounding countdown (also read by screen readers).", "{seconds, plural, =1{1 సెకను మిగిలింది} other{{seconds} సెకన్లు మిగిలాయి}}", "{seconds, plural, =1{1 second migilindi} other{{seconds} seconds migilaayi}}", INT("seconds"), hi="{seconds, plural, =1{1 सेकंड बाकी} other{{seconds} सेकंड बाकी}}", hl="{seconds, plural, =1{1 second baaki} other{{seconds} seconds baaki}}")
s("help_disclaimer", "Aura is not a medical device or an emergency service.", "Legal disclaimer (Play health policy, Apple 1.4.1).", "Aura వైద్య పరికరం కాదు, అత్యవసర సేవ కూడా కాదు.", "Aura medical device kaadu, emergency service kooda kaadu.", hi="Aura कोई मेडिकल डिवाइस या इमरजेंसी सेवा नहीं है।", hl="Aura koi medical device ya emergency service nahi hai.")
s("help_backToCheckin", "Back to my check-in", "Close the crisis sheet after saving.", "నా చెక్-ఇన్‌కి తిరిగి వెళ్ళండి", "Naa check-in ki tirigi vellandi", hi="मेरे चेक-इन पर वापस", hl="Mere check-in par wapas")

# ---- onboarding (F8) ------------------------------------------------------
s("welcome_title", "Welcome to Aura", "Welcome screen title.", "Auraకి స్వాగతం", "Aura ki swaagatam", hi="Aura में आपका स्वागत है", hl="Aura mein aapka swagat hai")
s("welcome_body", "A quiet place to notice how you feel. Your check-ins stay private, and your Aura grows a little each time you show up.", "Welcome screen body. Calm, inviting.", "మీ మనసు ఎలా ఉందో ప్రశాంతంగా గమనించుకునే చోటు. మీ చెక్-ఇన్‌లు మీకు మాత్రమే, మీరు వచ్చిన ప్రతిసారీ మీ Aura కొంచెం పెరుగుతుంది.", "Mee manasu ela undo prashaanthanga gamaninchukune chotu. Mee check-ins private ga untaayi, meeru vachina prati saari mee Aura konchem perugutundi.", hi="अपने मन का हाल देखने की एक शांत जगह। आपके चेक-इन प्राइवेट रहते हैं, और हर बार आपके आने पर आपका Aura थोड़ा बढ़ता है।", hl="Apne mann ka haal dekhne ki ek shaant jagah. Aapke check-ins private rehte hain, aur har baar aapke aane par aapka Aura thoda badhta hai.")
s("welcome_begin", "Begin", "Welcome CTA.", "మొదలుపెడదాం", "Modalupedadam", hi="शुरू करें", hl="Shuru karein")
s("dob_title", "When's your birthday?", "DOB gate title. Neutral; never mentions 13 or 18.", "మీ పుట్టినరోజు ఎప్పుడు?", "Mee birthday eppudu?", hi="आपका जन्मदिन कब है?", hl="Aapka birthday kab hai?")
s("dob_body", "We ask everyone. It stays private and is never shown to anyone.", "DOB gate body.", "అందరినీ ఇదే అడుగుతాం. ఇది గోప్యంగా ఉంటుంది, ఎవరికీ కనిపించదు.", "Andarini ide adugutaam. Idi private ga untundi, evariki kanipinchadu.", hi="यह हम सबसे पूछते हैं। यह प्राइवेट रहता है और किसी को कभी नहीं दिखाया जाता।", hl="Yeh hum sabse poochhte hain. Yeh private rehta hai aur kisi ko kabhi nahi dikhaya jaata.")
s("dob_day", "Day", "DOB picker: day.", "రోజు", "Roju", hi="दिन", hl="Din")
s("dob_month", "Month", "DOB picker: month.", "నెల", "Nela", hi="महीना", hl="Mahina")
s("dob_year", "Year", "DOB picker: year.", "సంవత్సరం", "Samvatsaram", hi="साल", hl="Saal")
s("dob_invalid", "That date doesn't exist. Could you check it?", "DOB validation (e.g. 30 Feb).", "ఆ తేదీ ఉండదు. ఒకసారి చూసుకుంటారా?", "Aa date undadu. Okasari choosukuntaara?", hi="ऐसी कोई तारीख नहीं होती। एक बार देख लें?", hl="Aisi koi date nahi hoti. Ek baar check kar lein?")
s("dob_future", "That date hasn't happened yet. Could you check it?", "DOB validation (future date).", "ఆ తేదీ ఇంకా రాలేదు. ఒకసారి చూసుకుంటారా?", "Aa date inka raaledu. Okasari choosukuntaara?", hi="यह तारीख अभी आई नहीं है। एक बार देख लें?", hl="Yeh date abhi aayi nahi hai. Ek baar check kar lein?")
s("blocked_title", "Aura is made for people 13 and older.", "Under-13 block screen title. Kind.", "Aura 13 ఏళ్లు, ఆ పైబడిన వారి కోసం.", "Aura 13 ella paiga unna vaalla kosam.", hi="Aura 13 साल और उससे ज़्यादा उम्र के लोगों के लिए बना है।", hl="Aura 13 saal aur usse zyada umar ke logon ke liye bana hai.")
s("blocked_body", "We'd love to see you then.", "Under-13 block screen body.", "అప్పుడు మిమ్మల్ని తప్పకుండా కలుస్తాం.", "Appudu mimmalni tappakunda kalustaam.", hi="तब आपसे मिलकर हमें बहुत खुशी होगी।", hl="Tab aapse milkar humein bahut khushi hogi.")
s("blocked_helpIndia", "If you want to talk to someone now, Childline is free on 1098. In an emergency, call 112.", "Under-13 help line, India.", "ఇప్పుడే ఎవరితోనైనా మాట్లాడాలనిపిస్తే, Childline 1098కి ఉచితంగా కాల్ చేయండి. అత్యవసరమైతే 112కి కాల్ చేయండి.", "Ippude evaritho ainaa maatlaadaalanipiste, Childline 1098 ki free ga call cheyandi. Emergency aite 112 ki call cheyandi.", hi="अगर अभी किसी से बात करने का मन है, तो Childline 1098 पर मुफ़्त है। इमरजेंसी में 112 पर कॉल करें।", hl="Agar abhi kisi se baat karne ka mann hai, to Childline 1098 par free hai. Emergency mein 112 par call karein.")
s("blocked_helpOther", "If you want to talk to someone now, please reach out to an adult you trust.", "Under-13 help line, other countries.", "ఇప్పుడే ఎవరితోనైనా మాట్లాడాలనిపిస్తే, మీరు నమ్మే పెద్దవాళ్ళతో మాట్లాడండి.", "Ippude evaritho ainaa maatlaadaalanipiste, meeru namme peddavaalla tho maatlaadandi.", hi="अगर अभी किसी से बात करने का मन है, तो कृपया किसी ऐसे बड़े से बात करें जिस पर आपको भरोसा हो।", hl="Agar abhi kisi se baat karne ka mann hai, to please kisi aise bade se baat karein jis par aapko bharosa ho.")
s("language_title", "Which language feels like home?", "Language picker title.", "ఏ భాష మీకు సొంతంగా అనిపిస్తుంది?", "Ye bhaasha meeku sontham anipistundi?", hi="कौन-सी भाषा अपनी-सी लगती है?", hl="Kaun si bhasha apni si lagti hai?")
s("language_body", "You can change this any time in Settings.", "Language picker body.", "దీన్ని సెట్టింగ్‌లలో ఎప్పుడైనా మార్చుకోవచ్చు.", "Deenni Settings lo eppudaina maarchukovachu.", hi="इसे सेटिंग्स में कभी भी बदला जा सकता है।", hl="Ise Settings mein kabhi bhi badla ja sakta hai.")
s("language_teLatnHint", "Telugu in English letters", "Explains Tenglish.", "తెలుగు, ఇంగ్లీష్ అక్షరాల్లో", "Telugu, English aksharaallo", hi="अंग्रेज़ी अक्षरों में तेलुगु", hl="Telugu, English letters mein")
s("language_hiLatnHint", "Hindi in English letters", "Explains Hinglish.", "హిందీ, ఇంగ్లీష్ అక్షరాల్లో", "Hindi, English aksharaallo", hi="अंग्रेज़ी अक्षरों में हिंदी", hl="Hindi, English letters mein")
s("language_beta", "Beta", "Badge on beta languages.", "బీటా", "Beta", hi="बीटा", hl="Beta")
s("signin_title", "Keep your Aura safe", "Sign-in title.", "మీ Auraని భద్రంగా ఉంచండి", "Mee Aura ni safe ga unchandi", hi="अपने Aura को सुरक्षित रखें", hl="Apne Aura ko safe rakhein")
s("signin_body", "Sign in with your email so your Aura can follow you to a new phone. No name, no phone number, no password.", "Sign-in body. Reassuring about privacy.", "మీ ఈమెయిల్‌తో సైన్ ఇన్ చేయండి, అప్పుడు కొత్త ఫోన్‌లో కూడా మీ Aura మీతోనే ఉంటుంది. పేరు, ఫోన్ నంబర్, పాస్‌వర్డ్ ఏవీ అక్కర్లేదు.", "Mee email tho sign in cheyandi, appudu kotta phone lo kooda mee Aura meetho untundi. Peru, phone number, password edee akkarledu.", hi="अपने ईमेल से साइन इन करें, ताकि नए फ़ोन में भी आपका Aura आपके साथ रहे। न नाम, न फ़ोन नंबर, न पासवर्ड।", hl="Apne email se sign in karein, taaki naye phone mein bhi aapka Aura aapke saath rahe. Na naam, na phone number, na password.")
s("signin_emailLabel", "Email", "Email field label.", "ఈమెయిల్", "Email", hi="ईमेल", hl="Email")
s("signin_sendCode", "Email me a code", "Send OTP button.", "నాకు కోడ్ పంపండి", "Naaku code pampandi", hi="मुझे ईमेल पर कोड भेजें", hl="Mujhe email par code bhejein")
s("signin_codeSent", "We sent a 6-digit code to {email}. You can also tap the link in that email.", "After sending the OTP.", "{email}కి 6 అంకెల కోడ్ పంపాం. ఆ ఈమెయిల్‌లోని లింక్‌ను కూడా నొక్కవచ్చు.", "{email} ki 6-digit code pampaam. Aa email lo unna link ni kooda tap cheyochu.", STR("email"), hi="हमने {email} पर 6 अंकों का कोड भेजा है। चाहें तो उस ईमेल के लिंक पर भी टैप करें।", hl="Humne {email} par 6-digit code bheja hai. Chahein to us email ke link par bhi tap karein.")
s("signin_codeLabel", "6-digit code", "OTP field label.", "6 అంకెల కోడ్", "6-digit code", hi="6 अंकों का कोड", hl="6-digit code")
s("signin_verify", "Continue", "Verify OTP button.", "కొనసాగించండి", "Continue cheyandi", hi="आगे बढ़ें", hl="Aage badhein")
s("signin_resend", "Send a fresh code", "Resend OTP.", "కొత్త కోడ్ పంపండి", "Kotta code pampandi", hi="नया कोड भेजें", hl="Naya code bhejein")
s("signin_changeEmail", "Use a different email", "Go back to the email step.", "వేరే ఈమెయిల్ వాడండి", "Vere email vaadandi", hi="दूसरा ईमेल इस्तेमाल करें", hl="Doosra email use karein")
s("signin_error", "That didn't go through. Try again, or sign in another way.", "Sign-in failed. No blame, no exclamation.", "అది జరగలేదు. మళ్ళీ ప్రయత్నించండి, లేదా వేరే విధంగా సైన్ ఇన్ చేయండి.", "Adi jaragaledu. Malli try cheyandi, leda vere vidhamga sign in cheyandi.", hi="यह हो नहीं पाया। फिर से कोशिश करें, या किसी और तरीके से साइन इन करें।", hl="Yeh ho nahi paaya. Phir se try karein, ya kisi aur tareeke se sign in karein.")
s("signin_codeExpired", "This code has timed out. We'll send a fresh one.", "OTP expired.", "ఈ కోడ్ గడువు ముగిసింది. కొత్తది పంపుతాం.", "Ee code time aipoyindi. Kottadi pamputaam.", hi="इस कोड का समय खत्म हो गया है। हम नया कोड भेज देंगे।", hl="Is code ka time khatam ho gaya hai. Hum naya code bhej denge.")
s("signin_invalidCode", "That code doesn't match. Could you check it?", "Wrong OTP.", "ఆ కోడ్ సరిపోలలేదు. ఒకసారి చూసుకుంటారా?", "Aa code match avvaledu. Okasari choosukuntaara?", hi="यह कोड मेल नहीं खा रहा। एक बार देख लें?", hl="Yeh code match nahi ho raha. Ek baar check kar lein?")
s("signin_invalidEmail", "That email doesn't look quite right.", "Invalid email.", "ఆ ఈమెయిల్ సరిగ్గా ఉన్నట్టు లేదు.", "Aa email correct ga unnattu ledu.", hi="यह ईमेल कुछ ठीक नहीं लग रहा।", hl="Yeh email kuch sahi nahi lag raha.")
s("signin_apple", "Continue with Apple", "Sign in with Apple (disabled until enabled by flag).", "Appleతో కొనసాగించండి", "Apple tho continue cheyandi", hi="Apple के साथ जारी रखें", hl="Apple ke saath continue karein")
s("signin_google", "Continue with Google", "Sign in with Google (disabled until enabled by flag).", "Googleతో కొనసాగించండి", "Google tho continue cheyandi", hi="Google के साथ जारी रखें", hl="Google ke saath continue karein")
s("signin_offline", "You're offline. Pick your first mood now. We'll finish setting up when you're connected.", "Offline at first launch (PRD States).", "మీరు ఆఫ్‌లైన్‌లో ఉన్నారు. ముందు మీ మొదటి మూడ్ ఎంచుకోండి. కనెక్ట్ అయ్యాక మిగతా సెటప్ పూర్తి చేస్తాం.", "Meeru offline lo unnaru. Mundu mee first mood select cheyandi. Connect ayyaaka migataa setup complete chestaam.", hi="आप ऑफ़लाइन हैं। अभी अपना पहला मूड चुनें। कनेक्ट होने पर हम सेटअप पूरा कर देंगे।", hl="Aap offline hain. Abhi apna pehla mood chunein. Connect hone par hum setup poora kar denge.")
s("signin_offlineContinue", "Check in now", "Continue offline to the first check-in.", "ఇప్పుడే చెక్-ఇన్ చేయండి", "Ippude check-in cheyandi", hi="अभी चेक-इन करें", hl="Abhi check-in karein")
s("signin_unavailable", "Sign-in isn't set up in this build yet. Your check-ins will stay on this phone for now.", "Dev builds without Supabase config.", "ఈ బిల్డ్‌లో సైన్-ఇన్ ఇంకా సెట్ కాలేదు. ప్రస్తుతానికి మీ చెక్-ఇన్‌లు ఈ ఫోన్‌లోనే ఉంటాయి.", "Ee build lo sign-in inka set avvaledu. Prastutaaniki mee check-ins ee phone lone untaayi.", hi="इस बिल्ड में साइन-इन अभी सेट नहीं हुआ है। फ़िलहाल आपके चेक-इन इसी फ़ोन पर रहेंगे।", hl="Is build mein sign-in abhi set nahi hua hai. Filhaal aapke check-ins isi phone par rahenge.")
s("signin_continueLocal", "Continue on this phone", "Skip sign-in when unavailable.", "ఈ ఫోన్‌లోనే కొనసాగించండి", "Ee phone lone continue cheyandi", hi="इसी फ़ोन पर आगे बढ़ें", hl="Isi phone par aage badhein")

# ---- check-in (F1) --------------------------------------------------------
s("checkin_title", "How are you feeling?", "Check-in screen title.", "మీకు ఇప్పుడు ఎలా అనిపిస్తోంది?", "Meeku ippudu ela anipistondi?", hi="अभी कैसा लग रहा है?", hl="Abhi kaisa lag raha hai?")
s("checkin_subtitle", "Pick the closest one. There's no wrong answer.", "Check-in subtitle.", "దగ్గరగా ఉన్నదాన్ని ఎంచుకోండి. తప్పు సమాధానం అంటూ ఏదీ లేదు.", "Daggaraga unnadi select cheyandi. Tappu answer antu edi ledu.", hi="जो सबसे करीब लगे, उसे चुनें। कोई जवाब गलत नहीं है।", hl="Jo sabse kareeb lage, use chunein. Koi jawaab galat nahi hai.")
s("checkin_moreEnergy", "More energy", "Grid axis label (top).", "ఎక్కువ శక్తి", "Ekkuva energy", hi="ज़्यादा एनर्जी", hl="Zyada energy")
s("checkin_lessEnergy", "Less energy", "Grid axis label (bottom).", "తక్కువ శక్తి", "Takkuva energy", hi="कम एनर्जी", hl="Kam energy")
s("checkin_pleasant", "Pleasant", "Grid axis label (right).", "హాయిగా", "Haayiga", hi="सुखद", hl="Pleasant")
s("checkin_unpleasant", "Unpleasant", "Grid axis label (left).", "ఇబ్బందిగా", "Ibbandiga", hi="असहज", hl="Unpleasant")
s("quadrant_storm", "Storm", "High energy, unpleasant quadrant. Never 'bad'.", "తుఫాను", "Storm", hi="तूफ़ान", hl="Storm")
s("quadrant_rain", "Rain", "Low energy, unpleasant quadrant.", "వాన", "Rain", hi="बारिश", hl="Rain")
s("quadrant_moonlight", "Moonlight", "Low energy, pleasant quadrant.", "వెన్నెల", "Moonlight", hi="चाँदनी", hl="Moonlight")
s("quadrant_sunrise", "Sunrise", "High energy, pleasant quadrant.", "సూర్యోదయం", "Sunrise", hi="सूर्योदय", hl="Sunrise")
s("mood_semantic", "{mood}, {quadrant} group, {energy}, {feel}", "Screen-reader label for a mood tile (REQ-A11Y-04).", "{mood}, {quadrant} గుంపు, {energy}, {feel}", "{mood}, {quadrant} group, {energy}, {feel}", STR("mood", "quadrant", "energy", "feel"), hi="{mood}, {quadrant} समूह, {energy}, {feel}", hl="{mood}, {quadrant} group, {energy}, {feel}")
s("semantic_highEnergy", "high energy", "Screen-reader part.", "ఎక్కువ శక్తి", "ekkuva energy", hi="ज़्यादा एनर्जी", hl="zyada energy")
s("semantic_lowEnergy", "low energy", "Screen-reader part.", "తక్కువ శక్తి", "takkuva energy", hi="कम एनर्जी", hl="kam energy")
s("semantic_pleasant", "pleasant", "Screen-reader part.", "హాయిగా", "haayiga", hi="सुखद", hl="pleasant")
s("semantic_unpleasant", "unpleasant", "Screen-reader part.", "ఇబ్బందిగా", "ibbandiga", hi="असहज", hl="unpleasant")
s("checkin_addDetails", "Add a tag or a few words", "Optional details toggle.", "ఒక ట్యాగ్ లేదా కొన్ని మాటలు జోడించండి", "Oka tag leda konni maatalu add cheyandi", hi="कोई टैग या कुछ शब्द जोड़ें", hl="Koi tag ya kuch shabd jodein")
s("checkin_tagsTitle", "What's it about?", "Tags section title.", "దేని గురించి?", "Deeni gurinchi?", hi="यह किस बारे में है?", hl="Yeh kis baare mein hai?")
for key, en, te, tl, hi, hl in [
    ("study", "Study", "చదువు", "Chaduvu", "पढ़ाई", "Padhai"),
    ("work", "Work", "పని", "Pani", "काम", "Kaam"),
    ("family", "Family", "కుటుంబం", "Family", "परिवार", "Family"),
    ("friends", "Friends", "స్నేహితులు", "Friends", "दोस्त", "Dost"),
    ("sleep", "Sleep", "నిద్ర", "Nidra", "नींद", "Neend"),
    ("health", "Health", "ఆరోగ్యం", "Health", "सेहत", "Health"),
    ("money", "Money", "డబ్బు", "Dabbu", "पैसे", "Paisa"),
    ("love", "Love", "ప్రేమ", "Prema", "प्यार", "Pyaar"),
    ("alone", "Alone", "ఒంటరితనం", "Ontaritanam", "अकेले", "Akele"),
    ("commute", "Commute", "ప్రయాణం", "Prayaanam", "आना-जाना", "Aana-jaana"),
]:
    s(f"tag_{key}", en, f"Context tag '{key}'.", te, tl, hi=hi, hl=hl)
s("checkin_customTag", "Your own tag", "Custom tag field.", "మీ సొంత ట్యాగ్", "Mee sontha tag", hi="अपना टैग", hl="Apna tag")
s("checkin_customTagAdd", "Add tag", "Add custom tag button.", "ట్యాగ్ జోడించండి", "Tag add cheyandi", hi="टैग जोड़ें", hl="Tag jodein")
s("checkin_noteLabel", "A few words, if you like", "Note field label.", "కావాలంటే, కొన్ని మాటలు", "Kaavaalante, konni maatalu", hi="चाहें तो कुछ शब्द", hl="Chahein to kuch shabd")
s("checkin_noteHint", "Only you can read this.", "Note privacy hint.", "ఇది మీరు మాత్రమే చదవగలరు.", "Idi meeru maatrame chadavagalaru.", hi="यह सिर्फ़ आपको दिखेगा।", hl="Yeh sirf aapko dikhega.")
s("checkin_save", "Save", "Save check-in (tap 2).", "సేవ్ చేయండి", "Save cheyandi", hi="सेव करें", hl="Save karein")
s("checkin_saveFailed", "We couldn't save that. Your phone may be low on space.", "Local write failed. Selection is kept.", "దాన్ని సేవ్ చేయలేకపోయాం. మీ ఫోన్‌లో స్థలం తక్కువగా ఉండొచ్చు.", "Daanni save cheyalekapoyaam. Mee phone lo space takkuva undochu.", hi="यह सेव नहीं हो पाया। शायद आपके फ़ोन में जगह कम है।", hl="Yeh save nahi ho paaya. Shayad aapke phone mein jagah kam hai.")
s("checkin_savedStarlight", "+{amount} Starlight", "Reward moment after saving.", "+{amount} Starlight", "+{amount} Starlight", INT("amount"), hi="+{amount} Starlight", hl="+{amount} Starlight")
s("checkin_saved", "Saved", "Saved confirmation.", "సేవ్ అయింది", "Save ayyindi", hi="सेव हो गया", hl="Save ho gaya")
s("checkin_savedOffline", "Saved on this phone", "Saved while offline / before sync.", "ఈ ఫోన్‌లో సేవ్ అయింది", "Ee phone lo save ayyindi", hi="इस फ़ोन पर सेव हो गया", hl="Is phone par save ho gaya")
s("checkin_savedThanks", "Thank you for checking in.", "After saving.", "చెక్-ఇన్ చేసినందుకు ధన్యవాదాలు.", "Check-in chesinanduku thanks.", hi="चेक-इन करने के लिए शुक्रिया।", hl="Check-in karne ke liye shukriya.")
s("checkin_savedFull", "You've gathered all of today's Starlight. Your check-in still counts.", "When the day's Starlight is already capped.", "ఈరోజు Starlight అంతా సేకరించేశారు. మీ చెక్-ఇన్ ఇప్పటికీ లెక్కలోకి వస్తుంది.", "Ee roju Starlight antaa sekarinchesaaru. Mee check-in ippatiki count avutundi.", hi="आज की सारी Starlight मिल चुकी है। आपका चेक-इन फिर भी गिना जाता है।", hl="Aaj ki saari Starlight mil chuki hai. Aapka check-in phir bhi count hota hai.")
s("checkin_roomButton", "Join a room of people feeling this", "Room prompt after saving (F5, coming soon).", "ఇలాగే అనిపిస్తున్నవాళ్ళ గదిలో చేరండి", "Ilaane anipistunna vaalla room lo cherandi", hi="ऐसा ही महसूस करने वालों के रूम में जुड़ें", hl="Aisa hi mehsoos karne walon ke room mein judein")

# ---- home -------------------------------------------------------------------
s("home_checkIn", "Check in", "Primary Home button.", "చెక్-ఇన్ చేయండి", "Check in cheyandi", hi="चेक-इन करें", hl="Check-in karein")
s("home_todayStarlight", "{count} Starlight today", "Today's Starlight.", "ఈరోజు {count} Starlight", "Ee roju {count} Starlight", INT("count"), hi="आज {count} Starlight", hl="Aaj {count} Starlight")
s("home_totalStarlight", "{count} in all", "All-time Starlight.", "మొత్తం {count}", "Mottham {count}", INT("count"), hi="कुल {count}", hl="Kul {count}")
s("home_empty", "This is your Aura. Check in to give it light.", "New user empty state.", "ఇది మీ Aura. చెక్-ఇన్ చేసి దానికి వెలుగు ఇవ్వండి.", "Idi mee Aura. Check in chesi daaniki velugu ivvandi.", hi="यह आपका Aura है। इसे रोशनी देने के लिए चेक-इन करें।", hl="Yeh aapka Aura hai. Ise roshni dene ke liye check-in karein.")
s("home_resting", "Your Aura has been resting. Say hi when you're ready.", "Resting Nebula copy. No guilt.", "మీ Aura కొంచెం విశ్రాంతి తీసుకుంటోంది. మీకు వీలైనప్పుడు ఒక్క హాయ్ చెప్పండి.", "Mee Aura konchem rest teesukuntondi. Meeku veelainappudu oka hi cheppandi.", hi="आपका Aura कुछ समय से आराम कर रहा है। जब मन हो, हाय कहें।", hl="Aapka Aura kuch time se aaram kar raha hai. Jab mann ho, hi keh dein.")
s("home_glowStreak", "{count, plural, =1{Glow streak · 1 day} other{Glow streak · {count} days}}", "Current glow streak.", "{count, plural, =1{వెలుగు వరుస · 1 రోజు} other{వెలుగు వరుస · {count} రోజులు}}", "{count, plural, =1{Glow streak · 1 roju} other{Glow streak · {count} rojulu}}", INT("count"), hi="{count, plural, =1{चमक का सिलसिला · 1 दिन} other{चमक का सिलसिला · {count} दिन}}", hl="{count, plural, =1{Glow streak · 1 din} other{Glow streak · {count} din}}")
s("home_restDays", "{count, plural, =0{No rest days saved yet} =1{1 rest day saved} other{{count} rest days saved}}", "Rest-day bank.", "{count, plural, =0{ఇంకా విశ్రాంతి రోజులు లేవు} =1{1 విశ్రాంతి రోజు దాచి ఉంది} other{{count} విశ్రాంతి రోజులు దాచి ఉన్నాయి}}", "{count, plural, =0{Inka rest days levu} =1{1 rest day daachi undi} other{{count} rest days daachi unnaayi}}", INT("count"), hi="{count, plural, =0{अभी कोई आराम का दिन जमा नहीं है} =1{1 आराम का दिन जमा है} other{{count} आराम के दिन जमा हैं}}", hl="{count, plural, =0{Abhi koi rest day jama nahi hai} =1{1 rest day jama hai} other{{count} rest days jama hain}}")
s("home_restingSafe", "Resting · your glow is safe", "Gap covered by rest days (F3). Never a countdown.", "విశ్రాంతి · మీ వెలుగు భద్రంగా ఉంది", "Rest · mee glow safe ga undi", hi="आराम · आपकी चमक सुरक्षित है", hl="Aaram · aapka glow safe hai")
s("home_glowCarriesOn", "Your glow carries on", "Shown once when a new streak starts. No loss words.", "మీ వెలుగు కొనసాగుతుంది", "Mee glow continue avutundi", hi="आपकी चमक जारी है", hl="Aapka glow jaari hai")
s("home_lifetimeGlow", "{count, plural, =1{1 glow day in all} other{{count} glow days in all}}", "Lifetime glow days.", "{count, plural, =1{మొత్తం 1 వెలుగు రోజు} other{మొత్తం {count} వెలుగు రోజులు}}", "{count, plural, =1{Mottham 1 glow day} other{Mottham {count} glow days}}", INT("count"), hi="{count, plural, =1{कुल 1 चमक वाला दिन} other{कुल {count} चमक वाले दिन}}", hl="{count, plural, =1{Kul 1 glow day} other{Kul {count} glow days}}")
s("home_habitsTitle", "Small things today", "Habits section title.", "ఈరోజు చిన్న చిన్న పనులు", "Ee roju chinna chinna panulu", hi="आज की छोटी-छोटी चीज़ें", hl="Aaj ki chhoti-chhoti cheezein")
s("home_habitDone", "{habit}, done today", "Screen-reader label, habit done.", "{habit}, ఈరోజు అయింది", "{habit}, ee roju ayyindi", STR("habit"), hi="{habit}, आज हो गया", hl="{habit}, aaj ho gaya")
s("home_habitNotYet", "{habit}, not yet today", "Screen-reader label, habit not done (no 'missed').", "{habit}, ఈరోజు ఇంకా లేదు", "{habit}, ee roju inka ledu", STR("habit"), hi="{habit}, आज अभी नहीं", hl="{habit}, aaj abhi nahi")
s("home_offline", "You're offline. Your own things still save here.", "Offline banner.", "మీరు ఆఫ్‌లైన్‌లో ఉన్నారు. మీ విషయాలు ఇక్కడ సేవ్ అవుతూనే ఉంటాయి.", "Meeru offline lo unnaru. Mee vishayaalu ikkada save avtune untaayi.", hi="आप ऑफ़लाइन हैं। आपकी अपनी चीज़ें फिर भी यहाँ सेव होती रहेंगी।", hl="Aap offline hain. Aapki apni cheezein phir bhi yahan save hoti rahengi.")
s("home_finishSetup", "Finish setting up so your Aura is kept safe.", "Signed-out banner.", "మీ Aura భద్రంగా ఉండటానికి సెటప్ పూర్తి చేయండి.", "Mee Aura safe ga undadaaniki setup complete cheyandi.", hi="सेटअप पूरा करें, ताकि आपका Aura सुरक्षित रहे।", hl="Setup poora karein, taaki aapka Aura safe rahe.")
s("home_signIn", "Sign in", "Sign-in button.", "సైన్ ఇన్", "Sign in", hi="साइन इन करें", hl="Sign in karein")
s("home_syncIdle", "All saved", "Sync indicator: synced.", "అన్నీ సేవ్ అయ్యాయి", "Anni save ayyaayi", hi="सब सेव हो गया", hl="Sab save ho gaya")
s("home_syncPending", "{count, plural, =1{1 thing waiting to sync} other{{count} things waiting to sync}}", "Sync indicator: pending.", "{count, plural, =1{1 సింక్ కోసం వేచి ఉంది} other{{count} సింక్ కోసం వేచి ఉన్నాయి}}", "{count, plural, =1{1 sync kosam wait chestondi} other{{count} sync kosam wait chestunnaayi}}", INT("count"), hi="{count, plural, =1{1 चीज़ सिंक होनी बाकी है} other{{count} चीज़ें सिंक होनी बाकी हैं}}", hl="{count, plural, =1{1 cheez sync honi baaki hai} other{{count} cheezein sync honi baaki hain}}")
s("home_syncLocal", "Saved on this phone", "Sync indicator: local only.", "ఈ ఫోన్‌లో సేవ్ అయింది", "Ee phone lo save ayyindi", hi="इस फ़ोन पर सेव हो गया", hl="Is phone par save ho gaya")
s("home_settings", "Settings", "Settings button.", "సెట్టింగ్‌లు", "Settings", hi="सेटिंग्स", hl="Settings")
s("home_welcomeBack", "Welcome back. One small thing today is plenty.", "Wake-up moment micro-goal. Never a list of what was missed.", "మళ్ళీ స్వాగతం. ఈరోజు ఒక్క చిన్న పని చాలు.", "Malli swaagatam. Ee roju oka chinna pani chaalu.", hi="फिर से स्वागत है। आज एक छोटी-सी चीज़ ही काफ़ी है।", hl="Phir se swagat hai. Aaj ek chhoti si cheez hi kaafi hai.")
s("home_evolved", "Your Aura grew into {stage}.", "Evolution moment.", "మీ Aura {stage}గా ఎదిగింది.", "Mee Aura {stage} ga edigindi.", STR("stage"), hi="आपका Aura बढ़कर {stage} बन गया।", hl="Aapka Aura badhkar {stage} ban gaya.")

for key, en, te, hi, hl in [
    ("spark", "Spark", "రవ్వ", "चिंगारी", "Spark"),
    ("ember", "Ember", "నిప్పు కణిక", "अंगारा", "Ember"),
    ("glow", "Glow", "వెలుగు", "चमक", "Glow"),
    ("radiance", "Radiance", "తేజస్సు", "आभा", "Radiance"),
    ("constellation", "Constellation", "నక్షత్ర మండలం", "तारामंडल", "Constellation"),
]:
    s(f"stage_{key}", en, f"Avatar stage '{key}'.", te, en, hi=hi, hl=hl)

for key, en, te, tl, hi, hl in [
    ("hydrate", "Hydrate", "నీళ్ళు", "Neellu", "पानी पीना", "Paani peena"),
    ("sleep_on_time", "Sleep on time", "సమయానికి నిద్ర", "Time ki nidra", "समय पर सोना", "Time par sona"),
    ("move", "Move", "కదలిక", "Kadalika", "चलना-फिरना", "Chalna-phirna"),
    ("breathe", "Breathe", "శ్వాస", "Breathe", "साँस लेना", "Saans lena"),
    ("journal", "Journal", "డైరీ", "Journal", "डायरी लिखना", "Diary likhna"),
    ("go_outside", "Go outside", "బయటికి", "Bayataki", "बाहर जाना", "Bahar jaana"),
]:
    s(f"habit_{key}", en, f"Preset habit '{key}'.", te, tl, hi=hi, hl=hl)

# ---- avatar semantics (REQ-A11Y-05) --------------------------------------
s("avatar_semantic", "Your Aura, {stage} stage, {hue} glow", "Avatar description for screen readers.", "మీ Aura, {stage} దశ, {hue} వెలుగు", "Mee Aura, {stage} stage, {hue} glow", STR("stage", "hue"), hi="आपका Aura, {stage} स्टेज, चमक का रंग {hue}", hl="Aapka Aura, {stage} stage, {hue} glow")
s("avatar_semanticResting", "resting in a soft nebula", "Appended when resting.", "మెత్తని నెబ్యులాలో విశ్రాంతి తీసుకుంటోంది", "mettani nebula lo rest teesukuntondi", hi="नरम नेबुला में आराम करता हुआ", hl="naram nebula mein aaram karta hua")
s("avatar_semanticRings", "{count, plural, =1{one orbiting light} other{{count} orbiting lights}}", "Rings trait for screen readers.", "{count, plural, =1{చుట్టూ తిరిగే ఒక వెలుగు} other{చుట్టూ తిరిగే {count} వెలుగులు}}", "{count, plural, =1{chuttu tirige oka velugu} other{chuttu tirige {count} velugulu}}", INT("count"), hi="{count, plural, =1{चारों ओर घूमती एक रोशनी} other{चारों ओर घूमती {count} रोशनियाँ}}", hl="{count, plural, =1{chaaron taraf ghoomti ek roshni} other{chaaron taraf ghoomti {count} roshniyan}}")
s("avatar_semanticStars", "{count, plural, =1{one star in its constellation} other{{count} stars in its constellation}}", "Constellation stars for screen readers.", "{count, plural, =1{నక్షత్ర మండలంలో ఒక నక్షత్రం} other{నక్షత్ర మండలంలో {count} నక్షత్రాలు}}", "{count, plural, =1{constellation lo oka star} other{constellation lo {count} stars}}", INT("count"), hi="{count, plural, =1{इसके तारामंडल में एक तारा} other{इसके तारामंडल में {count} तारे}}", hl="{count, plural, =1{iske constellation mein ek taara} other{iske constellation mein {count} taare}}")
for key, en, te, tl, hi, hl in [
    ("gold", "golden", "బంగారు", "bangaaru", "सुनहरा", "sunehra"),
    ("green", "green", "ఆకుపచ్చ", "aakupacha", "हरा", "hara"),
    ("teal", "teal", "నీలి-ఆకుపచ్చ", "teal", "टील", "teal"),
    ("silverBlue", "silver-blue", "వెండి-నీలి", "silver-blue", "सिल्वर-नीला", "silver-blue"),
    ("violet", "violet", "ఊదా", "violet", "बैंगनी", "baingani"),
    ("rose", "rose", "గులాబీ", "gulaabi", "गुलाबी", "gulaabi"),
]:
    s(f"hue_{key}", en, f"Avatar hue name '{key}'.", te, tl, hi=hi, hl=hl)

# ---- settings ---------------------------------------------------------------
s("settings_title", "Settings", "Settings title.", "సెట్టింగ్‌లు", "Settings", hi="सेटिंग्स", hl="Settings")
s("settings_language", "Language", "Language row.", "భాష", "Bhaasha", hi="भाषा", hl="Bhasha")
s("settings_account", "Account", "Account section.", "ఖాతా", "Account", hi="अकाउंट", hl="Account")
s("settings_signedInAs", "Signed in as {email}", "Account row.", "{email}తో సైన్ ఇన్ అయ్యారు", "{email} tho sign in ayyaru", STR("email"), hi="{email} से साइन इन है", hl="{email} se sign in hai")
s("settings_signOut", "Sign out", "Sign out.", "సైన్ అవుట్", "Sign out", hi="साइन आउट करें", hl="Sign out karein")
s("settings_signOutPending", "{count, plural, =1{1 thing hasn't synced yet. Stay signed in until it does?} other{{count} things haven't synced yet. Stay signed in until they do?}}", "Unsynced warning on sign-out.", "{count, plural, =1{1 విషయం ఇంకా సింక్ కాలేదు. అది అయ్యే వరకు సైన్ ఇన్‌లోనే ఉంటారా?} other{{count} విషయాలు ఇంకా సింక్ కాలేదు. అవి అయ్యే వరకు సైన్ ఇన్‌లోనే ఉంటారా?}}", "{count, plural, =1{1 vishayam inka sync avvaledu. Adi ayye varaku sign in lone untaara?} other{{count} vishayaalu inka sync avvaledu. Avi ayye varaku sign in lone untaara?}}", INT("count"), hi="{count, plural, =1{1 चीज़ अभी सिंक नहीं हुई है। उसके सिंक होने तक साइन इन रहें?} other{{count} चीज़ें अभी सिंक नहीं हुई हैं। उनके सिंक होने तक साइन इन रहें?}}", hl="{count, plural, =1{1 cheez abhi sync nahi hui hai. Uske sync hone tak sign in rahein?} other{{count} cheezein abhi sync nahi hui hain. Unke sync hone tak sign in rahein?}}")
s("settings_stay", "Stay signed in", "Keep session.", "సైన్ ఇన్‌లోనే ఉంటాను", "Sign in lone untaanu", hi="साइन इन रहें", hl="Sign in rahein")
s("settings_signOutAnyway", "Sign out anyway", "Confirm sign out.", "అయినా సైన్ అవుట్ చేయండి", "Ayinaa sign out cheyandi", hi="फिर भी साइन आउट करें", hl="Phir bhi sign out karein")
s("settings_signIn", "Sign in to keep your Aura safe", "Signed-out row.", "మీ Auraని భద్రంగా ఉంచడానికి సైన్ ఇన్ చేయండి", "Mee Aura ni safe ga unchadaaniki sign in cheyandi", hi="अपना Aura सुरक्षित रखने के लिए साइन इन करें", hl="Apna Aura safe rakhne ke liye sign in karein")
s("settings_avatarLab", "Avatar lab", "Debug-only entry.", "Avatar lab", "Avatar lab", hi="अवतार लैब", hl="Avatar lab")
s("settings_about", "About", "About section.", "గురించి", "Gurinchi", hi="बारे में", hl="About")
s("settings_version", "Version {version}", "App version.", "వెర్షన్ {version}", "Version {version}", STR("version"), hi="वर्ज़न {version}", hl="Version {version}")


# ---- notifications soft ask (PRD 15-permissions: after the first check-in) --
# Shown before the OS prompt. "Not now" (common_notNow) never fires it.
s("push_title", "Want a gentle nudge each evening?", "Pre-permission explainer title, shown once after the first check-in. PRD copy. Warm, no pressure.", "ప్రతి సాయంత్రం ఒక మృదువైన గుర్తు కావాలా?", "Prati saayantram oka gentle nudge kaavaalaa?", hi="हर शाम एक हल्का-सा रिमाइंडर चाहिए?", hl="Har shaam ek halka sa reminder chahiye?")
s("push_body", "One a day at most, and never about streaks. Nothing on your lock screen will say how you feel.", "Pre-permission explainer body. Must promise: at most one a day, never streaks, never a mood on the lock screen.", "రోజుకు ఒక్కటి మాత్రమే, streaks గురించి ఎప్పుడూ కాదు. మీరు ఎలా ఫీల్ అవుతున్నారో మీ లాక్ స్క్రీన్ ఎప్పుడూ చెప్పదు.", "Rojuki okkate, streaks gurinchi eppudu kaadu. Meeru ela feel avutunnaro mee lock screen eppudu cheppadu.", hi="दिन में ज़्यादा से ज़्यादा एक, और स्ट्रीक के बारे में कभी नहीं। आपकी लॉक स्क्रीन पर कभी नहीं दिखेगा कि आपका मन कैसा है।", hl="Din mein zyada se zyada ek, aur streaks ke baare mein kabhi nahi. Aapki lock screen par kabhi nahi dikhega ki aapka mann kaisa hai.")
s("push_allow", "Allow", "Explainer button that opens the system notification prompt.", "అనుమతించండి", "Allow cheyandi", hi="अनुमति दें", hl="Allow karein")

# ---- feature fragments (tool/l10n/*.py) -------------------------------------
# Each fragment holds one feature's copy so features can add strings without
# editing this file. Fragments call the same helpers:
#   s(key, en, desc, te, te_Latn, ph=None, hi=None, hl=None)   new key (a duplicate is an error)
#   edit(key, en=None, te=None, tl=None, desc=None, hi=None, hl=None)   change an existing key
# hi = Hindi (Devanagari), hl = Hinglish (hi_Latn). Changing `en` in edit()
# without new hi / hl drops the old ones, so the stale translation can't ship.
def _frag_s(key, en, desc, te, tl, ph=None, hi=None, hl=None):
    if key in S:
        raise SystemExit(f"l10n: duplicate key '{key}' in a fragment")
    s(key, en, desc, te, tl, ph, hi, hl)


def _edit(key, en=None, te=None, tl=None, desc=None, hi=None, hl=None):
    if key not in S:
        raise SystemExit(f"l10n: edit() of unknown key '{key}'")
    old_en, old_desc, ph, old_te, old_tl, old_hi, old_hl = S[key]
    if en and en != old_en:
        old_hi = old_hl = None
    S[key] = (en or old_en, desc or old_desc, ph, te or old_te, tl or old_tl, hi or old_hi, hl or old_hl)


FRAGMENTS = os.path.join(HERE, "l10n")
if os.path.isdir(FRAGMENTS):
    for name in sorted(os.listdir(FRAGMENTS)):
        if not name.endswith(".py"):
            continue
        path = os.path.join(FRAGMENTS, name)
        with open(path, encoding="utf-8") as f:
            code = compile(f.read(), path, "exec")
        exec(code, {"s": _frag_s, "edit": _edit, "INT": INT, "STR": STR})

LOCALES = [("en", 0), ("te", 3), ("te_Latn", 4), ("hi", 5), ("hi_Latn", 6)]


def _uses(text, ph):
    """The declared placeholders a message uses (`{name}` or `{name, plural, …}`)."""
    return {n for n in (ph or {}) if re.search(r"\{\s*" + re.escape(n) + r"\s*[,}]", text)}


def _check():
    """Every key in every language, with the English placeholders (no fallback)."""
    problems = []
    for key, row in S.items():
        ph = row[2]
        want = _uses(row[0], ph)
        for locale, idx in LOCALES[1:]:
            val = row[idx]
            if not isinstance(val, str) or not val.strip():
                problems.append(f"{key}: no {locale}")
            elif _uses(val, ph) != want:
                problems.append(f"{key}: {locale} placeholders {sorted(_uses(val, ph))} != {sorted(want)}")
            elif locale == "hi_Latn" and re.search("[\u0900-\u097F]", val):
                problems.append(f"{key}: hi_Latn has Devanagari")
    if problems:
        raise SystemExit("l10n: " + "\n  ".join([f"{len(problems)} problem(s):"] + problems))


def arb(locale, idx):
    out = {"@@locale": locale}
    for key, row in S.items():
        en, desc, ph = row[0], row[1], row[2]
        out[key] = row[idx]
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


_check()
os.makedirs(OUT, exist_ok=True)
for _locale, _idx in LOCALES:
    write(f"app_{_locale}.arb", arb(_locale, _idx))
print(f"wrote {len(S)} keys x {len(LOCALES)} locales")
