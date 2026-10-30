# EOS system review · October 30, 2026

A whole-system look at EOS as it stands at v202: what to consolidate, what to remove, and what to standardize so the
app and the database read as one connected system. Based on the full app code, the live database, and every page
rendered in a headless browser with stand-in data. The decisions Sam takes from this move into PLAN.md as builds.

## 1. The shape of the system today

- **App**: one file, 1.68 MB, 14,600 lines. 19 pages (home, meetings, tasks, projects, workorders, budget, people, system,
  documents, map, assets, pavement, dashboards, chat, kb, search, messages, requests, packages). 20 Home card types.
  About 20 features were added as "blocks" that wrap earlier functions (loadCore, applyTabs, newMenuItems, lkBulkBar,
  renderProjects are each wrapped two to four times).
- **Database**: 56 tables, 67 views, about 150 functions, 68 triggers, 113 settings rows, 4 scheduled jobs, 2 Edge
  Functions. Row-level security is on with no policies; everything the app reads goes through views, everything it
  writes through functions. That part is right and should stay.
- **People**: 20 EOS users across 4 levels; 6 permission sets; 33 of 69 roles mapped.

## 2. What is unnecessary (database)

Empty or dead, safe to drop in one cleanup script:

| Object | Why |
|---|---|
| `_eos_cal_staging`, `cal_event_staging`, `_cal_sync_staging` (386 rows) | Calendar sync scratch tables from September. Nothing reads them. |
| 48 settings rows named `_cal_ev_*`, `_cal_sync_temp`, `backup_field_forms_20261020`, `staging_field_forms` | Scratch copies kept as settings. |
| `tmp_cal_batch1`, `tmp_cal_batch2`, `tmp_close_ingest_run`, `_ingest_close_run`, `_pavement_load_2025` | One-off helpers nothing calls. |
| `eos_split_details`, `eos_standardize_details`, `eos_standardize_wo_details`, `eos_arr_text`, `eos_is_eos_user`, `ingest_set_doc_text`, `finish_health_run`, `opengov_get`, `opengov_snapshot_creds`, `eos_assets_after_sync` | Functions no app call, trigger, view, job or other function references. |
| `opengov_snapshot` (0 rows), `assets` (0 rows: assets read live from ArcGIS since v165) | Tables superseded by a later design. |
| Views `v_documents_missing`, `v_documents_ungeocoded`, `v_health_checks`, `v_ingest_exceptions`, `v_landmarks`, `v_pinning_conflicts` | Never read by the app. Either show them in System Health › Data quality or drop them. |
| `rpc_allowlist` setting | Listed in every script, enforced nowhere except an audit report. Enforce it in one place or drop it. |

Empty but live (keep, they are features that have not been used yet): `favorites` (0 rows after a month: see §4),
`form_records`, `task_dependencies`, `funding_sources`, `pavement_utility_items`, `recycle_bin`.

Debt worth fixing while the data is small:

- **Two record types share the `P-` prefix**: projects are P-0038 and work packages are P-0001. Packages should be `WP-`.
- **Tasks carry eight status-like columns**: status, progress_status, review_status, review_reasons, review_flagged_at,
  review_resolution, complete_pending_approval, sync_status. Two are needed: `status` and one review flag with a reason.
- **Work orders**: the title column is called `project_name` (an OpenGov leftover) next to a real `project_id`, and there are
  fifteen free-text columns (description, summary, problem_text, notes, instructions_scope_details, next_steps, waiting_on,
  key_details, councilor_report, mayor_report and more). Keep four: title, description, summary, notes.
- **Data dictionary** describes 32 of 56 tables. Every table should have a line, and the 68 triggers should be listed
  there too, because most of EOS's behavior now lives in triggers (relinking, guards, notifications, package sync).
- **Levels and permissions both still gate tabs**: `tabs_by_level` remains in settings and the app falls back to it. Once
  db/016 has run everywhere, tabs should follow permissions only and the setting goes.

## 3. Information architecture: 19 pages to 8 sections

Today the menu lists 19 pages, several of which are the same idea from a different angle. Proposed top level:

| Section | Holds | What moves |
|---|---|---|
| Home | greeting, search and Ask AI, your dashboard, shared dashboards as tabs | Dashboards page folds in here; Pavement's dashboard becomes a shared dashboard; Chat page becomes the Ask AI mode of search (it already is) |
| Work | Tasks · Work Orders · Projects · Requests · Packages · Templates | Task templates and package templates become one Templates bubble |
| Calendar | meetings, timeline, recurring, subscribe | unchanged |
| Money | Budget · Authorizations · Project funding · Contracts · POs · Invoices | already tabs since v201 |
| Map | GIS layers · Assets · Pavement · Documents on the map | Assets page (already hidden) and Pavement move under Map as modes |
| Documents | library · Knowledge Base · collections (planned) | Knowledge Base becomes a tab of Documents |
| Directory | people · organizations · org chart · accounts | unchanged |
| System | health, roles and permissions, settings, recycle bin | unchanged |

