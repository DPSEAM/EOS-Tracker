-- 020 · Work packages, round two (v202): several receivers, reassigning, items in order with notes and photos,
-- ticking a task item can mark the task done (and a task done elsewhere ticks itself), templates for repeat packages,
-- and packages visible from the records they contain. Safe to run twice. Run after 018.
begin;
select set_config('eos.via', 'admin', true);

-- several receivers: assigned_ids holds everyone; assigned_to stays the first of them (older code and the Home card read it)
alter table public.work_packages add column if not exists assigned_ids uuid[] not null default '{}';
update public.work_packages set assigned_ids = array[assigned_to] where cardinality(assigned_ids) = 0;
create index if not exists work_packages_assigned_ids on public.work_packages using gin (assigned_ids);

-- repeat packages
create table if not exists public.wp_templates (
  id uuid primary key default gen_random_uuid(),
  title text not null check (length(btrim(title)) between 3 and 200),
  note text,
  items jsonb not null default '[]',
  assigned_ids uuid[] not null default '{}',
  due_in_days int,
  created_by uuid references public.people(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.wp_templates enable row level security;
revoke all on public.wp_templates from anon, authenticated;
grant all on public.wp_templates to service_role;

-- items keep their order; each can carry a note, a photo (a document) and who ticked it
create or replace function public.wp_clean_items(p_items jsonb) returns jsonb
language plpgsql immutable set search_path to 'public' as $$
declare it jsonb; out jsonb := '[]'; t text;
begin
  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then raise exception 'Add at least one record to the package'; end if;
  if jsonb_array_length(p_items) > 200 then raise exception 'A package can hold up to 200 items'; end if;
  for it in select * from jsonb_array_elements(p_items) loop
    t := it->>'t';
    if t in ('tasks','work_orders','projects','documents','people','assets') then
      if coalesce(it->>'id', '') !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then raise exception 'A package item has no valid record id'; end if;
      out := out || jsonb_build_object('t', t, 'id', it->>'id', 'label', left(coalesce(it->>'label', ''), 200), 'done', false, 'done_at', null, 'done_by', null, 'note', nullif(left(coalesce(it->>'note',''), 1000), ''), 'photo_doc_id', null);
    elsif t = 'point' then
      if (it->>'lat') is null or (it->>'lng') is null then raise exception 'A map point needs a latitude and longitude'; end if;
      out := out || jsonb_build_object('t', 'point', 'lat', (it->>'lat')::numeric, 'lng', (it->>'lng')::numeric, 'label', left(coalesce(it->>'label', ''), 200), 'done', false, 'done_at', null, 'done_by', null, 'note', nullif(left(coalesce(it->>'note',''), 1000), ''), 'photo_doc_id', null);
    else raise exception 'Unknown package item: %', coalesce(t, '(none)'); end if;
  end loop;
  return out;
end $$;

-- the people who can receive a package: EOS users who are not the sender
create or replace function public.wp_receivers(p_ids uuid[], p_me uuid) returns uuid[] language sql stable security definer set search_path to 'public' as $$
  select coalesce(array_agg(distinct p.id), '{}') from unnest(coalesce(p_ids, '{}')) x(id) join people p on p.id = x.id
   where p.login_enabled and not coalesce(p.inactive, false) and p.id is distinct from p_me
$$;

drop function if exists public.wp_send(text, text, uuid, date, jsonb);
create or replace function public.wp_send(p_title text, p_note text, p_assigned_to uuid, p_due date, p_items jsonb, p_assigned_ids uuid[] default null) returns uuid
language plpgsql security definer set search_path to 'public' as $$
declare me uuid := public.eos_person_id(); nid uuid; who uuid[];
begin
  if me is null then raise exception 'Sign in with EOS access to send a work package'; end if;
  perform eos_require('packages.send');
  who := wp_receivers(coalesce(p_assigned_ids, array[p_assigned_to]), me);
  if cardinality(who) = 0 then raise exception 'Choose at least one person with EOS access (not yourself)'; end if;
  if (select count(*) from public.work_packages where sent_by = me and created_at > now() - interval '1 day') >= 50 then raise exception 'Up to 50 packages a day'; end if;
  insert into public.work_packages (title, note, sent_by, assigned_to, assigned_ids, due_date, items)
  values (btrim(p_title), nullif(btrim(coalesce(p_note, '')), ''), me, who[1], who, p_due, public.wp_clean_items(p_items))
  returning id into nid;
  return nid;
end $$;

-- receivers: accept | return (needs a note) | done ; sender (or packages.manage): cancel | resend | reassign (p_people)
drop function if exists public.wp_act(uuid, text, text);
create or replace function public.wp_act(p_id uuid, p_action text, p_note text default null, p_people uuid[] default null) returns text
language plpgsql security definer set search_path to 'public' as $$
declare me uuid := public.eos_person_id(); w public.work_packages; n text := nullif(btrim(coalesce(p_note, '')), ''); who uuid[];
begin
  if me is null then raise exception 'Sign in with EOS access'; end if;
  select * into w from public.work_packages where id = p_id for update;
  if not found then raise exception 'Package not found'; end if;
  if p_action in ('accept','return','done') then
    if not (me = any(w.assigned_ids)) then raise exception 'Only the people the package was given to can do that'; end if;
    if w.status in ('done','canceled') then raise exception 'This package is already closed'; end if;
    if p_action = 'return' and n is null then raise exception 'Say what you need when sending a package back'; end if;
    update public.work_packages set status = case p_action when 'accept' then 'accepted' when 'return' then 'returned' else 'done' end,
           response = coalesce(n, response), updated_at = now() where id = p_id;
  elsif p_action in ('cancel','resend','reassign') then
    if w.sent_by is distinct from me and not public.eos_can('packages.manage') then raise exception 'Only the sender can do that'; end if;
    if p_action = 'resend' and w.status <> 'returned' then raise exception 'Only a returned package can be sent again'; end if;
    if p_action = 'reassign' then
      if w.status in ('done','canceled') then raise exception 'This package is already closed'; end if;
      who := wp_receivers(p_people, w.sent_by);
      if cardinality(who) = 0 then raise exception 'Choose at least one person with EOS access'; end if;
      update public.work_packages set assigned_ids = who, assigned_to = who[1], status = case when status = 'returned' then 'sent' else status end,
             note = coalesce(n, note), updated_at = now() where id = p_id;
    else
      update public.work_packages set status = case p_action when 'cancel' then 'canceled' else 'sent' end,
             note = case when p_action = 'resend' and n is not null then n else note end, updated_at = now() where id = p_id;
    end if;
  else raise exception 'Unknown action'; end if;
  return (select status from public.work_packages where id = p_id);
end $$;

-- tick an item (receivers or the sender), with an optional note and photo; a task item can also mark the task done
drop function if exists public.wp_item_done(uuid, int, boolean);
create or replace function public.wp_item_done(p_id uuid, p_index int, p_done boolean, p_note text default null, p_photo uuid default null, p_complete_task boolean default false) returns jsonb
language plpgsql security definer set search_path to 'public' as $$
declare me uuid := public.eos_person_id(); w public.work_packages; it jsonb; tid uuid;
begin
  select * into w from public.work_packages where id = p_id for update;
  if not found or me is null or not (me = any(w.assigned_ids) or me = w.sent_by) then raise exception 'Package not found'; end if;
  if w.status in ('done','canceled') then raise exception 'This package is already closed'; end if;
  if p_index < 0 or p_index >= jsonb_array_length(w.items) then raise exception 'No such item'; end if;
  it := w.items -> p_index;
  if p_done is not null then
    it := it || jsonb_build_object('done', p_done, 'done_at', case when p_done then to_jsonb(now()) else 'null'::jsonb end, 'done_by', case when p_done then to_jsonb(me) else 'null'::jsonb end);
  end if;
  if p_note is not null then it := it || jsonb_build_object('note', nullif(left(btrim(p_note), 1000), '')); end if;
  if p_photo is not null then it := it || jsonb_build_object('photo_doc_id', p_photo); end if;
  update public.work_packages set items = jsonb_set(items, array[p_index::text], it), status = case when status = 'sent' then 'accepted' else status end, updated_at = now() where id = p_id;
  if coalesce(p_complete_task, false) and coalesce(p_done, false) and it->>'t' = 'tasks' then
    tid := (it->>'id')::uuid;
    begin perform public.eos_complete_task(tid, 'Done via work package P-' || lpad(w.package_number::text, 4, '0')); exception when others then null; end;
  end if;
  return (select items from public.work_packages where id = p_id);
end $$;

-- put the items in a new order (a permutation of their positions)
create or replace function public.wp_reorder(p_id uuid, p_order int[]) returns jsonb
language plpgsql security definer set search_path to 'public' as $$
declare me uuid := public.eos_person_id(); w public.work_packages; n int; out jsonb := '[]'; i int;
begin
  select * into w from public.work_packages where id = p_id for update;
  if not found or me is null or not (me = any(w.assigned_ids) or me = w.sent_by) then raise exception 'Package not found'; end if;
  if w.status in ('done','canceled') then raise exception 'This package is already closed'; end if;
  n := jsonb_array_length(w.items);
  if coalesce(cardinality(p_order), 0) <> n or (select count(distinct x) from unnest(p_order) x where x between 0 and n - 1) <> n then raise exception 'That is not a valid order'; end if;
  foreach i in array p_order loop out := out || (w.items -> i); end loop;
  update public.work_packages set items = out, updated_at = now() where id = p_id;
  return out;
end $$;

-- a task completed anywhere ticks itself in open packages
create or replace function public.trg_wp_task_done() returns trigger language plpgsql security definer set search_path to 'public' as $$
declare w record; out jsonb; it jsonb; changed boolean;
begin
  if new.status <> 'Completed' or old.status = 'Completed' then return null; end if;
  for w in select id, items from work_packages where status in ('sent','accepted','returned') and items @> jsonb_build_array(jsonb_build_object('t','tasks','id',new.id::text)) loop
    out := '[]'; changed := false;
    for it in select * from jsonb_array_elements(w.items) loop
      if it->>'t' = 'tasks' and it->>'id' = new.id::text and not coalesce((it->>'done')::boolean, false) then
        it := it || jsonb_build_object('done', true, 'done_at', to_jsonb(now()), 'done_by', to_jsonb(new.completed_by)); changed := true;
      end if;
      out := out || it;
    end loop;
    if changed then update work_packages set items = out, updated_at = now() where id = w.id; end if;
  end loop;
  return null;
exception when others then return null;
end $$;
drop trigger if exists zz_wp_task_done on public.tasks;
create trigger zz_wp_task_done after update of status on public.tasks for each row execute function public.trg_wp_task_done();

-- templates
create or replace function public.wp_template_save(p_id uuid, p_title text, p_note text, p_items jsonb, p_assigned_ids uuid[], p_due_in_days int) returns uuid
language plpgsql security definer set search_path to 'public' as $$
declare me uuid := public.eos_person_id(); tid uuid := p_id; t record;
begin
  if me is null then raise exception 'Sign in with EOS access'; end if;
  perform eos_require('packages.send');
  if tid is null then
    insert into wp_templates (title, note, items, assigned_ids, due_in_days, created_by)
    values (btrim(p_title), nullif(btrim(coalesce(p_note,'')), ''), wp_clean_items(p_items), coalesce(p_assigned_ids, '{}'), p_due_in_days, me) returning id into tid;
  else
    select * into t from wp_templates where id = tid; if not found then raise exception 'Template not found'; end if;
    if t.created_by is distinct from me and not eos_can('packages.manage') then raise exception 'Only the person who saved this template can change it'; end if;
    update wp_templates set title = btrim(p_title), note = nullif(btrim(coalesce(p_note,'')), ''), items = wp_clean_items(p_items), assigned_ids = coalesce(p_assigned_ids, '{}'), due_in_days = p_due_in_days, updated_at = now() where id = tid;
  end if;
  return tid;
end $$;
create or replace function public.wp_template_delete(p_id uuid) returns void language plpgsql security definer set search_path to 'public' as $$
declare me uuid := public.eos_person_id(); t record;
begin
  select * into t from wp_templates where id = p_id; if not found then return; end if;
  if t.created_by is distinct from me and not eos_can('packages.manage') then raise exception 'Only the person who saved this template can delete it'; end if;
  delete from wp_templates where id = p_id;
end $$;

-- notifications: every receiver hears about a package; the sender hears back; new receivers hear when reassigned
create or replace function public.trg_notif_package() returns trigger language plpgsql security definer set search_path to 'public' as $function$
declare ref text := 'P-' || lpad(new.package_number::text, 4, '0'); me uuid := eos_person_id(); p uuid; actor uuid;
begin
  actor := coalesce(me, new.sent_by);
  if tg_op = 'INSERT' then
    foreach p in array new.assigned_ids loop
      perform notif_add(p, 'package', notif_name(new.sent_by) || ' gave you a work package: ' || new.title, coalesce(new.note, ref), 'packages', new.id, new.sent_by);
    end loop;
    return null;
  end if;
  if new.assigned_ids is distinct from old.assigned_ids then
    foreach p in array new.assigned_ids loop
      if not (p = any(old.assigned_ids)) then perform notif_add(p, 'package', notif_name(new.sent_by) || ' gave you a work package: ' || new.title, coalesce(new.note, ref), 'packages', new.id, actor); end if;
    end loop;
  end if;
  if new.status is distinct from old.status then
    if new.status in ('accepted','returned','done') then
      perform notif_add(new.sent_by, 'package', notif_name(actor) || ' ' || case new.status when 'accepted' then 'accepted' when 'returned' then 'sent back' else 'finished' end || ' ' || ref || ' ' || new.title, coalesce(new.response, ''), 'packages', new.id, actor);
    elsif new.status = 'sent' and old.status = 'returned' then
      foreach p in array new.assigned_ids loop perform notif_add(p, 'package', notif_name(new.sent_by) || ' sent ' || ref || ' again: ' || new.title, coalesce(new.note, ''), 'packages', new.id, actor); end loop;
    elsif new.status = 'canceled' then
      foreach p in array new.assigned_ids loop perform notif_add(p, 'package', ref || ' ' || new.title || ' was canceled', '', 'packages', new.id, actor); end loop;
    end if;
  end if;
  return null;
exception when others then return null;
end $function$;
drop trigger if exists zz_notif_package on public.work_packages;
create trigger zz_notif_package after insert or update of status, assigned_ids on public.work_packages for each row execute function public.trg_notif_package();

revoke all on function public.wp_clean_items(jsonb), public.wp_receivers(uuid[], uuid) from public, anon, authenticated;
revoke all on function public.wp_send(text,text,uuid,date,jsonb,uuid[]), public.wp_act(uuid,text,text,uuid[]), public.wp_item_done(uuid,int,boolean,text,uuid,boolean), public.wp_reorder(uuid,int[]), public.wp_template_save(uuid,text,text,jsonb,uuid[],int), public.wp_template_delete(uuid) from public, anon;
grant execute on function public.wp_send(text,text,uuid,date,jsonb,uuid[]), public.wp_act(uuid,text,text,uuid[]), public.wp_item_done(uuid,int,boolean,text,uuid,boolean), public.wp_reorder(uuid,int[]), public.wp_template_save(uuid,text,text,jsonb,uuid[],int), public.wp_template_delete(uuid) to authenticated;

-- the view gains the receivers; columns move, so it is dropped and rebuilt
drop view if exists public.v_work_packages;
insert into public.view_defs (view_name, base_sql, min_level, row_filter, description) values
('v_work_packages', $v$
 SELECT w.id, w.package_number, w.title, w.note, w.status, w.response, w.due_date, w.items, w.created_at, w.updated_at,
        w.sent_by, sp.full_name AS sent_by_name, w.assigned_to, ap.full_name AS assigned_to_name,
        w.assigned_ids, (SELECT array_agg(p.full_name ORDER BY array_position(w.assigned_ids, p.id)) FROM people p WHERE p.id = ANY(w.assigned_ids)) AS assigned_names,
        jsonb_array_length(w.items) AS item_count,
        (SELECT count(*) FROM jsonb_array_elements(w.items) i WHERE (i->>'done')::boolean)::int AS done_count,
        (eos_person_id() = ANY(w.assigned_ids)) AS for_me, (w.sent_by = eos_person_id()) AS from_me
   FROM work_packages w
   LEFT JOIN people sp ON sp.id = w.sent_by
   LEFT JOIN people ap ON ap.id = w.assigned_to
  WHERE eos_person_id() = ANY(w.assigned_ids) OR w.sent_by = eos_person_id() OR eos_can('packages.manage')
$v$, 1, null, 'Work packages I sent or was given (packages.manage sees all).'),
('v_wp_templates', $v$
 SELECT t.id, t.title, t.note, t.items, t.assigned_ids, t.due_in_days, t.created_by, p.full_name AS created_by_name, t.created_at, t.updated_at,
        (SELECT array_agg(x.full_name ORDER BY array_position(t.assigned_ids, x.id)) FROM people x WHERE x.id = ANY(t.assigned_ids)) AS assigned_names,
        jsonb_array_length(t.items) AS item_count, (t.created_by = eos_person_id()) AS mine
   FROM wp_templates t LEFT JOIN people p ON p.id = t.created_by
$v$, 1, 'eos_can(''packages.send'')', 'Saved work packages to send again.')
on conflict (view_name) do update set base_sql = excluded.base_sql, min_level = excluded.min_level, row_filter = excluded.row_filter, description = excluded.description, updated_at = now();
select count(*) as views_rebuilt from public.rebuild_views();

-- field crews attach photos to package items (and to field forms): they need the upload grant
update public.permission_sets set grants = array(select distinct x from unnest(grants || array['documents.upload']) x), updated_at = now()
 where name = 'Field crew' and not ('documents.upload' = any(grants));
update public.settings set value = (select jsonb_agg(x) from (select distinct x from jsonb_array_elements(value || '["wp_reorder","wp_template_save","wp_template_delete"]'::jsonb) x) s)
 where key = 'rpc_allowlist';

select (select count(*) from pg_proc where proname in ('wp_send','wp_act','wp_item_done','wp_reorder','wp_template_save','wp_template_delete','wp_receivers')) as functions_ready,
       (select count(*) from information_schema.views where table_name in ('v_work_packages','v_wp_templates')) as views_ready,
       (select count(*) from pg_trigger where tgname in ('zz_wp_task_done','zz_notif_package')) as triggers_ready,
       (select count(*) from public.work_packages where cardinality(assigned_ids) > 0) as packages_with_receivers;
commit;
