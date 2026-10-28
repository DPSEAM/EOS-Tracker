-- 014 · Deleting records from the app, with a recycle bin (v190).
-- Modeled on OpenGov: a deleted record is not destroyed. It goes to the recycle bin with everything attached to it,
-- an administrator can restore it or delete it for good, and anything left in the bin is cleared after 30 days.
-- Deleting a work order can take its tasks with it; deleting a project can take its work orders and tasks.
-- Records that pointed at a deleted record (documents, emails, requests, invoices, commitments) are unlinked, not deleted,
-- and are linked again on restore.
-- Safe to run twice.
begin;
select set_config('eos.via', 'admin', true);

create table if not exists public.recycle_bin (
  id uuid primary key default gen_random_uuid(),
  batch uuid not null,
  table_name text not null,
  record_id uuid not null,
  label text,
  snapshot jsonb not null,
  children jsonb not null default '{}',
  links jsonb not null default '{}',
  reason text,
  deleted_by uuid references public.people(id) on delete set null,
  deleted_by_name text,
  deleted_at timestamptz not null default now(),
  restored_at timestamptz,
  purged_at timestamptz
);
create index if not exists recycle_bin_batch_idx on public.recycle_bin(batch);
create index if not exists recycle_bin_open_idx on public.recycle_bin(deleted_at) where restored_at is null and purged_at is null;
alter table public.recycle_bin enable row level security;
revoke all on public.recycle_bin from anon, authenticated;

-- history rows can now say "deleted" and "restored"
alter table public.record_changes drop constraint if exists record_changes_action_check;
alter table public.record_changes add constraint record_changes_action_check
  check (action in ('create','update','unlock','ingest_blocked','ingest_update','merge','delete','restore'));

-- Documents re-link themselves to a task from their source email when the link is cleared. The delete asks it to stand down.
create or replace function public.trg_documents_inherit_links() returns trigger
language plpgsql set search_path to 'public','extensions','pg_temp' as $function$
declare l record;
begin
  if coalesce(current_setting('eos.skip_relink', true), '') = '1' then return new; end if;
  if new.source_email_id is not null and (new.work_order_id is null or new.task_id is null or new.organization_id is null) then
    select * into l from document_links_for_email(new.source_email_id);
    new.work_order_id   := coalesce(new.work_order_id, l.o_work_order);
    new.task_id         := coalesce(new.task_id, l.o_task);
    new.organization_id := coalesce(new.organization_id, l.o_org);
  end if;
  return new;
end $function$;

-- What deleting a record would take with it and unlink. Used by the confirmation in the app.
create or replace function public.eos_delete_preview(p_table text, p_id uuid) returns jsonb
language plpgsql stable security definer set search_path to 'public' as $function$
declare r jsonb := '{}'; wo uuid[]; tk uuid[];
begin
  perform eos_editor();
  if p_table = 'tasks' then
    r := r || jsonb_build_object(
      'notes', (select count(*) from notes where task_id = p_id),
      'forms', (select count(*) from form_records where task_id = p_id),
      'documents', (select count(*) from documents where task_id = p_id),
      'requests', (select count(*) from requests where task_id = p_id),
      'invoices', (select count(*) from invoices where task_id = p_id));
  elsif p_table = 'work_orders' then
    select array_agg(id) into tk from tasks where work_order_id = p_id;
    r := r || jsonb_build_object(
      'tasks', coalesce(cardinality(tk),0),
      'notes', (select count(*) from notes where work_order_id = p_id or task_id = any(coalesce(tk,'{}'))),
      'forms', (select count(*) from form_records where task_id = any(coalesce(tk,'{}'))),
      'documents', (select count(*) from documents where work_order_id = p_id or task_id = any(coalesce(tk,'{}'))),
      'emails', (select count(*) from emails where work_order_id = p_id),
      'commitments', (select count(*) from commitments where work_order_id = p_id),
      'requests', (select count(*) from requests where task_id = any(coalesce(tk,'{}'))),
      'invoices', (select count(*) from invoices where task_id = any(coalesce(tk,'{}'))));
  elsif p_table = 'projects' then
    select array_agg(id) into wo from work_orders where project_id = p_id;
    select array_agg(id) into tk from tasks where project_id = p_id or work_order_id = any(coalesce(wo,'{}'));
    r := r || jsonb_build_object(
      'work_orders', coalesce(cardinality(wo),0),
      'tasks', coalesce(cardinality(tk),0),
      'notes', (select count(*) from notes where work_order_id = any(coalesce(wo,'{}')) or task_id = any(coalesce(tk,'{}'))),
      'documents', (select count(*) from documents where work_order_id = any(coalesce(wo,'{}')) or task_id = any(coalesce(tk,'{}'))),
      'commitments', (select count(*) from commitments where project_id = p_id or work_order_id = any(coalesce(wo,'{}'))));
  elsif p_table = 'documents' then
    r := r || jsonb_build_object('commitments', (select count(*) from commitments where contract_document_id = p_id),
                                 'invoices', (select count(*) from invoices where document_id = p_id));
  elsif p_table = 'organizations' then
    r := r || jsonb_build_object('people', (select count(*) from people where organization_id = p_id),
                                 'work_orders', (select count(*) from work_orders where organization_id = p_id),
                                 'tasks', (select count(*) from tasks where organization_id = p_id),
                                 'documents', (select count(*) from documents where organization_id = p_id),
                                 'blocking', (select count(*) from invoices where vendor_org_id = p_id) + (select count(*) from commitments where vendor_org_id = p_id));
  end if;
  r := r || jsonb_build_object('favorites', (select count(*) from favorites where record_table = p_table and record_id = p_id),
                               'recycle_days', coalesce((select (value->>'recycle_days')::int from settings where key = 'editing'), 30));
  return r;
