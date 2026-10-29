-- 015 · Notifications (v191). A bell in the header and a Home card: messages, work put on you, notes on your tasks,
-- requests, work packages, your tasks marked done, and a weekday morning "Today" line.
-- Rows are written by triggers as things happen; the app reads v_notifications and marks them seen / read.
-- Safe to run twice.
begin;
select set_config('eos.via', 'admin', true);

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  person_id uuid not null references public.people(id) on delete cascade,
  kind text not null,                 -- message, assigned, note, done, request, package, today
  title text not null,
  body text,
  record_table text,
  record_id uuid,
  actor_id uuid references public.people(id) on delete set null,
  created_at timestamptz not null default now(),
  seen_at timestamptz,                -- the bell badge counts rows with no seen_at
  read_at timestamptz                 -- bold until read
);
create index if not exists notifications_person_idx on public.notifications(person_id, created_at desc);
create index if not exists notifications_unseen_idx on public.notifications(person_id) where seen_at is null;
alter table public.notifications enable row level security;
revoke all on public.notifications from anon, authenticated;
alter table public.people add column if not exists notify_muted text[] not null default '{}';

-- One unread row per person + kind + record: a second event on the same record refreshes it instead of piling up.
create or replace function public.notif_add(p_person uuid, p_kind text, p_title text, p_body text, p_table text, p_id uuid, p_actor uuid default null)
returns void language plpgsql security definer set search_path to 'public' as $function$
declare ok boolean; existing uuid;
begin
  if p_person is null or p_person = p_actor then return; end if;
  select login_enabled and not coalesce(inactive, false) and not (p_kind = any(coalesce(notify_muted, '{}'))) into ok from people where id = p_person;
  if not coalesce(ok, false) then return; end if;
  if p_id is not null then
    select id into existing from notifications where person_id = p_person and kind = p_kind and record_id = p_id and read_at is null order by created_at desc limit 1;
  end if;
  if existing is not null then
    update notifications set title = p_title, body = p_body, actor_id = coalesce(p_actor, actor_id), created_at = now(), seen_at = null where id = existing;
  else
    insert into notifications (person_id, kind, title, body, record_table, record_id, actor_id) values (p_person, p_kind, left(p_title, 200), left(p_body, 300), p_table, p_id, p_actor);
  end if;
end $function$;

create or replace function public.notif_name(p_person uuid) returns text language sql stable security definer set search_path to 'public' as $$
  select coalesce((select full_name from people where id = p_person), 'Someone')
$$;

-- Messages: everyone else in the conversation
create or replace function public.trg_notif_message() returns trigger language plpgsql security definer set search_path to 'public' as $function$
declare c record; m uuid; who text;
begin
  select * into c from msg_conversations where id = new.conversation_id;
  who := notif_name(new.sender_id);
  for m in select person_id from msg_members where conversation_id = new.conversation_id and person_id <> new.sender_id loop
    perform notif_add(m, 'message', case when c.kind = 'dm' or c.title is null then who || ' sent you a message' else who || ' in ' || c.title end,
                      left(new.body, 160), 'messages', new.conversation_id, new.sender_id);
  end loop;
  return null;
exception when others then return null;
end $function$;
drop trigger if exists zz_notif_message on public.msg_messages;
create trigger zz_notif_message after insert on public.msg_messages for each row execute function public.trg_notif_message();

-- Tasks: put on a task, and a task you asked for is done
create or replace function public.trg_notif_task() returns trigger language plpgsql security definer set search_path to 'public' as $function$
declare me uuid := eos_person_id(); ref text; ttl text; p uuid; byname text;
begin
  ref := eos_task_ref(new.task_number); ttl := coalesce(nullif(new.title, ''), left(new.instructions, 90), 'task');
  byname := coalesce(notif_name(me), nullif(new.last_modified_by_name, ''), 'EOS');
  for p in select unnest(coalesce(new.labor_ids, '{}')) except select unnest(coalesce(case when tg_op = 'UPDATE' then old.labor_ids end, '{}')) loop
    perform notif_add(p, 'assigned', 'You were put on ' || ref || ' ' || ttl, case when me is not null then 'By ' || byname else case when new.due_date is not null then 'Due ' || to_char(new.due_date, 'Mon FMDD') end end, 'tasks', new.id, me);
  end loop;
  if tg_op = 'UPDATE' and new.status = 'Completed' and old.status is distinct from 'Completed' then
    perform notif_add(new.requested_by_id, 'done', ref || ' ' || ttl || ' is done', 'Marked done by ' || byname, 'tasks', new.id, me);
    for p in select unnest(coalesce(new.labor_ids, '{}')) loop
      if p is distinct from new.requested_by_id then perform notif_add(p, 'done', ref || ' ' || ttl || ' is done', 'Marked done by ' || byname, 'tasks', new.id, me); end if;
    end loop;
  end if;
  return null;
