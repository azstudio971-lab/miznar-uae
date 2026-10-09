begin;
create table public.roles (key text primary key, name_ar text not null, name_en text not null);
create table public.role_permissions (role_key text references public.roles(key) on delete cascade, permission text, primary key(role_key,permission));
create table public.staff_accounts (user_id uuid primary key references auth.users(id) on delete cascade, role_key text not null references public.roles(key), enabled boolean not null default true, created_at timestamptz not null default now());
insert into public.roles values ('super_admin','المسؤول الرئيسي','Super Admin'),('admin','مدير','Admin'),('content_manager','مدير المحتوى','Content Manager'),('theme_editor','محرر الثيمات','Theme Editor'),('viewer','مشاهد','Viewer');
insert into public.role_permissions values
('super_admin','*'),('admin','themes.read'),('admin','themes.write'),('admin','music.read'),('admin','music.write'),('admin','content.read'),('admin','content.write'),('admin','users.read'),('admin','users.write'),('admin','subscriptions.read'),('admin','messages.read'),('admin','messages.write'),('admin','settings.read'),('admin','settings.write'),('admin','audit.read'),('admin','staff.read'),
('content_manager','themes.read'),('content_manager','music.read'),('content_manager','music.write'),('content_manager','content.read'),('content_manager','content.write'),('content_manager','messages.read'),('content_manager','messages.write'),('content_manager','settings.read'),
('theme_editor','themes.read'),('theme_editor','themes.write'),('theme_editor','music.read'),('theme_editor','settings.read'),
('viewer','themes.read'),('viewer','music.read'),('viewer','content.read'),('viewer','settings.read');
insert into public.staff_accounts(user_id,role_key) select user_id,'super_admin' from public.admin_roles;
alter table public.profiles add column last_active_at timestamptz,add column account_status text not null default 'active' check(account_status in ('active','suspended'));
create function private.can(cap text) returns boolean language sql stable security definer set search_path='' as $$
 select (select private.account_exists()) and not exists(select 1 from public.profiles where user_id=(select auth.uid()) and account_status<>'active') and exists(select 1 from public.staff_accounts s join public.role_permissions p on p.role_key=s.role_key where s.user_id=(select auth.uid()) and s.enabled and (p.permission=cap or p.permission='*')) $$;
revoke all on function private.can(text) from public; grant execute on function private.can(text) to authenticated;
create or replace function private.is_admin() returns boolean language sql stable security definer set search_path='' as $$ select (select private.can('staff.write')) $$;
create function public.my_permissions() returns text[] language sql stable security definer set search_path='' as $$ select coalesce(array_agg(p.permission),'{}') from public.staff_accounts s join public.role_permissions p on p.role_key=s.role_key where s.user_id=(select auth.uid()) and s.enabled and (select private.can(p.permission)) $$;
revoke all on function public.my_permissions() from public;grant execute on function public.my_permissions() to authenticated;
-- Users never assign themselves staff status. First owner is bootstrapped by a server credential.
alter table public.roles enable row level security;alter table public.role_permissions enable row level security;alter table public.staff_accounts enable row level security;
create policy roles_read on public.roles for select to authenticated using((select private.can('staff.read')) or exists(select 1 from public.staff_accounts s where s.user_id=(select auth.uid())));
create policy permissions_read on public.role_permissions for select to authenticated using((select private.can('staff.read')));
create policy staff_read on public.staff_accounts for select to authenticated using(user_id=(select auth.uid()) or (select private.can('staff.read')));
create policy staff_insert on public.staff_accounts for insert to authenticated with check((select private.can('staff.write')));
create policy staff_update on public.staff_accounts for update to authenticated using((select private.can('staff.write'))) with check((select private.can('staff.write')));
create policy staff_delete on public.staff_accounts for delete to authenticated using((select private.can('staff.write')));
create function private.keep_owner() returns trigger language plpgsql security definer set search_path='' as $$
begin
 perform pg_advisory_xact_lock(720911);
 if old.role_key='super_admin' and old.enabled and (tg_op='DELETE' or new.role_key<>'super_admin' or not new.enabled) and not exists(select 1 from public.staff_accounts where user_id<>old.user_id and role_key='super_admin' and enabled) then raise exception 'Last owner cannot be removed';end if;
 if tg_op='DELETE' then return old;end if;return new;
