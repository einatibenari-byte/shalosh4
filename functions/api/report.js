// POST /api/report  {vote: voteId, text}  — "מצאת טעות?" from a bill card; read by Lior in Supabase (table error_report)
import { json, sb } from './_supabase.js';

export async function onRequestPost({ request, env }) {
  let body;
  try { body = await request.json() } catch { return json({ error: 'bad json' }, 400) }
  const vote = +body?.vote, text = String(body?.text || '').trim().slice(0, 2000);
  if (!Number.isInteger(vote) || vote <= 0 || text.length < 2) return json({ error: 'bad request' }, 400);
  try {
    await sb(env, 'error_report', { method: 'POST', headers: { Prefer: 'return=minimal' }, body: JSON.stringify({ vote_id: vote, text }) });
  } catch (e) { return json({ error: 'save failed' }, 502) }
  return json({ ok: true });
}
