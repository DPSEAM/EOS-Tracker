-- 007: page error log and backup report (P11: tasks #1040 #1042).  Run once in the Supabase SQL editor; safe to run again.
-- Approved by Sam in the build plan: new table page_errors.
--
-- page_errors        every JavaScript error the app catches on someone's screen (message, stack, page, build, device), rate-limited to 30 per person per hour.
-- eos_log_error()    the app writes through this function; nobody can read or write the table directly.
-- eos_page_errors()  level 6: errors grouped by message for System Health.
-- eos_backup_report() level 6: the backup schemas in this database, and the live row counts next to the latest EOS backup
--                     (a read-only "can we still read it, and does it match" rehearsal for System Health).

create table if not exists public.page_errors (
  id bigint generated always as identity primary key,
  at timestamptz not null default now(),
  person_id uuid,
  build text,
  route text,
  message text not null,
  stack text,
  user_agent text
);
create index if not exists page_errors_at_idx on public.page_errors (at desc);
alter table public.page_errors enable row level security;
revoke all on public.page_errors from anon, authenticated;
grant all on public.page_errors to service_role;      -- Data API change (Oct 30 2026): explicit grants; the app uses the functions below

create or replace function public.eos_log_error(p_message text, p_stack text, p_route text, p_build text, p_ua text) returns void
language plpgsql security definer set search_path = public as $$
declare me uuid;
begin
  if auth.uid() is null then return; end if;
  select id into me from public.people where auth_user_id = auth.uid() limit 1;
  if (select count(*) from public.page_errors where person_id is not distinct from me and at > now() - interval '1 hour') >= 30 then return; end if;
  insert into public.page_errors (person_id, build, route, message, stack, user_agent)
  values (me, left(p_build, 40), left(p_route, 200), left(coalesce(nullif(btrim(p_message), ''), '(no message)'), 500), left(p_stack, 3000), left(p_ua, 300));
end $$;

create or replace function public.eos_page_errors(p_days int default 7) returns jsonb
language plpgsql security definer set search_path = public as $$
begin
  if coalesce(public.eos_level(), 0) < 6 then raise exception 'Page errors are for level 6'; end if;
  return coalesce((select jsonb_agg(to_jsonb(x) order by x.last_at desc) from (
    select e.message, count(*)::int as n, count(distinct e.person_id)::int as people, max(e.at) as last_at, min(e.at) as first_at,
           (array_agg(e.route order by e.at desc))[1] as route, (array_agg(e.build order by e.at desc))[1] as build,
           (array_agg(e.stack order by e.at desc))[1] as stack, (array_agg(e.user_agent order by e.at desc))[1] as user_agent
      from public.page_errors e where e.at > now() - make_interval(days => greatest(1, least(p_days, 90)))
     group by e.message limit 200) x), '[]'::jsonb);
end $$;

create or replace function public.eos_backup_report() returns jsonb
language plpgsql security definer set search_path = public as $$
declare s record; t record; schemas jsonb := '[]'; cmp jsonb := '[]'; latest text; n int; r bigint; a bigint; b bigint;
begin
  if coalesce(public.eos_level(), 0) < 6 then raise exception 'The backup report is for level 6'; end if;
  for s in select nspname::text as nspname, oid from pg_namespace where nspname like 'eos\_backup\_%' or nspname like 'backup\_%' order by nspname loop
    select count(*)::int, coalesce(sum(greatest(c.reltuples, 0)), 0)::bigint into n, r from pg_class c where c.relnamespace = s.oid and c.relkind = 'r';
    schemas := schemas || jsonb_build_object('schema', s.nspname, 'tables', n, 'rows', r);
  end loop;
  select nspname::text into latest from pg_namespace where nspname like 'eos\_backup\_2%' order by nspname desc limit 1;
  if latest is not null then
    for t in select c.relname::text as relname from pg_class c
              where c.relnamespace = (select oid from pg_namespace where nspname = latest) and c.relkind = 'r' and c.reltuples < 500000
                and exists (select 1 from pg_class p where p.relnamespace = 'public'::regnamespace and p.relname = c.relname and p.relkind = 'r' and p.reltuples < 500000)
              order by c.relname loop
      execute format('select count(*) from %I.%I', latest, t.relname) into a;
      execute format('select count(*) from public.%I', t.relname) into b;
      cmp := cmp || jsonb_build_object('table', t.relname, 'backup', a, 'live', b);
    end loop;
  end if;
  return jsonb_build_object('schemas', schemas, 'latest', latest, 'compare', cmp, 'checked_at', now());
end $$;

revoke all on function public.eos_log_error(text, text, text, text, text), public.eos_page_errors(int), public.eos_backup_report() from public, anon;
grant execute on function public.eos_log_error(text, text, text, text, text), public.eos_page_errors(int), public.eos_backup_report() to authenticated;
