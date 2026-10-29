-- 019 · Asset types (v197): non-spatial asset types with their own attributes, a spreadsheet import,
-- and the two loaders added this week on the RPC allowlist. Safe to run more than once. Run after 016, 017 and 018.
begin;
select set_config('eos.via', 'admin', true);

-- ── 1. Attributes on non-spatial assets: the type (settings.asset_hierarchy › types[].fields) says which keys exist ──
alter table public.assets add column if not exists attributes jsonb not null default '{}'::jsonb;

-- v_assets carries them; appended at the end so the view keeps its column order and create-or-replace works
update public.view_defs
   set base_sql = replace(base_sql, 'COALESCE(fr.forms, 0) AS form_count, fr.last_form_at', 'COALESCE(fr.forms, 0) AS form_count, fr.last_form_at, a.attributes'), updated_at = now()
 where view_name = 'v_assets' and base_sql not like '%a.attributes%';
select public.rebuild_views();

-- the standard editor may save them (the app draws the type's own inputs; the raw field stays hidden)
update public.settings
   set value = jsonb_set(value, '{tables,assets,fields,attributes}', '{"type":"json","label":"Attributes","hidden":true}'::jsonb, true), updated_at = now()
 where key = 'editing' and not (value->'tables'->'assets'->'fields' ? 'attributes');

-- ── 2. Import a spreadsheet of one asset type: rows with an Asset ID already in EOS are updated, the rest added ──
create or replace function public.eos_assets_import(p_type text, p_rows jsonb, p_prefix text default null)
returns jsonb language plpgsql security definer set search_path to 'public' as $function$
declare r jsonb; added int := 0; updated int := 0; me uuid; batch uuid := gen_random_uuid(); aid text; ex uuid; seq int; tg text[];
begin
  perform eos_require('assets.edit');
  if nullif(btrim(coalesce(p_type, '')), '') is null then raise exception 'Pick an asset type'; end if;
  if p_rows is null or jsonb_typeof(p_rows) <> 'array' or jsonb_array_length(p_rows) = 0 then raise exception 'Nothing to import'; end if;
  if jsonb_array_length(p_rows) > 5000 then raise exception 'Import at most 5,000 rows at a time'; end if;
  select id into me from people where auth_user_id = auth.uid() limit 1;
  select count(*) into seq from assets where class_key = p_type;
  perform set_config('eos.via', 'app', true);
  for r in select * from jsonb_array_elements(p_rows) loop
    aid := nullif(btrim(coalesce(r->>'asset_id', '')), '');
    if aid is null then seq := seq + 1; aid := coalesce(nullif(p_prefix, ''), upper(left(p_type, 4)) || '-') || lpad(seq::text, 4, '0'); end if;
    tg := case when jsonb_typeof(r->'tags') = 'array' then array(select jsonb_array_elements_text(r->'tags')) else null end;
    select id into ex from assets where class_key = p_type and asset_id = aid limit 1;
    if ex is null then
      insert into assets (class_key, asset_id, name, status, department, address, condition, criticality, install_date, replacement_cost, account_string, notes, tags, attributes)
      values (p_type, aid, coalesce(nullif(r->>'name', ''), aid), coalesce(nullif(r->>'status', ''), 'Active'), nullif(r->>'department', ''), nullif(r->>'address', ''),
              nullif(r->>'condition', ''), nullif(r->>'criticality', ''), nullif(r->>'install_date', '')::date, nullif(r->>'replacement_cost', '')::numeric,
              nullif(r->>'account_string', ''), nullif(r->>'notes', ''), tg, coalesce(r->'attributes', '{}'::jsonb))
      returning id into ex;
      insert into record_changes (table_name, record_id, field, old_value, new_value, action, source, actor_id, batch_id, note)
      values ('assets', ex, null, null, r, 'create', 'app', me, batch, 'spreadsheet import');
      added := added + 1;
    else
      update assets a
         set name = coalesce(nullif(r->>'name', ''), a.name), status = coalesce(nullif(r->>'status', ''), a.status),
             department = coalesce(nullif(r->>'department', ''), a.department), address = coalesce(nullif(r->>'address', ''), a.address),
             condition = coalesce(nullif(r->>'condition', ''), a.condition), criticality = coalesce(nullif(r->>'criticality', ''), a.criticality),
             install_date = coalesce(nullif(r->>'install_date', '')::date, a.install_date), replacement_cost = coalesce(nullif(r->>'replacement_cost', '')::numeric, a.replacement_cost),
             account_string = coalesce(nullif(r->>'account_string', ''), a.account_string), notes = coalesce(nullif(r->>'notes', ''), a.notes),
             tags = coalesce(tg, a.tags), attributes = a.attributes || coalesce(r->'attributes', '{}'::jsonb), retired_at = null
       where a.id = ex;
      insert into record_changes (table_name, record_id, field, old_value, new_value, action, source, actor_id, batch_id, note)
      values ('assets', ex, null, null, r, 'update', 'app', me, batch, 'spreadsheet import');
      updated := updated + 1;
    end if;
  end loop;
  perform set_config('eos.via', '', true);
  return jsonb_build_object('added', added, 'updated', updated, 'batch', batch);
end $function$;
revoke all on function public.eos_assets_import(text, jsonb, text) from public, anon;
grant execute on function public.eos_assets_import(text, jsonb, text) to authenticated;

-- ── 3. The functions the app may call ──
update public.settings set value = (select jsonb_agg(x) from (select distinct x from jsonb_array_elements(value || '["eos_assets_import","eos_budget_load"]'::jsonb) x) s)
 where key = 'rpc_allowlist';

commit;
