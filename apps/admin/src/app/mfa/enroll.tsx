'use client';

import { useActionState } from 'react';
import { ActionForm, type FormAction } from '@/components/client';
import type { EnrollState } from './actions';

/** Authenticator set-up: QR code (and the secret for manual entry), then the first code. */
export function Enroll({ start, confirm }: { start: (prev: EnrollState, fd: FormData) => Promise<EnrollState>; confirm: FormAction }) {
  const [state, startAction, pending] = useActionState(start, null);
  if (!state?.ok || !state.qr) {
    return (
      <form action={startAction} className="stack">
        <p>This account has no authenticator yet. Use an app such as 1Password, Google Authenticator or Authy.</p>
        <div className="row">
          <button type="submit" className="btn" disabled={pending}>
            {pending ? 'Working…' : 'Set up an authenticator'}
          </button>
          <p role="status" aria-live="polite" className={state && !state.ok ? 'msg msg-err' : 'msg'}>
            {state && !state.ok ? state.message : ''}
          </p>
        </div>
      </form>
    );
  }
  return (
    <div className="stack">
      <p role="status">{state.message}</p>
      <div className="qr">
        {/* GoTrue returns the QR code as an SVG data URI; nothing is fetched from elsewhere. */}
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img src={state.qr} alt="QR code for your authenticator app" />
      </div>
      <p className="small">
        Can’t scan? Enter this key: <code>{state.secret}</code>
      </p>
      <ActionForm action={confirm} submitLabel="Verify and continue">
        <div>
          <label htmlFor="code">6-digit code</label>
          <input id="code" name="code" className="code" inputMode="numeric" autoComplete="one-time-code" pattern="[0-9 ]{6,7}" required autoFocus />
        </div>
      </ActionForm>
    </div>
  );
}
