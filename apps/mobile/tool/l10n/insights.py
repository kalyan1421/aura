# F10 Insights ("Aura Sky"). Loaded by tool/l10n_source.py.
# s(key, en, desc, te, te_Latn, ph=None) · edit(key, en=, te=, tl=, desc=)
# te / te_Latn are first drafts: NEEDS NATIVE REVIEW before alpha.
#
# Copy rules (PRD F10, REQ-INS-03 `[LEGAL]`): descriptive only. "More often",
# never "because"; no numbers, percentages, scores, labels or diagnoses in a
# pattern; every quadrant uses the same template, so no feeling reads worse
# than another. Pattern sentences are whole templates with placeholders,
# never assembled from pieces. The linter in test/insights_copy_lint_test.dart
# fails the build on banned words.

# ---- screen -----------------------------------------------------------------
s("insights_title", "Aura Sky", "Title of the Insights tab: the person's check-in history drawn as a night sky. 'Aura Sky' is a brand name.", "Aura Sky", "Aura Sky")
s("insights_private", "Only you can see your sky. It's worked out on this phone.", "Privacy line under the sky: patterns are computed on the device and never uploaded (PRD F10).", "మీ ఆకాశం మీకు మాత్రమే కనిపిస్తుంది. ఇదంతా ఈ ఫోన్‌లోనే లెక్కిస్తాం.", "Mee sky meeku maatrame kanipistundi. Idantaa ee phone lone lekkistaam.")
s("insights_empty", "Your sky fills in as you check in.", "Empty Insights (no check-ins yet): a quiet sky and a Check in button (PRD F10 edge cases, 14-states).", "మీరు చెక్-ఇన్ చేస్తున్న కొద్దీ మీ ఆకాశం నిండుతుంది.", "Meeru check-in chestunna koddi mee sky nindutundi.")
s("insights_allCheckIns", "All check-ins", "Button that opens the full private list of check-ins (history), with edit and delete.", "అన్ని చెక్-ఇన్‌లు", "Anni check-ins")

# ---- sky calendar -----------------------------------------------------------
s("insights_viewMonth", "Month", "Sky view switch: one month of days.", "నెల", "Nela")
s("insights_viewYear", "Year", "Sky view switch: a whole year of days.", "సంవత్సరం", "Samvatsaram")
s("insights_prevMonth", "Previous month", "Button (icon, screen-reader label) that shows the month before.", "ముందు నెల", "Mundu nela")
s("insights_nextMonth", "Next month", "Button (icon, screen-reader label) that shows the month after.", "తర్వాతి నెల", "Tarvaati nela")
s("insights_prevYear", "Previous year", "Button (icon, screen-reader label) that shows the year before.", "ముందు సంవత్సరం", "Mundu samvatsaram")
s("insights_nextYear", "Next year", "Button (icon, screen-reader label) that shows the year after.", "తర్వాతి సంవత్సరం", "Tarvaati samvatsaram")
s("insights_dayEmpty", "{date}, quiet sky", "Screen-reader label of a day with no check-in. Neutral: an inactive day is plain sky, never 'missed'.", "{date}, ప్రశాంత ఆకాశం", "{date}, quiet sky", STR("date"))
s("insights_dayRest", "{date}, a rest day", "Screen-reader label of a rest day (a faint ring in the sky).", "{date}, విశ్రాంతి రోజు", "{date}, rest day", STR("date"))
s("insights_daySingle", "{date}, {quadrant}, {count, plural, =1{1 check-in} other{{count} check-ins}}", "Screen-reader label of a day whose most frequent quadrant is {quadrant} (Storm, Rain, Moonlight or Sunrise).", "{date}, {quadrant}, {count, plural, =1{1 చెక్-ఇన్} other{{count} చెక్-ఇన్‌లు}}", "{date}, {quadrant}, {count, plural, =1{1 check-in} other{{count} check-ins}}", {"date": {"type": "String"}, "quadrant": {"type": "String"}, "count": {"type": "int"}})
s("insights_dayPair", "{date}, {first} and {second} equally, {count, plural, =1{1 check-in} other{{count} check-ins}}", "Screen-reader label of a mixed day: two quadrants tied (a split star).", "{date}, {first}, {second} సమానంగా, {count, plural, =1{1 చెక్-ఇన్} other{{count} చెక్-ఇన్‌లు}}", "{date}, {first} and {second} samaanamga, {count, plural, =1{1 check-in} other{{count} check-ins}}", {"date": {"type": "String"}, "first": {"type": "String"}, "second": {"type": "String"}, "count": {"type": "int"}})
s("insights_dayMixed", "{date}, an even mix, {count, plural, =1{1 check-in} other{{count} check-ins}}", "Screen-reader label of a mixed day: three or four quadrants tied (a split star).", "{date}, సమానమైన మిశ్రమం, {count, plural, =1{1 చెక్-ఇన్} other{{count} చెక్-ఇన్‌లు}}", "{date}, samaanamaina mix, {count, plural, =1{1 check-in} other{{count} check-ins}}", {"date": {"type": "String"}, "count": {"type": "int"}})
s("insights_dayHint", "Shows this day's check-ins", "Screen-reader hint on a day with check-ins.", "ఈ రోజు చెక్-ఇన్‌లు చూపిస్తుంది", "Ee roju check-ins chupistundi")
s("insights_dayNone", "Nothing was logged this day. The sky was just quiet.", "Day sheet for a day without check-ins. Calm, no blame.", "ఈ రోజు ఏమీ నమోదు కాలేదు. ఆకాశం ప్రశాంతంగా ఉంది.", "Ee roju emi note avvaledu. Sky prashaanthanga undi.")
s("insights_monthSemantic", "{month}, {count, plural, =0{a quiet sky} =1{1 day checked in} other{{count} days checked in}}", "Screen-reader label of one month in the year view; tapping it opens that month.", "{month}, {count, plural, =0{ప్రశాంత ఆకాశం} =1{1 రోజు చెక్-ఇన్} other{{count} రోజులు చెక్-ఇన్}}", "{month}, {count, plural, =0{quiet sky} =1{1 roju check-in} other{{count} rojulu check-in}}", {"month": {"type": "String"}, "count": {"type": "int"}})
s("insights_legendRest", "Rest day", "Sky legend: the faint ring.", "విశ్రాంతి రోజు", "Rest day")
s("insights_legendMixed", "Mixed day", "Sky legend: the split star (quadrants tied that day).", "మిశ్రమ రోజు", "Mixed day")

