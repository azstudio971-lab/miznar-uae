import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {PGlite} from '@electric-sql/pglite';
const a='11111111-1111-4111-8111-111111111111',b='22222222-2222-4222-8222-222222222222',admin='33333333-3333-4333-8333-333333333333';
test('migration enforces owner/admin isolation, publication validation and deletion cascade',async()=>{
 const db=new PGlite();
 try {
 await db.exec(`create role anon;create role authenticated;create schema auth;create table auth.users(id uuid primary key);create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;grant usage on schema auth to authenticated;grant execute on function auth.uid() to authenticated;create schema storage;create table storage.buckets(id text primary key,name text,public boolean,file_size_limit bigint,allowed_mime_types text[]);create table storage.objects(id uuid primary key,bucket_id text,name text);alter table storage.objects enable row level security;grant usage on schema storage to authenticated;grant all on storage.objects to authenticated;`);
 await db.exec(readFileSync('supabase/migrations/20261009140504_initial_schema.sql','utf8'));
 await db.exec(readFileSync('supabase/migrations/20261009151105_full_platform.sql','utf8'));

 await db.exec(`insert into auth.users values('${a}'),('${b}'),('${admin}');insert into public.admin_roles values('${admin}');insert into public.staff_accounts(user_id,role_key) values('${admin}','super_admin');insert into public.profiles(user_id,display_name) values('${a}','A'),('${b}','B');set role authenticated;select set_config('request.jwt.claim.sub','${a}',false);`);
 assert.deepEqual((await db.query('select display_name from public.profiles')).rows,[{display_name:'A'}]);
 assert.equal((await db.query('select * from public.themes')).rows.length,0);
 await assert.rejects(db.exec(`insert into public.admin_roles values('${a}')`));
 await assert.rejects(db.exec(`update public.profiles set user_id='${b}' where user_id='${a}'`));
 await db.exec(`update public.profiles set display_name='Updated' where user_id='${a}'`);
 assert.equal((await db.query('select display_name from public.profiles')).rows[0].display_name,'Updated');
 await db.exec(`select set_config('request.jwt.claim.sub','${admin}',false)`);
 assert.equal((await db.query('select * from public.profiles')).rows.length,2);
 assert.equal((await db.query('select * from public.themes')).rows.length,1);
 assert.deepEqual((await db.query('select public.my_permissions() as p')).rows[0].p,['*']);
 await assert.rejects(db.exec(`delete from public.staff_accounts where user_id='${admin}'`));
 await db.exec(`reset role;insert into public.staff_accounts(user_id,role_key) values('${b}','theme_editor');insert into public.devices(id,user_id,name) values('${a}','${a}','iPhone');set role authenticated;select set_config('request.jwt.claim.sub','${a}',false);`);
 const sid='44444444-4444-4444-8444-444444444444';
 let tick=(await db.query(`select public.trial_heartbeat('${sid}','${a}',1,true) as result`)).rows[0].result;
 assert.equal(tick.remaining_seconds,1800);
 await db.exec(`reset role;update public.trial_sessions set last_heartbeat=clock_timestamp()-interval '10 seconds' where id='${sid}';set role authenticated;`);
 tick=(await db.query(`select public.trial_heartbeat('${sid}','${a}',2,true) as result`)).rows[0].result;
 assert.ok(tick.used_seconds>=10&&tick.used_seconds<=11);
 const replay=(await db.query(`select public.trial_heartbeat('${sid}','${a}',2,true) as result`)).rows[0].result;
 assert.equal(replay.used_seconds,tick.used_seconds);assert.equal(replay.replayed,true);
 await assert.rejects(db.exec(`update public.trial_accounts set used_seconds=0`));
 await db.exec(`select set_config('request.jwt.claim.sub','${b}',false);`);
 const caps=(await db.query('select public.my_permissions() as p')).rows[0].p;
 assert.ok(caps.includes('themes.write'));assert.ok(!caps.includes('staff.write'));
 await assert.rejects(db.exec(`insert into public.staff_accounts(user_id,role_key) values('${a}','super_admin')`));
 await db.exec(`insert into public.themes(id,name_ar,name_en,slots) select 'editor-theme','أ','Editor',slots from public.themes where id='spirit-of-the-uae';`);
 await db.exec(`insert into storage.objects(id,bucket_id,name) values('55555555-5555-4555-8555-555555555555','theme-media','themes/editor-theme/a.png');reset role;insert into storage.objects(id,bucket_id,name) values('66666666-6666-4666-8666-666666666666','theme-media','music/song/a.mp3');set role authenticated;`);
 assert.equal((await db.query(`delete from storage.objects where name like 'music/%' returning id`)).rows.length,0);
 assert.equal((await db.query(`select public.my_permissions() as p`)).rows[0].p.includes('music.write'),false);
 await db.exec(`select set_config('request.jwt.claim.sub','${admin}',false);`);
 await db.exec(`insert into public.theme_widget_settings(theme_id,widget_id,x,y) values('editor-theme','clock',.2,.3);update public.themes set version=1 where id='editor-theme';update public.themes set name_en='Changed',version=2 where id='editor-theme';update public.theme_widget_settings set x=.8 where theme_id='editor-theme';select public.restore_theme('editor-theme',1);`);
 assert.equal((await db.query(`select name_en,version,status from public.themes where id='editor-theme'`)).rows[0].name_en,'Editor');
 assert.equal((await db.query(`select x::float8 as x from public.theme_widget_settings where theme_id='editor-theme'`)).rows[0].x,0.2);
 assert.equal((await db.query(`select snapshot->'widgets'->0->>'x' as x from public.theme_versions where theme_id='editor-theme' and version=3`)).rows[0].x,'0.2');
 await db.exec(`reset role;update public.profiles set account_status='suspended' where user_id='${b}';set role authenticated;select set_config('request.jwt.claim.sub','${b}',false);`);
 assert.deepEqual((await db.query('select public.my_permissions() as p')).rows[0].p,[]);
 await db.exec(`select set_config('request.jwt.claim.sub','${admin}',false);`);

 await assert.rejects(db.exec(`update public.themes set slots='[]' where id='spirit-of-the-uae'`));
 await assert.rejects(db.exec(`insert into public.themes(id,name_ar,name_en,status,slots) select 'new','جديد','New','published',slots from public.themes limit 1`));
 await db.exec(`insert into public.messages(title_ar,title_en,body_ar,body_en,expires_at) values('أ','A','ب','B',now()+interval '1 day');reset role;delete from auth.users where id='${a}';set role authenticated;select set_config('request.jwt.claim.sub','${a}',false);`);
 assert.equal((await db.query('select * from public.profiles')).rows.length,0);
 assert.equal((await db.query('select * from public.messages')).rows.length,0);
 } finally {await db.close();}
});
