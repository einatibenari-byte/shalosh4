// shared helpers for the API functions; SUPABASE_URL and SUPABASE_SERVICE_KEY are set in the Cloudflare Pages project settings
export const json = (body, status = 200, extra = {}) =>
  new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json; charset=utf-8', ...extra } });

export async function sb(env, path, init = {}) {
  if (!env.SUPABASE_URL || !env.SUPABASE_SERVICE_KEY) throw new Error('missing Supabase settings');
  const r = await fetch(`${env.SUPABASE_URL.replace(/\/$/, '')}/rest/v1/${path}`, {
    ...init,
    headers: {
      apikey: env.SUPABASE_SERVICE_KEY,
      // older "service_role" keys are JWTs and must also go as a bearer token; new sb_secret_ keys go in apikey only
      ...(env.SUPABASE_SERVICE_KEY.startsWith('eyJ') ? { Authorization: `Bearer ${env.SUPABASE_SERVICE_KEY}` } : {}),
      'Content-Type': 'application/json', ...(init.headers || {}),
    },
  });
  if (!r.ok) throw new Error(`supabase ${r.status}: ${await r.text()}`);
  return r;
}

export const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
