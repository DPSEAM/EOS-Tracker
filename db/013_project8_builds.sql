-- 013 · Project #8 "EOS System Development" restructured by build.
-- One work order per build (W-nnnn "v189 · Work packages"); the tasks under it are the features and fixes in that build.
-- The 14 area work orders become the backlog ("Backlog · Map & GIS"): open work waits there until it is scheduled into a build.
-- Completed tasks are moved into the build that shipped them: first by the task numbers named in the build log,
-- then by completion date, and the rest into "v157 and earlier". Every move is written to record_changes.
-- eos_claim_build becomes the one shipping action: it claims the number, completes the build's work order and its tasks.
-- Data plus one function. Safe to run twice. Nothing is deleted.
begin;
select set_config('eos.via', 'admin', true);

-- ── 1. the backlog ───────────────────────────────────────────────────────────────────────────────
update public.work_orders
   set project_name = 'Backlog · ' || regexp_replace(project_name, '^EOS Dev: ', ''),
       status = 'Planned', tags = (select array_agg(distinct x) from unnest(coalesce(tags,'{}') || '{backlog}') x),
       last_modified = now(), last_modified_by_name = 'db/013'
 where project_id = (select id from public.projects where project_number = 8) and project_name like 'EOS Dev: %';
update public.work_orders
   set project_name = 'Backlog · General', status = 'Planned', tags = (select array_agg(distinct x) from unnest(coalesce(tags,'{}') || '{backlog}') x),
       last_modified = now(), last_modified_by_name = 'db/013'
 where work_order_number = 8 and project_name = 'EOS System Development';

-- ── 2. one work order per released build (titles from CHANGELOG.md, notes and dates from the build log) ──
with p as (select id from public.projects where project_number = 8),
titles(n, title) as (values
 (158,'Menu and Home fixes'),(159,'GIS tab'),(160,'Pavement as a dashboard, Documents map'),(161,'One header on every tab'),
 (162,'Home fixes'),(163,'Bulk upload'),(164,'Assets tab'),(165,'Assets read live from ArcGIS'),(166,'ISO 55001 asset hierarchy'),
 (167,'Search-first Home, Ask AI, Knowledge Base, gadget dashboards'),(168,'Accounts manager'),(169,'One place for roles and levels'),
 (170,'Directory wording, Hide inactive, Logins fix'),(171,'Done button for everyone'),(172,'Directory status, budget load prepared'),
 (173,'Hide inactive on Employees, header search removed'),(174,'Home and Work'),(175,'Pavement Season'),(176,'Budget lines and invoice Pipeline'),
 (177,'Last modified by'),(178,'Messages'),(179,'Org chart and Data quality'),(180,'Search language and departments'),(181,'Calendar'),
 (182,'Ingest guards'),(183,'GIS search, Near me, work order at a point'),(184,'Platform and security'),(185,'Field and iPad'),
 (186,'Home and Work extras'),(187,'Slim header, floating GIS, Home touches')),
log as (select (regexp_match(e->>'build','v(\d+)'))[1]::int n, e->>'note' note, (regexp_match(e->>'build','(\d{4}-\d{2}-\d{2})'))[1]::date d
          from public.settings, jsonb_array_elements(value->'log') e where key = 'deployment')
insert into public.work_orders (project_id, project_name, description, status, start_date, stop_date, tags, priority, entered_by, sync_status, visible_levels, last_modified_by_name)
select p.id, 'v'||t.n||' · '||t.title, l.note, 'Completed', l.d, l.d, '{build}', 'Medium', 'db/013', 'eos_only', '{1,2,3,4,5,6}', 'db/013'
  from titles t join log l on l.n = t.n cross join p
 where not exists (select 1 from public.work_orders w where w.project_id = p.id and w.project_name ~ ('^v'||t.n||'\M'));

-- builds before the log began
insert into public.work_orders (project_id, project_name, description, status, start_date, stop_date, tags, priority, entered_by, sync_status, visible_levels, last_modified_by_name)
select id, 'v157 and earlier · Before the build log', 'Work completed before the build log began on 2026-10-20 (v1 to v157).', 'Completed', date '2026-09-09', date '2026-10-19', '{build}', 'Medium', 'db/013', 'eos_only', '{1,2,3,4,5,6}', 'db/013'
  from public.projects where project_number = 8
   and not exists (select 1 from public.work_orders w where w.project_id = projects.id and w.project_name like 'v157 and earlier%');

