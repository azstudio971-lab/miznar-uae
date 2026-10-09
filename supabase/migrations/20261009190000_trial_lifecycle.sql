begin;
-- Account-level serialization also covers restarting an existing paused session.
create or replace function public.trial_heartbeat(p_session uuid,p_device uuid,p_sequence integer,p_active boolean) returns jsonb language plpgsql security definer set search_path='' as $$
declare uid uuid := (select auth.uid());s public.trial_sessions;used integer;delta integer:=0;now_at timestamptz:=clock_timestamp();paid boolean;
begin
 if uid is null or not (select private.account_exists()) then raise exception 'Authentication required';end if;
 if p_sequence is null or p_sequence<1 or p_active is null then raise exception 'Invalid heartbeat';end if;
 if not exists(select 1 from public.devices where id=p_device and user_id=uid and revoked_at is null) then raise exception 'Invalid device';end if;
 if exists(select 1 from public.profiles where user_id=uid and account_status<>'active') then raise exception 'Account unavailable';end if;
 perform pg_advisory_xact_lock(hashtext(uid::text));
 insert into public.trial_accounts(user_id) values(uid) on conflict do nothing;
 select used_seconds into used from public.trial_accounts where user_id=uid for update;
 select exists(select 1 from public.subscription_entitlements where user_id=uid and revoked_at is null and expires_at>now_at and status in ('active','grace_period')) into paid;
 select * into s from public.trial_sessions where id=p_session for update;
 if found then
  if s.user_id<>uid or s.device_id<>p_device or s.closed_at is not null then raise exception 'Invalid session';end if;
  if p_sequence<=s.sequence then
   return jsonb_build_object('used_seconds',used,'remaining_seconds',1800-used,'entitled',paid,'replayed',true,'lease_seconds',case when s.active then greatest(0,least(case when paid then 15 else 1800-used end,15-floor(extract(epoch from now_at-s.last_heartbeat))::integer)) else 0 end);
  end if;
  if p_sequence<>s.sequence+1 then raise exception 'Out of order heartbeat';end if;
  if s.active and not paid then delta:=least(15,greatest(0,floor(extract(epoch from now_at-s.last_heartbeat))::integer));end if;
 else
  if p_sequence<>1 then raise exception 'Session must start at sequence one';end if;
  insert into public.trial_sessions(id,user_id,device_id) values(p_session,uid,p_device);
 end if;
 if p_active and not paid and exists(select 1 from public.trial_sessions where user_id=uid and id<>p_session and active and closed_at is null and last_heartbeat>now_at-interval '15 seconds') then raise exception 'Another device is already using the trial';end if;
 used:=least(1800,used+delta);
 update public.trial_accounts set used_seconds=used,updated_at=now_at where user_id=uid;
 update public.trial_sessions set sequence=p_sequence,active=p_active and (paid or used<1800),last_heartbeat=now_at where id=p_session;
 update public.devices set last_seen_at=now_at where id=p_device;
 update public.profiles set last_active_at=now_at where user_id=uid;
 return jsonb_build_object('used_seconds',used,'remaining_seconds',1800-used,'entitled',paid,'lease_seconds',case when p_active then least(15,case when paid then 15 else 1800-used end) else 0 end);
end $$;
-- Merely opening the subscription screen must never start or reset a trial.
create function public.trial_status() returns jsonb language plpgsql security definer set search_path='' as $$
declare uid uuid := (select auth.uid());used integer;paid boolean;
begin
 if uid is null or not (select private.account_exists()) or exists(select 1 from public.profiles where user_id=uid and account_status<>'active') then raise exception 'Authentication required';end if;
 select coalesce((select used_seconds from public.trial_accounts where user_id=uid),0) into used;
 select exists(select 1 from public.subscription_entitlements where user_id=uid and revoked_at is null and expires_at>clock_timestamp() and status in ('active','grace_period')) into paid;
 return jsonb_build_object('used_seconds',used,'remaining_seconds',1800-used,'entitled',paid,'lease_seconds',0);
end $$;
revoke all on function public.trial_status() from public;grant execute on function public.trial_status() to authenticated;
commit;