end $function$;

-- Delete one record into the recycle bin. p_with_children: a work order takes its tasks, a project its work orders and tasks.
-- Several deletes can share p_batch so one Undo brings them all back.
create or replace function public.eos_delete(p_table text, p_id uuid, p_with_children boolean default true, p_reason text default null, p_batch uuid default null)
returns jsonb language plpgsql security definer set search_path to 'public' as $function$
declare row_j jsonb; kids jsonb := '{}'; lnk jsonb := '{}'; me uuid; me_name text; the_batch uuid := coalesce(p_batch, gen_random_uuid());
        lbl text; bin_id uuid; n int; counts jsonb := '{}'; x uuid; blocking int;
begin
  perform eos_editor();
  if p_table not in ('tasks','work_orders','projects','meetings','requests','documents','organizations','work_packages','notes','docs') then
    raise exception 'Records in % cannot be deleted from the app', p_table;
  end if;
  execute format('select to_jsonb(t) from public.%I t where id = $1', p_table) into row_j using p_id;
  if row_j is null then raise exception 'Record not found (it may already be deleted)'; end if;
  select id, full_name into me, me_name from people where auth_user_id = auth.uid() limit 1;

  lbl := case p_table
    when 'tasks' then coalesce(eos_task_ref((row_j->>'task_number')::int) || ' ', '') || left(coalesce(row_j->>'title', row_j->>'instructions', ''), 120)
    when 'work_orders' then coalesce(row_j->>'work_order_number' || ' ', '') || left(coalesce(row_j->>'project_name',''), 120)
    when 'projects' then left(coalesce(row_j->>'name',''), 120)
    when 'meetings' then left(coalesce(row_j->>'title',''), 120)
    when 'requests' then left(coalesce(row_j->>'title',''), 120)
    when 'documents' then left(coalesce(row_j->>'title', row_j->>'filename', ''), 120)
    when 'organizations' then left(coalesce(row_j->>'name',''), 120)
    when 'work_packages' then left(coalesce(row_j->>'title',''), 120)
    when 'notes' then left(coalesce(row_j->>'content',''), 120)
    when 'docs' then left(coalesce(row_j->>'title',''), 120) end;

  perform set_config('eos.via', 'app', true);
  perform set_config('eos.skip_relink', '1', true);

  -- children first (each becomes its own bin entry in the same batch), then what this record carries
  if p_table = 'work_orders' then
    if p_with_children then
      for x in select id from tasks where work_order_id = p_id loop perform eos_delete('tasks', x, true, p_reason, the_batch); end loop;
    else
      kids := kids || jsonb_build_object('unlinked_tasks', coalesce((select jsonb_agg(id) from tasks where work_order_id = p_id), '[]'));
      update tasks set work_order_id = null where work_order_id = p_id;
    end if;
    kids := kids || jsonb_build_object('notes', coalesce((select jsonb_agg(to_jsonb(nt)) from notes nt where nt.work_order_id = p_id), '[]'));
    lnk := lnk || jsonb_build_object(
      'documents', coalesce((select jsonb_agg(id) from documents where work_order_id = p_id), '[]'),
      'emails', coalesce((select jsonb_agg(id) from emails where work_order_id = p_id), '[]'),
      'commitments', coalesce((select jsonb_agg(id) from commitments where work_order_id = p_id), '[]'),
      'pavement_work', coalesce((select jsonb_agg(id) from pavement_work where work_order_id = p_id), '[]'),
      'pavement_recon', coalesce((select jsonb_agg(id) from pavement_recon where work_order_id = p_id), '[]'),
      'task_templates', coalesce((select jsonb_agg(id) from task_templates where work_order_id = p_id), '[]'));
    delete from notes where work_order_id = p_id;
    update commitments set work_order_id = null where work_order_id = p_id;
  elsif p_table = 'projects' then
    if p_with_children then
      for x in select id from work_orders where project_id = p_id loop perform eos_delete('work_orders', x, true, p_reason, the_batch); end loop;
      for x in select id from tasks where project_id = p_id loop perform eos_delete('tasks', x, true, p_reason, the_batch); end loop;
    else
      kids := kids || jsonb_build_object('unlinked_work_orders', coalesce((select jsonb_agg(id) from work_orders where project_id = p_id), '[]'),
                                         'unlinked_tasks', coalesce((select jsonb_agg(id) from tasks where project_id = p_id), '[]'));
      update work_orders set project_id = null where project_id = p_id;
      update tasks set project_id = null where project_id = p_id;
    end if;
    lnk := lnk || jsonb_build_object(
      'commitments', coalesce((select jsonb_agg(id) from commitments where project_id = p_id), '[]'),
      'pavement_work', coalesce((select jsonb_agg(id) from pavement_work where project_id = p_id), '[]'),
      'task_templates', coalesce((select jsonb_agg(id) from task_templates where project_id = p_id), '[]'));
    update commitments set project_id = null where project_id = p_id;
  elsif p_table = 'tasks' then
    kids := kids || jsonb_build_object(
      'notes', coalesce((select jsonb_agg(to_jsonb(nt)) from notes nt where nt.task_id = p_id), '[]'),
      'form_records', coalesce((select jsonb_agg(to_jsonb(fr)) from form_records fr where fr.task_id = p_id), '[]'),
      'task_dependencies', coalesce((select jsonb_agg(to_jsonb(td)) from task_dependencies td where td.task_id = p_id or td.blocked_by_id = p_id), '[]'));
    lnk := lnk || jsonb_build_object(
      'documents', coalesce((select jsonb_agg(id) from documents where task_id = p_id), '[]'),
      'requests', coalesce((select jsonb_agg(id) from requests where task_id = p_id), '[]'),
      'invoices', coalesce((select jsonb_agg(id) from invoices where task_id = p_id), '[]'));
    delete from notes where task_id = p_id;
    update invoices set task_id = null where task_id = p_id;
  elsif p_table = 'documents' then
    lnk := lnk || jsonb_build_object(
      'commitments', coalesce((select jsonb_agg(id) from commitments where contract_document_id = p_id), '[]'),
      'invoices', coalesce((select jsonb_agg(id) from invoices where document_id = p_id), '[]'));
    update commitments set contract_document_id = null where contract_document_id = p_id;
    update invoices set document_id = null where document_id = p_id;
  elsif p_table = 'organizations' then
    select (select count(*) from invoices where vendor_org_id = p_id) + (select count(*) from commitments where vendor_org_id = p_id) into blocking;
    if blocking > 0 then raise exception 'This organization is the vendor on % invoice(s) or commitment(s). Move those first.', blocking; end if;
    lnk := lnk || jsonb_build_object(
      'people', coalesce((select jsonb_agg(id) from people where organization_id = p_id), '[]'),
      'work_orders', coalesce((select jsonb_agg(id) from work_orders where organization_id = p_id), '[]'),
      'tasks', coalesce((select jsonb_agg(id) from tasks where organization_id = p_id), '[]'),
      'documents', coalesce((select jsonb_agg(id) from documents where organization_id = p_id), '[]'));
  end if;
  kids := kids || jsonb_build_object('favorites', coalesce((select jsonb_agg(to_jsonb(fv)) from favorites fv where fv.record_table = p_table and fv.record_id = p_id), '[]'));
  delete from favorites where record_table = p_table and record_id = p_id;

  insert into recycle_bin (batch, table_name, record_id, label, snapshot, children, links, reason, deleted_by, deleted_by_name)
  values (the_batch, p_table, p_id, lbl, row_j, kids, lnk, p_reason, me, me_name) returning id into bin_id;

  execute format('delete from public.%I where id = $1', p_table) using p_id;
  insert into record_changes (table_name, record_id, field, old_value, new_value, action, source, actor_id, batch_id, note)
  values (p_table, p_id, null, null, null, 'delete', 'app', me, the_batch, coalesce(p_reason, 'Moved to the recycle bin'));

  perform set_config('eos.skip_relink', '', true);
  perform set_config('eos.via', '', true);
  select jsonb_object_agg(s.table_name, s.cnt) into counts from (select rb.table_name, count(*) cnt from recycle_bin rb where rb.batch = the_batch group by rb.table_name) s;
  return jsonb_build_object('batch', the_batch, 'bin', bin_id, 'label', lbl, 'deleted', counts);