end $$;
create trigger keep_owner before update or delete on public.staff_accounts for each row execute function private.keep_owner();
create table public.devices (id uuid primary key,user_id uuid not null references auth.users(id) on delete cascade,name text not null check(length(name)<=100),platform text not null default 'ios',last_seen_at timestamptz not null default now(),revoked_at timestamptz);
create index devices_owner on public.devices(user_id,last_seen_at desc);
-- Status and activity are maintained by server functions, not owner upserts.
revoke update on public.profiles from authenticated;
grant update(display_name,language,city,preferences) on public.profiles to authenticated;
create table public.subscription_entitlements (id uuid primary key default gen_random_uuid(),user_id uuid not null references auth.users(id) on delete cascade,product_id text not null,original_transaction_id text unique not null,expires_at timestamptz,revoked_at timestamptz,status text not null check(status in ('active','expired','billing_retry','grace_period','revoked')),environment text not null check(environment in ('Sandbox','Production')),updated_at timestamptz not null default now());
create index entitlements_owner on public.subscription_entitlements(user_id,expires_at);
create table public.trial_accounts (user_id uuid primary key references auth.users(id) on delete cascade,used_seconds integer not null default 0 check(used_seconds between 0 and 1800),updated_at timestamptz not null default now());
create table public.trial_sessions (id uuid primary key,user_id uuid not null references auth.users(id) on delete cascade,device_id uuid not null references public.devices(id) on delete cascade,sequence integer not null default 0,active boolean not null default false,started_at timestamptz not null default now(),last_heartbeat timestamptz not null default now(),closed_at timestamptz);
create index trial_sessions_owner on public.trial_sessions(user_id,last_heartbeat desc);
create function public.trial_heartbeat(p_session uuid,p_device uuid,p_sequence integer,p_active boolean) returns jsonb language plpgsql security definer set search_path='' as $$
declare uid uuid := (select auth.uid());s public.trial_sessions;used integer;delta integer:=0;now_at timestamptz:=clock_timestamp(); paid boolean;
begin
 if uid is null or not (select private.account_exists()) then raise exception 'Authentication required';end if;
 if not exists(select 1 from public.devices where id=p_device and user_id=uid and revoked_at is null) then raise exception 'Invalid device';end if;
 if exists(select 1 from public.profiles where user_id=uid and account_status<>'active') then raise exception 'Account unavailable';end if;
 perform pg_advisory_xact_lock(hashtext(uid::text));
 insert into public.trial_accounts(user_id) values(uid) on conflict do nothing;
 select used_seconds into used from public.trial_accounts where user_id=uid for update;
 select exists(select 1 from public.subscription_entitlements where user_id=uid and revoked_at is null and expires_at>now_at and status in ('active','grace_period')) into paid;
 select * into s from public.trial_sessions where id=p_session for update;
 if found then
   if s.user_id<>uid or s.device_id<>p_device or s.closed_at is not null then raise exception 'Invalid session';end if;
   if p_sequence<=s.sequence then return jsonb_build_object('used_seconds',used,'remaining_seconds',1800-used,'entitled',paid,'replayed',true);end if;
   if s.active and not paid then delta:=least(15,greatest(0,floor(extract(epoch from now_at-s.last_heartbeat))::integer));end if;
 else
   if p_sequence<>1 then raise exception 'Session must start at sequence one';end if;
   if exists(select 1 from public.trial_sessions where user_id=uid and active and closed_at is null and last_heartbeat>now_at-interval '20 seconds') then raise exception 'Another device is already using the trial';end if;
   insert into public.trial_sessions(id,user_id,device_id) values(p_session,uid,p_device);
 end if;
 used:=least(1800,used+delta);
 update public.trial_accounts set used_seconds=used,updated_at=now_at where user_id=uid;
 update public.trial_sessions set sequence=p_sequence,active=p_active and (paid or used<1800),last_heartbeat=now_at where id=p_session;
 update public.devices set last_seen_at=now_at where id=p_device;
 update public.profiles set last_active_at=now_at where user_id=uid;
 return jsonb_build_object('used_seconds',used,'remaining_seconds',1800-used,'entitled',paid,'lease_expires_at',now_at+interval '15 seconds');
