import type { GrievanceCategory } from '../clocks';

/**
 * Every localized line of the emails Aura sends to people (not staff): the grievance acknowledgement, the
 * deletion-case confirmation link and the trial-ending reminder (src/user-mail) — in one place so a reviewer reads
 * all five languages side by side (docs/l10n/helplines-and-emails.md, docs/l10n/hindi-review.md). English is the
 * reviewed original; **te, te-Latn, hi and hi-Latn are drafts that NEED NATIVE REVIEW**, like every non-English
 * string (Telugu uses the respectful *meeru* form, Hindi and Hinglish *aap* with no verb that agrees with the reader's
 * gender).
 *
 * Content rules (the same in every language): never quote the complaint back, never a date of birth, a mood or any
 * account detail; the only links are the random-token deletion link and the store's own subscription page (no
 * personal data in a URL). Other languages get English (`mailLocale`). The decision reply and staff mail stay English.
 */
export const MAIL_LOCALES = ['en', 'te', 'te-Latn', 'hi', 'hi-Latn'] as const;
export type MailLocale = (typeof MAIL_LOCALES)[number];

/** An app locale (`profiles.ui_locale`, a grievance's `locale`) → the email language; anything else → English. */
export function mailLocale(locale: string | null | undefined): MailLocale {
  return (MAIL_LOCALES as readonly string[]).includes(locale ?? '') ? (locale as MailLocale) : 'en';
}

export interface MailCopy {
  /** Intl locale for dates (romanized locales use English formats, PRD 18). */
  dateLocale: string;
  hello: string;
  helloNamed: (name: string) => string;
  withinDays: (n: number) => string;
  withinHours: (n: number) => string;
  officer: (contact: string) => string;
  publisher: string;
  safety: string;
  categories: Readonly<Record<GrievanceCategory, string>>;
  ack: {
    subject: (ticket: string) => string;
    intro: string;
    ticket: string;
    received: string;
    category: string;
    resolveBy: (when: string, window: string) => string;
    quoteTicket: string;
  };
  /**
   * The trial-ending email (PRD 12 "Aura Plus trial ending": push + in-app card + email; "Trial-ending reminder rules").
   * Facts only: the end date, the store's own price string and period, and the store's subscription page. The first
   * sentence is word for word the push line (push-copy.ts `trial_ending*`). Transactional and sent once, so there is
   * no unsubscribe link; nothing about moods, content or the account beyond the trial.
   */
  trialEnding: {
    subject: (date: string) => string;
    facts: (date: string, price: string) => string;
    factsYear: (date: string, price: string) => string;
    factsNoPrice: (date: string) => string;
    cancelHow: (store: string) => string;
    once: string;
  };
  deletion: {
    subject: (ticket: string) => string;
    intro: (ticket: string) => string;
    ifYou: string;
    linkWorks: (until: string) => string;
    ifNot: string;
    next: (graceDays: number) => string;
  };
}