-- builds on the test site (numbers already stamped in their files)
insert into public.work_orders (project_id, project_name, description, status, start_date, tags, priority, entered_by, sync_status, visible_levels, last_modified_by_name)
select id, x.name, x.note, 'In Progress', date '2026-10-27', '{build,staging}', 'Medium', 'db/013', 'eos_only', '{1,2,3,4,5,6}', 'db/013'
  from public.projects, (values
   ('v188 · Mini pages, What''s new, Directory', 'Mini pages drag by a grip strip; no blur behind mini pages, Add update or dialogs; What''s new on Home with the full history and a Coming tab; Remove from directory and Restore on the person page.'),
   ('v189 · Work packages', 'Bundle tasks, work orders, projects, people, documents and map points and give them to one person: Packages tab, package page with Done ticks, accept / send back / done, Discuss, Print field sheet, + New › Work package, Add to package from a selected list, Work packages gadget on Home.')
  ) x(name, note)
 where project_number = 8 and not exists (select 1 from public.work_orders w where w.project_id = projects.id and w.project_name = x.name);

-- planned builds, in order (no number until they ship; eos_claim_build gives them one)
insert into public.work_orders (project_id, project_name, description, status, tags, priority, entered_by, sync_status, visible_levels, last_modified_by_name)
select id, x.name, x.note, 'Planned', '{build}', 'Medium', 'db/013', 'eos_only', '{1,2,3,4,5,6}', 'db/013'
  from public.projects, (values
   ('Next · Ask AI hands you the file', 'Ask for a document and the chat opens it, previews it and can quote from it; answers carry document, task and person cards that open the record.'),
   ('Next · Saved AI conversations', 'Conversations saved per person with titles, a history list and search, like Claude and ChatGPT.'),
   ('Next · Roles and permissions manager', 'One place to see and change what each role can see and do; role templates on top of the EOS levels.'),
   ('Next · Budget chart and forecast', 'Spending by date against budget with a projection to June 30; division cards; drill down from budget line to purchase orders, invoices and work.'),
   ('Next · Work tied to assets', 'Link tasks, work orders and requests to GIS assets; work history on the asset; back-fill from existing work; OpenGov activities.'),
   ('Next · GIS symbols by default, rotation, popups', 'Every layer carries a saved symbol set so a new sign-in sees a finished map; symbol rotation by field; popups from ArcGIS Online.'),
   ('Next · Notifications', 'In-app bell for messages, requests, packages and mentions; Realtime delivery; optional email digests.'),
   ('Next · Document collections', 'Group documents into nested collections, shareable by level, with a collections view on records.'),
   ('Next · Invoices from email', 'Invoice emails and PDFs to the EOS mailbox become invoice rows, matched to purchase orders and routed for sign-off.'),
   ('Next · Sign-in screen', 'City imagery, a status line, one-tap sign-in on a trusted device, Request access.'),
   ('Next · CYVL LiDAR and 3D', 'Street-level point cloud from the CYVL drive in a 3D view; plan-to-GIS extraction.')
  ) x(name, note)
 where project_number = 8 and not exists (select 1 from public.work_orders w where w.project_id = projects.id and w.project_name = x.name);

-- ── 3. completed tasks move into the build that shipped them ────────────────────────────────────
-- 3a. by the task numbers named in the build log (the latest build that names a task wins)
with p as (select id from public.projects where project_number = 8),
log as (select (regexp_match(e->>'build','v(\d+)'))[1]::int n, e->>'note' note from public.settings, jsonb_array_elements(value->'log') e where key = 'deployment'),
refs as (select max(n) n, m[1]::int tn from log, regexp_matches(note, '#(\d{2,5})', 'g') m group by m[1]),
mv as (
  update public.tasks t set work_order_id = w.id, last_modified = now(), last_modified_by_name = 'db/013'
    from refs r, public.work_orders w, public.work_orders old, p
   where t.task_number = r.tn and t.status = 'Completed' and w.project_id = p.id and w.project_name ~ ('^v'||r.n||'\M')
     and old.id = t.work_order_id and old.project_id = p.id and 'backlog' = any(old.tags)
  returning t.id, old.id as old_id, w.id as new_id, w.project_name)
