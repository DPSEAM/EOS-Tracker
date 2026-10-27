# EOS Build Plan (Project #8 "EOS System Development")

Updated 2026-10-27 after v187 went live and v188 went to staging. The live plan is in EOS itself (Project #8, one work order per area); this file is the readable copy for people and for Claude conversations. Numbers are EOS task numbers. The short list also lives in `settings.deployment.planned` (db/012) and shows on the *Coming* tab of What's new.

## Done since the last plan
- db/001 to db/011 run on 2026-10-27 (#1322). Budget lines (694), Messages, Modified by, calendar link, ingest guards, error log, favorites, templates, dependencies, Requests and work packages are all in the database.
- v187 live: slim header, floating GIS, iPad layout fixes, Home touches.
- GitHub reorganised: README, CHANGELOG, PLAN, docs/DESIGN, `test/` staging. Claude can push from a session when Sam grants write access at the start of it.

## Waiting on Sam
- Say "go" on v188 (staging at /test/), then run db/012 (planned-builds list).
- CYVL: their notes on plan-to-GIS extraction, and what format the LiDAR point cloud is in (LAS/LAZ, COPC, I3S/SLPK, Potree).
- A sharper Home background (≥ 3840×2160) and which basemaps look blurry, at what zoom.
- Rotate the Anthropic API key, expires Oct 31 (#1317, #1328).
- Tracy: FY2026 month-end Munis YTD reports (July 2025–June 2026) for the budget history chart.
- Decisions in `docs/DESIGN.md`: who may edit the Directory; the permissions model; ID display; notifications channels; where invoices are extracted.
- Earlier lists still open: data change lists #841 #842 #839 #840 #112 #976 #1000 #971; ingest rules #843 #892 #1242 #787 #122; Monday reports #16 #17; #1272 status model; #1259 hosting; #1293 roles with no level.

## Next builds, in order
1. **v189 Work packages** (db/011 in): + New › Work package, add-to-package from any list, Packages for you / I sent on Home, package page with items, Done ticks, accept / send back, print as field sheet.
2. **v190 Ask AI hands you the file**: `get_document` tool in eos-chat returns the file (signed URL) and its text; the answer carries a document card that opens the preview; same for tasks, work orders and people (open-in-mini-page chips).
3. **v191 Saved AI conversations** (new table `ai_conversations`, needs approval): history list, titles, search, delete, continue.
4. **v192 Roles and permissions manager** (after the design decision): System Health › Access, role templates, per-tab and per-action grants, a person's effective access in one view, audit of changes.
5. **v193 Budget chart and forecast**: spend by date, projection to June 30, division cards, drill-down to POs, invoices and work (needs FY2026 history for a real curve).
6. **v194 Work tied to assets**: asset links on tasks, work orders and requests; work history on the asset panel; back-fill from OpenGov asset fields and locations; OpenGov activities table.
7. **v195 GIS symbols by default and rotation**; popups from AGOL popup definitions.
8. **v196 Notifications** (new table `notifications`, needs approval): bell, unread, Realtime; sources: messages, requests, packages, mentions.
9. **v197 Document collections** (new table `collections`, needs approval).
10. **v198 Invoices from email**: ingest rule + extraction + match + routing.
11. **Sign-in screen** and **CYVL 3D** once the design is agreed and the data is in hand.

## Open by area (task numbers)
**App-wide**: #1016 names link to records (partly done); #1023 one form engine; #1029 help and first sign-in tour; #889 tab-by-tab review; #1003 edit notes after saving; #1006 open a record in its own tab; #1004 AI restyle; #1024 one export/print menu; #1026 history panel on every record; #1038 accessibility.
**Budget and invoices**: #1011 Budget tab (lines in); #895; #921 PO/invoice approval; #1047 retainage; #1048 grant reimbursement; #1049 fiscal-year rollover; #1056 vendor profiles and COIs; #1323 monthly reload; #1260 invoice emails; #1261 Munis exports; #1284 FY2027 budgets (done by db/002).
**Calendar**: #114, #756, #864, #975 (link built), #1019 Gantt, #1327 two-way calendar, #1305 minutes on a meeting.
**Dashboards and reports**: #16, #17, #866, #868.
**Directory, roles, data**: #112, #839, #840, #841, #842, #890, #971, #976, #1000, #1293, #1297 vendors as employees, #1298 Munis vendor numbers, #1299 Supplier/Service groups, #1300 job descriptions, #1326.
**Documents and intake**: #1015 Knowledge Base; #995 Drive drop folder (working: 2,692 documents came through the Filer); #1053 version history; #1054 retention; collections (new).
**Field and iPad**: #1058 Assets; #1123 fleet; #1271 condition/risk; #1344 offline cold start; #1345 photo per repeat item; #1347 photos and pin on requests.
**Home and notifications**: #64, #849, #1014, #1279 PWF weather, #1324 @mentions, #1325 Realtime, #1346 reminder emails, #1306 chat decisions, #1320 Gmail path.
**Ingest**: #122, #787, #843, #892, #1242 (guards in db/006; rules wait on Sam), #1069, #795 demo, #1066 event-driven ingest.
**Map and GIS**: #887, #888, #1022, #1050, #1062, #1109 LiDAR, #1127 vector basemaps, #1319 Neptune, #1262 GIS integration; symbols, rotation, popups, work-to-asset links (new).
**Pavement**: #990 (db/001 in), #997, #998, #1060, #1061, #1064.
**Platform**: #1037 two-step (nudge live), #1040, #1042 (db/007 in), #115, #767 ID prefix, #883 IT onboarding, #896 Pages check, #933 Pro notice, #1020, #1030, #1035, #1059 Admin tab, #1067 lifecycle and first OpenGov push, #1255 advisor warnings, #1259 hosting, #1341 database-level two-step.
**Work**: #1043 (db/009 in), #1044 (db/009 in), #1057 (db/010 in), #1318 (db/003 in), #1272 status lifecycle; work packages (db/011 in).

## Rules that apply to every build
- Query Project #8 before building; build against existing tasks; add a task only when nothing covers the work.
- Never write to OpenGov without an approved change list. Never put a secret in the app. List deletions and wait for a yes.
- New tables need Sam's approval; tables are read through views and written through functions; structural changes are SQL files in `db/`.
- Every build: one file, tested headless on desktop and phone with no console errors, staged at `test/` first, number claimed in the database when it goes live, GitHub checked before delivery.
