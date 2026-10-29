-- 017 · Budget charts (v193): ledger snapshots over time, a loader the app calls, division names,
-- funding sources editable from the app, and the Funding roll-up with account and department.
-- Safe to run more than once. Run after 002 (budget_lines), 006 (guards) and 016 (permissions).
begin;
select set_config('eos.via', 'admin', true);   -- 006 guards view_defs and settings: changes from the SQL editor must say they are an administrator

-- ── 1. Load a ledger report from the app ─────────────────────────────────────────────────────────────────
-- Budget › Budget lines › "Load ledger report" parses the City's Ytd_Budget_Report workbook in the browser and sends
-- the rows here. One call per as-of date; the rows for that date are replaced, so a report can be loaded again.
-- Every load is a snapshot: the Overview chart draws spending through the year from one point per as-of date.
create or replace function public.eos_budget_load(p_as_of date, p_fiscal_year int, p_source text, p_rows jsonb, p_fund_groups jsonb default '{}'::jsonb)
returns jsonb language plpgsql security definer set search_path to 'public' as $function$
declare n int; fy int;
begin
  if to_regproc('public.eos_require') is not null then perform public.eos_require('invoices.approve');   -- the permission model from 016
  elsif eos_level() < 5 then raise exception 'Loading the ledger needs a level-5 login'; end if;
  if p_as_of is null then raise exception 'An as-of date is required'; end if;
  if p_rows is null or jsonb_typeof(p_rows) <> 'array' or jsonb_array_length(p_rows) = 0 then raise exception 'Nothing to load'; end if;
  fy := coalesce(p_fiscal_year, eos_fy(p_as_of));
  perform set_config('eos.via', 'app', true);
  delete from budget_lines where as_of = p_as_of;
  insert into budget_lines (as_of, fiscal_year, fund, fund_group, org, org_name, object, account_description,
                            original_appropriation, adjustments, ytd_actual, encumbrance, source_file)
  select p_as_of, fy, r.fund,
         coalesce(nullif(p_fund_groups->>r.fund, ''),
                  case when r.fund = '001' then 'General Fund' when r.fund in ('002','004','006') then 'Enterprise Fund' else 'Other' end),
         r.org,
         coalesce(max(nullif(r.org_name, '')),
                  (select bl.org_name from budget_lines bl where bl.org = r.org and bl.org_name is not null order by bl.as_of desc limit 1)),
         r.object, max(nullif(r.descr, '')),
         sum(coalesce(r.orig, 0)), sum(coalesce(r.adj, 0)), sum(coalesce(r.ytd, 0)), sum(coalesce(r.enc, 0)),
         left(coalesce(p_source, 'app'), 200)
    from (select case when btrim(x.fund) ~ '^\d+$' then lpad(btrim(x.fund), 3, '0') else btrim(x.fund) end as fund,     -- codes as the ledger writes them: 001, 14101, 51105
                 case when btrim(x.org) ~ '^\d+$' then lpad(btrim(x.org), 5, '0') else btrim(x.org) end as org,
                 case when btrim(x.object) ~ '^\d+$' then lpad(btrim(x.object), 5, '0') else btrim(x.object) end as object,
                 x.org_name, x.descr, x.orig, x.adj, x.ytd, x.enc
            from jsonb_to_recordset(p_rows) as x(fund text, org text, org_name text, object text, descr text, orig numeric, adj numeric, ytd numeric, enc numeric)) r
   where nullif(r.fund, '') is not null and nullif(r.org, '') is not null and nullif(r.object, '') is not null
   group by r.fund, r.org, r.object;
  get diagnostics n = row_count;
  perform set_config('eos.via', '', true);
  return jsonb_build_object('loaded', n, 'as_of', p_as_of, 'fiscal_year', fy);
end $function$;
revoke all on function public.eos_budget_load(date, int, text, jsonb, jsonb) from public, anon;
grant execute on function public.eos_budget_load(date, int, text, jsonb, jsonb) to authenticated;

-- ── 2. Snapshots: one row per as-of date, fund and organization (small; the chart and the Home card read this) ──
insert into public.view_defs (view_name, base_sql, min_level, row_filter, description) values ('v_budget_snapshots', $v$
 SELECT bl.as_of, bl.fiscal_year, bl.fund_group, bl.fund, bl.org, max(bl.org_name) AS org_name, bl.line_type,
        sum(bl.revised_budget)::numeric(14,2) AS revised_budget, sum(bl.ytd_actual)::numeric(14,2) AS ytd_actual,
        sum(bl.encumbrance)::numeric(14,2) AS encumbrance, count(*)::int AS lines
   FROM budget_lines bl
  GROUP BY bl.as_of, bl.fiscal_year, bl.fund_group, bl.fund, bl.org, bl.line_type
$v$, 5, null, 'Budget by as-of date, fund and organization: one row per ledger load. Level 5 and above.')
on conflict (view_name) do update set base_sql = excluded.base_sql, min_level = excluded.min_level, description = excluded.description, updated_at = now();

