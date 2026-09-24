# Helpline names, the "rooms are open" notice and people-facing emails — Telugu and Tenglish for native review

**Status: DRAFTS, NEED NATIVE REVIEW before alpha.** Written by the dev team from the English originals, in the respectful *meeru* form. Nothing here changes meaning on review without the owner's sign-off; the English is the reviewed original. Hindi and Hinglish ship from beta: until then these surfaces fall back to English.

Where each string lives (edit there, not here — this page is the review copy):

| Surface | Source of truth | Regenerate |
|---|---|---|
| Helpline names | `contracts/safety/helplines.v1.json` (`names`) | `cd apps/mobile && python3 tool/gen_helplines.py` (bundled copy); a signed version from the console for phones already out |
| "Rooms are open" push | `server/aura-api/src/notifications/push-copy.ts` (`rooms_pool_open`) | — (server-rendered) |
| In-app notice + Android channel | `apps/mobile/tool/l10n/gaps.py` | `bash apps/mobile/tool/gen.sh l10n` |
| Grievance acknowledgement, deletion link | `server/aura-api/src/admin/mail/copy.ts` | — |

Review checklist: meaning matches the English; *meeru* form throughout; no word that reads as blame, urgency or pressure (the copy lint also bans them: miss / lose / streak / hurry and their te / te-Latn forms); Tenglish spelled the way people type it in chat (house style: long vowels doubled, as in the mood names); product names (Aura, Tele-MANAS, Childline, Lantern Hour, Suicide & Crisis Lifeline) stay in English.

## 1. Helpline names (crisis sheet, Safety Center, under-13 screen)

Numbers are not translated. Lines without a name in a locale show the English one.

| id | English | Telugu (`te`) | Tenglish (`te-Latn`) |
|---|---|---|---|
| `in.tele_manas` | Tele-MANAS · free, 24×7 | Tele-MANAS · ఉచితం, 24×7 | Tele-MANAS · free, 24×7 |
| `in.tele_manas_toll_free` | Tele-MANAS toll-free | Tele-MANAS టోల్-ఫ్రీ | Tele-MANAS toll-free |
| `in.childline` | Childline · for under-18s | Childline · 18 ఏళ్ల లోపు వారికి | Childline · 18 ella lopu vaallaki |
| `in.emergency` | Emergency | అత్యవసరం | Emergency |
| `us.988` | Suicide & Crisis Lifeline · call or text | Suicide & Crisis Lifeline · కాల్ లేదా మెసేజ్ | Suicide & Crisis Lifeline · call leda text |

Open: Childline 1098 is `[ASSUMPTION: confirm operational]` in PRD 06c F9. Every number: re-verify quarterly (PRD 18).

## 2. "Tell me when they open" (Hindi + Hinglish rooms)

| Key | English | Telugu | Tenglish |
|---|---|---|---|
| push `rooms_pool_open` / `notif_roomsPoolBanner` | Hindi and Hinglish rooms are open now. | హిందీ, హింగ్లిష్ రూమ్‌లు ఇప్పుడు మొదలయ్యాయి. | Hindi, Hinglish rooms ippudu modalayyaayi. |
| `notif_roomsPoolAction` | See rooms | రూమ్‌లు చూడండి | Rooms chudandi |
| `notif_channelRooms` (Android settings) | Rooms & Lantern Hour | రూమ్‌లు & Lantern Hour | Rooms & Lantern Hour |
| `notif_channelRoomsDescription` | When rooms you asked about open. | మీరు అడిగిన రూమ్‌లు మొదలైనప్పుడు. | Meeru adigina rooms modalainappudu. |

The people who get this push are mostly Hindi / Hinglish readers, who see English until the beta translations land. Proposed Hinglish for the beta pass (not shipped): "Hindi aur Hinglish rooms ab khul gaye hain." — needs a Hindi reviewer.

## 3. Grievance acknowledgement email

