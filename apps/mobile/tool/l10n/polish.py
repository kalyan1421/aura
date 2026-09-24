# Polish copy: legal-link and helpline fallbacks when the device can't open
# the browser or place a call. Loaded by tool/l10n_source.py.
# s(key, en, desc, te, te_Latn, ph=None, hi=, hl=) · edit(key, en=, te=, tl=, desc=, hi=, hl=)
# te / te_Latn / hi / hi_Latn (hl) are first drafts: NEEDS NATIVE REVIEW before alpha / beta.

# ---- Legal links: the browser didn't open --------------------------------
s("polish_legalOpenFailed", "Your browser didn't open. The page is at {url}.", "Calm inline note under the Privacy policy / Terms links when no browser could open the page. {url} is the public page address (not personal data). No blame.", "మీ బ్రౌజర్ తెరుచుకోలేదు. ఆ పేజీ {url} లో ఉంది.", "Mee browser open avvaledu. Aa page {url} lo undi.", STR("url"), hi="आपका ब्राउज़र नहीं खुला। यह पेज {url} पर है।", hl="Aapka browser nahi khula. Yeh page {url} par hai.")
s("polish_legalCopyLink", "Copy link", "Button next to the note above: copies the page address.", "లింక్ కాపీ చేయండి", "Link copy cheyandi", hi="लिंक कॉपी करें", hl="Link copy karein")
s("polish_legalLinkCopied", "Link copied", "Shown and announced after the page address was copied.", "లింక్ కాపీ అయింది", "Link copy ayyindi", hi="लिंक कॉपी हो गया", hl="Link copy ho gaya")

# ---- Helplines: this device can't place calls (iPad, simulator) ----------
s("polish_helpCallFailed", "This phone can't place the call. The number is {number}.", "Calm inline note under a helpline when the device can't dial (iPad, simulator). {number} is the helpline number as shown. Never alarming.", "ఈ ఫోన్ నుంచి కాల్ చేయడం కుదరడం లేదు. నంబర్ {number}.", "Ee phone nundi call cheyyadam kudaratledu. Number {number}.", STR("number"), hi="इस फ़ोन से कॉल करना मुमकिन नहीं है। नंबर है {number}।", hl="Is phone se call karna mumkin nahi hai. Number hai {number}.")
s("polish_helpCopyNumber", "Copy number", "Button next to the note above: copies the helpline number.", "నంబర్ కాపీ చేయండి", "Number copy cheyandi", hi="नंबर कॉपी करें", hl="Number copy karein")
s("polish_helpNumberCopied", "Number copied", "Shown and announced after the helpline number was copied.", "నంబర్ కాపీ అయింది", "Number copy ayyindi", hi="नंबर कॉपी हो गया", hl="Number copy ho gaya")