end $$;
revoke all on function public.trial_heartbeat(uuid,uuid,integer,boolean) from public;grant execute on function public.trial_heartbeat(uuid,uuid,integer,boolean) to authenticated;
create table public.widget_definitions (id text primary key,name_ar text not null,name_en text not null,kind text not null,enabled boolean not null default true);
insert into public.widget_definitions values ('clock','الساعة','Clock','clock',true),('date','التاريخ','Date','date',true),('weather','الطقس','Weather','weather',true),('prayer','الصلاة','Prayer','prayer',true),('adhkar','الأذكار','Adhkar','religious',true),('music','الموسيقى','Music','music',true),('greeting','التحية','Greeting','greeting',true);
create table public.theme_widget_settings (theme_id text references public.themes(id) on delete cascade,widget_id text references public.widget_definitions(id),visible boolean not null default true,x numeric not null default .7 check(x between 0 and 1),y numeric not null default .2 check(y between 0 and 1),scale numeric not null default 1 check(scale between .5 and 2),opacity numeric not null default 1 check(opacity between .2 and 1),sort_order integer not null default 0,allow_move boolean not null default false,allow_resize boolean not null default true,allow_hide boolean not null default true,primary key(theme_id,widget_id));
create table public.user_widget_preferences (user_id uuid references auth.users(id) on delete cascade,theme_id text references public.themes(id) on delete cascade,widget_id text references public.widget_definitions(id),value jsonb not null,primary key(user_id,theme_id,widget_id));
alter table public.themes drop constraint themes_status_check;
alter table public.themes add constraint themes_status_check check(status in ('draft','published','unpublished','scheduled','archived'));
alter table public.themes add column description_ar text not null default '',add column description_en text not null default '',add column thumbnail_path text,add column theme_type text not null default 'daily',add column priority integer not null default 0,add column sort_order integer not null default 0,add column weekdays integer[] not null default array[0,1,2,3,4,5,6],add column fallback_path text;
create table public.theme_media (id uuid primary key default gen_random_uuid(),theme_id text not null references public.themes(id) on delete cascade,layout text not null check(layout in ('compact','ultrawide')),period text not null check(period in ('dawn','morning','sunset','night','any')),kind text not null check(kind in ('image','video')),path text not null check(path !~ '(^/|\.\.)'),sort_order integer not null default 0,duration_seconds integer not null default 30 check(duration_seconds between 5 and 3600),starts_at timestamptz,ends_at timestamptz,check(ends_at is null or starts_at is null or ends_at>starts_at));
create index theme_media_lookup on public.theme_media(theme_id,layout,period,sort_order);
create table public.theme_versions (id uuid primary key default gen_random_uuid(),theme_id text not null references public.themes(id) on delete cascade,version integer not null,snapshot jsonb not null,created_by uuid references auth.users(id) on delete set null,created_at timestamptz not null default now(),unique(theme_id,version));
create function private.snapshot_theme() returns trigger language plpgsql security definer set search_path='' as $$
begin
 insert into public.theme_versions(theme_id,version,snapshot,created_by) values(new.id,new.version,jsonb_build_object('theme',to_jsonb(new),'assets',(select coalesce(jsonb_agg(a),'[]') from public.theme_assets a where theme_id=new.id),'media',(select coalesce(jsonb_agg(m),'[]') from public.theme_media m where theme_id=new.id),'widgets',(select coalesce(jsonb_agg(w),'[]') from public.theme_widget_settings w where theme_id=new.id),'playlists',(select coalesce(jsonb_agg(p),'[]') from public.theme_playlists p where theme_id=new.id)),(select auth.uid())) on conflict(theme_id,version) do update set snapshot=excluded.snapshot,created_by=excluded.created_by where public.theme_versions.snapshot->'theme'->>'status' not in ('published','scheduled');return new;
