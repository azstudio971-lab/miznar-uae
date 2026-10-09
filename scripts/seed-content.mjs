// Trusted deployment step only. Service credentials must never enter a browser bundle.
import {createClient} from '@supabase/supabase-js';
import {readFile} from 'node:fs/promises';
const url=process.env.SUPABASE_URL,key=process.env.SUPABASE_SERVICE_ROLE_KEY;
if(!url||!key)throw Error('Set trusted SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY environment variables.');
const db=createClient(url,key,{auth:{persistSession:false,autoRefreshToken:false}});
const id='spirit-of-the-uae';
const {data:theme,error:themeError}=await db.from('themes').select('id').eq('id',id).single();
if(themeError||!theme)throw Error('Apply migrations before seeding content.');
for(const layout of ['compact','ultrawide'])for(const period of ['dawn','morning','sunset','night']) {
    const path=`themes/${id}/approved-v1/${layout}-${period}.png`;
    const bytes=await readFile(new URL(`../assets/themes/${id}/${layout}/${period}.png`,import.meta.url));
    if(bytes.subarray(0,8).toString('hex')!=='89504e470d0a1a0a')throw Error('Approved PNG is invalid.');
    const upload=await db.storage.from('theme-media').upload(path,bytes,{contentType:'image/png',upsert:false});
    if(upload.error&&!String(upload.error.message).toLowerCase().includes('already exists'))throw upload.error;
    const saved=await db.from('theme_assets').upsert({theme_id:id,layout,period,kind:'image',path},{onConflict:'theme_id,layout,period'});
    if(saved.error)throw saved.error;
}
const policies=JSON.parse(await readFile(new URL('../ios/WudCar/Resources/policies.json',import.meta.url),'utf8'));
for(const [id,policy]of Object.entries(policies)) {
    // Seed drafts only; release text must match the deployed providers and billing configuration.
    const {data:existing,error}=await db.from('legal_documents').select('id').eq('id',id).maybeSingle();if(error)throw error;if(existing)continue;
    const saved=await db.from('legal_documents').insert({id,title_ar:policy.ar.title,title_en:policy.en.title,sections_ar:policy.ar.sections,sections_en:policy.en.sections,published:false,version:1});if(saved.error)throw saved.error;
}
console.log('Approved scenes uploaded and legal drafts seeded. No payments enabled.');