-- ── 3. Funding roll-up carries the account, department and notes, so the Funding tab can show and edit them ──
insert into public.view_defs (view_name, base_sql, min_level, row_filter, description) values ('v_budget_rollup', $v$
 SELECT s.*, (s.budget - s.committed)::numeric(14,2) AS uncommitted
   FROM (
     SELECT fs.id AS funding_source_id, fs.id, fs.name, fs.source_type, fs.fiscal_year, fs.account_string, fs.department, fs.is_active, fs.notes,
            fs.amount, fs.amount AS budget,
            COALESCE((SELECT sum(c.fee_total) FROM commitments c
                       WHERE c.funding_source_id = fs.id AND c.status = 'executed'), 0)::numeric(14,2) AS committed,
            COALESCE((SELECT sum(i.amount) FROM invoices i JOIN commitments c ON c.id = i.commitment_id
                       WHERE c.funding_source_id = fs.id AND i.status NOT IN ('void','rejected','needs_match')), 0)::numeric(14,2) AS invoiced,
            COALESCE((SELECT sum(i.paid_amount) FROM invoices i JOIN commitments c ON c.id = i.commitment_id
                       WHERE c.funding_source_id = fs.id AND i.status = 'paid'), 0)::numeric(14,2) AS paid
       FROM funding_sources fs) s
$v$, 5, null, 'Funding sources with what is committed, invoiced and paid against each. Level 5 and above.')
on conflict (view_name) do update set base_sql = excluded.base_sql, min_level = excluded.min_level, description = excluded.description, updated_at = now();
drop view if exists public.v_budget_rollup;   -- columns are added in the middle; create-or-replace cannot reorder a view's columns, so it is recreated (nothing depends on it)
select public.rebuild_views();

-- ── 4. Funding sources can be added and edited from the app (Budget › Funding, and from a budget line) ──
-- Goes through eos_create / eos_edit like every other record, so every change is in the record history.
update public.settings
   set value = jsonb_set(value, '{tables,funding_sources}', $j${
     "label": "funding source", "create": true,
     "order": ["name","source_type","fiscal_year","account_string","amount","department","is_active","notes"],
     "fields": {
       "name":           {"type":"text",     "label":"Name", "required":true},
       "source_type":    {"type":"select",   "label":"Type", "options":["Appropriation","Enterprise","Capital","Chapter 90","Grant","Bond","Revolving","Other"], "required":true},
       "fiscal_year":    {"type":"number",   "label":"Fiscal year (named for the year it ends in)"},
       "account_string": {"type":"text",     "label":"Ledger account (fund-org-object, e.g. 001-14102-53853)"},
       "amount":         {"type":"number",   "label":"Amount ($)"},
       "department":     {"type":"text",     "label":"Department / division"},
       "is_active":      {"type":"bool",     "label":"Active"},
       "notes":          {"type":"textarea", "label":"Notes", "rows":3}
     },
     "create_defaults": {"source_type":"Appropriation", "is_active":true}
   }$j$::jsonb, true),
       updated_at = now()
 where key = 'editing';

-- ── 5. Funding sources are edited under the same permission as commitments (016 maps unknown tables to settings.manage) ──
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
    when 'funding_sources' then 'commitments.edit'
    else case when p_table like 'pavement%' then 'pavement.manage' else 'settings.manage' end end
$$;

-- ── 6. Division names by ledger code, so the Overview can be read by division (and permissions can use the same codes later) ──
-- General Fund orgs are 1 + the three-digit department code + a category digit (14101 = Engineering 410, personal services).
-- Enterprise funds are keyed by fund number. Edit the names here; the app falls back to these if the setting is missing.
insert into public.settings (key, value, description, min_level) values ('budget_divisions', $j${
  "400":"DPW Administration", "410":"Engineering", "415":"Sanitation", "422":"Highway", "423":"Snow & Ice", "425":"Maintenance",
  "430":"Sanitation", "490":"Municipal Garage", "491":"Cemetery", "492":"Electrical", "493":"Parks & Forestry",
  "fund:002":"Water", "fund:004":"Sewer", "fund:006":"Sanitation Enterprise"
}$j$::jsonb, 'Division name for each ledger department code (General Fund org digits 2-4) or enterprise fund (fund:NNN). Used by Budget › Overview.', 5)
on conflict (key) do nothing;

commit;
