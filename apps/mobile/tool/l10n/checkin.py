# Check-in (F1) and private history copy. Loaded by tool/l10n_source.py.
# s(key, en, desc, te, te_Latn, ph=None, hi=, hl=) · edit(key, en=, te=, tl=, desc=, hi=, hl=)
# te / te_Latn / hi / hi_Latn (hl) are first drafts: NEEDS NATIVE REVIEW before alpha / beta.

# ---- check-in picker ---------------------------------------------------------
s("checkin_discardTitle", "Leave without saving?", "Asked when closing the check-in (or an edit) with a mood, tags or words not yet saved. Calm, no blame.", "సేవ్ చేయకుండా వెళ్ళిపోతారా?", "Save cheyakunda vellipotaara?", hi="सेव किए बिना बाहर निकलें?", hl="Bina save kiye bahar niklein?")
s("checkin_discardKeep", "Keep editing", "Default choice in the leave-without-saving dialog: stay and keep what was entered.", "ఇక్కడే కొనసాగిస్తాను", "Ikkade continue chestaanu", hi="एडिट करते रहें", hl="Edit karte rahein")
s("checkin_discardConfirm", "Discard", "Leave-without-saving dialog: leave and drop what was entered.", "వదిలేయండి", "Vadileyandi", hi="हटा दें", hl="Hata dein")
s("checkin_tagLimit", "{count, plural, =1{Up to 1 tag} other{Up to {count} tags}}", "Calm hint shown when the tag limit for one check-in is reached.", "{count, plural, =1{1 ట్యాగ్ వరకు} other{{count} ట్యాగ్‌ల వరకు}}", "{count, plural, =1{1 tag varaku} other{{count} tags varaku}}", INT("count"), hi="{count, plural, =1{ज़्यादा से ज़्यादा 1 टैग} other{ज़्यादा से ज़्यादा {count} टैग}}", hl="{count, plural, =1{Zyada se zyada 1 tag} other{Zyada se zyada {count} tags}}")
s("checkin_quadrantAxes", "{energy} · {feel}", "Caption under a quadrant name when the mood grid is stacked one quadrant per row (large text). energy = 'More energy'/'Less energy', feel = 'Pleasant'/'Unpleasant'.", "{energy} · {feel}", "{energy} · {feel}", STR("energy", "feel"), hi="{energy} · {feel}", hl="{energy} · {feel}")

