-- 021 · People: delete fix, and merge two Directory entries that are the same person
-- Part 1 (delete fix) is LIVE (applied 2026-10-30 as migration "011_eos_delete_people_idless_tables").
-- Part 2 (eos_merge_people) is NOT applied yet: the Supabase approval prompt timed out. Apply it, test it on a copy, then build the app screen.
--
-- 1. eos_delete('people', ...) failed with: column "id" does not exist.
--    Cause: task_dependencies.created_by points at people but the table has no id column, and the generic
--    "record every link" loop selected id from it. Tables with no id are no longer recorded in the bin
--    (they are audit attributions only); the link is still cleared. Patched in place:
do $m$
declare d text; o text; n text;
begin
  d := pg_get_functiondef('public.eos_delete(text,uuid,boolean,text,uuid)'::regprocedure);
  o := $q$execute format('select coalesce(jsonb_agg(id), ''[]'') from %s where %I = $1', fkr.tbl, fkr.col) into v using p_id;$q$;
  n := $q$if exists (select 1 from pg_attribute where attrelid = fkr.tbl::regclass and attname = 'id' and not attisdropped) then execute format('select coalesce(jsonb_agg(id), ''[]'') from %s where %I = $1', fkr.tbl, fkr.col) into v using p_id; else v := '[]'::jsonb; end if;$q$;
  if position(o in d) > 0 then execute replace(d, o, n); end if;
end $m$;

-- 2. eos_merge_people(p_drop, p_keep): two Directory entries are one person (different addresses, same human).
--    Everything that pointed at p_drop (foreign keys and uuid lists) is moved to p_keep; p_drop's address(es)
--    become p_keep's other_emails; blank fields on p_keep are filled from p_drop; p_drop goes to the recycle bin
--    (30 days). Refuses if p_drop can sign in to EOS. Needs the directory.manage grant.
create or replace function public.eos_merge_people(p_drop uuid, p_keep uuid)
returns jsonb language plpgsql security definer set search_path to 'public' as $f$
declare dr people%rowtype; ke people%rowtype; fkr record; moved jsonb := '{}'; n int; me uuid; me_name text;
        add_emails text[]; del jsonb; bat uuid := gen_random_uuid();
begin
  perform eos_editor();
  perform eos_require('directory.manage');
  if p_drop is null or p_keep is null or p_drop = p_keep then raise exception 'Choose two different people'; end if;
  select * into dr from people where id = p_drop;  if not found then raise exception 'The person to merge was not found'; end if;
  select * into ke from people where id = p_keep;  if not found then raise exception 'The person to keep was not found'; end if;
  if dr.auth_user_id is not null and coalesce(dr.login_enabled, false) then
    raise exception '% can sign in to EOS. Turn off their EOS access first, then merge.', coalesce(dr.full_name, dr.email_address);
  end if;
  select id, full_name into me, me_name from people where auth_user_id = auth.uid() limit 1;
  perform set_config('eos.via', 'app', true);
  perform set_config('eos.skip_relink', '1', true);

  -- 1. foreign keys to people (not the bin itself)
  for fkr in select c.conrelid::regclass::text as tbl, a.attname as col
               from pg_constraint c join pg_attribute a on a.attrelid = c.conrelid and a.attnum = any(c.conkey)
              where c.contype = 'f' and c.confrelid = 'public.people'::regclass and c.conrelid <> 'public.recycle_bin'::regclass loop
    begin
      execute format('update %s set %I = $2 where %I = $1', fkr.tbl, fkr.col, fkr.col) using p_drop, p_keep;
      get diagnostics n = row_count;
    exception when unique_violation then
      -- the kept person already has this row (same favourite, same conversation...): the duplicate is dropped
      execute format('delete from %s where %I = $1', fkr.tbl, fkr.col) using p_drop;
      get diagnostics n = row_count;
    end;
    if n > 0 then moved := moved || jsonb_build_object(replace(fkr.tbl, 'public.', '') || '.' || fkr.col, n); end if;
  end loop;

  -- 2. uuid lists (assigned labor, attendees ...): swap the id, keep the order, no repeats
  for fkr in select c.table_name as tbl, c.column_name as col from information_schema.columns c
              where c.table_schema = 'public' and c.data_type = 'ARRAY' and c.udt_name = '_uuid'
                and c.table_name not like 'v\_%' and c.table_name <> 'recycle_bin'
                and exists (select 1 from information_schema.tables t where t.table_schema = 'public' and t.table_name = c.table_name and t.table_type = 'BASE TABLE') loop
    execute format('update public.%I set %I = array(select x from (select x, min(o) o from (select case when y = $1 then $2 else y end x, o from unnest(%I) with ordinality u(y,o)) a group by x) b order by o) where $1 = any(%I)',
                   fkr.tbl, fkr.col, fkr.col, fkr.col) using p_drop, p_keep;
    get diagnostics n = row_count;
    if n > 0 then moved := moved || jsonb_build_object('arr:' || fkr.tbl || '.' || fkr.col, n); end if;
  end loop;

  -- 3. the merged person goes to the recycle bin (nothing now points at them)
  add_emails := array(select distinct lower(btrim(e)) from unnest(array[dr.email_address] || coalesce(dr.other_emails, '{}')) e where btrim(coalesce(e,'')) <> '');
  del := eos_delete('people', p_drop, true, 'Merged into ' || coalesce(ke.full_name, ke.email_address), bat);
  perform set_config('eos.via', 'app', true);   -- eos_delete clears it on the way out

  -- 4. the kept person gains the addresses and any blank detail
  update people set
      other_emails   = coalesce(other_emails, '{}') || array(select e from unnest(add_emails) e where e <> lower(coalesce(ke.email_address, '')) and not (e = any(coalesce(ke.other_emails, '{}')))),
      work_phone     = coalesce(nullif(work_phone,''), dr.work_phone),
      cellular       = coalesce(nullif(cellular,''), dr.cellular),
      title          = coalesce(nullif(title,''), dr.title),
      department     = coalesce(nullif(department,''), dr.department),
      organization_id = coalesce(organization_id, dr.organization_id),
      supervisor_id  = coalesce(supervisor_id, dr.supervisor_id),
      opengov_labor_id = coalesce(nullif(opengov_labor_id,''), dr.opengov_labor_id),
      hire_date      = coalesce(hire_date, dr.hire_date),
      notes          = case when coalesce(dr.notes,'') = '' then notes when coalesce(notes,'') = '' then dr.notes else notes || E'\n' || dr.notes end
   where id = p_keep;

  insert into record_changes (table_name, record_id, field, old_value, new_value, action, source, actor_id, batch_id, note)
  values ('people', p_keep, 'other_emails', to_jsonb(coalesce(ke.other_emails,'{}'::text[])), to_jsonb(add_emails), 'merge', 'app', me, bat,
          'Merged in ' || coalesce(dr.full_name, '') || ' (' || coalesce(dr.email_address, '') || ')');

  perform set_config('eos.skip_relink', '', true);
  perform set_config('eos.via', '', true);
  return jsonb_build_object('kept', p_keep, 'merged', p_drop, 'emails_added', to_jsonb(add_emails), 'moved', moved, 'batch', bat);
end $f$;
revoke all on function public.eos_merge_people(uuid, uuid) from public, anon;
grant execute on function public.eos_merge_people(uuid, uuid) to authenticated;
