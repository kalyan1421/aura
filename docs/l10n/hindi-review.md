# Hindi (`hi`) and Hinglish (`hi-Latn`) — native review list

> **Release gate:** Hindi and Hinglish are hidden from testers (`AURA_BETA_LOCALES` defaults to false) until the crisis
> lexicon (`contracts/safety/crisis_lexicon.v1.json`) has reviewed `hi` / `hi-Latn` terms. Today it has none, so text
> written in Hindi or Hinglish never opens the crisis sheet. Review builds can turn them on with
> `--dart-define=AURA_BETA_LOCALES=true`.

**Status: EVERY STRING BELOW IS A DRAFT. NOT NATIVE-REVIEWED.** Written by the dev team for Milestone B (beta) from the
English originals. The English is the reviewed original; a reviewer changes the Hindi / Hinglish, never the meaning,
without the owner's sign-off. PRD 18 asks for Hindi to be tested with ≥ 10 native speakers before beta, and crisis copy
to be self-reviewed against the WHO / AFSP / Samaritans safe-messaging guidelines (06c F9). Neither has happened yet.

This page is the **review copy**. It was generated from the shipped files on 24 Sep 2026. To change a string, edit its
source (below) and regenerate. Don't edit it here.

| Surface | Source of truth | Regenerate |
|---|---|---|
| App UI (1,191 keys × 2) | `apps/mobile/tool/l10n_source.py` + `apps/mobile/tool/l10n/*.py`: each `s(...)` line carries `hi=` (Devanagari) and `hl=` (Hinglish) after the Tenglish | `bash apps/mobile/tool/gen.sh l10n` |
| Push notifications | `server/aura-api/src/notifications/push-copy.ts` (`hi`, `'hi-Latn'`) | — (server-rendered) |
| Grievance and deletion emails | `server/aura-api/src/admin/mail/copy.ts` (`hi`, `'hi-Latn'`) | — |
| Helpline names | `contracts/safety/helplines.v1.json` (`names.hi`, `names["hi-Latn"]`) | `cd apps/mobile && python3 tool/gen_helplines.py`, then re-sign the dev fixture (contracts/safety/README.md "A") |
| Mood names | `contracts/moods.json` (not changed here; see `docs/l10n/hinglish-mood-names.md`) | `packages/aura_domain/tool/gen_catalog.dart` |

## Review checklist

1. **Meaning matches the English.** Nothing is added or dropped: no claims, no promises, no urgency.
2. **Respectful *aap* throughout.** Imperatives are hi *करें / देखें* and Hinglish *karein / dekhein*. Never *तुम / tu*.
3. **No gendered forms (PRD 18).** Aura never knows the user's gender, but Hindi verbs agree with it. The drafts avoid
   *करोगे/करोगी*, *थके/थकी*, *आए/आईं* and *सकते/सकती* whenever the subject is the reader, a stranger or "I". They use:
   - imperatives
   - "… का मन है?"
   - "… मुमकिन है"
   - passives that agree with a thing ("बदला जा सकता है")
   - ergative forms ("आपने अपना साथ दिया")
   - nouns
   Please flag anything that still reads as gendered, and anything the rephrasing made stiff. Intentions and other
   first-person lines are infinitives or nouns, e.g. "आज रात ख़ुद से नरमी".
4. **Everyday register.** Hindi should be spoken *Hindustani* a 20-year-old uses, not Sanskritised or official Hindi.
   Hinglish should be spelled the way people type in chat. House style for Hinglish:
   - aap, hai / hain, nahi, mein, yahan, abhi, phir se, thoda, zaroor
   - no diacritics
   - English words kept where they are the common word (check-in, room, habit, settings, free trial)
5. **Not clinical, not treatment** (06d "calm, not treatment").
   - Never इलाज, थेरेपी, चिकित्सा, "better sleep", तनाव कम.
   - No word that makes a feeling a diagnosis.
   - Moods are passing feelings, not identities.
6. **Brand terms stay in Latin script** everywhere: Aura, Aura Plus, Aura Sky, Starlight, Stardust, Lantern Hour,
   Breath Ripples, Tele-MANAS, Childline.
7. **Linted areas.** A reviewer's change must still pass these. The tests fail the build otherwise.
   - **Notifications** (`notif_*`, the capsule notice, every push): no mood, quadrant or room-theme name in any
     language. No guilt, loss or urgency (मिस, खो…, टूट, जल्दी, छूट गया, jaldi, streak…).
     Devanagari stems match *inside* words, so शांति is out: it contains the mood name शांत.
   - **Insights**: no causal words (क्योंकि, वजह, कारण, इसलिए, kyunki, wajah…). No better / worse (बेहतर, बदतर).
     No digits in pattern sentences, and `{quadrant}` is never written out.
   - **Sounds**: no sleep, stress, worry or treatment words (नींद, तनाव, चिंता, इलाज, neend, tanaav…). No "!".
8. **Placeholders** (`{count}`, `{date}`, `{quadrant}`…) stay exactly as written. They may move for Hindi word order.
   Plural forms keep their `=0` / `=1` / `other` branches.

## Glossary the drafts use (check these first; changing one means changing it everywhere)

