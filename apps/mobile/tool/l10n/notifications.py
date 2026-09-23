# F14 notifications (Milestone A): Settings › Notifications, the in-app
# notices for pushes that arrive while Aura is open, the Android channel and
# the evening-time row on the post-check-in explainer. Loaded by
# tool/l10n_source.py.
# s(key, en, desc, te, te_Latn, ph=None) · edit(key, en=, te=, tl=, desc=)
# te / te_Latn are first drafts: NEEDS NATIVE REVIEW before alpha.
#
# REQ-NTF-01: every key starting with `notif_` (anything shown as, or instead
# of, a notification) is checked by the server's copy lint
# (server/aura-api `pnpm lint:copy`): no mood, quadrant or room theme name,
# never miss / lose / streak / broken / fading / last chance / hurry.

# ---- in-app notices (a push while Aura is open; never a system banner) -------
s("notif_reminderBanner", "A quiet minute for you. How's today feeling?", "In-app notice when the daily check-in reminder arrives while the app is open (same line as the push, PRD 12-notifications catalogue). Never guilt, never a streak.", "మీ కోసం ఒక నిమిషం. ఈ రోజు ఎలా అనిపిస్తోంది?", "Mee kosam oka quiet minute. Ee roju ela anipistondi?")
s("notif_reminderAction", "Check in", "Action on the reminder notice: opens the check-in.", "చెక్-ఇన్ చేయండి", "Check in cheyandi")
s("notif_capsuleBanner", "Something you sealed is ready to open.", "In-app notice when a date capsule's push arrives while the app is open (PRD catalogue line). Never a title, date or mood.", "మీరు దాచుకున్నది ఇప్పుడు తెరవొచ్చు.", "Meeru daachukunnadi ippudu open cheyyochu.")
s("notif_capsuleAction", "Open", "Action on the capsule notice: opens the capsules.", "తెరవండి", "Open cheyandi")
s("notif_channelReminders", "Reminders", "Android notification channel name for the daily check-in reminder (phone Settings).", "రిమైండర్లు", "Reminders")
s("notif_channelRemindersDescription", "Your daily check-in reminder.", "Android notification channel description (phone Settings).", "మీ రోజువారీ చెక్-ఇన్ రిమైండర్.", "Mee daily check-in reminder.")

