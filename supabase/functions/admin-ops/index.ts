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