end $$;
create trigger snapshot_theme after insert or update on public.themes for each row execute function private.snapshot_theme();
create function public.restore_theme(p_id text,p_version integer) returns void language plpgsql security definer set search_path='' as $$
declare snap jsonb;t public.themes;next_version integer;
begin
 if not (select private.can('themes.write')) then raise exception 'Permission denied';end if;
 perform pg_advisory_xact_lock(hashtext(p_id));
 select snapshot into snap from public.theme_versions where theme_id=p_id and version=p_version;if snap is null then raise exception 'Version unavailable';end if;
 select version+1 into next_version from public.themes where id=p_id for update;
 t:=jsonb_populate_record(null::public.themes,snap->'theme');
 update public.themes set status='draft',name_ar=t.name_ar,name_en=t.name_en,description_ar=t.description_ar,description_en=t.description_en,timezone=t.timezone,slots=t.slots,widgets=t.widgets,music_mode=t.music_mode,music_ids=t.music_ids,forced=t.forced,starts_at=t.starts_at,ends_at=t.ends_at,priority=t.priority,weekdays=t.weekdays,theme_type=t.theme_type,sort_order=t.sort_order,thumbnail_path=t.thumbnail_path,fallback_path=t.fallback_path,version=next_version where id=p_id;
 delete from public.theme_assets where theme_id=p_id;insert into public.theme_assets select * from jsonb_populate_recordset(null::public.theme_assets,snap->'assets');
 delete from public.theme_media where theme_id=p_id;insert into public.theme_media select * from jsonb_populate_recordset(null::public.theme_media,snap->'media');
 delete from public.theme_widget_settings where theme_id=p_id;insert into public.theme_widget_settings select * from jsonb_populate_recordset(null::public.theme_widget_settings,snap->'widgets');
 delete from public.theme_playlists where theme_id=p_id;insert into public.theme_playlists select * from jsonb_populate_recordset(null::public.theme_playlists,coalesce(snap->'playlists','[]'::jsonb));
 update public.themes set version=next_version where id=p_id;
end $$;
revoke all on function public.restore_theme(text,integer) from public;grant execute on function public.restore_theme(text,integer) to authenticated;
create function private.validate_rollout() returns trigger language plpgsql set search_path='' as $$
begin
 if new.weekdays is null or cardinality(new.weekdays)=0 or not new.weekdays <@ array[0,1,2,3,4,5,6] then raise exception 'Invalid weekdays';end if;
 if new.status in ('published','scheduled') and new.forced then
  perform pg_advisory_xact_lock(720912);
  if exists(select 1 from public.themes t where t.id<>new.id and t.forced and t.status in ('published','scheduled') and t.priority=new.priority and t.weekdays && new.weekdays and tstzrange(t.starts_at,t.ends_at,'[)') && tstzrange(new.starts_at,new.ends_at,'[)')) then raise exception 'Forced theme schedule conflict at the same priority';end if;
 end if;
 if new.status='scheduled' and new.starts_at is null then raise exception 'Scheduled themes require a start date';end if;
 return new;
