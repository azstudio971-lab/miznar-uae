import { createClient } from 'npm:@supabase/supabase-js@2.117.3';
export function headers(request: Request): HeadersInit {
  const origin = request.headers.get('Origin');
  const allowed = (Deno.env.get('ALLOWED_ORIGINS') ?? '').split(',').filter(Boolean);
  return { 'Content-Type': 'application/json', 'Cache-Control': 'no-store', 'Vary': 'Origin',
    ...(origin && allowed.includes(origin) ? { 'Access-Control-Allow-Origin': origin } : {}),
    'Access-Control-Allow-Headers': 'authorization, apikey, content-type, x-client-info',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS' };
}
export function json(request: Request, status: number, body: unknown) { return new Response(JSON.stringify(body), { status, headers: headers(request) }); }
export function service() { return createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, { auth: { persistSession: false, autoRefreshToken: false } }); }
