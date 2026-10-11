// POST /api/tags  {player: uuid, tags: {voteId: 'K' | 'M'}}  — one mark per player per bill; a later mark replaces the earlier one
import { json, sb, UUID } from './_supabase.js';

export async function onRequestPost({ request, env }) {
  let body;
  try { body = await request.json() } catch { return json({ error: 'bad json' }, 400) }
  const { player, tags } = body || {};
  if (!UUID.test(player || '') || !tags || typeof tags !== 'object') return json({ error: 'bad request' }, 400);
  const rows = Object.entries(tags)
    .filter(([id, t]) => /^\d{1,9}$/.test(id) && (t === 'K' || t === 'M'))
    .slice(0, 700)
    .map(([id, t]) => ({ player_id: player, vote_id: +id, tag: t, updated_at: new Date().toISOString() }));
  if (!rows.length) return json({ saved: 0 });
  try {
    await sb(env, 'player_tag?on_conflict=player_id,vote_id', {
      method: 'POST', headers: { Prefer: 'resolution=merge-duplicates,return=minimal' }, body: JSON.stringify(rows),
    });
  } catch (e) { return json({ error: 'save failed' }, 502) }
  return json({ saved: rows.length });
}
