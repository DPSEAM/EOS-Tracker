# EOS Build Plan (Project #8 "EOS System Development")

Snapshot of the open tasks on Oct 26, 2026, after v186. The live plan is in EOS itself (Project #8, one work order per area); this file is a readable copy for Claude conversations and for people. Numbers are EOS task numbers. In Progress = built or being built; Planned = scheduled; Projected = idea or later.

## Waiting on Sam (nothing happens until he answers)
- Run the SQL files db/001 to db/010 in order (#1322).
- Rotate the Anthropic API key, expires Oct 31, 2026 (#1317; Sam generates it, it is added as a server secret).
- Data change lists for approval: #841, #842, #839, #840, #112, #976, #1000, #971.
- Ingest rules and two data changes (mark 88 guessed OpenGov emails unverified; re-date 359 notes): #843, #892, #1242, #787, #122.
- Monday report drafts, five questions: #16, #17.
- Not in the approval: #1272, #767, #115, #1067, #1319 (Neptune), #1320 (Gmail on hold), #977, #883, #795, #933, #756.
- Nov 1 paving deadline.

## App-wide look and consolidation
In Progress: #1016 names link to records; #1023 one form engine; #1029 help and first sign-in tour.
Planned: #889 tab-by-tab review; #977 voicemail player; #1003 edit notes after saving; #1006 open a record in its own tab, deep links.
Projected: #1004 AI interface restyle; #1024 one export and print menu; #1026 history panel on every record; #1038 accessibility (WCAG 2.1 AA).

## Budget and invoices
In Progress: #1011 Budget tab (lines and pipeline built, needs db/002).
Planned: #895 building analysis for budgeting; #921 PO and invoice approval workflow.
Projected: #1047 retainage; #1048 grant reimbursement; #1049 fiscal-year rollover; #1056 vendor profiles and COIs; #1323 monthly budget reload and link to commitments.

## Calendar and meetings
Planned: #114 recurring meeting entry; #756 real-time meeting notes; #864 recurring meetings with attendees; #975 Google Calendar option (private link built, needs db/005).
Projected: #1019 Gantt charts; #1327 two-way calendar connection.

## Dashboards and reports
Planned: #16 Monday Water Division work plan; #17 Monday follow-up report; #866 hydrant flushing dashboard; #868 catch basin cleanouts.

## Directory, roles and data cleanup
Planned: #112, #839, #840, #841, #842, #890, #971, #976, #1000 (data lists waiting on Sam).
Projected: #1326 data quality checks in the nightly check, trended.

## Documents and intake
In Progress: #1015 Knowledge Base.
Planned: #995 Drive "EOS Inbox" drop folder.
Projected: #1053 document version history; #1054 records retention helper.

## Field and iPad
In Progress: #1058 Assets tab.
Projected: #1123 fleet management; #1271 asset condition, risk and priority; #1344 offline app load (service worker); #1345 photo field inside repeat items; #1347 photos and location pin on requests.
Done in v185: photo field, offline forms, install icon, phone mode, Paving inspection form.

## Home and notifications
In Progress: #64 overdue and SOP flags (in-app done; reminder emails wait on #1320); #849 Chat tab with AI assistant; #1007 My favorites (needs db/008); #1014 Messenger; #1279 PWF weather bulletins.
Projected: #1324 Messages @mentions and replies on Home; #1325 instant delivery and attachments; #1346 reminder emails for overdue tasks, requests and repeating tasks.

## Ingest (email and notepad)
In Progress: #122, #787, #843, #892, #1242 (rules waiting on Sam; guards in db/006); #1069 Run ingest now.
Planned: #795 demo for Hazen & Sawyer.
Projected: #1066 event-driven ingest; #1320 Gmail inbox in EOS.

## Map and GIS
In Progress: #887 premade GIS map cleanup; #888 360 viewer arrows.
Projected: #1022 one map engine; #1050 measure, sketch, buffer; #1062 Fire Department live map; #1109 correct GIS from LiDAR; #1127 vector basemaps; #1319 Neptune meter reads.

## Pavement
In Progress: #990 work order status syncs to street sections (needs db/001).
Projected: #997 budget scenarios; #998 layers on the Map tab; #1060 paving list optimizer; #1061 abutter notice letters; #1064 utility layers feed Pavement.

## Platform, security and hosting
In Progress: #1037 two-step sign-in; #1040 page error log; #1042 backup check (the last two need db/007).
Planned: #115 OpenGov work order schema alignment; #767 fiscal-year record ID prefix; #883 IT onboarding; #896 GitHub Pages build cancellation (confirm green Actions run after upload); #933 Supabase Pro upgrade notice.
Projected: #1020 System Health sections; #1030 performance; #1035 admin screens; #1059 Admin tab; #1067 Draft/Reviewed/Pushed lifecycle and first OpenGov push; #1322 run pending SQL; #1341 database-level two-step sign-in.

## Work (tasks, work orders, projects)
In Progress: #1043 templates and repeating tasks (needs db/009); #1044 dependencies and aging flags (flags live, dependencies need db/009); #1057 Requests tab (needs db/010); #1318 Modified by (needs db/003).
Projected: #1272 decide the work order status lifecycle.

## Rules that apply to every build
- Query Project #8 before building; build against existing tasks; add a task only when nothing covers the work.
- Never write to OpenGov without an approved change list. Never put a secret in the app. List deletions and wait for a yes.
- New tables need Sam's approval; tables are read through views and written through functions; structural changes are SQL files in `db/`.
- Every build: one file `index.html`, tested headless on desktop and phone with no console errors, number claimed in the database, GitHub checked before delivery.