Messages stops being a page and becomes a panel like the bell (it is a conversation list, not a place to work).
Search results stay a page but open from the one search box.

## 4. One way to do each thing

Where two or more controls do nearly the same job, and what to keep.

| Today | Keep | Drop or merge |
|---|---|---|
| Add update (dictate, filed by ingest) · + Note on a task · Discuss (message) · Request | **Add note** on the record, posted at once; the ingest enriches it afterwards. **Request** for people outside Work. | The separate Add update dialog; Discuss stays but only on records with more than one party. |
| Home search · Ctrl/Cmd+K · in-page Find · a search box on every list · map search | **One search** in the header with scope chips (everything, this list, this page, map). | Per-page search boxes become the same control with the scope preset. |
| Run ingest now in the account menu · on the Home ingest card · after an update | **Home ingest card** (and System Health). | The account-menu row and the after-update tick box. |
| Task templates · Package templates | **Templates** bubble on Work, with a kind. | Two separate dialogs and two tables (`task_templates`, `wp_templates`) become one. |
| Favorites card · My tasks · Work packages for me | **My tasks** and **Packages**. | Favorites: nobody has starred anything in a month. Remove the card and the table, or rename it Pinned and put it in the menu. |
| Dashboards page · Pavement dashboard · Budget Overview · Home gadgets | **Home** is the dashboard; shared dashboards are tabs on Home; Budget Overview stays as the Money landing tab. | The Dashboards page and Pavement as a top-level page. |
| Flagged for review · Needs attention card · Data quality · Ingest exceptions | **Needs attention**, one queue with a kind column (review, stale, no owner, data quality, ingest). | The separate Review filter and the two unread views. |
| Remove from directory · Delete person | Both, but **Remove** is renamed **Mark inactive**. | |
| Levels · permission sets · visible_levels arrays · field_visibility | Levels for rows and fields; permissions for actions and tabs. | `tabs_by_level`. |
| Three ways to open a record: list row, mini page, full page | **Mini page** on wide screens, full page on phones, same markup. | The S/M/L size control; one size that remembers. |

## 5. Glanceability: a standard record page

Every record page (task, work order, project, person, document, package, request, meeting) gets the same frame:

1. **Header**: reference and status pill, title, one line of facts (owner, due or date, where it sits: work order, project, package).
2. **Three actions** that matter for that record, then **More ▾** for everything else. A task today shows Edit, Done, Delete,
   Add update, Discuss, Find, S, M, L, expand and close in the header: eleven controls before the content.
3. **Glance strip**: four to six facts, the same order on every record.
4. **Tabs**: Details · Activity · Documents · History, with counts. Work orders have this; tasks and projects do not.

Lists: one header row, one search, one Filters button, one view switch (list, board), and one Select mode. Tasks has
all of these; Documents and Directory each have their own variants.

Home: the standard layout shows eight cards. Fewer, larger cards read faster on the iPad: My work at a glance,
My tasks, Notifications, Timeline, Packages, Weather. The others stay available through Edit dashboard.

## 6. App structure

- Fold the feature blocks (P13 field, P14 home and work extras, P15 packages, notifications, permissions, push) into the
  main code paths instead of wrapping functions. Same behavior, one place to read it, no ordering accidents like the
  budget card that stopped v193 loading.
- Replace the scattered "needs db/0xx" messages with one **features** view from the database that says what is
  installed. The app asks once at sign-in instead of probing each view for a 404.
- Split the file into index.html plus one script file served next to it. One file was right for a long time; at 1.7 MB
  a second file costs nothing and makes diffs and reviews readable. GitHub Pages serves both the same way.

## 7. Working practice

- One build session at a time. Two sessions pushing on the same day produced two v193s, two v195s, a boot failure that
  reached the live site, and a database script number taken twice.
- Every build: changelog line in plain words, test headless, push. Every database script: numbered from the repo,
  tested on the local stand-in, safe to run twice.

## 8. Proposed order

1. **Cleanup** (one database script, one app build): drop the dead objects in §2, rename packages to WP-, add the features
   view, remove `tabs_by_level`. Low risk, nothing visible changes except the prefix.
2. **Navigation**: the eight sections in §3. Mostly moving existing pages under new headings.
3. **One way to do each thing**: §4, one row per build.
4. **Standard record page**: §5, applied to tasks first, then the rest.
5. **Data model tidy**: task status fields, work order columns, the data dictionary.
6. **App structure**: §6, once the above has settled.
