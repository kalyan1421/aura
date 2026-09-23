import { When } from '@/components/ui';
import type { Delivery } from '@/lib/types';

const CHANNEL: Record<string, string> = {
  webhook: 'Push webhook',
  email: 'Email',
  escalation_webhook: 'Escalation (call)',
  none: 'No channel configured',
};

/** The paging log for one page: every attempt on every channel (codes only, never response bodies). */
export function DeliveryLog({ deliveries }: { deliveries: Delivery[] }) {
  if (deliveries.length === 0) return <p className="empty">No delivery attempts yet.</p>;
  return (
    <div className="table-wrap">
      <table>
        <thead>
          <tr>
            <th scope="col">When</th>
            <th scope="col">Channel</th>
            <th scope="col">Round</th>
            <th scope="col">Attempt</th>
            <th scope="col">Result</th>
          </tr>
        </thead>
        <tbody>
          {deliveries.map((d, i) => (
            <tr key={i}>
              <td className="small nowrap">
                <When iso={d.at} />
              </td>
              <td>
                {CHANNEL[d.channel] ?? d.channel}
                {d.level > 0 ? <span className="hint"> · escalated</span> : null}
              </td>
              <td>{d.round}</td>
              <td>{d.attempt}</td>
              <td>
                <span className={d.ok ? 'yes' : 'sla-overdue'}>{d.ok ? 'delivered' : 'failed'}</span>
                {d.httpStatus ? <span className="small muted"> · HTTP {d.httpStatus}</span> : null}
                {d.error ? (
                  <span className="small muted">
                    {' · '}
                    <code>{d.error}</code>
                  </span>
                ) : null}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