export const MAIL_COPY: Readonly<Record<MailLocale, MailCopy>> = {
  en: {
    dateLocale: 'en-IN',
    hello: 'Hello,',
    helloNamed: (name) => `Hello ${name},`,
    withinDays: (n) => `within ${n} days`,
    withinHours: (n) => `within ${n} hours`,
    officer: (contact) => `Grievance Officer: ${contact}`,
    publisher: 'Aura is published by AKVega.',
    safety: 'If someone is in immediate danger, call your local emergency number (India: 112).',
    categories: {
      general: 'Complaint about content or conduct',
      unlawful_content: 'Unlawful content',
      nudity_csam: 'Nudity, sexual content or child sexual abuse material',
      ncii: 'Intimate images shared without consent',
      data_request: 'My data or my account',
      moderation_appeal: 'Appeal a moderation decision',
    },
    ack: {
      subject: (ticket) => `Aura: we received your grievance ${ticket}`,
      intro: "Thank you for writing to Aura's Grievance Officer. This email acknowledges your grievance.",
      ticket: 'Ticket',
      received: 'Received',
      category: 'Category',
      resolveBy: (when, window) => `We will resolve it by: ${when} (${window} of receipt)`,
      quoteTicket: 'Please quote your ticket number if you write to us again. You can reply to this email.',
    },
    trialEnding: {
      subject: (date) => `Aura Plus: your free month ends on ${date}`,
      facts: (date, price) => `Your free month of Aura Plus ends on ${date}. After that it's ${price}/month. Keep it or cancel anytime.`,
      factsYear: (date, price) => `Your free month of Aura Plus ends on ${date}. After that it's ${price}/year. Keep it or cancel anytime.`,
      factsNoPrice: (date) => `Your free month of Aura Plus ends on ${date}. Keep it or cancel anytime in the store.`,
      cancelHow: (store) => `To cancel or change it, open your ${store} subscriptions:`,
      once: 'This is a one-time email: your free month is ending, and Aura sends no other email about it.',
    },
    deletion: {
      subject: (ticket) => `Aura: confirm the request to delete your account (${ticket})`,
      intro: (ticket) =>
        `Aura's Grievance Officer received a request to delete the Aura account that signs in with this email address (request ${ticket}).`,
      ifYou: 'If you made this request, open the link below and press "Delete my account":',
      linkWorks: (until) => `The link works once, until ${until}.`,
      ifNot:
        "If you did not ask for this, you don't need to do anything: nothing is deleted without your confirmation. You can also open the link and press \"This wasn't me\".",
      next: (graceDays) =>
        `What happens next: once you confirm, Aura starts the same deletion as the in-app option. The account is switched off straight away and deleted for good within 30 days (normally after ${graceDays} days, during which signing in to the app lets you keep it). Records the law requires us to keep (for example about reported content) are kept only as long as required.`,
    },
  },

  // DRAFT — NEEDS NATIVE REVIEW. The confirmation page's buttons are English ("Delete my account", "This wasn't me"),
  // so the email names them in English.
  te: {
    dateLocale: 'te-IN',
    hello: 'నమస్కారం,',
    helloNamed: (name) => `నమస్కారం ${name} గారు,`,
    withinDays: (n) => `${n} రోజుల్లోపు`,
    withinHours: (n) => `${n} గంటల్లోపు`,
    officer: (contact) => `గ్రీవెన్స్ ఆఫీసర్: ${contact}`,
    publisher: 'Aura ను AKVega ప్రచురిస్తోంది.',
    safety: 'ఎవరైనా తక్షణ ప్రమాదంలో ఉంటే, మీ స్థానిక అత్యవసర నంబర్‌కు కాల్ చేయండి (భారతదేశం: 112).',
    categories: {
      general: 'కంటెంట్ లేదా ప్రవర్తనపై ఫిర్యాదు',
      unlawful_content: 'చట్టవిరుద్ధమైన కంటెంట్',
      nudity_csam: 'నగ్నత్వం, లైంగిక కంటెంట్ లేదా పిల్లలపై లైంగిక వేధింపుల కంటెంట్',
      ncii: 'అనుమతి లేకుండా పంచుకున్న వ్యక్తిగత చిత్రాలు',
      data_request: 'నా డేటా లేదా నా ఖాతా',
      moderation_appeal: 'మోడరేషన్ నిర్ణయంపై అప్పీల్',
    },
    ack: {
      subject: (ticket) => `Aura: మీ ఫిర్యాదు ${ticket} మాకు అందింది`,
      intro: 'Aura గ్రీవెన్స్ ఆఫీసర్‌కు రాసినందుకు ధన్యవాదాలు. మీ ఫిర్యాదు మాకు అందిందని ఈ ఈమెయిల్ నిర్ధారిస్తోంది.',
      ticket: 'టికెట్',
      received: 'అందిన సమయం',
      category: 'విభాగం',
      resolveBy: (when, window) => `పరిష్కరించే గడువు: ${when} (అందినప్పటి నుండి ${window})`,
      quoteTicket: 'మాకు మళ్ళీ రాసేటప్పుడు దయచేసి మీ టికెట్ నంబర్‌ను పేర్కొనండి. ఈ ఈమెయిల్‌కు మీరు జవాబు ఇవ్వవచ్చు.',
    },
    trialEnding: {
      subject: (date) => `Aura Plus: మీ ఉచిత నెల ${date}తో ముగుస్తుంది`,
      facts: (date, price) => `మీ Aura Plus ఉచిత నెల ${date}తో ముగుస్తుంది. తర్వాత నెలకు ${price}. కొనసాగించవచ్చు, లేదా ఎప్పుడైనా రద్దు చేయవచ్చు.`,
      factsYear: (date, price) => `మీ Aura Plus ఉచిత నెల ${date}తో ముగుస్తుంది. తర్వాత సంవత్సరానికి ${price}. కొనసాగించవచ్చు, లేదా ఎప్పుడైనా రద్దు చేయవచ్చు.`,
      factsNoPrice: (date) => `మీ Aura Plus ఉచిత నెల ${date}తో ముగుస్తుంది. కొనసాగించవచ్చు, లేదా ఎప్పుడైనా రద్దు చేయవచ్చు.`,
      cancelHow: (store) => `రద్దు చేయడానికి లేదా మార్చడానికి, మీ ${store} సబ్‌స్క్రిప్షన్లు తెరవండి:`,
      once: 'ఇది ఒక్కసారి మాత్రమే వచ్చే ఈమెయిల్: మీ ఉచిత నెల ముగుస్తోంది. దీని గురించి Aura మరే ఈమెయిల్ పంపదు.',
    },
    deletion: {
      subject: (ticket) => `Aura: మీ ఖాతా తొలగింపు అభ్యర్థనను నిర్ధారించండి (${ticket})`,
      intro: (ticket) =>
        `ఈ ఈమెయిల్ చిరునామాతో సైన్ ఇన్ అయ్యే Aura ఖాతాను తొలగించమని Aura గ్రీవెన్స్ ఆఫీసర్‌కు ఒక అభ్యర్థన అందింది (అభ్యర్థన ${ticket}).`,
      ifYou: 'ఈ అభ్యర్థన మీరే చేసి ఉంటే, కింది లింక్ తెరిచి "Delete my account" నొక్కండి:',
      linkWorks: (until) => `ఈ లింక్ ఒక్కసారి మాత్రమే, ${until} వరకు పనిచేస్తుంది.`,
      ifNot:
        'ఇది మీరు అడగకపోతే, మీరు ఏమీ చేయనవసరం లేదు: మీ నిర్ధారణ లేకుండా ఏదీ తొలగించబడదు. లింక్ తెరిచి "This wasn\'t me" కూడా నొక్కవచ్చు.',
      next: (graceDays) =>
        `తర్వాత ఏమవుతుంది: మీరు నిర్ధారించగానే, యాప్‌లోని తొలగింపు ఎంపిక లాగానే Aura తొలగింపును మొదలుపెడుతుంది. ఖాతా వెంటనే ఆగిపోతుంది, 30 రోజుల్లోపు శాశ్వతంగా తొలగించబడుతుంది (సాధారణంగా ${graceDays} రోజుల తర్వాత; ఆ లోపు యాప్‌లో సైన్ ఇన్ చేస్తే ఖాతాను ఉంచుకోవచ్చు). చట్టం ప్రకారం మేము ఉంచాల్సిన రికార్డులు (ఉదాహరణకు రిపోర్ట్ చేసిన కంటెంట్ గురించి) అవసరమైనంత కాలం మాత్రమే ఉంచుతాం.`,
    },
  },

  // DRAFT — NEEDS NATIVE REVIEW (Tenglish: Telugu in Latin letters, English words kept where people use them).
  'te-Latn': {
    dateLocale: 'en-IN',
    hello: 'Namaskaram,',
    helloNamed: (name) => `Namaskaram ${name} garu,`,
    withinDays: (n) => `${n} rojullo`,
    withinHours: (n) => `${n} gantallo`,
    officer: (contact) => `Grievance Officer: ${contact}`,
    publisher: 'Aura ni AKVega publish chestondi.',
    safety: 'Evaraina ventane pramaadam lo unte, mee local emergency number ki call cheyandi (India: 112).',
    categories: {
      general: 'Content leda pravartana meeda complaint',
      unlawful_content: 'Chattaviruddhamaina content',
      nudity_csam: 'Nagnatvam, sexual content leda pillala meeda sexual abuse content',
      ncii: 'Anumati lekunda share chesina private photos',
      data_request: 'Naa data leda naa account',
      moderation_appeal: 'Moderation nirnayam meeda appeal',
    },
    ack: {
      subject: (ticket) => `Aura: mee grievance ${ticket} maaku andindi`,
      intro: 'Aura Grievance Officer ki raasinanduku dhanyavaadaalu. Mee grievance maaku andindani ee email confirm chestondi.',
      ticket: 'Ticket',
      received: 'Andina samayam',
      category: 'Category',
      resolveBy: (when, window) => `Parishkarinche gaduvu: ${when} (andinappati nundi ${window})`,
      quoteTicket: 'Maaku malli raasetappudu dayachesi mee ticket number mention cheyandi. Ee email ki reply ivvochu.',
    },
    trialEnding: {
      subject: (date) => `Aura Plus: mee free month ${date} tho aipotundi`,
      facts: (date, price) => `Mee Aura Plus free month ${date} tho aipotundi. Tarvatha nelaki ${price}. Continue cheyyochu, leda eppudaina cancel cheyyochu.`,
      factsYear: (date, price) =>
        `Mee Aura Plus free month ${date} tho aipotundi. Tarvatha samvatsaraaniki ${price}. Continue cheyyochu, leda eppudaina cancel cheyyochu.`,
      factsNoPrice: (date) => `Mee Aura Plus free month ${date} tho aipotundi. Continue cheyyochu, leda eppudaina cancel cheyyochu.`,
      cancelHow: (store) => `Cancel cheyyadaniki leda maarchadaniki, mee ${store} subscriptions open cheyandi:`,
      once: 'Idi okkasaari maatrame vache email: mee free month aipotondi. Deeni gurinchi Aura inko email pampadu.',
    },
    deletion: {
      subject: (ticket) => `Aura: mee account delete request ni confirm cheyandi (${ticket})`,
      intro: (ticket) =>
        `Ee email address tho sign in ayye Aura account ni delete cheyyamani Aura Grievance Officer ki oka request vachindi (request ${ticket}).`,
      ifYou: 'Ee request meere chesi unte, kindi link open chesi "Delete my account" nokkandi:',
      linkWorks: (until) => `Ee link okkasaari maatrame, ${until} varaku pani chestundi.`,
      ifNot:
        'Idi meeru adagakapothe, meeru emi cheyyanakkarledu: mee confirmation lekunda edi delete avvadu. Link open chesi "This wasn\'t me" kooda nokkavachu.',
      next: (graceDays) =>
        `Tarvatha emi jarugutundi: meeru confirm cheyagaane, app lo unna delete option laage Aura deletion start chestundi. Account ventane off avutundi, 30 rojullo purtiga delete avutundi (maamulugaa ${graceDays} rojula tarvatha; aa lopu app lo sign in chesthe account ni unchukovachu). Chattam prakaaram memu unchaalsina records (udaharanaki report chesina content gurinchi) avasaram ainanta kaalam maatrame unchutaam.`,
    },
  },

  // DRAFT — NEEDS NATIVE REVIEW (Milestone B). Hindi in Devanagari; brand and button names stay English.
  hi: {
    dateLocale: 'hi-IN',
    hello: 'नमस्ते,',
    helloNamed: (name) => `नमस्ते ${name} जी,`,
    withinDays: (n) => `${n} दिनों के भीतर`,
    withinHours: (n) => `${n} घंटों के भीतर`,
    officer: (contact) => `शिकायत अधिकारी (Grievance Officer): ${contact}`,
    publisher: 'Aura को AKVega प्रकाशित करता है।',
    safety: 'अगर कोई तुरंत ख़तरे में है, तो अपने स्थानीय इमरजेंसी नंबर पर कॉल करें (भारत: 112)।',
    categories: {
      general: 'कंटेंट या व्यवहार के बारे में शिकायत',
      unlawful_content: 'ग़ैर-क़ानूनी कंटेंट',
      nudity_csam: 'नग्नता, यौन कंटेंट या बच्चों के यौन शोषण से जुड़ी सामग्री',
      ncii: 'बिना सहमति के शेयर की गई निजी तस्वीरें',
      data_request: 'मेरा डेटा या मेरा अकाउंट',
      moderation_appeal: 'मॉडरेशन के फ़ैसले के ख़िलाफ़ अपील',
    },
    ack: {
      subject: (ticket) => `Aura: आपकी शिकायत ${ticket} हमें मिल गई है`,
      intro: 'Aura के शिकायत अधिकारी को लिखने के लिए धन्यवाद। यह ईमेल इस बात की पुष्टि है कि आपकी शिकायत हमें मिल गई है।',
      ticket: 'टिकट',
      received: 'मिलने का समय',
      category: 'श्रेणी',
      resolveBy: (when, window) => `समाधान की समय-सीमा: ${when} (मिलने के ${window})`,
      quoteTicket: 'हमें दोबारा लिखते समय कृपया अपना टिकट नंबर बताएँ। इस ईमेल का जवाब भी दिया जा सकता है।',
    },
    trialEnding: {
      subject: (date) => `Aura Plus: आपका मुफ़्त महीना ${date} को पूरा होगा`,
      facts: (date, price) => `Aura Plus का आपका मुफ़्त महीना ${date} को पूरा होगा। उसके बाद ${price}/महीना। इसे जारी रखें या कभी भी रद्द करें।`,
      factsYear: (date, price) => `Aura Plus का आपका मुफ़्त महीना ${date} को पूरा होगा। उसके बाद ${price}/साल। इसे जारी रखें या कभी भी रद्द करें।`,
      factsNoPrice: (date) => `Aura Plus का आपका मुफ़्त महीना ${date} को पूरा होगा। इसे जारी रखें या स्टोर में कभी भी रद्द करें।`,
      cancelHow: (store) => `रद्द करने या बदलने के लिए, अपने ${store} सब्सक्रिप्शन खोलें:`,
      once: 'यह ईमेल सिर्फ़ एक बार भेजा जाता है: आपका मुफ़्त महीना पूरा होने वाला है। इसके बारे में Aura कोई और ईमेल नहीं भेजेगा।',
    },
    deletion: {
      subject: (ticket) => `Aura: अपना अकाउंट डिलीट करने के अनुरोध की पुष्टि करें (${ticket})`,
      intro: (ticket) =>
        `इस ईमेल पते से साइन इन होने वाले Aura अकाउंट को डिलीट करने का एक अनुरोध Aura के शिकायत अधिकारी को मिला है (अनुरोध ${ticket})।`,
      ifYou: 'अगर यह अनुरोध आपने किया है, तो नीचे दिया गया लिंक खोलें और "Delete my account" दबाएँ:',
      linkWorks: (until) => `यह लिंक सिर्फ़ एक बार, ${until} तक काम करेगा।`,
      ifNot:
        'अगर यह अनुरोध आपका नहीं है, तो कुछ भी करने की ज़रूरत नहीं: आपकी पुष्टि के बिना कुछ भी डिलीट नहीं होगा। चाहें तो लिंक खोलकर "This wasn\'t me" भी दबाया जा सकता है।',
      next: (graceDays) =>
        `आगे क्या होगा: आपकी पुष्टि होते ही Aura वही डिलीट प्रक्रिया शुरू करेगा जो ऐप के अंदर वाले विकल्प से होती है। अकाउंट तुरंत बंद हो जाएगा और 30 दिनों के भीतर हमेशा के लिए डिलीट हो जाएगा (आम तौर पर ${graceDays} दिनों के बाद; इस बीच ऐप में साइन इन करने पर अकाउंट बना रहेगा)। जिन रिकॉर्ड को क़ानूनन रखना ज़रूरी है (जैसे रिपोर्ट किए गए कंटेंट के बारे में), उन्हें सिर्फ़ ज़रूरी समय तक रखा जाता है।`,
    },
  },

  // DRAFT — NEEDS NATIVE REVIEW (Hinglish: Hindi in Latin letters, English words kept where people use them).
  'hi-Latn': {
    dateLocale: 'en-IN',
    hello: 'Namaste,',
    helloNamed: (name) => `Namaste ${name} ji,`,
    withinDays: (n) => `${n} dinon ke andar`,
    withinHours: (n) => `${n} ghanton ke andar`,
    officer: (contact) => `Grievance Officer: ${contact}`,
    publisher: 'Aura ko AKVega publish karta hai.',
    safety: 'Agar koi turant khatre mein hai, to apne local emergency number par call karein (India: 112).',
    categories: {
      general: 'Content ya vyavhaar ke baare mein complaint',
      unlawful_content: 'Gair-kaanooni content',
      nudity_csam: 'Nudity, sexual content ya bachchon ke yaun shoshan se juda content',
      ncii: 'Bina consent ke share ki gayi private photos',
      data_request: 'Mera data ya mera account',
      moderation_appeal: 'Moderation ke faisle ke khilaaf appeal',
    },
    ack: {
      subject: (ticket) => `Aura: aapki grievance ${ticket} humein mil gayi hai`,
      intro: 'Aura ke Grievance Officer ko likhne ke liye shukriya. Yeh email confirm karta hai ki aapki grievance humein mil gayi hai.',
      ticket: 'Ticket',
      received: 'Milne ka samay',
      category: 'Category',
      resolveBy: (when, window) => `Samadhan ki deadline: ${when} (milne ke ${window})`,
      quoteTicket: 'Humein dobara likhte waqt please apna ticket number batayein. Is email ka reply bhi kiya ja sakta hai.',
    },
    trialEnding: {
      subject: (date) => `Aura Plus: aapka free month ${date} ko poora hoga`,
      facts: (date, price) => `Aapka Aura Plus free month ${date} ko poora hoga. Uske baad ${price}/month. Ise continue karein ya kabhi bhi cancel karein.`,
      factsYear: (date, price) => `Aapka Aura Plus free month ${date} ko poora hoga. Uske baad ${price}/year. Ise continue karein ya kabhi bhi cancel karein.`,
      factsNoPrice: (date) => `Aapka Aura Plus free month ${date} ko poora hoga. Ise continue karein ya store mein kabhi bhi cancel karein.`,
      cancelHow: (store) => `Cancel karne ya badalne ke liye, apne ${store} subscriptions kholein:`,
      once: 'Yeh email sirf ek baar bheja jata hai: aapka free month poora hone wala hai. Iske baare mein Aura koi aur email nahi bhejega.',
    },
    deletion: {
      subject: (ticket) => `Aura: apna account delete karne ki request confirm karein (${ticket})`,
      intro: (ticket) =>
        `Is email address se sign in hone wale Aura account ko delete karne ki ek request Aura ke Grievance Officer ko mili hai (request ${ticket}).`,
      ifYou: 'Agar yeh request aapne ki hai, to neeche diya gaya link kholein aur "Delete my account" dabayein:',
      linkWorks: (until) => `Yeh link sirf ek baar, ${until} tak kaam karega.`,
      ifNot:
        'Agar yeh request aapki nahi hai, to kuch bhi karne ki zaroorat nahi: aapke confirmation ke bina kuch bhi delete nahi hoga. Chahein to link kholkar "This wasn\'t me" bhi dabaya ja sakta hai.',
      next: (graceDays) =>
        `Aage kya hoga: aapka confirmation milte hi Aura wahi deletion shuru karega jo app ke andar wale option se hota hai. Account turant band ho jayega aur 30 dinon ke andar hamesha ke liye delete ho jayega (aam taur par ${graceDays} dinon ke baad; is beech app mein sign in karne par account bana rahega). Jin records ko kaanoonan rakhna zaroori hai (jaise report kiye gaye content ke baare mein), unhein sirf zaroori samay tak rakha jata hai.`,
    },
  },
};
