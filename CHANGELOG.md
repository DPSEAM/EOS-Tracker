# What's new in EOS

Every build, newest first. A build is one update of the app.

## v199 · October 29, 2026 · Requests and Packages on Work
- Requests and Work packages are now bubbles on the Work page beside Tasks, Work Orders and Projects, each with its count of open items. Their own menu entries are gone; the Home cards and notifications still open them.

## v198 · October 29, 2026 · What's new, Coming tab
- The Coming tab of What's new now shows only the next builds in order. The longer list by area stays in the plan on GitHub.

## v197 · October 29, 2026 · Asset types
- **System Health › Asset layers is now Asset types.** The ArcGIS layers are registered there as before, and below them a new section holds the **asset types kept in EOS**: iPads, printers, radios, tools, vehicles, facility parts. Add one with a name, class, department, an ID prefix and its own list of attributes (text, number, date, yes/no or a choice list).
- A type is backed by one place only. If it is an ArcGIS layer, GIS stays the record and nothing is copied. If it is inventory, EOS is the record. The asset register stays inside GIS; there is one map.
- **Import from a spreadsheet** on the register: pick the type, pick the file, check the column mapping (columns are matched to fields and attributes for you; unmatched columns become new attributes or are ignored), and load. Rows whose Asset ID is already in EOS are updated, the rest are added; rows with no ID get the type's prefix and a number.
- **+ Asset** and ✎ Edit show the type's attributes as ordinary inputs, and an asset's page lists them.
- Run db/019 once in the Supabase SQL editor.

## v196 · October 29, 2026 · Device notifications
- **Device notifications** in the account menu (your initials, top right): turn them on and everything that reaches your bell also reaches this device, even when EOS is closed. Turn them off per device.
- Tapping an alert opens the task, conversation, request or package it is about.
- On iPhone and iPad, add EOS to the Home Screen first (Share, then Add to Home Screen); the menu says so until you have.
- The bell's "Turn on desktop alerts" now turns on device notifications when the browser supports them.

## v195 · October 29, 2026 · Fix: EOS did not load
- v193 and v194 stopped at the loading screen for everyone: the Budget card on Home was registered before the list of Home cards existed. Fixed; nothing else changed.
## v194 · October 29, 2026 · Small fix
- A fix to the roles and permissions database script so it runs cleanly the first time.

## v193 · October 29, 2026 · Budget charts
- Budget opens on a new **Overview** tab (anyone who can approve invoices): the fiscal year at a glance by fund, with tabs for All funds, General, Enterprise, Capital, Chapter 90 and Paving. Tiles show budget, spent, encumbered, available, a pace read (spending against the share of the year gone by) and the projected year-end spend.
- **Spending through the year**: one point per ledger load, the budget line, the straight-line pace and a projection to the end of June. Hover or tab to a point for the figures; **Table** shows the same numbers as a table.
- **By division**: a card for Engineering, Highway, Parks & Forestry, Water, Sewer and the rest, each with a spent / encumbered / available bar, a tick where the year stands, and an on pace, ahead of pace or over budget read. Tap a card for its budget lines.
- **By category**: personal services, purchased services, supplies, other charges and capital outlay as bars, with a table view.
- **Load ledger report**: load the City's Ytd_Budget_Report workbook straight from the Budget tab. Every load is kept as a dated snapshot, so the chart gains a point each month and a budget line keeps its history.
- **Budget lines** gain a Division filter, and tapping a line opens it: its history across loads, pace, and the funding sources, commitments, invoices and projects tied to it, with a button to add a funding source for the line.
- **Funding sources** can be added and edited from the app (on the Funding tab or from a budget line), with the ledger account and department. Tap one to see what is committed, invoiced and paid against it and the ledger line it maps to.
- A **Budget** card on Home for level 5 and above, with the pace by division.
- Funding sources are edited by whoever can edit commitments; loading the ledger needs the invoice-approval permission.
- Run db/017 once in the Supabase SQL editor, after db/016. Until it runs, the Overview reads the lines already loaded and the Load and funding-source buttons stay hidden.

