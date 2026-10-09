begin;
-- A theme has one curated playlist at most.
alter table public.theme_playlists add constraint theme_one_playlist unique(theme_id);
alter table public.playlists add column description text not null default '';
alter table public.profiles add column region text not null default '', add column country text not null default 'AE';
grant update(region,country) on public.profiles to authenticated;
alter table public.audit_logs add column metadata jsonb not null default '{}';
create table public.library_items (
 id uuid primary key default gen_random_uuid(),kind text not null check(kind in ('website','live')),
 name_ar text not null check(length(name_ar) between 1 and 120),name_en text not null,
 url text not null check(url ~ '^https://'),description_ar text not null default '',description_en text not null default '',
 icon_url text not null default '',brand_color text not null default '#073844',sort_order integer not null default 0,enabled boolean not null default true,
 created_at timestamptz not null default now()
);
create table public.app_updates (id uuid primary key default gen_random_uuid(),title_ar text not null,title_en text not null,body_ar text not null,body_en text not null,version text not null default '1.1.1',published boolean not null default true,created_at timestamptz not null default now());
create table public.user_library (user_id uuid primary key references auth.users(id) on delete cascade,items jsonb not null default '[]',favorites jsonb not null default '[]',updated_at timestamptz not null default now(),check(jsonb_typeof(items)='array'),check(jsonb_typeof(favorites)='array'));
alter table public.user_library enable row level security;
grant select,insert,update,delete on public.user_library to authenticated;
create policy own_library on public.user_library for all to authenticated using(user_id=(select auth.uid()) and (select private.account_exists())) with check(user_id=(select auth.uid()) and (select private.account_exists()));
do $$declare t text;begin foreach t in array array['library_items','app_updates'] loop
 execute format('alter table public.%I enable row level security',t);
 execute format('grant select,insert,update,delete on public.%I to authenticated',t);
 execute format('create policy content_admin on public.%I for all to authenticated using((select private.can(''content.write''))) with check((select private.can(''content.write'')))',t);
 execute format('create trigger audit_change after insert or update or delete on public.%I for each row execute function private.audit_change()',t);
end loop;end $$;
create table public.push_devices (
 installation_id uuid primary key,secret_hash text not null,device_token text not null unique,environment text not null check(environment in ('sandbox','production')),
 user_id uuid references auth.users(id) on delete cascade,city text not null default '',region text not null default '',country text not null default '',enabled boolean not null default true,last_seen_at timestamptz not null default now()
);
alter table public.push_devices enable row level security;
revoke all on public.push_devices from anon,authenticated;
create table public.push_campaigns (
 id uuid primary key default gen_random_uuid(),title text not null check(length(title) between 1 and 120),body text not null check(length(body) between 1 and 1000),
 audience text not null check(audience in ('all','city','region')),target text not null default '',status text not null default 'draft' check(status in ('draft','queued','sending','sent','partial','blocked','failed')),
 sent_count integer not null default 0,failed_count integer not null default 0,target_count integer not null default 0,last_error text,created_by uuid references auth.users(id),created_at timestamptz not null default now(),sent_at timestamptz,
 check(audience='all' or length(trim(target))>0)
);
alter table public.push_campaigns enable row level security;
revoke all on public.push_campaigns from anon,authenticated;
grant select on public.push_campaigns to authenticated;
create policy push_admin_read on public.push_campaigns for select to authenticated using((select private.can('messages.read')));
create table public.push_deliveries (campaign_id uuid references public.push_campaigns(id) on delete cascade,installation_id uuid references public.push_devices(installation_id) on delete cascade,status text not null,reason text,updated_at timestamptz not null default now(),primary key(campaign_id,installation_id));
alter table public.push_deliveries enable row level security;
revoke all on public.push_deliveries from anon,authenticated;
create index push_target_city on public.push_devices(city) where enabled;
create index push_target_region on public.push_devices(region) where enabled;
create index push_owner on public.push_devices(user_id);
create index push_delivery_install on public.push_deliveries(installation_id);
create index push_creator on public.push_campaigns(created_by);
insert into public.library_items(kind,name_ar,name_en,url,brand_color,sort_order) values
 ('website','YouTube','YouTube','https://www.youtube.com','#FF0033',0),('website','شاهد','Shahid','https://shahid.mbc.net','#00BFA5',1),('website','Netflix','Netflix','https://www.netflix.com','#E50914',2),('website','Disney+','Disney+','https://www.disneyplus.com','#2543B3',3),('website','Prime Video','Prime Video','https://www.primevideo.com','#0078D4',4),('website','Twitch','Twitch','https://www.twitch.tv','#9146FF',5);
insert into public.playlists(name_ar,name_en,description) values('ريلاكس','Relax','أضف المقاطع المرخصة لهذه القائمة'),('إسلامية','Islamic','القرآن الكريم والمحتوى الإسلامي'),('القرآن الكريم','Holy Quran','قائمة مخصصة لتلاوات القرآن الكريم');
insert into public.app_updates(title_ar,title_en,body_ar,body_en) values ('أهلاً بك في WudCar 1.1.1','Welcome to WudCar 1.1.1','ثيماتك ومواقعك والبث المباشر، في تجربة واحدة.','Your themes, websites and live streams, together.');
update public.themes set description_ar='بين الصحراء والمستقبل، رفيق لكل أوقات مشوارك.',description_en='Desert calm meets the future, throughout your journey.',widgets='{"clock":true,"date":true,"greeting":true,"weather":true,"prayer":true,"adhkar":true,"music":true,"allow_move":true,"allow_resize":true}',music_mode='all',thumbnail_path='https://wudcar.netlify.app/media/ultrawide/sunset.png' where id='spirit-of-the-uae';
update public.app_settings set value=value||'{"minimum_version":"1.1.1","greeting_ar":"مرحباً","greeting_en":"Welcome","monthly_intro_aed":8,"intro_months":2,"monthly_aed":18,"annual_aed":null,"refresh_seconds":60,"widget_defaults":{"clock":true,"weather":true,"prayer":true,"music":false,"adhkar":true},"subscriptions_enabled":false,"trial_enabled":false}';
commit;
