// GET /api/stats with header X-Stats-Key → the game's numbers for Lior's private stats page (/stats/)
import { json, sb } from './_supabase.js';

export async function onRequestGet({ request, env }) {
  const key = request.headers.get('X-Stats-Key') || '';
  if (key.length < 20) return json({ error: 'forbidden' }, 403);
  try {
    const ok = await sb(env, `admin_key?select=key&key=eq.${encodeURIComponent(key)}`).then(r => r.json());
    if (!ok.length) return json({ error: 'forbidden' }, 403);
    const s = await sb(env, 'rpc/game_stats', { method: 'POST', body: '{}' }).then(r => r.json());
    return json(s, 200, { 'Cache-Control': 'no-store' });
  } catch (e) { return json({ error: 'unavailable' }, 502) }
}