# ---- patterns ---------------------------------------------------------------
s("insights_patternsTitle", "Patterns", "Section title: plain-language patterns from the person's own check-ins.", "ధోరణులు", "Patterns")
s("insights_patternsLast30", "From your last 30 days", "Under the Patterns title on Free: the window the patterns come from.", "మీ గత 30 రోజుల నుండి", "Mee last 30 rojula nundi")
s("insights_patternsNeedCheckIns", "Patterns appear after 7 check-ins ({count}/7)", "Shown instead of patterns while there are fewer than 7 check-ins in the window (PRD F10, REQ-INS-01: '6/7').", "7 చెక్-ఇన్‌ల తర్వాత ధోరణులు కనిపిస్తాయి ({count}/7)", "7 check-ins tarvaata patterns kanipistaayi ({count}/7)", INT("count"))
s("insights_patternsNeedDays", "Patterns appear after check-ins on 5 different days ({count}/5)", "Shown when there are 7+ check-ins but on fewer than 5 different days (REQ-INS-01 negative).", "5 వేర్వేరు రోజుల్లో చెక్-ఇన్ చేశాక ధోరణులు కనిపిస్తాయి ({count}/5)", "5 veru veru rojullo check-in chesaaka patterns kanipistaayi ({count}/5)", INT("count"))
s("insights_patternsNone", "No clear patterns right now. Your sky is still here.", "Enough check-ins, but nothing passes the thresholds (weak patterns are hidden, not caveated).", "ఇప్పుడు స్పష్టమైన ధోరణులు ఏవీ లేవు. మీ ఆకాశం ఇక్కడే ఉంది.", "Ippudu clear patterns emi levu. Mee sky ikkade undi.")
s("insights_patternTag", "On check-ins with {tag}, {quadrant} showed up more often.", "A pattern: check-ins carrying tag {tag} were {quadrant} more often than others. Descriptive only, never 'because'. {quadrant} = Storm/Rain/Moonlight/Sunrise.", "{tag} ఉన్న చెక్-ఇన్‌లలో {quadrant} ఎక్కువగా కనిపించింది.", "{tag} unna check-ins lo {quadrant} ekkuvaga kanipinchindi.", STR("tag", "quadrant"))
s("insights_patternHabit", "On days you did {habit}, {quadrant} showed up more often.", "A pattern (Aura Plus): on days the habit was done, check-ins were {quadrant} more often. Descriptive only, never causal.", "మీరు {habit} చేసిన రోజుల్లో {quadrant} ఎక్కువగా కనిపించింది.", "Meeru {habit} chesina rojullo {quadrant} ekkuvaga kanipinchindi.", STR("habit", "quadrant"))
s("insights_patternMorning", "In the mornings, {quadrant} showed up more often.", "A pattern: morning check-ins (04:00–12:00) were {quadrant} more often than the rest of the day.", "ఉదయాల్లో {quadrant} ఎక్కువగా కనిపించింది.", "Morning lo {quadrant} ekkuvaga kanipinchindi.", STR("quadrant"))
s("insights_patternAfternoon", "In the afternoons, {quadrant} showed up more often.", "A pattern: afternoon check-ins (12:00–17:00) were {quadrant} more often.", "మధ్యాహ్నాల్లో {quadrant} ఎక్కువగా కనిపించింది.", "Madhyaahnam lo {quadrant} ekkuvaga kanipinchindi.", STR("quadrant"))
s("insights_patternEvening", "In the evenings, {quadrant} showed up more often.", "A pattern: evening check-ins (17:00–21:00) were {quadrant} more often.", "సాయంత్రాల్లో {quadrant} ఎక్కువగా కనిపించింది.", "Evening lo {quadrant} ekkuvaga kanipinchindi.", STR("quadrant"))
s("insights_patternNight", "At night, {quadrant} showed up more often.", "A pattern: late check-ins (21:00–04:00) were {quadrant} more often.", "రాత్రుల్లో {quadrant} ఎక్కువగా కనిపించింది.", "Raatri {quadrant} ekkuvaga kanipinchindi.", STR("quadrant"))
s("insights_patternMix", "{quadrant} showed up most often in your sky.", "A pattern: the most frequent quadrant in the window. Same warmth for every quadrant.", "మీ ఆకాశంలో {quadrant} అన్నిటికంటే ఎక్కువగా కనిపించింది.", "Mee sky lo {quadrant} anni kante ekkuvaga kanipinchindi.", STR("quadrant"))

