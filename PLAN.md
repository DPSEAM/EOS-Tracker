# EOS Plan

What is coming, in order, then the backlog by area. When a build ships, move its lines into `CHANGELOG.md` under the new version. Edit freely; this file is the plan.

## Next builds, in order

1. **Ask AI hands you the file** — ask for a document and the chat opens it, previews it and can quote from it; answers carry document, task and person cards that open the record.
2. **Saved AI conversations** — conversations saved per person with titles, a history list and search, like Claude and ChatGPT.
3. **Roles and permissions manager** — one place to see and change what each role can see and do; role templates on top of the EOS levels.
4. **Budget chart and forecast** — spending by date against budget with a projection to June 30; division cards; drill down from budget line to purchase orders, invoices and work.
5. **Work tied to assets** — link tasks, work orders and requests to GIS assets; work history on the asset; back-fill from existing work; OpenGov activities.
6. **GIS symbols by default, rotation, popups** — every layer carries a saved symbol set so a new sign-in sees a finished map; symbol rotation by field; popups from ArcGIS Online.
7. **Notifications** — in-app bell for messages, requests, packages and mentions; Realtime delivery; optional email digests.
8. **Document collections** — group documents into nested collections, shareable by level, with a collections view on records.
9. **Invoices from email** — invoice emails and PDFs to the EOS mailbox become invoice rows, matched to purchase orders and routed for sign-off.
10. **Sign-in screen** — City imagery, a status line, one-tap sign-in on a trusted device, Request access.
11. **CYVL LiDAR and 3D** — street-level point cloud from the CYVL drive in a 3D view; plan-to-GIS extraction (after CYVL's notes and the point cloud format are in hand).

Design notes for these are in `docs/DESIGN.md`.

## Waiting on Sam

- Go on v189 (staging at /test/; includes v188).
- CYVL: their plan-to-GIS notes, and the point cloud format and size.
- A sharper Home background (≥ 3840×2160); which basemaps look blurry and at what zoom.
- Rotate the Anthropic API key before Oct 31.
- Tracy: FY2026 month-end Munis YTD reports for the budget history chart.
- Decisions in docs/DESIGN.md: permissions model, who edits the Directory now, the new tables (ai_conversations, notifications, collections, activities), popup source, trusted-device sign-in.

## Backlog by area

### App-wide look & consolidation (11)

- Built-in help per tab and first sign-in tour *(In Progress)* — Roadmap R9.
- Names and key data link to their Directory or record *(In Progress)* — Eric #958 10/16: full names, hyperlinked.
- One form engine for edit, Pavement and field forms *(In Progress)* — v153 (2026-10-20) — field-form part built: • New table form_records (one row per submitted form, like OpenGov task child forms) + view v_form_records (task visibility rules) + eos_submit_form (task + form in one save) + eos_set_form_config
- Design and Build Voicemail Audio Player in EOS *(Planned)*
- Edit and correct notes after saving *(Planned)* — Eric #958 10/14: fix typos in notes; changes go to edit history.
- EOS Tab-by-Tab Review Update *(Planned, high)*
- Open any record in its own browser tab; deep links *(Planned)* — Eric #958 10/14 plus roadmap R1.
- Accessibility to WCAG 2.1 AA *(Projected)* — Roadmap R19. Confirm the City's ADA Title II compliance date.
- AI interface generator: restyle EOS from a prompt or image *(Projected)* — Eric #958 10/14, with the motor pool and Lisa's dashboard examples attached to #958.
- History panel on every record from record_changes *(Projected)* — Roadmap R4.
- One export and print menu on every list and record *(Projected)* — Roadmap R52 (absorbs R7).

### Work (tasks, work orders, projects) (6)

- Record who last changed a record (Modified by) *(In Progress)* — Build v177 (partly): app shows Last modified by in task/work order lists, Modified cell on both pages, and exports. db/003_last_modified_by.sql (backup, columns, stamping trigger, backfill, view columns) is written and tested on a scratch d
- Recurring tasks and task templates *(In Progress)* — Roadmap R25.
- Requests tab: service requests from other departments *(In Progress)* — Roadmap R42.
- Task dependencies and aging flags *(In Progress)* — Roadmap R26.
- Decide: work order status lifecycle (groups, Waiting on Vendor) *(Projected)* — Requested by Sam Goodwin, 2026-10-22. Today tasks allow Planned, In Progress, Completed, Canceled, Projected; work orders allow Planned, In Progress, Completed, Canceled (database checks tasks_status_chk and work_orders_status_chk). Related
- Project record page: tabs, health strip, required fields *(Projected)* — From the EOS Architecture Plan, 2026-10-21.

### Home & notifications (9)

- EOS Chat Tab with AI Data Assistant *(In Progress, high)* — Requested by E. Barber (2026-10-01, EOS editing session) Add a Chat tab to EOS where staff can ask questions about any EOS data (tasks, work orders, meetings, people, documents) and get answers, limited to what the signed-in person is allow
- EOS Overdue Reminders & SOP Flags *(In Progress)* — Dewberry suggested EOS build-out: (1) automated poke/reminders for overdue tasks; (2) SOP violation flag alerts.
- Messenger: @mention threads on records, replies on Home *(In Progress)* — Build v178 (partly): Messages tab v1 — DMs, named groups, Discuss on tasks/work orders, unread, search, edit 15 min, delete. db/004_messages.sql waits on #1322. Left: @mentions in record threads and replies on Home.
- My Favorites: star records to get back to them fast *(In Progress)* — Eric #958 10/14.
- Weather: Precision Weather Forecasting bulletins on Home *(In Progress)* — Build v167 (partly done): weather gadget shows the NWS forecast plus the latest PWF bulletin from the EOS mailbox (v_weather_bulletins, settings.weather, ingest rule "Store Precision Weather Forecasting bulletins"). PWF has no public data f
- Decide: how chat and messaging between EOS users works *(Planned)*
- Messages: @mentions and replies on Home *(Projected)*
- Messages: instant delivery and attachments *(Projected, low)*
- Reminder emails for overdue tasks, new requests and repeating tasks *(Projected, low)*

### Map & GIS (11)

- EOS 360 Viewer Arrow Fix *(In Progress)*
- EOS Premade GIS Map Update and Cleanup *(In Progress)* — Sam Goodwin requested cleanup and updating of premade saved GIS maps currently stored in EOS.
- GIS Integrations page in System Health *(In Progress)* — From the EOS Architecture Plan, 2026-10-21.
- Automated plan digitization: upload a plan, get a GIS file out *(Planned)* — Requested by Sam Goodwin. Came up again with the Dane Street Beach irrigation layout map (merged from #1117).
- 3D GIS and augmented reality in EOS *(Projected)* — Roadmap R55. Phases: (1) 3D view on the Map tab: City scene layers, buildings, terrain, CYVL LiDAR point clouds (#1063) and underground utilities shown at depth. (2) AR on iPad: point the camera at the street and see utilities and assets ov
- Correct GIS records from LiDAR and 3D scans *(Projected)* — Depends on #1063 (CYVL LiDAR scene layers) and #1068 (3D GIS and AR in EOS). Scan data must be in MA State Plane Mainland, NAD83, US feet (EPSG 2249). GIS loads server-side. No writes to OpenGov without an approved change list.
- Fire Department live map with truck AVL and calls *(Projected)* — Roadmap idea 9/26.
- Map: measure, sketch, buffer select and abutter list *(Projected)* — Roadmap R34; feeds abutter notice letters.
- Neptune meter live reads (API) *(Projected)*
- One map engine for Map, Pavement and Documents *(Projected)* — Partly done — v160 (#1131): Documents now uses the same basemap gallery as the GIS tab and a full-page map like it. Still separate Leaflet setups for GIS, Pavement and Documents; Pavement is now a dashboard (#1130).
- Vector street basemaps that stay sharp at any zoom *(Projected)* — MassGIS publishes no vector basemap. Options: Esri vector basemaps (need an ArcGIS sign-in or API key and a vector renderer such as MapLibre) or a free vector style. Aerials, Nearmap and City mosaics stay picture tiles.

### Field & iPad (10)

- Assets tab: asset register mirroring OpenGov classes *(In Progress)* — Sam asked 2026-10-20 to build an asset inventory into EOS. Roadmap R43: an asset register mirroring the OpenGov asset classes, tied to the field forms (form_records) and the map.
- Asset condition, risk and priority: registry attributes *(Projected, high)* — Requested by Sam Goodwin, 2026-10-22. Builds on #01058 (Assets tab), #01262 (GIS Integrations) and field forms (form_records).
- Asset history on the map pop-up (forms + tasks on this asset) *(Projected)*
- Crew review of drafted field forms *(Projected)*
- Fleet Management System in EOS *(Projected)* — Sam asked 2026-10-20 to look into creating a fleet management system. Vehicles and equipment would be assets in the asset inventory (#01058), so the two should be designed together.
- Follow-up actions create follow-up tasks *(Projected)*
- Forms per role (who can fill which forms) *(Projected)*
- Offline app load for field devices (service worker) *(Projected, low)*
- Photo field inside repeat items (punch list photos) *(Projected, low)*
- Requests: photos and location pin on a request *(Projected, low)*

### Documents & intake (7)

- Knowledge Base for how the City runs and its history *(In Progress)* — Eric #958 10/16: legacy knowledge, not assignments.
- Add AI-generated summaries to EOS document records *(Planned)*
- Add public records obligations to EOS knowledgebase *(Planned)*
- Drive 'EOS Inbox' drop folder for document intake *(Planned, high)* — Roadmap R53: files, folders and zips; subfolder named for a work order links its files; batches for large plan sets.
- Bring the Access database into the document library *(Projected)* — Split out of #1025 when in-app bulk upload was built in v163.
- Document version history *(Projected)* — Roadmap R37.
- Records retention categories and public records helper *(Projected)* — Roadmap R38.

### Budget & invoices (11)

- Budget tab: Budget, Commitments, Purchase Orders, Invoices *(In Progress, high)* — Build v176 (partly): Budget lines tab built and tested; data load waits on db/002_budget_lines.sql (#1322).
- Add Claude API credits — balance at $2.35 *(Planned, high)*
- Budget imports: Munis budget lines, POs and payments *(Planned, high)* — From the EOS Architecture Plan, 2026-10-21.
- Design PO and Invoice Approval Workflow in EOS *(Planned, important)* — Invoices need to be submitted through EOS with a full sign-off process built in. Contracts currently sprawl across departments with no centralized approval process.
- EOS - Building Analysis for Budgeting Tab *(Planned, high)* — Determine what building-related fields should be included and how they should be structured in the budgeting view.
- Load FY2027 DPS operating budgets into EOS *(Planned)* — Requested by Tracy Reardon (Business Manager, DPS Administration) via email on 2026-10-22. Files already in Drive: Ytd_Budget_Report_20261022143049888.xlsx and Ytd_Budget_Report_20261022143111707.xlsx. General Fund: orgs 14001-14937 expense
- Budget lines: monthly reload and link to commitments *(Projected)*
- Fiscal-year rollover of open POs and commitments *(Projected)* — Roadmap R32.
- Grant reimbursement tracking *(Projected)* — Roadmap R31.
- Retainage tracking on pay requisitions *(Projected)* — Roadmap R30.
- Vendor and consultant profiles with contracts and COIs *(Projected)* — Roadmap R40.

### Calendar & meetings (7)

- Add Google Calendar Integration Option for EOS Users *(Planned)*
- Build Recurring EOS Calendar Meetings with Attendees *(Planned)* — Requested by Sam Goodwin, 2026-10-01 Source: email subject "Updates" (id: 1a0f948600945c90) Set up recurring calendar meetings in EOS including attendee lists and meeting structure/agenda format.
- Calendar: meeting minutes and files, processed at next ingest *(Planned)*
- DPS Recurring Meeting Schedule Entry *(Planned)* — The DPS recurring meeting schedule needs to be entered into the meetings table in the database so it is accessible and trackable within EOS alongside related projects and tasks.
- EOS Real-Time Meeting Notes *(Planned)* — notes in real time and keep up with the flow of conversation.
- Calendar: connect Google or Outlook calendar per person (two-way) *(Projected, low)*
- Gantt charts for projects, work orders and the Calendar *(Projected)* — Eric #958 10/16 plus roadmap R27.

### Dashboards & reports (5)

- Add Catch Basin Cleanouts to EOS Dashboards *(Planned)* — Requested by Sam Goodwin, 2026-10-01 Source: email subject "Updates" (id: 1a0f948600945c90) Add catch basin cleanout tracking to the EOS dashboard suite for stormwater management visibility.
- Add Hydrant Flushing Dashboard to EOS with AGOL Build-Out *(Planned)* — Requested by Sam Goodwin, 2026-10-01 Source: email subject "Updates" (id: 1a0f948600945c90) Build a hydrant flushing dashboard within EOS, integrated with ArcGIS Online (AGOL) for spatial visualization of flushing activities.
- EOS Reporting System Demonstration - Nov 9, 2026 *(Planned)* — Meeting: Nov 9, 2026, 9:30-11am, City Hall. Organizer: Eric Barber. Agenda: EOS Reporting System demonstration.
- Monday Follow-Up Report for Tracy Reardon *(Planned, high)* — Configure EOS system to send Tracy Reardon a filtered Monday 8:15am report containing only her assigned follow-up items (not full tracker). Sam Goodwin to implement configuration.
- Monday Water Division Work Plan *(Planned, high)* — Sam Goodwin to configure EOS to generate weekly water division work plan every Monday (available staff, locations, scope) and deliver by noon via HTML export to Tracy Reardon, J. Rushton, E. Chandler.

### Directory, roles & data cleanup (18)

- Profile photo upload error for Jenn Rushton (row-level security) *(In Progress)*
- Add City-created OpenGov security roles to EOS roles *(Planned, low)*
- Audit and Update Org/WO Aliases That Are Out of Date in EOS *(Planned)*
- Decide: roles for the 7 role-less accounts and Jason Foster's level *(Planned, high)*
- Directory data check: vendors as employees, school emails *(Planned)*
- EOS Task & Work Order Assignment Cleanup *(Planned)* — Also improve work order (project) names as part of the same pass.
- EOS Views and Visibility Levels Enhancement *(Planned, high)*
- Level 3 Visibility for Work Order Programs *(Planned)* — Work order programs to enable (all prefixed w-): w-0016, w-0021, w-0010, w-0004, w-0002, w-0006, w-0023, w-0017, w-0014, w-0024, w-0307, w-0291, w-0310, w-0309, w-0022, w-0308, w-0289, w-0306, w-0027, w-0003, w-0011, w-0302, w-0303, w-0315,
- Level 4 User Permission — Add Users in EOS *(Planned)*
- Non-City Staff Employee Designation Fix *(Planned)* — Partly done 2026-10-20: applied Eric's 9/28 corrections to the 6 non-OpenGov records — B. Griffin, E. Hall, Eric Holbrook, T. Cooper (no City affiliation, type other); Chris Granese and E. Prescott (E.J. Prescott, vendor; new organization);
- School Staff Person Record Cleanup *(Planned)* — Requested by E. Barber (2026-09-28 email) Approximately 24 Beverly Schools Buildings & Grounds staff are in the EOS people directory. E. Barber indicated these should be reviewed — they are school district employees, not City of Beverly DPS
- Work Order 0027 & 0019 Merge *(Planned)* — Per E. Barber email 2026-09-28: "0027 and 0019 are the same program and need to be combined." Determine which program number to retain and migrate associated records. Coordinate with OpenGov admin.
- Force password change at first sign-in *(Projected)* — Follow-up from the Accounts manager build (v168, #1289).
- Invite new EOS users by email *(Projected)* — Follow-up from the Accounts manager build (v168, #1289).
- Munis vendor numbers on vendors (match POs to vendors) *(Projected)*
- Roles: job descriptions from John Coffey (himself, J Michael, staff) *(Projected)*
- Run data quality checks in the nightly check and trend them *(Projected)*
- Vendor groups: Supplier and Service (alongside Consultant) *(Projected, low)*

### Ingest (email & notepad) (11)

- Employee Auto-Add Ingest Rule *(In Progress, high)* — Rule "Apply directory corrections from staff" added 2026-10-20 so correction emails update the Directory instead of becoming tasks. The database guard that stops the ingest auto-adding City staff is drafted but not applied — waiting on Sam.
- EOS Email Structural-Change Safeguard *(In Progress, high)* — Requested by Sam Goodwin (self-assigned) EOS ingest should not allow email-triggered structural changes to the app; build in a safeguard to block this.
- EOS Ingest - Fix Email Domain Assumption for New People *(In Progress, low)* — Found 2026-10-20: 100 of 113 people imported from OpenGov Labor got an address built from their OpenGov user name + @beverlyma.gov; only 23 have ever appeared on an email. These guessed addresses are what Eric flagged on 9/28. Fix needs a d
- EOS Note Event Dates *(In Progress)* — Notes and dates recorded on tasks in EOS are currently storing the email ingest timestamp rather than the actual date the information relates to. Sam observed this as incorrect and wants dates on notes and tasks to reflect the true date of
- Ingest: one task per listed line, list statuses, program links *(In Progress, high)* — Eric Barber's "P-0036 Update" thread (Oct 19-20, 2026, 4 emails): the ingest created the 15 work orders but invented one summary task per work order instead of Eric's 105 lines, applied none of the complete / IP031424 statuses, and never li
- Run ingest now: button to force an email ingest *(In Progress)* — Roadmap R56. Where: System Health ingest section (R47), plus a small refresh action next to "Last ingest" in the account menu. Shows a running state, then the result (emails read, tasks created or updated) and a link to the run. Guard again
- EOS Ingest Demo for Hazen & Sawyer *(Planned)* — Target: within ~2 weeks of Sept 15, 2026.
- Fix invoice ingest: invoice emails not creating invoices *(Planned, high)* — From the EOS Architecture Plan, 2026-10-21.
- Research and implement Q-Alert integration with EOS for public service requests *(Planned)*
- Event-driven ingest replacing the hourly task *(Projected)* — Roadmap Later.
- Gmail inbox in EOS with important/awaiting flags *(Projected)*

### Pavement (7)

- Pavement: work order status syncs to street sections *(In Progress)* — Roadmap P1.
- CYVL LiDAR scene layers and December scan prep *(Projected)* — Roadmap Later.
- Pavement layers read-only on the Map tab *(Projected)* — Roadmap P6.
- Pavement: abutter notice letters from street addresses *(Projected)* — Roadmap idea 10/13.
- Pavement: budget scenarios projecting network PCI *(Projected)* — Roadmap P5.
- Pavement: paving list optimizer by PCI gain per dollar *(Projected)* — Roadmap idea 10/13.
- Water and utility layers feed Pavement utility items *(Projected)* — Roadmap Later.

### Platform, security & hosting (18)

- Backup check and restore test in System Health *(In Progress)* — Build v184: System Health > Backup check (needs db/007). Restore test not done.
- Multi-factor sign-in for level 5-6 *(In Progress)* — Build v184: authenticator-app (TOTP) sign-in, set up in the account menu; code asked after the password; reminder for levels 5-6. Database enforcement not on yet.
- Record page errors for System Health *(In Progress)* — Build v184 done; starts recording when Sam runs db/007_page_errors_backup_check.sql (task #1322).
- Decide: EOS hosting — Supabase cloud or City server *(Planned, high)* — From the EOS Architecture Plan, 2026-10-21.
- EOS API key renewal *(Planned, high)*
- EOS IT Official Onboarding with Garrett Whitney *(Planned, high)* — Sam Goodwin flagged need to get IT officially involved in EOS. Garrett Whitney (IT) is the contact.
- EOS Tracker GitHub Pages Build Cancellation *(Planned)* — Commit: 6c15035; Branch: main; Duration: 30m 9s; Finished: 2026-10-05 21:18:23 UTC
- EOS–OpenGov Work Order Schema Alignment *(Planned)* — Includes planning the export path from EOS to OpenGov.
- Fiscal Year Record ID Prefix *(Planned)* — Per Eric Barber 2026-09-15: 4-digit IDs will be insufficient long-term. Every record ID needs a fiscal year prefix. FY rules: July 1–June 30. Current fiscal year is FY27. [EOS ingest]
- Review Supabase Pro upgrade notification *(Planned, low)* — EOS currently on Supabase Free tier. Upgrade link: https://supabase.com/dashboard/org/opoococpalykkhzwfxcf/billing
- Admin screens for settings, rules and data dictionary *(Projected)* — Roadmap R15.
- Admin tab, if System Health gets crowded *(Projected)* — Roadmap R44.
- Draft, Reviewed, Pushed lifecycle and first OpenGov push *(Projected)* — Roadmap Later. Only with an approved change list.
- Performance: paging, load tabs on first visit, under 2 s *(Projected)* — Roadmap R10.
- Require two-step sign-in in the database for levels 5-6 *(Projected)* — Follow-up to #1037 (v184 added the sign-in step but does not enforce it in the database).
- Run pending DB changes (db/*.sql) *(Projected, high)*
- Security advisor clean-up (search_path, passwords) *(Projected)* — Found while closing #1247 on 2026-10-21.
- System Health in three sections: Ingest, Checks, Admin *(Projected)* — Roadmap R47 (absorbs R41).

### General (5)

- EOS: System Configuration Ideas/Notes *(In Progress)*
- Rotate Anthropic API key EOS (expires Oct 31 2026) *(In Progress, high)* — URGENT: 6 days to expiry (2026-10-31). Key ID: apikey_01AkudVPdRDAi1iwMEXUGTFL. Ingest agent flagged on 2026-10-25 run.
- City Council Project Report for Todd Rotondo *(Planned)* — Sam noted this is part of EOS development.
- EOS UB Data Review and Reassessment Assist *(Planned)* — Glennys Gil requested Sam's help with EOS updates and re-assessments related to Utility Billing data (UB UPDATE 10.14 email).
- EOS Weekly Meeting Notes Upload — 10/24 *(Planned)* — Requested by Sam Goodwin, 2026-10-01 Source: email subject "Updates" (id: 1a0f948600945c90) Sam needs to upload the EOS weekly meeting notes from the 10/24 meeting into EOS.

### Dropped

- GitHub EOS-Deploy Token Renewal
- Retire Dashboards; pin dashboards to Home or records
- Automate digitizing engineering plans and drawings to GIS
- Organizations: Active/Inactive status column
