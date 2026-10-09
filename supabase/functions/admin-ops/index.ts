import {headers,json} from '../_shared/http.ts';import {authenticate} from '../_shared/auth.ts';
Deno.serve(async request=>{
 if(request.method==='OPTIONS')return new Response(null,{headers:headers(request)});
 if(request.method!=='POST')return json(request,405,{error:'Method not allowed'});
 try{
  const {db,user}=await authenticate(request);const body=await request.json();
  const {data:staff,error}=await db.from('staff_accounts').select('role_key,enabled').eq('user_id',user.id).maybeSingle();if(error||!staff?.enabled)return json(request,403,{error:'Permission denied'});
  const {data:perms}=await db.from('role_permissions').select('permission').eq('role_key',staff.role_key);const caps=(perms??[]).map(p=>p.permission);const can=(cap:string)=>caps.includes('*')||caps.includes(cap);
  if(body.action==='create_staff'){
   if(!can('staff.write'))return json(request,403,{error:'Permission denied'});
   if(typeof body.email!=='string'||typeof body.password!=='string'||body.password.length<8)return json(request,400,{error:'Invalid account details'});
   const {data:role}=await db.from('roles').select('key').eq('key',body.role_key).maybeSingle();if(!role)return json(request,400,{error:'Invalid role'});
   const {data:created,error:createError}=await db.auth.admin.createUser({email:body.email,password:body.password,email_confirm:true});if(createError||!created.user)throw createError;
   const {error:roleError}=await db.from('staff_accounts').insert({user_id:created.user.id,role_key:body.role_key});if(roleError){await db.auth.admin.deleteUser(created.user.id);throw roleError;}
   return json(request,200,{user_id:created.user.id});
  }
  if(body.action==='copy_theme'){
   if(!can('themes.write'))return json(request,403,{error:'Permission denied'});
   const {data:source,error}=await db.from('themes').select('*,theme_assets(*),theme_media(*),theme_widget_settings(*),theme_playlists(*)').eq('id',body.id).single();if(error||!source)throw error;
   const id=crypto.randomUUID();const {theme_assets:assets,theme_media:media,theme_widget_settings:widgets,theme_playlists:links,created_at,updated_at,...metadata}=source;
   const inserted=await db.from('themes').insert({...metadata,id,status:'draft',version:1,forced:false,name_ar:source.name_ar+' — نسخة',name_en:source.name_en+' — Copy',thumbnail_path:null,fallback_path:null});if(inserted.error)throw inserted.error;
   const copied=new Map<string,string>();
   const copy=async(path:string|null)=>{if(!path)return null;if(copied.has(path))return copied.get(path)!;const target=`themes/${id}/${crypto.randomUUID()}.${path.split('.').pop()}`;const result=await db.storage.from('theme-media').copy(path,target);if(result.error)throw result.error;copied.set(path,target);return target;};
   try{
    for(const asset of assets??[]){const result=await db.from('theme_assets').insert({theme_id:id,layout:asset.layout,period:asset.period,kind:asset.kind,path:await copy(asset.path)});if(result.error)throw result.error;}
    for(const item of media??[]){const {id:oldID,theme_id:oldTheme,...fields}=item;const result=await db.from('theme_media').insert({...fields,id:crypto.randomUUID(),theme_id:id,path:await copy(item.path)});if(result.error)throw result.error;}
    for(const item of widgets??[]){const result=await db.from('theme_widget_settings').insert({...item,theme_id:id});if(result.error)throw result.error;}
    for(const item of links??[]){const result=await db.from('theme_playlists').insert({...item,theme_id:id});if(result.error)throw result.error;}
    const completed=await db.from('themes').update({thumbnail_path:await copy(source.thumbnail_path),fallback_path:await copy(source.fallback_path)}).eq('id',id);if(completed.error)throw completed.error;
   }catch(error){await db.from('themes').delete().eq('id',id);if(copied.size)await db.storage.from('theme-media').remove([...copied.values()]);throw error;}
   await db.from('audit_logs').insert({actor_id:user.id,operation:'COPY',table_name:'themes',subject_id:id,metadata:{source_id:source.id}});
   return json(request,200,{id});
  }
  if(body.action==='user_status'){
   if(!can('users.write')||!['active','suspended'].includes(body.status))return json(request,403,{error:'Permission denied'});
   if(body.user_id===user.id)return json(request,409,{error:'You cannot suspend your own account'});
   const {error}=await db.from('profiles').update({account_status:body.status}).eq('user_id',body.user_id);if(error)throw error;
   return json(request,200,{done:true});
  }
  if(body.action==='delete_theme'||body.action==='delete_music'){
   const isTheme=body.action==='delete_theme';if(!can(isTheme?'themes.write':'music.write'))return json(request,403,{error:'Permission denied'});
   if(isTheme&&body.id==='spirit-of-the-uae')return json(request,409,{error:'The bundled fallback theme cannot be deleted'});
   let paths:string[]=[];
   if(isTheme){const results=await Promise.all([db.from('theme_assets').select('path').eq('theme_id',body.id),db.from('theme_media').select('path').eq('theme_id',body.id),db.from('themes').select('thumbnail_path,fallback_path').eq('id',body.id).maybeSingle()]);if(results.some(r=>r.error))throw Error('Read failed');paths=[...(results[0].data??[]).map(x=>x.path),...(results[1].data??[]).map(x=>x.path),results[2].data?.thumbnail_path,results[2].data?.fallback_path].filter(Boolean) as string[];}
   else{const {data,error}=await db.from('music').select('path').eq('id',body.id).single();if(error)throw error;paths=[data.path];}
   const {error}=await db.from(isTheme?'themes':'music').delete().eq('id',body.id);if(error)throw error;
   // Database first; failed object cleanup leaves an orphan, never a broken live record.
   const clean=paths.length?await db.storage.from('theme-media').remove([...new Set(paths)]):{error:null};
   await db.from('audit_logs').insert({actor_id:user.id,operation:'DELETE',table_name:isTheme?'themes':'music',subject_id:body.id});
   return json(request,200,{done:true,cleanup_pending:!!clean.error});
  }
  return json(request,400,{error:'Unknown action'});
 }catch{return json(request,400,{error:'Action could not be completed'});}
});