# ---- Plus depth (F12 gate; locked with calm copy) ------------------------------
s("insights_plusBadge", "Aura Plus", "Small label on an Insights extra that comes with Aura Plus (brand name).", "Aura Plus", "Aura Plus")
s("insights_rangeLocked", "Any range and habits alongside moods come with Aura Plus. Your sky and 30-day patterns are always free.", "Locked note under the patterns on Free (PRD F10: Plus gates depth only; REQ-INS-05). Calm, no pressure.", "ఏ కాల పరిధి అయినా, మూడ్‌లతో పాటు అలవాట్లు Aura Plus‌తో వస్తాయి. మీ ఆకాశం, 30 రోజుల ధోరణులు ఎప్పుడూ ఉచితమే.", "Any range, moods tho paatu habits Aura Plus tho vastaayi. Mee sky, 30 rojula patterns eppudu free.")
s("insights_rangeLabel", "Patterns from", "Screen-reader label of the range picker (Aura Plus).", "ఈ కాలం నుండి ధోరణులు", "Ee kaalam nundi patterns")
s("insights_range7", "7 days", "Range choice (Aura Plus).", "7 రోజులు", "7 rojulu")
s("insights_range30", "30 days", "Range choice.", "30 రోజులు", "30 rojulu")
s("insights_range90", "90 days", "Range choice (Aura Plus).", "90 రోజులు", "90 rojulu")
s("insights_range365", "1 year", "Range choice (Aura Plus).", "1 సంవత్సరం", "1 samvatsaram")
s("insights_rangeAll", "All time", "Range choice (Aura Plus).", "మొత్తం", "Mottham")

# ---- weekly insight card (Milestone B) -------------------------------------------
s("insights_weeklyTitle", "From your past week", "Weekly insight card title, shown on the first Aura day of the week in Insights only (never pushed). The body is one pattern sentence.", "మీ గత వారం నుండి", "Mee last week nundi")
s("insights_weeklyHide", "Hide for this week", "Hides the weekly card until next week.", "ఈ వారానికి దాచండి", "Ee vaaraaniki daachandi")

# ---- care card (PRD F10 `[ASSUMPTION]`) --------------------------------------------
s("insights_careTitle", "It's been a heavy couple of weeks", "Care card when most recent check-ins were Storm or Rain (PRD F10 literal). Shown in Insights only, never pushed. Warm, never diagnostic.", "గత రెండు వారాలు భారంగా గడిచాయి", "Last rendu vaaraalu bhaaranga gadichaayi")
s("insights_careBody", "You don't have to carry it alone. Support and a room are here whenever you want them.", "Care card body. No pressure, no labels.", "దీన్ని మీరు ఒంటరిగా మోయాల్సిన అవసరం లేదు. మీకు ఎప్పుడు కావాలంటే అప్పుడు సహాయం, ఒక రూమ్ ఇక్కడే ఉన్నాయి.", "Idi meeru okkare moyyalsina avasaram ledu. Meeku eppudu kaavaalante appudu support, oka room ikkade unnaayi.")
s("insights_careSupport", "See support", "Care card button: opens the support sheet (helplines, grounding).", "సహాయం చూడండి", "Support chudandi")
s("insights_careRoom", "Find a room", "Care card button: opens Rooms.", "ఒక రూమ్ వెతకండి", "Oka room vetakandi")