exception when others then return null;
end $function$;
drop trigger if exists zz_notif_task on public.tasks;
create trigger zz_notif_task after insert or update of labor_ids, status on public.tasks for each row execute function public.trg_notif_task();

-- Notes: the people on the task (or the work order's lead and owner)
create or replace function public.trg_notif_note() returns trigger language plpgsql security definer set search_path to 'public' as $function$
declare t record; w record; p uuid; who text;
begin
  who := coalesce(notif_name(new.author_id), case when new.source_email_id is not null then 'An email' else 'EOS' end);
  if new.task_id is not null then
    select id, task_number, title, instructions, labor_ids, requested_by_id into t from tasks where id = new.task_id;
    for p in select distinct x from unnest(coalesce(t.labor_ids, '{}') || coalesce(array[t.requested_by_id], '{}')) x where x is not null loop
      perform notif_add(p, 'note', who || ' added a note on ' || eos_task_ref(t.task_number) || ' ' || coalesce(nullif(t.title,''), left(t.instructions, 80)), left(new.content, 160), 'tasks', t.id, new.author_id);
    end loop;
  elsif new.work_order_id is not null then
    select id, project_name, lead_worker_id, owner_id into w from work_orders where id = new.work_order_id;
    for p in select distinct x from unnest(array[w.lead_worker_id, w.owner_id]) x where x is not null loop
      perform notif_add(p, 'note', who || ' added a note on ' || coalesce(w.project_name, 'a work order'), left(new.content, 160), 'work_orders', w.id, new.author_id);
    end loop;
  end if;
  return null;
exception when others then return null;
end $function$;
drop trigger if exists zz_notif_note on public.notes;
create trigger zz_notif_note after insert on public.notes for each row execute function public.trg_notif_note();

-- Requests: new ones go to level 4 and up; answers go to the requester
create or replace function public.trg_notif_request() returns trigger language plpgsql security definer set search_path to 'public' as $function$
declare p uuid; ref text := 'R-' || lpad(new.request_number::text, 4, '0'); me uuid := eos_person_id();
begin
  if tg_op = 'INSERT' then
    for p in select pp.id from people pp left join roles r on r.id = pp.role_id
              where pp.login_enabled and not coalesce(pp.inactive, false) and coalesce(pp.visibility_level, r.visibility_level, 0) >= 4 and pp.id is distinct from new.requested_by loop
      perform notif_add(p, 'request', 'New request ' || ref || ': ' || new.title, coalesce(notif_name(new.requested_by), 'Someone') || case when new.department is not null then ' · ' || new.department else '' end, 'requests', new.id, new.requested_by);
    end loop;
  elsif new.status is distinct from old.status and new.status in ('accepted','declined','done') then
    perform notif_add(new.requested_by, 'request', 'Your request ' || ref || ' was ' || new.status || ': ' || new.title, coalesce(new.response, ''), 'requests', new.id, coalesce(new.handled_by, me));
  end if;
  return null;
exception when others then return null;
end $function$;
drop trigger if exists zz_notif_request on public.requests;
create trigger zz_notif_request after insert or update of status on public.requests for each row execute function public.trg_notif_request();

-- Work packages: given to you; and the sender hears back
create or replace function public.trg_notif_package() returns trigger language plpgsql security definer set search_path to 'public' as $function$
declare ref text := 'P-' || lpad(new.package_number::text, 4, '0'); me uuid := eos_person_id();
begin
  if tg_op = 'INSERT' then
    perform notif_add(new.assigned_to, 'package', notif_name(new.sent_by) || ' gave you a work package: ' || new.title, coalesce(new.note, ref), 'packages', new.id, new.sent_by);
  elsif new.status is distinct from old.status then
    if new.status in ('accepted','returned','done') then
      perform notif_add(new.sent_by, 'package', notif_name(new.assigned_to) || ' ' || case new.status when 'accepted' then 'accepted' when 'returned' then 'sent back' else 'finished' end || ' ' || ref || ' ' || new.title, coalesce(new.response, ''), 'packages', new.id, new.assigned_to);
    elsif new.status = 'sent' then
      perform notif_add(new.assigned_to, 'package', notif_name(new.sent_by) || ' sent ' || ref || ' again: ' || new.title, coalesce(new.note, ''), 'packages', new.id, new.sent_by);
    elsif new.status = 'canceled' then
      perform notif_add(new.assigned_to, 'package', ref || ' ' || new.title || ' was canceled', '', 'packages', new.id, new.sent_by);
    end if;
  end if;
  return null;
exception when others then return null;
end $function$;
drop trigger if exists zz_notif_package on public.work_packages;
create trigger zz_notif_package after insert or update of status on public.work_packages for each row execute function public.trg_notif_package();

-- Weekday morning: one line per person with what today holds
create or replace function public.notif_daily() returns int language plpgsql security definer set search_path to 'public' as $function$
declare p record; n_due int; n_over int; n_mtg int; parts text[]; cnt int := 0; today date := (now() at time zone 'America/New_York')::date;
begin
  for p in select id from people where login_enabled and not coalesce(inactive, false) loop
    select count(*) filter (where due_date = today), count(*) filter (where due_date < today) into n_due, n_over
      from tasks where p.id = any(coalesce(labor_ids, '{}')) and status not in ('Completed','Canceled');
    select count(*) into n_mtg from meetings m where p.id = any(coalesce(m.attendee_ids, '{}')) and (m.scheduled_at at time zone 'America/New_York')::date = today and coalesce(m.status, '') <> 'Canceled';
    if n_due + n_over + n_mtg = 0 then continue; end if;
    parts := '{}';
    if n_due > 0 then parts := parts || (n_due || ' due today'); end if;
    if n_over > 0 then parts := parts || (n_over || ' overdue'); end if;
    if n_mtg > 0 then parts := parts || (n_mtg || ' meeting' || case when n_mtg = 1 then '' else 's' end); end if;
    update notifications set read_at = coalesce(read_at, now()), seen_at = coalesce(seen_at, now()) where person_id = p.id and kind = 'today' and read_at is null;
    perform notif_add(p.id, 'today', 'Today: ' || array_to_string(parts, ', '), to_char(today, 'FMDay, Mon FMDD'), 'home', null, null);
    cnt := cnt + 1;
  end loop;
  return cnt;
end $function$;

-- What the app calls
create or replace function public.notif_mark_seen() returns int language plpgsql security definer set search_path to 'public' as $function$
declare n int; begin
  update notifications set seen_at = now() where person_id = eos_person_id() and seen_at is null; get diagnostics n = row_count; return n;
end $function$;
create or replace function public.notif_mark_read(p_ids uuid[] default null) returns int language plpgsql security definer set search_path to 'public' as $function$
declare n int; begin
  update notifications set read_at = now(), seen_at = coalesce(seen_at, now()) where person_id = eos_person_id() and read_at is null and (p_ids is null or id = any(p_ids));
  get diagnostics n = row_count; return n;
end $function$;
create or replace function public.notif_mute(p_kind text, p_muted boolean) returns text[] language plpgsql security definer set search_path to 'public' as $function$
declare cur text[]; begin
  select coalesce(notify_muted, '{}') into cur from people where id = eos_person_id();
  if p_muted then cur := array(select distinct x from unnest(cur || p_kind) x); else cur := array_remove(cur, p_kind); end if;
  update people set notify_muted = cur where id = eos_person_id();
  return cur;
end $function$;

revoke all on function public.notif_add(uuid,text,text,text,text,uuid,uuid), public.notif_daily(), public.notif_mark_seen(), public.notif_mark_read(uuid[]), public.notif_mute(text,boolean) from public, anon;
grant execute on function public.notif_mark_seen(), public.notif_mark_read(uuid[]), public.notif_mute(text,boolean) to authenticated;

insert into public.view_defs (view_name, base_sql, min_level, row_filter, description)
values ('v_notifications', $$
 SELECT n.id, n.kind, n.title, n.body, n.record_table, n.record_id, n.actor_id, a.full_name AS actor_name, n.created_at, n.seen_at, n.read_at,
        (SELECT coalesce(p.notify_muted, '{}') FROM people p WHERE p.id = n.person_id) AS muted
   FROM notifications n
   LEFT JOIN people a ON a.id = n.actor_id
  WHERE n.person_id = eos_person_id() AND n.created_at > now() - interval '60 days'
$$, 1, null, 'Your notifications from the last 60 days: messages, work put on you, notes, requests, packages, tasks done, the morning Today line.')
on conflict (view_name) do update set base_sql = excluded.base_sql, min_level = excluded.min_level, description = excluded.description, updated_at = now();
select count(*) as views_rebuilt from public.rebuild_views();

update public.settings set value = (select jsonb_agg(x) from (select distinct x from jsonb_array_elements(value || '["notif_mark_seen","notif_mark_read","notif_mute"]'::jsonb) x) s)
 where key = 'rpc_allowlist';

-- weekday mornings, 6:40 Eastern (11:40 UTC in winter, 10:40 in summer; both are before the workday)
select cron.unschedule(jobid) from cron.job where jobname = 'eos-notify-daily';
select cron.schedule('eos-notify-daily', '40 10 * * 1-5', $$select public.notif_daily()$$);

select (select count(*) from pg_trigger where tgname like 'zz_notif_%') as triggers_ready,
       (select count(*) from information_schema.views where table_name = 'v_notifications') as view_ready,
       (select count(*) from cron.job where jobname = 'eos-notify-daily') as morning_job;
commit;
