# Forced update (MASVS-CODE-2, docs/security/masvs-l1.md F-6): the full screen
# shown when this app is older than the server's `minAppVersion`
# (contracts/api/v1.md "Remote config"). Loaded by tool/l10n_source.py.
# s(key, en, desc, te, te_Latn, ph=None, hi=, hl=) · edit(key, en=, te=, tl=, desc=, hi=, hl=)
# te / te_Latn / hi / hi_Latn (hl) are first drafts: NEEDS NATIVE REVIEW before alpha / beta.
#
# Rules: calm, never alarming or blaming; say plainly that nothing on the phone
# is lost; no technical words (no "version", "deprecated", "security fix").
# "I need help now" stays in the top bar, so it isn't repeated here.

s("update_title", "Please update Aura",
  "Title of the full screen shown when this app is too old to keep using. Calm, a request, not an error.",
  "దయచేసి Auraని అప్‌డేట్ చేయండి",
  "Dayachesi Aura ni update cheyandi", hi="कृपया Aura अपडेट करें", hl="Please Aura update karein")
s("update_body", "This copy of Aura needs an update before it can keep going. It only takes a moment.",
  "Body under update_title. Plain words, no version numbers or reasons.",
  "Aura కొనసాగాలంటే ఈ కాపీకి అప్‌డేట్ అవసరం. ఒక్క క్షణమే పడుతుంది.",
  "Aura continue avvaalante ee copy ki update avasaram. Oka kshaname padutundi.",
  hi="Aura को आगे चलाने के लिए इसे अपडेट करना ज़रूरी है। बस एक पल लगेगा।",
  hl="Aura ko aage chalane ke liye ise update karna zaroori hai. Bas ek pal lagega.")
s("update_safe", "Everything on this phone stays safe. Your check-ins sync as soon as you've updated.",
  "Reassurance under the body: nothing is deleted; unsynced check-ins are kept and sync after the update.",
  "ఈ ఫోన్‌లో ఉన్నవన్నీ భద్రంగా ఉంటాయి. అప్‌డేట్ అయిన వెంటనే మీ చెక్-ఇన్‌లు సింక్ అవుతాయి.",
  "Ee phone lo unnavanni bhadranga untaayi. Update ayina ventane mee check-ins sync avutaayi.",
  hi="इस फ़ोन पर सब कुछ सुरक्षित रहेगा। अपडेट होते ही आपके चेक-इन सिंक हो जाएँगे।",
  hl="Is phone par sab kuch surakshit rahega. Update hote hi aapke check-ins sync ho jayenge.")
s("update_openAppStore", "Update in the App Store",
  "Primary button on iPhone: opens Aura's App Store page.",
  "App Storeలో అప్‌డేట్ చేయండి",
  "App Store lo update cheyandi", hi="App Store में अपडेट करें", hl="App Store mein update karein")
s("update_openPlayStore", "Update on Google Play",
  "Primary button on Android: opens Aura's Google Play page.",
  "Google Playలో అప్‌డేట్ చేయండి",
  "Google Play lo update cheyandi", hi="Google Play पर अपडेट करें", hl="Google Play par update karein")
s("update_storeFailed", "The store didn't open. Please open it yourself and search for Aura.",
  "Shown under the button when the store page could not be opened.",
  "స్టోర్ తెరుచుకోలేదు. దయచేసి మీరే తెరిచి Aura కోసం వెతకండి.",
  "Store open avvaledu. Dayachesi meere open chesi Aura kosam vetakandi.",
  hi="स्टोर नहीं खुला। कृपया खुद खोलकर Aura खोजें।",
  hl="Store nahi khula. Please khud kholkar Aura search karein.")
