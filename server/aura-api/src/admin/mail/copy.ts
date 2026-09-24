import type { GrievanceCategory } from '../clocks';

/**
 * Every localized line of the emails Aura sends to people (not staff): the grievance acknowledgement and the
 * deletion-case confirmation link — in one place so a reviewer reads all three languages side by side
 * (docs/l10n/helplines-and-emails.md). English is the reviewed original; **te and te-Latn are drafts that NEED NATIVE
 * REVIEW** before alpha, like every non-English string (Telugu uses the respectful *meeru* form).
 *
 * Content rules (the same in every language): never quote the complaint back, never a date of birth, a mood or any
 * account detail; the only link is the random-token deletion link (no personal data in a URL). Hindi and Hinglish
 * ship from beta: until then those accounts get English (`mailLocale`). The decision reply and staff mail stay English.
 */
export const MAIL_LOCALES = ['en', 'te', 'te-Latn'] as const;
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
};
