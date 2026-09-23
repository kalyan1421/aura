import type { Metadata } from 'next';
import { ActionForm } from '@/components/client';
import { PageHead } from '@/components/ui';
import { createOrder } from '../actions';

export const metadata: Metadata = { title: 'Record a legal order' };

export default function NewLegalOrderPage() {
  return (
    <>
      <PageHead title="Record a legal order" />
      <p className="callout">
        The 3-hour clock runs from when the order was <strong>received</strong>, not from now. Recording it pages you (24×7) until you acknowledge.
        Decide disclosure questions with counsel.
      </p>
      <section className="panel">
        <ActionForm action={createOrder} submitLabel="Record and page">
          <div className="grid">
            <div>
              <label htmlFor="source">Issued by</label>
              <select id="source" name="source" defaultValue="government">
                <option value="court">Court</option>
                <option value="government">Government</option>
                <option value="law_enforcement">Law enforcement</option>
                <option value="other">Other</option>
              </select>
            </div>
            <div>
              <label htmlFor="authority">Authority</label>
              <input id="authority" name="authority" type="text" required minLength={2} maxLength={200} />
            </div>
            <div>
              <label htmlFor="reference">
                Order reference <span className="hint">(optional)</span>
              </label>
              <input id="reference" name="reference" type="text" maxLength={200} />
            </div>
            <div>
              <label htmlFor="receivedAt">
                Received at <span className="hint">(IST; empty = now)</span>
              </label>
              <input id="receivedAt" name="receivedAt" type="datetime-local" />
            </div>
          </div>
          <div>
            <label htmlFor="summary">What the order requires</label>
            <textarea id="summary" name="summary" required minLength={3} maxLength={5000} />
          </div>
          <div>
            <label htmlFor="targets">
              Content or accounts named <span className="hint">(optional)</span>
            </label>
            <textarea id="targets" name="targets" maxLength={5000} />
          </div>
          <label className="choice">
            <input type="checkbox" name="isTest" value="yes" /> This is a drill (TEST)
          </label>
        </ActionForm>
      </section>
    </>
  );
}
