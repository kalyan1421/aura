# Check-in (F1) and private history copy. Loaded by tool/l10n_source.py.
# s(key, en, desc, te, te_Latn, ph=None) · edit(key, en=, te=, tl=, desc=)
# te / te_Latn are first drafts: NEEDS NATIVE REVIEW before alpha.

# ---- check-in picker ---------------------------------------------------------
s("checkin_discardTitle", "Leave without saving?", "Asked when closing the check-in (or an edit) with a mood, tags or words not yet saved. Calm, no blame.", "సేవ్ చేయకుండా వెళ్ళిపోతారా?", "Save cheyakunda vellipotaara?")
s("checkin_discardKeep", "Keep editing", "Default choice in the leave-without-saving dialog: stay and keep what was entered.", "ఇక్కడే కొనసాగిస్తాను", "Ikkade continue chestaanu")
s("checkin_discardConfirm", "Discard", "Leave-without-saving dialog: leave and drop what was entered.", "వదిలేయండి", "Vadileyandi")
s("checkin_tagLimit", "{count, plural, =1{Up to 1 tag} other{Up to {count} tags}}", "Calm hint shown when the tag limit for one check-in is reached.", "{count, plural, =1{1 ట్యాగ్ వరకు} other{{count} ట్యాగ్‌ల వరకు}}", "{count, plural, =1{1 tag varaku} other{{count} tags varaku}}", INT("count"))
s("checkin_quadrantAxes", "{energy} · {feel}", "Caption under a quadrant name when the mood grid is stacked one quadrant per row (large text). energy = 'More energy'/'Less energy', feel = 'Pleasant'/'Unpleasant'.", "{energy} · {feel}", "{energy} · {feel}", STR("energy", "feel"))

# ---- history (private list + one check-in) -----------------------------------
s("history_title", "Your check-ins", "Private history screen title.", "మీ చెక్-ఇన్‌లు", "Mee check-ins")
s("history_private", "Only you can see these.", "Privacy line under the history title.", "ఇవి మీకు మాత్రమే కనిపిస్తాయి.", "Ivi meeku maatrame kanipistaayi.")
s("history_empty", "Nothing here yet. Your check-ins will gather here, and only you can see them.", "History empty state. Calm, no pressure.", "ఇక్కడ ఇంకా ఏమీ లేదు. మీ చెక్-ఇన్‌లు ఇక్కడ చేరుతాయి, అవి మీకు మాత్రమే కనిపిస్తాయి.", "Ikkada inka emi ledu. Mee check-ins ikkada cherutaayi, avi meeku maatrame kanipistaayi.")
s("history_today", "Today", "Day header in history: the current Aura day.", "ఈరోజు", "Ee roju")
s("history_yesterday", "Yesterday", "Day header in history: the previous Aura day.", "నిన్న", "Ninna")
s("history_tagCount", "{count, plural, =1{1 tag} other{{count} tags}}", "Discreet tag count on a history row.", "{count, plural, =1{1 ట్యాగ్} other{{count} ట్యాగ్‌లు}}", "{count, plural, =1{1 tag} other{{count} tags}}", INT("count"))
s("history_hasNote", "Has a note", "Screen-reader label for the note icon on a history row (the note itself is never shown in the list).", "ఒక నోట్ ఉంది", "Oka note undi")
s("history_entryTitle", "Your check-in", "Title of one check-in's page.", "మీ చెక్-ఇన్", "Mee check-in")
s("history_when", "{day}, {time}", "When a check-in was made, e.g. 'Today, 3:30 PM'.", "{day}, {time}", "{day}, {time}", STR("day", "time"))
s("history_tags", "Tags", "Section header on a check-in's page.", "ట్యాగ్‌లు", "Tags")
s("history_note", "Your words", "Section header for the private note on a check-in's page.", "మీ మాటలు", "Mee maatalu")
s("history_synced", "Synced", "Sync status: this check-in is safely on the server.", "సింక్ అయింది", "Sync ayyindi")
s("history_edit", "Edit", "Edit a check-in (only within a day).", "మార్చండి", "Edit cheyandi")
s("history_editWindowOver", "You can edit a check-in for a day after you make it.", "Shown instead of Edit after 24 hours. Calm, informative.", "చెక్-ఇన్ చేసిన ఒక రోజు వరకు దాన్ని మార్చుకోవచ్చు.", "Check-in chesina oka roju varaku daanni maarchukovachu.")
s("history_delete", "Delete", "Delete a check-in (asks first).", "తొలగించండి", "Delete cheyandi")
s("history_deleteTitle", "Delete this check-in?", "Delete confirmation title.", "ఈ చెక్-ఇన్‌ను తొలగించాలా?", "Ee check-in delete cheyyaalaa?")
s("history_deleteBody", "This doesn't change your Starlight or glow days.", "Delete confirmation body: deleting never removes progress (PRD F1).", "దీనివల్ల మీ Starlight గానీ వెలుగు రోజులు గానీ మారవు.", "Deeni valla mee Starlight gaani glow days gaani maaravu.")
s("history_missing", "This check-in isn't here anymore.", "Shown when a check-in was deleted or can't be found.", "ఈ చెక్-ఇన్ ఇప్పుడు ఇక్కడ లేదు.", "Ee check-in ippudu ikkada ledu.")

# Integration: a pulled note this phone can't read yet blocks editing (the edit
# would overwrite the note on the server).
s("history_editNoteLocked", "This check-in's note hasn't reached this phone yet. You can edit it once it has.", "Shown instead of Edit when the note is still encrypted-only on this phone. Calm, no blame.", "ఈ చెక్-ఇన్ నోట్ ఇంకా ఈ ఫోన్‌కు రాలేదు. అది వచ్చాక మీరు దీన్ని మార్చవచ్చు.", "Ee check-in note inka ee phone ki raaledu. Adi vachaaka meeru dinni edit cheyochu.")
