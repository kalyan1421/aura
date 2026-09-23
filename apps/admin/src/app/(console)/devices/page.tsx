import type { Metadata } from 'next';
import Link from 'next/link';
import { ActionForm } from '@/components/client';
import { Empty, Forbidden, Hash, PageHead, When } from '@/components/ui';
import { shortHash } from '@/lib/format';
import { isForbidden, load } from '@/lib/load';
import type { DeviceBan } from '@/lib/types';
import { liftDeviceBan } from './actions';

export const metadata: Metadata = { title: 'Device bans' };

const STATUSES = ['active', 'lifted', 'all'] as const;

/**
 * Device bans (Owner only; PRD 19 roles, REQ-ADM-14). A device is an install id's HMAC — never the raw id, never a
 * hardware id. A banned phone gets “This device can’t use Aura” (no reason) but can still delete its account and ask
 * for a review. Bans are placed from a report (the account ban does it in the same action); lifting one is here.
 */
export default async function DevicesPage({ searchParams }: { searchParams: Promise<Record<string, string | string[] | undefined>> }) {
  const sp = await searchParams;
  const status = STATUSES.find((s) => s === sp.status) ?? 'active';
  const data = await load<{ bans: DeviceBan[] }>(`/admin/devices/bans?status=${status}`);
  if (isForbidden(data)) return <Forbidden what="Device bans" />;
  return (
    <>
      <PageHead title="Device bans">
        <nav className="row small" aria-label="Filter">
          {STATUSES.map((s) => (
            <Link key={s} href={`/devices?status=${s}`} prefetch={false} aria-current={s === status ? 'page' : undefined}>
              {s}
            </Link>
          ))}
        </nav>
      </PageHead>
      <p className="muted small">
        Bans outlive the account (a new account on a banned phone is refused). A modified app can leave the install id out and an Android reinstall
        gets a new one; attestation (DeviceCheck / Play Integrity) is the later hardening.
      </p>
      <div className="table-wrap">
        {data.bans.length === 0 ? (
          <Empty>No {status === 'all' ? '' : `${status} `}device bans.</Empty>
        ) : (
          <table>
            <thead>
              <tr>
                <th scope="col">Device</th>
                <th scope="col">Account</th>
                <th scope="col">Banned</th>
                <th scope="col">Reason</th>
                <th scope="col">State</th>
              </tr>
            </thead>
            <tbody>
              {data.bans.map((b) => (
                <tr key={b.banId}>
                  <td>
                    <code title={b.deviceId}>{shortHash(b.deviceId)}</code>
                  </td>
                  <td>
                    <Hash value={b.subjectHash} />
                    {b.reportId ? (
                      <div className="small">
                        <Link href={`/reports/${b.reportId}`} prefetch={false}>
                          report
                        </Link>
                      </div>
                    ) : null}
                  </td>
                  <td className="small">
                    <When iso={b.createdAt} />
                    <div className="muted">{b.createdBy}</div>
                  </td>
                  <td>
                    <code>{b.reasonCode}</code>
                  </td>
                  <td>
                    {b.liftedAt ? (
                      <span className="small">
                        lifted <When iso={b.liftedAt} /> · {b.liftedBy}
                        {b.liftReason ? (
                          <>
                            {' '}
                            · <code>{b.liftReason}</code>
                          </>
                        ) : null}
                      </span>
                    ) : (
                      <ActionForm action={liftDeviceBan.bind(null, b.banId)} submitLabel="Lift" confirm="Lift this device ban?" className="stack small">
                        <label htmlFor={`lift-${b.banId}`} className="hint">
                          Reason code
                        </label>
                        <input id={`lift-${b.banId}`} name="reasonCode" type="text" required pattern="[a-z0-9_]{1,40}" placeholder="e.g. appeal_upheld" />
                      </ActionForm>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </>
  );
}
