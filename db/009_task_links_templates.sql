-- 009 · #1044 task dependencies, #1043 recurring tasks and templates.
-- Approved by Sam as part of P14: new tables task_dependencies and task_templates.
--   task_dependencies  "task A is blocked by task B" (no loops allowed); shown on the task page and on the Needs attention card.
--   task_templates     a saved task (title, instructions, work order or project, people, priority). Optionally repeats every N days / weeks / months / years.
--   eos_templates_run  creates the tasks for every repeating template that is due (one task per template per run, then moves its next date forward).
--                      The app calls it once a day when a level 4+ person opens EOS, and there is a Run now button.
-- Safe to run twice. Run after 008.
begin;
select set_config('eos.via', 'admin', true);   -- 006 guards view_defs: changes from the SQL editor must say they are an administrator

create table if not exists public.task_dependencies (
  task_id uuid not null references public.tasks(id) on delete cascade,
  blocked_by_id uuid not null references public.tasks(id) on delete cascade,
  created_by uuid references public.people(id) on delete set null,
  created_at timestamptz not null default now(),
  primary key (task_id, blocked_by_id),
  check (task_id <> blocked_by_id)
);
create index if not exists task_dependencies_blocker on public.task_dependencies (blocked_by_id);

create table if not exists public.task_templates (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  title text not null,
  instructions text,
  priority text,
  department text,
  work_order_id uuid references public.work_orders(id) on delete set null,
  project_id uuid references public.projects(id) on delete set null,
  labor_ids uuid[] not null default '{}',
  due_in_days int check (due_in_days is null or due_in_days between 0 and 3650),
  every_n int check (every_n is null or every_n between 1 and 366),
  unit text check (unit is null or unit in ('day','week','month','year')),
  next_due date,                                   -- the date the next task is created (its due date is next_due + due_in_days)
  active boolean not null default true,
  last_run date,
  created_by uuid references public.people(id) on delete set null,
  created_at timestamptz not null default now(),
  check ((every_n is null) = (unit is null))
);
alter table public.task_dependencies enable row level security;
alter table public.task_templates enable row level security;
revoke all on public.task_dependencies, public.task_templates from anon, authenticated;
grant all on public.task_dependencies, public.task_templates to service_role;     -- Data API change (Oct 30 2026)

-- ── dependencies ──
create or replace function public.task_dep_add(p_task uuid, p_blocker uuid) returns void
language plpgsql security definer set search_path to 'public' as $$
begin
  if not coalesce(public.eos_can_edit(), false) then raise exception 'You cannot edit tasks'; end if;
  if p_task = p_blocker then raise exception 'A task cannot wait on itself'; end if;
  if not exists (select 1 from public.v_task_tracker where id = p_task) or not exists (select 1 from public.v_task_tracker where id = p_blocker) then
    raise exception 'Task not found or not visible to you'; end if;
  -- no loops: the blocker must not (directly or through others) already wait on this task
  if exists (with recursive up as (select blocked_by_id as id from public.task_dependencies where task_id = p_blocker
                                   union select d.blocked_by_id from public.task_dependencies d join up on d.task_id = up.id)
             select 1 from up where id = p_task) then raise exception 'That would make a loop: the other task already waits on this one'; end if;
  insert into public.task_dependencies (task_id, blocked_by_id, created_by) values (p_task, p_blocker, public.eos_person_id()) on conflict do nothing;
end $$;

create or replace function public.task_dep_remove(p_task uuid, p_blocker uuid) returns void
language plpgsql security definer set search_path to 'public' as $$
begin
  if not coalesce(public.eos_can_edit(), false) then raise exception 'You cannot edit tasks'; end if;
  delete from public.task_dependencies where task_id = p_task and blocked_by_id = p_blocker;
end $$;

-- ── templates ──
create or replace function public.tpl_save(p_id uuid, p_data jsonb) returns uuid
language plpgsql security definer set search_path to 'public' as $$
declare me uuid := public.eos_person_id(); nid uuid := p_id; en int; un text; nd date; labs uuid[];
begin
  if coalesce(public.eos_level(), 0) < 4 then raise exception 'Templates are for level 4 and up'; end if;
  if btrim(coalesce(p_data->>'name', '')) = '' or btrim(coalesce(p_data->>'title', '')) = '' then raise exception 'A template needs a name and a task title'; end if;
  en := nullif(p_data->>'every_n', '')::int; un := nullif(p_data->>'unit', ''); nd := nullif(p_data->>'next_due', '')::date;
  if (en is null) <> (un is null) then raise exception 'Choose both how many and the unit, or leave both empty for a one-off template'; end if;
  if en is not null and nd is null then nd := current_date; end if;
  select coalesce(array_agg(x::uuid), '{}') into labs from jsonb_array_elements_text(coalesce(p_data->'labor_ids', '[]'::jsonb)) x;
  if p_id is null then
    insert into public.task_templates (name, title, instructions, priority, department, work_order_id, project_id, labor_ids, due_in_days, every_n, unit, next_due, active, created_by)
    values (left(btrim(p_data->>'name'), 120), left(btrim(p_data->>'title'), 300), nullif(p_data->>'instructions', ''), nullif(p_data->>'priority', ''), nullif(p_data->>'department', ''),
            nullif(p_data->>'work_order_id', '')::uuid, nullif(p_data->>'project_id', '')::uuid, labs, nullif(p_data->>'due_in_days', '')::int, en, un, nd,
            coalesce((p_data->>'active')::boolean, true), me) returning id into nid;
  else
    update public.task_templates set name = left(btrim(p_data->>'name'), 120), title = left(btrim(p_data->>'title'), 300), instructions = nullif(p_data->>'instructions', ''),
           priority = nullif(p_data->>'priority', ''), department = nullif(p_data->>'department', ''), work_order_id = nullif(p_data->>'work_order_id', '')::uuid,
           project_id = nullif(p_data->>'project_id', '')::uuid, labor_ids = labs, due_in_days = nullif(p_data->>'due_in_days', '')::int, every_n = en, unit = un, next_due = nd,
           active = coalesce((p_data->>'active')::boolean, true)
     where id = p_id;
    if not found then raise exception 'Template not found'; end if;
  end if;
  return nid;