## v192 · October 29, 2026 · Roles and permissions
- What you can **do** now comes from a **permission set**, not from your level. Your level still decides what you can **see** (which rows and fields).
- Six sets to start: Viewer, Field crew, Crew leader, Supervisor, Division head and Administrator. Every role points at a set, so people get their permissions through their job. A person can also be given a different set, extra grants or denied grants on their Directory page.
- **System Health › Roles & permissions**: a grid of every action by set, where a tick saves straight away. Add, rename, copy and delete sets. Each role has its permission set beside its level. EOS will not let the last person who can manage permissions be locked out.
- Actions covered: seeing Budget, Directory, Calendar, Documents, Pavement, Dashboards and System Health; creating and editing tasks, work orders, projects, meetings and document details; notes, templates, requests, work packages, field forms; deleting records; invoices and commitments; assets, GIS layers and pavement data; the Directory, roles, settings, the email ingest and shared dashboards.
- Every change is checked in the database as well as on the screen, so permissions hold even outside the app.
- Existing access was carried over from levels: level 6 roles are Administrators, level 5 Division heads, level 4 Supervisors, levels 2 and 3 Crew leaders, level 1 Field crew. Consultants are Division heads rather than Administrators. The Directory is managed by Sam, Tracy, Jenn and Eric.
- People can now be **deleted** from the Directory (by the four Directory managers). Someone with EOS access must have it turned off first. The person goes to the recycle bin and every link to them is restored if they are brought back.

## v191 · October 29, 2026 · Notifications
- A **bell** in the header with a count of what is new. Open it for the list; click an item to go to the record. **Mark all read** clears the list, and the gear lets you switch off kinds you do not want.
- You are told about: messages sent to you, tasks you were put on, notes added to your tasks (including ones that arrive by email), tasks you asked for being marked done, new requests (supervisors) and answers to your requests, work packages given to you and what happened to the ones you sent.
- A **Today** line every weekday morning: what is due today, what is overdue, and your meetings.
- A **Notifications** card on Home shows the latest. It is added to the standard layout and once to any Home you had already arranged.
- The page checks every half minute while open. Turn on desktop alerts from the gear and you get one when something arrives while you are on another tab. The browser tab title shows the count.

## v190 · October 28, 2026 · Deleting records
- A **Delete** button on tasks, work orders, projects, meetings, requests, documents, organizations and work packages. It works the way OpenGov does it: nothing is destroyed straight away. The record goes to a recycle bin with its notes, forms and favorites, and an **Undo** on the confirmation brings it straight back.
- Deleting a work order can take its tasks with it, and a project its work orders and tasks (a tick box on the confirmation, with the counts). Documents, emails, requests, invoices and commitments that pointed at a deleted record are kept and simply lose the link; they get it back on restore.
- Select several rows on Tasks, Work orders, Projects or Documents and choose **Delete…** to delete them together; one Undo restores the whole set.
- **System Health › Recycle bin** lists everything waiting, who deleted it, when, and the reason. **Restore** puts a record back with its links; **Delete for good** removes it permanently. The bin clears itself after 30 days.
- Every delete and restore shows in the record's history.
- People are not deleted; **Remove from directory** on a person's page still does that job. An organization that is the vendor on an invoice or commitment cannot be deleted until those are moved.

## v189 · October 28, 2026 · Work packages
- New **Packages** tab. Bundle tasks, work orders, projects, people, documents and map points into one package and hand it to a person.
- Each package has a note, a due date and a tick list. The person it was given to can accept it, tick items as they go, send it back with a question, or mark it done. The sender can cancel it or send it again.
- **Discuss** opens a Messages conversation between the sender and the receiver. **Print** gives a one-page field sheet with tick boxes and signature lines.
- Create a package from **+ New › Work package**, or select rows on Tasks, Work orders or Projects and choose **Add to package**.
- A **Work packages** card on Home shows packages given to you and ones you sent, with progress.

## v188 · October 28, 2026 · Mini pages, What's new, Directory
- Mini pages (the floating task, work order and project windows) now move by the grip strip across their top edge. You can select text in the header again.
- The page behind a mini page, an Add update window or a dialog is no longer blurred; it just dims.
- **What's new** is linked from the Home greeting and now shows every build and what is coming next.
- On a person's page, **Remove from directory** hides someone who has left (nothing is deleted, and **Restore** brings them back).

## v187 · October 27, 2026 · Slim header, floating GIS, Home touches
- The header is one slim row. It slides away while you scroll down and comes back as soon as you scroll up.
- GIS has no header bar: the City seal (menu), + New and your account float over a full-screen map. On iPad the Basemap button is back on screen.
- Full-height pages fit the iPad screen; Home cards are no longer cut off.
- The two-step sign-in reminder sits at the bottom of the screen instead of inside the header.
- Home: the greeting line now shows what is due today and today's meetings. On your first visit of the day the numbers count up and the Overdue card pulses once. The aerial photo drifts slowly and is tinted by the time of day. Pressing Done draws a check mark.

