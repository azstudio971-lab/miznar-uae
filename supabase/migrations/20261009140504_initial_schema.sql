begin;
create schema if not exists private;
revoke all on schema private from public;
grant usage on schema private to authenticated;
create table public.admin_roles (user_id uuid primary key references auth.users(id) on delete cascade);
alter table public.admin_roles enable row level security;
create policy read_own_admin_role on public.admin_roles for select to authenticated using (user_id = (select auth.uid()));
create function private.is_admin() returns boolean language sql stable security definer set search_path = '' as $$ select exists(select 1 from public.admin_roles where user_id = (select auth.uid())) $$;
revoke all on function private.is_admin() from public;
grant execute on function private.is_admin() to authenticated;
create function private.account_exists() returns boolean language sql stable security definer set search_path = '' as $$ select exists(select 1 from auth.users where id=(select auth.uid())) $$;
revoke all on function private.account_exists() from public;
grant execute on function private.account_exists() to authenticated;
create table public.profiles (
 user_id uuid primary key references auth.users(id) on delete cascade,
 display_name text not null default '' check(char_length(display_name)<=40),
 language text not null default 'ar' check(language in ('ar','en')),
 city text not null default 'Dubai', preferences jsonb not null default '{}' check(jsonb_typeof(preferences)='object'),
 created_at timestamptz not null default now()
);
alter table public.profiles enable row level security;
create policy own_profile_select on public.profiles for select to authenticated using(user_id=(select auth.uid()) or (select private.is_admin()));
create policy own_profile_insert on public.profiles for insert to authenticated with check(user_id=(select auth.uid()));
create policy own_profile_update on public.profiles for update to authenticated using(user_id=(select auth.uid())) with check(user_id=(select auth.uid()));
-- Account deletion runs through the authenticated Edge Function, cascading from auth.users.
create table public.themes (
 id text primary key, name_ar text not null, name_en text not null,
 status text not null default 'draft' check(status in ('draft','published','archived')),
 version integer not null default 1 check(version>0), timezone text not null default 'Asia/Dubai',
 slots jsonb not null, widgets jsonb not null default '{}',
 music_mode text not null default 'none' check(music_mode in ('all','selected','none')),
 music_ids text[] not null default '{}', forced boolean not null default false,
 starts_at timestamptz, ends_at timestamptz, created_at timestamptz not null default now(),
 check(ends_at is null or starts_at is null or ends_at > starts_at)
);
create table public.theme_assets (
 theme_id text references public.themes(id) on delete cascade,
 layout text check(layout in ('compact','ultrawide')), period text check(period in ('dawn','morning','sunset','night')),
 path text not null check(path !~ '(^/|\.\.)'), kind text not null check(kind in ('image','video')),
 primary key(theme_id,layout,period)
);
create function private.validate_theme() returns trigger language plpgsql set search_path = '' as $$
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
 if new.status='published' and new.id<>'spirit-of-the-uae' and (select count(*) from public.theme_assets where theme_id=new.id)<>8 then raise exception 'Eight assets required before publishing'; end if;
 return new;
end $$;
create trigger validate_theme before insert or update on public.themes for each row execute function private.validate_theme();
create table public.music (id text primary key, name_ar text not null, name_en text not null, path text not null, enabled boolean not null default false, created_at timestamptz not null default now());
create table public.messages (id uuid primary key default gen_random_uuid(),title_ar text not null,title_en text not null,body_ar text not null,body_en text not null,city text,starts_at timestamptz not null default now(),expires_at timestamptz not null,check(expires_at>starts_at));
create index messages_active on public.messages(expires_at,city);
create table public.app_settings (id text primary key check(id='public'), value jsonb not null default '{}');
alter table public.themes enable row level security;
alter table public.theme_assets enable row level security;
alter table public.music enable row level security;
alter table public.messages enable row level security;
alter table public.app_settings enable row level security;
create policy admin_themes on public.themes for all to authenticated using((select private.is_admin())) with check((select private.is_admin()));
create policy admin_assets on public.theme_assets for all to authenticated using((select private.is_admin())) with check((select private.is_admin()));
create policy admin_music on public.music for all to authenticated using((select private.is_admin())) with check((select private.is_admin()));
create policy admin_messages on public.messages for all to authenticated using((select private.is_admin())) with check((select private.is_admin()));
create policy admin_settings on public.app_settings for all to authenticated using((select private.is_admin())) with check((select private.is_admin()));
create policy own_messages on public.messages for select to authenticated using((select private.account_exists()) and starts_at<=now() and expires_at>now() and (city is null or city=(select p.city from public.profiles p where p.user_id=(select auth.uid()))));
-- Guests only access curated, signed catalog responses. No direct anonymous table grants.
revoke all on public.admin_roles,public.profiles,public.themes,public.theme_assets,public.music,public.messages,public.app_settings from anon;
grant select on public.admin_roles to authenticated;
revoke insert,update,delete on public.admin_roles from authenticated;
grant select,insert,update on public.profiles to authenticated;
grant select,insert,update,delete on public.themes,public.theme_assets,public.music,public.messages,public.app_settings to authenticated;
insert into public.themes(id,name_ar,name_en,status,slots,widgets,music_mode) values('spirit-of-the-uae','روح الإمارات','Spirit of the UAE','published','[{"period":"dawn","start":300,"end":420},{"period":"morning","start":420,"end":1020},{"period":"sunset","start":1020,"end":1140},{"period":"night","start":1140,"end":300}]','{"clock":true,"date":true,"greeting":true,"allow_move":false,"allow_resize":true}','none');
insert into public.app_settings values('public','{"default_theme":"spirit-of-the-uae"}');
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('theme-media','theme-media',false,52428800,array['image/png','image/jpeg','image/webp','video/mp4','audio/mpeg','audio/mp4','audio/wav','audio/x-wav']);
create policy admin_storage on storage.objects for all to authenticated using(bucket_id='theme-media' and (select private.is_admin())) with check(bucket_id='theme-media' and (select private.is_admin()));
commit;