end $function$;

-- Put back everything a delete took (one record and its children, or a whole bulk delete). Called by Undo and by the bin.
create or replace function public.eos_restore(p_batch uuid) returns jsonb
language plpgsql security definer set search_path to 'public' as $function$
declare b record; cols text; n int := 0; k text; v jsonb; me uuid; skipped text[] := '{}';
  ord text[] := array['organizations','projects','work_orders','tasks','documents','meetings','requests','work_packages','notes','docs'];
begin
  perform eos_editor();
  select id into me from people where auth_user_id = auth.uid() limit 1;
  perform set_config('eos.via', 'app', true);
  perform set_config('eos.skip_relink', '1', true);
  for b in select * from recycle_bin where (batch = p_batch or id = p_batch) and restored_at is null and purged_at is null
           order by array_position(ord, table_name), deleted_at loop
    -- the row itself, every column except generated ones; parents that were unlinked stay unlinked only if they are gone
    select string_agg(quote_ident(column_name), ', ') into cols
      from information_schema.columns c
     where c.table_schema = 'public' and c.table_name = b.table_name and c.is_generated = 'NEVER'
       and b.snapshot ? c.column_name;
    begin
      execute format('insert into public.%1$I (%2$s) overriding system value select %2$s from jsonb_populate_record(null::public.%1$I, $1) on conflict (id) do nothing', b.table_name, cols) using b.snapshot;
    exception when foreign_key_violation then
      -- a parent is gone for good: put the record back without the dangling link
      v := b.snapshot;
      if b.table_name = 'tasks' then v := v - 'work_order_id' - 'project_id'; elsif b.table_name = 'work_orders' then v := v - 'project_id'; end if;
      execute format('insert into public.%1$I (%2$s) overriding system value select %2$s from jsonb_populate_record(null::public.%1$I, $1) on conflict (id) do nothing', b.table_name,
                     (select string_agg(quote_ident(key), ', ') from jsonb_object_keys(v) key where key <> 'search_tsv')) using v;
      skipped := skipped || (b.label || ' (its parent is gone)');
    end;
  end loop;
  -- second pass: children and links, once every record of the batch is back (a dependency may point at another restored task)
  for b in select * from recycle_bin where (batch = p_batch or id = p_batch) and restored_at is null and purged_at is null
           order by array_position(ord, table_name), deleted_at loop
    -- children
    for k, v in select * from jsonb_each(b.children) loop
      if k = 'task_dependencies' and jsonb_array_length(v) > 0 then
        insert into task_dependencies select d.* from jsonb_populate_recordset(null::task_dependencies, v) d
         where exists (select 1 from tasks t where t.id = d.task_id) and exists (select 1 from tasks t where t.id = d.blocked_by_id) on conflict do nothing;
      elsif k in ('notes','form_records','favorites') and jsonb_array_length(v) > 0 then
        execute format('insert into public.%1$I select * from jsonb_populate_recordset(null::public.%1$I, $1) on conflict do nothing', k) using v;
      elsif k = 'unlinked_tasks' then
        update tasks set work_order_id = b.record_id where id in (select (e->>0)::uuid from jsonb_array_elements(v) e) and work_order_id is null and b.table_name = 'work_orders';
        update tasks set project_id = b.record_id where id in (select (e->>0)::uuid from jsonb_array_elements(v) e) and project_id is null and b.table_name = 'projects';
      elsif k = 'unlinked_work_orders' then
        update work_orders set project_id = b.record_id where id in (select (e->>0)::uuid from jsonb_array_elements(v) e) and project_id is null;
      end if;
    end loop;
    -- links from other records
    for k, v in select * from jsonb_each(b.links) loop
      if jsonb_array_length(v) = 0 then continue; end if;
      if b.table_name = 'tasks' then
        if k = 'documents' then update documents set task_id = b.record_id where id in (select (e->>0)::uuid from jsonb_array_elements(v) e) and task_id is null; end if;
        if k = 'requests' then update requests set task_id = b.record_id where id in (select (e->>0)::uuid from jsonb_array_elements(v) e) and task_id is null; end if;
        if k = 'invoices' then update invoices set task_id = b.record_id where id in (select (e->>0)::uuid from jsonb_array_elements(v) e) and task_id is null; end if;
      elsif b.table_name = 'work_orders' then
        if k = 'documents' then update documents set work_order_id = b.record_id where id in (select (e->>0)::uuid from jsonb_array_elements(v) e) and work_order_id is null; end if;
        if k = 'emails' then update emails set work_order_id = b.record_id where id in (select e->>0 from jsonb_array_elements(v) e) and work_order_id is null; end if;
        if k = 'commitments' then update commitments set work_order_id = b.record_id where id in (select (e->>0)::uuid from jsonb_array_elements(v) e) and work_order_id is null; end if;
        if k = 'pavement_work' then update pavement_work set work_order_id = b.record_id where id in (select (e->>0)::uuid from jsonb_array_elements(v) e) and work_order_id is null; end if;
        if k = 'pavement_recon' then update pavement_recon set work_order_id = b.record_id where id in (select (e->>0)::uuid from jsonb_array_elements(v) e) and work_order_id is null; end if;
        if k = 'task_templates' then update task_templates set work_order_id = b.record_id where id in (select (e->>0)::uuid from jsonb_array_elements(v) e) and work_order_id is null; end if;
      elsif b.table_name = 'projects' then
        if k = 'commitments' then update commitments set project_id = b.record_id where id in (select (e->>0)::uuid from jsonb_array_elements(v) e) and project_id is null; end if;
        if k = 'pavement_work' then update pavement_work set project_id = b.record_id where id in (select (e->>0)::uuid from jsonb_array_elements(v) e) and project_id is null; end if;
        if k = 'task_templates' then update task_templates set project_id = b.record_id where id in (select (e->>0)::uuid from jsonb_array_elements(v) e) and project_id is null; end if;
      elsif b.table_name = 'documents' then
        if k = 'commitments' then update commitments set contract_document_id = b.record_id where id in (select (e->>0)::uuid from jsonb_array_elements(v) e) and contract_document_id is null; end if;
        if k = 'invoices' then update invoices set document_id = b.record_id where id in (select (e->>0)::uuid from jsonb_array_elements(v) e) and document_id is null; end if;
      elsif b.table_name = 'organizations' then
        if k = 'people' then update people set organization_id = b.record_id where id in (select (e->>0)::uuid from jsonb_array_elements(v) e) and organization_id is null; end if;
        if k = 'work_orders' then update work_orders set organization_id = b.record_id where id in (select (e->>0)::uuid from jsonb_array_elements(v) e) and organization_id is null; end if;
        if k = 'tasks' then update tasks set organization_id = b.record_id where id in (select (e->>0)::uuid from jsonb_array_elements(v) e) and organization_id is null; end if;
        if k = 'documents' then update documents set organization_id = b.record_id where id in (select (e->>0)::uuid from jsonb_array_elements(v) e) and organization_id is null; end if;
      end if;
    end loop;
    update recycle_bin set restored_at = now() where id = b.id;
    insert into record_changes (table_name, record_id, field, old_value, new_value, action, source, actor_id, batch_id, note)
    values (b.table_name, b.record_id, null, null, null, 'restore', 'app', me, p_batch, 'Restored from the recycle bin');
    n := n + 1;
  end loop;
  perform set_config('eos.skip_relink', '', true);
  perform set_config('eos.via', '', true);
  if n = 0 then raise exception 'Nothing to restore (already restored or deleted for good)'; end if;
  return jsonb_build_object('restored', n, 'skipped', skipped);
