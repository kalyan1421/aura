# Polish copy: legal-link and helpline fallbacks when the device can't open
# the browser or place a call. Loaded by tool/l10n_source.py.
# s(key, en, desc, te, te_Latn, ph=None) · edit(key, en=, te=, tl=, desc=)
# te / te_Latn are first drafts: NEEDS NATIVE REVIEW before alpha.

# ---- Legal links: the browser didn't open --------------------------------
s("polish_legalOpenFailed", "Your browser didn't open. The page is at {url}.", "Calm inline note under the Privacy policy / Terms links when no browser could open the page. {url} is the public page address (not personal data). No blame.", "మీ బ్రౌజర్ తెరుచుకోలేదు. ఆ పేజీ {url} లో ఉంది.", "Mee browser open avvaledu. Aa page {url} lo undi.", STR("url"))
s("polish_legalCopyLink", "Copy link", "Button next to the note above: copies the page address.", "లింక్ కాపీ చేయండి", "Link copy cheyandi")
s("polish_legalLinkCopied", "Link copied", "Shown and announced after the page address was copied.", "లింక్ కాపీ అయింది", "Link copy ayyindi")

# ---- Helplines: this device can't place calls (iPad, simulator) ----------
s("polish_helpCallFailed", "This phone can't place the call. The number is {number}.", "Calm inline note under a helpline when the device can't dial (iPad, simulator). {number} is the helpline number as shown. Never alarming.", "ఈ ఫోన్ నుంచి కాల్ చేయడం కుదరడం లేదు. నంబర్ {number}.", "Ee phone nundi call cheyyadam kudaratledu. Number {number}.", STR("number"))
s("polish_helpCopyNumber", "Copy number", "Button next to the note above: copies the helpline number.", "నంబర్ కాపీ చేయండి", "Number copy cheyandi")
s("polish_helpNumberCopied", "Number copied", "Shown and announced after the helpline number was copied.", "నంబర్ కాపీ అయింది", "Number copy ayyindi")