end $$;
create trigger validate_rollout before insert or update on public.themes for each row execute function private.validate_rollout();
alter table public.music add column sort_order integer not null default 0,add column duration_seconds integer,add column rights_note text not null default '';
create table public.playlists (id uuid primary key default gen_random_uuid(),name_ar text not null,name_en text not null,enabled boolean not null default true,sort_order integer not null default 0);
create table public.playlist_tracks (playlist_id uuid references public.playlists(id) on delete cascade,track_id text references public.music(id) on delete cascade,sort_order integer not null default 0,primary key(playlist_id,track_id));
create table public.theme_playlists (theme_id text references public.themes(id) on delete cascade,playlist_id uuid references public.playlists(id) on delete cascade,primary key(theme_id,playlist_id));
create table public.religious_content (id uuid primary key default gen_random_uuid(),kind text not null check(kind in ('adhkar','dua','hadith')),title_ar text not null,title_en text not null,text_ar text not null,text_en text not null,source_title text not null,source_url text not null check(source_url like 'https://%'),verified boolean not null default false,status text not null default 'draft' check(status in ('draft','published','archived')),sort_order integer not null default 0,starts_at timestamptz,ends_at timestamptz,check(status<>'published' or verified));
create table public.legal_documents (id text primary key,title_ar text not null,title_en text not null,sections_ar jsonb not null,sections_en jsonb not null,version integer not null default 1,published boolean not null default false,updated_at timestamptz not null default now());
create table public.notification_receipts (user_id uuid references auth.users(id) on delete cascade,message_id uuid references public.messages(id) on delete cascade,read_at timestamptz not null default now(),primary key(user_id,message_id));
create table public.audit_logs (id bigint generated always as identity primary key,actor_id uuid references auth.users(id) on delete set null,operation text not null,table_name text not null,subject_id text,changed_fields text[],created_at timestamptz not null default now());
create index audit_recent on public.audit_logs(created_at desc);
create function private.audit_change() returns trigger language plpgsql security definer set search_path='' as $$
declare item jsonb:=case when tg_op='DELETE' then to_jsonb(old) else to_jsonb(new) end;
begin
 insert into public.audit_logs(actor_id,operation,table_name,subject_id,changed_fields) values((select auth.uid()),tg_op,tg_table_name,coalesce(item->>'id',item->>'theme_id',item->>'user_id'),array(select jsonb_object_keys(item)));
 if tg_op='DELETE' then return old;end if;return new;
end $$;
-- Replace broad administrator policies with explicit permissions.
drop policy admin_themes on public.themes;drop policy admin_assets on public.theme_assets;drop policy admin_music on public.music;drop policy admin_messages on public.messages;drop policy admin_settings on public.app_settings;
drop policy own_profile_select on public.profiles;
create policy profile_read on public.profiles for select to authenticated using(user_id=(select auth.uid()) or (select private.can('users.read')));
do $$ declare item record;begin
 for item in select * from (values('themes','themes'),('theme_assets','themes'),('theme_media','themes'),('theme_versions','themes'),('theme_widget_settings','themes'),('widget_definitions','themes'),('music','music'),('playlists','music'),('playlist_tracks','music'),('theme_playlists','themes'),('religious_content','content'),('legal_documents','settings'),('messages','messages'),('app_settings','settings')) v(tbl,cap) loop
  execute format('alter table public.%I enable row level security',item.tbl);
  execute format('revoke all on public.%I from anon,authenticated',item.tbl);
  execute format('grant select,insert,update,delete on public.%I to authenticated',item.tbl);
  execute format('create policy permission_read on public.%I for select to authenticated using ((select private.can(%L)))',item.tbl,item.cap||'.read');
  if item.tbl<>'theme_versions' then
   execute format('create policy permission_insert on public.%I for insert to authenticated with check ((select private.can(%L)))',item.tbl,item.cap||'.write');
   execute format('create policy permission_update on public.%I for update to authenticated using ((select private.can(%L))) with check ((select private.can(%L)))',item.tbl,item.cap||'.write',item.cap||'.write');
   execute format('create policy permission_delete on public.%I for delete to authenticated using ((select private.can(%L)))',item.tbl,item.cap||'.write');
  end if;
  execute format('create trigger audit_change after insert or update or delete on public.%I for each row execute function private.audit_change()',item.tbl);
 end loop;
 for item in select * from (values('user_widget_preferences'),('notification_receipts')) v(tbl) loop
  execute format('alter table public.%I enable row level security',item.tbl);
  execute format('revoke all on public.%I from anon,authenticated',item.tbl);
  execute format('grant select,insert,update,delete on public.%I to authenticated',item.tbl);
  execute format('create policy owner_rows on public.%I for all to authenticated using (user_id=(select auth.uid())) with check (user_id=(select auth.uid()) and (select private.account_exists()))',item.tbl);
 end loop;
 for item in select * from (values('trial_accounts'),('trial_sessions'),('subscription_entitlements')) v(tbl) loop
  execute format('alter table public.%I enable row level security',item.tbl);
  execute format('revoke all on public.%I from anon,authenticated',item.tbl);
  execute format('grant select on public.%I to authenticated',item.tbl);
  execute format('create policy entitlement_read on public.%I for select to authenticated using (user_id=(select auth.uid()) or (select private.can(''subscriptions.read'')))',item.tbl);
 end loop;