end $function$;

-- Delete for good: one bin entry, or a whole batch. Returns the storage paths of any documents so the app can remove the files.
create or replace function public.eos_purge(p_id uuid) returns jsonb
language plpgsql security definer set search_path to 'public' as $function$
declare paths jsonb; n int;
begin
  perform eos_editor();
  if eos_level() < 6 then raise exception 'Deleting for good needs a level-6 login'; end if;
  select coalesce(jsonb_agg(snapshot->>'storage_path'), '[]') into paths
    from recycle_bin where (id = p_id or batch = p_id) and purged_at is null and restored_at is null and table_name = 'documents' and snapshot->>'storage_path' is not null;
  update recycle_bin set purged_at = now(), snapshot = jsonb_build_object('purged', true), children = '{}', links = '{}'
   where (id = p_id or batch = p_id) and purged_at is null and restored_at is null;
  get diagnostics n = row_count;
  return jsonb_build_object('purged', n, 'storage_paths', paths);
end $function$;

-- Nightly: anything in the bin longer than editing.recycle_days (30) is deleted for good.
create or replace function public.eos_recycle_purge() returns int
language plpgsql security definer set search_path to 'public' as $function$
declare d int := coalesce((select (value->>'recycle_days')::int from settings where key = 'editing'), 30); n int;
begin
  update recycle_bin set purged_at = now(), snapshot = jsonb_build_object('purged', true), children = '{}', links = '{}'
   where purged_at is null and restored_at is null and deleted_at < now() - make_interval(days => d);
  get diagnostics n = row_count;
  return n;
