begin;
revoke execute on function public.my_permissions(),public.restore_theme(text,integer),public.trial_heartbeat(uuid,uuid,integer,boolean),public.trial_status() from public,anon;
grant execute on function public.my_permissions(),public.restore_theme(text,integer),public.trial_heartbeat(uuid,uuid,integer,boolean),public.trial_status() to authenticated;
do $$begin if to_regprocedure('public.rls_auto_enable()') is not null then execute 'revoke execute on function public.rls_auto_enable() from public,anon,authenticated';end if;end $$;
-- Server-only push tables deliberately have no client policies.
grant all on public.push_devices,public.push_campaigns,public.push_deliveries,public.library_items,public.app_updates,public.user_library to service_role;
commit;
