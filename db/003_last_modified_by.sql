-- 003 · #1318 "Last modified by" on tasks and work orders (matches OpenGov: Entered By / Last Modified / Last Modified By)
-- What it does, in one transaction:
--   1. BACKUP: copies tasks, work_orders and view_defs into schema backup_p4 (drop the schema when you are happy: drop schema backup_p4 cascade).
--   2. Adds last_modified_by_id (person) and last_modified_by_name (text, for names read from OpenGov or "EOS email ingest") to tasks and work_orders.
--   3. A BEFORE UPDATE trigger stamps the signed-in person on every edit made through the app, and "EOS email ingest" when
--      the email ingest changes a tracked field. A name set explicitly (the OpenGov sync, read only) is kept as sent.
--   4. Backfills each record from its latest entry in record_changes (app edits -> that person; ingest -> "EOS email ingest").
--      Records never changed since they were loaded stay blank until OpenGov sync supplies Last Modified By.
--   5. Adds last_modified_by (name) and last_modified_by_id to v_task_tracker and v_work_orders at the END of the column list, then rebuild_views().
-- Safe to run twice.
begin;

create schema if not exists backup_p4;
create table if not exists backup_p4.tasks_20261025 as select * from public.tasks;
create table if not exists backup_p4.work_orders_20261025 as select * from public.work_orders;
create table if not exists backup_p4.view_defs_20261025 as select * from public.view_defs;
revoke all on schema backup_p4 from anon, authenticated;

alter table public.tasks       add column if not exists last_modified_by_id uuid references public.people(id) on delete set null;
alter table public.tasks       add column if not exists last_modified_by_name text;
alter table public.work_orders add column if not exists last_modified_by_id uuid references public.people(id) on delete set null;
alter table public.work_orders add column if not exists last_modified_by_name text;

create or replace function public.eos_stamp_modified_by() returns trigger
language plpgsql security definer set search_path to 'public' as $$
declare me uuid; nm text; o jsonb; n jsonb; f text; flds text[]; changed boolean := false;
begin
  if coalesce(current_setting('eos.via', true), '') = 'app' then
    select p.id, p.full_name into me, nm from people p where p.auth_user_id = auth.uid() limit 1;
    if me is not null then new.last_modified_by_id := me; new.last_modified_by_name := nm; end if;
    return new;
  end if;
  -- set explicitly in this statement (OpenGov sync): keep it
  if new.last_modified_by_name is distinct from old.last_modified_by_name or new.last_modified_by_id is distinct from old.last_modified_by_id then
    if new.last_modified_by_id is not distinct from old.last_modified_by_id then new.last_modified_by_id := null; end if;   -- a name sent alone replaces the person link
    return new;
  end if;
  if tg_table_name = 'tasks' then
    flds := array['status','priority','due_date','start_date','start_date_actual','stop_date','stop_date_actual','work_order_id','labor_ids','title','instructions',
                  'notes','context','next_steps','waiting_on','key_details','tags','requested_by_id'];
  else
    flds := array['status','priority','project_name','description','lead_worker_id','start_date','stop_date','progress_phase',
                  'contractor_name','notes','next_steps','waiting_on','key_details','tags','project_id'];
  end if;
  o := to_jsonb(old); n := to_jsonb(new);
  foreach f in array flds loop
    if (n->f) is distinct from (o->f) then changed := true; exit; end if;
  end loop;
  if changed then new.last_modified_by_id := null; new.last_modified_by_name := 'EOS email ingest'; end if;
  return new;
end $$;

drop trigger if exists tasks_modified_by on public.tasks;
create trigger tasks_modified_by before update on public.tasks for each row execute function public.eos_stamp_modified_by();
drop trigger if exists work_orders_modified_by on public.work_orders;
create trigger work_orders_modified_by before update on public.work_orders for each row execute function public.eos_stamp_modified_by();

-- backfill without firing the other triggers (last_modified must not move)
alter table public.tasks disable trigger user;
alter table public.work_orders disable trigger user;
update public.tasks t set last_modified_by_id = x.actor_id,
       last_modified_by_name = case when x.actor_id is not null then (select full_name from people where id = x.actor_id) else 'EOS email ingest' end
  from (select distinct on (record_id) record_id, actor_id, source from public.record_changes where table_name = 'tasks' order by record_id, at desc, id desc) x
 where t.id = x.record_id and t.last_modified_by_name is null and t.last_modified_by_id is null and (x.actor_id is not null or x.source = 'ingest');
update public.work_orders w set last_modified_by_id = x.actor_id,
       last_modified_by_name = case when x.actor_id is not null then (select full_name from people where id = x.actor_id) else 'EOS email ingest' end
  from (select distinct on (record_id) record_id, actor_id, source from public.record_changes where table_name = 'work_orders' order by record_id, at desc, id desc) x
 where w.id = x.record_id and w.last_modified_by_name is null and w.last_modified_by_id is null and (x.actor_id is not null or x.source = 'ingest');
alter table public.tasks enable trigger user;
alter table public.work_orders enable trigger user;

-- views: wrap the saved definition so the two new columns land at the end
update public.view_defs set updated_at = now(), base_sql =
  'SELECT s.*, x.last_modified_by_id, COALESCE(p.full_name, x.last_modified_by_name) AS last_modified_by FROM (' || base_sql || ') s LEFT JOIN tasks x ON x.id = s.id LEFT JOIN people p ON p.id = x.last_modified_by_id'
 where view_name = 'v_task_tracker' and position('last_modified_by' in base_sql) = 0;
update public.view_defs set updated_at = now(), base_sql =
  'SELECT s.*, x.last_modified_by_id, COALESCE(p.full_name, x.last_modified_by_name) AS last_modified_by FROM (' || base_sql || ') s LEFT JOIN work_orders x ON x.id = s.id LEFT JOIN people p ON p.id = x.last_modified_by_id'
 where view_name = 'v_work_orders' and position('last_modified_by' in base_sql) = 0;
select public.rebuild_views();
commit;
