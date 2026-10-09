import { headers,json } from '../_shared/http.ts';
import { authenticate } from '../_shared/auth.ts';
Deno.serve(async request=>{
 if(request.method==='OPTIONS')return new Response(null,{headers:headers(request)});
 if(request.method!=='POST')return json(request,405,{error:'Method not allowed'});
 try{
  const {db,user,jwt}=await authenticate(request);const body=await request.json();
  if(body.action==='list'){const {data,error}=await db.from('devices').select('*').eq('user_id',user.id).order('last_seen_at',{ascending:false});if(error)throw error;return json(request,200,{devices:data});}
  if(body.action==='signout_others'){const {error}=await db.auth.admin.signOut(jwt,'others');if(error)throw error;await db.from('devices').update({revoked_at:new Date().toISOString()}).eq('user_id',user.id).neq('id',body.id);return json(request,200,{done:true});}
  if(!/^[0-9a-f-]{36}$/i.test(body.id))return json(request,400,{error:'Invalid device'});
  const {data:existing,error:readError}=await db.from('devices').select('*').eq('id',body.id).maybeSingle();if(readError)throw readError;
  if(existing&&existing.user_id!==user.id)return json(request,403,{error:'Permission denied'});
  if(body.action==='revoke'){if(!existing)return json(request,404,{error:'Device unavailable'});const {error}=await db.from('devices').update({revoked_at:new Date().toISOString()}).eq('id',body.id).eq('user_id',user.id);if(error)throw error;return json(request,200,{done:true});}
  if(body.action!=='register')return json(request,400,{error:'Unknown action'});
  if(existing?.revoked_at)return json(request,409,{error:'Device revoked. Sign in again to register a new session.'});
  const record={id:body.id,user_id:user.id,name:String(body.name??'iPhone').slice(0,100),platform:'ios',last_seen_at:new Date().toISOString()};
  const {error}=await db.from('devices').upsert(record);if(error)throw error;
  return json(request,200,{device:record});
 }catch{return json(request,401,{error:'Session or request invalid'});}
});