# ---- Settings › Notifications ------------------------------------------------
s("set_notifications", "Notifications", "Settings section heading.", "నోటిఫికేషన్లు", "Notifications")
s("set_notifMaster", "Notifications from Aura", "Master switch for every push.", "Aura నుండి నోటిఫికేషన్లు", "Aura nundi notifications")
s("set_notifMasterNote", "At most two a day. Nothing on your lock screen says how you feel.", "Under the master switch: the daily cap and the privacy promise (PRD 12 rules 2 and 3). Calm.", "రోజుకు రెండు మించి రావు. మీరు ఎలా ఫీల్ అవుతున్నారో మీ లాక్ స్క్రీన్ ఎప్పుడూ చెప్పదు.", "Rojuki rendu minchi raavu. Meeru ela feel avutunnaro mee lock screen eppudu cheppadu.")
s("set_notifReminder", "Daily check-in reminder", "Switch for the daily reminder push.", "రోజువారీ చెక్-ఇన్ రిమైండర్", "Daily check-in reminder")
s("set_notifReminderNote", "One gentle nudge a day, at {time}. Skipped once you've checked in.", "Under the reminder switch when on; {time} is the chosen time, e.g. '8:00 PM'.", "రోజుకు ఒక్క మృదువైన గుర్తు, {time}కి. మీరు చెక్-ఇన్ చేశాక రాదు.", "Rojuki okka gentle nudge, {time} ki. Meeru check-in chesaaka raadu.", STR("time"))
s("set_notifReminderOffNote", "Off. Turn it on for one gentle nudge a day.", "Under the reminder switch when off.", "ఆఫ్‌లో ఉంది. రోజుకు ఒక్క మృదువైన గుర్తు కావాలంటే ఆన్ చేయండి.", "Off lo undi. Rojuki okka gentle nudge kaavaalante on cheyandi.")
s("set_notifReminderTime", "Reminder time", "Row that opens the time picker for the daily reminder.", "రిమైండర్ సమయం", "Reminder time")
s("set_notifCapsule", "A capsule is ready to open", "Switch for the 'date capsule unlocked' push.", "క్యాప్సూల్ తెరవడానికి సిద్ధంగా ఉన్నప్పుడు", "Capsule open cheyyadaaniki ready ainappudu")
s("set_notifCapsuleNote", "On the day you chose for something you sealed.", "Under the capsule switch.", "మీరు దాచుకున్నదానికి మీరు ఎంచుకున్న రోజున.", "Meeru daachukunnadaaniki meeru select chesina roju.")
s("set_notifQuietNote", "Quiet hours: nothing is sent {start}–{end}.", "Quiet hours explainer; {start}/{end} are times like '11:00 PM'.", "నిశ్శబ్ద సమయం: {start}–{end} మధ్య ఏదీ పంపం.", "Quiet hours: {start}–{end} madhya edi pampam.", STR("start", "end"))
s("set_notifQuietFrom", "Quiet from", "Row: start of quiet hours (opens a time picker).", "నిశ్శబ్దం మొదలు", "Quiet modalu")
s("set_notifQuietUntil", "Quiet until", "Row: end of quiet hours (opens a time picker).", "నిశ్శబ్దం ముగింపు", "Quiet mugimpu")
s("set_notifDiscreet", "Discreet mode", "Switch: every push shows only a generic line (PRD rule 4).", "గోప్య మోడ్", "Discreet mode")
s("set_notifDiscreetNote", "Every notification just says “Aura · You have a gentle update”.", "Under the discreet switch; quotes the discreet line.", "ప్రతి నోటిఫికేషన్ “Aura · మీకు ఒక మృదువైన అప్‌డేట్ ఉంది” అని మాత్రమే చెబుతుంది.", "Prati notification “Aura · Meeku oka gentle update undi” ani maatrame cheptundi.")
s("set_notifOffNote", "Notifications are off for Aura on this phone. Your choices here still apply once they're on.", "Calm note when the OS permission is off (PRD 15-permissions). No blame.", "ఈ ఫోన్‌లో Aura నోటిఫికేషన్లు ఆఫ్‌లో ఉన్నాయి. అవి ఆన్ అయ్యాక ఇక్కడి మీ ఎంపికలే వర్తిస్తాయి.", "Ee phone lo Aura notifications off lo unnaayi. Avi on ayyaaka ikkadi mee choices ey apply avutaayi.")
s("set_notifTurnOn", "Turn on", "Button in the off note: shows the phone's notification prompt.", "ఆన్ చేయండి", "On cheyandi")
s("set_notifOpenSettings", "Open phone settings", "Button in the off note: opens this app's page in the phone's Settings.", "ఫోన్ సెట్టింగ్‌లు తెరవండి", "Phone settings open cheyandi")
s("set_notifQuietConfirmTitle", "This time is inside your quiet hours", "Dialog title: the chosen reminder time falls inside quiet hours (one-time confirmation, PRD rule 1).", "ఈ సమయం మీ నిశ్శబ్ద సమయంలో ఉంది", "Ee time mee quiet hours lo undi")
s("set_notifQuietConfirmBody", "Aura stays silent {start}–{end}. Send your reminder at {time} anyway?", "Dialog body; {start}/{end} quiet hours, {time} the reminder time.", "Aura {start}–{end} మధ్య నిశ్శబ్దంగా ఉంటుంది. అయినా మీ రిమైండర్‌ను {time}కి పంపాలా?", "Aura {start}–{end} madhya quiet ga untundi. Ayinaa mee reminder ni {time} ki pampaala?", STR("start", "end", "time"))
s("set_notifQuietConfirmYes", "Send it anyway", "Dialog: keep the reminder inside quiet hours (night shifts).", "అయినా పంపండి", "Ayinaa pampandi")
s("set_notifQuietConfirmNo", "Keep it quiet", "Dialog: don't send inside quiet hours.", "నిశ్శబ్దంగానే ఉంచండి", "Quiet gaane unchandi")

# ---- post-check-in explainer (PRD 15-permissions "with a time picker") -------
s("push_timeRow", "Every evening at {time}", "On the notification explainer: when the daily nudge comes; {time} e.g. '8:00 PM'.", "ప్రతి సాయంత్రం {time}కి", "Prati saayantram {time} ki", STR("time"))
s("push_changeTime", "Change time", "Opens the time picker on the explainer.", "సమయం మార్చండి", "Time maarchandi")
s("push_discreet", "Keep them discreet", "Checkbox on the explainer: discreet mode (PRD 12 rule 4, a one-tap choice on the permission screen). The line under it quotes the discreet text.", "గోప్యంగా ఉంచండి", "Discreet ga unchandi")
