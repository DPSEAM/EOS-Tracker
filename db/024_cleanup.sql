-- 024 · Clean-up: dead objects out, one installed-features view, work packages become WP- — 2026-11-01
-- Paste once into the Supabase SQL editor. The editor runs statements one by one; every statement here is safe to
-- run again on its own. Goes with build v206.
--
-- What it does
--   1. Drops the calendar scratch tables from September, the empty OpenGov snapshot table, 49 scratch settings rows,
--      16 functions nothing calls, and two views the app never reads (v_health_checks, v_landmarks). Everything was
--      checked against the live database on 2026-11-01: no function, view, trigger, scheduled job or app call uses them.
--   2. Work packages are referred to as WP-0001 instead of P-0001, so they no longer share a prefix with projects.
--   3. v_features: one row that says which parts of EOS are installed. The app reads it once at sign-in instead of
--      probing each view for a 404.

select set_config('eos.via', 'admin', true);

-- ───────────── 1. dead objects ─────────────
drop table if exists public._eos_cal_staging;
drop table if exists public.cal_event_staging;
drop table if exists public._cal_sync_staging;
drop table if exists public.opengov_snapshot;

delete from public.settings
 where key like '\_cal\_ev\_%' or key in ('_cal_sync_staging', '_cal_sync_temp', 'backup_field_forms_20261020', 'staging_field_forms');

do $$ declare r record;
begin
  for r in select p.oid::regprocedure as sig
             from pg_proc p join pg_namespace n on n.oid = p.pronamespace
            where n.nspname = 'public' and p.proname in (
              'tmp_cal_batch1', 'tmp_cal_batch2', 'tmp_close_ingest_run', '_ingest_close_run', '_pavement_load_2025',
              'eos_split_details', 'eos_standardize_details', 'eos_standardize_wo_details', 'eos_arr_text', 'eos_is_eos_user',
              'ingest_set_doc_text', 'finish_health_run', 'opengov_get', 'opengov_snapshot_creds', 'opengov_snapshot_run',
              'eos_assets_after_sync')
  loop
    execute 'drop function if exists ' || r.sig || ' cascade';
  end loop;
end $$;

drop view if exists public.v_health_checks;
drop view if exists public.v_landmarks;
delete from public.view_defs where view_name in ('v_health_checks', 'v_landmarks');

-- ───────────── 2. work packages: WP- ─────────────
do $$ declare d text;
begin
  d := pg_get_functiondef('public.trg_notif_package()'::regprocedure);
  if position($o$'P-' || lpad(new.package_number::text, 4, '0')$o$ in d) > 0 then
    execute replace(d, $o$'P-' || lpad(new.package_number::text, 4, '0')$o$, $n$'WP-' || lpad(new.package_number::text, 4, '0')$n$);
  end if;
end $$;
update public.notifications
   set title = regexp_replace(title, '\mP-(\d{4})\M', 'WP-\1', 'g'), body = regexp_replace(coalesce(body, ''), '\mP-(\d{4})\M', 'WP-\1', 'g')
 where kind = 'package' and (title ~ '\mP-\d{4}\M' or coalesce(body, '') ~ '\mP-\d{4}\M');

-- ───────────── 3. installed features ─────────────
-- pg_catalog is readable by everyone, so the checks work for a signed-in user; information_schema would hide tables they have no grant on.
create or replace function public.eos_has_column(p_table text, p_column text) returns boolean language sql stable as $$
  select exists (select 1 from pg_attribute a where a.attrelid = to_regclass('public.' || p_table) and a.attname = p_column and a.attnum > 0 and not a.attisdropped) $$;
insert into public.view_defs (view_name, min_level, row_filter, description, base_sql)
values ('v_features', 0, null, 'One row: which parts of EOS are installed. The app reads it once at sign-in.', $v$
 SELECT jsonb_build_object(
   'messages',          to_regclass('public.msg_messages') IS NOT NULL,
   'favorites',         to_regclass('public.favorites') IS NOT NULL,
   'requests',          to_regclass('public.requests') IS NOT NULL,
   'packages',          to_regclass('public.work_packages') IS NOT NULL,
   'package_templates', to_regclass('public.wp_templates') IS NOT NULL,
   'task_dependencies', to_regclass('public.task_dependencies') IS NOT NULL,
   'task_templates',    to_regclass('public.task_templates') IS NOT NULL,
   'recycle_bin',       to_regclass('public.recycle_bin') IS NOT NULL,
   'notifications',     to_regclass('public.notifications') IS NOT NULL,
   'push',              to_regclass('public.push_subscriptions') IS NOT NULL,
   'permissions',       to_regclass('public.permission_sets') IS NOT NULL,
   'access_tiers',      eos_has_column('permission_sets', 'tier'),
   'page_errors',       to_regprocedure('public.eos_page_errors(integer)') IS NOT NULL,
   'backup_check',      to_regprocedure('public.eos_backup_report()') IS NOT NULL,
   'budget',            to_regclass('public.budget_lines') IS NOT NULL,
   'asset_types',       eos_has_column('assets', 'attributes'),
   'ingest_rules',      to_regprocedure('public.eos_ingest_begin()') IS NOT NULL
 ) AS features $v$)
on conflict (view_name) do update set base_sql = excluded.base_sql, min_level = excluded.min_level, row_filter = excluded.row_filter, description = excluded.description;
select count(*) as views_rebuilt from public.rebuild_views();

-- What is installed now
select * from public.v_features;