Sent right after a grievance is received, in the app language of the Aura account that signs in with the complainant's address, else the language the form was in, else English. `{…}` are filled in; dates are IST (Telugu month names in `te`, English formats in `te-Latn`).

| Line | English | Telugu | Tenglish |
|---|---|---|---|
| Subject | Aura: we received your grievance {ticket} | Aura: మీ ఫిర్యాదు {ticket} మాకు అందింది | Aura: mee grievance {ticket} maaku andindi |
| Greeting | Hello, / Hello {name}, | నమస్కారం, / నమస్కారం {name} గారు, | Namaskaram, / Namaskaram {name} garu, |
| Intro | Thank you for writing to Aura's Grievance Officer. This email acknowledges your grievance. | Aura గ్రీవెన్స్ ఆఫీసర్‌కు రాసినందుకు ధన్యవాదాలు. మీ ఫిర్యాదు మాకు అందిందని ఈ ఈమెయిల్ నిర్ధారిస్తోంది. | Aura Grievance Officer ki raasinanduku dhanyavaadaalu. Mee grievance maaku andindani ee email confirm chestondi. |
| Labels | Ticket · Received · Category | టికెట్ · అందిన సమయం · విభాగం | Ticket · Andina samayam · Category |
| Deadline | We will resolve it by: {when} ({window} of receipt) | పరిష్కరించే గడువు: {when} (అందినప్పటి నుండి {window}) | Parishkarinche gaduvu: {when} (andinappati nundi {window}) |
| Window | within {n} days / within {n} hours | {n} రోజుల్లోపు / {n} గంటల్లోపు | {n} rojullo / {n} gantallo |
| Quote the ticket | Please quote your ticket number if you write to us again. You can reply to this email. | మాకు మళ్ళీ రాసేటప్పుడు దయచేసి మీ టికెట్ నంబర్‌ను పేర్కొనండి. ఈ ఈమెయిల్‌కు మీరు జవాబు ఇవ్వవచ్చు. | Maaku malli raasetappudu dayachesi mee ticket number mention cheyandi. Ee email ki reply ivvochu. |
| Officer | Grievance Officer: {contact} | గ్రీవెన్స్ ఆఫీసర్: {contact} | Grievance Officer: {contact} |
| Publisher | Aura is published by AKVega. | Aura ను AKVega ప్రచురిస్తోంది. | Aura ni AKVega publish chestondi. |
| Safety line | If someone is in immediate danger, call your local emergency number (India: 112). | ఎవరైనా తక్షణ ప్రమాదంలో ఉంటే, మీ స్థానిక అత్యవసర నంబర్‌కు కాల్ చేయండి (భారతదేశం: 112). | Evaraina ventane pramaadam lo unte, mee local emergency number ki call cheyandi (India: 112). |

Categories:

| Code | English | Telugu | Tenglish |
|---|---|---|---|
| `general` | Complaint about content or conduct | కంటెంట్ లేదా ప్రవర్తనపై ఫిర్యాదు | Content leda pravartana meeda complaint |
| `unlawful_content` | Unlawful content | చట్టవిరుద్ధమైన కంటెంట్ | Chattaviruddhamaina content |
| `nudity_csam` | Nudity, sexual content or child sexual abuse material | నగ్నత్వం, లైంగిక కంటెంట్ లేదా పిల్లలపై లైంగిక వేధింపుల కంటెంట్ | Nagnatvam, sexual content leda pillala meeda sexual abuse content |
| `ncii` | Intimate images shared without consent | అనుమతి లేకుండా పంచుకున్న వ్యక్తిగత చిత్రాలు | Anumati lekunda share chesina private photos |
| `data_request` | My data or my account | నా డేటా లేదా నా ఖాతా | Naa data leda naa account |
| `moderation_appeal` | Appeal a moderation decision | మోడరేషన్ నిర్ణయంపై అప్పీల్ | Moderation nirnayam meeda appeal |

Legal note for the reviewer: these category names are shown to the complainant only; the console and the audit log keep the English codes. The decision reply (with the Grievance Appellate Committee appeal text) stays English for now.

