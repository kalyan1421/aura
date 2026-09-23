'use client';

import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';
import { useActionState, useEffect, useState, type ReactNode } from 'react';
import { slaText } from '@/lib/format';

/**
 * The console's only client-side code: live SLA timers, a calm auto-refresh, j/k list navigation and forms that
 * report their result. No third-party scripts, no analytics.
 */
export type { ActionResult } from '@/lib/actions';
import type { ActionResult } from '@/lib/actions';
export type FormAction = (prev: ActionResult, formData: FormData) => Promise<ActionResult>;

/** A deadline that counts down in place (updates every 15 s; the text, not only the colour, says the state). */
export function SlaTimer({ dueAt, closed = false }: { dueAt: string; closed?: boolean }) {
  const [now, setNow] = useState(() => Date.now());
  useEffect(() => {
    if (closed) return;
    const t = setInterval(() => setNow(Date.now()), 15_000);
    return () => clearInterval(t);
  }, [closed]);
  const { text, state } = slaText(dueAt, now, closed);
  return (
    <time dateTime={dueAt} className={`sla sla-${state}`} suppressHydrationWarning>
      {text}
    </time>
  );
}

/** Refreshes the page's server data every `seconds` while the tab is visible. */
export function AutoRefresh({ seconds = 60 }: { seconds?: number }) {
  const router = useRouter();
  useEffect(() => {
    const t = setInterval(() => {
      if (document.visibilityState === 'visible') router.refresh();
    }, seconds * 1000);
    return () => clearInterval(t);
  }, [router, seconds]);
  return null;
}

/** j / k move between rows of the list (links marked data-row); Enter opens. Ignored while typing. */
export function ListKeys() {
  useEffect(() => {
    const onKey = (e: KeyboardEvent): void => {
      const t = e.target as HTMLElement | null;
      if (e.metaKey || e.ctrlKey || e.altKey || (t && /^(INPUT|TEXTAREA|SELECT)$/.test(t.tagName)) || t?.isContentEditable) return;
      if (e.key !== 'j' && e.key !== 'k') return;
      const rows = Array.from(document.querySelectorAll<HTMLAnchorElement>('a[data-row]'));
      if (rows.length === 0) return;
      const i = rows.indexOf(document.activeElement as HTMLAnchorElement);
      const next = e.key === 'j' ? Math.min(rows.length - 1, i + 1) : Math.max(0, i < 0 ? 0 : i - 1);
      rows[next].focus();
      e.preventDefault();
    };
    document.addEventListener('keydown', onKey);
    return () => document.removeEventListener('keydown', onKey);
  }, []);
  return null;
}

/**
 * A form bound to a server action. Shows the result in a polite live region; `confirm` asks before submitting
 * (irreversible or sensitive steps).
 */
export function ActionForm({
  action,
  children,
  submitLabel,
  confirm,
  danger = false,
  className,
}: {
  action: FormAction;
  children?: ReactNode;
  submitLabel: string;
  confirm?: string;
  danger?: boolean;
  className?: string;
}) {
  const [state, formAction, pending] = useActionState(action, null);
  return (
    <form
      action={formAction}
      className={className ?? 'stack'}
      onSubmit={(e) => {
        if (confirm && !window.confirm(confirm)) e.preventDefault();
      }}
    >
      {children}
      <div className="row">
        <button type="submit" className={danger ? 'btn btn-danger' : 'btn'} disabled={pending} aria-busy={pending}>
          {pending ? 'Working…' : submitLabel}
        </button>
        <p role="status" aria-live="polite" className={state ? (state.ok ? 'msg msg-ok' : 'msg msg-err') : 'msg'}>
          {state?.message ?? ''}
        </p>
      </div>
    </form>
  );
}

/** Console navigation with the current section marked (aria-current). */
export function NavLinks({ items }: { items: Array<{ href: string; label: string }> }) {
  const path = usePathname();
  return (
    <nav className="nav" aria-label="Console sections">
      {items.map((i) => {
        const current = path === i.href || path.startsWith(`${i.href}/`);
        return (
          <Link key={i.href} href={i.href} prefetch={false} aria-current={current ? 'page' : undefined}>
            {i.label}
          </Link>
        );
      })}
    </nav>
  );
}