# ---- history (private list + one check-in) -----------------------------------
s("history_title", "Your check-ins", "Private history screen title.", "మీ చెక్-ఇన్‌లు", "Mee check-ins", hi="आपके चेक-इन", hl="Aapke check-ins")
s("history_private", "Only you can see these.", "Privacy line under the history title.", "ఇవి మీకు మాత్రమే కనిపిస్తాయి.", "Ivi meeku maatrame kanipistaayi.", hi="ये सिर्फ़ आपको दिखते हैं।", hl="Yeh sirf aapko dikhte hain.")
s("history_empty", "Nothing here yet. Your check-ins will gather here, and only you can see them.", "History empty state. Calm, no pressure.", "ఇక్కడ ఇంకా ఏమీ లేదు. మీ చెక్-ఇన్‌లు ఇక్కడ చేరుతాయి, అవి మీకు మాత్రమే కనిపిస్తాయి.", "Ikkada inka emi ledu. Mee check-ins ikkada cherutaayi, avi meeku maatrame kanipistaayi.", hi="यहाँ अभी कुछ नहीं है। आपके चेक-इन यहाँ जमा होंगे, और ये सिर्फ़ आपको दिखेंगे।", hl="Yahan abhi kuch nahi hai. Aapke check-ins yahan jama honge, aur yeh sirf aapko dikhenge.")
s("history_today", "Today", "Day header in history: the current Aura day.", "ఈరోజు", "Ee roju", hi="आज", hl="Aaj")
s("history_yesterday", "Yesterday", "Day header in history: the previous Aura day.", "నిన్న", "Ninna", hi="कल", hl="Kal")
s("history_tagCount", "{count, plural, =1{1 tag} other{{count} tags}}", "Discreet tag count on a history row.", "{count, plural, =1{1 ట్యాగ్} other{{count} ట్యాగ్‌లు}}", "{count, plural, =1{1 tag} other{{count} tags}}", INT("count"), hi="{count, plural, =1{1 टैग} other{{count} टैग}}", hl="{count, plural, =1{1 tag} other{{count} tags}}")
s("history_hasNote", "Has a note", "Screen-reader label for the note icon on a history row (the note itself is never shown in the list).", "ఒక నోట్ ఉంది", "Oka note undi", hi="नोट है", hl="Note hai")
s("history_entryTitle", "Your check-in", "Title of one check-in's page.", "మీ చెక్-ఇన్", "Mee check-in", hi="आपका चेक-इन", hl="Aapka check-in")
s("history_when", "{day}, {time}", "When a check-in was made, e.g. 'Today, 3:30 PM'.", "{day}, {time}", "{day}, {time}", STR("day", "time"), hi="{day}, {time}", hl="{day}, {time}")
s("history_tags", "Tags", "Section header on a check-in's page.", "ట్యాగ్‌లు", "Tags", hi="टैग", hl="Tags")
s("history_note", "Your words", "Section header for the private note on a check-in's page.", "మీ మాటలు", "Mee maatalu", hi="आपके शब्द", hl="Aapke shabd")
s("history_synced", "Synced", "Sync status: this check-in is safely on the server.", "సింక్ అయింది", "Sync ayyindi", hi="सिंक हो गया", hl="Sync ho gaya")
s("history_edit", "Edit", "Edit a check-in (only within a day).", "మార్చండి", "Edit cheyandi", hi="एडिट करें", hl="Edit karein")
s("history_editWindowOver", "You can edit a check-in for a day after you make it.", "Shown instead of Edit after 24 hours. Calm, informative.", "చెక్-ఇన్ చేసిన ఒక రోజు వరకు దాన్ని మార్చుకోవచ్చు.", "Check-in chesina oka roju varaku daanni maarchukovachu.", hi="चेक-इन करने के बाद एक दिन तक उसे एडिट किया जा सकता है।", hl="Check-in karne ke baad ek din tak use edit kiya ja sakta hai.")
s("history_delete", "Delete", "Delete a check-in (asks first).", "తొలగించండి", "Delete cheyandi", hi="डिलीट करें", hl="Delete karein")
s("history_deleteTitle", "Delete this check-in?", "Delete confirmation title.", "ఈ చెక్-ఇన్‌ను తొలగించాలా?", "Ee check-in delete cheyyaalaa?", hi="यह चेक-इन डिलीट करें?", hl="Yeh check-in delete karein?")
s("history_deleteBody", "This doesn't change your Starlight or glow days.", "Delete confirmation body: deleting never removes progress (PRD F1).", "దీనివల్ల మీ Starlight గానీ వెలుగు రోజులు గానీ మారవు.", "Deeni valla mee Starlight gaani glow days gaani maaravu.", hi="इससे आपकी Starlight या चमक वाले दिनों पर कोई असर नहीं पड़ता।", hl="Isse aapki Starlight ya glow days par koi asar nahi padta.")
s("history_missing", "This check-in isn't here anymore.", "Shown when a check-in was deleted or can't be found.", "ఈ చెక్-ఇన్ ఇప్పుడు ఇక్కడ లేదు.", "Ee check-in ippudu ikkada ledu.", hi="यह चेक-इन अब यहाँ नहीं है।", hl="Yeh check-in ab yahan nahi hai.")

# Integration: a pulled note this phone can't read yet blocks editing (the edit
# would overwrite the note on the server).
s("history_editNoteLocked", "This check-in's note hasn't reached this phone yet. You can edit it once it has.", "Shown instead of Edit when the note is still encrypted-only on this phone. Calm, no blame.", "ఈ చెక్-ఇన్ నోట్ ఇంకా ఈ ఫోన్‌కు రాలేదు. అది వచ్చాక మీరు దీన్ని మార్చవచ్చు.", "Ee check-in note inka ee phone ki raaledu. Adi vachaaka meeru dinni edit cheyochu.", hi="इस चेक-इन का नोट अभी इस फ़ोन तक नहीं पहुँचा है। पहुँचने के बाद इसे एडिट किया जा सकता है।", hl="Is check-in ka note abhi is phone tak nahi pahuncha hai. Pahunchne ke baad ise edit kiya ja sakta hai.")