end $function$;

revoke all on function public.eos_delete_preview(text, uuid), public.eos_delete(text, uuid, boolean, text, uuid), public.eos_restore(uuid), public.eos_purge(uuid), public.eos_recycle_purge() from public, anon;
grant execute on function public.eos_delete_preview(text, uuid), public.eos_delete(text, uuid, boolean, text, uuid), public.eos_restore(uuid), public.eos_purge(uuid) to authenticated;

-- The bin as the app reads it (level 6).
insert into public.view_defs (view_name, base_sql, min_level, row_filter, description)
values ('v_recycle_bin', $$
 SELECT b.id, b.batch, b.table_name, b.record_id, b.label, b.reason, b.deleted_by, b.deleted_by_name, b.deleted_at, b.restored_at, b.purged_at,
        (SELECT count(*) FROM recycle_bin c WHERE c.batch = b.batch AND c.id <> b.id AND c.restored_at IS NULL AND c.purged_at IS NULL)::int AS with_others,
        b.deleted_at + make_interval(days => coalesce((SELECT (value->>'recycle_days')::int FROM settings WHERE key = 'editing'), 30)) AS clears_at
   FROM recycle_bin b
  WHERE b.restored_at IS NULL AND b.purged_at IS NULL
$$, 6, null, 'Deleted records waiting in the recycle bin: restore them or delete them for good.')
on conflict (view_name) do update set base_sql = excluded.base_sql, min_level = excluded.min_level, description = excluded.description, updated_at = now();
select count(*) as views_rebuilt from public.rebuild_views();

update public.settings set value = value || jsonb_build_object('recycle_days', 30), updated_at = now()
 where key = 'editing' and not (value ? 'recycle_days');
update public.settings set value = (select jsonb_agg(x) from (select distinct x from jsonb_array_elements(value || '["eos_delete_preview","eos_delete","eos_restore","eos_purge"]'::jsonb) x) s)
 where key = 'rpc_allowlist';

-- clear the bin nightly at 3:17
select cron.unschedule(jobid) from cron.job where jobname = 'eos-recycle-purge';
select cron.schedule('eos-recycle-purge', '17 3 * * *', $$select public.eos_recycle_purge()$$);

select (select count(*) from pg_proc where proname in ('eos_delete','eos_restore','eos_purge','eos_delete_preview','eos_recycle_purge')) as functions_ready,
       (select count(*) from information_schema.views where table_name = 'v_recycle_bin') as view_ready,
       (select count(*) from cron.job where jobname = 'eos-recycle-purge') as nightly_job;
commit;
