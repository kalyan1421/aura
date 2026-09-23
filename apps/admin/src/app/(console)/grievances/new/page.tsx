import type { Metadata } from 'next';
import { ActionForm } from '@/components/client';
import { PageHead } from '@/components/ui';
import { GRIEVANCE_LABEL } from '@/lib/format';
import { createGrievance } from '../actions';

export const metadata: Metadata = { title: 'Record a grievance' };

/** Emailed or posted grievances become tickets here; the clock runs from when they were received (IST). */
export default function NewGrievancePage() {
  return (
    <>
      <PageHead title="Record an emailed grievance" />
      <section className="panel">
        <ActionForm action={createGrievance} submitLabel="Create ticket">
          <div className="grid">
            <div>
              <label htmlFor="category">Category</label>
              <select id="category" name="category" defaultValue="general">
                {Object.entries(GRIEVANCE_LABEL).map(([k, v]) => (
                  <option key={k} value={k}>
                    {v}
                  </option>
                ))}
              </select>
            </div>
            <div>
              <label htmlFor="channel">Arrived by</label>
              <select id="channel" name="channel" defaultValue="email">
                <option value="email">Email</option>
                <option value="post">Post</option>
                <option value="other">Other</option>
              </select>
            </div>
            <div>
              <label htmlFor="receivedAt">
                Received at <span className="hint">(IST)</span>
              </label>
              <input id="receivedAt" name="receivedAt" type="datetime-local" required />
            </div>
          </div>
          <div className="grid">
            <div>
              <label htmlFor="email">Complainant email</label>
              <input id="email" name="email" type="email" required />
            </div>
            <div>
              <label htmlFor="name">
                Name <span className="hint">(optional)</span>
              </label>
              <input id="name" name="name" type="text" maxLength={120} />
            </div>
          </div>
          <div>
            <label htmlFor="description">Grievance</label>
            <textarea id="description" name="description" required minLength={10} maxLength={5000} />
          </div>
          <div>
            <label htmlFor="contentLocation">
              Where the content is <span className="hint">(optional)</span>
            </label>
            <input id="contentLocation" name="contentLocation" type="text" maxLength={1000} />
          </div>
          <label className="choice">
            <input type="checkbox" name="sendAck" value="yes" defaultChecked /> Email the acknowledgement with the ticket number now
          </label>
        </ActionForm>
      </section>
    </>
  );
}
