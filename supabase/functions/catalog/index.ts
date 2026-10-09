import {headers,json,service} from '../_shared/http.ts';
Deno.serve(async request=>{
 if(request.method==='OPTIONS')return new Response(null,{headers:headers(request)});
 if(request.method!=='GET')return json(request,405,{error:'Method not allowed'});
 try {
  const db=service(),now=Date.now();
  const {data:rows,error}=await db.from('themes').select('*,theme_assets(*),theme_media(*),theme_widget_settings(*),theme_playlists(*)').in('status',['published','scheduled']).order('priority',{ascending:false}).order('sort_order');if(error)throw error;
  const active=(rows??[]).filter(t=>{
   if((t.starts_at&&Date.parse(t.starts_at)>now)||(t.ends_at&&Date.parse(t.ends_at)<=now))return false;
   const day=new Intl.DateTimeFormat('en-US',{timeZone:t.timezone,weekday:'short'}).format(new Date());return (t.weekdays??[0,1,2,3,4,5,6]).includes(['Sun','Mon','Tue','Wed','Thu','Fri','Sat'].indexOf(day));
  });
  const widgets=await db.from('widget_definitions').select('id,enabled');if(widgets.error)throw widgets.error;for(const theme of active){theme.widgets={...theme.widgets};for(const w of widgets.data||[])if(!w.enabled)theme.widgets[w.id]=false;}
  const sign=async(path:string|null)=>{if(!path)return null;if(path.startsWith('https://'))return path;const {data,error}=await db.storage.from('theme-media').createSignedUrl(path,3600);if(error||!data)throw error??Error('Asset unavailable');return data.signedUrl;};
  const themes=await Promise.all(active.map(async t=>({id:t.id,name_ar:t.name_ar,name_en:t.name_en,description_ar:t.description_ar,description_en:t.description_en,version:t.version,timezone:t.timezone,slots:t.slots,widgets:t.widgets,music_mode:t.music_mode,music_ids:t.music_ids,forced:t.forced,priority:t.priority,sort_order:t.sort_order,weekdays:t.weekdays,starts_at:t.starts_at,ends_at:t.ends_at,thumbnail_url:await sign(t.thumbnail_path),fallback_url:await sign(t.fallback_path),widget_settings:t.theme_widget_settings,
   assets:await Promise.all(t.theme_assets.map(async(a:{layout:string;period:string;kind:string;path:string})=>({layout:a.layout,period:a.period,kind:a.kind,url:await sign(a.path)}))),
   media:await Promise.all(t.theme_media.filter((m:{starts_at:string|null;ends_at:string|null})=>(!m.starts_at||Date.parse(m.starts_at)<=now)&&(!m.ends_at||Date.parse(m.ends_at)>now)).map(async(m:{id:string;layout:string;period:string;kind:string;path:string;sort_order:number;duration_seconds:number})=>({id:m.id,layout:m.layout,period:m.period,kind:m.kind,url:await sign(m.path),sort_order:m.sort_order,duration_seconds:m.duration_seconds})))
  })));
  const results=await Promise.all([db.from('music').select('*').eq('enabled',true).order('sort_order'),db.from('playlists').select('*,playlist_tracks(*)').eq('enabled',true).order('sort_order'),db.from('religious_content').select('*').eq('status','published').eq('verified',true).order('sort_order'),db.from('app_settings').select('value').eq('id','public').maybeSingle(),db.from('legal_documents').select('*').eq('published',true)]);for(const result of results)if(result.error)throw result.error;
  const [songs,lists,religious,setting,legal]=results;
 const lib=await db.from('library_items').select('*').eq('enabled',true).order('sort_order');const updates=await db.from('app_updates').select('*').eq('published',true).order('created_at',{ascending:false});if(lib.error||updates.error)throw Error('Catalog unavailable');
  for(const theme of themes){const source=active.find(t=>t.id===theme.id);const ids=new Set((Array.isArray(source?.theme_playlists)?source.theme_playlists:source?.theme_playlists?[source.theme_playlists]:[]).map((p:{playlist_id:string})=>p.playlist_id));theme.music_ids=[...new Set([...theme.music_ids,...(lists.data??[]).filter(p=>ids.has(p.id)).flatMap(p=>p.playlist_tracks.sort((a:{sort_order:number},b:{sort_order:number})=>a.sort_order-b.sort_order).map((a:{track_id:string})=>a.track_id))])];}
  const permitted=(songs.data??[]).filter(m=>active.some(t=>t.music_mode==='all'||(t.music_mode==='selected'&&(t.music_ids.includes(m.id)||themes.find(theme=>theme.id===t.id)?.music_ids.includes(m.id)))));
  const music=await Promise.all(permitted.map(async m=>({id:m.id,name_ar:m.name_ar,name_en:m.name_en,url:await sign(m.path),sort_order:m.sort_order})));
  return json(request,200,{themes,music,library:lib.data,updates:updates.data,playlists:lists.data??[],religious:(religious.data??[]).filter(item=>(!item.starts_at||Date.parse(item.starts_at)<=now)&&(!item.ends_at||Date.parse(item.ends_at)>now)),legal:legal.data??[],settings:setting.data?.value??{},default_theme:setting.data?.value?.default_theme??'spirit-of-the-uae',generated_at:new Date().toISOString()});
 }catch{return json(request,503,{error:'Catalog temporarily unavailable'});}
});
