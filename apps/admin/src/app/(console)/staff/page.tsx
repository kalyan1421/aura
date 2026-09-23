import type { Metadata } from 'next';
import { ActionForm } from '@/components/client';
import { Badge, Empty, Forbidden, PageHead, When, YesNo } from '@/components/ui';
import { ROLE_LABEL } from '@/lib/format';
import { isForbidden, load } from '@/lib/load';
import type { StaffList } from '@/lib/types';
import { addStaff, changeRole, setDisabled } from './actions';

export const metadata: Metadata = { title: 'Staff' };

/**
 * The staff editor (PRD 19 Roles: staff roles are Owner business). Staff sign in with Google Workspace + TOTP
 * (REQ-ADM-01), so a new person signs in once (the console says they are not on the list), then the Owner adds them
 * here. Access is removed by disabling, never by deleting; every change is in the audit log with the Owner as actor.
 */
export default async function StaffPage() {
  const data = await load<StaffList>('/admin/staff');
  if (isForbidden(data)) return <Forbidden what="The staff editor" />;
  return (
    <>
      <PageHead title="Staff" />
      <p className="muted small">
        {data.sso.configured
          ? `Sign-in: Google Workspace (${data.sso.domains.join(', ')}) + TOTP. `
          : 'Sign-in: development email code + TOTP (Google Workspace SSO is not configured on the API). '}
        Staff accounts are never Aura app accounts. An Owner cannot demote or disable themselves; the console always keeps an
        enabled Owner.
      </p>
      <div className="table-wrap">
        {data.staff.length === 0 ? (
          <Empty>No staff yet.</Empty>
        ) : (
          <table>
            <thead>
              <tr>
                <th scope="col">Name</th>
                <th scope="col">Email</th>
                <th scope="col">Role</th>
                <th scope="col">Sign-in</th>
                <th scope="col">Last sign-in</th>
                <th scope="col">Access</th>
              </tr>
            </thead>
            <tbody>
              {data.staff.map((s) => (
                <tr key={s.staffId}>
                  <td>
                    {s.displayName} {s.isMe ? <Badge>you</Badge> : null}
                  </td>
                  <td className="small">{s.email ?? '—'}</td>
                  <td>
                    {s.isMe ? (
                      ROLE_LABEL[s.role]
                    ) : (
                      <ActionForm action={changeRole.bind(null, s.staffId)} submitLabel="Change" className="row small" confirm={`Change ${s.displayName}'s role?`}>
                        <label htmlFor={`role-${s.staffId}`} className="sr-only">
                          Role
                        </label>
                        <select id={`role-${s.staffId}`} name="role" defaultValue={s.role}>
                          <option value="owner">Owner</option>
                          <option value="moderator">Moderator</option>
                          <option value="analyst">Read-only analyst</option>
                        </select>
                      </ActionForm>
                    )}
                  </td>
                  <td className="small">
                    TOTP <YesNo value={s.totpEnrolled} yes="enrolled" no="not yet" />
                    <div>
                      {data.sso.configured ? (
                        s.sso.allowed ? (
                          <span className="yes">Google Workspace ({s.sso.domains.join(', ')})</span>
                        ) : (
                          <span className="sla-overdue">
                            cannot pass SSO
                            {s.otherProviders.length ? ` (also ${s.otherProviders.join(', ')})` : s.sso.domains.length ? ' (other domain)' : ' (no Workspace sign-in yet)'}
                          </span>
                        )
                      ) : (
                        <span className="muted">development sign-in</span>
                      )}
                    </div>
                  </td>
                  <td className="small nowrap">
                    <When iso={s.lastSignInAt} />
                  </td>
                  <td>
                    {s.disabled ? <Badge tone="alert">disabled</Badge> : <Badge>active</Badge>}
                    {s.isMe ? null : (
                      <ActionForm
                        action={setDisabled.bind(null, s.staffId, !s.disabled)}
                        submitLabel={s.disabled ? 'Restore access' : 'Disable'}
                        danger={!s.disabled}
                        confirm={s.disabled ? `Restore ${s.displayName}'s access?` : `Remove ${s.displayName}'s access now?`}
                        className="stack small"
                      />
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
      <section className="panel spaced" aria-labelledby="h-add">
        <h2 id="h-add">Add a staff member</h2>
        <p className="small muted">
          They sign in once first (with Google Workspace), so their account exists. App accounts are refused. They set up TOTP at their next sign-in.
        </p>
        <ActionForm action={addStaff} submitLabel="Add">
          <div className="grid">
            <div>
              <label htmlFor="email">Email</label>
              <input id="email" name="email" type="email" required />
            </div>
            <div>
              <label htmlFor="displayName">Display name</label>
              <input id="displayName" name="displayName" type="text" required maxLength={60} />
            </div>
            <div>
              <label htmlFor="role">Role</label>
              <select id="role" name="role" defaultValue="moderator">
                <option value="moderator">Moderator</option>
                <option value="analyst">Read-only analyst</option>
                <option value="owner">Owner</option>
              </select>
            </div>
          </div>
        </ActionForm>
      </section>
    </>
  );
}
