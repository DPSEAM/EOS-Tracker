# EOS Changelog

Every build of `index.html`, newest first. The version lives in the file (`const BUILD = "vNNN · date"`); the GitHub Action `version.yml` stamps a new number on every commit of `index.html` that does not already carry one, and adds the commit message here. Add detail to an entry by editing this file. `PLAN.md` holds what is coming.

Staging builds (in `test/index.html`) are listed with *staging* until they go live.

## v189 · staging · Work packages
- Packages tab (after Requests): For me / I sent / Closed / All, search, progress on every card.
- Package page as a mini page: note, items grouped by kind with Done ticks, Accept, Send back with a note, Mark done, Cancel, Send again, Discuss (opens a Messages group with sender and receiver), Print (one-page field sheet with tick boxes and signature lines).
- + New › Work package (and "Work package with this task/work order/project/person" when one is open); Add to package… in the selection bar on Tasks, Work orders and Projects.
- New-package sheet: title, give to (EOS users), due date, note, items found by number, title or name across tasks, work orders, projects, people and documents, map points by coordinates or the current map centre.
- Work packages gadget on Home (packages for you and ones you sent, with progress); in the default layout for new users. Badge on the Packages tab counts open packages for you.
- Needs db/011 (run 2026-10-27). Asset items wait for the work-to-asset links build.
- What's new reads this file and PLAN.md from the site: Released = this changelog, Coming = the plan.

## v188 · staging · Mini pages, What's new, Directory
- Mini pages (task, work order, project windows) drag by a slim grip strip across the top, not by the whole header; text in the header can be selected again.
- No blur behind mini pages, Add update, edit dialogs or the notepad: the page behind stays readable.
- What's new is linked from the Home greeting line, shows every build in the log (not just the last eight) and a Coming tab with the planned builds (needs db/012 for the list).
- Person page: Remove from directory (marks inactive, nothing deleted) and Restore, for anyone who can edit the Directory.

## v187 · 2026-10-27 · Slim header, floating GIS, Home touches
- Header is one 48 px row; it slides away while scrolling down and returns on the first scroll up.
- GIS has no bar: the seal (menu), + New and the account float over a full-screen map; the Basemap button is back on screen on iPad.
- Full-height layouts use the visible screen height (iPad Safari counted the hidden toolbar); Home cards no longer clipped.
- Two-step sign-in reminder floats at the bottom of the screen instead of inside the header.
- Home: greeting line adds due today and meetings; first visit of the day counts the numbers up and pulses the overdue card; aerial drifts and is tinted by time of day; Done draws a check mark. All motion respects reduced motion.

## v186 · 2026-10-26 · Home and Work extras
- My favorites: ☆ star on tasks, work orders, projects, people and documents, plus a My favorites card on Home. Needs db/008.
- Needs attention card on Home: overdue, waiting on another task, no change in 30+ days, in progress with no one assigned or no due date. Mine or Everyone (level 4+).
- Task dependencies ("Depends on", no loops) and flag chips on the task page. Needs db/009.
- Task templates and repeating tasks (Templates button on Tasks, + New menu; level 4+). Needs db/009.
- Requests tab: any EOS user sends a request; level 4+ accept (creates a task), decline with a reason, or mark done. Needs db/010.
- Project page: sortable task table with labor, include work-order tasks, show completed, column checkboxes.
- Portfolio dialog on Projects: health (red/amber/green) and Capital plan by fiscal year, with Excel/CSV export. Portfolio health card on Home.
- Home cards: ingest card for level 4+, counts in record-list titles, View all on the status card.
- Home cards: view all, click counts, scroll; ingest card 4+
- Project portfolio health and Capital Improvement Plan view
- Projects: sortable task list, labor, visibility checkboxes

## v185 · 2026-10-26 · Field and iPad
- Photo field on field forms (camera or library), saved as documents and linked to the form and task.
- Forms saved on the device when offline or when sending fails, sent automatically when back online ("saved forms waiting" pill).
- Install-to-home-screen icon and an Install row in the account menu.
- 16 px fields on touch screens and phones (no iOS zoom).
- New "Paving inspection" form (course inspected, weather, temperatures, thickness, result, photos, punch list).
- Inspector iPad form: binder, top course, photos, punch list
- Installable app icon for iPad and phone
- Offline field forms that send when back online
- Phone mode for small screens
- Photo capture in field forms

## v184 · 2026-10-26 · Platform and security
- Idle sign-out (8 h for levels 1-4, 2 h for levels 5-6) and "sign out of all devices".
- Authenticator-app two-step sign-in with a weekly nudge for levels 5-6 (enforced on screen; database enforcement is a follow-up).
- Page error log and backup check in System Health. Needs db/007.
- Standing smoke test (`test/eos_smoke.js` in the Project docs).
- EOS Data API Grants for New Tables
- Session timeout and sign out everywhere
- Standing smoke test before every build

