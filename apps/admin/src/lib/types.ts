/** Shapes of the NestJS `/admin/*` responses the console renders (server/aura-api/src/admin). */
export type StaffRole = 'owner' | 'moderator' | 'analyst';
export type Lane = 'crisis' | 'minors_grooming' | 'harassment' | 'spam';

export interface SessionInfo {
  staff: { id: string; displayName: string; role: StaffRole; email: string | null };
  mfa: 'verified' | 'challenge' | 'enroll';
  sessionStartedAt: string;
  sessionExpiresAt: string;
}

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
  flags: Array<{ key: string; enabled: boolean }>;
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