insert into public.record_changes (table_name, record_id, field, old_value, new_value, action, source, note)
select 'tasks', id, 'work_order_id', to_jsonb(old_id), to_jsonb(new_id), 'edit', 'admin', 'db/013: moved into build '||project_name||' (named in the build log)' from mv;

-- 3b. by completion date: the last build claimed that day
with p as (select id from public.projects where project_number = 8),
builds as (select id, stop_date, (regexp_match(project_name,'^v(\d+)'))[1]::int n, project_name from public.work_orders where project_id = (select id from p) and 'build' = any(tags) and status = 'Completed' and project_name ~ '^v\d+ ·'),
best as (select distinct on (stop_date) stop_date, id, project_name from builds order by stop_date, n desc),
mv as (
  update public.tasks t set work_order_id = b.id, last_modified = now(), last_modified_by_name = 'db/013'
    from best b, public.work_orders old
   where t.status = 'Completed' and t.stop_date_actual::date = b.stop_date
     and old.id = t.work_order_id and old.project_id = (select id from p) and 'backlog' = any(old.tags)
  returning t.id, old.id as old_id, b.id as new_id, b.project_name)
insert into public.record_changes (table_name, record_id, field, old_value, new_value, action, source, note)
select 'tasks', id, 'work_order_id', to_jsonb(old_id), to_jsonb(new_id), 'edit', 'admin', 'db/013: moved into build '||project_name||' (completed that day)' from mv;

-- 3c. everything else that is complete: before the log
with p as (select id from public.projects where project_number = 8),
early as (select id, project_name from public.work_orders where project_id = (select id from p) and project_name like 'v157 and earlier%'),
mv as (
  update public.tasks t set work_order_id = e.id, last_modified = now(), last_modified_by_name = 'db/013'
    from early e, public.work_orders old
   where t.status = 'Completed' and old.id = t.work_order_id and old.project_id = (select id from p) and 'backlog' = any(old.tags)
  returning t.id, old.id as old_id, e.id as new_id, e.project_name)
insert into public.record_changes (table_name, record_id, field, old_value, new_value, action, source, note)
select 'tasks', id, 'work_order_id', to_jsonb(old_id), to_jsonb(new_id), 'edit', 'admin', 'db/013: moved into '||project_name from mv;

-- ── 4. tasks for the three builds made in this session (one per feature) ─────────────────────────
insert into public.tasks (instructions, title, status, work_order_id, tags, priority, work_type, department, entered_by, sync_status, labor_ids, stop_date_actual, last_modified_by_name)
select x.txt, x.txt, x.st, w.id, x.tags::text[], 'Medium', 'action', 'DPS - Engineering Division', 'db/013', 'eos_only',
       (select array_agg(id) from public.people where email_address = 'dpseam@beverlyma.gov' or full_name = 'Sam Goodwin' limit 1),
       case when x.st = 'Completed' then timestamptz '2026-10-27 12:00-04' end, 'db/013'
  from (values
   ('v187','Slim 48 px header that slides away while scrolling down','Completed','{feature}'),
   ('v187','GIS: no bar; the seal, + New and the account float over a full-screen map','Completed','{feature}'),
   ('v187','iPad: full-height layouts use the visible screen height (Basemap button back on screen)','Completed','{fix}'),
   ('v187','Home status cards no longer clipped by the fixed row','Completed','{fix}'),
   ('v187','Two-step sign-in reminder floats at the bottom instead of inside the header','Completed','{fix}'),
   ('v187','First visit of the day: numbers count up, overdue card pulses; drifting aerial tinted by time of day; Done draws a check mark','Completed','{feature}'),
   ('v188','Mini pages drag by a grip strip across the top, not the whole header','In Progress','{feature}'),
   ('v188','No blur behind mini pages, Add update, edit dialogs or the notepad','In Progress','{fix}'),
   ('v188','What''s new linked from Home, full history and a Coming tab','In Progress','{feature}'),
   ('v188','Remove from directory and Restore on the person page','In Progress','{feature}'),
   ('v189','Packages tab: For me / I sent / Closed / All, search, progress','In Progress','{feature}'),
   ('v189','Package page: items with Done ticks, Accept, Send back, Mark done, Cancel, Send again, Discuss, Print field sheet','In Progress','{feature}'),
   ('v189','+ New › Work package and Add to package… from a selected list','In Progress','{feature}'),
   ('v189','Work packages gadget on Home and a badge on the Packages tab','In Progress','{feature}')
  ) x(b, txt, st, tags)
  join public.work_orders w on w.project_id = (select id from public.projects where project_number = 8) and w.project_name ~ ('^'||x.b||'\M')
 where not exists (select 1 from public.tasks t where t.work_order_id = w.id and t.instructions = x.txt);