## 4. Deletion link email (emailed / grievance deletion requests)

Sent to the address on the account, in the account's app language. The only link is the one-time token link (no personal data in it). The confirmation page's buttons are English ("Delete my account", "This wasn't me"), so every language names them in English.

| Line | English | Telugu | Tenglish |
|---|---|---|---|
| Subject | Aura: confirm the request to delete your account ({ticket}) | Aura: మీ ఖాతా తొలగింపు అభ్యర్థనను నిర్ధారించండి ({ticket}) | Aura: mee account delete request ni confirm cheyandi ({ticket}) |
| Intro | Aura's Grievance Officer received a request to delete the Aura account that signs in with this email address (request {ticket}). | ఈ ఈమెయిల్ చిరునామాతో సైన్ ఇన్ అయ్యే Aura ఖాతాను తొలగించమని Aura గ్రీవెన్స్ ఆఫీసర్‌కు ఒక అభ్యర్థన అందింది (అభ్యర్థన {ticket}). | Ee email address tho sign in ayye Aura account ni delete cheyyamani Aura Grievance Officer ki oka request vachindi (request {ticket}). |
| If you did | If you made this request, open the link below and press "Delete my account": | ఈ అభ్యర్థన మీరే చేసి ఉంటే, కింది లింక్ తెరిచి "Delete my account" నొక్కండి: | Ee request meere chesi unte, kindi link open chesi "Delete my account" nokkandi: |
| Expiry | The link works once, until {until}. | ఈ లింక్ ఒక్కసారి మాత్రమే, {until} వరకు పనిచేస్తుంది. | Ee link okkasaari maatrame, {until} varaku pani chestundi. |
| If not | If you did not ask for this, you don't need to do anything: nothing is deleted without your confirmation. You can also open the link and press "This wasn't me". | ఇది మీరు అడగకపోతే, మీరు ఏమీ చేయనవసరం లేదు: మీ నిర్ధారణ లేకుండా ఏదీ తొలగించబడదు. లింక్ తెరిచి "This wasn't me" కూడా నొక్కవచ్చు. | Idi meeru adagakapothe, meeru emi cheyyanakkarledu: mee confirmation lekunda edi delete avvadu. Link open chesi "This wasn't me" kooda nokkavachu. |
| What next | What happens next: once you confirm, Aura starts the same deletion as the in-app option. The account is switched off straight away and deleted for good within 30 days (normally after {grace} days, during which signing in to the app lets you keep it). Records the law requires us to keep (for example about reported content) are kept only as long as required. | తర్వాత ఏమవుతుంది: మీరు నిర్ధారించగానే, యాప్‌లోని తొలగింపు ఎంపిక లాగానే Aura తొలగింపును మొదలుపెడుతుంది. ఖాతా వెంటనే ఆగిపోతుంది, 30 రోజుల్లోపు శాశ్వతంగా తొలగించబడుతుంది (సాధారణంగా {grace} రోజుల తర్వాత; ఆ లోపు యాప్‌లో సైన్ ఇన్ చేస్తే ఖాతాను ఉంచుకోవచ్చు). చట్టం ప్రకారం మేము ఉంచాల్సిన రికార్డులు (ఉదాహరణకు రిపోర్ట్ చేసిన కంటెంట్ గురించి) అవసరమైనంత కాలం మాత్రమే ఉంచుతాం. | Tarvatha emi jarugutundi: meeru confirm cheyagaane, app lo unna delete option laage Aura deletion start chestundi. Account ventane off avutundi, 30 rojullo purtiga delete avutundi (maamulugaa {grace} rojula tarvatha; aa lopu app lo sign in chesthe account ni unchukovachu). Chattam prakaaram memu unchaalsina records (udaharanaki report chesina content gurinchi) avasaram ainanta kaalam maatrame unchutaam. |

Plus the officer, publisher and safety lines from §3.
