-- 023 · Access, one model: jobs, access profiles with a data tier, accounts, record visibility — 2026-10-30
-- Run once in the Supabase SQL editor, right after build v204 is live. Everything runs in one transaction:
-- if any step fails nothing changes. The last statement prints every account with its profile and tier.
--
-- What changes
--   * Levels 0–6 are gone from people and jobs. Each access profile (the permission sets from db/016) now carries one
--     DATA TIER: Staff, Management (adds financial and HR fields) or Executive (adds personnel notes and accounts).
--     Inside the database the tiers are still the numbers the views and field gates already use: Staff = 3,
--     Management = 5, Executive = 6. eos_level() returns the tier of your profile. Nothing in the views had to change.
--   * A person's profile comes from their job (roles.permission_set_id), or is set on the person. No more level
--     on the person, no more level on the job, no more "denied" grants. Extra grants on a person stay.
--   * Record visibility on meetings, work orders, projects, Knowledge Base entries and dashboards is one field,
--     visibility: everyone | management | executive (was an array of levels).
--   * "View as" previews an access profile, not a level number.
--   * The eight OpenGov access categories leave the jobs list. The four consultants get a Consultant profile
--     (Division head's grants, Management tier) and no job.
--   * Settings visibility_levels and tabs_by_level go; settings.tiers describes the three tiers.
--   * Guard: the script refuses to commit if anyone's tier would drop, except the consultants (6 → Management),
--     which is intended.

begin;
select set_config('eos.via', 'admin', true);

-- ───────────────────────────── 0. what everyone sees today (for the final check) ─────────────────────────────
create temp table _before on commit drop as
select p.id, p.full_name, coalesce(p.visibility_level, r.visibility_level) as old_level,
       case when coalesce(p.visibility_level, r.visibility_level, 0) >= 6 then 6
            when coalesce(p.visibility_level, r.visibility_level, 0) >= 4 then 5 else 3 end as old_tier_level,
       r.title as role_title
  from people p left join roles r on r.id = p.role_id
 where p.login_enabled;

-- ───────────────────────────── 1. tiers on access profiles ─────────────────────────────
alter table public.permission_sets add column if not exists tier text not null default 'staff';
alter table public.permission_sets drop constraint if exists permission_sets_tier_check;
alter table public.permission_sets add constraint permission_sets_tier_check check (tier in ('staff','management','executive'));
update public.permission_sets set tier = case name when 'Administrator' then 'executive'
                                                   when 'Division head' then 'management'
                                                   when 'Supervisor' then 'management' else 'staff' end;
insert into public.permission_sets (name, description, grants, sort_order, is_builtin, tier)
select 'Consultant', 'Outside engineers and project managers working for the City. The same grants as Division head, Management data.',
       grants, 55, false, 'management'
  from public.permission_sets where name = 'Division head'
    and not exists (select 1 from public.permission_sets where name = 'Consultant');

create or replace function public.eos_tier_level(p_tier text) returns integer language sql immutable as $$
  select case p_tier when 'executive' then 6 when 'management' then 5 when 'staff' then 3 else 0 end $$;
create or replace function public.eos_vis_level(p_vis text) returns integer language sql immutable as $$
  select case p_vis when 'executive' then 6 when 'management' then 5 else 0 end $$;

alter table public.people add column if not exists preview_set_id uuid references public.permission_sets(id) on delete set null;

-- ───────────────────────────── 2. who am I: profile, tier, grants ─────────────────────────────
-- The signed-in person's profile: their own (set on the person, else from the job), or the one they are previewing.
create or replace function public.eos_my_profile(out person_id uuid, out set_id uuid, out own_set_id uuid, out extra text[])
returns record language plpgsql stable security definer set search_path to 'public' as $$
declare p record; own_tier text;
begin
  select pp.id, pp.permission_set_id, pp.extra_grants, pp.preview_set_id, r.permission_set_id as role_set
    into p from people pp left join roles r on r.id = pp.role_id
   where pp.auth_user_id = auth.uid() and pp.login_enabled and not coalesce(pp.inactive, false) limit 1;
  if p.id is null then return; end if;
  person_id := p.id; own_set_id := coalesce(p.permission_set_id, p.role_set); set_id := own_set_id; extra := coalesce(p.extra_grants, '{}');
  if p.preview_set_id is not null then
    select tier into own_tier from permission_sets where id = own_set_id;
    if own_tier = 'executive' then set_id := p.preview_set_id; extra := '{}'; end if;
  end if;
end $$;

create or replace function public.eos_level() returns integer language plpgsql stable security definer set search_path to 'public' as $$
declare claims text; jrole text; probe text; pr record;
begin
  if session_user = 'postgres' then
    probe := nullif(current_setting('eos.probe_level', true), '');
    if probe is not null then return probe::int; end if;
  end if;
  claims := nullif(current_setting('request.jwt.claims', true), '');
  if claims is null then return 6; end if;
  jrole := coalesce(claims::json->>'role', '');
  if jrole = 'service_role' then return 6; end if;
  if jrole <> 'authenticated' then return 0; end if;
  select * into pr from eos_my_profile();
  if pr.set_id is null then return 0; end if;
  return eos_tier_level((select tier from permission_sets where id = pr.set_id));
end $$;

create or replace function public.eos_grants() returns text[] language plpgsql stable security definer set search_path to 'public' as $$
declare claims text; jrole text; pr record; setg text[];
begin
  claims := nullif(current_setting('request.jwt.claims', true), '');
  jrole := case when claims is null then '' else coalesce(claims::json->>'role', '') end;
  if claims is null or jrole = 'service_role' then
    return array(select e->>'key' from jsonb_array_elements((select value from settings where key = 'permissions')) e);
  end if;
  if jrole <> 'authenticated' then return '{}'; end if;
  select * into pr from eos_my_profile();
  if pr.set_id is null then return '{}'; end if;
  select grants into setg from permission_sets where id = pr.set_id;
  return array(select distinct x from unnest(coalesce(setg, '{}') || coalesce(pr.extra, '{}')) x);
end $$;

-- What one person can do (used by the lock-out guard and by notifications)
create or replace function public.eos_person_grants(p_person uuid) returns text[] language sql stable security definer set search_path to 'public' as $$
  select array(select distinct x from unnest(
           coalesce((select ps.grants from permission_sets ps where ps.id = coalesce(p.permission_set_id, r.permission_set_id)), '{}')
           || coalesce(p.extra_grants, '{}')) x)
    from people p left join roles r on r.id = p.role_id where p.id = p_person $$;

create or replace function public.perm_guard() returns void language plpgsql security definer set search_path to 'public' as $$
declare n int;
begin
  select count(*) into n
    from people pp left join roles r on r.id = pp.role_id
    left join permission_sets ps on ps.id = coalesce(pp.permission_set_id, r.permission_set_id)
   where pp.login_enabled and not coalesce(pp.inactive, false) and pp.auth_user_id is not null
     and ps.tier = 'executive' and 'roles.manage' = any(eos_person_grants(pp.id));
  if n = 0 then raise exception 'That would leave nobody at the Executive tier able to manage access.'; end if;
end $$;

-- ───────────────────────────── 3. managing access ─────────────────────────────
drop function if exists public.eos_set_access(text, integer, boolean);
create or replace function public.eos_set_access(p_email text, p_enabled boolean, p_set uuid default null)
returns json language plpgsql security definer set search_path to 'public' as $$
declare pid uuid; uid uuid; eff uuid;
begin
  perform eos_require('directory.manage');
  if p_set is not null and not exists (select 1 from permission_sets where id = p_set) then raise exception 'Unknown access profile'; end if;
  select id into uid from auth.users where lower(email) = lower(p_email);
  if uid is null then raise exception 'No sign-in exists for % yet', p_email; end if;
  update public.people set auth_user_id = uid where lower(email_address) = lower(p_email) and auth_user_id is null;
  update public.people set login_enabled = p_enabled, permission_set_id = coalesce(p_set, permission_set_id), updated_at = now()
   where auth_user_id = uid returning id into pid;
  if pid is null then raise exception 'No Directory entry is linked to %', p_email; end if;
  select coalesce(pp.permission_set_id, r.permission_set_id) into eff from people pp left join roles r on r.id = pp.role_id where pp.id = pid;
  if p_enabled and eff is null then raise exception 'Choose an access profile for this person first: their job has none.'; end if;
  perform perm_guard();
  return json_build_object('person_id', pid, 'email', lower(p_email), 'enabled', p_enabled, 'profile_id', eff);
end $$;

drop function if exists public.eos_set_preview(integer);
create or replace function public.eos_set_preview(p_set uuid) returns uuid language plpgsql security definer set search_path to 'public' as $$
declare me uuid; own uuid; ok boolean;
begin
  select pp.id, coalesce(pp.permission_set_id, r.permission_set_id) into me, own
    from people pp left join roles r on r.id = pp.role_id where pp.auth_user_id = auth.uid() and pp.login_enabled limit 1;
  if me is null then raise exception 'Not signed in'; end if;
  if p_set is null or p_set = own then update people set preview_set_id = null where id = me; return null; end if;
  select ps.tier = 'executive' and 'roles.manage' = any(eos_person_grants(me)) into ok from permission_sets ps where ps.id = own;
  if not coalesce(ok, false) then raise exception 'Only an Executive-tier administrator can view EOS as another profile'; end if;
  if not exists (select 1 from permission_sets where id = p_set) then raise exception 'Unknown access profile'; end if;
  update people set preview_set_id = p_set where id = me;
  return p_set;
end $$;

drop function if exists public.perm_person_set(uuid, uuid, text[], text[]);
create or replace function public.perm_person_set(p_person uuid, p_set uuid, p_extra text[])
returns void language plpgsql security definer set search_path to 'public' as $$
declare valid text[]; bad text[];
begin
  if not (eos_can('roles.manage') or eos_can('directory.manage')) then raise exception 'You do not have permission to change a person''s access'; end if;
  if p_set is not null and not exists (select 1 from permission_sets where id = p_set) then raise exception 'Unknown access profile'; end if;
  valid := array(select e->>'key' from jsonb_array_elements((select value from settings where key = 'permissions')) e);
  bad := array(select x from unnest(coalesce(p_extra, '{}')) x where not (x = any(valid)));
  if cardinality(bad) > 0 then raise exception 'Unknown permission: %', bad[1]; end if;
  update people set permission_set_id = p_set, extra_grants = array(select distinct x from unnest(coalesce(p_extra, '{}')) x), updated_at = now() where id = p_person;
  if not found then raise exception 'Person not found'; end if;
  perform perm_guard();
end $$;

drop function if exists public.perm_set_save(uuid, text, text, text[]);
create or replace function public.perm_set_save(p_id uuid, p_name text, p_description text, p_grants text[], p_tier text default null)
returns uuid language plpgsql security definer set search_path to 'public' as $$
declare sid uuid := p_id; valid text[]; bad text[]; cur record;
begin
  perform eos_require('roles.manage');
  if btrim(coalesce(p_name, '')) = '' then raise exception 'Give the profile a name'; end if;
  if p_tier is not null and p_tier not in ('staff','management','executive') then raise exception 'The tier must be staff, management or executive'; end if;
  valid := array(select e->>'key' from jsonb_array_elements((select value from settings where key = 'permissions')) e);
  bad := array(select x from unnest(coalesce(p_grants, '{}')) x where not (x = any(valid)));
  if cardinality(bad) > 0 then raise exception 'Unknown permission: %', bad[1]; end if;
  if sid is null then
    insert into permission_sets (name, description, grants, sort_order, tier)
    values (btrim(p_name), p_description, array(select distinct x from unnest(coalesce(p_grants, '{}')) x), 100, coalesce(p_tier, 'staff')) returning id into sid;
  else
    select * into cur from permission_sets where id = sid;
    if not found then raise exception 'Profile not found'; end if;
    if cur.is_builtin and coalesce(p_tier, cur.tier) <> 'executive' then raise exception 'The % profile stays at the Executive tier', cur.name; end if;
    update permission_sets set name = btrim(p_name), description = p_description,
           grants = array(select distinct x from unnest(coalesce(p_grants, '{}')) x), tier = coalesce(p_tier, tier), updated_at = now()
     where id = sid;
  end if;
  perform perm_guard();
  return sid;
end $$;

-- Patch helpers for functions that only need one line changed (fails loudly if the line is not there)
create or replace function pg_temp.patch_fn(p_sig text, p_old text, p_new text) returns void language plpgsql as $$
declare d text;
begin
  d := pg_get_functiondef(p_sig::regprocedure);
  if position(p_old in d) = 0 then raise exception 'patch_fn: % does not contain: %', p_sig, left(p_old, 80); end if;
  execute replace(d, p_old, p_new);
end $$;

-- task templates: a grant, not a level
select pg_temp.patch_fn('public.tpl_save(uuid,jsonb)', $o$if coalesce(public.eos_level(), 0) < 4 then raise exception 'Templates are for level 4 and up'; end if;$o$, $n$perform public.eos_require('templates.use');$n$);
select pg_temp.patch_fn('public.tpl_make_task(uuid,date)', $o$if coalesce(public.eos_level(), 0) < 4 then raise exception 'Templates are for level 4 and up'; end if;$o$, $n$perform public.eos_require('templates.use');$n$);
select pg_temp.patch_fn('public.tpl_delete(uuid)', $o$if coalesce(public.eos_level(), 0) < 4 then raise exception 'Templates are for level 4 and up'; end if;$o$, $n$perform public.eos_require('templates.use');$n$);
-- layouts: per tier, not per level
select pg_temp.patch_fn('public.eos_set_layout(text,text,jsonb)', $o$'^(default|level:[0-6]|role:[0-9a-f-]{36})$'$o$, $n$'^(default|tier:(staff|management|executive)|role:[0-9a-f-]{36})$'$n$);
-- new requests go to the people who can handle them
select pg_temp.patch_fn('public.trg_notif_request()',
  $o$where pp.login_enabled and not coalesce(pp.inactive, false) and coalesce(pp.visibility_level, r.visibility_level, 0) >= 4 and pp.id is distinct from new.requested_by loop$o$,
  $n$where pp.login_enabled and not coalesce(pp.inactive, false) and 'requests.handle' = any(eos_person_grants(pp.id)) and pp.id is distinct from new.requested_by loop$n$);
-- the access audit probes the three tiers and checks every account has a profile
select pg_temp.patch_fn('public.eos_access_audit()', $o$for lv in 0..5 loop$o$, $n$foreach lv in array array[0,3,5] loop$n$);
select pg_temp.patch_fn('public.eos_access_audit()',
  $o$for g in select p.full_name, p.visibility_level from people p where p.login_enabled and (p.visibility_level is null or p.visibility_level not between 0 and 6) loop
    check_name:='login_without_level'; level:=null; object_name:=g.full_name; detail:='login enabled but visibility_level is '||coalesce(g.visibility_level::text,'null'); return next; end loop;$o$,
  $n$for g in select p.full_name from people p left join roles r on r.id = p.role_id where p.login_enabled and coalesce(p.permission_set_id, r.permission_set_id) is null loop
    check_name:='login_without_profile'; level:=null; object_name:=g.full_name; detail:='can sign in but has no access profile (none on the person, none on the job)'; return next; end loop;$n$);

drop function if exists public.eos_level_set(integer);

-- ───────────────────────────── 4. record visibility: one field ─────────────────────────────
do $$ declare t text;
begin
  foreach t in array array['meetings','work_orders','projects','docs','dashboards'] loop
    execute format('alter table public.%I add column if not exists visibility text not null default ''everyone''', t);
    execute format('alter table public.%I drop constraint if exists %I', t, t || '_visibility_check');
    execute format('alter table public.%I add constraint %I check (visibility in (''everyone'',''management'',''executive''))', t, t || '_visibility_check');
    execute format('update public.%I set visibility = case when visible_levels is null or visible_levels && array[0,1,2,3] then ''everyone''
                                                           when visible_levels && array[4,5] then ''management'' else ''executive'' end', t);
  end loop;
end $$;

-- the views: visible_levels → visibility in the column lists and row filters
update public.view_defs set
  base_sql = regexp_replace(base_sql, '\m([a-z]+)\.visible_levels AS work_order_visible_levels', '\1.visibility AS work_order_visibility', 'g'),
  row_filter = replace(replace(row_filter, 'eos_level() >= 4', 'eos_level() >= 5'),
                       'eos_level() = ANY(_s.work_order_visible_levels)', 'eos_level() >= eos_vis_level(_s.work_order_visibility)')
 where view_name in ('v_task_tracker', 'v_form_records');
update public.view_defs set
  base_sql = regexp_replace(base_sql, '\m([a-z]+)\.visible_levels\M', '\1.visibility', 'g'),
  row_filter = replace(replace(row_filter, 'eos_level() = 6 OR eos_level() = ANY(_s.visible_levels)', 'eos_level() >= eos_vis_level(_s.visibility)'),
                       'eos_level() = ANY(_s.visible_levels)', 'eos_level() >= eos_vis_level(_s.visibility)')
 where view_name in ('v_meetings', 'v_work_orders', 'v_projects', 'v_docs', 'v_dashboards');
do $$ declare n int;
begin
  select count(*) into n from view_defs where base_sql ~ 'visible_levels' or coalesce(row_filter, '') ~ 'visible_levels';
  if n > 0 then raise exception 'view_defs still mention visible_levels in % view(s)', n; end if;
end $$;

-- the account views
update public.view_defs set description = 'The signed-in user: profile, data tier, grants, and the profiles they may preview', base_sql = $v$
 SELECT p.id, p.full_name, p.first_name, p.email_address, p.title, p.department, p.person_type,
        eos_level() AS tier_level,
        (SELECT ps.tier FROM permission_sets ps WHERE ps.id = pr.set_id) AS tier,
        eos_tier_level((SELECT ps.tier FROM permission_sets ps WHERE ps.id = pr.own_set_id)) AS own_level,
        p.login_enabled, p.role_id, (SELECT r.title FROM roles r WHERE r.id = p.role_id) AS role_title,
        p.photo_path, p.background_path, p.home_layout, eos_grants() AS grants,
        pr.set_id AS profile_id, (SELECT ps.name FROM permission_sets ps WHERE ps.id = pr.set_id) AS profile_name,
        CASE WHEN p.permission_set_id IS NOT NULL THEN 'person' ELSE 'role' END AS profile_source,
        p.extra_grants,
        p.preview_set_id, (SELECT ps.name FROM permission_sets ps WHERE ps.id = p.preview_set_id) AS preview_name,
        cp.ok AS can_preview,
        CASE WHEN cp.ok THEN (SELECT jsonb_agg(jsonb_build_object('id', ps.id, 'name', ps.name, 'tier', ps.tier) ORDER BY ps.sort_order, ps.name) FROM permission_sets ps) END AS profiles
   FROM people p
   CROSS JOIN LATERAL eos_my_profile() pr
   CROSS JOIN LATERAL (SELECT coalesce((SELECT ps.tier = 'executive' AND 'roles.manage' = ANY(ps.grants || coalesce(p.extra_grants, '{}')) FROM permission_sets ps WHERE ps.id = pr.own_set_id), false) AS ok) cp
  WHERE p.auth_user_id = auth.uid() AND p.login_enabled $v$
 where view_name = 'v_me';

update public.view_defs set description = 'Every sign-in and the person it belongs to: job, access profile, tier, last sign-in, edits in 30 days', base_sql = $v$
 SELECT p.id AS person_id, p.full_name, p.email_address, p.title, p.department,
        p.login_enabled, p.inactive, p.last_seen_at,
        u.id AS auth_user_id, u.email::varchar(255) AS auth_email, u.created_at AS login_created_at, u.confirmed,
        p.role_id, r.title AS role_title,
        coalesce(p.permission_set_id, r.permission_set_id) AS profile_id,
        ps.name AS profile_name, ps.tier,
        CASE WHEN p.permission_set_id IS NOT NULL THEN 'person' WHEN r.permission_set_id IS NOT NULL THEN 'role' END AS profile_source,
        p.permission_set_id, p.extra_grants,
        s.last_sign_in_at, s.recovery_sent_at, s.banned,
        (SELECT count(DISTINCT rc.record_id::text || date_trunc('minute', rc.at)::text) FROM public.record_changes rc
          WHERE rc.actor_id = p.id AND rc.at > now() - interval '30 days') AS edits_30d
   FROM public.eos_auth_accounts() u
   LEFT JOIN public.eos_auth_signins() s ON s.id = u.id
   LEFT JOIN people p ON p.auth_user_id = u.id
   LEFT JOIN roles r ON r.id = p.role_id
   LEFT JOIN permission_sets ps ON ps.id = coalesce(p.permission_set_id, r.permission_set_id)
  ORDER BY p.full_name NULLS LAST, u.email $v$
 where view_name = 'v_logins';

update public.view_defs set description = 'Jobs (one per City job title) with the people in them and the access profile the job gives', base_sql = $v$
 SELECT r.id, r.title, r.department, r.reports_to, r.grade, r.bargaining_unit, r.summary, r.keywords,
        count(p.id) AS people_count,
        COALESCE(jsonb_agg(jsonb_build_object('id', p.id, 'name', p.full_name) ORDER BY p.full_name) FILTER (WHERE p.id IS NOT NULL), '[]'::jsonb) AS people,
        r.permission_set_id, ps.name AS permission_set_name, ps.tier,
        r.aliases, r.source,
        count(p.id) FILTER (WHERE p.login_enabled)::integer AS logins
   FROM roles r
   LEFT JOIN people p ON p.role_id = r.id
   LEFT JOIN permission_sets ps ON ps.id = r.permission_set_id
  GROUP BY r.id, ps.name, ps.tier $v$
 where view_name = 'v_roles';

update public.view_defs set base_sql = replace(base_sql, 'p.photo_path, p.permission_set_id, p.extra_grants, p.denied_grants,', 'p.photo_path, p.permission_set_id, p.extra_grants,')
 where view_name = 'v_people_directory';
update public.view_defs set base_sql = replace(base_sql, 's.is_builtin, s.updated_at,', 's.is_builtin, s.tier, s.updated_at,')
 where view_name = 'v_permission_sets';
do $$ begin
  if exists (select 1 from view_defs where base_sql ~ 'denied_grants|visibility_level|preview_level') then raise exception 'a view still mentions a level column'; end if;
  if not exists (select 1 from view_defs where view_name = 'v_permission_sets' and base_sql ~ 's\.tier') then raise exception 'v_permission_sets patch missed'; end if;
end $$;

-- Management-tier views that are really about a grant: say so in the view, not only in the app
update public.view_defs set row_filter = case when coalesce(btrim(row_filter), '') = '' then 'eos_can(''see.budget'')' else '(' || row_filter || ') AND eos_can(''see.budget'')' end
 where view_name in ('v_budget_lines', 'v_budget_rollup', 'v_budget_snapshots', 'v_funding_sources') and coalesce(row_filter, '') !~ 'see\.budget';
update public.view_defs set row_filter = case when coalesce(btrim(row_filter), '') = '' then 'eos_can(''see.system'')' else '(' || row_filter || ') AND eos_can(''see.system'')' end
 where view_name in ('v_ingest_runs', 'v_last_ingest', 'v_health_runs', 'v_health_checks', 'v_ingest_exceptions', 'v_email_activity', 'v_pinning_conflicts', 'v_documents_missing', 'v_documents_ungeocoded')
   and coalesce(row_filter, '') !~ 'see\.system';
update public.view_defs set row_filter = case when coalesce(btrim(row_filter), '') = '' then 'eos_can(''see.review'')' else '(' || row_filter || ') AND eos_can(''see.review'')' end
 where view_name = 'v_review_queue' and coalesce(row_filter, '') !~ 'see\.review';
-- templates: for anyone whose profile may use them (crew leaders are Staff tier)
update public.view_defs set min_level = 3, row_filter = 'eos_can(''templates.use'')' where view_name = 'v_task_templates';
-- document full text: Management (was level 4)
update public.view_defs set min_level = 5 where view_name = 'v_document_text';
update public.view_defs set min_level = 5 where min_level = 4;

-- field gates: the old level 4 is Management
update public.field_visibility set min_level = 5 where min_level = 4;
delete from public.field_visibility where column_name in ('visible_levels', 'work_order_visible_levels');
insert into public.field_visibility (column_name, min_level, view_name, note)
values ('visibility', 5, null, 'Who may see the record: everyone, management, executive. Management and up see and set it.'),
       ('work_order_visibility', 5, null, 'The work order''s visibility, carried on its tasks and forms.')
on conflict do nothing;

-- ───────────────────────────── 5. jobs: no access categories, no levels ─────────────────────────────
update public.people set permission_set_id = (select id from permission_sets where name = 'Consultant'), role_id = null, updated_at = now()
 where role_id in (select id from roles where department ilike 'access roles%');
delete from public.roles where department ilike 'access roles%';

-- ───────────────────────────── 6. rebuild every view, then drop the old columns ─────────────────────────────
do $$ declare v record;
begin
  for v in select view_name from view_defs loop execute format('drop view if exists public.%I cascade', v.view_name); end loop;
end $$;
drop trigger if exists trg_meetings_default_visible_levels on public.meetings;
drop function if exists public.meetings_default_visible_levels();
alter table public.people drop column if exists visibility_level, drop column if exists preview_level, drop column if exists denied_grants;
alter table public.roles drop column if exists visibility_level;
alter table public.meetings drop column if exists visible_levels;
alter table public.work_orders drop column if exists visible_levels;
alter table public.projects drop column if exists visible_levels;
alter table public.docs drop column if exists visible_levels;
alter table public.dashboards drop column if exists visible_levels;
select count(*) as views_rebuilt from public.rebuild_views();

-- ───────────────────────────── 7. settings ─────────────────────────────
delete from public.settings where key in ('visibility_levels', 'tabs_by_level');
insert into public.settings (key, value, min_level) values ('tiers', $j$[
  {"key": "staff", "label": "Staff", "summary": "Work, documents, the map, the calendar and staff work contact details."},
  {"key": "management", "label": "Management", "summary": "Staff, plus financial fields (estimated costs, budget lines), HR fields (hire date, cell), document full text, and records marked Management and up."},
  {"key": "executive", "label": "Executive", "summary": "Everything, including personnel notes, accounts, settings and records marked Executive only."}
]$j$::jsonb, 1)
on conflict (key) do update set value = excluded.value, min_level = excluded.min_level;
-- the permissions catalog: wording
update public.settings set value = (
  select jsonb_agg(case when e->>'key' = 'roles.manage'
                        then e || '{"label": "Manage access", "note": "Access profiles and their data tier, which profile each job gives, who can sign in."}'::jsonb
                        when e->>'key' = 'directory.manage'
                        then e || '{"note": "Add, edit, remove and delete people and organizations; give and take away sign-ins."}'::jsonb
                        else e end order by o)
    from jsonb_array_elements(value) with ordinality x(e, o))
 where key = 'permissions';
-- the editors: one visibility field instead of a level list; no level on jobs
update public.settings set value = (
  with t as (select jsonb_object_agg(tk, case
      when tk = 'roles' then (tv - 'order') || jsonb_build_object('order', (select jsonb_agg(x) from jsonb_array_elements(tv->'order') x where x #>> '{}' <> 'visibility_level'),
                                                                  'fields', (tv->'fields') - 'visibility_level')
      else tv end) as tables
    from jsonb_each(value->'tables') t(tk, tv))
  select value || jsonb_build_object('tables', (select tables from t)))
 where key = 'editing';
update public.settings set value = (
  with t as (select jsonb_object_agg(tk, (tv - 'fields' - 'order' - 'create_defaults')
      || jsonb_build_object('fields', coalesce((select jsonb_object_agg(fk, case when fv->>'type' = 'levels' then fv || '{"type": "visibility", "label": "Who can see this"}'::jsonb else fv end)
                                          from jsonb_each(coalesce(tv->'fields', '{}'::jsonb)) f(fk, fv)), '{}'::jsonb) - 'visible_levels'
                              || case when tv->'fields' ? 'visible_levels' then '{"visibility": {"type": "visibility", "label": "Who can see this"}}'::jsonb else '{}'::jsonb end)
      || case when tv ? 'order' then jsonb_build_object('order', (select jsonb_agg(case when x #>> '{}' = 'visible_levels' then '"visibility"'::jsonb else x end) from jsonb_array_elements(tv->'order') x)) else '{}'::jsonb end
      || case when tv ? 'create_defaults' then jsonb_build_object('create_defaults',
             case when tv->'create_defaults' ? 'visible_levels'
                  then (tv->'create_defaults') - 'visible_levels' || jsonb_build_object('visibility',
                         case when (tv->'create_defaults'->'visible_levels') @> '[3]' or (tv->'create_defaults'->'visible_levels') @> '[1]' then 'everyone'
                              when (tv->'create_defaults'->'visible_levels') @> '[4]' or (tv->'create_defaults'->'visible_levels') @> '[5]' then 'management' else 'executive' end)
                  else tv->'create_defaults' end) else '{}'::jsonb end) as tables
    from jsonb_each(value->'tables') t(tk, tv))
  select value || jsonb_build_object('tables', (select tables from t)))
 where key = 'editing';
do $$ begin
  if exists (select 1 from settings where key = 'editing' and value::text ~ 'visible_levels|visibility_level') then raise exception 'settings.editing still mentions levels'; end if;
end $$;
update public.data_dictionary
   set purpose = replace(purpose, 'visibility_level (0–6) and login_enabled decide what the person sees. Only rows with a login carry a level.',
                                  'login_enabled turns the sign-in on, permission_set_id (an access profile, usually from the job) decides what the person can do and which data tier they see.'),
       updated_at = now()
 where table_name = 'people';

-- ───────────────────────────── 8. the guard: nobody drops a tier (except the consultants, on purpose) ─────────────────────────────
do $$ declare r record; bad text := '';
begin
  for r in select b.full_name, b.old_level, b.old_tier_level, ps.name as profile, ps.tier
             from _before b join people p on p.id = b.id left join roles ro on ro.id = p.role_id
             left join permission_sets ps on ps.id = coalesce(p.permission_set_id, ro.permission_set_id) loop
    if r.profile is null then bad := bad || r.full_name || ' (no profile); '; end if;
    if eos_tier_level(r.tier) < r.old_tier_level and r.profile <> 'Consultant' then
      bad := bad || format('%s (was level %s, now %s · %s); ', r.full_name, r.old_level, r.profile, r.tier); end if;
  end loop;
  if bad <> '' then raise exception 'Access would change for: %', bad; end if;
end $$;

commit;

-- What every account has now
select p.full_name, r.title as job, ps.name as profile, ps.tier,
       case when p.permission_set_id is not null then 'set on the person' else 'from the job' end as profile_from,
       p.extra_grants, p.login_enabled
  from people p left join roles r on r.id = p.role_id
  left join permission_sets ps on ps.id = coalesce(p.permission_set_id, r.permission_set_id)
 where p.auth_user_id is not null
 order by ps.tier desc, p.full_name;