# ---- Your month in stars (Milestone B) ----------------------------------------------
s("insights_monthTitle", "Your month in stars", "Title of the monthly recap, shown from the first Aura day of each month (PRD F10).", "నక్షత్రాల్లో మీ నెల", "Stars lo mee nela")
s("insights_monthCardBody", "{month} in your sky", "Monthly recap card body; month = e.g. 'October 2026'.", "మీ ఆకాశంలో {month}", "Mee sky lo {month}", STR("month"))
s("insights_monthOpen", "Open", "Opens the monthly recap.", "తెరవండి", "Open cheyandi")
s("insights_monthHide", "Hide", "Hides the monthly recap card until next month.", "దాచండి", "Daachandi")
s("insights_monthDays", "{count, plural, =1{1 day checked in} other{{count} days checked in}}", "Recap: distinct days with a check-in in that month.", "{count, plural, =1{1 రోజు చెక్-ఇన్ చేశారు} other{{count} రోజులు చెక్-ఇన్ చేశారు}}", "{count, plural, =1{1 roju check-in chesaaru} other{{count} rojulu check-in chesaaru}}", INT("count"))
s("insights_monthMixTitle", "Your skies this month", "Recap: heading of the quadrant mix drawn as a sky.", "ఈ నెల మీ ఆకాశాలు", "Ee nela mee skies")
s("insights_monthMixItem", "{quadrant}: {count, plural, =1{1 check-in} other{{count} check-ins}}", "Recap legend row (glyph + name + count), also read by screen readers.", "{quadrant}: {count, plural, =1{1 చెక్-ఇన్} other{{count} చెక్-ఇన్‌లు}}", "{quadrant}: {count, plural, =1{1 check-in} other{{count} check-ins}}", {"quadrant": {"type": "String"}, "count": {"type": "int"}})
s("insights_monthSkySemantic", "A sky of {count, plural, =1{1 star} other{{count} stars}}, one for each check-in in {month}", "Screen-reader label of the recap's drawn sky.", "{month}లో ఒక్కో చెక్-ఇన్‌కి ఒక్కో నక్షత్రం, మొత్తం {count, plural, =1{1 నక్షత్రం} other{{count} నక్షత్రాలు}}", "{month} lo prati check-in ki oka star, mottham {count, plural, =1{1 star} other{{count} stars}}", {"count": {"type": "int"}, "month": {"type": "String"}})
s("insights_deeperTitle", "Deeper monthly review", "Section of the recap with patterns across the month and habit × mood (Aura Plus).", "లోతైన నెలవారీ సమీక్ష", "Deeper monthly review")
s("insights_deeperLocked", "Patterns across the month, with habits alongside moods, come with Aura Plus.", "Locked note on Free (PRD 14-states: blurred deeper chart, basic sky stays free).", "నెల మొత్తంలోని ధోరణులు, మూడ్‌లతో పాటు అలవాట్లు Aura Plus‌తో వస్తాయి.", "Nela mottham patterns, moods tho paatu habits Aura Plus tho vastaayi.")
s("insights_deeperNone", "No clear patterns this month.", "Plus recap: nothing passed the thresholds for that month.", "ఈ నెల స్పష్టమైన ధోరణులు ఏవీ లేవు.", "Ee nela clear patterns emi levu.")

# ---- lifetime ---------------------------------------------------------------------
s("insights_statsTitle", "All time", "Section title: lifetime stats (free).", "ఇప్పటివరకు", "Ippativaraku")
s("insights_statsCheckIns", "{count, plural, =1{1 check-in} other{{count} check-ins}}", "Lifetime stat: check-ins (not deleted).", "{count, plural, =1{1 చెక్-ఇన్} other{{count} చెక్-ఇన్‌లు}}", "{count, plural, =1{1 check-in} other{{count} check-ins}}", INT("count"))
s("insights_statsDays", "{count, plural, =1{1 day in your sky} other{{count} days in your sky}}", "Lifetime stat: distinct days with a check-in.", "{count, plural, =1{మీ ఆకాశంలో 1 రోజు} other{మీ ఆకాశంలో {count} రోజులు}}", "{count, plural, =1{Mee sky lo 1 roju} other{Mee sky lo {count} rojulu}}", INT("count"))
