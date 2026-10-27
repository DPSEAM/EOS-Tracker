-- 010 · #1057 Requests tab: service requests from other departments.
-- Approved by Sam as part of P14: new table requests.
-- Anyone with EOS access can send a request. Level 4 and up triage them (accept = creates a task, decline with a reason, mark done) and see them all;
-- everyone else sees only their own requests and the answer. Nothing is emailed (Gmail is on hold, #1320).
-- Safe to run twice. Run after 009.
begin;
select set_config('eos.via', 'admin', true);   -- 006 guards view_defs: changes from the SQL editor must say they are an administrator

create table if not exists public.requests (
  id uuid primary key default gen_random_uuid(),
  request_number int generated always as identity,
  title text not null check (length(btrim(title)) between 3 and 200),
  description text check (description is null or length(description) <= 4000),
  location_text text,
  department text,
  needed_by date,
  requested_by uuid references public.people(id) on delete set null,
  status text not null default 'new' check (status in ('new','accepted','declined','done')),
  response text,
  task_id uuid references public.tasks(id) on delete set null,
  handled_by uuid references public.people(id) on delete set null,
  handled_at timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists requests_by on public.requests (requested_by, created_at desc);
alter table public.requests enable row level security;
revoke all on public.requests from anon, authenticated;
grant all on public.requests to service_role;     -- Data API change (Oct 30 2026)

create or replace function public.req_submit(p_title text, p_description text, p_department text, p_needed_by date, p_location text) returns uuid
language plpgsql security definer set search_path to 'public' as $$
declare me uuid := public.eos_person_id(); nid uuid;
begin
  if me is null then raise exception 'Sign in with EOS access to send a request'; end if;
  if (select count(*) from public.requests where requested_by = me and created_at > now() - interval '1 day') >= 20 then raise exception 'Up to 20 requests a day'; end if;
  insert into public.requests (title, description, department, needed_by, location_text, requested_by)
  values (btrim(p_title), nullif(btrim(coalesce(p_description, '')), ''), nullif(btrim(coalesce(p_department, '')), ''), p_needed_by, nullif(btrim(coalesce(p_location, '')), ''), me)
  returning id into nid;
  return nid;
end $$;

-- p_action: accept (makes a task), decline (needs a reason), done
create or replace function public.req_triage(p_id uuid, p_action text, p_note text, p_work_order uuid default null) returns uuid
language plpgsql security definer set search_path to 'public' as $$
declare me uuid := public.eos_person_id(); r public.requests; tid uuid; res jsonb; vals jsonb;
begin
  if coalesce(public.eos_level(), 0) < 4 then raise exception 'Requests are handled by level 4 and up'; end if;
  select * into r from public.requests where id = p_id for update;
  if not found then raise exception 'Request not found'; end if;
  if p_action = 'accept' then
    if r.task_id is not null then raise exception 'This request already has a task'; end if;
    vals := jsonb_strip_nulls(jsonb_build_object('title', r.title, 'status', 'Planned', 'work_order_id', p_work_order, 'due_date', r.needed_by, 'requested_by_id', r.requested_by, 'department', r.department,
              'instructions', concat_ws(E'\n', r.description, case when r.location_text is not null then 'Location: ' || r.location_text end, 'Request R-' || lpad(r.request_number::text, 4, '0'))));
    res := public.eos_create('tasks', vals);
    tid := (res->>'id')::uuid;
    update public.requests set status = 'accepted', task_id = tid, response = nullif(btrim(coalesce(p_note, '')), ''), handled_by = me, handled_at = now() where id = p_id;
    return tid;
  elsif p_action = 'decline' then
    if btrim(coalesce(p_note, '')) = '' then raise exception 'Give a reason when declining'; end if;
    update public.requests set status = 'declined', response = btrim(p_note), handled_by = me, handled_at = now() where id = p_id;
  elsif p_action = 'done' then
    update public.requests set status = 'done', response = coalesce(nullif(btrim(coalesce(p_note, '')), ''), response), handled_by = me, handled_at = now() where id = p_id;
  else raise exception 'Unknown action'; end if;
  return r.task_id;
end $$;

revoke all on function public.req_submit(text, text, text, date, text), public.req_triage(uuid, text, text, uuid) from public, anon;
grant execute on function public.req_submit(text, text, text, date, text), public.req_triage(uuid, text, text, uuid) to authenticated;

insert into public.view_defs (view_name, base_sql, min_level, row_filter, description) values
('v_requests', $v$
 SELECT r.id, r.request_number, r.title, r.description, r.location_text, r.department, r.needed_by, r.status, r.response, r.task_id, r.created_at, r.handled_at,
        r.requested_by, rp.full_name AS requested_by_name, hp.full_name AS handled_by_name,
        eos_task_ref(t.task_number) AS task_ref, (r.requested_by = eos_person_id()) AS mine
   FROM requests r
   LEFT JOIN people rp ON rp.id = r.requested_by
   LEFT JOIN people hp ON hp.id = r.handled_by
   LEFT JOIN tasks t ON t.id = r.task_id
  WHERE r.requested_by = eos_person_id() OR eos_level() >= 4
$v$, 1, null, 'Service requests: level 4 and up see all, everyone else their own.')
on conflict (view_name) do update set base_sql = excluded.base_sql, min_level = excluded.min_level, description = excluded.description, updated_at = now();
select public.rebuild_views();
commit;
