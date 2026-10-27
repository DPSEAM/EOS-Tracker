# EOS Changelog

Newest first. Each entry is one build of `index.html`. "Needs db/00x" means a SQL file in `db/` has to be run once in Supabase before that feature works (the app explains this on screen until then).
The same list is stored in the database (`eos_claim_build` log) and feeds the "What's new" panel in the app. Project #8 "EOS System Development" holds the matching tasks; see `PLAN.md`.

Branches: `main` = live site (currently v172). `test` = staging (v186 and later).

## v186 · 2026-10-26 · Home and Work extras
- My favorites: ☆ star on tasks, work orders, projects, people and documents, plus a My favorites card on Home. Needs db/008.
- Needs attention card on Home: overdue, waiting on another task, no change in 30+ days, in progress with no one assigned or no due date. Mine or Everyone (level 4+).
- Task dependencies ("Depends on", no loops) and flag chips on the task page. Needs db/009.
- Task templates and repeating tasks (Templates button on Tasks, + New menu; level 4+). Needs db/009.
- Requests tab: any EOS user sends a request; level 4+ accept (creates a task), decline with a reason, or mark done. Needs db/010.
- Project page: sortable task table with labor, include work-order tasks, show completed, column checkboxes.
- Portfolio dialog on Projects: health (red/amber/green) and Capital plan by fiscal year, with Excel/CSV export. Portfolio health card on Home.
- Home cards: ingest card for level 4+, counts in record-list titles, View all on the status card.

## v185 · 2026-10-26 · Field and iPad
- Photo field on field forms (camera or library), saved as documents and linked to the form and task.
- Forms saved on the device when offline or when sending fails, sent automatically when back online ("saved forms waiting" pill).
- Install-to-home-screen icon and an Install row in the account menu.
- 16 px fields on touch screens and phones (no iOS zoom).
- New "Paving inspection" form (course inspected, weather, temperatures, thickness, result, photos, punch list).

## v184 · 2026-10-26 · Platform and security
- Idle sign-out (8 h for levels 1-4, 2 h for levels 5-6) and "sign out of all devices".
- Authenticator-app two-step sign-in with a weekly nudge for levels 5-6 (enforced on screen; database enforcement is a follow-up).
- Page error log and backup check in System Health. Needs db/007.
- Standing smoke test (`test/eos_smoke.js` in the Project docs).

## v183 · 2026-10-25 · GIS
- 360 street view arrows redrawn as large chevrons.
- GIS search finds assets by ASSET_ID, parcels and documents with a location.
- Near me button, New work order at a map point, Check saved maps tool.

## v182 · 2026-10-25 · Ingest guards (app side)
- "Unverified address" chip on the person page and a Data quality line. Needs db/006.

## v181 · 2026-10-25 · Calendar
- Meeting and department filters, Recurring meetings view with Add several, private calendar link. Needs db/005 and the eos-ics function.

## v180 · 2026-10-25 · Search and departments
- Search language everywhere (OR, "quoted phrases", -exclude, highlight); search covers organizations, commitments and invoices.
- Department column and filter on Tasks, Work orders, Projects, Commitments, Documents.

## v179 · 2026-10-25
- Directory org chart built from roles; Data quality card in System Health.

## v178 · 2026-10-25 · Messages
- Messages tab: direct messages and named groups, members only, unread counts, search, edit for 15 minutes, Discuss on a task or work order. No email. Needs db/004.

## v177 · 2026-10-25
- "Last modified by" on tasks and work orders (lists, record pages, exports). Needs db/003.

## v176 · 2026-10-25 · Budget
- Budget lines tab (FY2027 by fund, organization and object) and invoice Pipeline board. Needs db/002.

## v175 · 2026-10-25 · Pavement
- Pavement Season tab (board by stage, annual paving list with export). Work order status moves paving sections forward (needs db/001). Reclamation checklist suggestion; documents near a section.

## v174 · 2026-10-25 · Home and Work
- Labor grouping lists every assignee; Done button on Work rows and Board cards; Mine/Everyone switch on Home and Calendar; I owe / Owed to me tabs; What's new panel; + New menu and N shortcut; names link to the Directory.

## v173 · 2026-10-25
- Hide inactive applies on the Employees tab only; header search icon removed (Ctrl/Cmd+K and Home search kept).

## v172 · 2026-10-25 (this is what `main` has)
- Directory Status shown for employees only; budget load prepared; chat decisions recorded.

## v171 and earlier · 2026-10-20 to 2026-10-23
- v171 Done button for everyone with EOS access; directory Status and Notes.
- v170 Employee # wording; Hide inactive; Logins fix.
- v169 One place for roles and levels (System Health > Roles).
- v168 Accounts manager (last sign-in, resets, activity timeline).
- v167 Search-first Home with Ask AI, Knowledge Base tab, gadget dashboards, notepad, Run ingest now.
- v166 ISO 55001 asset hierarchy. v165 Assets read live from ArcGIS. v164 Assets tab.
- v163 Bulk upload (folders and zips). v162 Home fixes. v161 One header on every tab. v160 Pavement as a dashboard; Documents map.
- v159 GIS tab. v158 Menu and Home fixes. v157 Profile photos and backgrounds. v156 One search and Filters panel across Tasks, Work orders and Projects.
