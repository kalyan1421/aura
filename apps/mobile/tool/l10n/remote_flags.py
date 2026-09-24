# Milestone A remote flags and device bans (PRD 19 REQ-ADM-14, rooms kill
# switch). Loaded by tool/l10n_source.py.
# s(key, en, desc, te, te_Latn, ph=None, hi=, hl=) · edit(key, en=, te=, tl=, desc=, hi=, hl=)
# te / te_Latn / hi / hi_Latn (hl) are first drafts: NEEDS NATIVE REVIEW before alpha / beta.
#
# These strings were added straight to lib/l10n/*.arb in 25db8a4 with no
# source here, so every tool/gen.sh run dropped them. Recovered verbatim
# from those ARBs.

s("device_bannedTitle", "This device can't use Aura", "Title of the full-screen page shown when this phone is banned (403 device_banned, PRD 19 REQ-ADM-14). Calm; never says why (no tipping off).", "ఈ పరికరంలో Aura ఉపయోగించలేరు", "Ee device lo Aura use cheyyalemu", hi="इस डिवाइस पर Aura इस्तेमाल नहीं किया जा सकता", hl="Is device par Aura use nahi kiya ja sakta")
s("device_bannedBody", "Aura isn't available on this phone.", "Body under device_bannedTitle. No reason, no blame.", "ఈ ఫోన్‌లో Aura అందుబాటులో లేదు.", "Ee phone lo Aura available ledu.", hi="इस फ़ोन पर Aura उपलब्ध नहीं है।", hl="Is phone par Aura available nahi hai.")
s("device_bannedReviewSubject", "Review of a device", "Email subject when asking for a review of a device ban. Nothing about the person or the phone.", "పరికరం పునఃపరిశీలన", "Device review", hi="डिवाइस का रिव्यू", hl="Device ka review")
s("rooms_paused", "Rooms are resting for a bit. Try again later.", "Shown where rooms are offered while the rooms kill switch is off (flag rooms_enabled, 503 rooms_paused). Calm, no blame.", "రూమ్‌లు కాసేపు విశ్రాంతి తీసుకుంటున్నాయి. తర్వాత మళ్ళీ ప్రయత్నించండి.", "Rooms konchem sepu rest teesukuntunnayi. Taruvaata malli try cheyandi.", hi="रूम कुछ देर आराम कर रहे हैं। थोड़ी देर बाद फिर से कोशिश करें।", hl="Rooms kuch der aaram kar rahe hain. Thodi der baad phir se try karein.")
s("rooms_pausedJoin", "Rooms are resting for a bit. Your check-in is saved.", "After a check-in, when the rooms kill switch is off.", "రూమ్‌లు కాసేపు విశ్రాంతి తీసుకుంటున్నాయి. మీ చెక్-ఇన్ సేవ్ అయింది.", "Rooms konchem sepu rest teesukuntunnayi. Mee check-in save ayyindi.", hi="रूम कुछ देर आराम कर रहे हैं। आपका चेक-इन सेव हो गया है।", hl="Rooms kuch der aaram kar rahe hain. Aapka check-in save ho gaya hai.")
