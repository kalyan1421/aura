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

# ==== F14 Milestone B (contracts/api/v1-notifications.md §6–§10) =============
# The rest of the PRD 12 catalogue: gestures received, Lantern Hour, the
# opt-in wind-down reminder (REQ-NTF-04), habit nudges, welcome back, and the
# crisis follow-up card (in-app only, never a push). `notif_*` keys are
# copy-linted (REQ-NTF-01 + the "calm, not treatment" claim list).

# ---- in-app notices for pushes that arrive while Aura is open ---------------
s("notif_gesturesBanner", "People in your room sent you warmth.", "In-app notice when the 'gestures received' push arrives while the app is open. Never a pseudonym, count of gestures, theme or mood.", "మీ రూమ్‌లో కొందరు మీకు ఆత్మీయత పంపారు.", "Mee room lo kondaru meeku warmth pampaaru.")
s("notif_gesturesAction", "Open room", "Action on the gestures notice: opens that room.", "రూమ్ తెరవండి", "Room open cheyandi")
s("notif_lanternBanner", "Lantern Hour is on. Others are here tonight.", "In-app notice when the Lantern Hour push arrives while the app is open (PRD catalogue line).", "Lantern Hour మొదలైంది. ఈ రాత్రి ఇంకా కొందరు ఇక్కడే ఉన్నారు.", "Lantern Hour modalaindi. Ee raatri inka kondaru ikkade unnaru.")
s("notif_lanternAction", "See rooms", "Action on the Lantern Hour notice: opens Rooms.", "రూమ్‌లు చూడండి", "Rooms chudandi")
s("notif_windDownBanner", "A few quiet minutes before sleep, whenever you want them.", "In-app notice for the wind-down reminder (PRD line). Never promises better sleep (REQ-NTF-04).", "పడుకునే ముందు కొంచెం నిశ్శబ్ద సమయం? Aura ఇక్కడే ఉంది.", "Padukune mundu konchem quiet time? Aura ikkade undi.")
s("notif_windDownAction", "Open Sounds", "Action on the wind-down notice: opens Sanctuary › Sounds (nothing plays until a tap).", "శబ్దాలు తెరవండి", "Sounds open cheyandi")
s("notif_habitBanner", "A small habit or two, whenever you're ready.", "In-app notice for a habit nudge. Never a habit's name.", "ఒక చిన్న అలవాటు, మీకు వీలైనప్పుడు.", "Oka chinna habit, meeku veelainappudu.")
s("notif_habitAction", "See habits", "Action on the habit nudge notice: opens Home.", "అలవాట్లు చూడండి", "Habits chudandi")
s("notif_crisisFollowUp", "Just checking in. However today feels, help is one tap away.", "Crisis follow-up (PRD 12): an in-app card on the next open 12–72 h after the support sheet showed. Never a push, never mentions distress or what happened.", "ఊరికే అడుగుతున్నాం, ఈ రోజు ఎలా ఉంది? సహాయం ఒక్క ట్యాప్ దూరంలో ఉంది.", "Oorike adugutunnam, ee roju ela undi? Help oka tap dooram lo undi.")
s("notif_crisisFollowUpDismiss", "Close", "Closes the follow-up card (it doesn't come back for this time).", "మూసివేయండి", "Close cheyandi")
edit("notif_channelRemindersDescription", en="Your check-in, wind-down and habit reminders.", te="మీ చెక్-ఇన్, నిద్రకు ముందు, అలవాట్ల రిమైండర్లు.", tl="Mee check-in, wind-down, habit reminders.")
edit("notif_channelRoomsDescription", en="Lantern Hour, warmth from your room, and rooms you asked about.", te="Lantern Hour, మీ రూమ్ నుండి ఆత్మీయత, మీరు అడిగిన రూమ్‌లు.", tl="Lantern Hour, mee room nundi warmth, meeru adigina rooms.")