## v183 · 2026-10-25 · GIS search, Near me, work order at a point
- 360 street view arrows redrawn as large chevrons.
- GIS search finds assets by ASSET_ID, parcels and documents with a location.
- Near me button, New work order at a map point, Check saved maps tool.
- 'Near me': center on device location, list nearby assets
- GIS search beyond addresses (assets, parcels, records)
- Map: create a work order from a map click

## v182 · 2026-10-25 · Ingest guards
- "Unverified address" chip on the person page and a Data quality line. Needs db/006.

## v181 · 2026-10-25 · Calendar
- Meeting and department filters, Recurring meetings view with Add several, private calendar link. Needs db/005 and the eos-ics function.
- EOS Department Sort & Filter
- EOS Meeting Filter

## v180 · 2026-10-25 · Search language and departments
- Search language everywhere (OR, "quoted phrases", -exclude, highlight); search covers organizations, commitments and invoices.
- Department column and filter on Tasks, Work orders, Projects, Commitments, Documents.
- EOS Enhanced Search Filter Design
- EOS System-Wide Search

## v179 · 2026-10-25 · Org chart and Data quality
- Directory org chart built from roles; Data quality card in System Health.
- Data quality card in System Health
- Directory org chart from roles

## v178 · 2026-10-25 · Messages
- Messages tab: direct messages and named groups, members only, unread counts, search, edit for 15 minutes, Discuss on a task or work order. No email. Needs db/004.

## v177 · 2026-10-25 · Last modified by
- "Last modified by" on tasks and work orders (lists, record pages, exports). Needs db/003.

## v176 · 2026-10-25 · Budget lines and invoice Pipeline
- Budget lines tab (FY2027 by fund, organization and object) and invoice Pipeline board. Needs db/002.
- Invoice pipeline board with aging

## v175 · 2026-10-25 · Pavement Season
- Pavement Season tab (board by stage, annual paving list with export). Work order status moves paving sections forward (needs db/001). Reclamation checklist suggestion; documents near a section.
- Pavement: located documents show on street sections
- Pavement: paving tasks suggest reclamation checklist steps
- Pavement: season planning board and Nov 1 paving list

## v174 · 2026-10-25 · Home and Work
- Labor grouping lists every assignee; Done button on Work rows and Board cards; Mine/Everyone switch on Home and Calendar; I owe / Owed to me tabs; What's new panel; + New menu and N shortcut; names link to the Directory.
- 'What's new' panel after each build
- Add Column Headers to EOS Tasks List Page
- Add Row Highlight on Select in EOS List Views
- Bug: labor grouping misses Miles Bateman's tasks
- Done button on Work list rows
- Floating Save/Cancel bar that stays visible while editing
- Global + New menu and keyboard shortcut
- Home and Calendar default to 'only what applies to me'
- Home weather gadget loops with no location set
- Show what is owed to me separately from what I owe
- Status tabs across the top of the task list

## v173 · 2026-10-25 · Hide inactive on Employees, header search removed
- Hide inactive applies on the Employees tab only; header search icon removed (Ctrl/Cmd+K and Home search kept).
- People & Orgs Status and Notes
- Remove the search icon from the header

## v172 · 2026-10-25 · Directory status, budget load prepared
- Directory Status shown for employees only; budget load prepared; chat decisions recorded.

## v171 · 2026-10-23 · Done button for everyone
- Done button for everyone with EOS access; directory Status and Notes.
- Decide: let assignees mark their own tasks done
- Done button on tasks for everyone with EOS access

## v170 · 2026-10-23 · Directory wording, Hide inactive, Logins fix
- Employee # wording; Hide inactive; Logins fix.
- Directory: Employee # wording and Hide inactive toggle
- Fix: Logins 403 on the GIS tab (v168 sign-in function grant)

## v169 · 2026-10-22 · One place for roles and levels
- One place for roles and levels (System Health > Roles).
- One place for roles and levels (Roles manager only)

## v168 · 2026-10-22 · Accounts manager
- Accounts manager (last sign-in, resets, activity timeline).
- Create EOS User Accounts for Dewberry Staff (Bateman and Dwyer)
- Directory: Accounts manager (sign-in, activity, reset email)

## v167 · 2026-10-22 · Search-first Home, Ask AI, Knowledge Base, gadget dashboards
- Search-first Home with Ask AI, Knowledge Base tab, gadget dashboards, notepad, Run ingest now.
- Dashboard Generator: build EOS dashboards from gadgets
- EOS In-App Notepad for Field Updates
- Find: search within the open screen (like Ctrl+F)
- Fix Text Overflow in EOS Commitments Side Panel
- GIS and Assets combined; floating layer panel
- GIS: search Beverly addresses on the map
- Mini pages: drag to move, remember place and size
- Native EOS KPI tiles from database views
- Replace the Update email button with Add update (Notepad)
- Search-first Home: one box for Search and Ask AI
- Work: a status card for every status, lined up with Grid

