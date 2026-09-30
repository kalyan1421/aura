/** Shapes of the NestJS `/admin/*` responses the console renders (server/aura-api/src/admin). */
export type StaffRole = 'owner' | 'moderator' | 'analyst';
export type Lane = 'crisis' | 'minors_grooming' | 'harassment' | 'spam';

export interface QueueSessionView {
  active: boolean;
  startedAt: string | null;
  minutesLeft: number;
  capped: boolean;
  breakUntil: string | null;
  maxMinutes: number;
  breakMinutes: number;
}

export interface SessionInfo {
  staff: { id: string; displayName: string; role: StaffRole; email: string | null };
  mfa: 'verified' | 'challenge' | 'enroll';
  /** REQ-ADM-01: Google Workspace SSO, or the development email sign-in. */
  firstFactor: 'sso' | 'dev';
  sessionStartedAt: string;
  sessionExpiresAt: string;
  /** PRD 19 "Queue sessions capped at 2 h"; null for analysts. */
  queueSession: QueueSessionView | null;
}

export interface StaffMember {
  staffId: string;
  displayName: string;
  role: StaffRole;
  disabled: boolean;
  email: string | null;
  lastSignInAt: string | null;
  totpEnrolled: boolean;
  sso: { provider: 'google'; domains: string[]; allowed: boolean };
  otherProviders: string[];
  createdAt: string;
  updatedAt: string;
  isMe: boolean;
}

export interface StaffList {
  staff: StaffMember[];
  sso: { configured: boolean; provider: string | null; domains: string[] };
}

export type DeletionCaseStatus =
  | 'awaiting_verification'
  | 'verified'
  | 'declined'
  | 'deletion_scheduled'
  | 'completed'
  | 'closed'
  | 'no_account'
  | 'staff_account';

export interface DeletionCase {
  caseId: string;
  ticket: string;
  channel: string;
  grievanceId: string | null;
  grievanceTicket: string | null;
  receivedAt: string;
  status: DeletionCaseStatus;
  accountEmailMasked: string | null;
  subjectHash: string | null;
  verification: { sentAt: string | null; expiresAt: string | null; attempts: number; verifiedAt: string | null; declinedAt: string | null };
  deletion: { mode: 'grace' | 'immediate'; reasonCode: string | null; requestedAt: string; requestedBy: string | null; scheduledFor: string | null; pending: boolean } | null;
  legalHold: { records: number; until: string | null };
  completedAt: string | null;
  closedAt: string | null;
  closedBy: string | null;
  closeOutcome: string | null;
  createdBy: string;
  createdAt: string;
  updatedAt: string;
  allowed: { resend: boolean; startDeletion: boolean; close: boolean };
  linkEmailed?: boolean | null;
}

export interface AuditExportStatus {
  configured: { dir: boolean; email: boolean; nightly: string | null; timezone: string };
  last: Array<{
    id: number;
    createdAt: string;
    actor: string;
    trigger: string | null;
    fromId: number | null;
    toId: number | null;
    rows: number | null;
    sha256: string | null;
    destinations: string[];
    chainVerified: boolean | null;
  }>;
}

export type AuditExportResult =
  | { status: 'exported'; manifest: { fromId: number; toId: number; rows: number; ndjsonSha256: string; chainVerified: boolean; filename: string }; destinations: string[]; failed: string[] }
  | { status: 'skipped'; reason: 'not_configured' | 'nothing_new' }
  | { status: 'failed'; failed: string[] };

export interface WorkEntry {
  kind: 'legal_order' | 'report' | 'grievance';
  id: string;
  priority: number;
  dueAt: string;
  createdAt: string;
  title: string;
  lane: Lane | null;
  minorInvolved: boolean;
  pages: boolean;
  ticket: string | null;
  href: string;
}

export interface LaneSummary {
  lane: Lane;
  priority: number;
  open: number;
  overdue: number;
  paging: number;
  oldestCreatedAt: string | null;
}

export interface QueueItem {
  reportId: string;
  lane: Lane;
  priority: number;
  reason: number;
  reasonKey: string;
  source: 'user' | 'auto';
  autoSignal: string | null;
  targetKind: string;
  createdAt: string;
  slaDueAt: string;
  overdue: boolean;
  pages: boolean;
  involvesMinor: boolean;
  reporterCount: number;
  note: string | null;
  room: { roomId: string; quadrant: string; languagePool: string; tzRegion: string; ageHours: number } | null;
  subject: { hash: string; pseudonym: string | null; accountAgeDays: number | null; activeStrikes: number; activeSanctions: string[] } | null;
  evidenceHoldId: string | null;
}

export interface SanctionView {
  sanctionId: string;
  subjectHash: string;
  kind: string;
  reasonCode: string;
  source: string;
  reportId: string | null;
  startsAt: string;
  endsAt: string | null;
  liftedAt: string | null;
  createdBy: string;
  active: boolean;
}