## v186 · October 26, 2026 · Home and Work extras
- **My favorites**: star any task, work order, project, person or document and find it again from a card on Home.
- **Needs attention** card on Home: overdue work, tasks waiting on another task, nothing changed in 30 days, in progress with nobody assigned or no due date.
- Tasks can depend on other tasks ("Depends on"), shown on the task page.
- Task templates and repeating tasks (every N days, weeks, months or years) from the Templates button on Tasks and the + New menu.
- New **Requests** tab: anyone with EOS access can send a request for work; supervisors accept it (which creates a task), decline it with a reason, or mark it done.
- Project page: sortable task table with labor, include work-order tasks, show completed, choose columns.
- Projects: a Portfolio view with project health (red, amber, green) and the capital plan by fiscal year, with Excel and CSV export; a portfolio health card on Home.

## v185 · October 26, 2026 · Field and iPad
- Field forms can take photos (camera or library); photos are saved as documents on the task.
- Forms filled out offline are saved on the device and sent automatically when you are back online.
- EOS can be installed on the iPad or phone home screen like an app.
- Larger fields on touch screens so the page no longer zooms when you tap a field.
- New **Paving inspection** form: course inspected, weather, temperatures, thickness, result, photos and a punch list.

## v184 · October 26, 2026 · Security
- Idle sign-out after a period of inactivity, and a **Sign out of all devices** option.
- Two-step sign-in with an authenticator app, set up from the account menu.
- System Health shows page errors people run into and a backup check.

## v183 · October 25, 2026 · GIS search and tools
- Map search finds assets by their ID, parcels, and documents that have a location.
- **Near me** centres the map on your location and lists the assets around you.
- Create a work order from a point on the map.
- Street-view arrows redrawn as large chevrons so they are easy to tap.

## v182 · October 25, 2026 · Directory accuracy
- A person whose email address was guessed rather than confirmed shows an **Unverified address** chip.

## v181 · October 25, 2026 · Calendar
- Filter the calendar by meeting or department.
- Recurring meetings view, with a way to add several at once.
- A private calendar link adds your EOS meetings and tasks to Google, Apple or Outlook calendar.

## v180 · October 25, 2026 · Search
- The same search language everywhere: several words, "quoted phrases", OR, and -words to exclude, with matches highlighted.
- Search now covers organizations, commitments and invoices.
- A Department column and filter on Tasks, Work orders, Projects, Commitments and Documents.

## v179 · October 25, 2026 · Directory and data quality
- An organization chart in the Directory, built from roles.
- A Data quality card in System Health.

## v178 · October 25, 2026 · Messages
- New **Messages** tab: direct messages and named groups, inside EOS only. Unread counts, search, and **Discuss** on a task or work order opens a conversation with the people on it. You can edit a message for 15 minutes after sending.

## v177 · October 25, 2026 · Last modified by
- Tasks and work orders show who last changed them, in lists, on the record and in exports.

## v176 · October 25, 2026 · Budget
- **Budget lines** tab: the City budget by fund, organization and account, with totals and export.
- An invoice **Pipeline** board showing where each invoice sits and how long it has been there.

## v175 · October 25, 2026 · Pavement
- **Pavement Season** tab: a board by stage and the annual paving list with export.
- When a paving work order moves forward, its street sections move with it.
- Reclamation tasks suggest the standard checklist of steps.
- Documents with a location show on the street sections near them.

## v174 · October 25, 2026 · Home and Work
- A **Done** button on task rows and board cards.
- Home and Calendar can show only what applies to you, or everyone.
- My tasks splits into what you owe and what others owe you.
- A **+ New** menu in the header (shortcut N) to create a task, work order, project, meeting or person from anywhere.
- Names in lists link to the person in the Directory.
- Column headers on the task list, row highlight when you select, status tabs across the top, and a Save/Cancel bar that stays visible while editing.
- Fixed: the labor grouping missed some assignees; the weather card could loop when no location was set.

## v173 · October 25, 2026 · Directory
- Hide inactive applies on the Employees tab only. Status and notes on people and organizations.
- The search icon left the header; Ctrl/Cmd+K and the Home search box remain.

## v172 · October 25, 2026 · Directory
- Directory status shown for employees only.

## v171 · October 23, 2026 · Done for everyone
- Anyone with EOS access can mark their own tasks done, from the task page and from Home.

## v170 · October 23, 2026 · Directory fixes
- Employee number wording and a Hide inactive switch in the Directory.
- Fixed: a sign-in error on the GIS tab.