| English | Hindi | Hinglish | Note |
|---|---|---|---|
| check-in | चेक-इन | check-in | |
| Home / Sanctuary / Rooms / Insights (tabs) | होम / सुकून / रूम / समझ | Home / Sanctuary / Rooms / Insights | Telugu translates Sanctuary and Insights; Tenglish keeps English |
| Future you (capsules) | भविष्य के आप | Future you | "past you" = बीते समय के आप / Past you |
| Reflections | दिल की बातें | Reflections | Hinglish treats "reflection" as feminine |
| gesture / warmth | भाव / अपनापन | gesture / warmth | |
| habit / rest day | आदत / आराम का दिन | habit / rest day | Settings › Comfort = सहूलियत to avoid a clash with आराम |
| glow / glow days | चमक / चमक वाले दिन | glow / glow days | stage "Glow" = चमक; "Glow streak" = चमक का सिलसिला |
| Sounds / wind-down | आवाज़ें / सोने से पहले का सुकून | Sounds / wind-down | inside `sounds_*` the wind-down is रात का सुकून (no sleep word in Sounds) |
| intention (tonight's) | इरादा | irada | |
| lantern | लालटेन | lantern | alt. कंदील |
| sky (Insights) | आसमान | aasmaan | "Aura Sky" stays English |
| pseudonym | उपनाम | upnaam | |
| Grievance Officer | शिकायत अधिकारी | Grievance Officer | the IT Rules term |
| quadrants | तूफ़ान, बारिश, चाँदनी, सूर्योदय | Storm, Rain, Moonlight, Sunrise | PRD 18: theme words stay English in Hinglish |
| room themes | प्रकाश स्तंभ, बारिश का ठिकाना, आधी रात की वेधशाला, सूर्योदय की छत | The Lighthouse, … (English) | |
| gestures | एक कप चाय, एक दीया, झप्पी, मैं भी, हल्की फुहार, तारे देखें, गहरी साँस, कोई साथ है | Ek cup chai, Ek diya, Jhappi, Main bhi, Halki phuhaar, Taare dekhein, Gehri saans, Koi saath hai | "You're Not Alone" = "someone is with you" (अकेले/अकेली would be gendered) |

## ⚠ Safety gap to raise before Hindi ships: the crisis lexicon has no Hindi or Hinglish terms

`contracts/safety/crisis_lexicon.v1.json` declares `hi` and `hi-Latn` with `"status": "placeholder"`. It has **zero
entries** for either: the crisis and soft lists are English (8 + 3), Telugu (5 + 2) and Tenglish (5 + 2) only. PRD 06c
F9 requires L1 on-device detection in all five languages, including romanised forms. Its own examples are "marna
chahti" (crisis) and "mar gaye yaar" (soft idiom). PRD 18 adds the spelling drift *marna / marnaa / mrna* and digit
swaps like *m4rna*.

With the Hindi UI on, a note, reflection or capsule written in Hindi or Hinglish opens the crisis sheet only if it
also contains an English, Telugu or Tenglish term.

This work did **not** touch the lexicon: it is safety-reviewed and signed. Needed, in the lexicon's own process
(console → signed bundle):
- Hindi and Hinglish crisis terms (wanting to die, ending one's life, suicide, self-harm, "can't go on"), each with
  spelling variants.
- Soft idioms: "mar gaye yaar", "hanste hanste mar gaya", "bore ho ke mar gaya".
- A native speaker's review of all of them.

The reflection filter (`reflection_filter.v1.json`) already has hi / hi-Latn contact and grooming phrases, so those
are covered.

## Push notifications (server, `push-copy.ts`)

Every line that has an in-app twin is identical to it. `test/unit/notifications.copy.spec.ts` checks this.

| Key | English | Hindi (`hi`) | Hinglish (`hi-Latn`) |
|---|---|---|---|
| `daily_reminder` | A quiet minute for you. How's today feeling? | आपके लिए सुकून का एक मिनट। आज कैसा लग रहा है? | Aapke liye sukoon ka ek minute. Aaj kaisa lag raha hai? |
| `capsule_unlocked` | Something you sealed is ready to open. | आपने जो सील किया था, वह अब खुल सकता है। | Aapne jo seal kiya tha, woh ab khul sakta hai. |
| `rooms_pool_open` | Hindi and Hinglish rooms are open now. | हिंदी और हिंग्लिश रूम अब खुल गए हैं। | Hindi aur Hinglish rooms ab khul gaye hain. |
| `gestures_received` | {count} people in your room sent you warmth. | आपके रूम में {count} लोगों ने आपको अपनापन भेजा। | Aapke room mein {count} logon ne aapko warmth bheji. |
| `gestures_received_one` | Someone in your room sent you warmth. | आपके रूम में किसी ने आपको अपनापन भेजा। | Aapke room mein kisi ne aapko warmth bheji. |
| `lantern_hour` | Lantern Hour is on. Others are here tonight. | Lantern Hour शुरू हो गया है। आज रात और लोग भी यहाँ हैं। | Lantern Hour shuru ho gaya hai. Aaj raat aur log bhi yahan hain. |
| `wind_down_reminder` | A few quiet minutes before sleep, whenever you want them. | सोने से पहले सुकून के कुछ पल, जब भी मन हो। | Sone se pehle sukoon ke kuch pal, jab bhi mann ho. |
| `habit_nudge` | A small habit or two, whenever you're ready. | एक-दो छोटी आदतें, जब भी आप तैयार हों। | Ek-do chhoti habits, jab bhi aap taiyaar hon. |
| `habit_nudge_hydrate` | Small one: a glass of water? | छोटी-सी बात: एक गिलास पानी? | Chhoti si baat: ek glass paani? |
| `habit_nudge_breathe` | Small one: a few slow breaths? | छोटी-सी बात: कुछ धीमी साँसें? | Chhoti si baat: kuch dheemi saansein? |
| `habit_nudge_move` | Small one: a little stretch? | छोटी-सी बात: थोड़ा-सा स्ट्रेच? | Chhoti si baat: thoda sa stretch? |
| `habit_nudge_journal` | Small one: a line or two for yourself? | छोटी-सी बात: अपने लिए एक-दो लाइनें? | Chhoti si baat: apne liye ek-do lines? |
| `habit_nudge_go_outside` | Small one: a minute of fresh air? | छोटी-सी बात: एक मिनट ताज़ी हवा? | Chhoti si baat: ek minute taazi hawa? |
| `habit_nudge_sleep_on_time` | Small one: starting to wind down for bed? | छोटी-सी बात: सोने की तैयारी शुरू करें? | Chhoti si baat: sone ki taiyaari shuru karein? |
| `welcome_back` | No catch-up needed. Aura is here whenever you want a quiet minute. | पिछला कुछ भी पूरा करने की ज़रूरत नहीं। जब भी सुकून का एक मिनट चाहिए, Aura यहीं है। | Kuch bhi catch-up karne ki zaroorat nahi. Jab bhi sukoon ka ek minute chahiye, Aura yahin hai. |
| `trial_ending` | Your free month of Aura Plus ends on {date}. After that it's {price}/month. Keep it or cancel anytime. | Aura Plus का आपका मुफ़्त महीना {date} को पूरा होगा। उसके बाद {price}/महीना। इसे जारी रखें या कभी भी रद्द करें। | Aapka Aura Plus free month {date} ko poora hoga. Uske baad {price}/month. Ise continue karein ya kabhi bhi cancel karein. |
| `trial_ending_year` | Your free month of Aura Plus ends on {date}. After that it's {price}/year. Keep it or cancel anytime. | Aura Plus का आपका मुफ़्त महीना {date} को पूरा होगा। उसके बाद {price}/साल। इसे जारी रखें या कभी भी रद्द करें। | Aapka Aura Plus free month {date} ko poora hoga. Uske baad {price}/year. Ise continue karein ya kabhi bhi cancel karein. |
| `trial_ending_no_price` | Your free month of Aura Plus ends on {date}. Keep it or cancel anytime in the store. | Aura Plus का आपका मुफ़्त महीना {date} को पूरा होगा। इसे जारी रखें या स्टोर में कभी भी रद्द करें। | Aapka Aura Plus free month {date} ko poora hoga. Ise continue karein ya store mein kabhi bhi cancel karein. |
| `discreet` | You have a gentle update | आपके लिए एक हल्का-सा अपडेट है | Aapke liye ek gentle update hai |

## Emails (server, `admin/mail/copy.ts`)

Sent in the account's app language, then the language the grievance form was in, then English. Dates are IST:
Devanagari month names in `hi`, English formats in `hi-Latn`. The confirmation page's buttons are English, so every
language quotes them in English ("Delete my account", "This wasn't me").

| Line | Hindi | Hinglish |
|---|---|---|
| Greeting | नमस्ते, / नमस्ते {name} जी, | Namaste, / Namaste {name} ji, |
| Window | {n} दिनों के भीतर / {n} घंटों के भीतर | {n} dinon ke andar / {n} ghanton ke andar |
| Officer | शिकायत अधिकारी (Grievance Officer): {contact} | Grievance Officer: {contact} |
| Publisher | Aura को AKVega प्रकाशित करता है। | Aura ko AKVega publish karta hai. |
| Safety line | अगर कोई तुरंत ख़तरे में है, तो अपने स्थानीय इमरजेंसी नंबर पर कॉल करें (भारत: 112)। | Agar koi turant khatre mein hai, to apne local emergency number par call karein (India: 112). |
| Ack subject | Aura: आपकी शिकायत {ticket} हमें मिल गई है | Aura: aapki grievance {ticket} humein mil gayi hai |
| Ack intro | Aura के शिकायत अधिकारी को लिखने के लिए धन्यवाद। यह ईमेल इस बात की पुष्टि है कि आपकी शिकायत हमें मिल गई है। | Aura ke Grievance Officer ko likhne ke liye shukriya. Yeh email confirm karta hai ki aapki grievance humein mil gayi hai. |
| Labels | टिकट · मिलने का समय · श्रेणी | Ticket · Milne ka samay · Category |
| Deadline | समाधान की समय-सीमा: {when} (मिलने के {window}) | Samadhan ki deadline: {when} (milne ke {window}) |
| Quote the ticket | हमें दोबारा लिखते समय कृपया अपना टिकट नंबर बताएँ। इस ईमेल का जवाब भी दिया जा सकता है। | Humein dobara likhte waqt please apna ticket number batayein. Is email ka reply bhi kiya ja sakta hai. |
| Category `general` | कंटेंट या व्यवहार के बारे में शिकायत | Content ya vyavhaar ke baare mein complaint |
| `unlawful_content` | ग़ैर-क़ानूनी कंटेंट | Gair-kaanooni content |
| `nudity_csam` | नग्नता, यौन कंटेंट या बच्चों के यौन शोषण से जुड़ी सामग्री | Nudity, sexual content ya bachchon ke yaun shoshan se juda content |
| `ncii` | बिना सहमति के शेयर की गई निजी तस्वीरें | Bina consent ke share ki gayi private photos |
| `data_request` | मेरा डेटा या मेरा अकाउंट | Mera data ya mera account |
| `moderation_appeal` | मॉडरेशन के फ़ैसले के ख़िलाफ़ अपील | Moderation ke faisle ke khilaaf appeal |
| Deletion subject | Aura: अपना अकाउंट डिलीट करने के अनुरोध की पुष्टि करें ({ticket}) | Aura: apna account delete karne ki request confirm karein ({ticket}) |
| Deletion intro | इस ईमेल पते से साइन इन होने वाले Aura अकाउंट को डिलीट करने का एक अनुरोध Aura के शिकायत अधिकारी को मिला है (अनुरोध {ticket})। | Is email address se sign in hone wale Aura account ko delete karne ki ek request Aura ke Grievance Officer ko mili hai (request {ticket}). |
| If you did | अगर यह अनुरोध आपने किया है, तो नीचे दिया गया लिंक खोलें और "Delete my account" दबाएँ: | Agar yeh request aapne ki hai, to neeche diya gaya link kholein aur "Delete my account" dabayein: |
| Expiry | यह लिंक सिर्फ़ एक बार, {until} तक काम करेगा। | Yeh link sirf ek baar, {until} tak kaam karega. |
| If not | अगर यह अनुरोध आपका नहीं है, तो कुछ भी करने की ज़रूरत नहीं: आपकी पुष्टि के बिना कुछ भी डिलीट नहीं होगा। चाहें तो लिंक खोलकर "This wasn't me" भी दबाया जा सकता है। | Agar yeh request aapki nahi hai, to kuch bhi karne ki zaroorat nahi: aapke confirmation ke bina kuch bhi delete nahi hoga. Chahein to link kholkar "This wasn't me" bhi dabaya ja sakta hai. |
| What next | आगे क्या होगा: आपकी पुष्टि होते ही Aura वही डिलीट प्रक्रिया शुरू करेगा जो ऐप के अंदर वाले विकल्प से होती है। अकाउंट तुरंत बंद हो जाएगा और 30 दिनों के भीतर हमेशा के लिए डिलीट हो जाएगा (आम तौर पर {grace} दिनों के बाद; इस बीच ऐप में साइन इन करने पर अकाउंट बना रहेगा)। जिन रिकॉर्ड को क़ानूनन रखना ज़रूरी है (जैसे रिपोर्ट किए गए कंटेंट के बारे में), उन्हें सिर्फ़ ज़रूरी समय तक रखा जाता है। | Aage kya hoga: aapka confirmation milte hi Aura wahi deletion shuru karega jo app ke andar wale option se hota hai. Account turant band ho jayega aur 30 dinon ke andar hamesha ke liye delete ho jayega (aam taur par {grace} dinon ke baad; is beech app mein sign in karne par account bana rahega). Jin records ko kaanoonan rakhna zaroori hai (jaise report kiye gaye content ke baare mein), unhein sirf zaroori samay tak rakha jata hai. |

Legal note for the reviewer: category names are shown only to the complainant. The console and the audit log keep the
English codes. The decision reply (with the Grievance Appellate Committee text) stays English.

## Helpline names (crisis sheet, Safety Center, under-13 screen)

Numbers are never translated. The app's own `help_*` labels use the same wording.

| id | English | Hindi | Hinglish |
|---|---|---|---|
| `in.tele_manas` | Tele-MANAS · free, 24×7 | Tele-MANAS · मुफ़्त, 24×7 | Tele-MANAS · free, 24×7 |
| `in.tele_manas_toll_free` | Tele-MANAS toll-free | Tele-MANAS टोल-फ़्री | Tele-MANAS toll-free |
| `in.childline` | Childline · for under-18s | Childline · 18 साल से कम उम्र वालों के लिए | Childline · 18 se kam umar walon ke liye |
| `in.emergency` | Emergency | इमरजेंसी | Emergency |
| `us.988` | Suicide & Crisis Lifeline · call or text | Suicide & Crisis Lifeline · कॉल या टेक्स्ट करें | Suicide & Crisis Lifeline · call ya text karein |

## Open questions for the owner

- **Mood names differ from the PRD 18 table.** See `docs/l10n/hinglish-mood-names.md`. The catalogue has
  बेहाल / Behaal for Overwhelmed and बेचैन / Bechain for Anxious. The PRD table has भारीपन / Bahut bojh and
  घबराहट / Ghabrahat. It also shows "Proud" in Hinglish where the catalogue has Garv.
- **iOS menu paths in `plus_cancelApple` / `plus_cancelGoogle`** keep the English labels (Settings › Subscriptions,
  Payments & subscriptions). A phone set to Hindi shows those menus in Hindi.
- **`Env.betaLocales` now defaults to on** (`AURA_BETA_LOCALES`). The picker offers Hindi and Hinglish, and a Hindi
  device starts in Hindi. `--dart-define=AURA_BETA_LOCALES=false` hides them again. Room pools stay gated separately
  (409 `language_pool_unavailable` until the moderation bar in PRD 18 is met).

## Every app string, by feature (crisis and safety first)

Notes come from the translator and name the choices a reviewer is most likely to question.

### 1. Crisis, help and safety (review first)

60 keys.

| Key | English | Hindi (`hi`) | Hinglish (`hi-Latn`) | Note |
|---|---|---|---|---|
| `help_button` | I need help now | मुझे अभी मदद चाहिए | Mujhe abhi madad chahiye | First person, but चाहिए/chahiye is gender-neutral. Kept close to English so it feels safe to tap. |
| `help_title` | Help is here | मदद यहाँ है | Madad yahan hai |  |
| `help_subtitle` | You don't have to carry this alone. Reach out now, or take a minute to breathe. | आपको इसे अकेले नहीं सहना है। अभी किसी से संपर्क करें, या एक मिनट रुककर साँस लें। | Aapko ise akele nahi sehna hai. Abhi kisi se contact karein, ya ek minute ruk kar saans lein. | 'Carry this alone' rendered as सहना/sehna (bear, endure) with no noun like बोझ, to avoid dramatising. Same phrasing reused in help_crisisSubtitle and help_crisisSubtitleCapsule. |
| `help_crisisTitle` | It sounds like a lot right now. | लगता है अभी बहुत कुछ चल रहा है। | Lagta hai abhi bahut kuch chal raha hai. | Deliberately soft and vague ('a lot is going on'), matching the English. Nothing mentions the note or any risk. |
| `help_crisisSubtitle` | You don't have to carry it alone. Your check-in is saved. | आपको इसे अकेले नहीं सहना है। आपका चेक-इन सेव हो गया है। | Aapko ise akele nahi sehna hai. Aapka check-in save ho gaya hai. |  |
| `help_teleManas` | Tele-MANAS · free, 24×7 | Tele-MANAS · मुफ़्त, 24×7 | Tele-MANAS · free, 24×7 |  |
| `help_teleManasTollFree` | Tele-MANAS toll-free | Tele-MANAS टोल-फ़्री | Tele-MANAS toll-free |  |
| `help_emergency112` | Emergency | इमरजेंसी | Emergency |  |
| `help_childline` | Childline · for under-18s | Childline · 18 साल से कम उम्र वालों के लिए | Childline · 18 se kam umar walon ke liye |  |
| `help_us988` | Suicide & Crisis Lifeline · call or text | Suicide & Crisis Lifeline · कॉल या टेक्स्ट करें | Suicide & Crisis Lifeline · call ya text karein |  |
| `help_otherEmergency` | If you're in danger right now, please call your local emergency number. | अगर आप अभी खतरे में हैं, तो कृपया अपने इलाके के इमरजेंसी नंबर पर कॉल करें। | Agar aap abhi khatre mein hain, to please apne local emergency number par call karein. | hi uses 'अपने इलाके के' for 'local'. hl keeps 'local emergency number'. |
| `help_callSemantic` | Call {name}, {number} | {name} को कॉल करें, {number} | {name} ko call karein, {number} |  |
| `help_groundingTitle` | Sixty seconds to land | ठहरने के लिए साठ सेकंड | Thehrne ke liye sixty seconds | 'To land' rendered as ठहरने/thehrne (settle, pause). Please check it reads naturally; an alternative is 'ज़मीन पर लौटने के लिए साठ सेकंड'. |
| `help_groundingBody` | Breathe with the circle. Everything else can wait a minute. | घेरे के साथ साँस लें। बाकी सब एक मिनट रुक सकता है। | Circle ke saath saans lein. Baaki sab ek minute ruk sakta hai. |  |
| `help_groundingStart` | Start | शुरू करें | Shuru karein |  |
| `help_groundingPause` | Pause | रोकें | Rokein |  |
| `help_groundingResume` | Resume | फिर से शुरू करें | Phir se shuru karein |  |
| `help_breatheIn` | Breathe in | साँस अंदर लें | Saans andar lein |  |
| `help_breatheOut` | Breathe out | साँस बाहर छोड़ें | Saans bahar chhodein |  |
| `help_ground1` | Feel your feet on the ground. | ज़मीन पर अपने पैरों को महसूस करें। | Zameen par apne pairon ko mehsoos karein. |  |
| `help_ground2` | Notice five things you can see. | आसपास दिखने वाली पाँच चीज़ों पर ध्यान दें। | Aas-paas dikhne wali paanch cheezon par dhyaan dein. |  |
| `help_ground3` | Notice three sounds around you. | आसपास की तीन आवाज़ों पर ध्यान दें। | Aas-paas ki teen awaazon par dhyaan dein. |  |
| `help_ground4` | Let your shoulders drop. | अपने कंधों को ढीला छोड़ दें। | Apne kandhon ko dheela chhod dein. |  |
| `help_ground5` | You're here. That's enough for now. | आप यहाँ हैं। अभी के लिए इतना काफ़ी है। | Aap yahan hain. Abhi ke liye itna kaafi hai. |  |
| `help_groundingDone` | Well done. Stay as long as you need. | बहुत अच्छा। जितनी देर ज़रूरत हो, यहीं रहें। | Bahut accha. Jitni der zaroorat ho, yahin rahein. |  |
| `help_secondsLeft` | {seconds, plural, =1{1 second left} other{{seconds} seconds left}} | {seconds, plural, =1{1 सेकंड बाकी} other{{seconds} सेकंड बाकी}} | {seconds, plural, =1{1 second baaki} other{{seconds} seconds baaki}} |  |
| `help_disclaimer` | Aura is not a medical device or an emergency service. | Aura कोई मेडिकल डिवाइस या इमरजेंसी सेवा नहीं है। | Aura koi medical device ya emergency service nahi hai. |  |
| `help_backToCheckin` | Back to my check-in | मेरे चेक-इन पर वापस | Mere check-in par wapas |  |
| `blocked_title` | Aura is made for people 13 and older. | Aura 13 साल और उससे ज़्यादा उम्र के लोगों के लिए बना है। | Aura 13 saal aur usse zyada umar ke logon ke liye bana hai. |  |
| `blocked_body` | We'd love to see you then. | तब आपसे मिलकर हमें बहुत खुशी होगी। | Tab aapse milkar humein bahut khushi hogi. |  |
| `blocked_helpIndia` | If you want to talk to someone now, Childline is free on 1098. In an emergency, call 112. | अगर अभी किसी से बात करने का मन है, तो Childline 1098 पर मुफ़्त है। इमरजेंसी में 112 पर कॉल करें। | Agar abhi kisi se baat karne ka mann hai, to Childline 1098 par free hai. Emergency mein 112 par call karein. | 'If you want to' → 'बात करने का मन है' so the verb does not agree with gender. |
| `blocked_helpOther` | If you want to talk to someone now, please reach out to an adult you trust. | अगर अभी किसी से बात करने का मन है, तो कृपया किसी ऐसे बड़े से बात करें जिस पर आपको भरोसा हो। | Agar abhi kisi se baat karne ka mann hai, to please kisi aise bade se baat karein jis par aapko bharosa ho. | 'An adult you trust' → 'किसी ऐसे बड़े ... जिस पर आपको भरोसा हो' (बड़े = an elder/grown-up, as a child would say it). |
| `set_helpSafety` | Help & Safety | मदद और सुरक्षा | Help & Safety |  |
| `set_grievanceOfficer` | Grievance Officer | शिकायत अधिकारी | Grievance Officer | hi शिकायत अधिकारी is the usual IT Rules rendering; hl keeps the English legal title. |
| `help_crisisSubtitleCapsule` | You don't have to carry it alone. Your capsule is sealed. | आपको इसे अकेले नहीं सहना है। आपका कैप्सूल सील हो गया है। | Aapko ise akele nahi sehna hai. Aapka capsule seal ho gaya hai. |  |
| `help_backToCapsule` | Back to my capsule | मेरे कैप्सूल पर वापस | Mere capsule par wapas |  |
| `closed_title` | This account is closed | यह अकाउंट बंद है | Yeh account band hai |  |
| `closed_body` | This account was closed for breaking Aura's rules. | Aura के नियम तोड़ने की वजह से यह अकाउंट बंद किया गया। | Aura ke rules todne ki wajah se yeh account band kiya gaya. | 'For breaking Aura's rules' → 'नियम तोड़ने की वजह से'. It is factual and gives no reason, as the PRD requires. |
| `closed_review` | If you think this is a mistake, you can ask for a review. We reply within 7 days. | अगर आपको लगता है कि यह गलती है, तो रिव्यू माँगा जा सकता है। हम 7 दिनों के अंदर जवाब देते हैं। | Agar aapko lagta hai ki yeh galti hai, to review maanga ja sakta hai. Hum 7 din ke andar jawaab dete hain. |  |
| `closed_askReview` | Ask for a review | रिव्यू माँगें | Review maangein |  |
| `closed_reviewSubject` | Review of a closed account | बंद अकाउंट का रिव्यू | Band account ka review |  |
| `closed_deleteNote` | You can still delete your account and everything in it. | अपना अकाउंट और उसमें मौजूद सब कुछ अब भी डिलीट किया जा सकता है। | Apna account aur usmein maujood sab kuch ab bhi delete kiya ja sakta hai. |  |
| `closed_signOutNote` | Signing out clears this account from this phone. | साइन आउट करने से यह अकाउंट इस फ़ोन से हट जाएगा। | Sign out karne se yeh account is phone se hat jayega. |  |
| `help_groundingProgress` | Progress through the minute | इस एक मिनट में अब तक | Is ek minute mein ab tak |  |
| `help_progressBegun` | Just begun | अभी शुरू हुआ | Abhi shuru hua |  |
| `help_progressHalf` | About halfway | लगभग आधा | Lagbhag aadha |  |
| `help_progressNearly` | Nearly through | लगभग पूरा | Lagbhag poora |  |
| `help_progressDone` | Complete | पूरा हुआ | Poora hua |  |
| `help_breatheLogged` | {habit} is marked done for today. | {habit} आज के लिए पूरा मार्क कर दिया गया है। | {habit} aaj ke liye done mark kar diya gaya hai. |  |
| `notif_crisisFollowUp` | Just checking in. However today feels, help is one tap away. | बस हालचाल पूछ रहे हैं। आज जैसा भी लग रहा हो, मदद बस एक टैप दूर है। | Bas haal-chaal pooch rahe hain. Aaj jaisa bhi lag raha ho, madad bas ek tap door hai. |  |
| `notif_crisisFollowUpDismiss` | Close | बंद करें | Band karein |  |
| `onb_trustCareTitle` | Wellness support, not therapy | वेलनेस सपोर्ट, थेरेपी नहीं | Wellness support, therapy nahi |  |
| `onb_trustCareBody` | Aura helps you notice how you feel. It doesn't diagnose or treat anything. | Aura आपको यह ध्यान देने में मदद करता है कि आपका मन कैसा है। यह न कोई डायग्नोसिस करता है, न इलाज। | Aura aapko ye dhyaan dene mein madad karta hai ki aapka mann kaisa hai. Ye na koi diagnosis karta hai, na ilaaj. |  |
| `onb_trustHelpTitle` | Help is always one tap away | मदद हमेशा बस एक टैप दूर | Madad hamesha bas ek tap door |  |
| `onb_trustHelpBody` | Tap “{button}” any time to call a helpline or take a minute to breathe. | हेल्पलाइन पर कॉल करने या एक मिनट साँस पर ध्यान देने के लिए कभी भी “{button}” टैप करें। | Helpline par call karne ya ek minute saans par dhyaan dene ke liye kabhi bhi “{button}” tap karein. |  |
| `rooms_reason1` | Someone may be in danger or hurting themselves | शायद कोई खतरे में है या खुद को चोट पहुँचा रहा है | Shayad koi khatre mein hai ya khud ko chot pahuncha raha hai | Safe messaging: 'khud ko chot pahunchana' (no method, no suicide verb). 'koi … raha hai' is generic 'someone', not the user. |
| `rooms_reportCrisis` | Thank you for telling us. A moderator will look soon, and help is always one tap away. | बताने के लिए शुक्रिया। एक मॉडरेटर जल्द ही देखेंगे, और मदद हमेशा बस एक टैप दूर है। | Batane ke liye shukriya. Ek moderator jald hi dekhenge, aur madad hamesha bas ek tap door hai. |  |
| `safety_emergencyWhen` | Call emergency services right away if you or someone near you is in immediate danger, badly hurt, or can't stay safe. | अगर आपको या आपके आसपास किसी को तुरंत खतरा है, गंभीर चोट लगी है, या सुरक्षित रह पाना मुश्किल है, तो तुरंत इमरजेंसी सेवाओं को कॉल करें। | Agar aapko ya aapke aas-paas kisi ko turant khatra hai, gambhir chot lagi hai, ya safe reh paana mushkil hai, to turant emergency services ko call karein. | Rephrased with dative constructions (आपको/किसी को ... खतरा है, चोट लगी है) so nothing agrees with the reader's gender. 'Can't stay safe' → 'सुरक्षित रह पाना मुश्किल है'. No method mentioned. |
| `safety_settingsLink` | Help & Safety in Settings | सेटिंग्स में मदद और सुरक्षा | Settings mein Help & Safety |  |
| `safety_settingsHint` | Support contact, Grievance Officer and policies | सपोर्ट संपर्क, शिकायत अधिकारी और नीतियाँ | Support contact, Grievance Officer aur policies | Grievance Officer → शिकायत अधिकारी (the term used under India's IT Rules). hl keeps the English. |

### 2. Notifications and lock-screen copy (linted: REQ-NTF-01)

65 keys.

| Key | English | Hindi (`hi`) | Hinglish (`hi-Latn`) | Note |
|---|---|---|---|---|
| `push_title` | Want a gentle nudge each evening? | हर शाम एक हल्का-सा रिमाइंडर चाहिए? | Har shaam ek halka sa reminder chahiye? |  |
| `push_body` | One a day at most, and never about streaks. Nothing on your lock screen will say how you feel. | दिन में ज़्यादा से ज़्यादा एक, और स्ट्रीक के बारे में कभी नहीं। आपकी लॉक स्क्रीन पर कभी नहीं दिखेगा कि आपका मन कैसा है। | Din mein zyada se zyada ek, aur streaks ke baare mein kabhi nahi. Aapki lock screen par kabhi nahi dikhega ki aapka mann kaisa hai. |  |
| `push_allow` | Allow | अनुमति दें | Allow karein |  |
| `capsules_readyTitle` | Something you sealed is ready to open. | आपने जो सील किया था, वह अब खुल सकता है। | Aapne jo seal kiya tha, woh ab khul sakta hai. | Lock-screen: avoids खोल- (contains banned substring खो); uses खुल सकता है. |
| `capsules_channelName` | Capsules | कैप्सूल | Capsules |  |
| `capsules_channelDescription` | When something you sealed is ready to open. | जब आपका सील किया हुआ कुछ खुलने के लिए तैयार हो। | Jab aapka seal kiya hua kuch khulne ke liye taiyaar ho. |  |
| `notif_roomsPoolBanner` | Hindi and Hinglish rooms are open now. | हिंदी और हिंग्लिश रूम अब खुल गए हैं। | Hindi aur Hinglish rooms ab khul gaye hain. | Same line as the server push `rooms_pool_open` (the people who get it asked for Hindi/Hinglish rooms). |
| `notif_roomsPoolAction` | See rooms | रूम देखें | Rooms dekhein |  |
| `notif_channelRooms` | Rooms & Lantern Hour | रूम और Lantern Hour | Rooms & Lantern Hour |  |
| `notif_channelRoomsDescription` | Lantern Hour, warmth from your room, and rooms you asked about. | Lantern Hour, आपके रूम से अपनापन, और वे रूम जिनके बारे में आपने पूछा। | Lantern Hour, aapke room se warmth, aur woh rooms jinke baare mein aapne poochha. |  |
| `notif_reminderBanner` | A quiet minute for you. How's today feeling? | आपके लिए सुकून का एक मिनट। आज कैसा लग रहा है? | Aapke liye sukoon ka ek minute. Aaj kaisa lag raha hai? |  |
| `notif_reminderAction` | Check in | चेक-इन करें | Check-in karein |  |
| `notif_capsuleBanner` | Something you sealed is ready to open. | आपने जो सील किया था, वह अब खुल सकता है। | Aapne jo seal kiya tha, woh ab khul sakta hai. | Same line as capsules_readyTitle and the server push `capsule_unlocked`; uses खुल सकता है (the lint bans the substring खो in lock-screen copy). |
| `notif_capsuleAction` | Open | देखें | Kholein | hi uses देखें, not खोलें: lint bans the substring खो in notif_* keys. |
| `notif_channelReminders` | Reminders | रिमाइंडर | Reminders |  |
| `notif_channelRemindersDescription` | Your check-in, wind-down and habit reminders. | आपके चेक-इन, सोने से पहले के सुकून और आदत के रिमाइंडर। | Aapke check-in, wind-down aur habit reminders. |  |
| `set_notifications` | Notifications | नोटिफ़िकेशन | Notifications |  |
| `set_notifMaster` | Notifications from Aura | Aura के नोटिफ़िकेशन | Aura ke notifications |  |
| `set_notifMasterNote` | At most two a day. Nothing on your lock screen says how you feel. | दिन में ज़्यादा से ज़्यादा दो। आपकी लॉक स्क्रीन पर कभी नहीं दिखेगा कि आपको कैसा लग रहा है। | Din mein zyada se zyada do. Aapki lock screen par kabhi nahi dikhega ki aapko kaisa lag raha hai. |  |
| `set_notifReminder` | Daily check-in reminder | रोज़ का चेक-इन रिमाइंडर | Daily check-in reminder |  |
| `set_notifReminderNote` | One gentle nudge a day, at {time}. Skipped once you've checked in. | दिन में एक हल्की-सी याद, {time} पर। चेक-इन हो जाने पर नहीं आती। | Din mein ek halki si yaad, {time} par. Check-in ho jaane par nahi aati. |  |
| `set_notifReminderOffNote` | Off. Turn it on for one gentle nudge a day. | बंद है। दिन में एक हल्की-सी याद के लिए इसे चालू करें। | Off hai. Din mein ek halki si yaad ke liye ise on karein. |  |
| `set_notifReminderTime` | Reminder time | रिमाइंडर का समय | Reminder time |  |
| `set_notifCapsule` | A capsule is ready to open | कोई कैप्सूल खुलने के लिए तैयार है | Koi capsule khulne ke liye taiyaar hai |  |
| `set_notifCapsuleNote` | On the day you chose for something you sealed. | उस दिन, जो आपने अपनी सील की हुई चीज़ के लिए चुना था। | Us din, jo aapne apni seal ki hui cheez ke liye chuna tha. |  |
| `set_notifQuietNote` | Quiet hours: nothing is sent {start}–{end}. | शांत समय: {start}–{end} के बीच कुछ नहीं भेजा जाता। | Quiet hours: {start}–{end} ke beech kuch nahi bheja jata. |  |
| `set_notifQuietFrom` | Quiet from | शांत समय शुरू | Quiet hours shuru |  |
| `set_notifQuietUntil` | Quiet until | शांत समय ख़त्म | Quiet hours khatam |  |
| `set_notifDiscreet` | Discreet mode | गोपनीय मोड | Discreet mode |  |
| `set_notifDiscreetNote` | Every notification just says “Aura · You have a gentle update”. | हर नोटिफ़िकेशन में बस “Aura · आपके लिए एक हल्का-सा अपडेट है” लिखा होता है। | Har notification mein bas “Aura · Aapke liye ek gentle update hai” likha hota hai. | Quotes the discreet push line; must stay identical to server push-copy.ts `discreet` (hi ‘आपके लिए एक हल्का-सा अपडेट है’, hl ‘Aapke liye ek gentle update hai’). |
| `set_notifOffNote` | Notifications are off for Aura on this phone. Your choices here still apply once they're on. | इस फ़ोन पर Aura के नोटिफ़िकेशन बंद हैं। चालू होने पर यहाँ की आपकी पसंद लागू रहेगी। | Is phone par Aura ke notifications off hain. On hone par yahan ki aapki choices laagu rahengi. |  |
| `set_notifTurnOn` | Turn on | चालू करें | On karein |  |
| `set_notifOpenSettings` | Open phone settings | फ़ोन की सेटिंग्स खोलें | Phone settings kholein |  |
| `set_notifQuietConfirmTitle` | This time is inside your quiet hours | यह समय आपके शांत समय में आता है | Ye time aapke quiet hours mein aata hai |  |
| `set_notifQuietConfirmBody` | Aura stays silent {start}–{end}. Send your reminder at {time} anyway? | Aura {start}–{end} तक चुप रहता है। फिर भी {time} पर रिमाइंडर भेजें? | Aura {start}–{end} tak chup rehta hai. Phir bhi {time} par reminder bhejein? |  |
| `set_notifQuietConfirmYes` | Send it anyway | फिर भी भेजें | Phir bhi bhejein |  |
| `set_notifQuietConfirmNo` | Keep it quiet | शांत ही रखें | Quiet hi rakhein |  |
| `push_timeRow` | Every evening at {time} | हर शाम {time} पर | Har shaam {time} par |  |
| `push_changeTime` | Change time | समय बदलें | Time badlein |  |
| `push_discreet` | Keep them discreet | इन्हें गोपनीय रखें | Inhe discreet rakhein |  |
| `notif_gesturesBanner` | People in your room sent you warmth. | आपके रूम के लोगों ने आपको अपनापन भेजा। | Aapke room ke logon ne aapko warmth bheji. |  |
| `notif_gesturesAction` | Open room | रूम में जाएँ | Room mein jaayein |  |
| `notif_lanternBanner` | Lantern Hour is on. Others are here tonight. | Lantern Hour शुरू हो गया है। आज रात और लोग भी यहाँ हैं। | Lantern Hour shuru ho gaya hai. Aaj raat aur log bhi yahan hain. |  |
| `notif_lanternAction` | See rooms | रूम देखें | Rooms dekhein |  |
| `notif_windDownBanner` | A few quiet minutes before sleep, whenever you want them. | सोने से पहले सुकून के कुछ पल, जब भी मन हो। | Sone se pehle sukoon ke kuch pal, jab bhi mann ho. |  |
| `notif_windDownAction` | Open Sounds | आवाज़ें देखें | Sounds kholein | hi uses देखें, not खोलें (lint bans substring खो in notif_*). |
| `notif_habitBanner` | A small habit or two, whenever you're ready. | एक-दो छोटी आदतें, जब भी आप तैयार हों। | Ek-do chhoti habits, jab bhi aap taiyaar hon. |  |
| `notif_habitAction` | See habits | आदतें देखें | Habits dekhein |  |
| `set_notifGestures` | Warmth from your room | आपके रूम से अपनापन | Aapke room se warmth |  |
| `set_notifGesturesNote` | When people in your room send you a gesture. One a day at most. | जब आपके रूम के लोग आपको कोई भाव भेजें। दिन में ज़्यादा से ज़्यादा एक। | Jab aapke room ke log aapko koi gesture bhejein. Din mein zyada se zyada ek. |  |
| `set_notifLantern` | Lantern Hour | Lantern Hour | Lantern Hour |  |
| `set_notifLanternNote` | When Lantern Hour starts in your evening. Not if you've already been in a room that day. | जब आपकी शाम में Lantern Hour शुरू हो। अगर उस दिन कोई रूम पहले ही देखा जा चुका है, तो नहीं। | Jab aapki shaam mein Lantern Hour shuru ho. Agar us din koi room pehle hi dekha ja chuka hai, to nahi. | Rephrased as passive ('कोई रूम पहले ही देखा जा चुका है') to avoid gendered 'जा चुके/चुकी हैं'. |
| `set_notifWindDown` | Wind-down reminder | सोने से पहले के सुकून का रिमाइंडर | Wind-down reminder |  |
| `set_notifWindDownNote` | A few quiet minutes at {time}. Not sent once you've used Sanctuary that evening. | {time} पर सुकून के कुछ मिनट। अगर उस शाम सुकून टैब इस्तेमाल हो चुका है, तो नहीं भेजा जाता। | {time} par sukoon ke kuch minute. Agar us shaam Sanctuary use ho chuka hai, to nahi bheja jata. |  |
| `set_notifWindDownOffNote` | Off. Pick a time for a quiet nudge before sleep. | बंद है। सोने से पहले एक हल्की-सी याद के लिए समय चुनें। | Off hai. Sone se pehle ek halki si yaad ke liye time chunein. |  |
| `set_notifWindDownTime` | Wind-down time | सोने से पहले के सुकून का समय | Wind-down time |  |
| `set_notifWelcomeBack` | After a quiet while | कुछ समय बाद | Kuch samay baad |  |
| `set_notifWelcomeBackNote` | If you've been away a week or more, one gentle hello. Twice at most. | एक हफ़्ते या उससे ज़्यादा की दूरी के बाद, एक हल्का-सा नमस्ते। ज़्यादा से ज़्यादा दो बार। | Ek hafte ya usse zyada ki doori ke baad, ek halka sa hello. Zyada se zyada do baar. | Rephrased as a noun ('दूरी के बाद') to avoid gendered 'दूर रहे/रही हों'. |
| `set_notifHabits` | Habit nudges | आदतों की याद | Habit nudges |  |
| `set_notifHabitsNote` | A small nudge at a time you pick, for any habit on Home. One a day at most. | होम पर किसी भी आदत के लिए, आपके चुने समय पर एक छोटी-सी याद। दिन में ज़्यादा से ज़्यादा एक। | Home par kisi bhi habit ke liye, aapke chune time par ek chhoti si yaad. Din mein zyada se zyada ek. |  |
| `set_notifHabitsNone` | Add a habit on Home to get a nudge for it. | याद पाने के लिए होम पर कोई आदत जोड़ें। | Nudge ke liye Home par koi habit add karein. |  |
| `set_notifHabitOff` | Off | बंद | Off |  |
| `set_notifHabitQuiet` | Inside your quiet hours, so it won't be sent. | यह आपके शांत समय में है, इसलिए नहीं भेजा जाएगा। | Ye aapke quiet hours mein hai, isliye nahi bheja jayega. |  |
| `set_notifHabitChange` | Change time | समय बदलें | Time badlein |  |
| `set_notifHabitTurnOff` | Turn off | बंद करें | Off karein |  |

### 3. Sanctuary: breathing, grounding, companion lines, prompts (calm copy)

150 keys.

| Key | English | Hindi (`hi`) | Hinglish (`hi-Latn`) | Note |
|---|---|---|---|---|
| `sanctuary_title` | Sanctuary | सुकून | Sanctuary |  |
| `sanctuary_intro` | A quiet place, just for you. Go at your own pace. Nothing here is scored. | सिर्फ़ आपके लिए एक शांत जगह। अपनी रफ़्तार से चलें। यहाँ किसी चीज़ का स्कोर नहीं होता। | Sirf aapke liye ek shaant jagah. Apni raftaar se chalein. Yahan kisi cheez ka score nahi hota. |  |
| `sanctuary_todayTitle` | Today's minute | आज का एक मिनट | Aaj ka ek minute |  |
| `sanctuary_breatheSection` | Breathe | साँस लें | Saans lein |  |
| `sanctuary_breatheCard` | Breathe with your Aura | अपने Aura के साथ साँस लें | Apne Aura ke saath saans lein |  |
| `sanctuary_breatheCardBody` | Calm, box or 4-7-8 breathing, for as long as you like. | शांत, बॉक्स या 4-7-8 ब्रीदिंग, जितनी देर मन हो। | Calm, box ya 4-7-8 breathing, jitni der mann ho. |  |
| `sanctuary_groundingSection` | Grounding | ग्राउंडिंग | Grounding |  |
| `sanctuary_begin` | Begin | शुरू करें | Shuru karein |  |
| `sanctuary_start` | Start | शुरू करें | Start karein |  |
| `sanctuary_pause` | Pause | रोकें | Pause karein |  |
| `sanctuary_resume` | Resume | फिर से शुरू करें | Phir se shuru karein |  |
| `sanctuary_finish` | Finish | ख़त्म करें | Khatam karein |  |
| `sanctuary_next` | Next | आगे | Aage |  |
| `sanctuary_progress` | Progress through this session | इस सेशन की प्रगति | Is session ki progress |  |
| `sanctuary_progressBegun` | Just begun | अभी शुरू हुआ | Abhi shuru hua |  |
| `sanctuary_progressHalf` | About halfway | लगभग आधा | Lagbhag aadha |  |
| `sanctuary_progressNearly` | Nearly through | लगभग पूरा | Lagbhag poora |  |
| `sanctuary_progressDone` | Complete | पूरा हुआ | Poora hua |  |
| `breathe_rhythm` | Rhythm | लय | Rhythm |  |
| `breathe_calm` | Calm | शांत | Calm | Pattern name: hi 'शांत', hl keeps 'Calm' (like Tenglish). |
| `breathe_calmBody` | In for 4, out for 6. Gentle and steady. | 4 तक साँस अंदर, 6 तक बाहर। हल्की और एक-सी। | 4 tak saans andar, 6 tak baahar. Halki aur ek-si. |  |
| `breathe_box` | Box | बॉक्स | Box |  |
| `breathe_boxBody` | In, hold, out, hold. Four counts each. | अंदर, रोकें, बाहर, रोकें। हर बार चार गिनती। | Andar, rokein, baahar, rokein. Har baar chaar ginti. |  |
| `breathe_478` | 4-7-8 | 4-7-8 | 4-7-8 |  |
| `breathe_478Body` | In for 4, hold for 7, out for 8. | 4 तक अंदर, 7 तक रोकें, 8 तक बाहर। | 4 tak andar, 7 tak rokein, 8 tak baahar. |  |
| `breathe_lightHeaded` | If you feel light-headed, stop and breathe normally. | अगर चक्कर-सा लगे, तो रुकें और आम तरह से साँस लें। | Agar chakkar-sa lage, to rukein aur normal tarah se saans lein. |  |
| `breathe_length` | Length | कितनी देर | Kitni der |  |
| `breathe_minutes` | {count, plural, =1{1 minute} other{{count} minutes}} | {count, plural, =1{1 मिनट} other{{count} मिनट}} | {count, plural, =1{1 minute} other{{count} minute}} |  |
| `breathe_openEnded` | Until I stop | जब तक मैं न रोकूँ | Jab tak main na rokun | First person with subjunctive रोकूँ (neutral). |
| `breathe_in` | Breathe in | साँस अंदर लें | Saans andar lein |  |
| `breathe_hold` | Hold | रोकें | Rokein |  |
| `breathe_out` | Breathe out | साँस बाहर छोड़ें | Saans baahar chhodein |  |
| `breathe_paused` | Paused. Take your time. | रुका हुआ है। आराम से। | Ruka hua hai. Aaram se. |  |
| `breathe_done` | That was time just for you. | यह वक़्त सिर्फ़ आपके लिए था। | Yeh waqt sirf aapke liye tha. |  |
| `breathe_again` | Again | फिर से | Phir se |  |
| `breathe_land1` | Feel your feet on the ground. | अपने पैरों को ज़मीन पर महसूस करें। | Apne pairon ko zameen par mehsoos karein. |  |
| `breathe_land2` | Notice three sounds around you. | आसपास की तीन आवाज़ों पर ध्यान दें। | Aas-paas ki teen aawazon par dhyaan dein. |  |
| `breathe_keepGoing` | Keep going | जारी रखें | Jaari rakhein |  |
| `breathe_land3` | Let your shoulders drop. | कंधों को ढीला छोड़ दें। | Kandhon ko dheela chhod dein. |  |
| `senses_title` | Five senses | पाँच इंद्रियाँ | Paanch senses | hi uses standard 'इंद्रियाँ' (five senses); hl 'senses'. |
| `senses_card` | Notice what's around you, one sense at a time. | आसपास जो है, उसे एक-एक इंद्रिय से महसूस करें। | Aas-paas jo hai, use ek-ek sense se mehsoos karein. |  |
| `senses_intro` | Let's notice what's around you, one sense at a time. Go at your own pace. | चलिए, आसपास जो है उसे एक-एक इंद्रिय से महसूस करें। अपनी रफ़्तार से चलें। | Chaliye, aas-paas jo hai use ek-ek sense se mehsoos karein. Apni raftaar se chalein. |  |
| `senses_see` | Five things you can see | पाँच चीज़ें जो आपको दिख रही हैं | Paanch cheezein jo aapko dikh rahi hain |  |
| `senses_seeBody` | Look around slowly. Name them in your head or out loud. | धीरे-धीरे आसपास देखें। मन में या बोलकर उनके नाम लें। | Dheere-dheere aas-paas dekhein. Mann mein ya bolkar unke naam lein. |  |
| `senses_touch` | Four things you can touch | चार चीज़ें जिन्हें आप छू सकें | Chaar cheezein jinhein aap chhoo sakein | Subjunctive 'छू सकें' used to avoid gendered सकते/सकती. |
| `senses_touchBody` | The chair under you, your clothes, the air on your skin. | नीचे की कुर्सी, आपके कपड़े, त्वचा को छूती हवा। | Neeche ki kursi, aapke kapde, skin ko chhooti hawa. |  |
| `senses_hear` | Three things you can hear | तीन आवाज़ें जो आपको सुनाई दे रही हैं | Teen aawazein jo aapko sunai de rahi hain |  |
| `senses_hearBody` | Near or far, loud or soft. | पास की या दूर की, तेज़ या धीमी। | Paas ki ya door ki, tez ya dheemi. |  |
| `senses_smell` | Two things you can smell | दो चीज़ें जिनकी महक आ रही हो | Do cheezein jinki mehak aa rahi ho |  |
| `senses_smellBody` | Or two scents you like, if nothing is near. | या अगर पास कुछ न हो, तो दो पसंदीदा ख़ुशबुएँ। | Ya agar paas kuch na ho, to do pasandeeda khushbuein. |  |
| `senses_taste` | One thing you can taste | एक चीज़ जिसका स्वाद महसूस हो | Ek cheez jiska swaad mehsoos ho |  |
| `senses_tasteBody` | Or take a sip of water and notice it. | या पानी का एक घूँट लें और उसे महसूस करें। | Ya paani ka ek ghoont lein aur use mehsoos karein. |  |
| `senses_step` | Step {step} of {total} | {total} में से स्टेप {step} | {total} mein se step {step} |  |
| `senses_done` | You're here, in this moment. Nicely done. | आप यहाँ हैं, इसी पल में। बहुत अच्छा। | Aap yahan hain, isi pal mein. Bahut achha. |  |
| `heart_title` | Hand on heart | दिल पर हाथ | Dil par haath |  |
| `heart_card` | A minute of warmth, just for you. | सिर्फ़ आपके लिए, एक मिनट की गर्माहट। | Sirf aapke liye, ek minute ki garmahat. |  |
| `heart_intro` | Place a hand on your heart, or anywhere that feels comforting. | एक हाथ अपने दिल पर रखें, या जहाँ भी सुकून लगे। | Ek haath apne dil par rakhein, ya jahan bhi sukoon lage. |  |
| `heart_1` | Feel the warmth of your hand. | अपने हाथ की गर्माहट महसूस करें। | Apne haath ki garmahat mehsoos karein. |  |
| `heart_2` | Breathe gently. There's no rush. | धीरे से साँस लें। कोई जल्दी नहीं है। | Dheere se saans lein. Koi jaldi nahi hai. |  |
| `heart_3` | Whatever you're feeling is allowed here. | यहाँ जो भी महसूस हो, उसकी जगह है। | Yahan jo bhi mehsoos ho, uski jagah hai. | Rephrased impersonally ('जो भी महसूस हो') to avoid महसूस कर रहे/रही हैं. |
| `heart_4` | Be as kind to yourself as you would be to a friend. | ख़ुद के साथ उतनी ही नरमी रखें, जितनी किसी दोस्त के साथ। | Khud ke saath utni hi narmi rakhein, jitni kisi dost ke saath. |  |
| `heart_done` | Thank you for being gentle with yourself. | ख़ुद के साथ नरमी रखने के लिए शुक्रिया। | Khud ke saath narmi rakhne ke liye shukriya. |  |
| `gratitude_title` | Three small things | तीन छोटी बातें | Teen chhoti baatein |  |
| `gratitude_card` | Three small things that went okay today. | आज की तीन छोटी बातें जो ठीक-ठाक रहीं। | Aaj ki teen chhoti baatein jo theek-thaak rahin. |  |
| `gratitude_intro` | Bring three small things from today to mind, one at a time. There's nothing to write. | आज की तीन छोटी बातें, एक-एक करके याद करें। कुछ लिखना नहीं है। | Aaj ki teen chhoti baatein, ek-ek karke yaad karein. Kuch likhna nahi hai. |  |
| `gratitude_1` | One small thing that went okay | एक छोटी बात जो ठीक रही | Ek chhoti baat jo theek rahi |  |
| `gratitude_1Body` | It can be tiny, like a warm drink or a kind word. | बहुत छोटी बात भी चलेगी, जैसे कुछ गरम पीना या किसी के मीठे बोल। | Bahut chhoti baat bhi chalegi, jaise kuch garam peena ya kisi ke meethe bol. |  |
| `gratitude_2` | Another small thing | एक और छोटी बात | Ek aur chhoti baat |  |
| `gratitude_2Body` | Something you saw, heard or did. | कुछ जो आपने देखा, सुना या किया। | Kuch jo aapne dekha, suna ya kiya. |  |
| `gratitude_3` | One more small thing | बस एक और छोटी बात | Bas ek aur chhoti baat |  |
| `gratitude_3Body` | Maybe something about yourself. | शायद आपके अपने बारे में कुछ। | Shayad aapke apne baare mein kuch. |  |
| `gratitude_done` | Hold onto those for a moment. They're yours. | इन्हें एक पल के लिए अपने पास रखें। ये आपकी हैं। | Inhein ek pal ke liye apne paas rakhein. Ye aapki hain. |  |
| `savour_intro` | Let's replay one good moment from today, slowly. | चलिए, आज के एक अच्छे पल को धीरे-धीरे फिर से जिएँ। | Chaliye, aaj ke ek achhe pal ko dheere-dheere phir se jiyein. |  |
| `savour_1` | Bring one good moment from today to mind, however small. | आज का एक अच्छा पल याद करें, चाहे कितना भी छोटा हो। | Aaj ka ek achha pal yaad karein, chahe kitna bhi chhota ho. |  |
| `savour_2` | Where were you? What could you see and hear? | वह पल कहाँ का था? आसपास क्या दिख और सुनाई दे रहा था? | Woh pal kahan ka tha? Aas-paas kya dikh aur sunai de raha tha? | 'Where were you?' rephrased to 'वह पल कहाँ का था?' to avoid थे/थीं. |
| `savour_3` | Notice how it feels to remember it now. | अब उसे याद करके कैसा लग रहा है, इस पर ध्यान दें। | Ab use yaad karke kaisa lag raha hai, is par dhyaan dein. |  |
| `savour_done` | Let it stay with you a little longer. | उसे थोड़ी देर और अपने साथ रहने दें। | Use thodi der aur apne saath rehne dein. |  |
| `minute_forYou` | A minute for you | आपके लिए एक मिनट | Aapke liye ek minute |  |
| `minute_calmTitle` | One calm minute | एक शांत मिनट | Ek shaant minute |  |
| `minute_boxTitle` | Box breathing | बॉक्स ब्रीदिंग | Box breathing |  |
| `minute_478Title` | 4-7-8 breathing | 4-7-8 ब्रीदिंग | 4-7-8 breathing |  |
| `minute_stillnessTitle` | A minute of stillness | एक मिनट का ठहराव | Ek minute ka thehraav |  |
| `minute_stillnessBody` | One quiet minute with the orb. | ऑर्ब के साथ एक शांत मिनट। | Orb ke saath ek shaant minute. | 'orb' transliterated as ऑर्ब / Orb (Telugu kept Orb). |
| `minute_landTitle` | Thirty seconds to land | ठहरने के लिए तीस सेकंड | Thehrne ke liye tees second | 'to land' rendered as ठहरने (settle/pause); reviewer may prefer another verb. |
| `minute_landBody` | Three slow breaths with the orb. | ऑर्ब के साथ तीन धीमी साँसें। | Orb ke saath teen dheemi saansein. |  |
| `minute_comfortTitle` | A little comfort | थोड़ा सुकून | Thoda sukoon |  |
| `minute_comfortBody` | A hand on your heart, and a minute of warmth. | दिल पर एक हाथ, और एक मिनट की गर्माहट। | Dil par ek haath, aur ek minute ki garmahat. |  |
| `minute_savourTitle` | Savour this | इस पल को जिएँ | Is pal ko jiyein |  |
| `minute_savourBody` | Replay one good moment from today. | आज का एक अच्छा पल फिर से जिएँ। | Aaj ka ek achha pal phir se jiyein. |  |
| `companion_storm1` | That's a lot at once. Your light is still here. | एक साथ बहुत कुछ है। आपकी रोशनी अब भी यहीं है। | Ek saath bahut kuch hai. Aapki roshni ab bhi yahin hai. |  |
| `companion_storm2` | Naming a storm takes courage. You showed up for yourself. | तूफ़ान को नाम देना हिम्मत की बात है। आपने अपना साथ दिया। | Storm ko naam dena himmat ki baat hai. Aapne apna saath diya. |  |
| `companion_storm3` | Big, loud feelings are welcome here. So are you. | बड़ी, तेज़ भावनाओं के लिए यहाँ जगह है। आपके लिए भी। | Badi, tez feelings ke liye yahan jagah hai. Aapke liye bhi. |  |
| `companion_storm4` | Stormy days matter too. Thank you for checking in. | तूफ़ानी दिन भी मायने रखते हैं। चेक-इन करने के लिए शुक्रिया। | Storm wale din bhi maayne rakhte hain. Check-in karne ke liye shukriya. | Hinglish keeps quadrant names in English ('Storm wale din', 'Rain wale din'); hi uses तूफ़ानी/बारिश वाले. |
| `companion_storm5` | You named this honestly. That matters. | आपने इसे ईमानदारी से नाम दिया। यह मायने रखता है। | Aapne ise imaandaari se naam diya. Yeh maayne rakhta hai. |  |
| `companion_storm6` | Storms are part of your sky too. | तूफ़ान भी आपके आसमान का हिस्सा है। | Storm bhi aapke aasmaan ka hissa hai. |  |
| `companion_storm7` | Whatever is swirling, you noticed it. That counts. | अंदर जो भी उमड़ रहा हो, आपने उसे पहचाना। इसकी अहमियत है। | Andar jo bhi umad raha ho, aapne use pehchaana. Iski ahmiyat hai. | 'That counts' → 'इसकी अहमियत है' (kept distinct from 'That matters' → 'यह मायने रखता है'); same in rain7/moonlight7/sunrise7. |
| `companion_storm8` | Even in a storm, your glow is yours. | तूफ़ान में भी, आपकी चमक आपकी अपनी है। | Storm mein bhi, aapki chamak aapki apni hai. |  |
| `companion_rain1` | That feels heavy. Your light is still with you. | यह भारी लग रहा है। आपकी रोशनी अब भी आपके साथ है। | Yeh bhaari lag raha hai. Aapki roshni ab bhi aapke saath hai. |  |
| `companion_rain2` | Being honest about a low day takes courage. You showed up for yourself. | बुझे-से दिन के बारे में सच कहना हिम्मत की बात है। आपने अपना साथ दिया। | Low din ke baare mein sach kehna himmat ki baat hai. Aapne apna saath diya. | 'low day' → hi 'बुझे-से दिन', hl keeps 'low din'. |
| `companion_rain3` | Slow, heavy feelings are welcome here. So are you. | धीमी, भारी भावनाओं के लिए यहाँ जगह है। आपके लिए भी। | Dheemi, bhaari feelings ke liye yahan jagah hai. Aapke liye bhi. |  |
| `companion_rain4` | Rainy days matter too. Thank you for checking in. | बारिश वाले दिन भी मायने रखते हैं। चेक-इन करने के लिए शुक्रिया। | Rain wale din bhi maayne rakhte hain. Check-in karne ke liye shukriya. |  |
| `companion_rain5` | You were honest with yourself today. That matters. | आज आपने ख़ुद से सच कहा। यह मायने रखता है। | Aaj aapne khud se sach kaha. Yeh maayne rakhta hai. |  |
| `companion_rain6` | Rain is part of your sky too. | बारिश भी आपके आसमान का हिस्सा है। | Rain bhi aapke aasmaan ka hissa hai. |  |
| `companion_rain7` | However heavy it is, you noticed it. That counts. | यह जितना भी भारी हो, आपने इसे पहचाना। इसकी अहमियत है। | Yeh jitna bhi bhaari ho, aapne ise pehchaana. Iski ahmiyat hai. |  |
| `companion_rain8` | Even on grey days, your glow is yours. | बादलों वाले दिनों में भी, आपकी चमक आपकी अपनी है। | Baadal wale dinon mein bhi, aapki chamak aapki apni hai. |  |
| `companion_moonlight1` | A quiet, settled moment. Your light is resting easy. | एक शांत, ठहरा हुआ पल। आपकी रोशनी आराम से है। | Ek shaant, thehra hua pal. Aapki roshni aaraam se hai. |  |
| `companion_moonlight2` | Noticing a quiet moment is worth something. You showed up for yourself. | एक शांत पल को पहचानना भी मायने रखता है। आपने अपना साथ दिया। | Ek shaant pal ko pehchaanna bhi maayne rakhta hai. Aapne apna saath diya. |  |
| `companion_moonlight3` | Soft, easy feelings are welcome here. So are you. | नरम, हल्की भावनाओं के लिए यहाँ जगह है। आपके लिए भी। | Naram, halki feelings ke liye yahan jagah hai. Aapke liye bhi. |  |
| `companion_moonlight4` | Gentle days matter too. Thank you for checking in. | सुकून भरे दिन भी मायने रखते हैं। चेक-इन करने के लिए शुक्रिया। | Sukoon bhare din bhi maayne rakhte hain. Check-in karne ke liye shukriya. |  |
| `companion_moonlight5` | You took a moment to notice this. That matters. | आपने इसे महसूस करने के लिए एक पल लिया। यह मायने रखता है। | Aapne ise mehsoos karne ke liye ek pal liya. Yeh maayne rakhta hai. |  |
| `companion_moonlight6` | Moonlight is part of your sky too. | चाँदनी भी आपके आसमान का हिस्सा है। | Moonlight bhi aapke aasmaan ka hissa hai. |  |
| `companion_moonlight7` | However small this calm is, you noticed it. That counts. | यह सुकून जितना भी छोटा हो, आपने इसे पहचाना। इसकी अहमियत है। | Yeh sukoon jitna bhi chhota ho, aapne ise pehchaana. Iski ahmiyat hai. |  |
| `companion_moonlight8` | In the quiet, your glow is yours. | इस ख़ामोशी में, आपकी चमक आपकी अपनी है। | Is khamoshi mein, aapki chamak aapki apni hai. |  |
| `companion_sunrise1` | A bright moment. Your light is shining. | एक रोशन पल। आपकी रोशनी चमक रही है। | Ek roshan pal. Aapki roshni chamak rahi hai. |  |
| `companion_sunrise2` | Noticing a good moment is worth something. You showed up for yourself. | एक अच्छे पल को पहचानना भी मायने रखता है। आपने अपना साथ दिया। | Ek achhe pal ko pehchaanna bhi maayne rakhta hai. Aapne apna saath diya. |  |
| `companion_sunrise3` | Big, bright feelings are welcome here. So are you. | बड़ी, चमकती भावनाओं के लिए यहाँ जगह है। आपके लिए भी। | Badi, chamakti feelings ke liye yahan jagah hai. Aapke liye bhi. |  |
| `companion_sunrise4` | Bright days matter too. Thank you for checking in. | रोशन दिन भी मायने रखते हैं। चेक-इन करने के लिए शुक्रिया। | Roshan din bhi maayne rakhte hain. Check-in karne ke liye shukriya. |  |
| `companion_sunrise5` | You let yourself notice this. That matters. | आपने ख़ुद को यह महसूस करने दिया। यह मायने रखता है। | Aapne khud ko yeh mehsoos karne diya. Yeh maayne rakhta hai. |  |
| `companion_sunrise6` | Sunrise is part of your sky too. | सूर्योदय भी आपके आसमान का हिस्सा है। | Sunrise bhi aapke aasmaan ka hissa hai. |  |
| `companion_sunrise7` | However big or small this is, you noticed it. That counts. | यह बड़ा हो या छोटा, आपने इसे पहचाना। इसकी अहमियत है। | Yeh bada ho ya chhota, aapne ise pehchaana. Iski ahmiyat hai. |  |
| `companion_sunrise8` | In this brightness, your glow is yours. | इस उजाले में, आपकी चमक आपकी अपनी है। | Is ujaale mein, aapki chamak aapki apni hai. |  |
| `companion_neutral1` | Thank you for checking in. | चेक-इन करने के लिए शुक्रिया। | Check-in karne ke liye shukriya. |  |
| `companion_neutral2` | You showed up for yourself. | आपने अपना साथ दिया। | Aapne apna saath diya. | 'You showed up for yourself' rendered as 'आपने अपना साथ दिया' (you stood by yourself) in all pools: ergative, so gender-neutral (आप आए/आईं avoided). |
| `companion_neutral3` | Your light is still here. | आपकी रोशनी अब भी यहीं है। | Aapki roshni ab bhi yahin hai. |  |
| `companion_neutral4` | There's no rush here. | यहाँ कोई जल्दी नहीं है। | Yahan koi jaldi nahi hai. |  |
| `prompt_note1` | What's one small thing that helped today? | आज किस छोटी चीज़ से थोड़ी मदद मिली? | Aaj kis chhoti cheez se thodi madad mili? |  |
| `prompt_note2` | What's on your mind right now? | अभी मन में क्या चल रहा है? | Abhi mann mein kya chal raha hai? |  |
| `prompt_note3` | What would you like to remember about today? | आज की कौन-सी बात याद रखने का मन है? | Aaj ki kaun-si baat yaad rakhne ka mann hai? | 'What would you like to…' prompts use '… का मन है?' to avoid चाहेंगे/चाहेंगी. |
| `prompt_storm1` | What's taking up the most room right now? | अभी मन में सबसे ज़्यादा जगह किस चीज़ ने घेरी है? | Abhi mann mein sabse zyada jagah kis cheez ne gheri hai? |  |
| `prompt_storm2` | If this feeling could speak, what would it say? | अगर यह एहसास बोल पाता, तो क्या कहता? | Agar yeh ehsaas bol paata, to kya kehta? |  |
| `prompt_storm3` | What's one thing you could set down, even for a minute? | ऐसी कौन-सी एक चीज़ है जिसे एक मिनट के लिए ही सही, किनारे रखा जा सके? | Aisi kaun-si ek cheez hai jise ek minute ke liye hi sahi, kinaare rakha ja sake? |  |
| `prompt_rain1` | What would feel gentle right now? | अभी क्या सुकून भरा लगेगा? | Abhi kya sukoon bhara lagega? |  |
| `prompt_rain2` | What's weighing on you today? | आज मन पर क्या भारी है? | Aaj mann par kya bhaari hai? |  |
| `prompt_rain3` | Who or what has felt kind to you lately? | हाल में किसकी या किस चीज़ की नरमी महसूस हुई? | Haal mein kiski ya kis cheez ki narmi mehsoos hui? |  |
| `prompt_moonlight1` | What's helping you feel settled? | किस चीज़ से मन ठहरा हुआ लग रहा है? | Kis cheez se mann thehra hua lag raha hai? |  |
| `prompt_moonlight2` | What made today feel softer? | आज किस चीज़ ने दिन को थोड़ा नरम बनाया? | Aaj kis cheez ne din ko thoda naram banaya? |  |
| `prompt_moonlight3` | What would you like to keep from this moment? | इस पल से क्या अपने साथ रखने का मन है? | Is pal se kya apne saath rakhne ka mann hai? |  |
| `prompt_sunrise1` | What's lighting you up today? | आज किस चीज़ से मन खिल रहा है? | Aaj kis cheez se mann khil raha hai? |  |
| `prompt_sunrise2` | What went well that you'd like to remember? | क्या अच्छा रहा, जिसे याद रखने का मन है? | Kya achha raha, jise yaad rakhne ka mann hai? |  |
| `prompt_sunrise3` | Who would you like to share this with? | यह किसके साथ बाँटने का मन है? | Yeh kiske saath baantne ka mann hai? |  |
| `prompt_capsule1` | What do you want future you to know? | भविष्य के आप तक कौन-सी बात पहुँचानी है? | Future you tak kaun-si baat pahunchaani hai? | hi 'भविष्य के आप' per glossary; hl 'Future you'. |
| `prompt_capsule2` | What's helping you right now that you might forget? | अभी किस चीज़ से मदद मिल रही है, जो शायद बाद में याद न रहे? | Abhi kis cheez se madad mil rahi hai, jo shayad baad mein yaad na rahe? |  |
| `prompt_capsule3` | What would you say to yourself on a hard day? | मुश्किल दिन पर ख़ुद से क्या कहना है? | Mushkil din par khud se kya kehna hai? |  |
| `prompt_capsuleStorm` | What helps when everything feels like too much? | जब सब कुछ बहुत ज़्यादा लगे, तब किस चीज़ से मदद मिलती है? | Jab sab kuch bahut zyada lage, tab kis cheez se madad milti hai? |  |
| `prompt_capsuleRain` | What would you want to hear on a heavy day? | भारी दिन पर क्या सुनने का मन होगा? | Bhaari din par kya sunne ka mann hoga? |  |
| `prompt_capsuleMoonlight` | What helps you find this calm again? | यह सुकून फिर से पाने में किस चीज़ से मदद मिलती है? | Yeh sukoon phir se paane mein kis cheez se madad milti hai? |  |
| `prompt_capsuleSunrise` | What would you like to celebrate with future you? | भविष्य के आप के साथ किस बात का जश्न मनाने का मन है? | Future you ke saath kis baat ka jashn manaane ka mann hai? |  |
| `prompt_another` | Another prompt | कोई और सवाल | Koi aur sawaal |  |
| `prompt_settingsTitle` | Writing prompts | लिखने के लिए सवाल | Writing prompts |  |
| `prompt_settingsBody` | A gentle question in the empty note. Never saved. | खाली नोट में एक हल्का-सा सवाल। कभी सेव नहीं होता। | Khaali note mein ek halka-sa sawaal. Kabhi save nahi hota. |  |

### 4. Sounds (linted: no health / sleep claims)

68 keys.

| Key | English | Hindi (`hi`) | Hinglish (`hi-Latn`) | Note |
|---|---|---|---|---|
| `sounds_windDownRemind` | Remind me at {time} | {time} पर याद दिलाएँ | {time} par yaad dilayein |  |
| `sounds_windDownReminderOn` | A gentle reminder comes at {time}. | {time} पर एक हल्की-सी याद आएगी। | {time} par ek halki si yaad aayegi. |  |
| `sounds_windDownReminderOff` | Turn off | बंद करें | Off karein |  |
| `sounds_title` | Sounds | आवाज़ें | Sounds |  |
| `sounds_cardBody` | Rain, ocean, wind and more. Nothing plays until you choose. | बारिश, समुद्र, हवा और भी बहुत कुछ। जब तक आप न चुनें, कुछ नहीं बजता। | Baarish, samundar, hawa aur bhi bahut kuch. Jab tak aap na chunein, kuch nahi bajta. |  |
| `sounds_cardPlaying` | Playing now | अभी बज रहा है | Abhi baj raha hai |  |
| `sounds_intro` | Pick a sound to begin, or mix up to four. Nothing plays until you tap. | शुरू करने के लिए एक आवाज़ चुनें, या चार तक मिलाएँ। जब तक आप टैप न करें, कुछ नहीं बजता। | Shuru karne ke liye ek sound chunein, ya chaar tak mix karein. Jab tak aap tap na karein, kuch nahi bajta. |  |
| `sounds_nothingPlaying` | Nothing playing | कुछ नहीं बज रहा | Kuch nahi baj raha |  |
| `sounds_statePlaying` | Playing | बज रहा है | Baj raha hai |  |
| `sounds_statePaused` | Paused | रुका हुआ | Ruka hua |  |
| `sounds_backgroundNote` | Sounds keep playing with the screen off. They pause if your headphones disconnect or a call comes in. | स्क्रीन बंद होने पर भी आवाज़ें बजती रहती हैं। हेडफ़ोन डिसकनेक्ट होने या कॉल आने पर ये रुक जाती हैं। | Screen off hone par bhi sounds bajti rehti hain. Headphones disconnect hone ya call aane par ye ruk jaati hain. |  |
| `sounds_notificationChannel` | Sounds playback | आवाज़ों का प्लेबैक | Sounds playback |  |
| `sounds_windDownTitle` | Night wind-down | रात का सुकून | Night wind-down | hi 'रात का सुकून' instead of glossary 'सोने से पहले का सुकून' to keep sleep words out of sounds_*; hl keeps 'Night wind-down'. |
| `sounds_windDownBody` | About 20 minutes of sounds that slowly thin out to silence. The order changes each night. | लगभग 20 मिनट की आवाज़ें, जो धीरे-धीरे कम होकर ख़ामोशी में बदल जाती हैं। हर रात इनका क्रम बदलता है। | Lagbhag 20 minute ki sounds, jo dheere-dheere kam hokar khamoshi mein badal jaati hain. Har raat inka order badalta hai. |  |
| `sounds_windDownBegin` | Begin wind-down | रात का सुकून शुरू करें | Wind-down shuru karein |  |
| `sounds_windDownLeft` | {minutes, plural, =1{About 1 minute left} other{About {minutes} minutes left}} | {minutes, plural, =1{लगभग 1 मिनट बाक़ी} other{लगभग {minutes} मिनट बाक़ी}} | {minutes, plural, =1{Lagbhag 1 minute baaki} other{Lagbhag {minutes} minute baaki}} |  |
| `sounds_windDownBusy` | The wind-down is playing. Stop it to make your own mix. | रात का सुकून चल रहा है। अपना मिक्स बनाने के लिए पहले इसे रोकें। | Wind-down chal raha hai. Apna mix banane ke liye pehle ise rokein. |  |
| `sounds_mixSection` | Mix your own | अपना मिक्स बनाएँ | Apna mix banayein |  |
| `sounds_mixHint` | Up to four at once, each with its own volume. | एक साथ चार तक, हर एक का अपना वॉल्यूम। | Ek saath chaar tak, har ek ka apna volume. |  |
| `sounds_stemRain` | Rain | बारिश | Baarish |  |
| `sounds_stemOcean` | Ocean | समुद्र | Samundar |  |
| `sounds_stemWind` | Wind | हवा | Hawa |  |
| `sounds_stemNightInsects` | Night insects | रात के झींगुर | Raat ke jheengur |  |
| `sounds_stemSingingBowl` | Singing bowl | सिंगिंग बाउल | Singing bowl |  |
| `sounds_stemChimes` | Chimes | घंटियाँ | Chimes |  |
| `sounds_stemBrownNoise` | Brown noise | ब्राउन नॉइज़ | Brown noise |  |
| `sounds_stemPinkNoise` | Pink noise | पिंक नॉइज़ | Pink noise |  |
| `sounds_stemDeepBell` | Distant bell | दूर की घंटी | Door ki ghanti |  |
| `sounds_stemMonsoonRoof` | Monsoon on a roof | छत पर बरसात | Chhat par barsaat |  |
| `sounds_stemStream` | Stream | बहती धारा | Behti dhaara |  |
| `sounds_stemFireplace` | Fireplace | अलाव | Alaav |  |
| `sounds_stemDistantThunder` | Distant thunder | दूर की गरज | Door ki garaj |  |
| `sounds_stemOn` | {name}, playing, volume {percent}% | {name}, बज रहा है, वॉल्यूम {percent}% | {name}, baj raha hai, volume {percent}% |  |
| `sounds_stemPaused` | {name}, paused, volume {percent}% | {name}, रुका हुआ, वॉल्यूम {percent}% | {name}, ruka hua, volume {percent}% |  |
| `sounds_stemOff` | {name}, off | {name}, बंद | {name}, off |  |
| `sounds_stemLocked` | {name}, part of Aura Plus | {name}, Aura Plus का हिस्सा | {name}, Aura Plus ka hissa |  |
| `sounds_stemNeedsDownload` | {name}, {size} to download once | {name}, एक बार {size} डाउनलोड करना है | {name}, ek baar {size} download karna hai |  |
| `sounds_stemDownloading` | {name}, downloading | {name}, डाउनलोड हो रहा है | {name}, download ho raha hai |  |
| `sounds_volume` | {name} volume | {name} का वॉल्यूम | {name} ka volume |  |
| `sounds_plusBadge` | Aura Plus | Aura Plus | Aura Plus |  |
| `sounds_plusNote` | Coming with Aura Plus. | Aura Plus के साथ मिलता है। | Aura Plus ke saath milta hai. |  |
| `sounds_full` | Four sounds are playing. Turn one off to add another. | चार आवाज़ें बज रही हैं। नई जोड़ने के लिए एक बंद करें। | Chaar sounds baj rahi hain. Nayi add karne ke liye ek band karein. |  |
| `sounds_play` | Play | चलाएँ | Play |  |
| `sounds_pause` | Pause | रोकें | Pause |  |
| `sounds_stop` | Stop | बंद करें | Stop |  |
| `sounds_timer` | Timer | टाइमर | Timer |  |
| `sounds_timerTitle` | Fade out after | कितनी देर बाद धीरे-धीरे बंद हो | Kitni der baad dheere-dheere band ho |  |
| `sounds_timerOff` | Off | बंद | Off |  |
| `sounds_timerValue` | Timer · {value} | टाइमर · {value} | Timer · {value} |  |
| `sounds_timerLeft` | {minutes, plural, =1{Fades out in about 1 minute} other{Fades out in about {minutes} minutes}} | {minutes, plural, =1{लगभग 1 मिनट में धीरे-धीरे बंद होगा} other{लगभग {minutes} मिनट में धीरे-धीरे बंद होगा}} | {minutes, plural, =1{Lagbhag 1 minute mein dheere-dheere band hoga} other{Lagbhag {minutes} minute mein dheere-dheere band hoga}} |  |
| `sounds_fadingOut` | Fading out | धीरे-धीरे बंद हो रहा है | Dheere-dheere band ho raha hai |  |
| `sounds_saveMix` | Save this mix | यह मिक्स सेव करें | Ye mix save karein |  |
| `sounds_savedMixes` | Saved mixes | सेव किए गए मिक्स | Save kiye gaye mix |  |
| `sounds_mixSaved` | Saved on this phone. | इस फ़ोन पर सेव हो गया। | Is phone par save ho gaya. |  |
| `sounds_mixAlreadySaved` | This mix is already saved. | यह मिक्स पहले से सेव है। | Ye mix pehle se save hai. |  |
| `sounds_playMix` | Play {mix} | {mix} चलाएँ | {mix} play karein |  |
| `sounds_removeMix` | Remove {mix} | {mix} हटाएँ | {mix} hatayein |  |
| `sounds_mixUnavailable` | This mix can't play right now. | यह मिक्स अभी नहीं चल सकता। | Ye mix abhi play nahi ho sakta. |  |
| `sounds_downloadTitle` | Recorded sounds | रिकॉर्ड की गई आवाज़ें | Recorded sounds |  |
| `sounds_downloadBody` | {size} to download once. After that they play offline. Until then, sounds made on your phone play instead. | एक बार {size} डाउनलोड करना है। उसके बाद ये बिना इंटरनेट के बजती हैं। तब तक आपके फ़ोन पर बनी आवाज़ें बजती हैं। | Ek baar {size} download karna hai. Uske baad ye bina internet ke bajti hain. Tab tak aapke phone par bani sounds bajti hain. |  |
| `sounds_download` | Download | डाउनलोड करें | Download karein |  |
| `sounds_downloading` | Downloading… | डाउनलोड हो रहा है… | Download ho raha hai… |  |
| `sounds_downloadOffline` | You're offline. Brown noise and the sounds made on your phone play now; recordings can download later. | आप ऑफ़लाइन हैं। ब्राउन नॉइज़ और आपके फ़ोन पर बनी आवाज़ें अभी बजती हैं; रिकॉर्डिंग बाद में डाउनलोड करना मुमकिन है। | Aap offline hain. Brown noise aur aapke phone par bani sounds abhi bajti hain; recordings ka download baad mein ho sakta hai. |  |
| `sounds_downloadFailed` | The download didn't finish. Nothing is lost; you can download again later. | डाउनलोड पूरा नहीं हुआ। कुछ नहीं खोया; बाद में फिर से डाउनलोड करना मुमकिन है। | Download poora nahi hua. Kuch nahi khoya; baad mein phir se download karna mumkin hai. |  |
| `sounds_noSpace` | Sounds need about {size}. Free some space, or play brown noise, which needs none. | आवाज़ों के लिए लगभग {size} जगह चाहिए। थोड़ी जगह ख़ाली करें, या ब्राउन नॉइज़ चलाएँ, जिसे जगह की ज़रूरत नहीं। | Sounds ke liye lagbhag {size} jagah chahiye. Thodi jagah khaali karein, ya brown noise chalayein, jise jagah ki zaroorat nahi. |  |
| `sounds_megabytes` | {size} MB | {size} MB | {size} MB |  |
| `sounds_removeDownloads` | Remove downloaded sounds | डाउनलोड की गई आवाज़ें हटाएँ | Download ki gayi sounds hatayein |  |
| `sounds_downloadsRemoved` | Downloaded sounds removed. The sounds made on your phone still play. | डाउनलोड की गई आवाज़ें हटा दी गईं। आपके फ़ोन पर बनी आवाज़ें अब भी बजती हैं। | Download ki gayi sounds hata di gayin. Aapke phone par bani sounds ab bhi bajti hain. |  |

### 5. Insights (linted: REQ-INS-03)

60 keys.

| Key | English | Hindi (`hi`) | Hinglish (`hi-Latn`) | Note |
|---|---|---|---|---|
| `insights_title` | Aura Sky | Aura Sky | Aura Sky |  |
| `insights_private` | Only you can see your sky. It's worked out on this phone. | आपका आसमान सिर्फ़ आपको दिखता है। यह इसी फ़ोन पर तैयार होता है। | Aapka aasmaan sirf aapko dikhta hai. Ye isi phone par banta hai. | Sky = आसमान / hl 'aasmaan' throughout Insights (Aura Sky brand stays English). |
| `insights_empty` | Your sky fills in as you check in. | हर चेक-इन के साथ आपका आसमान भरता जाएगा। | Har check-in ke saath aapka aasmaan bharta jayega. |  |
| `insights_allCheckIns` | All check-ins | सभी चेक-इन | Saare check-in |  |
| `insights_viewMonth` | Month | महीना | Mahina |  |
| `insights_viewYear` | Year | साल | Saal |  |
| `insights_prevMonth` | Previous month | पिछला महीना | Pichhla mahina |  |
| `insights_nextMonth` | Next month | अगला महीना | Agla mahina |  |
| `insights_prevYear` | Previous year | पिछला साल | Pichhla saal |  |
| `insights_nextYear` | Next year | अगला साल | Agla saal |  |
| `insights_dayEmpty` | {date}, quiet sky | {date}, शांत आसमान | {date}, shaant aasmaan |  |
| `insights_dayRest` | {date}, a rest day | {date}, आराम का दिन | {date}, rest day |  |
| `insights_daySingle` | {date}, {quadrant}, {count, plural, =1{1 check-in} other{{count} check-ins}} | {date}, {quadrant}, {count, plural, =1{1 चेक-इन} other{{count} चेक-इन}} | {date}, {quadrant}, {count, plural, =1{1 check-in} other{{count} check-ins}} |  |
| `insights_dayPair` | {date}, {first} and {second} equally, {count, plural, =1{1 check-in} other{{count} check-ins}} | {date}, {first} और {second} बराबर, {count, plural, =1{1 चेक-इन} other{{count} चेक-इन}} | {date}, {first} aur {second} barabar, {count, plural, =1{1 check-in} other{{count} check-ins}} |  |
| `insights_dayMixed` | {date}, an even mix, {count, plural, =1{1 check-in} other{{count} check-ins}} | {date}, सब बराबर-बराबर, {count, plural, =1{1 चेक-इन} other{{count} चेक-इन}} | {date}, barabar ka mix, {count, plural, =1{1 check-in} other{{count} check-ins}} |  |
| `insights_dayHint` | Shows this day's check-ins | इस दिन के चेक-इन दिखाता है | Is din ke check-in dikhata hai |  |
| `insights_dayNone` | Nothing was logged this day. The sky was just quiet. | इस दिन कुछ दर्ज नहीं हुआ। आसमान बस शांत था। | Is din kuch note nahi hua. Aasmaan bas shaant tha. |  |
| `insights_monthSemantic` | {month}, {count, plural, =0{a quiet sky} =1{1 day checked in} other{{count} days checked in}} | {month}, {count, plural, =0{शांत आसमान} =1{1 दिन चेक-इन किया} other{{count} दिन चेक-इन किया}} | {month}, {count, plural, =0{shaant aasmaan} =1{1 din check-in kiya} other{{count} din check-in kiya}} |  |
| `insights_legendRest` | Rest day | आराम का दिन | Rest day |  |
| `insights_legendMixed` | Mixed day | मिला-जुला दिन | Mixed day |  |
| `insights_patternsTitle` | Patterns | पैटर्न | Patterns |  |
| `insights_patternsLast30` | From your last 30 days | आपके पिछले 30 दिनों से | Aapke pichhle 30 din se |  |
| `insights_patternsNeedCheckIns` | Patterns appear after 7 check-ins ({count}/7) | 7 चेक-इन के बाद पैटर्न दिखेंगे ({count}/7) | 7 check-ins ke baad patterns dikhenge ({count}/7) |  |
| `insights_patternsNeedDays` | Patterns appear after check-ins on 5 different days ({count}/5) | 5 अलग-अलग दिनों पर चेक-इन के बाद पैटर्न दिखेंगे ({count}/5) | 5 alag-alag dinon par check-in ke baad patterns dikhenge ({count}/5) |  |
| `insights_patternsNone` | No clear patterns right now. Your sky is still here. | अभी कोई साफ़ पैटर्न नहीं है। आपका आसमान यहीं है। | Abhi koi clear pattern nahi hai. Aapka aasmaan yahin hai. |  |
| `insights_patternTag` | On check-ins with {tag}, {quadrant} showed up more often. | {tag} टैग वाले चेक-इन में {quadrant} वाले चेक-इन ज़्यादा रहे। | {tag} tag wale check-ins mein {quadrant} wale check-in zyada rahe. | All pattern templates use '{quadrant} वाले चेक-इन ज़्यादा रहे' (agrees with चेक-इन) so the verb doesn't depend on the gender of the quadrant name (तूफ़ान m / बारिश f) or the tag/habit. |
| `insights_patternHabit` | On days you did {habit}, {quadrant} showed up more often. | {habit} वाले दिनों में {quadrant} वाले चेक-इन ज़्यादा रहे। | {habit} wale dinon mein {quadrant} wale check-in zyada rahe. | '{habit} वाले दिनों में' avoids a verb agreeing with the habit name's gender. |
| `insights_patternMorning` | In the mornings, {quadrant} showed up more often. | सुबह के समय {quadrant} वाले चेक-इन ज़्यादा रहे। | Subah ke waqt {quadrant} wale check-in zyada rahe. |  |
| `insights_patternAfternoon` | In the afternoons, {quadrant} showed up more often. | दोपहर में {quadrant} वाले चेक-इन ज़्यादा रहे। | Dopahar mein {quadrant} wale check-in zyada rahe. |  |
| `insights_patternEvening` | In the evenings, {quadrant} showed up more often. | शाम को {quadrant} वाले चेक-इन ज़्यादा रहे। | Shaam ko {quadrant} wale check-in zyada rahe. |  |
| `insights_patternNight` | At night, {quadrant} showed up more often. | रात में {quadrant} वाले चेक-इन ज़्यादा रहे। | Raat mein {quadrant} wale check-in zyada rahe. |  |
| `insights_patternMix` | {quadrant} showed up most often in your sky. | आपके आसमान में {quadrant} वाले चेक-इन सबसे ज़्यादा रहे। | Aapke aasmaan mein {quadrant} wale check-in sabse zyada rahe. |  |
| `insights_plusBadge` | Aura Plus | Aura Plus | Aura Plus |  |
| `insights_rangeLocked` | Any range and habits alongside moods come with Aura Plus. Your sky and 30-day patterns are always free. | कोई भी समय-सीमा और मूड के साथ आदतें Aura Plus में मिलती हैं। आपका आसमान और 30 दिन के पैटर्न हमेशा मुफ़्त हैं। | Koi bhi range aur moods ke saath habits Aura Plus mein milti hain. Aapka aasmaan aur 30 din ke patterns hamesha free hain. |  |
| `insights_rangeLabel` | Patterns from | इस अवधि के पैटर्न | Patterns kab se |  |
| `insights_range7` | 7 days | 7 दिन | 7 din |  |
| `insights_range30` | 30 days | 30 दिन | 30 din |  |
| `insights_range90` | 90 days | 90 दिन | 90 din |  |
| `insights_range365` | 1 year | 1 साल | 1 saal |  |
| `insights_rangeAll` | All time | शुरू से अब तक | Shuru se ab tak |  |
| `insights_weeklyTitle` | From your past week | आपके पिछले हफ़्ते से | Aapke pichhle hafte se |  |
| `insights_weeklyHide` | Hide for this week | इस हफ़्ते के लिए छिपाएँ | Is hafte ke liye chhupayein |  |
| `insights_careTitle` | It's been a heavy couple of weeks | पिछले दो हफ़्ते भारी रहे हैं | Pichhle do hafte bhaari rahe hain |  |
| `insights_careBody` | You don't have to carry it alone. Support and a room are here whenever you want them. | यह बोझ अकेले उठाना ज़रूरी नहीं। जब भी मन हो, मदद और एक रूम यहीं हैं। | Ye bojh akele uthana zaroori nahi. Jab bhi mann ho, support aur ek room yahin hain. |  |
| `insights_careSupport` | See support | मदद देखें | Support dekhein | 'Support' = मदद (glossary 'help'); hl keeps 'Support'. |
| `insights_careRoom` | Find a room | एक रूम ढूँढें | Ek room dhoondhein |  |
| `insights_monthTitle` | Your month in stars | तारों में आपका महीना | Taaron mein aapka mahina |  |
| `insights_monthCardBody` | {month} in your sky | आपके आसमान में {month} | Aapke aasmaan mein {month} |  |
| `insights_monthOpen` | Open | खोलें | Kholein |  |
| `insights_monthHide` | Hide | छिपाएँ | Chhupayein |  |
| `insights_monthDays` | {count, plural, =1{1 day checked in} other{{count} days checked in}} | {count, plural, =1{1 दिन चेक-इन किया} other{{count} दिन चेक-इन किया}} | {count, plural, =1{1 din check-in kiya} other{{count} din check-in kiya}} |  |
| `insights_monthMixTitle` | Your skies this month | इस महीने आपका आसमान | Is mahine aapka aasmaan |  |
| `insights_monthMixItem` | {quadrant}: {count, plural, =1{1 check-in} other{{count} check-ins}} | {quadrant}: {count, plural, =1{1 चेक-इन} other{{count} चेक-इन}} | {quadrant}: {count, plural, =1{1 check-in} other{{count} check-ins}} |  |
| `insights_monthSkySemantic` | A sky of {count, plural, =1{1 star} other{{count} stars}}, one for each check-in in {month} | {count, plural, =1{1 तारे का आसमान} other{{count} तारों का आसमान}}, {month} के हर चेक-इन के लिए एक तारा | {count, plural, =1{1 taare ka aasmaan} other{{count} taaron ka aasmaan}}, {month} ke har check-in ke liye ek taara |  |
| `insights_deeperTitle` | Deeper monthly review | महीने की गहरी झलक | Mahine ka deeper review |  |
| `insights_deeperLocked` | Patterns across the month, with habits alongside moods, come with Aura Plus. | पूरे महीने के पैटर्न, मूड के साथ आदतें, Aura Plus में मिलते हैं। | Poore mahine ke patterns, moods ke saath habits, Aura Plus mein milte hain. |  |
| `insights_deeperNone` | No clear patterns this month. | इस महीने कोई साफ़ पैटर्न नहीं। | Is mahine koi clear pattern nahi. |  |
| `insights_statsTitle` | All time | शुरू से अब तक | Shuru se ab tak |  |
| `insights_statsCheckIns` | {count, plural, =1{1 check-in} other{{count} check-ins}} | {count, plural, =1{1 चेक-इन} other{{count} चेक-इन}} | {count, plural, =1{1 check-in} other{{count} check-ins}} |  |
| `insights_statsDays` | {count, plural, =1{1 day in your sky} other{{count} days in your sky}} | {count, plural, =1{आपके आसमान में 1 दिन} other{आपके आसमान में {count} दिन}} | {count, plural, =1{Aapke aasmaan mein 1 din} other{Aapke aasmaan mein {count} din}} |  |

### 6. Rooms, Lantern Hour and tonight's intention

169 keys.

| Key | English | Hindi (`hi`) | Hinglish (`hi-Latn`) | Note |
|---|---|---|---|---|
| `rooms_lanternTitle` | Tonight's lantern | आज रात की लालटेन | Aaj raat ki lantern | 'lantern' → hi लालटेन (sky-lantern image; alt: कंदील). hl keeps 'lantern'. Used consistently across lantern keys. |
| `rooms_lanternStart` | Every gesture here adds a little light. | यहाँ हर भाव थोड़ी रोशनी जोड़ता है। | Yahan har gesture thodi roshni jodta hai. |  |
| `rooms_lanternGlowing` | It glows brighter with every gesture here. | यहाँ हर भाव के साथ यह और रोशन होती है। | Yahan har gesture ke saath yeh aur roshan hoti hai. |  |
| `rooms_lanternFull` | Fully lit, together. | सबने मिलकर, पूरी रोशन की। | Sabne milkar, poori roshan ki. |  |
| `rooms_lanternKept` | Tonight's lantern glowed this bright. | आज रात की लालटेन इतनी रोशन हुई। | Aaj raat ki lantern itni roshan hui. |  |
| `rooms_lanternSemantic` | Tonight's lantern, {level} of {max} lights lit | आज रात की लालटेन, {max} में से {level} रोशनियाँ जलीं | Aaj raat ki lantern, {max} mein se {level} roshniyan jali |  |
| `rooms_lanternRise` | The lantern is fully lit. Lanterns rise, together. | लालटेन पूरी रोशन हो गई। लालटेनें साथ मिलकर ऊपर उठती हैं। | Lantern poori roshan ho gayi. Lanterns saath milkar upar uthti hain. |  |
| `rooms_intentionTitle` | Tonight's intention | आज रात का इरादा | Aaj raat ka irada |  |
| `rooms_intentionHold` | Hold this tonight | आज रात इसे थामें | Aaj raat ise thaamein |  |
| `rooms_intentionHolding` | You're holding this tonight | आज रात यह इरादा आपके साथ है | Aaj raat yeh irada aapke saath hai | Rephrased as 'this intention is with you tonight' to avoid gendered थामे हुए/रहे/रही. |
| `rooms_intentionHolds` | {count, plural, =0{Hold it with one tap} =1{1 holding this tonight} other{{count} holding this tonight}} | {count, plural, =0{एक टैप से थामें} =1{आज रात 1 ने इसे थामा है} other{आज रात {count} ने इसे थामा है}} | {count, plural, =0{Ek tap se thaamein} =1{Aaj raat 1 ne ise thaama hai} other{Aaj raat {count} ne ise thaama hai}} | Rendered as 'N ne ise thaama hai' (ergative, agrees with the intention, so no gender for the holders). |
| `rooms_intentionHeld` | {count, plural, =0{Resting until the next Lantern Hour} =1{1 held this tonight} other{{count} held this tonight}} | {count, plural, =0{अगले Lantern Hour तक आराम} =1{आज रात 1 ने इसे थामा} other{आज रात {count} ने इसे थामा}} | {count, plural, =0{Agle Lantern Hour tak aaram} =1{Aaj raat 1 ne ise thaama} other{Aaj raat {count} ne ise thaama}} |  |
| `rooms_intentionPrivate` | Nobody sees who holds it, and nobody will ask about it tomorrow. | इसे किसने थामा, यह किसी को नहीं दिखता, और कल इसके बारे में कोई नहीं पूछेगा। | Ise kisne thaama, yeh kisi ko nahi dikhta, aur kal iske baare mein koi nahi poochhega. |  |
| `rooms_intentionFailed` | That didn't go through. Please try again. | यह हो नहीं पाया। कृपया फिर से कोशिश करें। | Yeh ho nahi paaya. Please phir se try karein. |  |
| `rooms_intention_sleep_before_midnight` | Sleep before midnight | आधी रात से पहले सोना | Aadhi raat se pehle sona |  |
| `rooms_intention_gentle_with_myself` | Be gentle with myself tonight | आज रात खुद से नरमी | Aaj raat khud se narmi |  |
| `rooms_intention_phone_down_10` | Phone down for 10 minutes | 10 मिनट फ़ोन से दूरी | 10 minute phone se doori |  |
| `rooms_intention_water_before_bed` | A glass of water before bed | सोने से पहले एक गिलास पानी | Sone se pehle ek glass paani |  |
| `rooms_intention_one_kind_thought` | One kind thought about today | आज के बारे में एक अच्छा ख्याल | Aaj ke baare mein ek achha khayal | 'kind thought' → अच्छा ख्याल / achha khayal (gentle, positive thought about the day). |
| `rooms_intention_slow_breaths` | Three slow breaths before sleep | सोने से पहले तीन धीमी साँसें | Sone se pehle teen dheemi saansein |  |
| `rooms_paused` | Rooms are resting for a bit. Try again later. | रूम कुछ देर आराम कर रहे हैं। थोड़ी देर बाद फिर से कोशिश करें। | Rooms kuch der aaram kar rahe hain. Thodi der baad phir se try karein. |  |
| `rooms_pausedJoin` | Rooms are resting for a bit. Your check-in is saved. | रूम कुछ देर आराम कर रहे हैं। आपका चेक-इन सेव हो गया है। | Rooms kuch der aaram kar rahe hain. Aapka check-in save ho gaya hai. |  |
| `rooms_title` | Rooms | रूम | Rooms |  |
| `rooms_yourRooms` | Your rooms | आपके रूम | Aapke rooms |  |
| `rooms_memories` | Memories | यादें | Memories | hi यादें; hl keeps 'Memories' (memory/memories used throughout hl, याद/यादें in hi). |
| `rooms_whatTitle` | What rooms are | रूम क्या हैं | Rooms kya hain |  |
| `rooms_whatBody` | A small room of people who feel like you do right now, for a day. | अभी आप जैसा महसूस करने वाले कुछ लोगों का एक छोटा रूम, एक दिन के लिए। | Abhi aap jaisa feel karne wale kuch logon ka ek chhota room, ek din ke liye. |  |
| `rooms_pointName` | A fresh name in every room. Nobody sees your account. | हर रूम में एक नया नाम। आपका अकाउंट किसी को नहीं दिखता। | Har room mein ek naya naam. Aapka account kisi ko nahi dikhta. |  |
| `rooms_pointGestures` | No messages or DMs: only eight warm gestures. | कोई मैसेज या DM नहीं: सिर्फ़ आठ अपनेपन भरे भाव। | Koi message ya DM nahi: sirf aath warm gestures. |  |
| `rooms_pointTime` | Rooms last a day, then rest as a memory for 7 days. | रूम एक दिन चलते हैं, फिर 7 दिन याद बनकर रहते हैं। | Rooms ek din chalte hain, phir 7 din memory bankar rehte hain. |  |
| `rooms_lanternNote` | Lantern Hour: every night from 9 to 11 on your region's clock, rooms light a shared lantern and more people drop in. | Lantern Hour: हर रात आपके इलाके के समय से 9 से 11 बजे तक, रूम मिलकर एक लालटेन जलाते हैं और ज़्यादा लोग आते हैं। | Lantern Hour: har raat aapke region ke time se 9 se 11 baje tak, rooms milkar ek lantern jalaate hain aur zyada log aate hain. |  |
| `rooms_lanternNow` | Lantern Hour is on now | अभी Lantern Hour चल रहा है | Abhi Lantern Hour chal raha hai |  |
| `rooms_checkInCta` | Check in to find a room | रूम ढूँढने के लिए चेक-इन करें | Room dhoondhne ke liye check-in karein |  |
| `rooms_empty` | You're not in a room right now. After a check-in you can join people who feel the same. | आप अभी किसी रूम में नहीं हैं। चेक-इन के बाद अपने जैसा महसूस करने वालों से जुड़ना मुमकिन है। | Aap abhi kisi room mein nahi hain. Check-in ke baad apne jaisa feel karne walon se judna mumkin hai. | 'you can join' rephrased to 'judna mumkin hai' to avoid सकते/सकती. |
| `rooms_offline` | Rooms need a connection. Your own check-ins still save on this phone. | रूम के लिए कनेक्शन चाहिए। आपके अपने चेक-इन इस फ़ोन पर सेव होते रहेंगे। | Rooms ke liye connection chahiye. Aapke apne check-in is phone par save hote rahenge. |  |
| `rooms_loadFailed` | We couldn't reach the rooms just now. | अभी रूम तक पहुँचना नहीं हो पाया। | Abhi rooms tak pahunchna nahi ho paaya. |  |
| `rooms_tryAgain` | Try again | फिर से कोशिश करें | Phir se try karein |  |
| `rooms_signedOut` | Rooms open once you're signed in. | साइन इन करने के बाद रूम खुलते हैं। | Sign in karne ke baad rooms khulte hain. |  |
| `rooms_signIn` | Sign in | साइन इन करें | Sign in karein |  |
| `rooms_suspended` | Rooms are paused for your account right now. Help is always here. | अभी आपके अकाउंट के लिए रूम रुके हुए हैं। मदद हमेशा यहाँ है। | Abhi aapke account ke liye rooms ruke hue hain. Madad hamesha yahan hai. |  |
| `rooms_suspendedUntil` | Rooms are paused for your account until {date}. Help is always here. | {date} तक आपके अकाउंट के लिए रूम रुके हुए हैं। मदद हमेशा यहाँ है। | {date} tak aapke account ke liye rooms ruke hue hain. Madad hamesha yahan hai. |  |
| `rooms_accountClosed` | This account was closed for breaking Aura's rules. | Aura के नियम तोड़ने की वजह से यह अकाउंट बंद कर दिया गया। | Aura ke rules todne ki wajah se yeh account band kar diya gaya. |  |
| `rooms_profilePending` | Rooms open once your account finishes setting up. Try again in a moment. | आपके अकाउंट का सेटअप पूरा होते ही रूम खुलेंगे। थोड़ी देर में फिर से कोशिश करें। | Aapke account ka setup poora hote hi rooms khulenge. Thodi der mein phir se try karein. |  |
| `rooms_openHint` | Opens the room | रूम खोलता है | Room kholta hai |  |
| `rooms_memoryUntil` | A memory until {date} | {date} तक एक याद | {date} tak ek memory |  |
| `rooms_theme_lighthouse` | The Lighthouse | प्रकाश स्तंभ | The Lighthouse |  |
| `rooms_theme_rain_sanctuary` | The Rain Sanctuary | बारिश का ठिकाना | The Rain Sanctuary |  |
| `rooms_theme_midnight_observatory` | The Midnight Observatory | आधी रात की वेधशाला | The Midnight Observatory |  |
| `rooms_theme_sunrise_deck` | The Sunrise Deck | सूर्योदय की छत | The Sunrise Deck |  |
| `rooms_gesture_warm_tea` | Warm Tea | एक कप चाय | Ek cup chai |  |
| `rooms_gesture_light_a_candle` | Light a Candle | एक दीया | Ek diya |  |
| `rooms_gesture_hug` | Hug | झप्पी | Jhappi |  |
| `rooms_gesture_me_too` | Me Too | मैं भी | Main bhi |  |
| `rooms_gesture_soft_rain` | Soft Rain | हल्की फुहार | Halki phuhaar |  |
| `rooms_gesture_stargaze` | Stargaze | तारे देखें | Taare dekhein |  |
| `rooms_gesture_deep_breath` | Deep Breath | गहरी साँस | Gehri saans |  |
| `rooms_gesture_youre_not_alone` | You're Not Alone | कोई साथ है | Koi saath hai |  |
| `rooms_hereNow` | {count, plural, =0{Nobody here right now} =1{1 here now} other{{count} here now}} | {count, plural, =0{अभी यहाँ कोई नहीं है} =1{अभी यहाँ 1 है} other{अभी यहाँ {count} हैं}} | {count, plural, =0{Abhi yahan koi nahi hai} =1{Abhi yahan 1 hai} other{Abhi yahan {count} hain}} |  |
| `rooms_today` | {count, plural, =1{1 person has been here today} other{{count} people have been here today}} | {count, plural, =1{आज 1 व्यक्ति यहाँ आ चुका है} other{आज {count} लोग यहाँ आ चुके हैं}} | {count, plural, =1{Aaj 1 person yahan aa chuka hai} other{Aaj {count} log yahan aa chuke hain}} |  |
| `rooms_countsSemantic` | {now, plural, =1{1 person here now} other{{now} people here now}}, {today, plural, =1{1 today} other{{today} today}} | {now, plural, =1{अभी यहाँ 1 व्यक्ति} other{अभी यहाँ {now} लोग}}, {today, plural, =1{आज 1} other{आज {today}}} | {now, plural, =1{Abhi yahan 1 person} other{Abhi yahan {now} log}}, {today, plural, =1{aaj 1} other{aaj {today}}} |  |
| `rooms_stripSemantic` | {theme}, {count, plural, =1{1 person here now} other{{count} people here now}} | {theme}, {count, plural, =1{अभी यहाँ 1 व्यक्ति} other{अभी यहाँ {count} लोग}} | {theme}, {count, plural, =1{abhi yahan 1 person} other{abhi yahan {count} log}} |  |
| `rooms_opening` | Opening the room… | रूम खुल रहा है… | Room khul raha hai… |  |
| `rooms_youAre` | You're {pseudonym} here | यहाँ आप {pseudonym} हैं | Yahan aap {pseudonym} hain |  |
| `rooms_coldStart` | {count, plural, =1{You're the first here today. Leave a light for the next one.} other{{count} people have been here today. Leave a light for the next one.}} | {count, plural, =1{आज यहाँ सबसे पहले आप हैं। अगले आने वाले के लिए एक रोशनी छोड़ जाएँ।} other{आज {count} लोग यहाँ आ चुके हैं। अगले आने वाले के लिए एक रोशनी छोड़ जाएँ।}} | {count, plural, =1{Aaj yahan sabse pehle aap hain. Agle aane wale ke liye ek roshni chhod jaayein.} other{Aaj {count} log yahan aa chuke hain. Agle aane wale ke liye ek roshni chhod jaayein.}} |  |
| `rooms_lanternOn` | Lantern Hour · until {time} | Lantern Hour · {time} तक | Lantern Hour · {time} tak |  |
| `rooms_closing` | This room becomes a memory at {time}. | यह रूम {time} पर याद बन जाएगा। | Yeh room {time} par memory ban jayega. |  |
| `rooms_memory` | This room has become a memory. You can look back for 7 days. | यह रूम अब एक याद बन गया है। 7 दिन तक इसे फिर से देखा जा सकता है। | Yeh room ab ek memory ban gaya hai. 7 din tak ise phir se dekha ja sakta hai. |  |
| `rooms_findNew` | Find a new room | नया रूम ढूँढें | Naya room dhoondhein |  |
| `rooms_reconnecting` | Reconnecting… | फिर से जुड़ रहा है… | Phir se connect ho raha hai… |  |
| `rooms_membersTitle` | Here with you | यहाँ आपके साथ | Yahan aapke saath |  |
| `rooms_you` | You | आप | Aap |  |
| `rooms_memberHereNow` | here now | अभी यहाँ | abhi yahan |  |
| `rooms_memberAway` | away for now | अभी दूर | abhi door |  |
| `rooms_memberMuted` | muted for you | आपके लिए म्यूट | aapke liye mute |  |
| `rooms_memberLabel` | {pseudonym}, {mood}, {status} | {pseudonym}, {mood}, {status} | {pseudonym}, {mood}, {status} |  |
| `rooms_youLabel` | You, {pseudonym}, {mood} | आप, {pseudonym}, {mood} | Aap, {pseudonym}, {mood} |  |
| `rooms_memberHint` | Opens options | विकल्प खोलता है | Options kholta hai |  |
| `rooms_recentTitle` | Warmth in this room | इस रूम में अपनापन | Is room mein warmth |  |
| `rooms_receivedLine` | {pseudonym} sent you {gesture} | {pseudonym} ने आपको {gesture} भेजा | {pseudonym} ne aapko {gesture} bheja |  |
| `rooms_sentToMember` | {gesture} sent to {pseudonym} | {gesture} {pseudonym} को भेजा गया | {gesture} {pseudonym} ko bheja gaya |  |
| `rooms_sentToRoom` | {gesture} sent to everyone here | {gesture} यहाँ सबको भेजा गया | {gesture} yahan sabko bheja gaya |  |
| `rooms_someoneSent` | Someone sent {gesture} | किसी ने {gesture} भेजा | Kisi ne {gesture} bheja |  |
| `rooms_someoneSentRoom` | Someone sent {gesture} to everyone here | किसी ने यहाँ सबको {gesture} भेजा | Kisi ne yahan sabko {gesture} bheja |  |
| `rooms_youSentMember` | You sent {gesture} to {pseudonym} | आपने {pseudonym} को {gesture} भेजा | Aapne {pseudonym} ko {gesture} bheja |  |
| `rooms_youSentRoom` | You sent {gesture} to everyone here | आपने यहाँ सबको {gesture} भेजा | Aapne yahan sabko {gesture} bheja |  |
| `rooms_trayTitle` | Send warmth to everyone here | यहाँ सबको अपनापन भेजें | Yahan sabko warmth bhejein |  |
| `rooms_trayHint` | Sends to everyone here | यहाँ सबको भेजता है | Yahan sabko bhejta hai |  |
| `rooms_trayResting` | Gestures rest in a memory. You can still report, block or mute. | याद में भाव आराम करते हैं। रिपोर्ट, ब्लॉक या म्यूट अब भी किया जा सकता है। | Memory mein gestures aaram karte hain. Report, block ya mute ab bhi kiya ja sakta hai. |  |
| `rooms_roomOptions` | Room options | रूम के विकल्प | Room options |  |
| `rooms_reportRoom` | Report a problem here | यहाँ की कोई समस्या रिपोर्ट करें | Yahan ki koi problem report karein |  |
| `rooms_leave` | Leave this room | यह रूम छोड़ें | Yeh room chhodein |  |
| `rooms_removeMemory` | Remove from my rooms | मेरे रूम से हटाएँ | Mere rooms se hatayein |  |
| `rooms_leaveTitle` | Leave this room? | यह रूम छोड़ना है? | Yeh room chhodna hai? |  |
| `rooms_leaveBody` | You won't be able to come back to it, and your seat opens up for someone else. Your next check-in can find you a new room. | इस रूम में वापस आना मुमकिन नहीं होगा, और आपकी जगह किसी और के लिए खुल जाएगी। आपका अगला चेक-इन आपके लिए नया रूम ढूँढ सकता है। | Is room mein wapas aana mumkin nahi hoga, aur aapki jagah kisi aur ke liye khul jayegi. Aapka agla check-in aapke liye naya room dhoondh sakta hai. | 'You won't be able to come back' rephrased impersonally (वापस आना मुमकिन नहीं होगा) to avoid पाएँगे/पाएँगी. |
| `rooms_leaveConfirm` | Leave room | रूम छोड़ें | Room chhodein |  |
| `rooms_stay` | Stay | यहीं रहें | Yahin rahein |  |
| `rooms_removeTitle` | Remove this memory? | यह याद हटानी है? | Yeh memory hatani hai? |  |
| `rooms_removeBody` | It leaves your rooms now. Memories close for good after 7 days anyway. | यह अभी आपके रूम से हट जाएगी। वैसे भी यादें 7 दिन बाद हमेशा के लिए बंद हो जाती हैं। | Yeh abhi aapke rooms se hat jayegi. Waise bhi memories 7 din baad hamesha ke liye band ho jaati hain. |  |
| `rooms_removeConfirm` | Remove | हटाएँ | Hatayein |  |
| `rooms_keep` | Keep it | रहने दें | Rehne dein |  |
| `rooms_leaveFailed` | That didn't go through. You're still in the room. | यह हो नहीं पाया। आप अभी भी रूम में हैं। | Yeh ho nahi paaya. Aap abhi bhi room mein hain. |  |
| `rooms_gone` | This room has closed. Rooms rest for 7 days as memories, then they're gone. | यह रूम बंद हो गया है। रूम 7 दिन याद बनकर रहते हैं, फिर चले जाते हैं। | Yeh room band ho gaya hai. Rooms 7 din memory bankar rehte hain, phir chale jaate hain. |  |
| `rooms_backToRooms` | Back to your rooms | अपने रूम पर वापस | Apne rooms par wapas |  |
| `rooms_offlineRoom` | Rooms need a connection. This room opens again when you're back online. | रूम के लिए कनेक्शन चाहिए। ऑनलाइन वापस आते ही यह रूम फिर खुलेगा। | Rooms ke liye connection chahiye. Online wapas aate hi yeh room phir khulega. |  |
| `rooms_joinTitle` | Finding your room | आपका रूम ढूँढा जा रहा है | Aapka room dhoondha ja raha hai |  |
| `rooms_finding` | Finding people who feel this way right now… | अभी ऐसा ही महसूस करने वाले लोग ढूँढे जा रहे हैं… | Abhi aisa hi feel karne wale log dhoondhe ja rahe hain… |  |
| `rooms_offlineJoin` | Rooms need a connection. Your check-in is saved. | रूम के लिए कनेक्शन चाहिए। आपका चेक-इन सेव हो गया है। | Rooms ke liye connection chahiye. Aapka check-in save ho gaya hai. |  |
| `rooms_joinFailed` | We couldn't reach the rooms just now. Your check-in is saved. | अभी रूम तक पहुँचना नहीं हो पाया। आपका चेक-इन सेव हो गया है। | Abhi rooms tak pahunchna nahi ho paaya. Aapka check-in save ho gaya hai. |  |
| `rooms_joinLimit` | That's 3 new rooms for this feeling today. The rooms you're in are still open to you. | आज इस एहसास के लिए 3 नए रूम हो चुके हैं। जिन रूम में आप हैं, वे अभी भी आपके लिए खुले हैं। | Aaj is feeling ke liye 3 naye rooms ho chuke hain. Jin rooms mein aap hain, woh abhi bhi aapke liye khule hain. |  |
| `rooms_seeYourRooms` | See your rooms | अपने रूम देखें | Apne rooms dekhein |  |
| `rooms_poolUnavailable` | Hindi and Hinglish rooms are opening soon. Join an English room for now? | हिंदी और हिंग्लिश रूम जल्द खुलेंगे। अभी के लिए अंग्रेज़ी रूम में जुड़ें? | Hindi aur Hinglish rooms jald khulenge. Abhi ke liye English room join karein? | hi uses हिंदी/हिंग्लिश/अंग्रेज़ी in Devanagari; hl keeps Hindi/Hinglish/English. |
| `rooms_poolJoinEnglish` | Join English room | अंग्रेज़ी रूम में जुड़ें | English room join karein |  |
| `rooms_poolNotify` | Tell me when they open | खुलने पर मुझे बताएँ | Khulne par mujhe batayein |  |
| `rooms_poolNotifyDone` | We'll let you know here when Hindi and Hinglish rooms open. | हिंदी और हिंग्लिश रूम खुलने पर हम आपको यहीं बताएँगे। | Hindi aur Hinglish rooms khulne par hum aapko yahin batayenge. |  |
| `rooms_noRequest` | Rooms open from a check-in. | रूम चेक-इन से खुलते हैं। | Rooms check-in se khulte hain. |  |
| `rooms_offer` | Join a room of people feeling this | ऐसा ही महसूस करने वालों के रूम में जुड़ें | Aisa hi feel karne walon ke room mein judein |  |
| `rooms_offerHint` | Opens a room, with a fresh name just for it | एक रूम खोलता है, सिर्फ़ उसी के लिए नए नाम के साथ | Ek room kholta hai, sirf usi ke liye naye naam ke saath |  |
| `rooms_offerOffline` | Rooms open when you're back online | ऑनलाइन वापस आने पर रूम खुलेंगे | Online wapas aane par rooms khulenge |  |
| `rooms_offerLater` | Rooms are in the Rooms tab whenever you'd like company. | जब भी किसी के साथ का मन हो, रूम टैब में रूम मिलेंगे। | Jab bhi kisi ke saath ka mann ho, Rooms tab mein rooms milenge. |  |
| `rooms_guidelinesTitle` | Before your first room | आपके पहले रूम से पहले | Aapke pehle room se pehle |  |
| `rooms_guidelinesIntro` | Rooms stay gentle because everyone keeps to a few simple things: | रूम सुकून भरे रहते हैं, क्योंकि हर कोई कुछ आसान बातों का ध्यान रखता है: | Rooms sukoon bhare rehte hain, kyunki har koi kuch aasaan baaton ka dhyaan rakhta hai: |  |
| `rooms_rule1` | Be kind. Everyone here is having a real day. | अच्छे से पेश आएँ। यहाँ हर कोई सच में अपना दिन जी रहा है। | Achhe se pesh aayein. Yahan har koi sach mein apna din jee raha hai. | 'Be kind' → 'अच्छे से पेश आएँ' (treat people well); 'having a real day' → 'सच में अपना दिन जी रहा है'. |
| `rooms_rule2` | No hate about caste, religion, gender, sexuality or anything else. | जाति, धर्म, जेंडर, सेक्शुअलिटी या किसी भी और चीज़ को लेकर कोई नफ़रत नहीं। | Jaati, dharm, gender, sexuality ya kisi bhi aur cheez ko lekar koi hate nahi. |  |
| `rooms_rule3` | No sexual content. | कोई सेक्शुअल कंटेंट नहीं। | Koi sexual content nahi. |  |
| `rooms_rule4` | Never share or ask for contact details or meet-ups, or anyone's age, school, city or photos. | कॉन्टैक्ट डिटेल्स, मिलने की बात, या किसी की उम्र, स्कूल, शहर या फ़ोटो कभी न शेयर करें, न माँगें। | Contact details, milne ki baat, ya kisi ki umar, school, sheher ya photos kabhi na share karein, na maangein. |  |
| `rooms_rule5` | No selling or spam. | कोई बिक्री या स्पैम नहीं। | Koi selling ya spam nahi. |  |
| `rooms_rule6` | Never encourage anyone to hurt themselves. Talking about how you feel is always okay. | किसी को भी खुद को चोट पहुँचाने के लिए कभी न उकसाएँ। अपने मन की बात कहना हमेशा ठीक है। | Kisi ko bhi khud ko chot pahunchane ke liye kabhi na uksaayein. Apne mann ki baat kehna hamesha theek hai. |  |
| `rooms_guidelinesSafety` | You can report, block or mute anyone, and help is always one tap away. | किसी को भी रिपोर्ट, ब्लॉक या म्यूट किया जा सकता है, और मदद हमेशा बस एक टैप दूर है। | Kisi ko bhi report, block ya mute kiya ja sakta hai, aur madad hamesha bas ek tap door hai. | 'You can report…' → passive 'kiya ja sakta hai' to avoid सकते/सकती. |
| `rooms_guidelinesAgree` | I'll keep to these | मंज़ूर है, इनका ध्यान रहेगा | Manzoor hai, inka dhyaan rahega | First-person promise made neutral: 'Accepted, I'll keep these in mind' (मंज़ूर है, इनका ध्यान रहेगा) instead of करूँगा/करूँगी. |
| `rooms_guidelinesUpdate` | Rooms have new community guidelines. Update Aura to read them before your next room. | रूम की कम्युनिटी गाइडलाइंस नई हैं। अगले रूम से पहले इन्हें पढ़ने के लिए Aura अपडेट करें। | Rooms ki community guidelines nayi hain. Agle room se pehle inhein padhne ke liye Aura update karein. |  |
| `rooms_sendTo` | Send {pseudonym} some warmth | {pseudonym} को थोड़ा अपनापन भेजें | {pseudonym} ko thodi warmth bhejein |  |
| `rooms_gestureHintMember` | Sends to {pseudonym} | {pseudonym} को भेजता है | {pseudonym} ko bhejta hai |  |
| `rooms_report` | Report | रिपोर्ट करें | Report karein |  |
| `rooms_block` | Block | ब्लॉक करें | Block karein |  |
| `rooms_mute` | Mute | म्यूट करें | Mute karein |  |
| `rooms_unmute` | Unmute | अनम्यूट करें | Unmute karein |  |
| `rooms_safetyNote` | They're never told who reported, blocked or muted them. | उन्हें कभी नहीं बताया जाता कि किसने उन्हें रिपोर्ट, ब्लॉक या म्यूट किया। | Unhein kabhi nahi bataya jaata ki kisne unhein report, block ya mute kiya. |  |
| `rooms_blockTitle` | Block {pseudonym}? | {pseudonym} को ब्लॉक करें? | {pseudonym} ko block karein? |  |
| `rooms_blockBody` | You won't be placed in a room together again, and gestures between you stop. They won't be told. | आप दोनों को फिर कभी एक रूम में नहीं रखा जाएगा, और आपके बीच भावों का आना-जाना बंद हो जाएगा। उन्हें इस बारे में नहीं बताया जाएगा। | Aap dono ko phir kabhi ek room mein nahi rakha jayega, aur aapke beech gestures band ho jayenge. Unhein is baare mein nahi bataya jayega. |  |
| `rooms_blocked` | {pseudonym} is blocked. You won't share a room again. | {pseudonym} को ब्लॉक कर दिया गया। अब आप दोनों को एक रूम में नहीं रखा जाएगा। | {pseudonym} ko block kar diya gaya. Ab aap dono ko ek room mein nahi rakha jayega. | Passive (को ब्लॉक कर दिया गया) so neither the pseudonym nor the user gets gendered agreement. |
| `rooms_muted` | {pseudonym} is muted for you. Their gestures won't reach you here. | {pseudonym} को आपके लिए म्यूट कर दिया गया। यहाँ उनके भाव आप तक नहीं पहुँचेंगे। | {pseudonym} ko aapke liye mute kar diya gaya. Yahan unke gestures aap tak nahi pahunchenge. |  |
| `rooms_unmuted` | {pseudonym} is unmuted. | {pseudonym} को अनम्यूट कर दिया गया। | {pseudonym} ko unmute kar diya gaya. |  |
| `rooms_undo` | Undo | वापस लें | Undo | hi 'वापस लें' (common Android undo label); hl keeps 'Undo'. |
| `rooms_actionFailed` | That didn't go through. Try again in a moment. | यह हो नहीं पाया। थोड़ी देर में फिर से कोशिश करें। | Yeh ho nahi paaya. Thodi der mein phir se try karein. |  |
| `rooms_reportMember` | Report {pseudonym} | {pseudonym} को रिपोर्ट करें | {pseudonym} ko report karein |  |
| `rooms_reportGesture` | Report this gesture | इस भाव को रिपोर्ट करें | Is gesture ko report karein |  |
| `rooms_reportWhy` | What's happening? | क्या हो रहा है? | Kya ho raha hai? |  |
| `rooms_reason2` | Harassment or bullying | तंग करना या बुलिंग | Harassment ya bullying |  |
| `rooms_reason3` | Sexual content or advances | सेक्शुअल कंटेंट या छेड़खानी | Sexual content ya advances | hi 'advances' → छेड़खानी (unwanted sexual advances); please confirm register. |
| `rooms_reason4` | Hate or slurs | नफ़रत या अपमानजनक शब्द | Hate ya slurs | hi 'slurs' → अपमानजनक शब्द; hl keeps English 'slurs' as in te-Latn. |
| `rooms_reason5` | Contact details or personal info | कॉन्टैक्ट डिटेल्स या निजी जानकारी | Contact details ya personal info |  |
| `rooms_reason6` | Spam or selling | स्पैम या बिक्री | Spam ya selling |  |
| `rooms_reason7` | Someone may be under 13 | शायद किसी की उम्र 13 से कम है | Shayad kisi ki umar 13 se kam hai |  |
| `rooms_reason8` | Something else | कुछ और | Kuch aur |  |
| `rooms_reason9` | Seems to be targeting a young person | लगता है किसी कम उम्र के इंसान को निशाना बनाया जा रहा है | Lagta hai kisi kam umar ke insaan ko target kiya ja raha hai |  |
| `rooms_reportNoteLabel` | Anything a moderator should know? (optional) | मॉडरेटर को कुछ बताना है? (ज़रूरी नहीं) | Moderator ko kuch batana hai? (optional) |  |
| `rooms_reportNoteHelp` | Only Aura's moderators read this. Please leave out phone numbers, links and handles. | इसे सिर्फ़ Aura के मॉडरेटर पढ़ते हैं। कृपया फ़ोन नंबर, लिंक और हैंडल न लिखें। | Ise sirf Aura ke moderators padhte hain. Please phone number, links aur handles na likhein. |  |
| `rooms_reportNoteContact` | Phone numbers, links and handles can't be shared here. It keeps everyone safer. | फ़ोन नंबर, लिंक और हैंडल यहाँ शेयर नहीं किए जा सकते। इससे सब ज़्यादा सुरक्षित रहते हैं। | Phone number, links aur handles yahan share nahi kiye ja sakte. Isse sab zyada safe rehte hain. |  |
| `rooms_reportSend` | Send report | रिपोर्ट भेजें | Report bhejein |  |
| `rooms_reportThanks` | Thank you for telling us. A moderator will look at it, usually within a day. | बताने के लिए शुक्रिया। आमतौर पर एक दिन के अंदर एक मॉडरेटर इसे देखेंगे। | Batane ke liye shukriya. Aamtaur par ek din ke andar ek moderator ise dekhenge. |  |
| `rooms_reportHidden` | Thank you for telling us. You won't get their gestures in this room while a moderator takes a look. | बताने के लिए शुक्रिया। जब तक मॉडरेटर इसे देखते हैं, इस रूम में उनके भाव आप तक नहीं आएँगे। | Batane ke liye shukriya. Jab tak moderator ise dekhte hain, is room mein unke gestures aap tak nahi aayenge. |  |
| `rooms_reportGestureHidden` | Thank you for telling us. That gesture is hidden for you now. | बताने के लिए शुक्रिया। वह भाव अब आपके लिए छिपा दिया गया है। | Batane ke liye shukriya. Woh gesture ab aapke liye chhupa diya gaya hai. |  |
| `rooms_reportLimit` | That's a lot of reports today. If someone is in danger, the help button is always here. | आज काफ़ी रिपोर्ट भेजी जा चुकी हैं। अगर कोई खतरे में है, तो मदद का बटन हमेशा यहाँ है। | Aaj kaafi reports bheji ja chuki hain. Agar koi khatre mein hai, to help button hamesha yahan hai. |  |
| `rooms_reportFailed` | That didn't go through, so nothing was sent. Try again in a moment. | यह हो नहीं पाया, इसलिए कुछ नहीं भेजा गया। थोड़ी देर में फिर से कोशिश करें। | Yeh ho nahi paaya, isliye kuch nahi bheja gaya. Thodi der mein phir se try karein. |  |
| `rooms_reportOffline` | Reports need a connection. Nothing was sent yet. | रिपोर्ट के लिए कनेक्शन चाहिए। अभी तक कुछ नहीं भेजा गया। | Reports ke liye connection chahiye. Abhi tak kuch nahi bheja gaya. |  |
| `rooms_surveyTitle` | Did you feel less alone? | क्या अकेलापन थोड़ा कम लगा? | Kya akelapan thoda kam laga? | Rephrased around the feeling ('did loneliness feel a little less?') to avoid gendered 'did you feel' forms. |
| `rooms_surveyYes` | Yes | हाँ | Haan |  |
| `rooms_surveyNo` | Not really | कुछ खास नहीं | Kuch khaas nahi |  |
| `rooms_surveySkip` | Skip | छोड़ें | Skip karein |  |

### 7. Reflections

51 keys.

| Key | English | Hindi (`hi`) | Hinglish (`hi-Latn`) | Note |
|---|---|---|---|---|
| `reflections_title` | Reflections | दिल की बातें | Reflections | Hinglish treats 'reflection' as feminine (aapki reflection, ho gayi) like other -tion loanwords; Hindi uses glossary दिल की बात (fem). |
| `reflections_intro` | A few words from people here. Answered only with gestures. | यहाँ के लोगों के कुछ शब्द। इनका जवाब सिर्फ़ भावों से दिया जाता है। | Yahan ke logon ke kuch shabd. Inka jawab sirf gestures se diya jata hai. |  |
| `reflections_share` | Share a reflection | दिल की बात शेयर करें | Reflection share karein |  |
| `reflections_empty` | No reflections here yet. You can share one, or just read and send gestures. | यहाँ अभी कोई दिल की बात नहीं है। आप चाहें तो एक शेयर करें, या बस पढ़ें और भाव भेजें। | Yahan abhi koi reflection nahi hai. Aap chahein to ek share karein, ya bas padhein aur gestures bhejein. |  |
| `reflections_emptyMemory` | No reflections were shared in this room. | इस रूम में कोई दिल की बात शेयर नहीं हुई। | Is room mein koi reflection share nahi hui. |  |
| `reflections_loadFailed` | Reflections couldn't load just now. | दिल की बातें अभी लोड नहीं हो पाईं। | Reflections abhi load nahi ho payi. |  |
| `reflections_offline` | Reflections need a connection. Anything you write stays on this phone. | दिल की बातों के लिए कनेक्शन चाहिए। आप जो भी लिखें, वह इसी फ़ोन पर रहेगा। | Reflections ke liye connection chahiye. Aap jo bhi likhein, woh isi phone par rahega. |  |
| `reflections_memory` | This room is a memory: its reflections can be read, not added to. | यह रूम अब एक याद है: इसकी दिल की बातें सिर्फ़ पढ़ने के लिए हैं, इनमें कुछ नया नहीं जुड़ेगा। | Yeh room ab ek yaad hai: iski reflections sirf padhne ke liye hain, ab koi nayi add nahi hogi. |  |
| `reflections_paused` | Reflections are resting for a bit. Gestures still work. | दिल की बातें थोड़ी देर के लिए आराम पर हैं। भाव अब भी भेजे जा सकते हैं। | Reflections thodi der ke liye aaram par hain. Gestures ab bhi kaam karte hain. |  |
| `reflections_limit` | {count, plural, =1{That's 1 reflection for today. Gestures are always open.} other{That's {count} reflections for today. Gestures are always open.}} | {count, plural, =1{आज के लिए 1 दिल की बात हो गई। भाव हमेशा भेजे जा सकते हैं।} other{आज के लिए {count} दिल की बातें हो गईं। भाव हमेशा भेजे जा सकते हैं।}} | {count, plural, =1{Aaj ke liye 1 reflection ho gayi. Gestures hamesha khule hain.} other{Aaj ke liye {count} reflections ho gayin. Gestures hamesha khule hain.}} |  |
| `reflections_slow` | Reflections are slower right now | दिल की बातें अभी थोड़ी धीमी चल रही हैं | Reflections abhi thodi dheemi chal rahi hain |  |
| `reflections_left` | {remaining} of {total} left today | आज {total} में से {remaining} बाकी | Aaj {total} mein se {remaining} baaki |  |
| `reflections_cardLabel` | Reflection by {pseudonym} | {pseudonym} की दिल की बात | {pseudonym} ki reflection |  |
| `reflections_mine` | Your reflection | आपकी दिल की बात | Aapki reflection |  |
| `reflections_onlyYou` | Only you can see this | यह सिर्फ़ आपको दिखता है | Yeh sirf aapko dikhta hai |  |
| `reflections_pending` | Still checking. You can keep reading. | अभी जाँच चल रही है। आप पढ़ना जारी रखें। | Abhi check ho raha hai. Aap padhna jaari rakhein. |  |
| `reflections_heldSoon` | Waiting for a quick check | एक छोटी-सी जाँच का इंतज़ार | Ek chhote se check ka intezaar |  |
| `reflections_heldOvernight` | Waiting for a quick check. This may take until morning. | एक छोटी-सी जाँच का इंतज़ार। इसमें सुबह तक का समय लग सकता है। | Ek chhote se check ka intezaar. Ismein subah tak ka time lag sakta hai. |  |
| `reflections_rejectedCard` | This one didn't go up here. | यह यहाँ पोस्ट नहीं हो पाई। | Yeh yahan post nahi ho payi. |  |
| `reflections_removedCard` | This one was taken down after a review. | रिव्यू के बाद इसे हटा दिया गया। | Review ke baad ise hata diya gaya. |  |
| `reflections_gestureCount` | {count, plural, =0{No gestures yet} =1{1 gesture} other{{count} gestures}} | {count, plural, =0{अभी कोई भाव नहीं} =1{1 भाव} other{{count} भाव}} | {count, plural, =0{Abhi koi gesture nahi} =1{1 gesture} other{{count} gestures}} |  |
| `reflections_countPrivate` | Only you see this count | यह गिनती सिर्फ़ आपको दिखती है | Yeh count sirf aapko dikhta hai |  |
| `reflections_options` | Reflection options | दिल की बात के विकल्प | Reflection options |  |
| `reflections_gestureHint` | Sends to {pseudonym} for this reflection | इस दिल की बात पर {pseudonym} को भेजा जाएगा | Is reflection par {pseudonym} ko bheja jayega |  |
| `reflections_gestureSent` | {gesture} sent to {pseudonym} | {pseudonym} को भेजा गया: {gesture} | {pseudonym} ko bheja gaya: {gesture} | Word order '{pseudonym} को भेजा गया: {gesture}' avoids verb agreement with the gesture's gender (एक दीया masc / झप्पी fem). |
| `reflections_delete` | Delete | डिलीट करें | Delete karein |  |
| `reflections_withdraw` | Withdraw | वापस लें | Wapas lein |  |
| `reflections_deleteTitle` | Delete this reflection? | यह दिल की बात डिलीट करें? | Yeh reflection delete karein? |  |
| `reflections_deleteBody` | It goes away for everyone here. Reflections can't be edited, but you can share a new one. | यह यहाँ सबके लिए हट जाएगी। दिल की बात एडिट नहीं होती, पर आप चाहें तो नई शेयर करें। | Yeh yahan sabke liye hat jayegi. Reflection edit nahi hoti, par aap chahein to nayi share karein. |  |
| `reflections_withdrawTitle` | Withdraw this reflection? | यह दिल की बात वापस लें? | Yeh reflection wapas lein? |  |
| `reflections_withdrawBody` | It won't go up. You can share a new one any time. | यह पोस्ट नहीं होगी। आप चाहें तो कभी भी नई शेयर करें। | Yeh post nahi hogi. Aap chahein to kabhi bhi nayi share karein. |  |
| `reflections_deleted` | Your reflection is gone. | आपकी दिल की बात हटा दी गई। | Aapki reflection hata di gayi. |  |
| `reflections_reportTitle` | Report this reflection | इस दिल की बात को रिपोर्ट करें | Is reflection ko report karein |  |
| `reflections_reportHidden` | Thank you for telling us. That reflection is hidden for you now. | हमें बताने के लिए शुक्रिया। वह दिल की बात अब आपको नहीं दिखेगी। | Humein batane ke liye shukriya. Woh reflection ab aapko nahi dikhegi. |  |
| `reflections_composeTitle` | Share a reflection | दिल की बात शेयर करें | Reflection share karein |  |
| `reflections_composeLabel` | What's on your mind? | मन में क्या है? | Mann mein kya hai? |  |
| `reflections_composeNote` | A few words for this room. People can answer with gestures only, never replies. | इस रूम के लिए कुछ शब्द। लोग सिर्फ़ भावों से जवाब दे सकते हैं, रिप्लाई से कभी नहीं। | Is room ke liye kuch shabd. Log sirf gestures se jawab de sakte hain, replies se kabhi nahi. |  |
| `reflections_counter` | {count}/{max} | {count}/{max} | {count}/{max} |  |
| `reflections_counterSemantic` | {count} of {max} characters | {max} में से {count} अक्षर | {max} mein se {count} characters |  |
| `reflections_tooLong` | A little shorter, please: up to {max} characters. | थोड़ा छोटा करें: ज़्यादा से ज़्यादा {max} अक्षर। | Thoda chhota karein: zyada se zyada {max} characters. |  |
| `reflections_send` | Send | भेजें | Bhejein |  |
| `reflections_sending` | Sending gently… | आराम से भेजा जा रहा है… | Aaram se bheja ja raha hai… |  |
| `reflections_contactBlocked` | Phone numbers, links and handles can't be shared here. It keeps everyone safer. | फ़ोन नंबर, लिंक और हैंडल यहाँ शेयर नहीं किए जा सकते। इससे सब ज़्यादा सुरक्षित रहते हैं। | Phone numbers, links aur handles yahan share nahi kiye ja sakte. Isse sab zyada safe rehte hain. |  |
| `reflections_draftKept` | Draft kept. You can send it once you're back online. | ड्राफ़्ट रख लिया गया है। ऑनलाइन वापस आने पर इसे भेजा जा सकता है। | Draft rakh liya gaya hai. Online wapas aane par ise bheja ja sakta hai. |  |
| `reflections_sendFailed` | It didn't send just now. Your words are still here: try again in a moment. | अभी भेजा नहीं जा सका। आपके शब्द यहीं हैं: थोड़ी देर में फिर से कोशिश करें। | Abhi bheja nahi ja saka. Aapke shabd yahin hain: thodi der mein phir se try karein. |  |
| `reflections_rejectedContact` | Reflections can't include contact details. Want to try without it? | दिल की बात में कॉन्टैक्ट डिटेल्स नहीं हो सकते। इनके बिना फिर से कोशिश करें? | Reflection mein contact details nahi ho sakti. Inke bina phir se try karein? |  |
| `reflections_rejectedLink` | Reflections can't include links. Want to try without it? | दिल की बात में लिंक नहीं हो सकते। इसके बिना फिर से कोशिश करें? | Reflection mein links nahi ho sakte. Iske bina phir se try karein? |  |
| `reflections_rejectedPersonal` | Questions about someone's personal details can't go up here. Want to try without them? | किसी की निजी जानकारी के बारे में सवाल यहाँ पोस्ट नहीं हो सकते। इनके बिना फिर से कोशिश करें? | Kisi ki personal details ke baare mein sawaal yahan post nahi ho sakte. Inke bina phir se try karein? |  |
| `reflections_rejectedGeneral` | This one can't go up here. It may hurt someone or share personal details. Your words are still here to edit. | यह यहाँ पोस्ट नहीं होगी। इससे किसी को ठेस पहुँचना या निजी जानकारी शेयर होना मुमकिन है। आपके शब्द एडिट करने के लिए यहीं हैं। | Yeh yahan post nahi hogi. Isse kisi ko thes pahunchna ya personal details share hona mumkin hai. Aapke shabd edit karne ke liye yahin hain. | Impersonal 'मुमकिन है' used instead of सकती है to keep it blame-free and avoid agreement flags. |
| `reflections_supportSubtitle` | You don't have to carry it alone. | यह बोझ आपको अकेले नहीं उठाना है। | Yeh bojh aapko akele nahi uthana hai. |  |
| `reflections_backToRoom` | Back to the room | रूम में वापस जाएँ | Room mein wapas jayein |  |

### 8. Breath Ripples

57 keys.

| Key | English | Hindi (`hi`) | Hinglish (`hi-Latn`) | Note |
|---|---|---|---|---|
| `ripples_title` | Breath Ripples | Breath Ripples | Breath Ripples |  |
| `ripples_homeCard` | Breathe together | साथ में साँस लें | Saath mein saans lein |  |
| `ripples_homeCardBody` | Three quiet minutes with a few others. No words, no score. | कुछ और लोगों के साथ तीन शांत मिनट। न कोई बात, न कोई स्कोर। | Kuch aur logon ke saath teen shaant minute. Na koi baat, na koi score. |  |
| `ripples_breatheTogether` | Breathe together | साथ में साँस लें | Saath mein saans lein |  |
| `ripples_invite` | {name} wants to breathe together · {count}/{capacity} | {name} का साथ में साँस लेने का मन है · {count}/{capacity} | {name} ka saath mein saans lene ka mann hai · {count}/{capacity} | ‘{name} wants to…’ → ‘{name} का … मन है’ so the verb doesn't agree with the stranger's unknown gender. |
| `ripples_inviteJoin` | Join | जुड़ें | Join karein |  |
| `ripples_inviteMine` | Your invite is open · {count}/{capacity} | आपका इनवाइट खुला है · {count}/{capacity} | Aapka invite open hai · {count}/{capacity} |  |
| `ripples_lobby` | Looking for others to breathe with… | साथ साँस लेने वाले लोग ढूँढे जा रहे हैं… | Saath saans lene wale log dhoondhe ja rahe hain… |  |
| `ripples_lobbyHint` | Breathe along while you wait. You can leave any time. | इंतज़ार के दौरान साथ-साथ साँस लें। इसे कभी भी छोड़ा जा सकता है। | Intezaar ke dauraan saath-saath saans lein. Ise kabhi bhi chhoda ja sakta hai. | ‘You can leave any time’ → impersonal ‘इसे कभी भी छोड़ा जा सकता है’ (gender-neutral). |
| `ripples_holdHint` | Hold to breathe in, let go to breathe out | साँस अंदर लेने के लिए दबाकर रखें, बाहर छोड़ने के लिए छोड़ दें | Saans andar lene ke liye daba ke rakhein, bahar chhodne ke liye chhod dein |  |
| `ripples_tapHint` | Tap to switch between breathing in and out | साँस अंदर और बाहर के बीच बदलने के लिए टैप करें | Saans andar aur bahar ke beech badalne ke liye tap karein |  |
| `ripples_breathArea` | Breathing area | साँस लेने की जगह | Saans lene ki jagah |  |
| `ripples_offline` | Breathing together needs a connection. Breathe solo instead? | साथ में साँस लेने के लिए कनेक्शन चाहिए। अकेले साँस लें? | Saath mein saans lene ke liye connection chahiye. Akele saans lein? |  |
| `ripples_paused` | Breath Ripples is resting for a bit. Breathe solo instead? | Breath Ripples अभी थोड़ी देर आराम कर रहा है। अकेले साँस लें? | Breath Ripples abhi thodi der aaram kar raha hai. Akele saans lein? |  |
| `ripples_suspended` | Breathing together is paused for this account right now. You can still breathe on your own. | इस अकाउंट के लिए साथ में साँस लेना अभी रुका हुआ है। अकेले साँस लेना अब भी मुमकिन है। | Is account ke liye saath mein saans lena abhi ruka hua hai. Akele saans lena ab bhi mumkin hai. |  |
| `ripples_closed` | This account can't breathe together with others. You can still breathe on your own. | इस अकाउंट से दूसरों के साथ साँस लेना मुमकिन नहीं है। अकेले साँस लेना अब भी मुमकिन है। | Is account se doosron ke saath saans lena mumkin nahi hai. Akele saans lena ab bhi mumkin hai. |  |
| `ripples_guidelines` | The community guidelines come first. Open Rooms to read them, or breathe on your own for now. | पहले कम्युनिटी गाइडलाइंस। उन्हें पढ़ने के लिए रूम खोलें, या अभी अकेले साँस लें। | Pehle community guidelines. Unhein padhne ke liye Rooms kholein, ya abhi ke liye akele saans lein. |  |
| `ripples_breatheSolo` | Breathe solo | अकेले साँस लें | Akele saans lein |  |
| `ripples_settle` | Settle in | सहज हो जाएँ | Sahaj ho jayein | ‘Settle in’ → सहज हो जाएँ / Sahaj ho jayein. |
| `ripples_fade` | Let it fade | धीरे-धीरे थमने दें | Dheere-dheere thamne dein |  |
| `ripples_together` | {count, plural, =1{Just you and the ocean} other{{count} people breathing together}} | {count, plural, =1{बस आप और समंदर} other{{count} लोग साथ साँस ले रहे हैं}} | {count, plural, =1{Bas aap aur samandar} other{{count} log saath saans le rahe hain}} |  |
| `ripples_echoesJoined` | {count, plural, =1{1 echo joined. It's a recording of a real person who breathed here before.} other{{count} echoes joined. They're recordings of real people who breathed here before.}} | {count, plural, =1{1 गूँज जुड़ी। यह किसी असली इंसान की रिकॉर्डिंग है, जिसने पहले यहाँ साँस ली थी।} other{{count} गूँजें जुड़ीं। ये उन असली लोगों की रिकॉर्डिंग हैं, जिन्होंने पहले यहाँ साँस ली थी।}} | {count, plural, =1{1 echo judi. Ye kisi asli insaan ki recording hai, jisne pehle yahan saans li thi.} other{{count} echoes judi. Ye un asli logon ki recordings hain, jinhone pehle yahan saans li thi.}} | echo → गूँज (fem) in hi; hl keeps ‘echo’, also treated as fem (judi) for consistency. Reviewer: check गूँज vs इको. |
| `ripples_guides` | {count, plural, =1{A guide light breathes with you.} other{{count} guide lights breathe with you.}} | {count, plural, =1{एक गाइड लाइट आपके साथ साँस लेती है।} other{{count} गाइड लाइट आपके साथ साँस लेती हैं।}} | {count, plural, =1{Ek guide light aapke saath saans leti hai.} other{{count} guide lights aapke saath saans leti hain.}} |  |
| `ripples_solo` | Breathing on your own this time. The ocean still listens. | इस बार अकेले साँस चल रही है। समंदर अब भी सुन रहा है। | Is baar akele saans chal rahi hai. Samandar ab bhi sun raha hai. | ‘Breathing on your own’ rephrased to agree with साँस (fem) — ‘अकेले साँस चल रही है’ — not the user. |
| `ripples_linkLost` | You're breathing on your own for a moment. | कुछ पल के लिए अकेले साँस चल रही है। | Kuch pal ke liye akele saans chal rahi hai. | Same neutral construction as ripples_solo. |
| `ripples_alone` | Keep breathing. The ocean is still here. | साँस लेते रहें। समंदर अब भी यहीं है। | Saans lete rahein. Samandar ab bhi yahin hai. |  |
| `ripples_leave` | Leave | निकलें | Nikalein |  |
| `ripples_accessibleMode` | Accessible mode | एक्सेसिबल मोड | Accessible mode | Kept ‘accessible mode’ as loanword (एक्सेसिबल मोड); सुलभ felt too formal. |
| `ripples_accessibleModeHint` | Tap to switch between in and out. Tones and firmer haptics tell you when you're in step with the others. | अंदर और बाहर के बीच बदलने के लिए टैप करें। जब आप दूसरों के साथ ताल में हों, तो टोन और ज़्यादा मज़बूत वाइब्रेशन यह बताते हैं। | Andar aur bahar ke beech badalne ke liye tap karein. Jab aap doosron ke saath step mein hon, to tones aur zyada firm haptics ye batate hain. |  |
| `ripples_oceanSemantic` | {count, plural, =1{A night ocean with your light} other{A night ocean with {count} lights}} | {count, plural, =1{आपकी रोशनी के साथ रात का समंदर} other{{count} रोशनियों के साथ रात का समंदर}} | {count, plural, =1{Aapki light ke saath raat ka samandar} other{{count} lights ke saath raat ka samandar}} |  |
| `ripples_lightMe` | Your light | आपकी रोशनी | Aapki light |  |
| `ripples_lightHuman` | {name}'s light | {name} की रोशनी | {name} ki light |  |
| `ripples_lightEcho` | An echo of someone who breathed here before | किसी की गूँज, जिसने पहले यहाँ साँस ली थी | Kisi ki echo, jisne pehle yahan saans li thi |  |
| `ripples_lightGuide` | A guide light, breathing with the pacer | एक गाइड लाइट, पेसर के साथ साँस लेती हुई | Ek guide light, pacer ke saath saans leti hui |  |
| `ripples_echo` | echo | गूँज | echo |  |
| `ripples_guide` | guide | गाइड | guide |  |
| `ripples_you` | you | आप | aap |  |
| `ripples_pulse` | Send a pulse | पल्स भेजें | Pulse bhejein |  |
| `ripples_gestureHug` | Hug | झप्पी | Jhappi |  |
| `ripples_gestureDeepBreath` | Deep breath | गहरी साँस | Gehri saans |  |
| `ripples_gestureNotAlone` | You're not alone | कोई साथ है | Koi saath hai |  |
| `ripples_pulseFrom` | {name} sent a pulse | {name} ने पल्स भेजी | {name} ne pulse bheji |  |
| `ripples_gestureFrom` | {name} · {gesture} | {name} · {gesture} | {name} · {gesture} |  |
| `ripples_contactTray` | Send something kind | कुछ अपनापन भेजें | Thoda apnapan bhejein | ‘Send something kind’ → ‘कुछ अपनापन भेजें’ using the warmth glossary term. |
| `ripples_mute` | Mute | म्यूट | Mute |  |
| `ripples_unmute` | Unmute | अनम्यूट | Unmute |  |
| `ripples_block` | Block | ब्लॉक | Block |  |
| `ripples_report` | Report | रिपोर्ट | Report |  |
| `ripples_blocked` | Blocked. You won't be matched together again. | ब्लॉक कर दिया गया। आप दोनों का फिर से मैच नहीं होगा। | Block kar diya gaya. Aap dono ka phir se match nahi hoga. |  |
| `ripples_reported` | Thank you. Someone from Aura will look at it. | शुक्रिया। Aura की टीम से कोई इसे देखेगा। | Shukriya. Aura ki team se koi ise dekhega. |  |
| `ripples_actionFailed` | That didn't go through. Please try again. | यह नहीं हो पाया। कृपया फिर से कोशिश करें। | Ye nahi ho paya. Please phir se try karein. |  |
| `ripples_endTitle` | That was a few minutes together. | ये कुछ मिनट साथ में बीते। | Ye kuch minute saath mein beete. |  |
| `ripples_again` | Breathe again | फिर से साँस लें | Phir se saans lein |  |
| `ripples_backToRoom` | Back to room | रूम पर वापस | Room par wapas |  |
| `ripples_feelNow` | How do you feel now? | अब कैसा लग रहा है? | Ab kaisa lag raha hai? |  |
| `ripples_echoToggle` | Let my breathing become an echo | मेरी साँसों को गूँज बनने दें | Meri saanson ko echo banne dein |  |
| `ripples_echoToggleHint` | An echo keeps only the timing of your breaths, never who you are, so it can't be traced back to you. Turning this off stops future echoes. | गूँज में सिर्फ़ आपकी साँसों की टाइमिंग रहती है, आप कौन हैं यह कभी नहीं, इसलिए इसे आप तक वापस नहीं जोड़ा जा सकता। इसे बंद करने पर आगे से कोई नई गूँज नहीं बनेगी। | Echo mein sirf aapki saanson ki timing rehti hai, aap kaun hain ye kabhi nahi, isliye ise aap tak wapas nahi joda ja sakta. Ise band karne par aage se koi nayi echo nahi banegi. |  |

### 9. Capsules (Future you) and voice notes

116 keys.

| Key | English | Hindi (`hi`) | Hinglish (`hi-Latn`) | Note |
|---|---|---|---|---|
| `capsules_title` | Future you | भविष्य के आप | Future you |  |
| `capsules_emptyBody` | Write to future you. Seal it for a date, or for a feeling. | भविष्य के आपके लिए कुछ लिखें। इसे किसी तारीख के लिए सील करें, या किसी एहसास के लिए। | Future you ke liye kuch likhein. Ise kisi date ke liye seal karein, ya kisi feeling ke liye. |  |
| `capsules_emptyCta` | Seal your first capsule | अपना पहला कैप्सूल सील करें | Apna pehla capsule seal karein |  |
| `capsules_new` | Write a capsule | कैप्सूल लिखें | Capsule likhein |  |
| `capsules_entryCount` | {count, plural, =0{Nothing sealed yet} =1{1 capsule sealed} other{{count} capsules sealed}} | {count, plural, =0{अभी कुछ सील नहीं हुआ} =1{1 कैप्सूल सील है} other{{count} कैप्सूल सील हैं}} | {count, plural, =0{Abhi kuch seal nahi hua} =1{1 capsule seal hai} other{{count} capsules seal hain}} |  |
| `capsules_entryReady` | {count, plural, =1{1 is ready to open} other{{count} are ready to open}} | {count, plural, =1{1 खुलने के लिए तैयार है} other{{count} खुलने के लिए तैयार हैं}} | {count, plural, =1{1 khulne ke liye taiyaar hai} other{{count} khulne ke liye taiyaar hain}} |  |
| `capsules_sectionReady` | Ready to open | खुलने के लिए तैयार | Khulne ke liye taiyaar |  |
| `capsules_sectionSealed` | Sealed | सील किए हुए | Sealed |  |
| `capsules_sectionOpened` | Opened | खुले हुए | Khule hue |  |
| `capsules_sealedUntil` | Sealed until {date}. It'll keep. | {date} तक सील है। यह सुरक्षित रहेगा। | {date} tak seal hai. Yeh safe rahega. |  |
| `capsules_waitingFeeling` | Waiting for a feeling | किसी एहसास का इंतज़ार | Kisi feeling ka intezaar |  |
| `capsules_readyRow` | Ready when you are | जब आप तैयार हों | Jab aap taiyaar hon |  |
| `capsules_untitled` | A capsule from {date} | {date} का एक कैप्सूल | {date} ka ek capsule |  |
| `capsules_lockedTitle` | A sealed capsule | एक सील किया हुआ कैप्सूल | Ek sealed capsule |  |
| `capsules_sealedOn` | Sealed {date} | {date} को सील किया | {date} ko seal kiya |  |
| `capsules_openedOn` | Opened {date} | {date} को खोला | {date} ko khola |  |
| `capsules_draftTitle` | Your draft is here | आपका ड्राफ़्ट यहाँ है | Aapka draft yahan hai |  |
| `capsules_draftBody` | Pick up where you left off. | जहाँ छोड़ा था, वहीं से आगे लिखें। | Jahan chhoda tha, wahin se aage likhein. |  |
| `capsules_composeTitle` | Write to future you | भविष्य के आपके लिए लिखें | Future you ke liye likhein |  |
| `capsules_titleLabel` | Title | टाइटल | Title |  |
| `capsules_titleHelper` | Shown on the capsule while it's sealed. | सील रहने तक कैप्सूल पर यही दिखेगा। | Seal rehne tak capsule par yahi dikhega. |  |
| `capsules_textLabel` | Your note | आपका नोट | Aapka note |  |
| `capsules_textHelper` | Only you will read this, when it opens. | खुलने पर यह सिर्फ़ आपके लिए होगा। | Khulne par yeh sirf aapke liye hoga. | Rephrased to 'it will be only for you' to avoid gendered पढ़ेंगे/पढ़ पाएँगे. |
| `capsules_photosTitle` | Photos | फ़ोटो | Photos |  |
| `capsules_addPhoto` | Add a photo | फ़ोटो जोड़ें | Photo add karein |  |
| `capsules_photoHint` | Up to 3. Location and camera details are removed. | ज़्यादा से ज़्यादा 3। लोकेशन और कैमरे की जानकारी हटा दी जाती है। | Zyada se zyada 3. Location aur camera details hata di jaati hain. |  |
| `capsules_photoAdding` | Adding your photo… | आपकी फ़ोटो जोड़ी जा रही है… | Aapki photo add ho rahi hai… |  |
| `capsules_photoFailed` | That photo couldn't be added. Try another one. | यह फ़ोटो नहीं जुड़ पाई। कोई दूसरी आज़माएँ। | Yeh photo add nahi ho payi. Koi doosri try karein. |  |
| `capsules_photoRemove` | Remove photo {index} | फ़ोटो {index} हटाएँ | Photo {index} hatayein |  |
| `capsules_photoSemantic` | Photo {index} of {count} | {count} में से फ़ोटो {index} | {count} mein se photo {index} |  |
| `capsules_voiceHint` | Up to 2 minutes. Only you can hear it. | ज़्यादा से ज़्यादा 2 मिनट। यह सिर्फ़ आपके लिए है। | Zyada se zyada 2 minute. Yeh sirf aapke liye hai. | Rephrased 'Only you can hear it' as 'it is only for you' to avoid gendered सकते/सकती. |
| `capsules_voiceLimit` | That's the full two minutes, so recording stopped. Your voice note is ready. | पूरे दो मिनट हो गए, इसलिए रिकॉर्डिंग रुक गई। आपका वॉइस नोट तैयार है। | Poore do minute ho gaye, isliye recording ruk gayi. Aapka voice note taiyaar hai. |  |
| `capsules_unlockTitle` | When should it open? | यह कब खुले? | Yeh kab khule? |  |
| `capsules_unlockDate` | On a date | किसी तारीख को | Kisi date par |  |
| `capsules_unlockFeeling` | For a feeling | किसी एहसास के लिए | Kisi feeling ke liye |  |
| `capsules_pickDate` | Pick a date | तारीख चुनें | Date chunein |  |
| `capsules_changeDate` | Change date | तारीख बदलें | Date badlein |  |
| `capsules_dateChosen` | Opens {date} at {time} | {date} को {time} पर खुलेगा | {date} ko {time} par khulega |  |
| `capsules_dateHelp` | Any day from a week to five years from now. | आज से एक हफ़्ते से लेकर पाँच साल तक का कोई भी दिन। | Aaj se ek hafte se lekar paanch saal tak ka koi bhi din. |  |
| `capsules_datePickerHelp` | It opens at 10:00 that day | उस दिन 10:00 बजे खुलेगा | Us din 10:00 baje khulega |  |
| `capsules_feelingHelp` | It can open from 24 hours after sealing, the next time you check in feeling this. | सील करने के 24 घंटे बाद से, अगली बार यही एहसास होने पर चेक-इन करते ही यह खुल सकता है। | Seal karne ke 24 ghante baad se, agli baar yahi feeling hone par check-in karte hi yeh khul sakta hai. |  |
| `capsules_anyQuadrant` | Any {quadrant} feeling | {quadrant} वाला कोई भी एहसास | Koi bhi {quadrant} feeling |  |
| `capsules_feelingChosen` | Waits for: {feeling} | इसका इंतज़ार: {feeling} | Iska intezaar: {feeling} |  |
| `capsules_seal` | Seal it | सील करें | Seal karein |  |
| `capsules_needContent` | Add a few words, a voice note or a photo first. | पहले कुछ शब्द, एक वॉइस नोट या एक फ़ोटो जोड़ें। | Pehle kuch shabd, ek voice note ya ek photo add karein. |  |
| `capsules_needUnlock` | Choose when it should open. | चुनें कि यह कब खुले। | Chunein ki yeh kab khule. |  |
| `capsules_sealFailed` | That didn't seal just now. Your capsule is still here. Try again. | अभी सील नहीं हो पाया। आपका कैप्सूल यहीं है। फिर से कोशिश करें। | Abhi seal nahi ho paya. Aapka capsule yahin hai. Phir se try karein. |  |
| `capsules_sealedTitle` | Sealed | सील हो गया | Seal ho gaya |  |
| `capsules_sealedFeeling` | Sealed. It'll wait for that feeling. | सील हो गया। यह उसी एहसास का इंतज़ार करेगा। | Seal ho gaya. Yeh usi feeling ka intezaar karega. |  |
| `capsules_mediaLater` | Sealed and safe on this phone. Photos and voice back up when you're online. | इस फ़ोन पर सील और सुरक्षित है। ऑनलाइन होने पर फ़ोटो और आवाज़ का बैकअप हो जाएगा। | Is phone par sealed aur safe hai. Online hone par photos aur voice ka backup ho jayega. |  |
| `capsules_limitBody` | Free accounts keep 3 mood capsules waiting. Date capsules are unlimited. | फ़्री अकाउंट में 3 मूड कैप्सूल इंतज़ार में रखे जा सकते हैं। तारीख वाले कैप्सूल की कोई सीमा नहीं है। | Free account mein 3 mood capsules intezaar mein rakhe ja sakte hain. Date capsules ki koi limit nahi hai. |  |
| `capsules_limitPickDate` | Pick a date instead | इसके बदले तारीख चुनें | Iske badle date chunein |  |
| `capsules_makeDate` | Make it a date capsule | इसे तारीख वाला कैप्सूल बनाएँ | Ise date capsule banayein |  |
| `capsules_leaveTitle` | Keep this draft? | यह ड्राफ़्ट रखें? | Yeh draft rakhein? |  |
| `capsules_leaveBody` | It stays on this phone until you seal it or let it go. | जब तक आप इसे सील न करें या हटा न दें, यह इसी फ़ोन पर रहेगा। | Jab tak aap ise seal na karein ya hata na dein, yeh isi phone par rahega. |  |
| `capsules_leaveEditing` | Keep editing | लिखते रहें | Likhte rahein |  |
| `capsules_leaveKeep` | Keep draft | ड्राफ़्ट रखें | Draft rakhein |  |
| `capsules_leaveDiscard` | Discard | हटा दें | Hata dein |  |
| `capsules_detailFeeling` | Waiting for a feeling: {feeling}. | किसी एहसास का इंतज़ार: {feeling}. | Kisi feeling ka intezaar: {feeling}. |  |
| `capsules_detailArming` | It can open from {date}. | यह {date} से खुल सकता है। | Yeh {date} se khul sakta hai. |  |
| `capsules_detailNoEarly` | Sealed means sealed: it can't be opened early or changed. | सील का मतलब सील: इसे न पहले खोला जा सकता है, न बदला जा सकता है। | Seal matlab seal: ise na pehle khola ja sakta hai, na badla ja sakta hai. |  |
| `capsules_delete` | Delete capsule | कैप्सूल डिलीट करें | Capsule delete karein |  |
| `capsules_deleteTitle` | Delete this capsule? | यह कैप्सूल डिलीट करें? | Yeh capsule delete karein? |  |
| `capsules_deleteBody` | It will be gone for good, without being opened. | यह बिना खुले हमेशा के लिए हट जाएगा। | Yeh bina khule hamesha ke liye hat jayega. |  |
| `capsules_deleteBodyOpened` | It will be gone for good. | यह हमेशा के लिए हट जाएगा। | Yeh hamesha ke liye hat jayega. |  |
| `capsules_deleteConfirm` | Delete | डिलीट करें | Delete karein |  |
| `capsules_deleteKeep` | Keep it | रहने दें | Rehne dein |  |
| `capsules_deleted` | Capsule deleted. | कैप्सूल डिलीट हो गया। | Capsule delete ho gaya. |  |
| `capsules_triggerTitle` | You left a note for a moment like this. Open now or later? | ऐसे पल के लिए आपने एक नोट छोड़ा था। अभी खोलें या बाद में? | Aise pal ke liye aapne ek note chhoda tha. Abhi kholein ya baad mein? |  |
| `capsules_holdTitle` | A note from past you is waiting. Open now, or later? | पहले लिखा आपका एक नोट इंतज़ार में है। अभी खोलें, या बाद में? | Pehle likha aapka ek note intezaar mein hai. Abhi kholein, ya baad mein? | Rendered 'a note you wrote earlier is waiting' (पहले लिखा आपका नोट) to avoid awkward 'बीते समय के आपका'. |
| `capsules_now` | Now | अभी | Abhi |  |
| `capsules_later` | Later | बाद में | Baad mein |  |
| `capsules_readyMore` | {count, plural, =1{1 capsule is ready.} other{{count} capsules are ready.}} | {count, plural, =1{1 कैप्सूल तैयार है।} other{{count} कैप्सूल तैयार हैं।}} | {count, plural, =1{1 capsule taiyaar hai.} other{{count} capsules taiyaar hain.}} |  |
| `capsules_readyOpen` | Open it | खोलें | Kholein |  |
| `capsules_notifyAskTitle` | Want to know when it opens? | खुलने पर आपको बताया जाए? | Khulne par aapko bataya jaye? | Impersonal 'should you be told when it opens?' avoids gendered जानना चाहेंगे. |
| `capsules_notifyAskBody` | One quiet note on the day it opens. Nothing on your lock screen says what's inside. | खुलने वाले दिन बस एक हल्का-सा नोट। आपकी लॉक स्क्रीन पर यह नहीं दिखेगा कि अंदर क्या है। | Khulne wale din bas ek halka sa note. Lock screen par yeh nahi dikhega ki andar kya hai. |  |
| `capsules_hardMoment` | You wrote this during a hard moment. Open when you're ready. | यह आपने एक मुश्किल घड़ी में लिखा था। जब आप तैयार हों, तब खोलें। | Yeh aapne ek mushkil waqt mein likha tha. Jab aap taiyaar hon, tab kholein. |  |
| `capsules_skip` | Skip | छोड़ें | Skip karein |  |
| `capsules_opening` | Opening your capsule | आपका कैप्सूल खुल रहा है | Aapka capsule khul raha hai |  |
| `capsules_openedTitle` | From past you | बीते समय के आप से | Past you se | 'past you' mirrors glossary 'Future you' = भविष्य के आप; Hinglish keeps English 'Past you se'. |
| `capsules_keepNextTime` | Keep for next time | अगली बार के लिए रखें | Agli baar ke liye rakhein |  |
| `capsules_keptNextTime` | It'll wait for that feeling again. | यह फिर से उसी एहसास का इंतज़ार करेगा। | Yeh phir se usi feeling ka intezaar karega. |  |
| `capsules_voiceOffline` | Your capsule is open. The voice note arrives when you're back online. | आपका कैप्सूल खुल गया है। ऑनलाइन वापस आने पर वॉइस नोट आ जाएगा। | Aapka capsule khul gaya hai. Online wapas aane par voice note aa jayega. |  |
| `capsules_photosOffline` | The photos arrive when you're back online. | ऑनलाइन वापस आने पर फ़ोटो आ जाएँगी। | Online wapas aane par photos aa jayengi. |  |
| `capsules_mediaFailed` | This couldn't be loaded just now. Try again in a moment. | यह अभी लोड नहीं हो पाया। थोड़ी देर में फिर से कोशिश करें। | Yeh abhi load nahi ho paya. Thodi der mein phir se try karein. |  |
| `capsules_retry` | Try again | फिर से कोशिश करें | Phir se try karein |  |
| `capsules_cantRead` | This capsule can't be read on this phone yet. It opens once you're back online. | यह कैप्सूल अभी इस फ़ोन पर पढ़ा नहीं जा सकता। ऑनलाइन वापस आने पर यह खुल जाएगा। | Yeh capsule abhi is phone par padha nahi ja sakta. Online wapas aane par yeh khul jayega. |  |
| `capsules_accountDeletionCount` | {count, plural, =1{1 sealed capsule will be lost.} other{{count} sealed capsules will be lost.}} | {count, plural, =1{सील किया हुआ 1 कैप्सूल हमेशा के लिए मिट जाएगा।} other{सील किए हुए {count} कैप्सूल हमेशा के लिए मिट जाएँगे।}} | {count, plural, =1{Seal kiya hua 1 capsule hamesha ke liye mit jayega.} other{Seal kiye hue {count} capsules hamesha ke liye mit jayenge.}} |  |
| `voice_record` | Record a voice note | वॉइस नोट रिकॉर्ड करें | Voice note record karein |  |
| `voice_recordHint` | Up to a minute. Only you can hear it. | एक मिनट तक। यह सिर्फ़ आपको सुनाई देगा। | Ek minute tak. Ye sirf aapko sunai dega. | ‘Only you can hear it’ → ‘सिर्फ़ आपको सुनाई देगा’ to avoid gendered सकते/सकती. |
| `voice_rationaleTitle` | Add your voice? | अपनी आवाज़ जोड़ें? | Apni awaaz add karein? |  |
| `voice_rationaleBody` | To record a voice note, Aura needs your microphone. Recordings stay private to you and are never shared in rooms. | वॉइस नोट रिकॉर्ड करने के लिए Aura को आपका माइक्रोफ़ोन चाहिए। रिकॉर्डिंग सिर्फ़ आपके पास रहती हैं और रूम में कभी शेयर नहीं होतीं। | Voice note record karne ke liye Aura ko aapka microphone chahiye. Recordings sirf aapke paas rehti hain aur rooms mein kabhi share nahi hoti. |  |
| `voice_rationaleAllow` | Allow | अनुमति दें | Allow karein |  |
| `voice_denied` | Voice is off. Type instead, or turn it on in Settings. | आवाज़ बंद है। इसकी जगह टाइप करें, या सेटिंग्स में इसे चालू करें। | Voice off hai. Iski jagah type karein, ya Settings mein ise on karein. |  |
| `voice_openSettings` | Settings | सेटिंग्स | Settings |  |
| `voice_recording` | Recording | रिकॉर्ड हो रहा है | Record ho raha hai |  |
| `voice_elapsed` | {time} · up to {limit} | {time} · {limit} तक | {time} · {limit} tak |  |
| `voice_recordingFor` | {seconds, plural, =1{Recording, 1 second} other{Recording, {seconds} seconds}} | {seconds, plural, =1{रिकॉर्ड हो रहा है, 1 सेकंड} other{रिकॉर्ड हो रहा है, {seconds} सेकंड}} | {seconds, plural, =1{Record ho raha hai, 1 second} other{Record ho raha hai, {seconds} seconds}} |  |
| `voice_stop` | Stop recording | रिकॉर्डिंग रोकें | Recording rokein |  |
| `voice_started` | Recording started | रिकॉर्डिंग शुरू हुई | Recording shuru hui |  |
| `voice_recorded` | {seconds, plural, =1{Voice note recorded, 1 second} other{Voice note recorded, {seconds} seconds}} | {seconds, plural, =1{वॉइस नोट रिकॉर्ड हुआ, 1 सेकंड} other{वॉइस नोट रिकॉर्ड हुआ, {seconds} सेकंड}} | {seconds, plural, =1{Voice note record hua, 1 second} other{Voice note record hua, {seconds} seconds}} |  |
| `voice_limitReached` | That's the full minute, so recording stopped. Your voice note is ready. | पूरा एक मिनट हो गया, इसलिए रिकॉर्डिंग रुक गई। आपका वॉइस नोट तैयार है। | Poora ek minute ho gaya, isliye recording ruk gayi. Aapka voice note ready hai. |  |
| `voice_recordFailed` | Voice couldn't be recorded just now. Your words still save. | अभी आवाज़ रिकॉर्ड नहीं हो पाई। आपका लिखा हुआ फिर भी सेव होगा। | Abhi voice record nahi ho payi. Aapka likha hua phir bhi save hoga. |  |
| `voice_note` | Voice note | वॉइस नोट | Voice note |  |
| `voice_length` | {seconds, plural, =1{1 second} other{{seconds} seconds}} | {seconds, plural, =1{1 सेकंड} other{{seconds} सेकंड}} | {seconds, plural, =1{1 second} other{{seconds} seconds}} |  |
| `voice_play` | Play voice note | वॉइस नोट चलाएँ | Voice note play karein |  |
| `voice_pause` | Pause voice note | वॉइस नोट रोकें | Voice note pause karein |  |
| `voice_reRecord` | Record again | फिर से रिकॉर्ड करें | Phir se record karein |  |
| `voice_remove` | Remove | हटाएँ | Hatayein |  |
| `voice_removeSemantic` | Remove voice note | वॉइस नोट हटाएँ | Voice note hatayein |  |
| `voice_dropped` | Your check-in is saved. The voice note couldn't be kept, as your phone may be low on space. | आपका चेक-इन सेव हो गया है। वॉइस नोट नहीं रखा जा सका, शायद फ़ोन में जगह कम है। | Aapka check-in save ho gaya hai. Voice note rakha nahi ja saka, shayad phone mein jagah kam hai. |  |
| `voice_loading` | Getting your voice note… | आपका वॉइस नोट लाया जा रहा है… | Aapka voice note laaya ja raha hai… |  |
| `voice_offline` | The voice note plays when you're back online. | फिर से ऑनलाइन होने पर वॉइस नोट चलेगा। | Phir se online hone par voice note chalega. |  |
| `voice_failed` | This voice note couldn't be played just now. Try again in a moment. | यह वॉइस नोट अभी चल नहीं पाया। थोड़ी देर में फिर से कोशिश करें। | Ye voice note abhi play nahi ho paya. Thodi der mein phir se try karein. |  |
| `voice_section` | Your voice | आपकी आवाज़ | Aapki awaaz |  |
| `voice_hasVoice` | Has a voice note | इसमें वॉइस नोट है | Isme voice note hai |  |

### 10. Aura Plus, paywall and gifts (prices come from the store)

110 keys.

| Key | English | Hindi (`hi`) | Hinglish (`hi-Latn`) | Note |
|---|---|---|---|---|
| `plus_title` | Aura Plus | Aura Plus | Aura Plus |  |
| `plus_intro` | More of what you already have. Everything that helps you feel better stays free. | जो आपके पास पहले से है, उसी का और ज़्यादा। जो कुछ भी आपको अच्छा महसूस करने में मदद करता है, वह मुफ़्त ही रहेगा। | Jo aapke paas pehle se hai, usi ka aur zyada. Jo kuch bhi aapko achha feel karne mein madad karta hai, woh free hi rahega. |  |
| `plus_addsTitle` | Plus adds | Plus के साथ मिलता है | Plus ke saath milta hai |  |
| `plus_addCapsules` | Unlimited mood-trigger capsules | अनलिमिटेड मूड-ट्रिगर कैप्सूल | Unlimited mood-trigger capsules |  |
| `plus_addVoice` | Voice up to 10 minutes in a capsule | कैप्सूल में 10 मिनट तक वॉइस | Capsule mein 10 minute tak voice |  |
| `plus_addInsights` | Deeper Insights: any range, habit × mood, the deeper month in stars | और गहरी समझ: कोई भी अवधि, आदत × मूड, सितारों में महीने की गहरी झलक | Deeper Insights: koi bhi range, habit × mood, sitaron mein mahine ki gehri jhalak |  |
| `plus_addSounds` | Extra sounds and two Plus skies | ज़्यादा आवाज़ें और दो Plus आसमान | Extra sounds aur do Plus skies |  |
| `plus_freeTitle` | Always free | हमेशा मुफ़्त | Hamesha free |  |
| `plus_freeBody` | Check-ins, habits, rest days, rooms, Breath Ripples, date capsules, crisis support, Breathe, grounding, Today's minute, every base sound and the night wind-down. | चेक-इन, आदतें, आराम के दिन, रूम, Breath Ripples, तारीख वाले कैप्सूल, संकट में मदद, साँस लें, ग्राउंडिंग, आज का मिनट, हर बेसिक आवाज़ और रात का सोने से पहले का सुकून। | Check-ins, habits, rest days, rooms, Breath Ripples, date capsules, crisis support, Breathe, grounding, Today's minute, har base sound aur raat ka wind-down. | Feature names follow the glossary (साँस लें = Breathe, सोने से पहले का सुकून = wind-down, आज का मिनट = Today's minute). |
| `plus_planMonthly` | Monthly | मासिक | Monthly |  |
| `plus_planAnnual` | Yearly | सालाना | Yearly |  |
| `plus_trialLineMonthly` | 1 month free, then {price}/month | 1 महीना मुफ़्त, फिर {price}/महीना | 1 month free, phir {price}/month |  |
| `plus_trialLineAnnual` | 1 month free, then {price}/year | 1 महीना मुफ़्त, फिर {price}/साल | 1 month free, phir {price}/year |  |
| `plus_priceMonthly` | {price}/month | {price}/महीना | {price}/month |  |
| `plus_priceAnnual` | {price}/year | {price}/साल | {price}/year |  |
| `plus_trialEnds` | Your free month ends on {date}. The first charge is on {date} unless you cancel before then. | आपका मुफ़्त महीना {date} को खत्म होगा। उससे पहले रद्द न किया गया, तो पहला चार्ज {date} को लगेगा। | Aapka free month {date} ko khatam hoga. Usse pehle cancel nahi kiya, to pehla charge {date} ko lagega. |  |
| `plus_renews` | Renews automatically until you cancel. Paid through your {store} account. | रद्द करने तक यह अपने-आप रिन्यू होता रहेगा। पेमेंट आपके {store} अकाउंट से होगा। | Cancel karne tak yeh apne-aap renew hota rahega. Payment aapke {store} account se hoga. | 'until you cancel' rendered as 'रद्द करने तक' (neutral). |
| `plus_cancelApple` | To cancel: iPhone Settings › your name › Subscriptions › Aura. Cancel at least a day before a charge. | रद्द करने के लिए: iPhone Settings › आपका नाम › Subscriptions › Aura. किसी भी चार्ज से कम से कम एक दिन पहले रद्द करें। | Cancel karne ke liye: iPhone Settings › aapka naam › Subscriptions › Aura. Kisi bhi charge se kam se kam ek din pehle cancel karein. | iOS menu labels (Settings, Subscriptions) kept in English because they depend on the phone's language; review if the app should localise them. |
| `plus_cancelGoogle` | To cancel: Play Store › your profile › Payments & subscriptions › Subscriptions › Aura. | रद्द करने के लिए: Play Store › आपकी प्रोफ़ाइल › Payments & subscriptions › Subscriptions › Aura. | Cancel karne ke liye: Play Store › aapki profile › Payments & subscriptions › Subscriptions › Aura. | Play Store menu labels kept in English (depend on device language). |
| `plus_storeApple` | App Store | App Store | App Store |  |
| `plus_storeGoogle` | Google Play | Google Play | Google Play |  |
| `plus_startTrial` | Start free month | मुफ़्त महीना शुरू करें | Free month shuru karein |  |
| `plus_subscribe` | Subscribe | सब्सक्राइब करें | Subscribe karein |  |
| `plus_restore` | Restore purchases | खरीदारी रिस्टोर करें | Purchases restore karein |  |
| `plus_manage` | Manage in store | स्टोर में मैनेज करें | Store mein manage karein |  |
| `plus_loadingPrices` | Loading prices from the store | स्टोर से कीमतें लोड हो रही हैं | Store se prices load ho rahi hain |  |
| `plus_storeUnavailable` | The store isn't reachable right now. Nothing was charged. | अभी स्टोर तक नहीं पहुँचा जा पा रहा। कोई चार्ज नहीं लिया गया। | Abhi store tak nahi pahuncha ja pa raha. Koi charge nahi liya gaya. |  |
| `plus_retry` | Try again | फिर से कोशिश करें | Phir se try karein |  |
| `plus_confirming` | Confirming with the store… | स्टोर से पुष्टि हो रही है… | Store se confirm ho raha hai… |  |
| `plus_confirmingLater` | The store has your request. Plus unlocks the moment it's confirmed. You can close this. | आपकी रिक्वेस्ट स्टोर तक पहुँच गई है। पुष्टि होते ही Plus खुल जाएगा। इसे बंद किया जा सकता है। | Aapki request store tak pahunch gayi hai. Confirm hote hi Plus unlock ho jayega. Ise band kiya ja sakta hai. |  |
| `plus_validationFailed` | We couldn't confirm this yet. If you were charged, it's safe. We'll keep checking. | अभी इसकी पुष्टि नहीं हो पाई। अगर आपसे चार्ज लिया गया है, तो वह सुरक्षित है। हम जाँच करते रहेंगे। | Abhi iska confirmation nahi ho paaya. Agar aapse charge liya gaya hai, to woh safe hai. Hum check karte rahenge. |  |
| `plus_pendingApproval` | Waiting for approval. You won't be charged until it goes through. | मंज़ूरी का इंतज़ार है। यह पूरा होने तक आपसे कोई चार्ज नहीं लिया जाएगा। | Approval ka intezaar hai. Yeh poora hone tak aapse koi charge nahi liya jayega. |  |
| `plus_declined` | Payment didn't go through. You weren't charged. | पेमेंट नहीं हो पाया। आपसे कोई चार्ज नहीं लिया गया। | Payment nahi ho paaya. Aapse koi charge nahi liya gaya. |  |
| `plus_welcome` | Aura Plus is on. Thank you. | Aura Plus चालू हो गया है। शुक्रिया। | Aura Plus on ho gaya hai. Shukriya. |  |
| `plus_ownedElsewhere` | This purchase belongs to another Aura account on this store account, so it stays there. | यह खरीदारी इस स्टोर अकाउंट पर किसी दूसरे Aura अकाउंट की है, इसलिए यह वहीं रहेगी। | Yeh purchase is store account par kisi doosre Aura account ki hai, isliye yeh wahin rahegi. |  |
| `plus_restored` | {count, plural, =0{Nothing to restore on this store account.} =1{1 purchase restored.} other{{count} purchases restored.}} | {count, plural, =0{इस स्टोर अकाउंट पर रिस्टोर करने के लिए कुछ नहीं है।} =1{1 खरीदारी रिस्टोर हुई।} other{{count} खरीदारियाँ रिस्टोर हुईं।}} | {count, plural, =0{Is store account par restore karne ke liye kuch nahi hai.} =1{1 purchase restore hui.} other{{count} purchases restore hui.}} |  |
| `plus_lockedOnly` | Part of Aura Plus | Aura Plus का हिस्सा | Aura Plus ka hissa |  |
| `plus_about` | About Aura Plus | Aura Plus के बारे में | Aura Plus ke baare mein |  |
| `plus_seePlus` | See Aura Plus | Aura Plus देखें | Aura Plus dekhein |  |
| `plus_freePath` | The free way stays right here. | मुफ़्त रास्ता यहीं मौजूद है। | Free raasta yahin maujood hai. |  |
| `plus_explainerCapsules` | Free accounts keep 3 mood capsules waiting. Aura Plus keeps as many as you like. Date capsules are always unlimited. | मुफ़्त अकाउंट में 3 मूड कैप्सूल इंतज़ार में रखे जा सकते हैं। Aura Plus में जितने चाहें, उतने। तारीख वाले कैप्सूल हमेशा अनलिमिटेड हैं। | Free account mein 3 mood capsules wait mein rakhe ja sakte hain. Aura Plus mein jitne chahein, utne. Date capsules hamesha unlimited hain. |  |
| `plus_explainerVoice` | Voice in a capsule stops at 2 minutes on free Aura, 10 minutes with Aura Plus. | मुफ़्त Aura में कैप्सूल की वॉइस 2 मिनट पर रुक जाती है, Aura Plus के साथ 10 मिनट पर। | Free Aura mein capsule ki voice 2 minute par ruk jaati hai, Aura Plus ke saath 10 minute par. |  |
| `plus_explainerSounds` | This sound comes with Aura Plus. Every base sound and the night wind-down stay free. | यह आवाज़ Aura Plus के साथ मिलती है। हर बेसिक आवाज़ और रात का सोने से पहले का सुकून मुफ़्त रहते हैं। | Yeh sound Aura Plus ke saath milta hai. Har base sound aur raat ka wind-down free rehte hain. |  |
| `plus_explainerInsights` | Aura Plus adds any range, habit × mood and the deeper month. Your sky and history stay free. | Aura Plus में कोई भी अवधि, आदत × मूड और महीने की गहरी झलक मिलती है। आपका आसमान और हिस्ट्री मुफ़्त रहते हैं। | Aura Plus mein koi bhi range, habit × mood aur deeper month milta hai. Aapka sky aur history free rehte hain. |  |
| `plus_explainerSky` | This sky comes with Aura Plus. | यह आसमान Aura Plus के साथ मिलता है। | Yeh sky Aura Plus ke saath milta hai. |  |
| `plus_statusFree` | You're on free Aura. | अभी आपके पास मुफ़्त Aura है। | Abhi aapke paas free Aura hai. |  |
| `plus_statusTrial` | Free month: {days, plural, =0{ends today} =1{1 day left} other{{days} days left}}. First charge on {date}. | मुफ़्त महीना: {days, plural, =0{आज खत्म} =1{1 दिन बाकी} other{{days} दिन बाकी}}। पहला चार्ज {date} को। | Free month: {days, plural, =0{aaj khatam} =1{1 din baaki} other{{days} din baaki}}. Pehla charge {date} ko. |  |
| `plus_statusTrialCancelled` | Your free month stays on until {date}. After that you're on free Aura, and everything you made stays yours. | आपका मुफ़्त महीना {date} तक चालू रहेगा। उसके बाद मुफ़्त Aura रहेगा, और आपका बनाया सब कुछ आपका ही रहेगा। | Aapka free month {date} tak on rahega. Uske baad free Aura rahega, aur aapka banaya sab kuch aapka hi rahega. |  |
| `plus_statusActive` | Aura Plus renews on {date}. | Aura Plus {date} को रिन्यू होगा। | Aura Plus {date} ko renew hoga. |  |
| `plus_statusCancelled` | Aura Plus stays on until {date}. You won't be charged again. | Aura Plus {date} तक चालू रहेगा। आपसे दोबारा चार्ज नहीं लिया जाएगा। | Aura Plus {date} tak on rahega. Aapse dobara charge nahi liya jayega. |  |
| `plus_statusGrace` | The store couldn't renew Aura Plus. Plus stays on while it tries again. | स्टोर Aura Plus को रिन्यू नहीं कर पाया। जब तक स्टोर फिर से कोशिश कर रहा है, Plus चालू रहेगा। | Store Aura Plus ko renew nahi kar paaya. Jab tak store phir se try kar raha hai, Plus on rahega. |  |
| `plus_statusBillingRetry` | Aura Plus is paused until the store can renew it. Everything you made stays yours. | स्टोर के रिन्यू कर पाने तक Aura Plus रुका हुआ है। आपका बनाया सब कुछ आपका ही रहेगा। | Store ke renew kar paane tak Aura Plus ruka hua hai. Aapka banaya sab kuch aapka hi rahega. |  |
| `plus_statusExpired` | Aura Plus has ended. Everything you made stays yours. | Aura Plus खत्म हो गया है। आपका बनाया सब कुछ आपका ही रहेगा। | Aura Plus khatam ho gaya hai. Aapka banaya sab kuch aapka hi rahega. |  |
| `plus_statusRefunded` | Your refund went through, so Aura Plus has ended. Everything you made stays yours. | आपका रिफ़ंड हो गया है, इसलिए Aura Plus खत्म हो गया है। आपका बनाया सब कुछ आपका ही रहेगा। | Aapka refund ho gaya hai, isliye Aura Plus khatam ho gaya hai. Aapka banaya sab kuch aapka hi rahega. |  |
| `plus_statusPending` | Waiting for the store to confirm. You won't be charged until it goes through. | स्टोर की पुष्टि का इंतज़ार है। यह पूरा होने तक आपसे कोई चार्ज नहीं लिया जाएगा। | Store ke confirmation ka intezaar hai. Yeh poora hone tak aapse koi charge nahi liya jayega. |  |
| `plus_updatePayment` | Update payment in store | स्टोर में पेमेंट अपडेट करें | Store mein payment update karein |  |
| `plus_turnBackOn` | Turn Plus back on | Plus फिर से चालू करें | Plus phir se on karein |  |
| `plus_managedElsewhere` | Bought on {store}. Manage it there. | {store} पर खरीदा गया। इसे वहीं मैनेज करें। | {store} par kharida gaya. Ise wahin manage karein. |  |
| `plus_notYet` | Aura Plus opens up a day after you join. Everything you need is already free. | Aura Plus जुड़ने के एक दिन बाद खुलता है। आपकी ज़रूरत की हर चीज़ पहले से मुफ़्त है। | Aura Plus join karne ke ek din baad khulta hai. Aapki zaroorat ki har cheez pehle se free hai. |  |
| `plus_cardTrialEnding` | Your free month ends on {date}. Plus then continues at {price}/month unless you cancel in the store. | आपका मुफ़्त महीना {date} को खत्म होगा। उसके बाद, स्टोर में रद्द न किया गया, तो Plus {price}/महीना पर जारी रहेगा। | Aapka free month {date} ko khatam hoga. Uske baad, store mein cancel nahi kiya, to Plus {price}/month par jaari rahega. |  |
| `plus_cardTrialEndingYear` | Your free month ends on {date}. Plus then continues at {price}/year unless you cancel in the store. | आपका मुफ़्त महीना {date} को खत्म होगा। उसके बाद, स्टोर में रद्द न किया गया, तो Plus {price}/साल पर जारी रहेगा। | Aapka free month {date} ko khatam hoga. Uske baad, store mein cancel nahi kiya, to Plus {price}/year par jaari rahega. |  |
| `plus_cardTrialEndingNoPrice` | Your free month ends on {date}. Plus then continues unless you cancel in the store. | आपका मुफ़्त महीना {date} को खत्म होगा। उसके बाद, स्टोर में रद्द न किया गया, तो Plus जारी रहेगा। | Aapka free month {date} ko khatam hoga. Uske baad, store mein cancel nahi kiya, to Plus jaari rahega. |  |
| `plus_cardKeep` | Keep Plus | Plus जारी रखें | Plus jaari rakhein |  |
| `plus_cardTrialCancelled` | Plus stays on until {date}. You won't be charged. | Plus {date} तक चालू रहेगा। आपसे कोई चार्ज नहीं लिया जाएगा। | Plus {date} tak on rahega. Aapse koi charge nahi liya jayega. |  |
| `plus_cardBillingIssue` | Your Aura Plus payment didn't go through. Everything you've made is safe. | आपका Aura Plus पेमेंट नहीं हो पाया। आपका बनाया सब कुछ सुरक्षित है। | Aapka Aura Plus payment nahi ho paaya. Aapka banaya sab kuch safe hai. |  |
| `plus_cardContinues` | Aura Plus continues. Thank you. | Aura Plus जारी है। शुक्रिया। | Aura Plus jaari hai. Shukriya. |  |
| `plus_dismiss` | Dismiss | हटाएँ | Hatayein |  |
| `plus_giftWarmTea` | Warm Tea | एक कप चाय | Ek cup chai | Uses the same rendering as the Warm Tea gesture (एक कप चाय / Ek cup chai) for consistency; reviewer may want a distinct gift name. |
| `plus_giftComfortLantern` | Comfort Lantern | सुकून की लालटेन | Sukoon ki lalten | Translated gift name; Latin 'Lantern' kept only in the brand 'Lantern Hour'. |
| `plus_giftBouquet` | Encouragement Bouquet | हौसले का गुलदस्ता | Hausle ka guldasta |  |
| `plus_giftReceived` | Someone here sent you a {gift}. | यहाँ किसी की ओर से आपके लिए {gift}। | Yahan kisi ki taraf se aapke liye {gift}. | Rendered as 'from someone here, for you: {gift}' so the verb does not need to agree with the gift's grammatical gender. plus_giftBody quotes the same wording. |
| `plus_giftStardust` | +{count} Stardust | +{count} Stardust | +{count} Stardust |  |
| `plus_giftTitle` | Send a gift | तोहफ़ा भेजें | Gift bhejein |  |
| `plus_giftBody` | They'll see “Someone here sent you a gift” and get Stardust for a sky. No message and no name. | उन्हें “यहाँ किसी की ओर से आपके लिए एक तोहफ़ा” दिखेगा और आसमान के लिए Stardust मिलेगा। न कोई मैसेज, न कोई नाम। | Unhe “Yahan kisi ki taraf se aapke liye ek gift” dikhega aur sky ke liye Stardust milega. Na koi message, na koi naam. |  |
| `plus_giftSend` | Send for {price} | {price} में भेजें | {price} mein bhejein |  |
| `plus_giftSent` | Sent. They'll see it the next time they open Aura. | भेज दिया गया। अगली बार Aura खोलने पर उन्हें दिखेगा। | Bhej diya gaya. Agli baar Aura kholne par unhe dikhega. |  |
| `plus_giftUnavailable` | This gift can't be sent right now. Nothing was charged. | यह तोहफ़ा अभी नहीं भेजा जा सकता। कोई चार्ज नहीं लिया गया। | Yeh gift abhi nahi bheja ja sakta. Koi charge nahi liya gaya. |  |
| `plus_giftDailyLimit` | That's 5 gifts today. You can send more tomorrow. | आज के 5 तोहफ़े हो गए। कल और भेजे जा सकते हैं। | Aaj ke 5 gifts ho gaye. Kal aur bheje ja sakte hain. |  |
| `plus_giftPaused` | Gifts aren't available on this account right now. | इस अकाउंट पर अभी तोहफ़े उपलब्ध नहीं हैं। | Is account par abhi gifts available nahi hain. |  |
| `plus_giftsOff` | Gifts are resting for a bit. Nothing was charged. | तोहफ़े थोड़ी देर के लिए आराम कर रहे हैं। कोई चार्ज नहीं लिया गया। | Gifts thodi der ke liye aaram kar rahe hain. Koi charge nahi liya gaya. |  |
| `plus_stardustBalance` | {count} Stardust | {count} Stardust | {count} Stardust |  |
| `plus_stardustNote` | Stardust comes only from gifts people send you. It can't be bought, cashed or moved. | Stardust सिर्फ़ उन तोहफ़ों से मिलता है जो लोग आपको भेजते हैं। इसे न खरीदा जा सकता है, न कैश किया जा सकता है, न कहीं भेजा जा सकता है। | Stardust sirf un gifts se milta hai jo log aapko bhejte hain. Ise na khareeda ja sakta hai, na cash kiya ja sakta hai, na kahin bheja ja sakta hai. |  |
| `plus_skiesTitle` | Your sky | आपका आसमान | Aapka sky |  |
| `plus_skiesIntro` | A sky for your own Home, Sanctuary and Insights. Only you see it. | आपके अपने होम, सुकून और समझ के लिए एक आसमान। यह सिर्फ़ आपको दिखता है। | Aapke apne Home, Sanctuary aur Insights ke liye ek sky. Yeh sirf aapko dikhta hai. |  |
| `plus_skyNight` | Night sky | रात का आसमान | Night sky | hi sky names translated; hl keeps English sky names (like room theme names). |
| `plus_skyAurora` | Aurora | ऑरोरा | Aurora |  |
| `plus_skyMonsoonDusk` | Monsoon dusk | मानसून की शाम | Monsoon dusk |  |
| `plus_skyFirstLight` | First light | पहली रोशनी | First light |  |
| `plus_skyLanternFestival` | Lantern festival | लालटेन उत्सव | Lantern festival |  |
| `plus_skyDeepOcean` | Deep ocean | गहरा समंदर | Deep ocean |  |
| `plus_skyMeteorShower` | Meteor shower | टूटते तारे | Meteor shower |  |
| `plus_skyFree` | Free | मुफ़्त | Free |  |
| `plus_skyWithPlus` | With Aura Plus | Aura Plus के साथ | Aura Plus ke saath |  |
| `plus_skyOwned` | Yours | आपका | Aapka |  |
| `plus_skyInUse` | In use | इस्तेमाल में | Use mein |  |
| `plus_skyUse` | Use this sky | यह आसमान लगाएँ | Yeh sky lagayein |  |
| `plus_skyBuy` | Buy for {price} | {price} में खरीदें | {price} mein kharidein |  |
| `plus_skyStardust` | Use {count} Stardust | {count} Stardust इस्तेमाल करें | {count} Stardust use karein |  |
| `plus_skyNotEnough` | Not enough Stardust for this sky yet. | इस आसमान के लिए अभी Stardust काफ़ी नहीं है। | Is sky ke liye abhi Stardust kaafi nahi hai. |  |
| `plus_soundscapeTitle` | Pair a soundscape | साथ में एक साउंडस्केप जोड़ें | Saath mein ek soundscape jodein |  |
| `plus_soundscapeNone` | No sounds | कोई आवाज़ नहीं | Koi sound nahi |  |
| `plus_soundscapeNightAir` | Night air | रात की हवा | Night air |  |
| `plus_soundscapeHighWind` | High wind | तेज़ हवा | High wind |  |
| `plus_soundscapeMonsoon` | Monsoon | मानसून | Monsoon |  |
| `plus_soundscapeBells` | Bells | घंटियाँ | Bells |  |
| `plus_soundscapeShore` | Shore | समंदर किनारा | Shore |  |
| `plus_soundscapePlay` | Play these sounds | ये आवाज़ें चलाएँ | Yeh sounds chalayein |  |
| `plus_settingsSky` | Your sky and Stardust | आपका आसमान और Stardust | Aapka sky aur Stardust |  |
| `plus_channelAccount` | Account | अकाउंट | Account |  |
| `plus_channelAccountDescription` | Aura Plus reminders, like your free month ending. | Aura Plus रिमाइंडर, जैसे आपका मुफ़्त महीना खत्म होना। | Aura Plus reminders, jaise aapka free month khatam hona. |  |

### 11. Onboarding, sign-in and account

86 keys.

| Key | English | Hindi (`hi`) | Hinglish (`hi-Latn`) | Note |
|---|---|---|---|---|
| `welcome_title` | Welcome to Aura | Aura में आपका स्वागत है | Aura mein aapka swagat hai |  |
| `welcome_body` | A quiet place to notice how you feel. Your check-ins stay private, and your Aura grows a little each time you show up. | अपने मन का हाल देखने की एक शांत जगह। आपके चेक-इन प्राइवेट रहते हैं, और हर बार आपके आने पर आपका Aura थोड़ा बढ़ता है। | Apne mann ka haal dekhne ki ek shaant jagah. Aapke check-ins private rehte hain, aur har baar aapke aane par aapka Aura thoda badhta hai. |  |
| `welcome_begin` | Begin | शुरू करें | Shuru karein |  |
| `dob_title` | When's your birthday? | आपका जन्मदिन कब है? | Aapka birthday kab hai? |  |
| `dob_body` | We ask everyone. It stays private and is never shown to anyone. | यह हम सबसे पूछते हैं। यह प्राइवेट रहता है और किसी को कभी नहीं दिखाया जाता। | Yeh hum sabse poochhte hain. Yeh private rehta hai aur kisi ko kabhi nahi dikhaya jaata. |  |
| `dob_day` | Day | दिन | Din |  |
| `dob_month` | Month | महीना | Mahina |  |
| `dob_year` | Year | साल | Saal |  |
| `dob_invalid` | That date doesn't exist. Could you check it? | ऐसी कोई तारीख नहीं होती। एक बार देख लें? | Aisi koi date nahi hoti. Ek baar check kar lein? |  |
| `dob_future` | That date hasn't happened yet. Could you check it? | यह तारीख अभी आई नहीं है। एक बार देख लें? | Yeh date abhi aayi nahi hai. Ek baar check kar lein? |  |
| `language_title` | Which language feels like home? | कौन-सी भाषा अपनी-सी लगती है? | Kaun si bhasha apni si lagti hai? |  |
| `language_body` | You can change this any time in Settings. | इसे सेटिंग्स में कभी भी बदला जा सकता है। | Ise Settings mein kabhi bhi badla ja sakta hai. |  |
| `language_teLatnHint` | Telugu in English letters | अंग्रेज़ी अक्षरों में तेलुगु | Telugu, English letters mein |  |
| `language_hiLatnHint` | Hindi in English letters | अंग्रेज़ी अक्षरों में हिंदी | Hindi, English letters mein |  |
| `language_beta` | Beta | बीटा | Beta |  |
| `signin_title` | Keep your Aura safe | अपने Aura को सुरक्षित रखें | Apne Aura ko safe rakhein |  |
| `signin_body` | Sign in with your email so your Aura can follow you to a new phone. No name, no phone number, no password. | अपने ईमेल से साइन इन करें, ताकि नए फ़ोन में भी आपका Aura आपके साथ रहे। न नाम, न फ़ोन नंबर, न पासवर्ड। | Apne email se sign in karein, taaki naye phone mein bhi aapka Aura aapke saath rahe. Na naam, na phone number, na password. |  |
| `signin_emailLabel` | Email | ईमेल | Email |  |
| `signin_sendCode` | Email me a code | मुझे ईमेल पर कोड भेजें | Mujhe email par code bhejein |  |
| `signin_codeSent` | We sent a 6-digit code to {email}. You can also tap the link in that email. | हमने {email} पर 6 अंकों का कोड भेजा है। चाहें तो उस ईमेल के लिंक पर भी टैप करें। | Humne {email} par 6-digit code bheja hai. Chahein to us email ke link par bhi tap karein. |  |
| `signin_codeLabel` | 6-digit code | 6 अंकों का कोड | 6-digit code |  |
| `signin_verify` | Continue | आगे बढ़ें | Aage badhein |  |
| `signin_resend` | Send a fresh code | नया कोड भेजें | Naya code bhejein |  |
| `signin_changeEmail` | Use a different email | दूसरा ईमेल इस्तेमाल करें | Doosra email use karein |  |
| `signin_error` | That didn't go through. Try again, or sign in another way. | यह हो नहीं पाया। फिर से कोशिश करें, या किसी और तरीके से साइन इन करें। | Yeh ho nahi paaya. Phir se try karein, ya kisi aur tareeke se sign in karein. |  |
| `signin_codeExpired` | This code has timed out. We'll send a fresh one. | इस कोड का समय खत्म हो गया है। हम नया कोड भेज देंगे। | Is code ka time khatam ho gaya hai. Hum naya code bhej denge. |  |
| `signin_invalidCode` | That code doesn't match. Could you check it? | यह कोड मेल नहीं खा रहा। एक बार देख लें? | Yeh code match nahi ho raha. Ek baar check kar lein? |  |
| `signin_invalidEmail` | That email doesn't look quite right. | यह ईमेल कुछ ठीक नहीं लग रहा। | Yeh email kuch sahi nahi lag raha. |  |
| `signin_apple` | Continue with Apple | Apple के साथ जारी रखें | Apple ke saath continue karein |  |
| `signin_google` | Continue with Google | Google के साथ जारी रखें | Google ke saath continue karein |  |
| `signin_offline` | You're offline. Pick your first mood now. We'll finish setting up when you're connected. | आप ऑफ़लाइन हैं। अभी अपना पहला मूड चुनें। कनेक्ट होने पर हम सेटअप पूरा कर देंगे। | Aap offline hain. Abhi apna pehla mood chunein. Connect hone par hum setup poora kar denge. |  |
| `signin_offlineContinue` | Check in now | अभी चेक-इन करें | Abhi check-in karein |  |
| `signin_unavailable` | Sign-in isn't set up in this build yet. Your check-ins will stay on this phone for now. | इस बिल्ड में साइन-इन अभी सेट नहीं हुआ है। फ़िलहाल आपके चेक-इन इसी फ़ोन पर रहेंगे। | Is build mein sign-in abhi set nahi hua hai. Filhaal aapke check-ins isi phone par rahenge. |  |
| `signin_continueLocal` | Continue on this phone | इसी फ़ोन पर आगे बढ़ें | Isi phone par aage badhein |  |
| `signin_busy` | One moment | एक पल | Ek pal |  |
| `signin_resendIn` | {seconds, plural, =1{You can ask for a fresh code in 1 s} other{You can ask for a fresh code in {seconds} s}} | {seconds, plural, =1{1 सेकंड में नया कोड माँगा जा सकता है} other{{seconds} सेकंड में नया कोड माँगा जा सकता है}} | {seconds, plural, =1{1 second mein naya code maanga ja sakta hai} other{{seconds} second mein naya code maanga ja sakta hai}} | Used passive 'माँगा जा सकता है' (neutral); 's' expanded to सेकंड/second. |
| `signin_freshSent` | A fresh code is on its way. | नया कोड आ रहा है। | Naya code aa raha hai. |  |
| `acct_pendingTitle` | Keep your account? | अपना अकाउंट रखना है? | Apna account rakhna hai? |  |
| `acct_pendingBody` | Your account is set to be deleted on {date}. Keep it? | आपका अकाउंट {date} को डिलीट होना तय है। क्या इसे रखना है? | Aapka account {date} ko delete hona tay hai. Kya ise rakhna hai? |  |
| `acct_pendingBodySoon` | Your account is set to be deleted soon. Keep it? | आपका अकाउंट जल्द ही डिलीट होना तय है। क्या इसे रखना है? | Aapka account jald hi delete hona tay hai. Kya ise rakhna hai? |  |
| `acct_keep` | Keep my account | मेरा अकाउंट रखें | Mera account rakhein |  |
| `acct_letGo` | Let it go | जाने दें | Jaane dein |  |
| `acct_keepFailed` | That didn't go through, so nothing has changed yet. Try again when you're connected. | यह नहीं हो पाया, इसलिए अभी कुछ नहीं बदला है। कनेक्ट होने पर फिर से कोशिश करें। | Yeh nahi ho paaya, isliye abhi kuch nahi badla hai. Connect hone par phir se try karein. |  |
| `acct_deleteTitle` | Delete my account | मेरा अकाउंट डिलीट करें | Mera account delete karein |  |
| `acct_deleteIntro` | Deleting your account removes: | अकाउंट डिलीट करने पर ये सब हट जाएगा: | Account delete karne par yeh sab hat jayega: |  |
| `acct_itemCheckIns` | Your check-ins and notes | आपके चेक-इन और नोट | Aapke check-ins aur notes |  |
| `acct_itemHabits` | Your habits | आपकी आदतें | Aapki habits |  |
| `acct_itemProgress` | Your Starlight and your Aura's growth | आपका Starlight और आपके Aura का बढ़ना | Aapka Starlight aur aapke Aura ki growth |  |
| `acct_itemAccount` | Your account and the email you sign in with | आपका अकाउंट और साइन इन वाला ईमेल | Aapka account aur sign in wala email | 'the email you sign in with' rendered as 'साइन इन वाला ईमेल' to avoid gendered करते/करती. |
| `acct_grace` | You have 7 days to change your mind. Sign in again before then and everything stays. After that it's deleted for good and can't be brought back. | मन बदलने के लिए आपके पास 7 दिन हैं। उससे पहले फिर से साइन इन करें, तो सब कुछ बना रहेगा। उसके बाद यह हमेशा के लिए डिलीट हो जाएगा और वापस नहीं लाया जा सकेगा। | Mann badalne ke liye aapke paas 7 din hain. Usse pehle phir se sign in karein, to sab kuch bana rahega. Uske baad yeh hamesha ke liye delete ho jayega aur wapas nahi laaya ja sakega. |  |
| `acct_store` | If you pay for a subscription through the App Store or Google Play, deleting your account doesn't cancel it. Manage or cancel it in your store's subscription settings. | अगर किसी सब्सक्रिप्शन का पेमेंट App Store या Google Play से होता है, तो अकाउंट डिलीट करने से वह रद्द नहीं होता। उसे अपने स्टोर की सब्सक्रिप्शन सेटिंग्स में मैनेज या रद्द करें। | Agar kisi subscription ka payment App Store ya Google Play se hota hai, to account delete karne se woh cancel nahi hota. Use apne store ki subscription settings mein manage ya cancel karein. | Rephrased impersonally ('if a subscription is paid through...') to avoid gendered करते हैं; facts unchanged. |
| `acct_phone` | This phone will be cleared and signed out straight away. | यह फ़ोन तुरंत क्लियर हो जाएगा और इससे साइन आउट हो जाएगा। | Yeh phone turant clear ho jayega aur isse sign out ho jayega. |  |
| `acct_needsConnection` | Deleting your account needs a connection. Connect to the internet, then try again. | अकाउंट डिलीट करने के लिए कनेक्शन चाहिए। इंटरनेट से कनेक्ट करके फिर से कोशिश करें। | Account delete karne ke liye connection chahiye. Internet se connect karke phir se try karein. |  |
| `acct_confirmTitle` | Delete your account? | अपना अकाउंट डिलीट करें? | Apna account delete karein? |  |
| `acct_confirmBody` | Your account and everything in it will be deleted in 7 days. Sign in again before then to keep it. This phone will be cleared now. | आपका अकाउंट और उसमें मौजूद सब कुछ 7 दिनों में डिलीट हो जाएगा। इसे रखना हो तो उससे पहले फिर से साइन इन करें। यह फ़ोन अभी क्लियर हो जाएगा। | Aapka account aur usmein maujood sab kuch 7 din mein delete ho jayega. Ise rakhna ho to usse pehle phir se sign in karein. Yeh phone abhi clear ho jayega. |  |
| `acct_failed` | That didn't go through, and nothing has been deleted. Try again in a moment. | यह नहीं हो पाया, और कुछ भी डिलीट नहीं हुआ है। थोड़ी देर में फिर से कोशिश करें। | Yeh nahi ho paaya, aur kuch bhi delete nahi hua hai. Thodi der mein phir se try karein. |  |
| `acct_failedOffline` | We couldn't reach Aura, and nothing has been deleted. Check your connection and try again. | Aura तक पहुँचा नहीं जा सका, और कुछ भी डिलीट नहीं हुआ है। अपना कनेक्शन जाँचें और फिर से कोशिश करें। | Aura tak pahuncha nahi ja saka, aur kuch bhi delete nahi hua hai. Apna connection check karein aur phir se try karein. |  |
| `acct_retry` | Try again | फिर से कोशिश करें | Phir se try karein |  |
| `acct_scheduledTitle` | Your account is set to be deleted | आपका अकाउंट डिलीट होना तय हो गया है | Aapka account delete hona tay ho gaya hai |  |
| `acct_scheduledBody` | It will be deleted on {date}. Sign in again before then to keep it. | यह {date} को डिलीट हो जाएगा। इसे रखना हो तो उससे पहले फिर से साइन इन करें। | Yeh {date} ko delete ho jayega. Ise rakhna ho to usse pehle phir se sign in karein. |  |
| `acct_phoneCleared` | This phone has been cleared and signed out. | यह फ़ोन क्लियर कर दिया गया है और इससे साइन आउट हो गया है। | Yeh phone clear kar diya gaya hai aur isse sign out ho gaya hai. |  |
| `acct_signedOut` | You're not signed in, so there's no account to delete. What you've saved lives only on this phone. | अभी साइन इन नहीं है, इसलिए डिलीट करने के लिए कोई अकाउंट नहीं है। आपका सेव किया हुआ सब कुछ सिर्फ़ इसी फ़ोन पर है। | Abhi sign in nahi hai, isliye delete karne ke liye koi account nahi hai. Aapka save kiya hua sab kuch sirf isi phone par hai. |  |
| `acct_unavailable` | Account deletion isn't set up in this build. | इस बिल्ड में अकाउंट डिलीट करने की सुविधा सेट नहीं है। | Is build mein account delete karne ki suvidha set nahi hai. |  |
| `acct_inProgress` | This account is already being deleted, so it can't be kept any more. This phone will be cleared and signed out. | इस अकाउंट को डिलीट करने का काम शुरू हो चुका है, इसलिए अब इसे रखा नहीं जा सकता। यह फ़ोन क्लियर हो जाएगा और इससे साइन आउट हो जाएगा। | Is account ko delete karne ka kaam shuru ho chuka hai, isliye ab ise rakha nahi ja sakta. Yeh phone clear ho jayega aur isse sign out ho jayega. |  |
| `signin_or` | or | या | ya |  |
| `signin_socialNotReady` | That sign-in option isn't ready yet. Use your email for now. | साइन-इन का यह तरीका अभी तैयार नहीं है। फ़िलहाल अपना ईमेल इस्तेमाल करें। | Sign-in ka yeh option abhi ready nahi hai. Filhaal apna email use karein. |  |
| `signin_socialOffline` | It looks like you're offline. Try again when you're connected. | लगता है आप ऑफ़लाइन हैं। कनेक्ट होने पर फिर से कोशिश करें। | Lagta hai aap offline hain. Connect hone par phir se try karein. |  |
| `legal_privacy` | Privacy policy | प्राइवेसी पॉलिसी | Privacy policy |  |
| `legal_terms` | Terms of use | इस्तेमाल की शर्तें | Terms of use |  |
| `legal_opensInBrowser` | Opens in your browser | आपके ब्राउज़र में खुलेगा | Aapke browser mein khulega |  |
| `flows_startOverTitle` | Start over? | फिर से शुरू करें? | Phir se shuru karein? |  |
| `flows_startOverBody` | This clears what you've picked and written so far. | अब तक जो चुना और लिखा है, वह हट जाएगा। | Ab tak jo chuna aur likha hai, woh hat jayega. |  |
| `flows_startOver` | Start over | फिर से शुरू करें | Phir se shuru karein |  |
| `onb_trustTitle` | Before we begin | शुरू करने से पहले | Shuru karne se pehle |  |
| `onb_trustBody` | A few things to know about how Aura looks after you. | Aura आपका खयाल कैसे रखता है, इसके बारे में कुछ बातें। | Aura aapka khayal kaise rakhta hai, iske baare mein kuch baatein. |  |
| `onb_trustPrivateTitle` | Private by default | शुरू से ही प्राइवेट | Shuru se hi private |  |
| `onb_trustPrivateBody` | Your check-ins and notes are yours. Notes are encrypted, and nobody else sees how you feel unless you choose to share it. | आपके चेक-इन और नोट सिर्फ़ आपके हैं। नोट एन्क्रिप्ट रहते हैं, और जब तक आप शेयर करना न चुनें, आपका हाल कोई और नहीं देख सकता। | Aapke check-ins aur notes sirf aapke hain. Notes encrypted rehte hain, aur jab tak aap share karna na chunein, aapka haal koi aur nahi dekh sakta. | ‘how you feel’ → आपका हाल / aapka haal (neutral) instead of gendered ‘कैसा महसूस कर रहे हैं’. |
| `onb_dobYearType` | Type the year | साल टाइप करें | Saal type karein |  |
| `onb_dobYearNoMatch` | No year in the list matches that. Could you check it? | लिस्ट में इससे मिलता कोई साल नहीं है। एक बार देख लें? | List mein isse milta koi saal nahi hai. Ek baar check kar lein? |  |
| `onb_blockedWrongDate` | Entered the wrong date? | गलत तारीख डाल दी? | Galat date daal di? |  |
| `onb_blockedWrongDateHint` | Opens your email app | आपका ईमेल ऐप खुलेगा | Aapka email app khulega |  |
| `onb_blockedMailSubject` | Aura: I entered the wrong date | Aura: मैंने गलत तारीख डाल दी | Aura: maine galat date daal di |  |
| `onb_blockedMailFailed` | We couldn't open an email app. You can write to us at {email}. | ईमेल ऐप नहीं खुल पाया। आप चाहें तो हमें {email} पर लिखें। | Email app nahi khul paya. Aap chahein to humein {email} par likhein. | ‘You can write to us’ → ‘आप चाहें तो हमें … लिखें’ to avoid सकते/सकती. |
| `device_bannedTitle` | This device can't use Aura | इस डिवाइस पर Aura इस्तेमाल नहीं किया जा सकता | Is device par Aura use nahi kiya ja sakta |  |
| `device_bannedBody` | Aura isn't available on this phone. | इस फ़ोन पर Aura उपलब्ध नहीं है। | Is phone par Aura available nahi hai. |  |
| `device_bannedReviewSubject` | Review of a device | डिवाइस का रिव्यू | Device ka review |  |

### 12. Check-in, moods and history

75 keys.

| Key | English | Hindi (`hi`) | Hinglish (`hi-Latn`) | Note |
|---|---|---|---|---|
| `checkin_title` | How are you feeling? | अभी कैसा लग रहा है? | Abhi kaisa lag raha hai? | 'How are you feeling?' → 'अभी कैसा लग रहा है?' so it avoids कर रहे/रही हैं. |
| `checkin_subtitle` | Pick the closest one. There's no wrong answer. | जो सबसे करीब लगे, उसे चुनें। कोई जवाब गलत नहीं है। | Jo sabse kareeb lage, use chunein. Koi jawaab galat nahi hai. |  |
| `checkin_moreEnergy` | More energy | ज़्यादा एनर्जी | Zyada energy |  |
| `checkin_lessEnergy` | Less energy | कम एनर्जी | Kam energy |  |
| `checkin_pleasant` | Pleasant | सुखद | Pleasant | Axis labels: hi सुखद / असहज (pleasant / uncomfortable), chosen so they don't read as 'good/bad'. hl keeps the English 'Pleasant/Unpleasant'. Needs a native check. The same pair is used in semantic_pleasant/unpleasant. |
| `checkin_unpleasant` | Unpleasant | असहज | Unpleasant |  |
| `quadrant_storm` | Storm | तूफ़ान | Storm |  |
| `quadrant_rain` | Rain | बारिश | Rain |  |
| `quadrant_moonlight` | Moonlight | चाँदनी | Moonlight |  |
| `quadrant_sunrise` | Sunrise | सूर्योदय | Sunrise |  |
| `mood_semantic` | {mood}, {quadrant} group, {energy}, {feel} | {mood}, {quadrant} समूह, {energy}, {feel} | {mood}, {quadrant} group, {energy}, {feel} |  |
| `semantic_highEnergy` | high energy | ज़्यादा एनर्जी | zyada energy |  |
| `semantic_lowEnergy` | low energy | कम एनर्जी | kam energy |  |
| `semantic_pleasant` | pleasant | सुखद | pleasant |  |
| `semantic_unpleasant` | unpleasant | असहज | unpleasant |  |
| `checkin_addDetails` | Add a tag or a few words | कोई टैग या कुछ शब्द जोड़ें | Koi tag ya kuch shabd jodein |  |
| `checkin_tagsTitle` | What's it about? | यह किस बारे में है? | Yeh kis baare mein hai? |  |
| `tag_study` | Study | पढ़ाई | Padhai |  |
| `tag_work` | Work | काम | Kaam |  |
| `tag_family` | Family | परिवार | Family |  |
| `tag_friends` | Friends | दोस्त | Dost |  |
| `tag_sleep` | Sleep | नींद | Neend |  |
| `tag_health` | Health | सेहत | Health |  |
| `tag_money` | Money | पैसे | Paisa |  |
| `tag_love` | Love | प्यार | Pyaar |  |
| `tag_alone` | Alone | अकेले | Akele |  |
| `tag_commute` | Commute | आना-जाना | Aana-jaana |  |
| `checkin_customTag` | Your own tag | अपना टैग | Apna tag |  |
| `checkin_customTagAdd` | Add tag | टैग जोड़ें | Tag jodein |  |
| `checkin_noteLabel` | A few words, if you like | चाहें तो कुछ शब्द | Chahein to kuch shabd |  |
| `checkin_noteHint` | Only you can read this. | यह सिर्फ़ आपको दिखेगा। | Yeh sirf aapko dikhega. |  |
| `checkin_save` | Save | सेव करें | Save karein |  |
| `checkin_saveFailed` | We couldn't save that. Your phone may be low on space. | यह सेव नहीं हो पाया। शायद आपके फ़ोन में जगह कम है। | Yeh save nahi ho paaya. Shayad aapke phone mein jagah kam hai. |  |
| `checkin_savedStarlight` | +{amount} Starlight | +{amount} Starlight | +{amount} Starlight |  |
| `checkin_saved` | Saved | सेव हो गया | Save ho gaya |  |
| `checkin_savedOffline` | Saved on this phone | इस फ़ोन पर सेव हो गया | Is phone par save ho gaya |  |
| `checkin_savedThanks` | Thank you for checking in. | चेक-इन करने के लिए शुक्रिया। | Check-in karne ke liye shukriya. |  |
| `checkin_savedFull` | You've gathered all of today's Starlight. Your check-in still counts. | आज की सारी Starlight मिल चुकी है। आपका चेक-इन फिर भी गिना जाता है। | Aaj ki saari Starlight mil chuki hai. Aapka check-in phir bhi count hota hai. |  |
| `checkin_roomButton` | Join a room of people feeling this | ऐसा ही महसूस करने वालों के रूम में जुड़ें | Aisa hi mehsoos karne walon ke room mein judein |  |
| `checkin_discardTitle` | Leave without saving? | सेव किए बिना बाहर निकलें? | Bina save kiye bahar niklein? |  |
| `checkin_discardKeep` | Keep editing | एडिट करते रहें | Edit karte rahein |  |
| `checkin_discardConfirm` | Discard | हटा दें | Hata dein |  |
| `checkin_tagLimit` | {count, plural, =1{Up to 1 tag} other{Up to {count} tags}} | {count, plural, =1{ज़्यादा से ज़्यादा 1 टैग} other{ज़्यादा से ज़्यादा {count} टैग}} | {count, plural, =1{Zyada se zyada 1 tag} other{Zyada se zyada {count} tags}} |  |
| `checkin_quadrantAxes` | {energy} · {feel} | {energy} · {feel} | {energy} · {feel} |  |
| `history_title` | Your check-ins | आपके चेक-इन | Aapke check-ins |  |
| `history_private` | Only you can see these. | ये सिर्फ़ आपको दिखते हैं। | Yeh sirf aapko dikhte hain. |  |
| `history_empty` | Nothing here yet. Your check-ins will gather here, and only you can see them. | यहाँ अभी कुछ नहीं है। आपके चेक-इन यहाँ जमा होंगे, और ये सिर्फ़ आपको दिखेंगे। | Yahan abhi kuch nahi hai. Aapke check-ins yahan jama honge, aur yeh sirf aapko dikhenge. |  |
| `history_today` | Today | आज | Aaj |  |
| `history_yesterday` | Yesterday | कल | Kal |  |
| `history_tagCount` | {count, plural, =1{1 tag} other{{count} tags}} | {count, plural, =1{1 टैग} other{{count} टैग}} | {count, plural, =1{1 tag} other{{count} tags}} |  |
| `history_hasNote` | Has a note | नोट है | Note hai |  |
| `history_entryTitle` | Your check-in | आपका चेक-इन | Aapka check-in |  |
| `history_when` | {day}, {time} | {day}, {time} | {day}, {time} |  |
| `history_tags` | Tags | टैग | Tags |  |
| `history_note` | Your words | आपके शब्द | Aapke shabd |  |
| `history_synced` | Synced | सिंक हो गया | Sync ho gaya |  |
| `history_edit` | Edit | एडिट करें | Edit karein |  |
| `history_editWindowOver` | You can edit a check-in for a day after you make it. | चेक-इन करने के बाद एक दिन तक उसे एडिट किया जा सकता है। | Check-in karne ke baad ek din tak use edit kiya ja sakta hai. |  |
| `history_delete` | Delete | डिलीट करें | Delete karein |  |
| `history_deleteTitle` | Delete this check-in? | यह चेक-इन डिलीट करें? | Yeh check-in delete karein? |  |
| `history_deleteBody` | This doesn't change your Starlight or glow days. | इससे आपकी Starlight या चमक वाले दिनों पर कोई असर नहीं पड़ता। | Isse aapki Starlight ya glow days par koi asar nahi padta. | ‘glow days’ = चमक वाले दिन in hi everywhere (home_*, habits_*); hl keeps ‘glow days’. |
| `history_missing` | This check-in isn't here anymore. | यह चेक-इन अब यहाँ नहीं है। | Yeh check-in ab yahan nahi hai. |  |
| `history_editNoteLocked` | This check-in's note hasn't reached this phone yet. You can edit it once it has. | इस चेक-इन का नोट अभी इस फ़ोन तक नहीं पहुँचा है। पहुँचने के बाद इसे एडिट किया जा सकता है। | Is check-in ka note abhi is phone tak nahi pahuncha hai. Pahunchne ke baad ise edit kiya ja sakta hai. |  |
| `backfill_add` | Add a past check-in | पिछला चेक-इन जोड़ें | Pichhla check-in add karein |  |
| `backfill_pickTitle` | Which day? | कौन-सा दिन? | Kaun-sa din? |  |
| `backfill_pickBody` | {count, plural, =1{You can add a check-in for yesterday.} other{You can add a check-in for any of the last {count} days.}} | {count, plural, =1{कल के लिए चेक-इन जोड़ा जा सकता है।} other{पिछले {count} दिनों में से किसी भी दिन का चेक-इन जोड़ा जा सकता है।}} | {count, plural, =1{Kal ke liye check-in add kiya ja sakta hai.} other{Pichhle {count} dinon mein se kisi bhi din ka check-in add kiya ja sakta hai.}} |  |
| `backfill_title` | How were you feeling? | उस दिन कैसा लग रहा था? | Us din kaisa lag raha tha? |  |
| `backfill_forDay` | Check-in for {day} | {day} का चेक-इन | {day} ka check-in |  |
| `backfill_changeDay` | Change day | दिन बदलें | Din badlein |  |
| `backfill_outOfRange` | Past check-ins can go up to a week back. Could you pick another day? | पिछले चेक-इन सिर्फ़ एक हफ़्ते पीछे तक जोड़े जा सकते हैं। कोई और दिन चुनें? | Pichhle check-in sirf ek hafte peeche tak add kiye ja sakte hain. Koi aur din chunein? |  |
| `backfill_savedTitle` | Added to your sky | आपके आसमान में जुड़ गया | Aapke aasmaan mein jud gaya |  |
| `backfill_savedDay` | Saved for {day}. | {day} के लिए सेव हो गया। | {day} ke liye save ho gaya. |  |
| `backfill_savedBody` | Starlight comes from check-ins made on the day itself. | Starlight उसी दिन किए गए चेक-इन से मिलता है। | Starlight usi din kiye gaye check-in se milta hai. |  |
| `history_addedLater` | Added later | बाद में जोड़ा गया | Baad mein joda gaya |  |
| `history_whenAddedLater` | {day} · added later | {day} · बाद में जोड़ा गया | {day} · baad mein joda gaya |  |

### 13. Home, avatar, habits and progress

79 keys.

| Key | English | Hindi (`hi`) | Hinglish (`hi-Latn`) | Note |
|---|---|---|---|---|
| `home_checkIn` | Check in | चेक-इन करें | Check-in karein |  |
| `home_todayStarlight` | {count} Starlight today | आज {count} Starlight | Aaj {count} Starlight |  |
| `home_totalStarlight` | {count} in all | कुल {count} | Kul {count} |  |
| `home_empty` | This is your Aura. Check in to give it light. | यह आपका Aura है। इसे रोशनी देने के लिए चेक-इन करें। | Yeh aapka Aura hai. Ise roshni dene ke liye check-in karein. |  |
| `home_resting` | Your Aura has been resting. Say hi when you're ready. | आपका Aura कुछ समय से आराम कर रहा है। जब मन हो, हाय कहें। | Aapka Aura kuch time se aaram kar raha hai. Jab mann ho, hi keh dein. |  |
| `home_glowStreak` | {count, plural, =1{Glow streak · 1 day} other{Glow streak · {count} days}} | {count, plural, =1{चमक का सिलसिला · 1 दिन} other{चमक का सिलसिला · {count} दिन}} | {count, plural, =1{Glow streak · 1 din} other{Glow streak · {count} din}} | ‘Glow streak’ → hi चमक का सिलसिला (no ‘लगातार दिन’ pressure wording); hl keeps ‘Glow streak’ as the English names the setting. |
| `home_restDays` | {count, plural, =0{No rest days saved yet} =1{1 rest day saved} other{{count} rest days saved}} | {count, plural, =0{अभी कोई आराम का दिन जमा नहीं है} =1{1 आराम का दिन जमा है} other{{count} आराम के दिन जमा हैं}} | {count, plural, =0{Abhi koi rest day jama nahi hai} =1{1 rest day jama hai} other{{count} rest days jama hain}} |  |
| `home_restingSafe` | Resting · your glow is safe | आराम · आपकी चमक सुरक्षित है | Aaram · aapka glow safe hai |  |
| `home_glowCarriesOn` | Your glow carries on | आपकी चमक जारी है | Aapka glow jaari hai |  |
| `home_lifetimeGlow` | {count, plural, =1{1 glow day in all} other{{count} glow days in all}} | {count, plural, =1{कुल 1 चमक वाला दिन} other{कुल {count} चमक वाले दिन}} | {count, plural, =1{Kul 1 glow day} other{Kul {count} glow days}} |  |
| `home_habitsTitle` | Small things today | आज की छोटी-छोटी चीज़ें | Aaj ki chhoti-chhoti cheezein |  |
| `home_habitDone` | {habit}, done today | {habit}, आज हो गया | {habit}, aaj ho gaya |  |
| `home_habitNotYet` | {habit}, not yet today | {habit}, आज अभी नहीं | {habit}, aaj abhi nahi |  |
| `home_offline` | You're offline. Your own things still save here. | आप ऑफ़लाइन हैं। आपकी अपनी चीज़ें फिर भी यहाँ सेव होती रहेंगी। | Aap offline hain. Aapki apni cheezein phir bhi yahan save hoti rahengi. |  |
| `home_finishSetup` | Finish setting up so your Aura is kept safe. | सेटअप पूरा करें, ताकि आपका Aura सुरक्षित रहे। | Setup poora karein, taaki aapka Aura safe rahe. |  |
| `home_signIn` | Sign in | साइन इन करें | Sign in karein |  |
| `home_syncIdle` | All saved | सब सेव हो गया | Sab save ho gaya |  |
| `home_syncPending` | {count, plural, =1{1 thing waiting to sync} other{{count} things waiting to sync}} | {count, plural, =1{1 चीज़ सिंक होनी बाकी है} other{{count} चीज़ें सिंक होनी बाकी हैं}} | {count, plural, =1{1 cheez sync honi baaki hai} other{{count} cheezein sync honi baaki hain}} |  |
| `home_syncLocal` | Saved on this phone | इस फ़ोन पर सेव हो गया | Is phone par save ho gaya |  |
| `home_settings` | Settings | सेटिंग्स | Settings |  |
| `home_welcomeBack` | Welcome back. One small thing today is plenty. | फिर से स्वागत है। आज एक छोटी-सी चीज़ ही काफ़ी है। | Phir se swagat hai. Aaj ek chhoti si cheez hi kaafi hai. |  |
| `home_evolved` | Your Aura grew into {stage}. | आपका Aura बढ़कर {stage} बन गया। | Aapka Aura badhkar {stage} ban gaya. |  |
| `stage_spark` | Spark | चिंगारी | Spark | Stage names: hi uses Hindi words (चिंगारी, अंगारा, चमक, आभा, तारामंडल); hl keeps English like the Tenglish draft. |
| `stage_ember` | Ember | अंगारा | Ember |  |
| `stage_glow` | Glow | चमक | Glow |  |
| `stage_radiance` | Radiance | आभा | Radiance |  |
| `stage_constellation` | Constellation | तारामंडल | Constellation |  |
| `habit_hydrate` | Hydrate | पानी पीना | Paani peena | Habits are written as infinitives (पानी पीना / Paani peena …) so they work both as labels and inside '{habit}, आज हो गया'. |
| `habit_sleep_on_time` | Sleep on time | समय पर सोना | Time par sona |  |
| `habit_move` | Move | चलना-फिरना | Chalna-phirna |  |
| `habit_breathe` | Breathe | साँस लेना | Saans lena |  |
| `habit_journal` | Journal | डायरी लिखना | Diary likhna |  |
| `habit_go_outside` | Go outside | बाहर जाना | Bahar jaana |  |
| `avatar_semantic` | Your Aura, {stage} stage, {hue} glow | आपका Aura, {stage} स्टेज, चमक का रंग {hue} | Aapka Aura, {stage} stage, {hue} glow | hi restructured as 'चमक का रंग {hue}' so the hue adjectives (सुनहरा, हरा …) don't need gender or case agreement. |
| `avatar_semanticResting` | resting in a soft nebula | नरम नेबुला में आराम करता हुआ | naram nebula mein aaram karta hua |  |
| `avatar_semanticRings` | {count, plural, =1{one orbiting light} other{{count} orbiting lights}} | {count, plural, =1{चारों ओर घूमती एक रोशनी} other{चारों ओर घूमती {count} रोशनियाँ}} | {count, plural, =1{chaaron taraf ghoomti ek roshni} other{chaaron taraf ghoomti {count} roshniyan}} |  |
| `avatar_semanticStars` | {count, plural, =1{one star in its constellation} other{{count} stars in its constellation}} | {count, plural, =1{इसके तारामंडल में एक तारा} other{इसके तारामंडल में {count} तारे}} | {count, plural, =1{iske constellation mein ek taara} other{iske constellation mein {count} taare}} |  |
| `hue_gold` | golden | सुनहरा | sunehra |  |
| `hue_green` | green | हरा | hara |  |
| `hue_teal` | teal | टील | teal |  |
| `hue_silverBlue` | silver-blue | सिल्वर-नीला | silver-blue |  |
| `hue_violet` | violet | बैंगनी | baingani |  |
| `hue_rose` | rose | गुलाबी | gulaabi |  |
| `home_stageProgress` | {stage}, {count} of {target} Starlight toward {next} | {stage}, {next} की ओर {target} में से {count} Starlight | {stage}, {next} ki taraf {target} mein se {count} Starlight |  |
| `home_constellationProgress` | {stage}, {count} of {max} stars in your constellation | {stage}, आपके तारामंडल में {max} में से {count} तारे | {stage}, aapke constellation mein {max} mein se {count} stars |  |
| `home_glowTitle` | Your glow | आपकी चमक | Aapka glow | ‘glow’ rendered as चमक in hi (चमक वाले दिन = glow days); kept English ‘glow’ in hl like Tenglish. Align with other chunks' term for glow/glow days. |
| `home_restDaysHint` | Learn how rest days work | जानें कि आराम के दिन कैसे काम करते हैं | Jaanein ki rest days kaise kaam karte hain |  |
| `home_restInfoTitle` | Rest days | आराम के दिन | Rest days |  |
| `home_restInfoEarn` | Every {days} glow days earn a rest day. You can keep up to {max}. | हर {days} चमक वाले दिनों पर एक आराम का दिन मिलता है। {max} तक जमा रखे जा सकते हैं। | Har {days} glow days par ek rest day milta hai. {max} tak jama rakhe ja sakte hain. | ‘You can keep up to {max}’ rephrased impersonally (जमा रखे जा सकते हैं) to avoid gendered सकते/सकती. |
| `home_restInfoUse` | When you take a short break, they fill in those days on their own. There's nothing you need to do. | छोटे ब्रेक के दौरान ये उन दिनों को अपने-आप भर देते हैं। आपको कुछ नहीं करना है। | Chhote break ke dauraan ye un dinon ko apne aap bhar dete hain. Aapko kuch nahi karna hai. | ‘When you take a short break’ rephrased as ‘during a short break’ to avoid gendered लेते/लेती. |
| `home_restInfoKeep` | Every glow day you've had stays with you. | आपका हर चमक वाला दिन आपके साथ रहता है। | Aapka har glow day aapke saath rehta hai. |  |
| `home_checkInsToday` | {count, plural, =1{1 check-in today} other{{count} check-ins today}} | {count, plural, =1{आज 1 चेक-इन} other{आज {count} चेक-इन}} | {count, plural, =1{Aaj 1 check-in} other{Aaj {count} check-ins}} |  |
| `home_seeAll` | See all | सब देखें | Sab dekhein |  |
| `home_yourCheckIns` | Your check-ins | आपके चेक-इन | Aapke check-ins |  |
| `home_syncExplainIdle` | Everything is saved on this phone and in your account. | सब कुछ इस फ़ोन पर और आपके अकाउंट में सेव है। | Sab kuch is phone par aur aapke account mein save hai. |  |
| `home_syncExplainPending` | They're safe on this phone and will sync on their own. | ये इस फ़ोन पर सुरक्षित हैं और अपने-आप सिंक हो जाएँगे। | Ye is phone par safe hain aur apne aap sync ho jayenge. |  |
| `home_syncExplainOffline` | You're offline. Everything is safe on this phone and syncs when you're back online. | आप ऑफ़लाइन हैं। सब कुछ इस फ़ोन पर सुरक्षित है और फिर से ऑनलाइन होने पर सिंक हो जाएगा। | Aap offline hain. Sab kuch is phone par safe hai aur phir se online hone par sync ho jayega. |  |
| `home_syncExplainSignedOut` | You're not signed in, so everything stays on this phone for now. | आपने साइन इन नहीं किया है, इसलिए अभी सब कुछ इसी फ़ोन पर रहेगा। | Aapne sign in nahi kiya hai, isliye abhi sab kuch isi phone par rahega. |  |
| `home_syncExplainUnavailable` | This version keeps everything on this phone. | यह वर्ज़न सब कुछ इसी फ़ोन पर रखता है। | Ye version sab kuch isi phone par rakhta hai. |  |
| `home_syncNow` | Sync now | अभी सिंक करें | Abhi sync karein |  |
| `home_syncing` | Syncing… | सिंक हो रहा है… | Sync ho raha hai… |  |
| `home_syncHint` | Show sync details | सिंक की जानकारी देखें | Sync details dekhein |  |
| `habits_edit` | Edit | एडिट करें | Edit karein |  |
| `habits_editSemantic` | Edit small things | छोटे काम एडिट करें | Chhote kaam edit karein |  |
| `habits_sheetTitle` | Your small things | आपके छोटे काम | Aapke chhote kaam |  |
| `habits_sheetBody` | Choose what shows on Home. Check-ins grow your Aura either way. | चुनें कि होम पर क्या दिखे। चेक-इन से आपका Aura हर हाल में बढ़ता है। | Chunein ki Home par kya dikhe. Check-ins se aapka Aura har haal mein badhta hai. |  |
| `habits_presetsTitle` | Suggested | सुझाव | Suggestions |  |
| `habits_customTitle` | Your own | आपके अपने | Aapke apne |  |
| `habits_addLabel` | Add your own | अपना जोड़ें | Apna add karein |  |
| `habits_addHint` | For example, water the plants | जैसे, पौधों को पानी देना | Jaise, paudhon ko paani dena |  |
| `habits_add` | Add | जोड़ें | Add karein |  |
| `habits_limit` | You have {count} custom habits. Swap one to add another. | आपके पास {count} कस्टम आदतें हैं। नई जोड़ने के लिए किसी एक को बदलें। | Aapke paas {count} custom habits hain. Nayi add karne ke liye kisi ek ko swap karein. |  |
| `habits_saveFailed` | That didn't save. Could you try again? | यह सेव नहीं हुआ। फिर से कोशिश करें? | Ye save nahi hua. Phir se try karein? |  |
| `habits_remove` | Remove {name} | {name} हटाएँ | {name} hatayein |  |
| `habits_removeTitle` | Remove {name}? | {name} हटाएँ? | {name} hatayein? |  |
| `habits_removeBody` | It leaves your list. Starlight and glow days you earned with it stay. | यह आपकी लिस्ट से हट जाएगा। इससे मिले Starlight और चमक वाले दिन बने रहेंगे। | Ye aapki list se hat jayega. Isse mile Starlight aur glow days bane rahenge. |  |
| `habits_removeConfirm` | Remove | हटाएँ | Hatayein |  |
| `habits_empty` | Pick one small thing to start. | शुरू करने के लिए एक छोटा काम चुनें। | Shuru karne ke liye ek chhota kaam chunein. |  |
| `habits_autoLogged` | {habit} is marked done for today. | आज के लिए {habit} को पूरा मार्क किया गया। | Aaj ke liye {habit} ko done mark kiya gaya. |  |

### 14. Settings, shell and everything else

45 keys.

| Key | English | Hindi (`hi`) | Hinglish (`hi-Latn`) | Note |
|---|---|---|---|---|
| `appTitle` | Aura | Aura | Aura |  |
| `common_continue` | Continue | आगे बढ़ें | Aage badhein |  |
| `common_back` | Back | वापस | Wapas |  |
| `common_done` | Done | हो गया | Ho gaya |  |
| `common_notNow` | Not now | अभी नहीं | Abhi nahi |  |
| `common_cancel` | Cancel | रद्द करें | Cancel karein |  |
| `common_close` | Close | बंद करें | Band karein |  |
| `common_comingSoon` | Coming soon | जल्द आ रहा है | Jald aa raha hai |  |
| `settings_title` | Settings | सेटिंग्स | Settings |  |
| `settings_language` | Language | भाषा | Bhasha |  |
| `settings_account` | Account | अकाउंट | Account |  |
| `settings_signedInAs` | Signed in as {email} | {email} से साइन इन है | {email} se sign in hai |  |
| `settings_signOut` | Sign out | साइन आउट करें | Sign out karein |  |
| `settings_signOutPending` | {count, plural, =1{1 thing hasn't synced yet. Stay signed in until it does?} other{{count} things haven't synced yet. Stay signed in until they do?}} | {count, plural, =1{1 चीज़ अभी सिंक नहीं हुई है। उसके सिंक होने तक साइन इन रहें?} other{{count} चीज़ें अभी सिंक नहीं हुई हैं। उनके सिंक होने तक साइन इन रहें?}} | {count, plural, =1{1 cheez abhi sync nahi hui hai. Uske sync hone tak sign in rahein?} other{{count} cheezein abhi sync nahi hui hain. Unke sync hone tak sign in rahein?}} |  |
| `settings_stay` | Stay signed in | साइन इन रहें | Sign in rahein |  |
| `settings_signOutAnyway` | Sign out anyway | फिर भी साइन आउट करें | Phir bhi sign out karein |  |
| `settings_signIn` | Sign in to keep your Aura safe | अपना Aura सुरक्षित रखने के लिए साइन इन करें | Apna Aura safe rakhne ke liye sign in karein |  |
| `settings_avatarLab` | Avatar lab | अवतार लैब | Avatar lab |  |
| `settings_about` | About | बारे में | About |  |
| `settings_version` | Version {version} | वर्ज़न {version} | Version {version} |  |
| `set_comfort` | Comfort | सहूलियत | Comfort | hi uses सहूलियत to avoid clashing with आराम (rest day); hl keeps English 'Comfort'. |
| `set_reduceMotion` | Reduce motion | मोशन कम करें | Motion kam karein |  |
| `set_reduceMotionNote` | Also follows your phone's setting | आपके फ़ोन की सेटिंग को भी मानता है | Aapke phone ki setting ko bhi follow karta hai |  |
| `set_haptics` | Haptics | हैप्टिक्स | Haptics |  |
| `set_hapticsNote` | Soft taps when you choose something | कुछ चुनने पर हल्का वाइब्रेशन | Kuch chunne par halka vibration |  |
| `set_hideStreak` | Hide streak number | स्ट्रीक नंबर छिपाएँ | Streak number chhupayein | Kept 'streak' because the English names the setting; no pressure wording added. |
| `set_hideStreakNote` | Your glow still grows. Home just won't count the days. | आपकी चमक बढ़ती रहेगी। बस होम पर दिन नहीं गिने जाएँगे। | Aapka glow badhta rahega. Bas Home par din nahi gine jayenge. |  |
| `set_signOutTitle` | Sign out of Aura? | Aura से साइन आउट करें? | Aura se sign out karein? |  |
| `set_grievanceSubject` | Grievance about Aura | Aura के बारे में शिकायत | Aura ke baare mein shikayat |  |
| `set_contactSupport` | Contact support | सपोर्ट से संपर्क करें | Support se contact karein |  |
| `set_supportSubject` | Aura support | Aura सपोर्ट | Aura support |  |
| `set_opensEmail` | Opens your email app | आपका ईमेल ऐप खुलेगा | Aapka email app khulega |  |
| `set_emailFailed` | We couldn't open an email app. You can write to {email}. | कोई ईमेल ऐप नहीं खुल पाया। {email} पर लिखें। | Koi email app nahi khul paaya. {email} par likhein. | Rephrased to imperative ('{email} पर लिखें') to avoid gendered सकते/सकती. |
| `polish_legalOpenFailed` | Your browser didn't open. The page is at {url}. | आपका ब्राउज़र नहीं खुला। यह पेज {url} पर है। | Aapka browser nahi khula. Yeh page {url} par hai. |  |
| `polish_legalCopyLink` | Copy link | लिंक कॉपी करें | Link copy karein |  |
| `polish_legalLinkCopied` | Link copied | लिंक कॉपी हो गया | Link copy ho gaya |  |
| `polish_helpCallFailed` | This phone can't place the call. The number is {number}. | इस फ़ोन से कॉल करना मुमकिन नहीं है। नंबर है {number}। | Is phone se call karna mumkin nahi hai. Number hai {number}. |  |
| `polish_helpCopyNumber` | Copy number | नंबर कॉपी करें | Number copy karein |  |
| `polish_helpNumberCopied` | Number copied | नंबर कॉपी हो गया | Number copy ho gaya |  |
| `shell_tabHome` | Home | होम | Home |  |
| `shell_tabSanctuary` | Sanctuary | सुकून | Sanctuary |  |
| `shell_tabRooms` | Rooms | रूम | Rooms |  |
| `shell_tabInsights` | Insights | समझ | Insights |  |
| `shell_checkIn` | Check in | चेक-इन | Check-in |  |
| `shell_checkInHint` | Starts a new check-in | नया चेक-इन शुरू करता है | Naya check-in shuru karta hai |  |
