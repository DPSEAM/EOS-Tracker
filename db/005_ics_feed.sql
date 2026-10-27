-- 005_ics_feed.sql  (task #975: private calendar link for Google Calendar, Apple Calendar and Outlook)
-- Run once in the Supabase SQL editor. Safe to run again.
-- Adds one secret token per person and two functions:
--   eos_ics_token(reset)  : the signed-in person gets (or resets) their own token. Called by the app.
--   eos_ics_feed(token)   : returns that person's meetings, tasks and work orders as JSON. Only the
--                           eos-ics Edge Function (service role) can call it; the link itself is the secret.
-- people is not readable by the app's roles, so the token never leaves through a view.

alter table public.people add column if not exists ics_token text;
create unique index if not exists people_ics_token_key on public.people (ics_token) where ics_token is not null;

create or replace function public.eos_ics_token(p_reset boolean default false)
returns text language plpgsql security definer set search_path = public as $$
declare pid uuid := eos_person_id(); t text;
begin
  if pid is null then raise exception 'Sign in to use the calendar link'; end if;
  select ics_token into t from people where id = pid;
  if t is null or coalesce(p_reset, false) then
    t := replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', '');
    perform set_config('eos.via', 'app', true);
    update people set ics_token = t where id = pid;
    perform set_config('eos.via', '', true);
  end if;
  return t;
end $$;
revoke all on function public.eos_ics_token(boolean) from public, anon;
grant execute on function public.eos_ics_token(boolean) to authenticated;

create or replace function public.eos_ics_feed(p_token text)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare me people%rowtype;
begin
  if p_token is null or length(p_token) < 32 then return null; end if;
  select * into me from people where ics_token = p_token and login_enabled and not coalesce(inactive, false);
  if me.id is null then return null; end if;
  return jsonb_build_object(
    'name', me.full_name,
    'meetings', (select coalesce(jsonb_agg(jsonb_build_object('id', m.id, 'title', m.title, 'scheduled_at', m.scheduled_at, 'ends_at', m.ends_at,
                  'cadence', m.cadence, 'location', m.location, 'purpose', m.purpose, 'status', m.status)), '[]'::jsonb)
                 from meetings m
                 where me.id = any(m.attendee_ids) and coalesce(m.status, '') not in ('cancelled', 'canceled')
                   and (m.scheduled_at > now() - interval '120 days' or m.cadence in ('weekly', 'biweekly', 'bi-weekly', 'monthly'))),
    'tasks', (select coalesce(jsonb_agg(jsonb_build_object('id', t.id, 'ref', lpad(t.task_number::text, 5, '0'), 'title', t.title, 'status', t.status,
                  'due_date', t.due_date, 'start_date', t.start_date, 'stop_date', t.stop_date)), '[]'::jsonb)
              from tasks t
              where me.id = any(t.labor_ids) and t.status not in ('Completed', 'Canceled')
                and (t.due_date is not null or t.start_date is not null or t.stop_date is not null)),
    'workorders', (select coalesce(jsonb_agg(jsonb_build_object('id', w.id, 'title', w.project_name, 'status', w.status,
                  'start_date', w.start_date, 'stop_date', w.stop_date)), '[]'::jsonb)
                   from work_orders w
                   where (w.lead_worker_id = me.id or w.owner_id = me.id) and w.status not in ('Completed', 'Canceled')
                     and (w.start_date is not null or w.stop_date is not null)));
end $$;
revoke all on function public.eos_ics_feed(text) from public, anon, authenticated;
grant execute on function public.eos_ics_feed(text) to service_role;