## v169 · October 22, 2026 · Roles and levels
- One place to manage roles and the access level each role carries, in System Health.

## v168 · October 22, 2026 · Accounts
- An Accounts tab in the Directory: last sign-in, activity, password resets.

## v167 · October 22, 2026 · Search-first Home, Ask AI, Knowledge Base
- Home opens on one search box with two modes: **Search** everything in EOS, or **Ask AI** a question answered from EOS data and the Knowledge Base, with sources and follow-up questions.
- New **Knowledge Base** tab for definitions, how-tos and City processes.
- Build your own Home dashboard from gadgets: KPI tiles, charts, lists, a timeline, weather and more.
- **Add update**: type or dictate an update in the app; it is filed the same way as an email.
- **Run ingest now** to read new email straight away.
- **Find** searches within the open page, like Ctrl+F.
- GIS and Assets combined, with a floating layer panel; search Beverly addresses on the map.
- Mini pages can be dragged and remember their place and size.
- Work: a status card for every status, lined up with the grid.
- Fixed: text overflow in the Commitments side panel.

## v166 · October 21, 2026 · Asset hierarchy
- Assets follow the ISO 55001 hierarchy: portfolio, asset class, asset type, asset.
- Security fix: sign-in account details are no longer readable through the data service.

## v165 · October 21, 2026 · Assets read live
- Assets read live from ArcGIS instead of a copy, so they are always current.

## v164 · October 21, 2026 · Assets
- New **Assets** tab with class cards, lists and an asset panel with a mini map and work history.

## v163 · October 20, 2026 · Bulk upload
- Upload whole folders and zip files of documents from the Documents tab; files already in EOS are skipped.

## v162 · October 20, 2026 · Home fixes
- Fixed: dates showed one day early.
- The Home timeline fits its day labels beside the date; Home task rows show their project.

## v161 · October 20, 2026 · One header
- One header on every tab; the second page bar is gone.

## v160 · October 20, 2026 · Pavement and Documents
- Pavement became the first EOS dashboard.
- Documents tab redesigned with a map page and a list view.

## v159 · October 20, 2026 · GIS tab
- The Map became the **GIS** tab: a full-page map, a collapsible layer panel and tools on the map itself.
- A meter replacement program dashboard.

## v158 · October 20, 2026 · Menu and Home fixes
- Fixes to the app menu and Home.

## v157 · October 20, 2026 · Profile photos
- Set a profile photo and a background from the initials menu. Photos appear in activity, history and the Directory.

## v156 · October 20, 2026 · One search across Work
- One search box and one Filters panel across Tasks, Work orders and Projects.

## v155 · October 20, 2026 · App menu
- The City seal opens a menu of every page, replacing the tab bar.
- Home: a calendar timeline in a side rail, new cards, a weather and date card.

## v154 · October 20, 2026 · One Work tab
- Tasks, Work orders and Projects merged into one **Work** tab.

## v153 · October 20, 2026 · Field forms
- One form engine for editing records, Pavement and field forms; submitted field forms are kept with their task.

## v152 · October 20, 2026 · Directory
- The Directory shows who has EOS access and who has an OpenGov account; access is managed there.

## v151 · October 19, 2026 · Calendar timeline
- Tasks appear on the Calendar by their planned, actual and due dates, with a scrolling timeline.
- Fixed: the email ingest assigned due dates that were not in the email.

## v150 · October 19, 2026 · One look
- One standard look for everyone; the account card shows your name, role and level, with a theme (light, dark, automatic) and accent colour.

## v142–v149 · October 2026 · Search and looks
- Search everything with Ctrl/Cmd+K, with matches highlighted.
- Sortable column headers on lists.
- Choose light or dark mode and an accent colour.
- Dashboards can show live EOS data.

## v114–v119 · October 2026 · Editing and projects
- Edit tasks, work orders, projects, documents and people in the app, with a history of changes and undo.
- Projects and programs sit above work orders, with milestones, budget and funding.
- Fixed: the document side panel display.

## v55–v113 · September–October 2026 · Sign-in
- EOS data is visible only when signed in, filtered by each person's access level.
- Many smaller builds in this period were not individually recorded.

## v1–v54 · September 2026 · First builds
- Email intake: staff email updates to the EOS mailbox and they become tasks and work orders.
- The first tracker web page with user sign-ins.
- Email attachments are saved as documents.
- A button on each task to send an update by email.
- The database and the website were set up.