end $$;

create or replace function public.tpl_delete(p_id uuid) returns void
language plpgsql security definer set search_path to 'public' as $$
begin
  if coalesce(public.eos_level(), 0) < 4 then raise exception 'Templates are for level 4 and up'; end if;
  delete from public.task_templates where id = p_id;
end $$;

-- make one task from a template (used by "Create task" and by the repeat run); returns the new task's id
create or replace function public.tpl_make_task(p_id uuid, p_due date default null) returns uuid
language plpgsql security definer set search_path to 'public' as $$
declare t public.task_templates; r jsonb; nid uuid; vals jsonb;
begin
  if coalesce(public.eos_level(), 0) < 4 then raise exception 'Templates are for level 4 and up'; end if;
  select * into t from public.task_templates where id = p_id;
  if not found then raise exception 'Template not found'; end if;
  vals := jsonb_strip_nulls(jsonb_build_object('title', t.title, 'instructions', t.instructions, 'status', 'Planned', 'priority', t.priority, 'department', t.department,
            'work_order_id', t.work_order_id, 'project_id', t.project_id,
            'labor_ids', case when cardinality(t.labor_ids) > 0 then to_jsonb(t.labor_ids) end,
            'due_date', coalesce(p_due, case when t.due_in_days is not null then current_date + t.due_in_days end)));
  r := public.eos_create('tasks', vals);
  nid := (r->>'id')::uuid;
  return nid;
end $$;

create or replace function public.eos_templates_run() returns int
language plpgsql security definer set search_path to 'public' as $$
declare t record; n int := 0; nxt date; step interval;
begin
  if coalesce(public.eos_level(), 0) < 4 then return 0; end if;
  for t in select * from public.task_templates where active and every_n is not null and next_due <= current_date order by next_due for update loop
    perform public.tpl_make_task(t.id, case when t.due_in_days is not null then t.next_due + t.due_in_days end);
    step := make_interval(days => case t.unit when 'day' then t.every_n when 'week' then 7 * t.every_n else 0 end,
                          months => case t.unit when 'month' then t.every_n when 'year' then 12 * t.every_n else 0 end);
    nxt := t.next_due;
    loop nxt := (nxt + step)::date; exit when nxt > current_date; end loop;      -- skip any missed periods instead of creating a pile of tasks
    update public.task_templates set next_due = nxt, last_run = current_date where id = t.id;
    n := n + 1;
  end loop;
  return n;
end $$;

revoke all on function public.task_dep_add(uuid, uuid), public.task_dep_remove(uuid, uuid), public.tpl_save(uuid, jsonb), public.tpl_delete(uuid),
                       public.tpl_make_task(uuid, date), public.eos_templates_run() from public, anon;
grant execute on function public.task_dep_add(uuid, uuid), public.task_dep_remove(uuid, uuid), public.tpl_save(uuid, jsonb), public.tpl_delete(uuid),
                          public.tpl_make_task(uuid, date), public.eos_templates_run() to authenticated;

-- ── views ──
insert into public.view_defs (view_name, base_sql, min_level, row_filter, description) values
('v_task_dependencies', $v$
 SELECT d.task_id, d.blocked_by_id, b.task_id AS blocker_ref, b.title AS blocker_title, b.status AS blocker_status, b.due_date AS blocker_due
   FROM task_dependencies d
   JOIN v_task_tracker a ON a.id = d.task_id
   JOIN v_task_tracker b ON b.id = d.blocked_by_id
$v$, 1, null, 'Which task waits on which (only pairs you can see).'),
('v_task_templates', $v$
 SELECT t.id, t.name, t.title, t.instructions, t.priority, t.department, t.work_order_id, t.project_id, t.labor_ids, t.due_in_days, t.every_n, t.unit,
        t.next_due, t.active, t.last_run, t.created_at,
        (SELECT array_agg(p.full_name ORDER BY p.full_name) FROM people p WHERE p.id = ANY (t.labor_ids)) AS labor_names
   FROM task_templates t
$v$, 4, null, 'Task templates and repeating tasks (level 4 and up).')
on conflict (view_name) do update set base_sql = excluded.base_sql, min_level = excluded.min_level, description = excluded.description, updated_at = now();
select public.rebuild_views();
commit;
