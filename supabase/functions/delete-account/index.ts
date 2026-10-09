import { headers, json, service } from '../_shared/http.ts';
Deno.serve(async request => {
  if (request.method === 'OPTIONS') return new Response(null, { headers: headers(request) });
  if (request.method !== 'POST') return json(request, 405, { error: 'Method not allowed' });
  const token = request.headers.get('Authorization')?.match(/^Bearer (.+)$/i)?.[1];
  if (!token) return json(request, 401, { error: 'Authentication required' });
  let payload; try { payload = await request.json(); } catch { return json(request, 400, { error: 'Invalid JSON' }); }
  if (payload.confirmation !== 'DELETE') return json(request, 400, { error: 'Explicit confirmation required' });
  try {
    const db = service();
    // Fetch the user from Auth, not a client-supplied id or an unverified JWT claim.
    const { data: { user }, error } = await db.auth.getUser(token);
    if (error || !user) return json(request, 401, { error: 'Session is invalid' });
    const signedOut = await db.auth.admin.signOut(token, 'global');
    if (signedOut.error) throw signedOut.error;
    const result = await db.auth.admin.deleteUser(user.id, false);
    if (result.error) throw result.error;
    return json(request, 200, { deleted: true });
  } catch { return json(request, 503, { error: 'Deletion could not be completed. Please retry.' }); }
});
