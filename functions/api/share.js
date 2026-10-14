// POST /api/share  {kind: 'summary'|'vote'|'open'|'factions', how?: 'sheet'|'download', target?}  — counts shares (Supabase table share_event, view v_share_counts)
import { json, sb } from './_supabase.js';

export async function onRequestPost({ request, env }) {
  let body;
  try { body = await request.json() } catch { return json({ error: 'bad json' }, 400) }
  const kind = String(body?.kind || ''), how = body?.how ? String(body.how) : null, target = body?.target ? String(body.target).slice(0, 40) : null;
  if (!['summary', 'vote', 'open', 'factions'].includes(kind) || (how && !['sheet', 'download'].includes(how))) return json({ error: 'bad request' }, 400);
  try {
    await sb(env, 'share_event', { method: 'POST', headers: { Prefer: 'return=minimal' }, body: JSON.stringify({ kind, how, target }) });
  } catch (e) { return json({ error: 'save failed' }, 502) }
  return json({ ok: true });
}