end $$;
revoke all on public.roles,public.role_permissions,public.staff_accounts from anon,authenticated;grant select on public.roles,public.role_permissions to authenticated;grant select,insert,update,delete on public.staff_accounts to authenticated;
alter table public.audit_logs enable row level security;revoke all on public.audit_logs from anon,authenticated;grant select on public.audit_logs to authenticated;create policy audit_read on public.audit_logs for select to authenticated using((select private.can('audit.read')));
drop policy admin_storage on storage.objects;
create policy content_storage on storage.objects for all to authenticated using(bucket_id='theme-media' and ((name like 'themes/%' and (select private.can('themes.write'))) or (name like 'music/%' and (select private.can('music.write'))))) with check(bucket_id='theme-media' and ((name like 'themes/%' and (select private.can('themes.write'))) or (name like 'music/%' and (select private.can('music.write')))));
alter table public.devices enable row level security;revoke all on public.devices from anon,authenticated;grant select on public.devices to authenticated;create policy device_read on public.devices for select to authenticated using(user_id=(select auth.uid()) or (select private.can('users.read')));
-- Functions in private are not exposed RPCs; prevent inherited PUBLIC execution.
revoke all on all functions in schema private from public;
grant execute on function private.is_admin(),private.account_exists(),private.can(text) to authenticated;
-- Keep public settings free of secrets. Sensitive provider credentials live only in server environment variables.
update public.app_settings set value=value||'{"maintenance":false,"minimum_version":"0.1.0","subscriptions_enabled":false,"trial_enabled":false,"refresh_seconds":600,"splash_enabled":true,"splash_duration":1.2}';

create or replace function private.validate_theme() returns trigger language plpgsql set search_path = '' as $$
declare slot jsonb; seen text[] := '{}'; counts integer[] := array_fill(0,array[1440]); m integer; finish integer; i integer;
begin
 if not exists(select 1 from pg_timezone_names where name=new.timezone) then raise exception 'Unknown timezone'; end if;
 if jsonb_typeof(new.slots) <> 'array' or jsonb_array_length(new.slots)<>4 then raise exception 'Four periods required'; end if;
 for slot in select value from jsonb_array_elements(new.slots) loop
   if slot->>'period' is null or slot->>'period' not in ('dawn','morning','sunset','night') or slot->>'period'=any(seen) then raise exception 'Invalid period'; end if;
   seen := array_append(seen,slot->>'period'); m := (slot->>'start')::integer; finish := (slot->>'end')::integer;
   if m is null or finish is null or m<0 or m>1439 or finish<0 or finish>1439 or m=finish then raise exception 'Invalid time'; end if;
   while m<>finish loop counts[m+1]:=counts[m+1]+1; m:=(m+1)%1440; end loop;
 end loop;
 for i in 1..1440 loop if counts[i]<>1 then raise exception 'Schedule must cover each minute exactly once'; end if; end loop;
 if new.status in ('published','scheduled') and new.id<>'spirit-of-the-uae' and exists(
  select 1 from (values('compact'),('ultrawide')) l(layout) cross join (values('dawn'),('morning'),('sunset'),('night')) p(period)
  where not exists(select 1 from public.theme_assets a where a.theme_id=new.id and a.layout=l.layout and a.period=p.period)
    and not exists(select 1 from public.theme_media m where m.theme_id=new.id and m.layout=l.layout and m.period in(p.period,'any'))
 ) then raise exception 'Media required for each layout and daily period before publishing';end if;
 return new;
end $$;

commit;
