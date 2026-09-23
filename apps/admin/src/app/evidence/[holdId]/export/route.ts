import { NextResponse, type NextRequest } from 'next/server';
import { ApiFailure, apiPost } from '@/lib/api';
import { readSession } from '@/lib/session';

/**
 * Break-glass evidence export (Owner): a same-origin form POST → NestJS (which checks the role, audits the export with
 * the bundle's SHA-256 and withholds the reporter) → a JSON download. Never cached.
 */
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const PURPOSES = new Set(['mandatory_report', 'law_enforcement_request', 'court_order', 'counsel_review']);

export async function POST(request: NextRequest, ctx: { params: Promise<{ holdId: string }> }): Promise<Response> {
  // Route handlers don't get the Server Action origin check: only same-origin form posts may export.
  const origin = request.headers.get('origin');
  if (!origin || new URL(origin).host !== request.headers.get('host')) return new NextResponse('Forbidden', { status: 403 });
  const s = await readSession();
  if (!s?.at || s.stage !== 'aal2') return NextResponse.redirect(new URL('/login', request.url), 303);
  const { holdId } = await ctx.params;
  const form = await request.formData();
  const purpose = String(form.get('purpose') ?? '');
  if (!UUID.test(holdId) || !PURPOSES.has(purpose)) return new NextResponse('Bad request', { status: 400 });
  try {
    const bundle = await apiPost<unknown>(`/admin/evidence/${holdId}/export`, { purpose }, s.at);
    return new NextResponse(JSON.stringify(bundle, null, 2), {
      status: 200,
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
        'Content-Disposition': `attachment; filename="aura-evidence-${holdId}.json"`,
        'Cache-Control': 'no-store',
      },
    });
  } catch (e) {
    const status = e instanceof ApiFailure ? e.status : 500;
    const message = e instanceof ApiFailure ? e.message : 'Export failed.';
    return new NextResponse(message, { status, headers: { 'Content-Type': 'text/plain; charset=utf-8', 'Cache-Control': 'no-store' } });
  }
}
