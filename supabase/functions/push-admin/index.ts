import {headers,json} from '../_shared/http.ts';
import {authenticate} from '../_shared/auth.ts';
import {importPKCS8,SignJWT} from 'npm:jose@6.1.0';
const configured=()=>['APNS_PRIVATE_KEY','APNS_KEY_ID','APNS_TEAM_ID','APNS_BUNDLE_ID'].every(k=>!!Deno.env.get(k));
async function deliver(db:any,campaign:any){
 let sent=0,failed=0,total=0;
 try{
 const key=await importPKCS8(Deno.env.get('APNS_PRIVATE_KEY')!.replaceAll('\\n','\n'),'ES256');
 const token=await new SignJWT({}).setProtectedHeader({alg:'ES256',kid:Deno.env.get('APNS_KEY_ID')!}).setIssuer(Deno.env.get('APNS_TEAM_ID')!).setIssuedAt().sign(key);
 await db.from('push_campaigns').update({status:'sending'}).eq('id',campaign.id);
 let after='00000000-0000-0000-0000-000000000000';
 while(true){let q=db.from('push_devices').select('installation_id,device_token,environment').eq('enabled',true).gt('installation_id',after).order('installation_id').limit(200);if(campaign.audience!=='all')q=q.eq(campaign.audience,campaign.target);const r=await q;if(r.error)throw r.error;const devices=r.data||[];if(!devices.length)break;total+=devices.length;
 for(let i=0;i<devices.length;i+=10){await Promise.all(devices.slice(i,i+10).map(async(device:any)=>{
 let status='failed',reason='';try{const host=device.environment==='production'?'api.push.apple.com':'api.sandbox.push.apple.com';const response=await fetch(`https://${host}/3/device/${device.device_token}`,{method:'POST',headers:{authorization:`bearer ${token}`,'apns-topic':Deno.env.get('APNS_BUNDLE_ID')!,'apns-push-type':'alert','apns-priority':'10','apns-expiration':String(Math.floor(Date.now()/1000)+3600),'apns-collapse-id':campaign.id},body:JSON.stringify({aps:{alert:{title:campaign.title,body:campaign.body},sound:'default'},campaign_id:campaign.id}),signal:AbortSignal.timeout(15000)});if(response.ok){status='sent';sent++;}else{const error=await response.json().catch(()=>({}));reason=error.reason||`APNs ${response.status}`;failed++;if(response.status===410||reason==='BadDeviceToken')await db.from('push_devices').update({enabled:false}).eq('installation_id',device.installation_id);}}catch(e){reason=e instanceof Error?e.message:'Provider connection failed';failed++;}
 const saved=await db.from('push_deliveries').insert({campaign_id:campaign.id,installation_id:device.installation_id,status,reason});if(saved.error)throw saved.error;
 }));await db.from('push_campaigns').update({sent_count:sent,failed_count:failed,target_count:total}).eq('id',campaign.id);}
 after=devices[devices.length-1].installation_id;if(devices.length<200)break;
 }
 await db.from('push_campaigns').update({status:failed?(sent?'partial':'failed'):'sent',sent_count:sent,failed_count:failed,target_count:total,sent_at:new Date().toISOString(),last_error:total===0?'No opted-in devices matched this audience.':failed?'Some APNs deliveries failed; inspect push_deliveries.':null}).eq('id',campaign.id);
 }catch(e){await db.from('push_campaigns').update({status:sent?'partial':'failed',sent_count:sent,failed_count:failed,target_count:total,last_error:e instanceof Error?e.message:'Delivery failed'}).eq('id',campaign.id);}
}
Deno.serve(async request=>{
 if(request.method==='OPTIONS')return new Response(null,{headers:headers(request)});if(request.method!=='POST')return json(request,405,{error:'Method not allowed'});
 try{const {db,user}=await authenticate(request);const staff=await db.from('staff_accounts').select('role_key,enabled').eq('user_id',user.id).maybeSingle();if(!staff.data?.enabled)return json(request,403,{error:'Permission denied'});const perms=await db.from('role_permissions').select('permission').eq('role_key',staff.data.role_key);const caps=(perms.data||[]).map(p=>p.permission);if(!caps.includes('*')&&!caps.includes('messages.write'))return json(request,403,{error:'Permission denied'});
 const body=await request.json();if(body.action==='status')return json(request,200,{configured:configured()});
 if(!['draft','send'].includes(body.action)||typeof body.title!=='string'||!body.title.trim()||body.title.length>100||typeof body.body!=='string'||!body.body.trim()||body.body.length>1000||!['all','city','region'].includes(body.audience)||(body.audience!=='all'&&(!body.target||body.target.length>100)))return json(request,400,{error:'Invalid notification'});
 const status=body.action==='draft'?'draft':configured()?'queued':'blocked';const r=await db.from('push_campaigns').insert({title:body.title.trim(),body:body.body.trim(),audience:body.audience,target:body.audience==='all'?'':body.target.trim(),status,created_by:user.id,last_error:status==='blocked'?'APNs credentials are not configured. No notification was sent.':null}).select('*').single();if(r.error)throw r.error;
 if(status==='queued')EdgeRuntime.waitUntil(deliver(db,r.data));return json(request,200,{id:r.data.id,status});
 }catch(e){return json(request,400,{error:e instanceof Error?e.message:'Request failed'});}
});
