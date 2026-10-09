import { headers, json, service } from '../_shared/http.ts';
Deno.serve(async request => {
  if (request.method === 'OPTIONS') return new Response(null, { headers: headers(request) });
  if (request.method !== 'GET') return json(request, 405, { error: 'Method not allowed' });
  try {
    const db = service(); const now = Date.now();
    const { data: rows, error } = await db.from('themes').select('*,theme_assets(*)').eq('status', 'published');
    if (error) throw error;
    const active = (rows ?? []).filter(t => (!t.starts_at || Date.parse(t.starts_at) <= now) && (!t.ends_at || Date.parse(t.ends_at) > now));
    const sign = async (path: string) => { const { data, error } = await db.storage.from('theme-media').createSignedUrl(path, 3600); if (error || !data) throw error ?? Error('Asset unavailable'); return data.signedUrl; };
    const themes = await Promise.all(active.map(async t => ({ id: t.id, name_ar: t.name_ar, name_en: t.name_en, version: t.version, timezone: t.timezone, slots: t.slots, widgets: t.widgets, music_mode: t.music_mode, music_ids: t.music_ids, forced: t.forced, starts_at: t.starts_at, ends_at: t.ends_at,
      assets: await Promise.all(t.theme_assets.map(async (a: {layout:string;period:string;kind:string;path:string}) => ({layout:a.layout,period:a.period,kind:a.kind,url:await sign(a.path)}))) })));
    const { data: songs, error: musicError } = await db.from('music').select('*').eq('enabled', true); if (musicError) throw musicError;
    const permitted = (songs ?? []).filter(m => active.some(t => t.music_mode === 'all' || (t.music_mode === 'selected' && t.music_ids.includes(m.id))));
    const music = await Promise.all(permitted.map(async m => ({ id:m.id,name_ar:m.name_ar,name_en:m.name_en,url:await sign(m.path) })));
    const { data: setting, error: settingError } = await db.from('app_settings').select('value').eq('id', 'public').maybeSingle(); if (settingError) throw settingError;
    return json(request, 200, { themes, music, default_theme: setting?.value?.default_theme ?? 'spirit-of-the-uae' });
  } catch { return json(request, 503, { error: 'Catalog temporarily unavailable' }); }
});