-- ── 5. shipping is one action ───────────────────────────────────────────────────────────────────
-- eos_claim_build(note, work_order_number, title, task_numbers): claims the next number and logs it (as before); then the
-- build's work order (the one given, or the one already named vNNN, or a new one) is named "vNNN · title", completed with
-- today's date, the listed tasks are moved under it, and every open task under it is completed. The log is no longer trimmed.
drop function if exists public.eos_claim_build(text);
create or replace function public.eos_claim_build(p_note text, p_wo int default null, p_title text default null, p_tasks int[] default null)
returns jsonb language plpgsql security definer set search_path to 'public' as $$
declare v jsonb; n int; b text; today date := (now() at time zone 'America/New_York')::date; wid uuid; ttl text; p8 uuid;
begin
  select value into v from settings where key = 'deployment' for update;
  n := coalesce(nullif(substring(v->>'build' from 'v(\d+)'), '')::int, 0) + 1;
  b := 'v'||n||' · '||to_char(today, 'YYYY-MM-DD');
  v := jsonb_set(v, '{build}', to_jsonb(b));
  v := jsonb_set(v, '{log}', coalesce(v->'log', '[]'::jsonb) || jsonb_build_array(jsonb_build_object('build', b, 'note', p_note, 'claimed_at', now())));
  update settings set value = v, updated_at = now() where key = 'deployment';
  perform set_config('eos.via', 'admin', true);
  select id into p8 from projects where project_number = 8;
  if p_wo is not null then select id into wid from work_orders where work_order_number = p_wo and project_id = p8; end if;
  if wid is null then select id into wid from work_orders where project_id = p8 and 'build' = any(tags) and project_name ~ ('^v'||n||'\M') limit 1; end if;
  ttl := coalesce(nullif(btrim(p_title), ''), (select regexp_replace(project_name, '^(v\d+ · |Next · )', '') from work_orders where id = wid), left(p_note, 60));
  if wid is null then
    insert into work_orders (project_id, project_name, description, status, start_date, stop_date, tags, priority, entered_by, sync_status, visible_levels, last_modified_by_name)
    values (p8, 'v'||n||' · '||ttl, p_note, 'Completed', today, today, '{build}', 'Medium', 'eos_claim_build', 'eos_only', '{1,2,3,4,5,6}', 'eos_claim_build') returning id into wid;
  else
    update work_orders set project_name = 'v'||n||' · '||ttl, description = coalesce(nullif(p_note, ''), description), status = 'Completed', stop_date = today, start_date = coalesce(start_date, today),
           tags = (select array_agg(distinct x) from unnest(coalesce(tags, '{}') || '{build}') x where x <> 'staging'), visible_levels = '{1,2,3,4,5,6}', last_modified = now(), last_modified_by_name = 'eos_claim_build'
     where id = wid;
  end if;
  if p_tasks is not null then update tasks set work_order_id = wid, last_modified = now(), last_modified_by_name = 'eos_claim_build' where task_number = any(p_tasks); end if;
  update tasks set status = 'Completed', stop_date_actual = coalesce(stop_date_actual, today::timestamptz), last_modified = now(), last_modified_by_name = 'eos_claim_build'
   where work_order_id = wid and status in ('Planned', 'In Progress', 'Projected');
  return jsonb_build_object('build', b, 'number', n, 'work_order', wid, 'tasks', (select count(*) from tasks where work_order_id = wid));
end $$;
revoke all on function public.eos_claim_build(text, int, text, int[]) from public, anon, authenticated;

-- what moved
select w.project_name, w.status, count(t.id) as tasks
  from public.work_orders w left join public.tasks t on t.work_order_id = w.id
 where w.project_id = (select id from public.projects where project_number = 8)
 group by w.work_order_number, w.project_name, w.status order by w.work_order_number;
commit;
