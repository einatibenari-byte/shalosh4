// GET /api/tally  → {tally: {voteId: {K, M}}, players}  — how many players marked each bill כסא / מעשה
import { json, sb } from './_supabase.js';

export async function onRequestGet({ env }) {
  try {
    const [t, p] = await Promise.all([
      sb(env, 'v_tag_tally?select=vote_id,k,m').then(r => r.json()),
      sb(env, 'v_tag_players?select=players').then(r => r.json()),
    ]);
    const tally = {};
    for (const r of t) tally[r.vote_id] = { K: +r.k, M: +r.m };
    return json({ tally, players: +(p[0]?.players || 0) }, 200, { 'Cache-Control': 'public, max-age=20' });
  } catch (e) { return json({ tally: {}, players: 0, error: 'unavailable' }, 200) }
}