# ---- Settings › Notifications (per-type toggles, PRD 12 rule 8) -------------
s("set_notifGestures", "Warmth from your room", "Switch: the 'gestures received' push (batched).", "మీ రూమ్ నుండి ఆత్మీయత", "Mee room nundi warmth")
s("set_notifGesturesNote", "When people in your room send you a gesture. One a day at most.", "Under the gestures switch.", "మీ రూమ్‌లో ఎవరైనా మీకు గెస్చర్ పంపినప్పుడు. రోజుకు ఒక్కటి మించదు.", "Mee room lo evaraina meeku gesture pampinappudu. Rojuki okkati minchadu.")
s("set_notifLantern", "Lantern Hour", "Switch: the opt-in Lantern Hour push.", "Lantern Hour", "Lantern Hour")
s("set_notifLanternNote", "When Lantern Hour starts in your evening. Not if you've already been in a room that day.", "Under the Lantern Hour switch (region clock, around 9 pm).", "మీ సాయంత్రం Lantern Hour మొదలైనప్పుడు. ఆ రోజు మీరు ఇప్పటికే రూమ్‌లో ఉంటే రాదు.", "Mee saayantram Lantern Hour modalainappudu. Aa roju meeru ippatike room lo unte raadu.")
s("set_notifWindDown", "Wind-down reminder", "Switch: the opt-in wind-down reminder (REQ-NTF-04).", "నిద్రకు ముందు రిమైండర్", "Wind-down reminder")
s("set_notifWindDownNote", "A few quiet minutes at {time}. Not sent once you've used Sanctuary that evening.", "Under the wind-down switch when on; {time} e.g. '10:30 PM'. No sleep promise.", "{time}కి కొంచెం నిశ్శబ్ద సమయం. ఆ సాయంత్రం మీరు Sanctuary వాడితే రాదు.", "{time} ki konchem quiet time. Aa saayantram meeru Sanctuary vaadite raadu.", STR("time"))
s("set_notifWindDownOffNote", "Off. Pick a time for a quiet nudge before sleep.", "Under the wind-down switch when off.", "ఆఫ్‌లో ఉంది. నిద్రకు ముందు ఒక నిశ్శబ్ద గుర్తు కోసం సమయం ఎంచుకోండి.", "Off lo undi. Padukune mundu oka quiet nudge kosam time select cheyandi.")
s("set_notifWindDownTime", "Wind-down time", "Row that opens the time picker for the wind-down reminder.", "నిద్రకు ముందు సమయం", "Wind-down time")
s("set_notifWelcomeBack", "After a quiet while", "Switch: the 'welcome back' push.", "కొంత కాలం తర్వాత", "Konta kaalam tarvaata")
s("set_notifWelcomeBackNote", "If you've been away a week or more, one gentle hello. Twice at most.", "Under the welcome-back switch. No guilt.", "మీరు వారం లేదా అంతకంటే ఎక్కువ దూరంగా ఉంటే, ఒక మృదువైన పలకరింపు. రెండు సార్లు మించదు.", "Meeru vaaram leda antakante ekkuva dooram ga unte, oka gentle hello. Rendu saarlu minchadu.")
s("set_notifHabits", "Habit nudges", "Sub-heading: per-habit nudge times (opt-in).", "అలవాటు గుర్తులు", "Habit nudges")
s("set_notifHabitsNote", "A small nudge at a time you pick, for any habit on Home. One a day at most.", "Under the habit nudges heading.", "Home లోని ఏ అలవాటుకైనా, మీరు ఎంచుకున్న సమయంలో ఒక చిన్న గుర్తు. రోజుకు ఒక్కటి మించదు.", "Home lo e habit ki aina, meeru select chesina time lo oka chinna nudge. Rojuki okkati minchadu.")
s("set_notifHabitsNone", "Add a habit on Home to get a nudge for it.", "Habit nudges when there are no active habits.", "గుర్తు కోసం Home లో ఒక అలవాటు జోడించండి.", "Nudge kosam Home lo oka habit add cheyandi.")
s("set_notifHabitOff", "Off", "Trailing value of a habit row without a nudge.", "ఆఫ్", "Off")
s("set_notifHabitQuiet", "Inside your quiet hours, so it won't be sent.", "Under a habit nudge whose time is inside quiet hours.", "ఇది మీ నిశ్శబ్ద సమయంలో ఉంది, కాబట్టి రాదు.", "Idi mee quiet hours lo undi, kaabatti raadu.")
s("set_notifHabitChange", "Change time", "Dialog action on a habit with a nudge.", "సమయం మార్చండి", "Time maarchandi")
s("set_notifHabitTurnOff", "Turn off", "Dialog action: remove this habit's nudge.", "ఆఫ్ చేయండి", "Off cheyandi")

# ---- Sounds › night wind-down (the wind-down reminder set from Sanctuary) ----
s("sounds_windDownRemind", "Remind me at {time}", "On the night wind-down card: turns on the opt-in wind-down reminder (asks for a time first). {time} e.g. '10:30 PM'.", "{time}కి గుర్తు చేయండి", "{time} ki gurthu cheyandi", STR("time"))
s("sounds_windDownReminderOn", "A gentle reminder comes at {time}.", "On the wind-down card when the reminder is on.", "{time}కి ఒక మృదువైన గుర్తు వస్తుంది.", "{time} ki oka gentle reminder vastundi.", STR("time"))
s("sounds_windDownReminderOff", "Turn off", "Turns the wind-down reminder off from the card.", "ఆఫ్ చేయండి", "Off cheyandi")
