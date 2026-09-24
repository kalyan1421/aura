# Milestone A gaps: "Tell me when they open" (Hindi + Hinglish rooms) — the
# in-app notice when its push arrives while Aura is open, and the Android
# "Rooms & Lantern Hour" channel it is posted to (PRD 15-permissions). Loaded
# by tool/l10n_source.py.
# s(key, en, desc, te, te_Latn, ph=None) · edit(key, en=, te=, tl=, desc=)
# te / te_Latn are first drafts: NEEDS NATIVE REVIEW before alpha.
#
# REQ-NTF-01: `notif_` keys are checked by the server's copy lint
# (server/aura-api `pnpm lint:copy`).

s("notif_roomsPoolBanner", "Hindi and Hinglish rooms are open now.", "In-app notice when the 'rooms are open' push arrives while the app is open (the same line as the push; the person tapped 'Tell me when they open'). Never a mood or a room name.", "హిందీ, హింగ్లిష్ రూమ్‌లు ఇప్పుడు మొదలయ్యాయి.", "Hindi, Hinglish rooms ippudu modalayyaayi.")
s("notif_roomsPoolAction", "See rooms", "Action on the 'rooms are open' notice: opens Rooms.", "రూమ్‌లు చూడండి", "Rooms chudandi")
s("notif_channelRooms", "Rooms & Lantern Hour", "Android notification channel name for room notices (phone Settings; PRD 15-permissions).", "రూమ్‌లు & Lantern Hour", "Rooms & Lantern Hour")
s("notif_channelRoomsDescription", "When rooms you asked about open.", "Android notification channel description (phone Settings).", "మీరు అడిగిన రూమ్‌లు మొదలైనప్పుడు.", "Meeru adigina rooms modalainappudu.")