## v166 · 2026-10-21 · ISO 55001 asset hierarchy
- ISO 55001 asset hierarchy.
- Fix Supabase security advisory: auth_users view exposes user data

## v165 · 2026-10-21 · Assets read live from ArcGIS
- Assets read live from ArcGIS.

## v164 · 2026-10-21 · Assets tab
- Assets tab.

## v163 · 2026-10-20 · Bulk upload
- Bulk upload (folders and zips).
- In-app bulk upload: files, folders and zips

## v162 · 2026-10-20 · Home fixes
- Home fixes.
- Fix date-only fields showing one day early
- Home timeline rail: day labels fit beside the date
- Show each task's project on Home task rows

## v161 · 2026-10-20 · One header on every tab
- One header on every tab.
- One header on every tab (no second page bar)

## v160 · 2026-10-20 · Pavement as a dashboard, Documents map
- Pavement as a dashboard; Documents map.
- Documents Tab Redesign: Map Page and List View
- Pavement Tab Becomes the First EOS Dashboard

## v159 · 2026-10-20 · GIS tab
- GIS tab.
- EOS Meter Replacement Program Dashboard
- GIS tab: full-page map, collapsible layer panel, tools on the map

## v158 · 2026-10-20 · Menu and Home fixes
- Menu and Home fixes.

## v157 · 2026-10-20 · Profile photos and backgrounds
- Profile photos and backgrounds.
- Profile icons on activity, history and the Directory
- Profile photo and background, set from the initials menu

## v156 · 2026-10-20 · One search and Filters across Work
- One search and Filters panel across Tasks, Work orders and Projects.
- One Search and Filters Panel for the Work Tab

## v155 · 2026-10-20 · App menu from the seal, one Home header
- App menu: City logo + EOS dropdown replaces the tab bar
- Home: Calendar timeline in a side rail; new cards; remove ticker
- Home: weather and date card (radar on Map, date opens Calendar)

## v154 · 2026-10-20 · One Work tab for tasks, work orders and projects
- Merge Tasks, Work Orders and Projects into one Work tab

## v153 · 2026-10-20 · One form engine: field forms and form_records

## v152 · 2026-10-20 · EOS access managed in the Directory
- Directory Shows EOS and OpenGov Users

## v151 · 2026-10-19 · Calendar Timeline
- Calendar Task Dates and Scrolling Timeline
- Decide what email instructions may do (e.g. create a project)
- Decide: retire Dashboards (R49) or move Pavement into it
- Decide: standard look, layout and accent for EOS
- Fix auth_users_exposed security vulnerability in EOS database
- Fix Ingest: Assign Due Dates Only When Explicitly Stated
- Repoint stale handbook pointers to the roadmap

## v150 · 2026-10-19 · Role on the account card
- One macOS look; account card with theme, accent, level

## v149 · 2026-10-18 · GitHub Pages deployment confirmed *(date approximate)*

## v148 · 2026-10-18 · Per-user looks, accents, light/dark/auto *(date approximate)*

## v144 · 2026-10-18 · Dashboard data bridge for EOS HTML dashboards *(date approximate)*

## v143 · 2026-10-17 · List kit: sortable column headers *(date approximate)*

## v142 · 2026-10-17 · Search everything (Ctrl/Cmd+K), highlights *(date approximate)*
- Per-User UI Customization Research

## v119 · 2026-10-16 · Dashboard data bridge *(date approximate)*
- Fix EOS Document Side Panel Display

## v115 · 2026-10-15 · Projects layer above work orders: programs, milestones, budget, funding *(date approximate)*
- EOS Projects and Programs Data Model

## v114 · 2026-10-14 · In-app record editing with edit history and undo *(date approximate)*
- EOS In-App Record Editing Workflow

## v82 · 2026-10-01 · Sealed-frame EOS data bridge for dashboards *(date approximate)*

## v56 · 2026-09-22 · Views readable only by signed-in users *(date approximate)*
- EOS Overview for Emerging Leaders
- Ward Councilor Capital Project Report

## v55 · 2026-09-21 · Tracker app at the September audit

## v57–v81, v83–v113, v116–v118, v120–v141, v145–v147 · September–October 2026
- Builds not individually recorded; the live file was replaced in place before the changelog existed.

## v1–v54 · September 2026 · First builds
- Email intake, the first tracker, the Supabase schema and the GitHub Pages site.
- Ingest Writes Schedule Dates from Daily Updates
- EOS Data Limit Timeout Fix (2026-09-14)
- EOS Database Platform Decision (2026-09-14)
- EOS Email Attachment Ingestion (2026-09-14)
- EOS Web Page with User Logins (2026-09-18)
- Hazen & Sawyer Weekly Meeting Entry (2026-09-18)
- Monday Supervisors Meeting Calendar Entry (2026-09-18)
- Task Gmail Update Button (2026-09-18)