export interface EvidenceView {
  evidenceHoldId: string;
  itemKind: string;
  reason: string;
  capturedAt: string | null;
  createdAt: string;
  holdUntil: string;
  mandatoryReportRequired: boolean;
  mandatoryReportClosed: boolean;
  room: { quadrant: string | null; languagePool: string | null; tzRegion: string | null; createdAt: string | null; memoryAt: string | null; purgeAt: string | null } | null;
  note: string | null;
  people: Array<{ label: string; role: 'subject' | 'reporter' | 'member'; subjectHash: string | null; moodAtJoin: string | null; joinedAt: string | null; leftAt: string | null }>;
  gestures: Array<{ type: string | null; target: string | null; from: string | null; to: string | null; dropped: string | null; at: string | null }>;
}

export interface ItemView {
  report: {
    reportId: string;
    lane: Lane;
    priority: number;
    reason: number;
    reasonKey: string;
    source: string;
    autoSignal: string | null;
    targetKind: string;
    status: string;
    createdAt: string;
    slaDueAt: string;
    overdue: boolean;
    pages: boolean;
    involvesMinor: boolean;
    note: string | null;
    resolvedAt: string | null;
    resolvedBy: string | null;
    reporters: { count: number; reasons: string[] };
  };
  subject: {
    hash: string;
    pseudonym: string | null;
    accountAgeDays: number | null;
    under18: boolean;
    activeStrikes: number;
    strikes: Array<{ strikeId: string; reasonCode: string; createdAt: string; expiresAt: string; active: boolean }>;
    sanctions: SanctionView[];
    otherReports: Array<{ reportId: string; lane: Lane; reasonKey: string; status: string; createdAt: string }>;
  } | null;
  room: { roomId: string; quadrant: string; languagePool: string; tzRegion: string; ageHours: number; status: string; memoryAt: string; purgeAt: string } | null;
  evidence: EvidenceView | null;
  audit: Array<{ id: number; createdAt: string; actor: string; action: string; reasonCode: string | null }>;
  allowedActions: string[];
}

export interface MandatoryTask {
  evidenceHoldId: string;
  reportId: string | null;
  createdAt: string;
  holdUntil: string;
  subjectHashes: string[];
  checklist: Record<string, { done: boolean; auto: boolean; at: string | null }>;
  bundleExportedAt: string | null;
}

export interface GrievanceView {
  grievanceId: string;
  ticket: string;
  channel: string;
  category: string;
  categoryLabel: string;
  status: string;
  receivedAt: string;
  ackDueAt: string;
  resolveDueAt: string;
  pages: boolean;
  acknowledgedAt: string | null;
  ackEmailSentAt: string | null;
  resolvedAt: string | null;
  resolvedBy: string | null;
  outcome: string | null;
  replyEmailSentAt: string | null;
  overdue: boolean;
}

export interface GrievanceDetail extends GrievanceView {
  complainantName: string | null;
  complainantEmail: string;
  locale: string | null;
  description: string;
  contentLocation: string | null;
  reply: string | null;
  createdBy: string;
}

export interface Delivery {
  channel: string;
  round: number;
  level: number;
  attempt: number;
  ok: boolean;
  httpStatus: number | null;
  error: string | null;
  at: string;
  latencyMs?: number;
}

export interface LegalOrderView {
  legalOrderId: string;
  ticket: string;
  source: string;
  authority: string;
  reference: string | null;
  receivedAt: string;
  dueAt: string;
  intakeChannel: string;
  isTest: boolean;
  status: string;
  acknowledgedAt: string | null;
  acknowledgedBy: string | null;
  closedAt: string | null;
  closedBy: string | null;
  overdue: boolean;
  createdAt: string;
}

export interface LegalOrderDetail extends LegalOrderView {
  summary: string;
  targets: string | null;
  resolutionNote: string | null;
  createdBy: string;
  page: { pageId: string; status: string; round: number; escalationLevel: number; lastDeliveredAt: string | null; acknowledgedAt: string | null; deliveries: Delivery[] } | null;
}

export interface PageView {
  pageId: string;
  kind: string;
  refId: string | null;
  reason: string;
  lane: string | null;
  minorInvolved: boolean;
  isTest: boolean;
  dueAt: string | null;
  status: string;
  round: number;
  escalationLevel: number;
  nextAttemptAt: string | null;
  lastDeliveredAt: string | null;
  acknowledgedAt: string | null;
  acknowledgedBy: string | null;
  createdAt: string;
  ticket: string | null;
  deliveries: { total: number; ok: number; lastError: string | null };
}

