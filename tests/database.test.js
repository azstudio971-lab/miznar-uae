import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {PGlite} from '@electric-sql/pglite';
const a='11111111-1111-4111-8111-111111111111',b='22222222-2222-4222-8222-222222222222',admin='33333333-3333-4333-8333-333333333333';
test('migration enforces owner/admin isolation, publication validation and deletion cascade',async()=>{
 const db=new PGlite();
 try {
 await db.exec(`create role anon;create role authenticated;create schema auth;create table auth.users(id uuid primary key);create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;grant usage on schema auth to authenticated;grant execute on function auth.uid() to authenticated;create schema storage;create table storage.buckets(id text primary key,name text,public boolean,file_size_limit bigint,allowed_mime_types text[]);create table storage.objects(id uuid primary key,bucket_id text);alter table storage.objects enable row level security;grant usage on schema storage to authenticated;grant all on storage.objects to authenticated;`);
 await db.exec(readFileSync('supabase/migrations/20261009140504_initial_schema.sql','utf8'));
 await db.exec(`insert into auth.users values('${a}'),('${b}'),('${admin}');insert into public.admin_roles values('${admin}');insert into public.profiles(user_id,display_name) values('${a}','A'),('${b}','B');set role authenticated;select set_config('request.jwt.claim.sub','${a}',false);`);
 assert.deepEqual((await db.query('select display_name from public.profiles')).rows,[{display_name:'A'}]);
 assert.equal((await db.query('select * from public.themes')).rows.length,0);
 await assert.rejects(db.exec(`insert into public.admin_roles values('${a}')`));
 await assert.rejects(db.exec(`update public.profiles set user_id='${b}' where user_id='${a}'`));
 await db.exec(`update public.profiles set display_name='Updated' where user_id='${a}'`);
 assert.equal((await db.query('select display_name from public.profiles')).rows[0].display_name,'Updated');
 await db.exec(`select set_config('request.jwt.claim.sub','${admin}',false)`);
 assert.equal((await db.query('select * from public.profiles')).rows.length,2);
 assert.equal((await db.query('select * from public.themes')).rows.length,1);
 await assert.rejects(db.exec(`update public.themes set slots='[]' where id='spirit-of-the-uae'`));
 await assert.rejects(db.exec(`insert into public.themes(id,name_ar,name_en,status,slots) select 'new','جديد','New','published',slots from public.themes limit 1`));
 await db.exec(`insert into public.messages(title_ar,title_en,body_ar,body_en,expires_at) values('أ','A','ب','B',now()+interval '1 day');reset role;delete from auth.users where id='${a}';set role authenticated;select set_config('request.jwt.claim.sub','${a}',false);`);
 assert.equal((await db.query('select * from public.profiles')).rows.length,0);
 assert.equal((await db.query('select * from public.messages')).rows.length,0);
 } finally {await db.close();}
});
