-- 018 · Device notifications (v195). A person turns them on from the account menu; the browser gives EOS a push
-- subscription, and every notification written for that person is sent to their devices by the eos-push Edge Function.
-- Keys: the public key lives in settings.push, the private key in Vault as eos_vapid_private (never in GitHub).
-- Safe to run twice.
begin;
select set_config('eos.via', 'admin', true);

create table if not exists public.push_subscriptions (
  id uuid primary key default gen_random_uuid(),
  person_id uuid not null references public.people(id) on delete cascade,
  endpoint text not null unique,
  p256dh text not null,
  auth text not null,
  user_agent text,
  created_at timestamptz not null default now(),
  last_sent_at timestamptz,
  failures int not null default 0
);
create index if not exists push_subscriptions_person_idx on public.push_subscriptions(person_id);
alter table public.push_subscriptions enable row level security;
revoke all on public.push_subscriptions from anon, authenticated;

insert into public.settings (key, value, description, min_level)
values ('push', '{"public_key": null, "subject": "mailto:dpseam@beverlyma.gov"}'::jsonb, 'Device notifications: the VAPID public key the browser needs (the private key is in Vault as eos_vapid_private).', 1)
on conflict (key) do nothing;

-- the signed-in person registers or removes one of their devices
create or replace function public.push_subscribe(p_endpoint text, p_p256dh text, p_auth text, p_user_agent text default null) returns uuid
language plpgsql security definer set search_path to 'public' as $function$
declare me uuid := eos_person_id(); sid uuid;
begin
  if me is null then raise exception 'Sign in with EOS access'; end if;
  if coalesce(p_endpoint,'') = '' or coalesce(p_p256dh,'') = '' or coalesce(p_auth,'') = '' then raise exception 'Incomplete subscription'; end if;
  insert into push_subscriptions (person_id, endpoint, p256dh, auth, user_agent) values (me, p_endpoint, p_p256dh, p_auth, left(p_user_agent, 200))
  on conflict (endpoint) do update set person_id = excluded.person_id, p256dh = excluded.p256dh, auth = excluded.auth, user_agent = excluded.user_agent, failures = 0
  returning id into sid;
  return sid;
end $function$;
create or replace function public.push_unsubscribe(p_endpoint text) returns int language plpgsql security definer set search_path to 'public' as $function$
declare n int; begin
  delete from push_subscriptions where endpoint = p_endpoint and person_id = eos_person_id(); get diagnostics n = row_count; return n;
end $function$;
create or replace function public.push_status() returns jsonb language sql stable security definer set search_path to 'public' as $$
  select jsonb_build_object('devices', (select count(*) from push_subscriptions where person_id = eos_person_id()),
                            'public_key', (select value->>'public_key' from settings where key = 'push'))
$$;

-- the Edge Function fetches what to send (cron token) and reports dead subscriptions
create or replace function public.eos_push_fetch(p_token text, p_id uuid) returns jsonb language plpgsql security definer set search_path to 'public','vault' as $function$
declare n record;
begin
  if not eos_check_cron_token(p_token) then return jsonb_build_object('ok', false, 'reason', 'bad_token'); end if;
  select * into n from notifications where id = p_id;
  if n.id is null then return jsonb_build_object('ok', false, 'reason', 'not_found'); end if;
  return jsonb_build_object('ok', true,
    'title', n.title, 'body', n.body, 'kind', n.kind, 'record_table', n.record_table, 'record_id', n.record_id, 'person_id', n.person_id,
    'subject', (select value->>'subject' from settings where key = 'push'),
    'public_key', (select value->>'public_key' from settings where key = 'push'),
    'private_key', (select decrypted_secret from vault.decrypted_secrets where name = 'eos_vapid_private'),
    'subscriptions', coalesce((select jsonb_agg(jsonb_build_object('id', s.id, 'endpoint', s.endpoint, 'p256dh', s.p256dh, 'auth', s.auth)) from push_subscriptions s where s.person_id = n.person_id), '[]'));
end $function$;
create or replace function public.eos_push_result(p_token text, p_sent uuid[], p_gone uuid[]) returns int language plpgsql security definer set search_path to 'public','vault' as $function$
declare n int; begin
  if not eos_check_cron_token(p_token) then raise exception 'bad token'; end if;
  update push_subscriptions set last_sent_at = now(), failures = 0 where id = any(coalesce(p_sent, '{}'));
  delete from push_subscriptions where id = any(coalesce(p_gone, '{}'));
  get diagnostics n = row_count; return n;
end $function$;

-- every notification written or refreshed asks the Edge Function to send it (asynchronous, never blocks the write)
create or replace function public.trg_notif_push() returns trigger language plpgsql security definer set search_path to 'public','vault','net' as $function$
declare tok text;
begin
  if not exists (select 1 from push_subscriptions where person_id = new.person_id) then return null; end if;
  if (select value->>'public_key' from settings where key = 'push') is null then return null; end if;
  select decrypted_secret into tok from vault.decrypted_secrets where name = 'eos_cron_token';
  perform net.http_post(
    url := 'https://llwqcwrkbyniffjnwxym.supabase.co/functions/v1/eos-push',
    headers := jsonb_build_object('Content-Type', 'application/json', 'x-eos-token', coalesce(tok, '')),
    body := jsonb_build_object('id', new.id), timeout_milliseconds := 15000);
  return null;
exception when others then return null;
end $function$;
drop trigger if exists zz_notif_push on public.notifications;
create trigger zz_notif_push after insert or update of created_at on public.notifications for each row execute function public.trg_notif_push();

revoke all on function public.push_subscribe(text,text,text,text), public.push_unsubscribe(text), public.push_status(), public.eos_push_fetch(text,uuid), public.eos_push_result(text,uuid[],uuid[]) from public, anon;
grant execute on function public.push_subscribe(text,text,text,text), public.push_unsubscribe(text), public.push_status() to authenticated;
grant execute on function public.eos_push_fetch(text,uuid), public.eos_push_result(text,uuid[],uuid[]) to service_role;
update public.settings set value = (select jsonb_agg(x) from (select distinct x from jsonb_array_elements(value || '["push_subscribe","push_unsubscribe","push_status"]'::jsonb) x) s)
 where key = 'rpc_allowlist';

select (select count(*) from pg_proc where proname in ('push_subscribe','push_unsubscribe','push_status','eos_push_fetch','eos_push_result')) as functions_ready,
       (select count(*) from pg_trigger where tgname = 'zz_notif_push') as trigger_ready,
       (select value->>'public_key' is not null from public.settings where key = 'push') as public_key_set,
       (select count(*) from vault.secrets where name = 'eos_vapid_private') as private_key_set;
commit;
