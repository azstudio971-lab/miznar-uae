import {headers,json,service} from '../_shared/http.ts';
Deno.serve(async request=>{
 if(request.method==='OPTIONS')return new Response(null,{headers:headers(request)});
 if(request.method!=='POST')return json(request,405,{error:'Method not allowed'});
 try{
 const body=await request.json();const {installation_id,secret,device_token}=body;
 if(!/^[0-9a-f-]{36}$/i.test(installation_id)||typeof secret!=='string'||secret.length<32||secret.length>128||!['sandbox','production'].includes(body.environment))return json(request,400,{error:'Invalid installation'});
 const db=service(),hash=Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(secret)))).map(x=>x.toString(16).padStart(2,'0')).join('');
 const {data:old,error}=await db.from('push_devices').select('secret_hash').eq('installation_id',installation_id).maybeSingle();if(error)throw error;
 if(old&&old.secret_hash!==hash)return json(request,403,{error:'Installation credentials invalid'});
 if(body.action==='disable'){if(old)await db.from('push_devices').update({enabled:false}).eq('installation_id',installation_id);return json(request,200,{enabled:false});}
 if(typeof device_token!=='string'||!/^[0-9a-f]{32,512}$/i.test(device_token))return json(request,400,{error:'Invalid APNs token'});
 let user_id=null;const jwt=request.headers.get('Authorization')?.replace(/^Bearer /i,'');if(jwt){const r=await db.auth.getUser(jwt);user_id=r.data.user?.id||null;}
 const text=(x:unknown)=>typeof x==='string'?x.trim().slice(0,100):'';
 const r=await db.from('push_devices').upsert({installation_id,secret_hash:hash,device_token,environment:body.environment,user_id,city:text(body.city),region:text(body.region),country:text(body.country),enabled:true,last_seen_at:new Date().toISOString()});if(r.error)throw r.error;
 return json(request,200,{registered:true});
 }catch{return json(request,400,{error:'Device registration failed'});}
});