export interface PagingStatus {
  channels: Array<{ name: string; level: number }>;
  configured: { webhook: string | null; escalationWebhook: string | null; email: boolean; smtp: boolean };
  warnings: string[];
  repeatMinutes: number;
  escalateAfterMinutes: number;
  weeklyTest: { cron: string; timezone: string } | null;
  lastTest: { pageId: string; reason: string; createdAt: string; status: string; acknowledgedAt: string | null } | null;
}

export interface AuditEntry {
  id: number;
  createdAt: string;
  actor: string;
  actorLabel: string;
  action: string;
  reportId: string | null;
  subjectHash: string | null;
  reasonCode: string | null;
  detail: Record<string, unknown>;
  rowHash: string;
}

export interface ConsoleConfig {
  flags: Array<{ key: string; enabled: boolean; description: string | null; updatedAt: string | null }>;
  matching: Record<string, unknown>;
  safety: Record<string, unknown>;
}

export interface Stats {
  lanes: Array<{ lane: Lane; open: number; overdue: number; paging: number }>;
  grievances: { open: number; overdue: number; paging: number };
  legalOrders: { open: number; overdue: number };
  pagesOpen: number;
  generatedAt: string;
}

/** W07: aggregate outcomes of habit commitments (`GET /admin/stats/commitments`). */
export interface CommitmentOutcomes {
  rows: Array<{
    measure: 'recovery_7d' | 'lapse_14d' | 'logs_14d_change' | 'ended_30d';
    cohort: 'committed' | 'control' | 'difference';
    users: number;
    units: number;
    /** `null` when the cell has fewer than 20 people (suppressed). */
    value: number | null;
    suppressed: boolean;
  }>;
  generatedAt: string;
}

/** Crisis lexicon versions (contracts/api/v1.md "Crisis lexicon versions"; src/remote-config). */
export interface LexiconVersionSummary {
  version: number;
  contentSha256: string;
  entries: number;
  note: string | null;
  createdAt: string;
  createdBy: string;
  live: boolean;
}

export interface LexiconOverview {
  kind: string;
  live: { version: number; seq: number; keyId: string; publishedAt: string; publishedBy: string } | null;
  bundledVersion: number;
  signing: { available: boolean; keyId: string | null; devKey: boolean; offReason: string | null };
  versions: LexiconVersionSummary[];
  history: Array<{ id: number; createdAt: string; actor: string; action: string; reasonCode: string | null; detail: Record<string, unknown> }>;
}

export interface LexiconVersion {
  version: number;
  contentSha256: string;
  lexicon: unknown;
  vectors: unknown[];
  note: string | null;
  createdAt: string;
  createdBy: string;
}

export interface LexiconDiff {
  from: number | null;
  added: string[];
  removed: string[];
  changed: string[];
  crisisFormsRemoved: number;
  crisisFormsAdded: number;
}

export type LexiconVerdict = 'none' | 'soft' | 'crisis';

/** Crisis helpline directory versions (contracts/api/v1.md "Helpline directory versions"; src/remote-config). */
export interface HelplinesOverview {
  kind: string;
  live: { version: number; seq: number; keyId: string; publishedAt: string; publishedBy: string } | null;
  bundledVersion: number;
  /** Regions every version must keep (the ones app builds bundle). */
  requiredCountries: string[];
  signing: { available: boolean; keyId: string | null; devKey: boolean; offReason: string | null };
  /** `entries` = lines, summed over regions. */
  versions: LexiconVersionSummary[];
  history: Array<{ id: number; createdAt: string; actor: string; action: string; reasonCode: string | null; detail: Record<string, unknown> }>;
}

export interface HelplineLine {
  id: string;
  number: string;
  dial: string;
  audience: 'everyone' | 'minors';
  names: Record<string, string>;
}

export interface HelplinesVersion {
  version: number;
  contentSha256: string;
  helplines: { name: string; version: number; verifiedOn?: string; countries: Record<string, HelplineLine[]>; [key: string]: unknown };
  /** What the app lists per region (adult / minor), plus an unlisted region (nothing: the generic card). */
  vectors: Array<{ country: string; minor: boolean; dials: string[] }>;
  note: string | null;
  createdAt: string;
  createdBy: string;
}

export interface HelplinesDiff {
  from: number | null;
  added: string[];
  removed: string[];
  changed: string[];
  countriesRemoved: string[];
  numbersRemoved: number;
}

/** Device bans (contracts/api/v1.md "Device bans"; src/devices). A device id is the install HMAC, never a raw id. */
export interface ReportDevices {
  reportId: string;
  subjectHash: string;
  devices: Array<{ deviceId: string; platform: string | null; firstSeenAt: string; lastSeenAt: string; banId: string | null }>;
}

export interface DeviceBan {
  banId: string;
  deviceId: string;
  reasonCode: string;
  reportId: string | null;
  subjectHash: string | null;
  createdAt: string;
  createdBy: string;
  liftedAt: string | null;
  liftedBy: string | null;
  liftReason: string | null;
}
