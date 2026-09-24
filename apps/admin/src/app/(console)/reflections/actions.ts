'use server';

import { refresh } from 'next/cache';
import { unstable_rethrow } from 'next/navigation';
import { attempt, field, type ActionResult } from '@/lib/actions';
import { apiPost, failureMessage } from '@/lib/api';
import {
  POOL_LABEL,
  REASON_CODE,
  decisionBody,
  decisionResultText,
  isPool,
  isUuid,
  type DecisionResult,
  type ReflectionDecision,
} from '@/lib/reflections';

/** One reflection decision via NestJS (role-checked, state-checked and audited there; F6 contract §4). */
export async function decideReflection(
  reflectionId: string,
  ctx: { allowed: ReflectionDecision[]; canStrike: boolean; crisis: boolean },
  _prev: ActionResult,
  fd: FormData,
): Promise<ActionResult> {
  if (!isUuid(reflectionId)) return { ok: false, message: 'Unknown reflection.' };
  const parsed = decisionBody(fd, ctx);
  if (!parsed.ok) return { ok: false, message: parsed.message };
  let out: DecisionResult;
  try {
    out = await apiPost<DecisionResult>(`/admin/reflections/${reflectionId}/decision`, parsed.body);
  } catch (e) {
    unstable_rethrow(e);
    return { ok: false, message: failureMessage(e) };
  }
  refresh();
  return { ok: true, message: decisionResultText(out) };
}

/** The per-pool composer kill switch (Owner; `reflections_composer.payload.pausedPools`). */
export async function setPoolPaused(pool: string, paused: boolean, _prev: ActionResult, fd: FormData): Promise<ActionResult> {
  if (!isPool(pool)) return { ok: false, message: 'Unknown pool.' };
  const reasonCode = field(fd, 'reasonCode');
  if (!REASON_CODE.test(reasonCode)) return { ok: false, message: 'Give a reason code (a–z, 0–9, _).' };
  return attempt(
    () => apiPost(`/admin/reflections/pools/${pool}/${paused ? 'pause' : 'resume'}`, { reasonCode }),
    `${POOL_LABEL[pool]} reflections ${paused ? 'paused' : 'resumed'}.`,
  );
}
