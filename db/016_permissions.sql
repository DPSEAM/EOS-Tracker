-- 016 · Roles and permissions (v192).
-- Levels stay the clearance (what you can see: rows, fields). Permissions say what you can do, granted through
-- permission sets (Viewer, Field crew, Crew leader, Supervisor, Division head, Administrator) that each role points at.
-- A person can be given a different set than their role, plus extra grants or denied grants.
-- Every write function checks a permission in the database; the app only shows the buttons you can use.
-- Existing access is mapped from levels so nothing changes until a set is edited. Safe to run twice.
begin;
select set_config('eos.via', 'admin', true);

create table if not exists public.permission_sets (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  description text,
  grants text[] not null default '{}',
  sort_order int not null default 50,
  is_builtin boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.permission_sets enable row level security;
revoke all on public.permission_sets from anon, authenticated;
alter table public.roles add column if not exists permission_set_id uuid references public.permission_sets(id) on delete set null;
alter table public.people add column if not exists permission_set_id uuid references public.permission_sets(id) on delete set null;
alter table public.people add column if not exists extra_grants text[] not null default '{}';
alter table public.people add column if not exists denied_grants text[] not null default '{}';

-- the catalog of actions the app knows about (labels for the permissions page)
insert into public.settings (key, value, description, min_level)
values ('permissions', $cat$[{"key": "see.budget", "label": "See Budget", "area": "See", "note": "The Budget tab: budget lines, commitments and invoices."}, {"key": "see.people", "label": "See Directory", "area": "See", "note": "The Directory tab."}, {"key": "see.meetings", "label": "See Calendar", "area": "See", "note": "The Calendar tab and meetings."}, {"key": "see.documents", "label": "See Documents", "area": "See", "note": "The Documents tab."}, {"key": "see.pavement", "label": "See Pavement", "area": "See", "note": "The Pavement tab."}, {"key": "see.dashboards", "label": "See Dashboards", "area": "See", "note": "The Dashboards tab."}, {"key": "see.system", "label": "See System Health", "area": "See", "note": "System Health: nightly check, data quality, ingest runs, email activity, rules, settings and the data dictionary (read only)."}, {"key": "see.review", "label": "See flagged for review", "area": "See", "note": "Tasks the email ingest flagged for a person to check."}, {"key": "tasks.create", "label": "Create tasks", "area": "Work", "note": "New tasks from + New, work orders, projects and templates."}, {"key": "tasks.edit", "label": "Edit tasks", "area": "Work", "note": "Change any field on a task, bulk changes, undo."}, {"key": "tasks.done_any", "label": "Mark any task done", "area": "Work", "note": "Done on tasks you are not on, and undo of someone else's Done. Everyone can mark their own tasks done."}, {"key": "work_orders.create", "label": "Create work orders", "area": "Work", "note": ""}, {"key": "work_orders.edit", "label": "Edit work orders", "area": "Work", "note": ""}, {"key": "projects.create", "label": "Create projects", "area": "Work", "note": ""}, {"key": "projects.edit", "label": "Edit projects", "area": "Work", "note": "Including milestones, budget and funding."}, {"key": "notes.add", "label": "Add notes and updates", "area": "Work", "note": "Notes on tasks and work orders, and Add update."}, {"key": "templates.use", "label": "Use task templates", "area": "Work", "note": "Make tasks from templates and manage repeating tasks."}, {"key": "requests.handle", "label": "Handle requests", "area": "Work", "note": "Accept, decline and close requests from staff. Everyone can send one."}, {"key": "packages.send", "label": "Send work packages", "area": "Work", "note": "Bundle records and hand them to someone."}, {"key": "packages.manage", "label": "Manage any work package", "area": "Work", "note": "Cancel or resend packages other people sent."}, {"key": "forms.submit", "label": "Fill in field forms", "area": "Work", "note": "Inspections and other forms on the iPad."}, {"key": "meetings.edit", "label": "Edit meetings", "area": "Work", "note": "Add and change meetings and recurring meetings."}, {"key": "records.delete", "label": "Delete records", "area": "Work", "note": "Move records to the recycle bin, restore them, and delete for good."}, {"key": "documents.upload", "label": "Upload documents", "area": "Documents", "note": ""}, {"key": "documents.edit", "label": "Edit document details", "area": "Documents", "note": "Title, category, location, links to records."}, {"key": "kb.edit", "label": "Edit the Knowledge Base", "area": "Documents", "note": ""}, {"key": "invoices.approve", "label": "Check and approve invoices", "area": "Money", "note": "Check, route, sign for others, release and mark paid."}, {"key": "commitments.edit", "label": "Edit commitments", "area": "Money", "note": "Purchase orders and contracts."}, {"key": "assets.edit", "label": "Edit assets", "area": "GIS and pavement", "note": "Non-spatial assets in the Assets tab."}, {"key": "gis.edit", "label": "Edit GIS layers", "area": "GIS and pavement", "note": "Change features on the ArcGIS layers from the map."}, {"key": "pavement.manage", "label": "Manage pavement data", "area": "GIS and pavement", "note": "Imports, street segment sync and the paving review."}, {"key": "directory.manage", "label": "Manage the Directory", "area": "People", "note": "Add, edit, remove and delete people and organizations; give and take away EOS access."}, {"key": "roles.manage", "label": "Manage roles and permissions", "area": "People", "note": "Roles, levels, permission sets and who has which."}, {"key": "settings.manage", "label": "Manage settings", "area": "System", "note": "Settings, rules, data dictionary, layouts, forms, dropdown lists, asset layers, backups and page errors."}, {"key": "ingest.run", "label": "Run the email ingest", "area": "System", "note": "Run ingest now from the account menu and Home."}, {"key": "dashboards.edit", "label": "Edit shared dashboards", "area": "System", "note": "Dashboards everyone sees. Everyone can arrange their own Home."}]$cat$::jsonb, 'Every action a permission set can grant: key, label, area, note. The app and the database both use the keys.', 1)
on conflict (key) do update set value = excluded.value, description = excluded.description;

insert into public.permission_sets (name, description, grants, sort_order, is_builtin) values
 ('Viewer', 'Looks, does not change anything. What they see is set by their level.', '{}', 10, false),
 ('Field crew', 'Adds notes and fills in field forms.', array['notes.add','forms.submit','see.documents','see.pavement','see.dashboards']::text[], 20, false),
 ('Crew leader', 'Creates and edits tasks, uploads documents, sends work packages.', array['notes.add','forms.submit','see.documents','see.pavement','see.dashboards','tasks.create','tasks.edit','tasks.done_any','documents.upload','templates.use','packages.send','see.people','see.meetings']::text[], 30, false),
 ('Supervisor', 'Also work orders, projects, meetings, requests and document details.', array['notes.add','forms.submit','see.documents','see.pavement','see.dashboards','tasks.create','tasks.edit','tasks.done_any','documents.upload','templates.use','packages.send','see.people','see.meetings','work_orders.create','work_orders.edit','projects.create','projects.edit','documents.edit','requests.handle','packages.manage','meetings.edit','assets.edit']::text[], 40, false),
 ('Division head', 'Also budget, invoices, commitments, the Knowledge Base, pavement data and shared dashboards.', array['notes.add','forms.submit','see.documents','see.pavement','see.dashboards','tasks.create','tasks.edit','tasks.done_any','documents.upload','templates.use','packages.send','see.people','see.meetings','work_orders.create','work_orders.edit','projects.create','projects.edit','documents.edit','requests.handle','packages.manage','meetings.edit','assets.edit','see.budget','see.review','see.system','invoices.approve','commitments.edit','kb.edit','pavement.manage','dashboards.edit']::text[], 50, false),
 ('Administrator', 'Everything, including the Directory, roles and permissions, settings and deleting records.', array['see.budget','see.people','see.meetings','see.documents','see.pavement','see.dashboards','see.system','see.review','tasks.create','tasks.edit','tasks.done_any','work_orders.create','work_orders.edit','projects.create','projects.edit','notes.add','templates.use','requests.handle','packages.send','packages.manage','forms.submit','meetings.edit','records.delete','documents.upload','documents.edit','kb.edit','invoices.approve','commitments.edit','assets.edit','gis.edit','pavement.manage','directory.manage','roles.manage','settings.manage','ingest.run','dashboards.edit']::text[], 60, true)
on conflict (name) do nothing;

-- Which set a level falls back to when neither the person nor their role names one
create or replace function public.eos_level_set(p_level int) returns text language sql immutable as $$
  select case when p_level >= 6 then 'Administrator' when p_level = 5 then 'Division head' when p_level = 4 then 'Supervisor'
              when p_level in (2,3) then 'Crew leader' when p_level = 1 then 'Field crew' else 'Viewer' end
$$;

-- The signed-in person's grants. The SQL editor and the service role (ingest) get everything.
create or replace function public.eos_grants() returns text[] language plpgsql stable security definer set search_path to 'public' as $function$
declare claims text; jrole text; p record; setg text[];
begin
  claims := nullif(current_setting('request.jwt.claims', true), '');
  jrole := case when claims is null then '' else coalesce(claims::json->>'role', '') end;
  if claims is null or jrole = 'service_role' then
    return array(select e->>'key' from jsonb_array_elements((select value from settings where key = 'permissions')) e);
  end if;
  if jrole <> 'authenticated' then return '{}'; end if;
  select pp.id, pp.permission_set_id, pp.extra_grants, pp.denied_grants, pp.preview_level,
         coalesce(pp.visibility_level, r.visibility_level) as lvl, r.permission_set_id as role_set
    into p from people pp left join roles r on r.id = pp.role_id
   where pp.auth_user_id = auth.uid() and pp.login_enabled and not coalesce(pp.inactive, false) limit 1;
  if p.id is null then return '{}'; end if;
  if p.lvl = 6 and p.preview_level is not null then
    return coalesce((select grants from permission_sets where name = eos_level_set(p.preview_level)), '{}');
  end if;
  select grants into setg from permission_sets where id = coalesce(p.permission_set_id, p.role_set);
  if setg is null then select grants into setg from permission_sets where name = eos_level_set(coalesce(p.lvl, 0)); end if;
  return array(select distinct x from unnest(coalesce(setg, '{}') || coalesce(p.extra_grants, '{}')) x where not (x = any(coalesce(p.denied_grants, '{}'))));
end $function$;
create or replace function public.eos_can(p_key text) returns boolean language sql stable security definer set search_path to 'public' as $$
  select p_key = any(public.eos_grants())
$$;
create or replace function public.eos_can_any(p_keys text[]) returns boolean language sql stable security definer set search_path to 'public' as $$
  select coalesce(public.eos_grants() && p_keys, false)
$$;
create or replace function public.eos_require(p_key text) returns void language plpgsql stable security definer set search_path to 'public' as $function$
declare lbl text;
begin
  if public.eos_can(p_key) then return; end if;
  select e->>'label' into lbl from jsonb_array_elements((select value from settings where key = 'permissions')) e where e->>'key' = p_key;
  raise exception 'You do not have permission to %. Ask an administrator to change your permission set.', lower(coalesce(lbl, p_key));
end $function$;
-- Which permission a write on a table needs
create or replace function public.eos_perm_for(p_table text, p_mode text) returns text language sql immutable as $$
  select case p_table
    when 'tasks' then case when p_mode = 'create' then 'tasks.create' else 'tasks.edit' end
    when 'work_orders' then case when p_mode = 'create' then 'work_orders.create' else 'work_orders.edit' end
    when 'projects' then case when p_mode = 'create' then 'projects.create' else 'projects.edit' end
    when 'documents' then case when p_mode = 'create' then 'documents.upload' else 'documents.edit' end
    when 'notes' then 'notes.add'
    when 'meetings' then 'meetings.edit'
    when 'people' then 'directory.manage'
    when 'organizations' then 'directory.manage'
    when 'roles' then 'roles.manage'
    when 'docs' then 'kb.edit'
    when 'dashboards' then 'dashboards.edit'
    when 'assets' then 'assets.edit'
    when 'form_records' then 'forms.submit'
    when 'commitments' then 'commitments.edit'
    when 'invoices' then 'invoices.approve'
    when 'task_templates' then 'templates.use'
    else case when p_table like 'pavement%' then 'pavement.manage' else 'settings.manage' end end
$$;

-- Editing: any grant that changes something (the per-table check comes next, inside each function)
create or replace function public.eos_editor() returns jsonb language plpgsql stable security definer set search_path to 'public' as $function$
declare cfg jsonb;
begin
  select value into cfg from settings where key = 'editing';
  if cfg is null then raise exception 'Editing is not configured'; end if;
  if not public.eos_can_any(array['tasks.edit','tasks.create','work_orders.edit','work_orders.create','projects.edit','projects.create','notes.add','documents.upload','documents.edit','forms.submit','directory.manage','roles.manage','settings.manage','records.delete','kb.edit','dashboards.edit','assets.edit','pavement.manage','meetings.edit','gis.edit','templates.use','commitments.edit','invoices.approve']::text[]) then
    raise exception 'Your permission set does not allow changes. Ask an administrator.';
  end if;
  return cfg;
end $function$;
create or replace function public.eos_can_edit() returns boolean language sql stable security definer set search_path to 'public' as $$
  select public.eos_can_any(array['tasks.edit','tasks.create','work_orders.edit','work_orders.create','projects.edit','projects.create','notes.add','documents.upload','documents.edit','forms.submit','directory.manage','roles.manage','settings.manage','records.delete','kb.edit','dashboards.edit','assets.edit','pavement.manage','meetings.edit','gis.edit','templates.use','commitments.edit','invoices.approve']::text[])
$$;

create or replace function public.eos_edit(p_table text, p_id uuid, p_patch jsonb, p_note text default null)
 returns jsonb language plpgsql security definer set search_path to 'public' as $function$
declare cfg jsonb; f jsonb; k text; oldrow jsonb; newrow jsonb; cols text[] := '{}'; patch jsonb := '{}';
        me uuid; batch uuid := gen_random_uuid(); n int := 0; v jsonb;
begin
  cfg := eos_editor();
  perform eos_require(eos_perm_for(p_table, 'edit'));
  f := cfg->'tables'->p_table->'fields';
  if f is null then raise exception 'Records in % cannot be edited from the app', p_table; end if;
  if p_patch is null or jsonb_typeof(p_patch) <> 'object' then raise exception 'Nothing to save'; end if;
  execute format('select to_jsonb(t) from public.%I t where id = $1', p_table) into oldrow using p_id;
  if oldrow is null then raise exception 'Record not found'; end if;
  for k, v in select * from jsonb_each(p_patch) loop
    if not f ? k then raise exception 'The field "%" cannot be edited from the app', k; end if;
    if jsonb_typeof(v) = 'string' and btrim(v #>> '{}') = '' then v := 'null'::jsonb; end if;
    if coalesce((f->k->>'required')::boolean,false) and v = 'null'::jsonb then raise exception '% is required', f->k->>'label'; end if;
    if v is distinct from oldrow->k then cols := cols || k; patch := patch || jsonb_build_object(k, v); end if;
  end loop;
  if cardinality(cols) = 0 then return jsonb_build_object('changed', 0); end if;

  perform set_config('eos.via', 'app', true);
  execute format('update public.%1$I t set (%2$s) = (select %3$s from jsonb_populate_record(null::public.%1$I, $1) r) where t.id = $2',
                 p_table,
                 (select string_agg(quote_ident(c), ', ') from unnest(cols) c),
                 (select string_agg('r.' || quote_ident(c), ', ') from unnest(cols) c))
    using patch, p_id;
  if p_table = 'documents' and 'location_text' = any(cols) then      -- a typed address is re-geocoded on the next pass
    update public.documents set latitude = null, longitude = null, geocoded_at = null, location_source = 'manual' where id = p_id;
  end if;
  perform set_config('eos.via', '', true);

  execute format('select to_jsonb(t) from public.%I t where id = $1', p_table) into newrow using p_id;
  select id into me from people where auth_user_id = auth.uid() limit 1;
  insert into record_changes (table_name, record_id, field, old_value, new_value, action, source, actor_id, batch_id, note)
  select p_table, p_id, c, oldrow->c, newrow->c, 'update', 'app', me, batch, p_note
    from unnest(cols) c where newrow->c is distinct from oldrow->c;
  get diagnostics n = row_count;
  return jsonb_build_object('changed', n, 'batch', batch,
                            'row', (select jsonb_object_agg(key, value) from jsonb_each(newrow) where f ? key or key in ('id','last_modified','updated_at')));
end $function$;

CREATE OR REPLACE FUNCTION public._pavement_load_v2(p text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare n_seg int; n_cond int; scan uuid;
begin
  perform eos_require('pavement.manage');
  select id into scan from pavement_scans where name = 'CYVL 2025 citywide scan';
  create temp table _r on commit drop as
    select a, case when a[34] like '% %' then jsonb_build_object('type','MultiLineString','coordinates',
                (select jsonb_agg(_pv_decode_polyline(x)) from unnest(string_to_array(a[34], ' ')) x))
              when coalesce(a[34],'') <> '' then jsonb_build_object('type','LineString','coordinates', _pv_decode_polyline(a[34])) end g
      from (select string_to_array(l, '#') a from regexp_split_to_table(p, E'\n') l where btrim(l) <> '') s;

  insert into pavement_segments as s (segment_key, street_name, from_street, to_street, asset_id, roadcl_id, length_ft, width_ft, area_sy,
         pci_class, ward, functional_class, funding_eligibility, surface_type, notes, geom, centroid_lat, centroid_lng,
         gis_layer, gis_synced_at, gis_attributes)
  select a[1], a[2], nullif(a[3],''), nullif(a[4],''), nullif(a[5],''), nullif(a[6],''), nullif(a[7],'')::numeric, nullif(a[8],'')::numeric,
         nullif(a[9],'')::numeric, nullif(a[10],''), nullif(a[11],''), nullif(a[12],''), nullif(btrim(a[13]),''), 'Asphalt', nullif(a[14],''),
         g,
         ((case when g->>'type'='LineString' then g->'coordinates' else g->'coordinates'->0 end)->(jsonb_array_length(case when g->>'type'='LineString' then g->'coordinates' else g->'coordinates'->0 end)/2)->>1)::float8,
         ((case when g->>'type'='LineString' then g->'coordinates' else g->'coordinates'->0 end)->(jsonb_array_length(case when g->>'type'='LineString' then g->'coordinates' else g->'coordinates'->0 end)/2)->>0)::float8,
         'streets_cyvl_update.gdb / pci_2025', now(),
         jsonb_strip_nulls(jsonb_build_object('surcharge', nullif(a[18],'')::numeric, 'source_file', 'streets_cyvl_update.gdb'))
    from _r
  on conflict (segment_key) do update set street_name = excluded.street_name, from_street = excluded.from_street, to_street = excluded.to_street,
         asset_id = excluded.asset_id, roadcl_id = excluded.roadcl_id, length_ft = excluded.length_ft, width_ft = excluded.width_ft, area_sy = excluded.area_sy,
         pci_class = excluded.pci_class, ward = excluded.ward, functional_class = excluded.functional_class, funding_eligibility = excluded.funding_eligibility,
         notes = coalesce(s.notes, excluded.notes), geom = coalesce(excluded.geom, s.geom),
         centroid_lat = coalesce(excluded.centroid_lat, s.centroid_lat), centroid_lng = coalesce(excluded.centroid_lng, s.centroid_lng),
         gis_layer = excluded.gis_layer, gis_synced_at = now(), gis_attributes = s.gis_attributes || excluded.gis_attributes;
  get diagnostics n_seg = row_count;

  insert into pavement_conditions as c (segment_id, survey_year, pci, source, scan_id, iri, distresses, notes)
  select s.id, y.yr, y.pci, y.src, case when y.src = 'CYVL' then scan end,
         case when y.src = 'CYVL' then nullif(r.a[17],'')::numeric end,
         case when y.src = 'CYVL' then jsonb_strip_nulls(jsonb_build_object(
              'alligator_cracking_pct', nullif(r.a[19],'')::numeric, 'long_trans_cracking_pct', nullif(r.a[20],'')::numeric,
              'block_cracking_pct', nullif(r.a[21],'')::numeric, 'crack_seal_pct', nullif(r.a[22],'')::numeric,
              'bumpiness_pct', nullif(r.a[23],'')::numeric, 'pothole_pct', nullif(r.a[24],'')::numeric, 'patch_pct', nullif(r.a[25],'')::numeric))
              else '{}'::jsonb end,
         y.note
    from _r r
    join pavement_segments s on s.segment_key = r.a[1]
    cross join lateral (values
       (2017, nullif(r.a[26],'')::numeric, 'Legacy', null::text),
       (2019, nullif(r.a[27],'')::numeric, 'Legacy', null),
       (2021, nullif(r.a[28],'')::numeric, 'Legacy', nullif(r.a[15],'')),
       (2022, nullif(r.a[29],'')::numeric, 'Legacy', case when r.a[29] <> '' and r.a[29] = r.a[28] then 'Same value as 2021 in the source file' end),
       (2023, nullif(r.a[30],'')::numeric, 'Legacy', null),
       (2024, nullif(r.a[31],'')::numeric, 'Legacy', nullif(r.a[16],'')),
       (2025, nullif(r.a[32],'')::numeric, 'CYVL', case when r.a[33] = '1' then 'PCI was 0 in the source file; left blank for review' end)
    ) y(yr, pci, src, note)
   where y.pci is not null or y.note is not null or (y.src = 'CYVL' and r.a[19] <> '')
  on conflict (segment_id, survey_year, source) do update set pci = excluded.pci, iri = excluded.iri, distresses = excluded.distresses,
         notes = coalesce(excluded.notes, c.notes), scan_id = excluded.scan_id;
  get diagnostics n_cond = row_count;
  return jsonb_build_object('segments', n_seg, 'conditions', n_cond);
end $function$;

CREATE OR REPLACE FUNCTION public.eos_auth_accounts()
 RETURNS TABLE(id uuid, email character varying, created_at timestamp with time zone, confirmed boolean)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'auth'
AS $function$
  select u.id, u.email, u.created_at, u.email_confirmed_at is not null
  from auth.users u
  where public.eos_can('directory.manage')
$function$;

CREATE OR REPLACE FUNCTION public.eos_auth_signins()
 RETURNS TABLE(id uuid, last_sign_in_at timestamp with time zone, recovery_sent_at timestamp with time zone, banned boolean)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'auth'
AS $function$
  select u.id, u.last_sign_in_at, u.recovery_sent_at, (u.banned_until is not null and u.banned_until > now())
  from auth.users u
  where public.eos_can('directory.manage')
$function$;

CREATE OR REPLACE FUNCTION public.eos_check_commitment(p_commitment uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare c public.commitments%rowtype; org text; f jsonb := '[]'::jsonb; ex date; maxto date; sumfee numeric;
begin
  perform eos_require('commitments.edit');
  select * into c from public.commitments where id = p_commitment;
  if not found then raise exception 'Commitment not found'; end if;
  select name into org from public.organizations where id = c.vendor_org_id;
  ex := coalesce(c.effective_date, nullif(c.details->>'executed_on','')::date);

  if c.funding_source_id is null then
    f := eos_add(f, eos_finding('funding_source_missing','commitment','No funding source is set on this commitment.'));
  end if;
  if c.effective_date is null then
    f := eos_add(f, eos_finding('effective_date_missing','commitment',
           'The effective date is blank'||case when ex is not null then ' (last signature '||ex||')' else '' end||'.',
           jsonb_build_object('executed_on', ex)));
  end if;
  if coalesce((c.details->>'full_term_blank')::boolean, false) then
    f := eos_add(f, eos_finding('term_not_stated','commitment','The full term is not stated on the contract review form.'));
  end if;
  select max((r->>'effective_to')::date) into maxto from jsonb_array_elements(c.rates) r;
  if maxto is not null and c.expiration_date is not null and maxto < c.expiration_date then
    f := eos_add(f, eos_finding('rates_end_before_expiration','commitment',
           'The rate schedule ends '||maxto||' but the commitment runs to '||c.expiration_date||'.',
           jsonb_build_object('rates_end', maxto, 'expiration', c.expiration_date)));
  end if;
  if ex is not null and c.expiration_date is not null and c.expiration_date > (ex + interval '3 years')::date then
    f := eos_add(f, eos_finding('term_over_three_years','commitment','The term runs more than three years from execution.',
           jsonb_build_object('executed_on', ex, 'expiration', c.expiration_date)));
  end if;
  select coalesce(sum((l->>'fee')::numeric), 0) into sumfee from jsonb_array_elements(c.lines) l;
  if jsonb_array_length(c.lines) > 0 and abs(sumfee - c.fee_total) > 0.005 then
    f := eos_add(f, eos_finding('lines_total_mismatch','commitment',
           'Line fees add to '||sumfee||' but the commitment fee is '||c.fee_total||'.',
           jsonb_build_object('lines_total', sumfee, 'fee_total', c.fee_total)));
  end if;
  if c.details->>'po_vendor_name' is not null
     and eos_name_key(c.details->>'po_vendor_name') <> eos_name_key(org)
     and not exists (select 1 from unnest(c.aliases) a where eos_name_key(a) = eos_name_key(c.details->>'po_vendor_name')) then
    f := eos_add(f, eos_finding('vendor_name_mismatch','commitment',
           'The PO vendor is "'||(c.details->>'po_vendor_name')||'" but the contract vendor is "'||org||'".',
           jsonb_build_object('po_vendor', c.details->>'po_vendor_name', 'contract_vendor', org)));
  end if;
  return f;
end $function$;

CREATE OR REPLACE FUNCTION public.eos_check_invoice(p_invoice uuid, p_as_of date DEFAULT CURRENT_DATE)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  i public.invoices%rowtype; c public.commitments%rowtype;
  f jsonb := '[]'::jsonb; vmap jsonb; ex date; term jsonb;
  ln jsonb; dt jsonb; cl jsonb; mapped text; ftype text;
  s numeric; prior numeric; ceil numeric; expect numeric; rate_expected numeric;
  sum_lines numeric := 0; committed numeric; fs_amount numeric;
  dispute_by date; pay_by date; lag_days int; soon int; po_fy int; svc_fy int;
begin
  perform eos_require('invoices.approve');
  select * into i from public.invoices where id = p_invoice;
  if not found then raise exception 'Invoice not found'; end if;

  if i.commitment_id is null then
    return eos_add(f, eos_finding('no_match','invoice','No commitment matches this invoice''s PO or job number.',
             jsonb_build_object('po_number', i.po_number, 'vendor_job_number', i.vendor_job_number)));
  end if;
  select * into c from public.commitments where id = i.commitment_id;
  vmap := coalesce(c.details->'vendor_phase_map', '{}'::jsonb);
  ex   := coalesce(c.effective_date, nullif(c.details->>'executed_on','')::date);
  term := c.terms;

  if i.vendor_org_id <> c.vendor_org_id then
    f := eos_add(f, eos_finding('vendor_mismatch','invoice','The invoice vendor is not the vendor on the commitment.'));
  end if;
  if i.po_number is null and cardinality(c.po_numbers) > 0 then
    f := eos_add(f, eos_finding('po_mismatch','invoice','The invoice shows no PO number; this commitment uses '||array_to_string(c.po_numbers, ', ')||'.'));
  elsif i.po_number is not null and cardinality(c.po_numbers) > 0 and not (i.po_number = any(c.po_numbers)) then
    f := eos_add(f, eos_finding('po_mismatch','invoice','PO '||i.po_number||' is not on this commitment ('||array_to_string(c.po_numbers, ', ')||').'));
  end if;
  if i.vendor_job_number is not null and cardinality(c.vendor_job_numbers) > 0 and not (i.vendor_job_number = any(c.vendor_job_numbers)) then
    f := eos_add(f, eos_finding('job_number_mismatch','invoice','Vendor job number '||i.vendor_job_number||' is not on this commitment.'));
  end if;
  if c.status <> 'executed' then
    f := eos_add(f, eos_finding('commitment_not_executed','invoice','The commitment is '||c.status||', not executed.'));
  end if;

  if ex is not null and i.period_start is not null and i.period_start < ex then
    f := eos_add(f, eos_finding('work_before_execution','invoice',
           'The service period starts '||i.period_start||', before the commitment was executed ('||ex||').',
           jsonb_build_object('period_start', i.period_start, 'executed_on', ex)));
  end if;
  if c.expiration_date is not null and i.period_end is not null and i.period_end > c.expiration_date then
    f := eos_add(f, eos_finding('period_after_expiration','invoice','The service period ends after the commitment expires ('||c.expiration_date||').'));
  end if;
  if i.invoice_date is not null then
    lag_days := i.received_at::date - i.invoice_date;
    if lag_days > eos_rule_param('invoice_lag','invoice','days',14) then
      f := eos_add(f, eos_finding('invoice_lag','invoice','Received '||lag_days||' days after the invoice date.',
             jsonb_build_object('invoice_date', i.invoice_date, 'received', i.received_at::date, 'days', lag_days), 'info'));
    end if;
    dispute_by := case coalesce(term->>'dispute_from','invoice_date') when 'receipt' then i.received_at::date else i.invoice_date end
                  + coalesce((term->>'dispute_days')::int, 30);
    pay_by     := case coalesce(term->>'payment_from','receipt') when 'invoice_date' then i.invoice_date else i.received_at::date end
                  + coalesce((term->>'payment_days')::int, 30);
    f := eos_add(f, eos_finding('payment_clock','invoice',
           'Written dispute notice due by '||to_char(dispute_by,'FMMon FMDD, YYYY')||'; payment due by '||to_char(pay_by,'FMMon FMDD, YYYY')||'.',
           jsonb_build_object('dispute_by', dispute_by, 'pay_by', pay_by), 'info'));
    soon := eos_rule_param('deadline_soon','invoice','days',7)::int;
    if dispute_by - p_as_of <= soon then
      f := eos_add(f, eos_finding('deadline_soon','invoice',
             case when dispute_by < p_as_of then 'The written dispute window closed on '||to_char(dispute_by,'FMMon FMDD, YYYY')||'.'
                  else 'The written dispute window closes in '||(dispute_by - p_as_of)||' day(s), on '||to_char(dispute_by,'FMMon FMDD, YYYY')||'.' end,
             jsonb_build_object('dispute_by', dispute_by, 'as_of', p_as_of)));
    end if;
  end if;

  po_fy  := nullif(c.details->>'po_fiscal_year','')::int;
  svc_fy := eos_fy(coalesce(i.period_end, i.invoice_date));
  if po_fy is not null and svc_fy is not null and po_fy <> svc_fy then
    f := eos_add(f, eos_finding('fiscal_year_mismatch','invoice',
           'The PO is fiscal year '||po_fy||' but the service period falls in fiscal year '||svc_fy||'. Finance should confirm which funds pay.',
           jsonb_build_object('po_fy', po_fy, 'service_fy', svc_fy)));
  end if;

  for ln in select value from jsonb_array_elements(i.lines) loop
    mapped := coalesce(vmap->>(ln->>'code'), ln->>'code');
    sum_lines := sum_lines + coalesce((ln->>'amount')::numeric, 0);
    cl := null;
    select l into cl from jsonb_array_elements(c.lines) l where l->>'code' = mapped limit 1;
    if cl is null then
      f := eos_add(f, eos_finding('unknown_line','invoice','Line '||(ln->>'code')||' is not a line on this commitment.',
             jsonb_build_object('code', ln->>'code')));
      continue;
    end if;
    ftype := cl->>'fee_type';

    if jsonb_typeof(ln->'detail') = 'array' then
      s := 0;
      for dt in select value from jsonb_array_elements(ln->'detail') loop
        s := s + coalesce((dt->>'amount')::numeric, 0);
        if dt ? 'hours' and dt ? 'rate' and abs((dt->>'hours')::numeric * (dt->>'rate')::numeric - (dt->>'amount')::numeric) > 0.005 then
          f := eos_add(f, eos_finding('arithmetic','invoice',
                 'Line '||(ln->>'code')||': hours times rate does not equal the amount for '||(dt->>'name')||'.',
                 jsonb_build_object('line', ln->>'code', 'person', dt->>'name', 'hours', dt->>'hours', 'rate', dt->>'rate', 'amount', dt->>'amount')));
        end if;
        if dt ? 'rate' and jsonb_array_length(c.rates) > 0 then
          rate_expected := null;
          select (r->>'rate')::numeric into rate_expected from jsonb_array_elements(c.rates) r
           where eos_name_key(r->>'name') = eos_name_key(dt->>'name')
             and (r->>'effective_from' is null or coalesce(i.period_end, i.invoice_date)   >= (r->>'effective_from')::date)
             and (r->>'effective_to'   is null or coalesce(i.period_start, i.invoice_date) <= (r->>'effective_to')::date)
           limit 1;
          if not found then
            f := eos_add(f, eos_finding('rate_mismatch','invoice','Line '||(ln->>'code')||': '||(dt->>'name')||' is not on the rate schedule.',
                   jsonb_build_object('line', ln->>'code', 'person', dt->>'name')));
          elsif rate_expected <> (dt->>'rate')::numeric then
            f := eos_add(f, eos_finding('rate_mismatch','invoice',
                   'Line '||(ln->>'code')||': '||(dt->>'name')||' billed at '||(dt->>'rate')||' but the schedule rate is '||rate_expected||'.',
                   jsonb_build_object('line', ln->>'code', 'person', dt->>'name', 'billed', dt->>'rate', 'schedule', rate_expected)));
          end if;
        end if;
      end loop;
      if abs(s - coalesce((ln->>'amount')::numeric, 0)) > 0.005 then
        f := eos_add(f, eos_finding('arithmetic','invoice','Line '||(ln->>'code')||': detail rows add to '||s||' but the line shows '||(ln->>'amount')||'.',
               jsonb_build_object('line', ln->>'code', 'detail_total', s, 'line_amount', ln->>'amount')));
      end if;
    end if;

    if ftype = 'lump_sum' and ln ? 'pct_complete' then
      expect := round((cl->>'fee')::numeric * (ln->>'pct_complete')::numeric / 100 - coalesce((ln->>'prior_billed')::numeric, 0), 2);
      if abs(expect - coalesce((ln->>'amount')::numeric, 0)) > 0.005 then
        f := eos_add(f, eos_finding('arithmetic','invoice','Line '||(ln->>'code')||': '||(ln->>'pct_complete')||'% of the lump sum less prior billing is '||expect||', not '||(ln->>'amount')||'.',
               jsonb_build_object('line', ln->>'code', 'expected', expect, 'billed', ln->>'amount')));
      end if;
    end if;

    if ftype = 'unit_price' then
      if ln ? 'qty' and ln ? 'unit_price' and abs((ln->>'qty')::numeric * (ln->>'unit_price')::numeric - coalesce((ln->>'amount')::numeric,0)) > 0.005 then
        f := eos_add(f, eos_finding('arithmetic','invoice','Line '||(ln->>'code')||': quantity times unit price does not equal the amount.',
               jsonb_build_object('line', ln->>'code')));
      end if;
      if ln ? 'unit_price' and cl ? 'unit_price' and abs((ln->>'unit_price')::numeric - (cl->>'unit_price')::numeric) > 0.005 then
        f := eos_add(f, eos_finding('unit_price_mismatch','invoice','Line '||(ln->>'code')||': unit price '||(ln->>'unit_price')||' differs from the commitment price '||(cl->>'unit_price')||'.',
               jsonb_build_object('line', ln->>'code', 'billed', ln->>'unit_price', 'commitment', cl->>'unit_price')));
      end if;
    end if;

    select coalesce(sum((l->>'amount')::numeric), 0) into prior
      from public.invoices o, jsonb_array_elements(o.lines) l
     where o.commitment_id = c.id and o.id <> i.id and o.status not in ('void','rejected')
       and coalesce(vmap->>(l->>'code'), l->>'code') = mapped;
    ceil := coalesce((cl->>'ceiling')::numeric, (cl->>'fee')::numeric);
    if ceil is not null and prior + coalesce((ln->>'amount')::numeric, 0) > ceil + 0.005 then
      f := eos_add(f, eos_finding('over_line_ceiling','invoice',
             'Line '||mapped||' would reach '||(prior + coalesce((ln->>'amount')::numeric,0))||' against a ceiling of '||ceil||'.',
             jsonb_build_object('line', mapped, 'prior', prior, 'this', ln->>'amount', 'ceiling', ceil)));
    end if;

    if coalesce((cl->>'requires_authorization')::boolean, ftype = 'allowance')
       and nullif(btrim(coalesce(ln->>'authorization_ref','')), '') is null then
      f := eos_add(f, eos_finding('allowance_authorization','invoice',
             'Line '||mapped||' is an allowance; the City''s written direction for this work is not referenced.',
             jsonb_build_object('line', mapped)));
    end if;

    if ln->>'basis' = 'reimbursable' and term->>'reimbursables' = 'none' then
      f := eos_add(f, eos_finding('reimbursable_not_allowed','invoice','Line '||(ln->>'code')||' is a reimbursable; this commitment allows none.',
             jsonb_build_object('line', ln->>'code')));
    end if;

    if cl ? 'deliverable_due' and ex is not null and (cl->>'deliverable_due')::date < ex then
      f := eos_add(f, eos_finding('pre_effective_deliverable','invoice',
             'Line '||mapped||' covers a deliverable due '||(cl->>'deliverable_due')||', before this commitment was executed ('||ex||'). Confirm cumulative billing against the earlier agreement.',
             jsonb_build_object('line', mapped, 'deliverable_due', cl->>'deliverable_due', 'executed_on', ex)));
    end if;
  end loop;

  if abs(sum_lines - i.amount) > 0.005 then
    f := eos_add(f, eos_finding('arithmetic','invoice','The lines add to '||sum_lines||' but the invoice total is '||i.amount||'.',
           jsonb_build_object('lines_total', sum_lines, 'invoice_total', i.amount)));
  end if;
  select coalesce(sum(o.amount), 0) into prior from public.invoices o
   where o.commitment_id = c.id and o.id <> i.id and o.status not in ('void','rejected');
  if prior + i.amount > c.fee_total + 0.005 then
    f := eos_add(f, eos_finding('over_commitment','invoice','Billing would reach '||(prior + i.amount)||' against a commitment fee of '||c.fee_total||'.',
           jsonb_build_object('prior', prior, 'this', i.amount, 'fee_total', c.fee_total)));
  end if;

  if c.details->'remit_to' is not null and i.remit_to ? 'address'
     and lower(btrim(i.remit_to->>'address')) <> lower(btrim(c.details->'remit_to'->>'address')) then
    f := eos_add(f, eos_finding('remit_to_changed','invoice','The remit-to address differs from the one on file. Verify by phone before any payment.',
           jsonb_build_object('on_file', c.details->'remit_to'->>'address', 'on_invoice', i.remit_to->>'address')));
  end if;
  if exists (select 1 from public.invoices o
              where o.vendor_org_id = i.vendor_org_id and o.id <> i.id and o.status not in ('void','rejected')
                and o.amount = i.amount and o.period_start is not distinct from i.period_start
                and o.period_end is not distinct from i.period_end) then
    f := eos_add(f, eos_finding('possible_duplicate','invoice','Another live invoice from this vendor has the same amount and service period.'));
  end if;
  if coalesce((term->>'requires_progress_report')::boolean, false) and not coalesce((i.details->>'has_progress_report')::boolean, false) then
    f := eos_add(f, eos_finding('missing_progress_report','invoice','The commitment requires a progress report with each invoice; none is attached.'));
  end if;
  if c.funding_source_id is not null then
    select amount into fs_amount from public.funding_sources where id = c.funding_source_id;
    select coalesce(sum(fee_total), 0) into committed from public.commitments
     where funding_source_id = c.funding_source_id and status = 'executed';
    if committed > fs_amount then
      f := eos_add(f, eos_finding('funding_overrun','invoice','Executed commitments ('||committed||') exceed the funding source ('||fs_amount||').',
             jsonb_build_object('committed', committed, 'funding_amount', fs_amount)));
    end if;
  end if;

  return f || eos_check_commitment(c.id);
end $function$;

CREATE OR REPLACE FUNCTION public.eos_invoice_mark_paid(p_invoice uuid, p_amount numeric, p_date date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare i public.invoices%rowtype;
begin
  perform eos_require('invoices.approve');
  select * into i from public.invoices where id = p_invoice for update;
  if not found then raise exception 'Invoice not found'; end if;
  if i.status <> 'released' then raise exception 'Only a released invoice can be marked paid (status is %)', i.status; end if;
  perform set_config('eos.via', 'finance', true);
  update public.invoices set status = 'paid', paid_at = p_date, paid_amount = p_amount where id = p_invoice;
  perform set_config('eos.via', '', true);
  insert into public.record_changes (table_name, record_id, field, old_value, new_value, action, source, actor_id, note)
  values ('invoices', p_invoice, 'status', to_jsonb(i.status), to_jsonb('paid'::text), 'update', 'app', eos_person_id(),
          'PAID: '||p_amount||' on '||p_date);
  return jsonb_build_object('status', 'paid');
end $function$;

CREATE OR REPLACE FUNCTION public.eos_invoice_reject(p_invoice uuid, p_reason text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare me uuid := eos_person_id(); i public.invoices%rowtype; roster jsonb; idx int := -1; k int;
begin
  if coalesce(btrim(p_reason), '') = '' then raise exception 'A reason is required to reject an invoice'; end if;
  select * into i from public.invoices where id = p_invoice for update;
  if not found then raise exception 'Invoice not found'; end if;
  if i.status not in ('awaiting_vendor','awaiting_signoff') then
    raise exception 'This invoice is not waiting for a signature (status is %)', i.status;
  end if;
  roster := i.signers;
  for k in 0 .. jsonb_array_length(roster) - 1 loop
    if roster->k->>'status' = 'pending' and (roster->k->>'person_id')::uuid = me then idx := k; exit; end if;
  end loop;
  if idx < 0 and not eos_can('invoices.approve') then raise exception 'Only a named signer can reject this invoice'; end if;
  if idx >= 0 then
    roster := jsonb_set(roster, array[idx::text],
                (roster->idx) || jsonb_build_object('status', 'rejected', 'comment', p_reason,
                                   'at', to_char(now() at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')));
  end if;
  perform set_config('eos.via', 'finance', true);
  update public.invoices set signers = roster, status = 'rejected' where id = p_invoice;
  perform set_config('eos.via', '', true);
  insert into public.record_changes (table_name, record_id, field, old_value, new_value, action, source, actor_id, note)
  values ('invoices', p_invoice, 'status', to_jsonb(i.status), to_jsonb('rejected'::text), 'update', 'app', me, 'REJECT: '||p_reason);
  return jsonb_build_object('status', 'rejected');
end $function$;

CREATE OR REPLACE FUNCTION public.eos_invoice_release(p_invoice uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare i public.invoices%rowtype; cfg jsonb; addr text; dom text;
begin
  perform eos_require('invoices.approve');
  select * into i from public.invoices where id = p_invoice for update;
  if not found then raise exception 'Invoice not found'; end if;
  if i.status <> 'ready' then raise exception 'Only a fully signed invoice can be released (status is %)', i.status; end if;
  select value into cfg from public.settings where key = 'invoice_release';
  if cfg is null then raise exception 'No release address is configured'; end if;
  addr := lower(btrim(cfg->>'address'));
  dom  := split_part(addr, '@', 2);
  if dom = '' or not ((cfg->'allowed_domains') ? dom) then
    raise exception 'Release address % is not on the allowed domains', addr;
  end if;
  perform set_config('eos.via', 'finance', true);
  update public.invoices set status = 'released', released_at = now(), released_to = addr, locked = true where id = p_invoice;
  perform set_config('eos.via', '', true);
  insert into public.record_changes (table_name, record_id, field, old_value, new_value, action, source, actor_id, note)
  values ('invoices', p_invoice, 'status', to_jsonb(i.status), to_jsonb('released'::text), 'update', 'app', eos_person_id(),
          'RELEASE: to '||addr);
  return jsonb_build_object('status', 'released', 'released_to', addr);
end $function$;

CREATE OR REPLACE FUNCTION public.eos_invoice_route(p_invoice uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare i public.invoices%rowtype; c public.commitments%rowtype; roles jsonb; r text; pid uuid; nm text;
        roster jsonb := '[]'::jsonb; k int := 0; missing text[] := '{}'; first_role text;
begin
  perform eos_require('invoices.approve');
  select * into i from public.invoices where id = p_invoice for update;
  if not found then raise exception 'Invoice not found'; end if;
  if i.status <> 'checked' then
    raise exception 'The invoice must pass its checks before routing (status is %)', i.status;
  end if;
  select * into c from public.commitments where id = i.commitment_id;
  select s.value->'signers'->c.scenario into roles from public.settings s where s.key = 'invoice_rules';
  if roles is null then roles := '["project_manager"]'::jsonb; end if;

  for r in select jsonb_array_elements_text(roles) loop
    pid := null;
    if r = 'vendor' then
      if i.source = 'vendor_portal' then pid := i.submitted_by; else continue; end if;
    elsif r = 'project_manager' then
      pid := c.project_manager_id;
    else
      select (x->>'person_id')::uuid into pid from jsonb_array_elements(c.signer_roles) x where x->>'role' = r limit 1;
    end if;
    if pid is null then missing := missing || r; continue; end if;
    select full_name into nm from public.people where id = pid;
    k := k + 1;
    roster := roster || jsonb_build_array(jsonb_build_object('order', k, 'role', r, 'person_id', pid, 'name', nm, 'status', 'pending'));
  end loop;

  perform set_config('eos.via', 'finance', true);
  if cardinality(missing) > 0 then
    update public.invoices
       set findings = findings || jsonb_build_array(eos_finding('missing_signer_role','invoice','No person is named for: '||array_to_string(missing, ', ')||'.')),
           check_result = 'hold', status = 'hold'
     where id = p_invoice;
    perform set_config('eos.via', '', true);
    return jsonb_build_object('routed', false, 'missing', to_jsonb(missing));
  end if;
  first_role := roster->0->>'role';
  update public.invoices
     set signers = roster, status = case when first_role = 'vendor' then 'awaiting_vendor' else 'awaiting_signoff' end
   where id = p_invoice;
  perform set_config('eos.via', '', true);
  insert into public.record_changes (table_name, record_id, field, old_value, new_value, action, source, actor_id, note)
  values ('invoices', p_invoice, 'signers', i.signers, roster, 'update', 'app', eos_person_id(), 'ROUTE: signer roster built for scenario '||c.scenario);
  return jsonb_build_object('routed', true, 'roster', roster);
end $function$;

CREATE OR REPLACE FUNCTION public.eos_match_invoice(p_invoice uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare i public.invoices%rowtype; ids uuid[];
begin
  perform eos_require('invoices.approve');
  select * into i from public.invoices where id = p_invoice for update;
  if not found then raise exception 'Invoice not found'; end if;
  select array_agg(id) into ids from public.commitments
   where status <> 'cancelled' and vendor_org_id = i.vendor_org_id
     and ((i.po_number is not null and i.po_number = any(po_numbers))
       or (i.vendor_job_number is not null and i.vendor_job_number = any(vendor_job_numbers)));
  if ids is not null and cardinality(ids) = 1 then
    perform set_config('eos.via', 'finance', true);
    update public.invoices set commitment_id = ids[1] where id = p_invoice;
    perform set_config('eos.via', '', true);
    return jsonb_build_object('matched', true, 'commitment_id', ids[1]);
  end if;
  return jsonb_build_object('matched', false, 'candidates', coalesce(cardinality(ids), 0));
end $function$;

CREATE OR REPLACE FUNCTION public.eos_pavement_import_files()
 RETURNS TABLE(name text, size bigint, updated_at timestamp with time zone)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'storage'
AS $function$
  select o.name, (o.metadata->>'size')::bigint, o.updated_at from storage.objects o
   where o.bucket_id = 'gis-imports' and eos_can('pavement.manage') order by o.updated_at desc;
$function$;

CREATE OR REPLACE FUNCTION public.eos_pavement_import_run(p_path text DEFAULT 'beverly_pavement_pci_2025.geojson'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'vault', 'net', 'storage'
AS $function$
declare tok text; rid bigint; run uuid; me uuid;
begin
  perform eos_require('pavement.manage');
  if not exists (select 1 from storage.objects where bucket_id = 'gis-imports' and name = p_path) then
    raise exception 'No file named % in the gis-imports storage bucket', p_path; end if;
  select decrypted_secret into tok from vault.decrypted_secrets where name = 'eos_cron_token';
  select id into me from people where auth_user_id = auth.uid() limit 1;
  insert into pavement_import_runs (path, requested_by) values (p_path, me) returning id into run;
  select net.http_post(
      url := 'https://llwqcwrkbyniffjnwxym.supabase.co/functions/v1/pavement-import',
      headers := jsonb_build_object('Content-Type','application/json','x-eos-token', tok),
      body := jsonb_build_object('path', p_path, 'run_id', run),
      timeout_milliseconds := 300000) into rid;
  update pavement_import_runs set request_id = rid where id = run;
  return jsonb_build_object('run_id', run, 'request_id', rid);
end $function$;

CREATE OR REPLACE FUNCTION public.eos_pavement_recon_decide(p_id uuid, p_action text, p_segment_ids uuid[] DEFAULT NULL::uuid[], p_status text DEFAULT NULL::text, p_plan_year integer DEFAULT NULL::integer, p_treatment_id uuid DEFAULT NULL::uuid, p_wo_status text DEFAULT NULL::text, p_rename boolean DEFAULT false, p_note text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare r pavement_recon; me uuid; seg uuid; n int := 0; prog uuid; st text; yr int; tr uuid; patch jsonb := '{}'; ev text; wid uuid;
begin
  perform eos_require('pavement.manage');
  select * into r from pavement_recon where id = p_id for update;
  if r.id is null then raise exception 'Review row not found'; end if;
  if r.decision <> 'pending' then raise exception '% was already %', r.street, r.decision; end if;
  select id into me from people where auth_user_id = auth.uid() limit 1;
  if p_action = 'skip' then
    update pavement_recon set decision='skipped', decided_at=now(), decided_by=me, decision_note=p_note where id = p_id;
    return jsonb_build_object('skipped', true);
  end if;
  if p_action <> 'approve' then raise exception 'Unknown action %', p_action; end if;
  st := coalesce(p_status, r.proposed_status); yr := coalesce(p_plan_year, r.proposed_year); tr := coalesce(p_treatment_id, r.treatment_id);
  select project_id into prog from work_orders where id = r.work_order_id;
  if prog is null then select id into prog from projects where name = r.season || ' Paving Program' limit 1; end if;
  ev := (select string_agg(e->>'date' || ' ' || coalesce(e->>'from','') || ': ' || coalesce(e->>'text',''), E'\n') from jsonb_array_elements(r.evidence) e);
  foreach seg in array coalesce(p_segment_ids, r.suggested_segment_ids) loop
    select id into wid from pavement_work where segment_id = seg and (work_order_id = r.work_order_id or (r.work_order_id is null and plan_year = yr)) limit 1;
    if wid is null then
      insert into pavement_work (segment_id, project_id, work_order_id, plan_year, treatment_id, status, completed_date, notes)
      values (seg, prog, r.work_order_id, yr, tr, st, case when st = 'Complete' then r.completed_date end,
              concat_ws(E'\n', r.summary, nullif(r.reason,''), nullif(p_note,''), 'Evidence:', ev));
    else
      update pavement_work set plan_year = yr, treatment_id = coalesce(tr, treatment_id), status = st,
             completed_date = case when st = 'Complete' then coalesce(r.completed_date, completed_date) else completed_date end,
             notes = concat_ws(E'\n', notes, r.summary, nullif(p_note,''))
       where id = wid;
    end if;
    n := n + 1;
  end loop;
  if r.work_order_id is not null then
    if coalesce(p_wo_status, r.proposed_wo_status) is not null then patch := patch || jsonb_build_object('status', coalesce(p_wo_status, r.proposed_wo_status)); end if;
    if p_rename and r.proposed_wo_name is not null then patch := patch || jsonb_build_object('project_name', r.proposed_wo_name); end if;
    if r.reason is not null then patch := patch || jsonb_build_object('next_steps', concat_ws(' — ', r.summary, r.reason)); end if;
    if patch <> '{}'::jsonb then perform eos_edit('work_orders', r.work_order_id, patch, '2026 paving review'); end if;
  end if;
  update pavement_recon set decision='approved', decided_at=now(), decided_by=me, decision_note=p_note,
         suggested_segment_ids = coalesce(p_segment_ids, suggested_segment_ids) where id = p_id;
  return jsonb_build_object('approved', true, 'sections', n);
end $function$;

CREATE OR REPLACE FUNCTION public.eos_pavement_sync(p_segments jsonb, p_conditions jsonb DEFAULT '[]'::jsonb, p_layer text DEFAULT 'STR_centerline'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare n_ins int := 0; n_upd int := 0; n_cond int := 0; me uuid;
begin
  perform eos_require('pavement.manage');
  if jsonb_typeof(coalesce(p_segments,'[]')) <> 'array' or jsonb_typeof(coalesce(p_conditions,'[]')) <> 'array' then
    raise exception 'Segments and conditions must be arrays'; end if;

  with src as (
    select nullif(btrim(e->>'segment_key'),'') segment_key, nullif(btrim(e->>'street_name'),'') street_name,
           nullif(btrim(e->>'from_street'),'') from_street, nullif(btrim(e->>'to_street'),'') to_street,
           nullif(btrim(e->>'asset_id'),'') asset_id, nullif(btrim(e->>'roadcl_id'),'') roadcl_id,
           nullif(e->>'length_ft','')::numeric length_ft, nullif(e->>'width_ft','')::numeric width_ft, nullif(e->>'area_sy','')::numeric area_sy,
           nullif(btrim(e->>'acceptance_status'),'') acceptance_status, nullif(btrim(e->>'functional_class'),'') functional_class,
           nullif(btrim(e->>'ward'),'') ward, nullif(btrim(e->>'surface_type'),'') surface_type,
           nullif(btrim(e->>'funding_eligibility'),'') funding_eligibility, nullif(btrim(e->>'pci_class'),'') pci_class,
           nullif(e->>'last_paved_year','')::numeric::int last_paved_year, nullif(btrim(e->>'notes'),'') notes,
           nullif(e->>'gis_object_id','')::numeric::bigint gis_object_id,
           nullif(e->>'centroid_lat','')::double precision centroid_lat, nullif(e->>'centroid_lng','')::double precision centroid_lng,
           case when jsonb_typeof(e->'geom') = 'object' then e->'geom' end geom,
           case when jsonb_typeof(e->'attrs') = 'object' then jsonb_strip_nulls(e->'attrs') else '{}'::jsonb end attrs
      from jsonb_array_elements(coalesce(p_segments,'[]')) e
  ), up as (
    insert into pavement_segments as s (segment_key, street_name, from_street, to_street, asset_id, roadcl_id, length_ft, width_ft, area_sy,
           acceptance_status, functional_class, ward, surface_type, funding_eligibility, pci_class, last_paved_year, notes,
           gis_layer, gis_object_id, centroid_lat, centroid_lng, geom, gis_attributes, gis_synced_at)
    select segment_key, coalesce(street_name,'(unnamed)'), from_street, to_street, asset_id, roadcl_id, length_ft, width_ft, area_sy,
           acceptance_status, functional_class, ward, surface_type, funding_eligibility, pci_class, last_paved_year, notes,
           p_layer, gis_object_id, centroid_lat, centroid_lng, geom, attrs, now()
      from src where segment_key is not null
    on conflict (segment_key) do update set
      street_name = coalesce(excluded.street_name, s.street_name), from_street = coalesce(excluded.from_street, s.from_street),
      to_street = coalesce(excluded.to_street, s.to_street), asset_id = coalesce(excluded.asset_id, s.asset_id),
      roadcl_id = coalesce(excluded.roadcl_id, s.roadcl_id), length_ft = coalesce(excluded.length_ft, s.length_ft),
      width_ft = coalesce(excluded.width_ft, s.width_ft), area_sy = coalesce(excluded.area_sy, s.area_sy),
      acceptance_status = coalesce(excluded.acceptance_status, s.acceptance_status),
      functional_class = coalesce(excluded.functional_class, s.functional_class), ward = coalesce(excluded.ward, s.ward),
      surface_type = coalesce(excluded.surface_type, s.surface_type), funding_eligibility = coalesce(excluded.funding_eligibility, s.funding_eligibility),
      pci_class = coalesce(excluded.pci_class, s.pci_class),
      last_paved_year = greatest(excluded.last_paved_year, s.last_paved_year),
      notes = coalesce(s.notes, excluded.notes),
      gis_layer = excluded.gis_layer, gis_object_id = coalesce(excluded.gis_object_id, s.gis_object_id),
      centroid_lat = coalesce(excluded.centroid_lat, s.centroid_lat), centroid_lng = coalesce(excluded.centroid_lng, s.centroid_lng),
      geom = coalesce(excluded.geom, s.geom), gis_attributes = s.gis_attributes || excluded.gis_attributes, gis_synced_at = now()
    returning (xmax = 0) as inserted
  )
  select count(*) filter (where inserted), count(*) filter (where not inserted) into n_ins, n_upd from up;

  with c as (
    select s.id segment_id, (e->>'survey_year')::numeric::int survey_year, nullif(e->>'pci','')::numeric pci,
           coalesce(nullif(e->>'source',''),'Legacy') source, nullif(e->>'survey_date','')::date survey_date,
           nullif(e->>'iri','')::numeric iri,
           case when jsonb_typeof(e->'distresses') = 'object' then jsonb_strip_nulls(e->'distresses') else '{}'::jsonb end distresses,
           nullif(btrim(e->>'notes'),'') notes,
           (select sc.id from pavement_scans sc where sc.name = e->>'scan_name' limit 1) scan_id
      from jsonb_array_elements(coalesce(p_conditions,'[]')) e
      join pavement_segments s on s.segment_key = e->>'segment_key'
     where nullif(e->>'survey_year','') is not null
  ), ins as (
    insert into pavement_conditions as pc (segment_id, survey_year, pci, source, survey_date, iri, distresses, notes, scan_id)
    select segment_id, survey_year, pci, source, survey_date, iri, distresses, notes, scan_id from c
    on conflict (segment_id, survey_year, source) do update set pci = excluded.pci,
      survey_date = coalesce(excluded.survey_date, pc.survey_date), iri = coalesce(excluded.iri, pc.iri),
      distresses = case when excluded.distresses = '{}'::jsonb then pc.distresses else excluded.distresses end,
      notes = coalesce(excluded.notes, pc.notes), scan_id = coalesce(excluded.scan_id, pc.scan_id)
    returning 1
  ) select count(*) into n_cond from ins;

  select id into me from people where auth_user_id = auth.uid() limit 1;
  insert into record_changes (table_name, record_id, field, old_value, new_value, action, source, actor_id, note)
  values ('pavement_segments', gen_random_uuid(), 'gis_sync', null, jsonb_build_object('inserted',n_ins,'updated',n_upd,'conditions',n_cond), 'update', 'app', me,
          'Street segments imported from ' || coalesce(p_layer,'file'));

  return jsonb_build_object('inserted', n_ins, 'updated', n_upd, 'conditions', n_cond);
end $function$;

CREATE OR REPLACE FUNCTION public.eos_run_checks(p_invoice uuid, p_as_of date DEFAULT CURRENT_DATE)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare i public.invoices%rowtype; f jsonb; hard int; rev int; res text; newstatus text;
begin
  perform eos_require('settings.manage');
  select * into i from public.invoices where id = p_invoice for update;
  if not found then raise exception 'Invoice not found'; end if;
  if i.locked then raise exception 'This invoice is locked'; end if;
  f := eos_check_invoice(p_invoice, p_as_of);
  select count(*) filter (where x->>'severity' = 'hard'), count(*) filter (where x->>'severity' = 'review')
    into hard, rev from jsonb_array_elements(f) x;
  res := case when hard > 0 then 'hold' when rev > 0 then 'review' else 'clean' end;
  newstatus := case when i.commitment_id is null then 'needs_match'
                    when hard > 0 then 'hold'
                    when i.status in ('received','needs_match','hold','checked') then 'checked'
                    else i.status end;
  perform set_config('eos.via', 'finance', true);
  update public.invoices set findings = f, check_result = res, checked_at = now(), status = newstatus where id = p_invoice;
  perform set_config('eos.via', '', true);
  return jsonb_build_object('check_result', res, 'status', newstatus, 'findings', f);
end $function$;

CREATE OR REPLACE FUNCTION public.eos_set_access(p_email text, p_level integer, p_enabled boolean)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare pid uuid; uid uuid;
begin
  perform eos_require('directory.manage');
  if p_level is not null and p_level not between 0 and 6 then raise exception 'Level must be 0–6'; end if;
  select id into uid from auth.users where lower(email) = lower(p_email);
  if uid is null then raise exception 'No login exists for % — create it first in Supabase → Authentication → Users', p_email; end if;
  update public.people set auth_user_id = uid where lower(email_address) = lower(p_email) and auth_user_id is null;
  update public.people set visibility_level = p_level, login_enabled = p_enabled, updated_at = now()
   where auth_user_id = uid returning id into pid;
  if pid is null then raise exception 'No people row is linked to %', p_email; end if;
  return json_build_object('person_id', pid, 'email', lower(p_email), 'level', p_level, 'enabled', p_enabled);
end $function$;

CREATE OR REPLACE FUNCTION public.eos_set_form_config(p_key text, p_value jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare old jsonb; me uuid;
begin
  perform eos_require('settings.manage');
  if p_key not in ('field_forms','form_libraries','asset_hierarchy') then raise exception 'Only field_forms, form_libraries and asset_hierarchy can be saved here'; end if;
  if p_value is null or jsonb_typeof(p_value) <> 'object' then raise exception 'Bad value'; end if;
  if p_key = 'asset_hierarchy' and (jsonb_typeof(p_value->'types') is distinct from 'array' or jsonb_typeof(p_value->'classes') is distinct from 'array') then raise exception 'asset_hierarchy needs classes and types lists'; end if;
  select value into old from settings where key = p_key for update;
  insert into settings(key, value, min_level) values (p_key, p_value, 1)
    on conflict (key) do update set value = excluded.value, updated_at = now();
  select id into me from people where auth_user_id = auth.uid() limit 1;
  insert into record_changes(table_name, record_id, field, old_value, new_value, action, source, actor_id, batch_id)
  values ('settings', md5(p_key)::uuid, p_key, old, p_value, 'update', 'app', me, gen_random_uuid());
  return jsonb_build_object('saved', p_key, 'updated_at', now());
end $function$;

CREATE OR REPLACE FUNCTION public.eos_set_layout(p_table text, p_target text, p_layout jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare cur jsonb;
begin
  perform eos_require('settings.manage');
  if p_table !~ '^[a-z_]+$' or p_target !~ '^(default|level:[0-6]|role:[0-9a-f-]{36})$' then raise exception 'Bad layout key'; end if;
  insert into settings(key, value) values ('layouts', '{}'::jsonb) on conflict (key) do nothing;
  select value into cur from settings where key='layouts' for update;
  if p_layout is null or p_layout = '{}'::jsonb then
    cur := jsonb_set(coalesce(cur,'{}'), array[p_table], coalesce(cur->p_table,'{}') - p_target);
  else
    cur := jsonb_set(coalesce(cur,'{}'), array[p_table], coalesce(cur->p_table,'{}') || jsonb_build_object(p_target, p_layout || jsonb_build_object('updated_at', now())));
  end if;
  update settings set value = cur where key='layouts';
  return cur->p_table;
end $function$;

CREATE OR REPLACE FUNCTION public.eos_templates_run()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare t record; n int := 0; nxt date; step interval;
begin
  if not public.eos_can('templates.use') then return 0; end if;
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
end $function$;

CREATE OR REPLACE FUNCTION public.eos_undo_complete(p_batch uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare me uuid; meName text; rid uuid; cur tasks%rowtype; nt tasks%rowtype; batch uuid := gen_random_uuid();
        old_status text; rc record; o jsonb; n jsonb; f text; cnt int := 0; new_stop timestamptz; new_by uuid;
begin
  select id, full_name into me, meName from people
   where auth_user_id = auth.uid() and login_enabled and not coalesce(inactive,false) limit 1;
  if me is null then raise exception 'Sign in with an EOS login to undo'; end if;
  select record_id, (old_value #>> '{}') into rid, old_status from record_changes
   where batch_id = p_batch and table_name = 'tasks' and field = 'status' and action = 'update' and source = 'app' limit 1;
  if rid is null then raise exception 'Nothing to undo for that save'; end if;
  if not exists (select 1 from record_changes where batch_id = p_batch and actor_id = me) and not eos_can('tasks.done_any') then
    raise exception 'Only the person who marked it done can undo it'; end if;
  perform 1 from v_task_tracker v where v.id = rid;
  if not found then raise exception 'Task not found'; end if;
  select * into cur from tasks where id = rid for update;
  if cur.status is distinct from 'Completed' then return jsonb_build_object('changed',0); end if;
  new_stop := cur.stop_date_actual; new_by := cur.completed_by;
  for rc in select field, old_value, new_value from record_changes where batch_id = p_batch and action = 'update' loop
    if rc.field = 'stop_date_actual' and to_jsonb(cur.stop_date_actual) is not distinct from rc.new_value then new_stop := (rc.old_value #>> '{}')::timestamptz; end if;
    if rc.field = 'completed_by' and to_jsonb(cur.completed_by) is not distinct from rc.new_value then new_by := (rc.old_value #>> '{}')::uuid; end if;
  end loop;
  perform set_config('eos.via','app',true);
  update tasks set status = coalesce(old_status,'Planned'), stop_date_actual = new_stop, completed_by = new_by where id = rid;
  perform set_config('eos.via','',true);
  select * into nt from tasks where id = rid;
  o := to_jsonb(cur); n := to_jsonb(nt);
  foreach f in array array['status','stop_date_actual','completed_by'] loop
    if n->f is distinct from o->f then
      insert into record_changes (table_name, record_id, field, old_value, new_value, action, source, actor_id, batch_id, note)
      values ('tasks', rid, f, o->f, n->f, 'update', 'app', me, batch, 'Undo of Marked done');
      cnt := cnt + 1;
    end if;
  end loop;
  insert into notes (content, task_id, author_id)
  values ('Marked done was undone by ' || coalesce(meName,'an EOS user') || ' on ' || to_char(now() at time zone 'America/New_York','Mon FMDD, YYYY'), rid, me);
  return jsonb_build_object('changed', cnt, 'batch', batch, 'status', nt.status);
end $function$;

CREATE OR REPLACE FUNCTION public.eos_log_gis_edit(p_layer text, p_service_url text, p_oid bigint, p_globalid text, p_old jsonb, p_new jsonb, p_note text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare me uuid; batch uuid := gen_random_uuid(); rid uuid; n int;
begin
  perform eos_require('gis.edit');
  if p_layer is null or p_oid is null then raise exception 'Layer and feature ID are required'; end if;
  rid := case when p_globalid ~* '^\{?[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\}?$'
              then trim(both '{}' from p_globalid)::uuid
              else md5(coalesce(p_service_url, p_layer) || '#' || p_oid)::uuid end;
  select id into me from people where auth_user_id = auth.uid() limit 1;
  insert into record_changes (table_name, record_id, field, old_value, new_value, action, source, actor_id, batch_id, note)
  select 'agol:' || p_layer, rid, k, p_old->k, p_new->k, 'update', 'app', me, batch,
         coalesce(p_note, '') || ' [ArcGIS ' || coalesce(p_service_url, p_layer) || ' · OBJECTID ' || p_oid || ']'
    from jsonb_object_keys(coalesce(p_new, '{}')) k
   where (p_old->k) is distinct from (p_new->k);
  get diagnostics n = row_count;
  return jsonb_build_object('logged', n, 'batch', batch, 'record_id', rid);
end $function$;

CREATE OR REPLACE FUNCTION public.eos_register_upload(p_path text, p_filename text, p_type text, p_size bigint, p_values jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare cfg jsonb; f jsonb; k text; v jsonb; me uuid; newid uuid; batch uuid := gen_random_uuid(); vals jsonb := '{}'; cols text[];
begin
  cfg := eos_editor(); perform eos_require('documents.upload');
  f := cfg->'tables'->'documents'->'fields';
  if p_path is null or p_path not like 'uploads/%' then raise exception 'Upload path must be under uploads/'; end if;
  if not exists (select 1 from storage.objects where bucket_id = 'eos-uploads' and name = p_path) then raise exception 'The file did not finish uploading — try again'; end if;
  for k, v in select * from jsonb_each(coalesce(p_values,'{}')) loop
    if not f ? k then raise exception 'The field "%" cannot be set on an upload', k; end if;
    if v = 'null'::jsonb or (jsonb_typeof(v) = 'string' and btrim(v #>> '{}') = '') then continue; end if;
    vals := vals || jsonb_build_object(k, v);
  end loop;
  select id into me from people where auth_user_id = auth.uid() limit 1;
  vals := vals || jsonb_build_object('filename', p_filename, 'file_type', p_type, 'file_size_bytes', p_size,
                                     'storage_bucket', 'eos-uploads', 'storage_path', p_path, 'location_status', 'in_storage',
                                     'uploaded_by', me, 'source_folder_name', 'Uploaded in the EOS app');
  if vals ? 'location_text' then vals := vals || '{"location_source":"manual"}'::jsonb; end if;
  select array_agg(key) into cols from jsonb_object_keys(vals) key;
  perform set_config('eos.via', 'app', true);
  execute format('insert into public.documents (%s) select %s from jsonb_populate_record(null::public.documents, $1) r returning id',
                 (select string_agg(quote_ident(c), ', ') from unnest(cols) c),
                 (select string_agg('r.' || quote_ident(c), ', ') from unnest(cols) c))
    into newid using vals;
  perform set_config('eos.via', '', true);
  insert into record_changes (table_name, record_id, field, old_value, new_value, action, source, actor_id, batch_id, note)
  values ('documents', newid, null, null, vals, 'create', 'app', me, batch, 'Uploaded in the app');
  insert into record_changes (table_name, record_id, field, old_value, new_value, action, source, actor_id, batch_id, note)
  select 'documents', newid, key, null, value, 'update', 'app', me, batch, 'Set at upload'
    from jsonb_each(coalesce(p_values,'{}')) where f ? key and value <> 'null'::jsonb and not (jsonb_typeof(value)='string' and btrim(value #>> '{}')='');
  return jsonb_build_object('id', newid, 'batch', batch);
end $function$;

CREATE OR REPLACE FUNCTION public.eos_register_bulk_upload(p_path text, p_filename text, p_type text, p_size bigint, p_values jsonb DEFAULT '{}'::jsonb, p_folder text DEFAULT NULL::text, p_batch text DEFAULT NULL::text, p_md5 text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare cfg jsonb; f jsonb; k text; v jsonb; me uuid; newid uuid; batch uuid := gen_random_uuid(); vals jsonb := '{}'; cols text[];
begin
  cfg := eos_editor(); perform eos_require('documents.upload');
  f := cfg->'tables'->'documents'->'fields';
  if f is null or not coalesce((cfg->'tables'->'documents'->>'upload')::boolean,false) then raise exception 'Uploads are not enabled for you'; end if;
  if p_path is null or p_path not like 'uploads/%' then raise exception 'Upload path must be under uploads/'; end if;
  if not exists (select 1 from storage.objects where bucket_id = 'eos-uploads' and name = p_path) then raise exception 'The file did not finish uploading — try again'; end if;
  if p_md5 is not null and p_md5 !~ '^[0-9a-f]{32}$' then raise exception 'Bad checksum'; end if;
  for k, v in select * from jsonb_each(coalesce(p_values,'{}')) loop
    if not f ? k then raise exception 'The field "%" cannot be set on an upload', k; end if;
    if v = 'null'::jsonb or (jsonb_typeof(v) = 'string' and btrim(v #>> '{}') = '') then continue; end if;
    vals := vals || jsonb_build_object(k, v);
  end loop;
  select id into me from people where auth_user_id = auth.uid() limit 1;
  vals := vals || jsonb_build_object('filename', p_filename, 'file_type', p_type, 'file_size_bytes', p_size,
                                     'storage_bucket', 'eos-uploads', 'storage_path', p_path, 'location_status', 'in_storage',
                                     'uploaded_by', me,
                                     'source_folder_name', coalesce(nullif(left(btrim(p_folder),300),''), 'Uploaded in the EOS app'));
  if nullif(btrim(p_batch),'') is not null then vals := vals || jsonb_build_object('source_folder_id', left(btrim(p_batch),80)); end if;
  if p_md5 is not null then vals := vals || jsonb_build_object('content_md5', p_md5); end if;
  if vals ? 'location_text' then vals := vals || '{"location_source":"manual"}'::jsonb; end if;
  select array_agg(key) into cols from jsonb_object_keys(vals) key;
  perform set_config('eos.via', 'app', true);
  execute format('insert into public.documents (%s) select %s from jsonb_populate_record(null::public.documents, $1) r returning id',
                 (select string_agg(quote_ident(c), ', ') from unnest(cols) c),
                 (select string_agg('r.' || quote_ident(c), ', ') from unnest(cols) c))
    into newid using vals;
  perform set_config('eos.via', '', true);
  insert into record_changes (table_name, record_id, field, old_value, new_value, action, source, actor_id, batch_id, note)
  values ('documents', newid, null, null, vals, 'create', 'app', me, batch, 'Bulk upload in the app');
  insert into record_changes (table_name, record_id, field, old_value, new_value, action, source, actor_id, batch_id, note)
  select 'documents', newid, key, null, value, 'update', 'app', me, batch, 'Set at upload'
    from jsonb_each(coalesce(p_values,'{}')) where f ? key and value <> 'null'::jsonb and not (jsonb_typeof(value)='string' and btrim(value #>> '{}')='');
  return jsonb_build_object('id', newid, 'batch', batch);
end $function$;

CREATE OR REPLACE FUNCTION public.eos_unlock_field(p_table text, p_id uuid, p_field text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare me uuid;
begin
  perform eos_editor(); perform eos_require(eos_perm_for(p_table, 'edit'));
  select id into me from people where auth_user_id = auth.uid() limit 1;
  insert into record_changes (table_name, record_id, field, action, source, actor_id, note)
  values (p_table, p_id, p_field, 'unlock', 'app', me, 'Email updates may change this field again');
end $function$;

CREATE OR REPLACE FUNCTION public.eos_create(p_table text, p_values jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare cfg jsonb; t jsonb; f jsonb; k text; v jsonb; vals jsonb := '{}'; me uuid; meName text; newid uuid; batch uuid := gen_random_uuid(); cols text[];
begin
  cfg := eos_editor(); perform eos_require(eos_perm_for(p_table, 'create'));
  t := cfg->'tables'->p_table;
  if t is null or not coalesce((t->>'create')::boolean, false) then raise exception 'New % records cannot be created from the app', p_table; end if;
  f := t->'fields';
  for k, v in select * from jsonb_each(coalesce(p_values, '{}')) loop
    if not f ? k then raise exception 'The field "%" cannot be set from the app', k; end if;
    if v = 'null'::jsonb or (jsonb_typeof(v) = 'string' and btrim(v #>> '{}') = '') then continue; end if;
    vals := vals || jsonb_build_object(k, v);
  end loop;
  for k in select key from jsonb_each(f) where coalesce((value->>'required')::boolean,false) loop
    if not vals ? k then raise exception '% is required', f->k->>'label'; end if;
  end loop;
  vals := coalesce(t->'create_defaults', '{}') || vals;
  select id, full_name into me, meName from people where auth_user_id = auth.uid() limit 1;
  if p_table in ('tasks','work_orders') then
    vals := vals || jsonb_build_object('entered_by', coalesce(meName, 'EOS app') || ' (EOS app)', 'sync_status', 'eos_only');
    if p_table = 'tasks' and not vals ? 'labor_ids' then vals := vals || jsonb_build_object('labor_ids', '[]'::jsonb); end if;
  elsif p_table = 'dashboards' then
    vals := vals || jsonb_build_object('owner_id', me);
    if not vals ? 'author' then vals := vals || jsonb_build_object('author', meName); end if;
  elsif p_table = 'notes' then
    if not (vals ? 'task_id' or vals ? 'work_order_id') then raise exception 'A note needs a task or a work order'; end if;
    vals := vals || jsonb_build_object('author_id', me);
  end if;
  select array_agg(key) into cols from jsonb_object_keys(vals) key;
  perform set_config('eos.via', 'app', true);
  execute format('insert into public.%1$I (%2$s) select %3$s from jsonb_populate_record(null::public.%1$I, $1) r returning id',
                 p_table,
                 (select string_agg(quote_ident(c), ', ') from unnest(cols) c),
                 (select string_agg('r.' || quote_ident(c), ', ') from unnest(cols) c))
    into newid using vals;
  perform set_config('eos.via', '', true);
  insert into record_changes (table_name, record_id, field, old_value, new_value, action, source, actor_id, batch_id)
  values (p_table, newid, null, null, vals, 'create', 'app', me, batch);
  return jsonb_build_object('id', newid, 'batch', batch);
end $function$;

CREATE OR REPLACE FUNCTION public.eos_purge(p_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare paths jsonb; n int;
begin
  perform eos_editor(); perform eos_require('records.delete');
  select coalesce(jsonb_agg(snapshot->>'storage_path'), '[]') into paths
    from recycle_bin where (id = p_id or batch = p_id) and purged_at is null and restored_at is null and table_name = 'documents' and snapshot->>'storage_path' is not null;
  update recycle_bin set purged_at = now(), snapshot = jsonb_build_object('purged', true), children = '{}', links = '{}'
   where (id = p_id or batch = p_id) and purged_at is null and restored_at is null;
  get diagnostics n = row_count;
  return jsonb_build_object('purged', n, 'storage_paths', paths);
end $function$;

create or replace function public.req_triage(p_id uuid, p_action text, p_note text, p_work_order uuid default null::uuid)
 returns uuid language plpgsql security definer set search_path to 'public' as $function$
declare me uuid := public.eos_person_id(); r public.requests; tid uuid; res jsonb; vals jsonb;
begin
  perform eos_require('requests.handle');
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
end $function$;

create or replace function public.wp_act(p_id uuid, p_action text, p_note text default null::text)
 returns text language plpgsql security definer set search_path to 'public' as $function$
declare me uuid := public.eos_person_id(); w public.work_packages; n text := nullif(btrim(coalesce(p_note, '')), '');
begin
  if me is null then raise exception 'Sign in with EOS access'; end if;
  select * into w from public.work_packages where id = p_id for update;
  if not found then raise exception 'Package not found'; end if;
  if p_action in ('accept','return','done') then
    if w.assigned_to is distinct from me then raise exception 'Only the person the package was given to can do that'; end if;
    if w.status in ('done','canceled') then raise exception 'This package is already closed'; end if;
    if p_action = 'return' and n is null then raise exception 'Say what you need when sending a package back'; end if;
    update public.work_packages set status = case p_action when 'accept' then 'accepted' when 'return' then 'returned' else 'done' end,
           response = coalesce(n, response), updated_at = now() where id = p_id;
  elsif p_action in ('cancel','resend') then
    if w.sent_by is distinct from me and not public.eos_can('packages.manage') then raise exception 'Only the sender can do that'; end if;
    if p_action = 'resend' and w.status <> 'returned' then raise exception 'Only a returned package can be sent again'; end if;
    update public.work_packages set status = case p_action when 'cancel' then 'canceled' else 'sent' end,
           note = case when p_action = 'resend' and n is not null then n else note end, updated_at = now() where id = p_id;
  else raise exception 'Unknown action'; end if;
  return (select status from public.work_packages where id = p_id);
end $function$;

CREATE OR REPLACE FUNCTION public.wp_send(p_title text, p_note text, p_assigned_to uuid, p_due date, p_items jsonb)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare me uuid := public.eos_person_id(); nid uuid;
begin
  if me is null then raise exception 'Sign in with EOS access to send a work package'; end if;
  perform eos_require('packages.send');
  if not exists (select 1 from public.people where id = p_assigned_to and login_enabled and not coalesce(inactive, false)) then
    raise exception 'That person does not have EOS access'; end if;
  if (select count(*) from public.work_packages where sent_by = me and created_at > now() - interval '1 day') >= 50 then raise exception 'Up to 50 packages a day'; end if;
  insert into public.work_packages (title, note, sent_by, assigned_to, due_date, items)
  values (btrim(p_title), nullif(btrim(coalesce(p_note, '')), ''), me, p_assigned_to, p_due, public.wp_clean_items(p_items))
  returning id into nid;
  return nid;
end $function$;

create or replace function public.eos_delete(p_table text, p_id uuid, p_with_children boolean default true, p_reason text default null, p_batch uuid default null)
returns jsonb language plpgsql security definer set search_path to 'public' as $function$
declare row_j jsonb; kids jsonb := '{}'; lnk jsonb := '{}'; me uuid; me_name text; the_batch uuid := coalesce(p_batch, gen_random_uuid());
        lbl text; bin_id uuid; n int; counts jsonb := '{}'; x uuid; blocking int; v jsonb; fkr record;
begin
  perform eos_editor();
  if p_table not in ('tasks','work_orders','projects','meetings','requests','documents','organizations','work_packages','notes','docs','people') then
    raise exception 'Records in % cannot be deleted from the app', p_table;
  end if;
  if p_table = 'people' then perform eos_require('directory.manage'); else perform eos_require('records.delete'); end if;
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
    when 'docs' then left(coalesce(row_j->>'title',''), 120)
    when 'people' then left(coalesce(row_j->>'full_name', row_j->>'email_address', ''), 120) end;

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
  elsif p_table = 'people' then
    -- a person: every link to them is recorded generically so a restore can put it back
    if (row_j->>'auth_user_id') is not null and coalesce((row_j->>'login_enabled')::boolean, false) then
      raise exception 'This person can sign in to EOS. Turn off their EOS access first, then delete them.';
    end if;
    for fkr in select c.conrelid::regclass::text as tbl, a.attname as col, c.confdeltype as act
                 from pg_constraint c join pg_attribute a on a.attrelid = c.conrelid and a.attnum = any(c.conkey)
                where c.contype = 'f' and c.confrelid = 'public.people'::regclass and c.conrelid <> 'public.recycle_bin'::regclass and c.conrelid <> 'public.notifications'::regclass loop
      if fkr.act = 'c' then
        execute format('select coalesce(jsonb_agg(to_jsonb(t)), ''[]'') from %s t where t.%I = $1', fkr.tbl, fkr.col) into v using p_id;
        if jsonb_array_length(v) > 0 then kids := kids || jsonb_build_object('rows:' || replace(fkr.tbl, 'public.', ''), v); end if;
      else
        execute format('select coalesce(jsonb_agg(id), ''[]'') from %s where %I = $1', fkr.tbl, fkr.col) into v using p_id;
        if jsonb_array_length(v) > 0 then lnk := lnk || jsonb_build_object(replace(fkr.tbl, 'public.', '') || '.' || fkr.col, v); end if;
        if fkr.act in ('a','r') then execute format('update %s set %I = null where %I = $1', fkr.tbl, fkr.col, fkr.col) using p_id; end if;
      end if;
    end loop;
    for fkr in select c.table_name as tbl, c.column_name as col, 'x' as act from information_schema.columns c
                where c.table_schema = 'public' and c.data_type = 'ARRAY' and c.udt_name = '_uuid' and c.table_name not like 'v\_%' and c.table_name <> 'recycle_bin'
                  and exists (select 1 from information_schema.columns i where i.table_schema = 'public' and i.table_name = c.table_name and i.column_name = 'id') loop
      execute format('select coalesce(jsonb_agg(id), ''[]'') from public.%I where $1 = any(%I)', fkr.tbl, fkr.col) into v using p_id;
      if jsonb_array_length(v) > 0 then
        lnk := lnk || jsonb_build_object('arr:' || fkr.tbl || '.' || fkr.col, v);
        execute format('update public.%I set %I = array_remove(%I, $1) where $1 = any(%I)', fkr.tbl, fkr.col, fkr.col, fkr.col) using p_id;
      end if;
    end loop;
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

create or replace function public.eos_restore(p_batch uuid) returns jsonb
language plpgsql security definer set search_path to 'public' as $function$
declare b record; cols text; n int := 0; k text; v jsonb; me uuid; skipped text[] := '{}';
  ord text[] := array['people','organizations','projects','work_orders','tasks','documents','meetings','requests','work_packages','notes','docs']; tbl text; col text;
begin
  perform eos_editor();
  if not (eos_can('records.delete') or eos_can('directory.manage')) then raise exception 'You do not have permission to restore records'; end if;
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
      elsif k like 'rows:%' and jsonb_array_length(v) > 0 then
        execute format('insert into public.%1$I select * from jsonb_populate_recordset(null::public.%1$I, $1) on conflict do nothing', substr(k, 6)) using v;
      elsif k = 'unlinked_work_orders' then
        update work_orders set project_id = b.record_id where id in (select (e->>0)::uuid from jsonb_array_elements(v) e) and project_id is null;
      end if;
    end loop;
    -- links from other records
    for k, v in select * from jsonb_each(b.links) loop
      if jsonb_array_length(v) = 0 then continue; end if;
      if b.table_name = 'people' then
        if k like 'arr:%' then
          tbl := split_part(substr(k, 5), '.', 1); col := split_part(substr(k, 5), '.', 2);
          execute format('update public.%I set %I = array_append(%I, $2) where id in (select (e->>0)::uuid from jsonb_array_elements($1) e) and not ($2 = any(%I))', tbl, col, col, col) using v, b.record_id;
        else
          tbl := split_part(k, '.', 1); col := split_part(k, '.', 2);
          execute format('update public.%I set %I = $2 where id in (select (e->>0)::uuid from jsonb_array_elements($1) e) and %I is null', tbl, col, col) using v, b.record_id;
        end if;
      elsif b.table_name = 'tasks' then
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


-- What deleting a person would unlink (the delete itself is in eos_delete above)
create or replace function public.eos_delete_preview(p_table text, p_id uuid) returns jsonb
language plpgsql stable security definer set search_path to 'public' as $function$
declare r jsonb := '{}'; wo uuid[]; tk uuid[];
begin
  perform eos_editor();
  if p_table = 'people' then perform eos_require('directory.manage'); end if;
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
  elsif p_table = 'people' then
    r := r || jsonb_build_object('tasks', (select count(*) from tasks where p_id = any(coalesce(labor_ids,'{}')) and status not in ('Completed','Canceled')),
                                 'work_orders', (select count(*) from work_orders where lead_worker_id = p_id and status not in ('Completed','Canceled')),
                                 'notes', (select count(*) from notes where author_id = p_id),
                                 'meetings', (select count(*) from meetings where p_id = any(coalesce(attendee_ids,'{}'))),
                                 'blocking', (select count(*) from people where id = p_id and auth_user_id is not null and coalesce(login_enabled, false)));
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

-- Managing sets and who has them (roles.manage), with a guard against locking everyone out
create or replace function public.perm_guard() returns void language plpgsql security definer set search_path to 'public' as $function$
declare n int;
begin
  select count(*) into n from people pp left join roles r on r.id = pp.role_id
   left join permission_sets ps on ps.id = coalesce(pp.permission_set_id, r.permission_set_id)
   where pp.login_enabled and not coalesce(pp.inactive, false) and pp.auth_user_id is not null
     and ('roles.manage' = any(coalesce(ps.grants, (select grants from permission_sets where name = eos_level_set(coalesce(pp.visibility_level, r.visibility_level, 0)))) || pp.extra_grants))
     and not ('roles.manage' = any(pp.denied_grants));
  if n = 0 then raise exception 'That would leave nobody able to manage roles and permissions.'; end if;
end $function$;
create or replace function public.perm_set_save(p_id uuid, p_name text, p_description text, p_grants text[]) returns uuid
language plpgsql security definer set search_path to 'public' as $function$
declare sid uuid := p_id; valid text[]; bad text[];
begin
  perform eos_require('roles.manage');
  if btrim(coalesce(p_name, '')) = '' then raise exception 'Give the set a name'; end if;
  valid := array(select e->>'key' from jsonb_array_elements((select value from settings where key = 'permissions')) e);
  bad := array(select x from unnest(coalesce(p_grants, '{}')) x where not (x = any(valid)));
  if cardinality(bad) > 0 then raise exception 'Unknown permission: %', bad[1]; end if;
  if sid is null then
    insert into permission_sets (name, description, grants, sort_order) values (btrim(p_name), p_description, array(select distinct x from unnest(coalesce(p_grants, '{}')) x), 100) returning id into sid;
  else
    update permission_sets set name = btrim(p_name), description = p_description, grants = array(select distinct x from unnest(coalesce(p_grants, '{}')) x), updated_at = now() where id = sid;
    if not found then raise exception 'Set not found'; end if;
  end if;
  perform perm_guard();
  return sid;
end $function$;
create or replace function public.perm_set_delete(p_id uuid) returns void language plpgsql security definer set search_path to 'public' as $function$
declare s record; n int;
begin
  perform eos_require('roles.manage');
  select * into s from permission_sets where id = p_id; if not found then raise exception 'Set not found'; end if;
  if s.is_builtin then raise exception 'The % set cannot be deleted', s.name; end if;
  select (select count(*) from roles where permission_set_id = p_id) + (select count(*) from people where permission_set_id = p_id) into n;
  if n > 0 then raise exception 'That set is used by % role(s) or people. Move them to another set first.', n; end if;
  delete from permission_sets where id = p_id;
end $function$;
create or replace function public.perm_role_set(p_role uuid, p_set uuid) returns void language plpgsql security definer set search_path to 'public' as $function$
begin
  perform eos_require('roles.manage');
  update roles set permission_set_id = p_set, updated_at = now() where id = p_role;
  if not found then raise exception 'Role not found'; end if;
  perform perm_guard();
end $function$;
create or replace function public.perm_person_set(p_person uuid, p_set uuid, p_extra text[], p_denied text[]) returns void language plpgsql security definer set search_path to 'public' as $function$
begin
  if not (eos_can('roles.manage') or eos_can('directory.manage')) then raise exception 'You do not have permission to change a person''s permissions'; end if;
  update people set permission_set_id = p_set, extra_grants = coalesce(p_extra, '{}'), denied_grants = coalesce(p_denied, '{}'), updated_at = now() where id = p_person;
  if not found then raise exception 'Person not found'; end if;
  perform perm_guard();
end $function$;
revoke all on function public.eos_grants(), public.eos_can(text), public.eos_can_any(text[]), public.eos_require(text), public.perm_guard(), public.perm_set_save(uuid,text,text,text[]), public.perm_set_delete(uuid), public.perm_role_set(uuid,uuid), public.perm_person_set(uuid,uuid,text[],text[]) from public, anon;
grant execute on function public.eos_grants(), public.eos_can(text), public.eos_can_any(text[]), public.perm_set_save(uuid,text,text,text[]), public.perm_set_delete(uuid), public.perm_role_set(uuid,uuid), public.perm_person_set(uuid,uuid,text[],text[]) to authenticated;

-- Views: the app learns its grants from v_me; roles and people carry their set
update public.view_defs set base_sql = regexp_replace(base_sql, 'p\.home_layout(\s+)FROM people p',
  'p.home_layout, eos_grants() AS grants, p.permission_set_id, (SELECT ps.name FROM permission_sets ps WHERE ps.id = coalesce(p.permission_set_id, (SELECT r2.permission_set_id FROM roles r2 WHERE r2.id = p.role_id))) AS permission_set_name, p.extra_grants, p.denied_grants\1FROM people p'), updated_at = now()
 where view_name = 'v_me' and base_sql not like '%eos_grants()%';
update public.view_defs set base_sql = replace(replace(base_sql, 'r.visibility_level,', 'r.visibility_level, r.permission_set_id, ps.name AS permission_set_name,'),
  'LEFT JOIN people p ON p.role_id = r.id', 'LEFT JOIN people p ON p.role_id = r.id LEFT JOIN permission_sets ps ON ps.id = r.permission_set_id'), updated_at = now()
 where view_name = 'v_roles' and base_sql not like '%permission_set_id%';
update public.view_defs set base_sql = regexp_replace(base_sql, 'GROUP BY r\.id\s*$', 'GROUP BY r.id, ps.name'), updated_at = now() where view_name = 'v_roles' and base_sql not like '%ps.name$%' and base_sql !~ 'GROUP BY r\.id, ps\.name';
update public.view_defs set base_sql = replace(base_sql, 'p.photo_path,', 'p.photo_path, p.permission_set_id, p.extra_grants, p.denied_grants,'), updated_at = now()
 where view_name = 'v_people_directory' and base_sql not like '%p.permission_set_id%';
insert into public.view_defs (view_name, base_sql, min_level, row_filter, description)
values ('v_permission_sets', $$
 SELECT s.id, s.name, s.description, s.grants, s.sort_order, s.is_builtin, s.updated_at,
        (SELECT count(*) FROM roles r WHERE r.permission_set_id = s.id)::int AS role_count,
        (SELECT count(*) FROM people p LEFT JOIN roles r ON r.id = p.role_id WHERE p.login_enabled AND coalesce(p.permission_set_id, r.permission_set_id) = s.id)::int AS people_count
   FROM permission_sets s
$$, 1, 'eos_can(''roles.manage'') OR eos_can(''directory.manage'')', 'Permission sets: what each one allows, and how many roles and people use it.')
on conflict (view_name) do update set base_sql = excluded.base_sql, min_level = excluded.min_level, row_filter = excluded.row_filter, description = excluded.description, updated_at = now();
update public.view_defs set min_level = 1, row_filter = 'eos_can(''directory.manage'')', updated_at = now() where view_name = 'v_logins';
update public.view_defs set min_level = 1, row_filter = 'eos_can(''records.delete'') OR eos_can(''directory.manage'')', updated_at = now() where view_name = 'v_recycle_bin';
select count(*) as views_rebuilt from public.rebuild_views();

-- Map today's access onto sets: by the role's level, consultants as Division heads
update public.roles r set permission_set_id = s.id from public.permission_sets s
 where r.permission_set_id is null and r.visibility_level is not null
   and s.name = case when r.title = 'Consultant User' then 'Division head' else eos_level_set(r.visibility_level) end;
-- A person whose level is set directly on the account (not from the role) keeps that level's set
update public.people p set permission_set_id = s.id from public.permission_sets s
 where p.permission_set_id is null and p.visibility_level is not null and p.login_enabled
   and p.visibility_level is distinct from (select r.visibility_level from roles r where r.id = p.role_id)
   and s.name = eos_level_set(p.visibility_level);
-- The Directory is managed by Sam, Tracy, Jenn and Eric only
update public.people set extra_grants = array(select distinct x from unnest(extra_grants || array['directory.manage']) x)
 where id in ('0900c4fe-4d31-4277-bcca-e4ded278a758','b2c3d4e5-0004-0004-0004-000000000004','b2c3d4e5-0006-0006-0006-000000000006','70d3cc82-21cb-45a9-88b3-47dab68cf606');

update public.settings set value = (select jsonb_agg(x) from (select distinct x from jsonb_array_elements(value || '["eos_grants","eos_can","eos_can_any","perm_set_save","perm_set_delete","perm_role_set","perm_person_set"]'::jsonb) x) s)
 where key = 'rpc_allowlist';

select (select count(*) from public.permission_sets) as sets,
       (select count(*) from public.roles where permission_set_id is not null) as roles_mapped,
       (select count(*) from public.people where login_enabled and 'directory.manage' = any(extra_grants)) as directory_managers,
       (select count(*) from information_schema.views where table_name in ('v_permission_sets')) as view_ready,
       (select count(*) from pg_proc where proname in ('eos_grants','eos_can','eos_require','perm_set_save','perm_role_set','perm_person_set')) as functions_ready;
commit;
