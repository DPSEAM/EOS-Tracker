# EOS design notes

Proposals for the larger pieces, written 2026-10-27 from Sam's list. Each section says what exists today, what is proposed, and what Sam has to decide. Settled decisions get moved to the top of their section with a date, so a later conversation does not reopen them.

---

## 1. Roles, levels and permissions

**Today.** Access is one number per person, the *visibility level* 0–6, which now comes from the person's role (`roles.visibility_level`, v169). The level decides: which tabs show (`settings.tabs_by_level`), which views return rows (`view_defs.min_level`, `row_filter`), which columns come back blank (`field_visibility`), which GIS layers and saved maps show, and whether the person can edit at all (`settings.editing.min_level`, 6, decision 2026-10-05). 69 roles exist; 33 carry a level; 36 (mostly OpenGov crew roles) have none. 20 people have logins. Everything except editing is a *reading* rule; the only writing rule is "level 6 edits, everyone else can mark a task Done, send a request, message, star".

**How OpenGov does it.** A *role* is a named bundle of permissions: for each record class, Create / Read / Update / Delete, plus feature switches (export, admin, GIS edit). People get one or more roles. Field-level security hides sensitive fields per role. There is no single "level" number; the role *is* the permission set.

**Proposal: keep levels for reading, add role grants for doing.** Levels already answer "what can this person *see*" well and are wired through 63 views; replacing them would be a rebuild. What is missing is "what can this person *do*", and that is where OpenGov's model fits:

- `roles.grants` (JSON on the existing roles table; no new table): `{"tasks":"crud","work_orders":"cru","people":"ru","documents":"cru","requests":"triage","packages":"send","export":true,"gis_edit":false,"budget":"r"}`. A grant on the role, not the person, so adding a crew leader is one role change.
- Role templates, OpenGov-style, so Sam picks a template rather than ticking boxes: *Crew* (read, Done, forms), *Crew leader* (+ create tasks, edit own), *Superintendent* (+ edit work orders, requests triage, packages), *Admin* (+ directory, documents, budget read), *Director* (+ budget, review), *System owner* (everything). Each template sets both the level and the grants.
- Per-person overrides only as exceptions, shown in orange on the Accounts tab so they are visible and temporary.
- Enforcement where it already happens: `eos_can_edit()` becomes `eos_can(table, action)` and `eos_create` / `eos_edit` call it; the app calls the same function once at sign-in to decide which buttons to draw. One function, one truth.
- **Access manager** (System Health › Access): a grid of roles × capabilities with the level in the first column; click a person to see their *effective* access in one card (role, level, grants, overrides, last sign-in); every change written to `record_changes`.

**Decisions.**
1. Keep levels as the reading rule and add grants for actions (recommended), or replace levels with roles entirely?
2. Who may edit the Directory now, before the manager exists? Setting `settings.editing.tables.people.min_level = 5` would let Tracy and the directors add, edit, remove and restore people today.
3. Roles with no level: give the 36 OpenGov crew roles level 1 by default (they are field staff), or leave blank until each is assigned?

## 2. Ask AI: real resources, not links

**Today.** `eos-chat` has two tools: `search_knowledge` and `run_query` (one read-only SELECT over the views). A document shows up as a source chip that links to the record. The chat cannot open the file or read its text.

**Proposal.**
- New tool `get_document(id)`: returns title, category, date, the extracted text (`v_document_text`, capped at ~12k characters) and a short-lived signed URL for the file. Claude can then quote from the plan, the invoice or the letter, not just name it.
- New tool `find_documents(words, filters)` so "find the Dewberry sewer atlas for Prince Street" is one call, not a hand-written SQL.
- Answers carry **cards**, not only chips: a document card (thumbnail, title, date, Open, Download), a task card (number, title, status, Done), a person card. The app already has mini pages; a card click opens the record in one.
- Same pattern for the other way round: *Ask AI about this record* on a task, document or work order pre-loads that record into the conversation.
- Guardrails stay: everything runs as the signed-in person; the signed URL is minted by the Edge Function with the user's token, so a level-2 user cannot be handed a level-4 document.

**Decision.** Should Ask AI also be able to *act* (mark done, add a note, create a task) with a confirm step, or stay read-only for now? Recommended: read-only this build, actions as a later build with an explicit "Do it" button per action.

## 3. Saved AI conversations

**Today.** Conversations live only in the browser tab (`settings.chat.note`).

**Proposal (one new table, needs approval): `ai_conversations`** — id, person_id, title, messages (jsonb, the same array the app already keeps), source record (optional: the task or document it started from), pinned, created_at, updated_at. Per person; nobody else can read them, not even level 6 (the same rule as Messages).
- Left-hand history like Claude and ChatGPT: *Today / Yesterday / Last 7 days / Older*, search by title and content, pin, rename, delete, *New chat*.
- Title written automatically from the first exchange (the function returns a 4–6 word title with the first answer).
- A conversation keeps its sources, so reopening it still shows the cards.
- Retention: conversations older than 180 days are pruned unless pinned (public-records question: see §15).

## 4. Sign-in screen

**Today.** A plain card: email, password, forgot password, the two-step prompt.

**Ideas.**
- Full-screen City aerial (the same background as Home, sharp) with a slow drift; the seal and "EOS · City of Beverly Public Services" top-left; the sign-in card bottom-right on tablet/desktop, centred on phones.
- A quiet status line under the card: *EOS is up · last email read 12 minutes ago · 8 people signed in today* (public counts only, from a tiny `v_status` view the anon role can read; nothing about who).
- **Trusted device**: after one full sign-in on a device, the next sign-in is one tap on your photo plus the two-step code; the session itself already lasts (idle sign-out rules from v184 still apply).
- Remember the last page: signing in returns you to where you were.
- Seasonal and time-of-day tint, like Home. Winter storm mode: a banner when `settings.weather` reports a storm, so the sign-in screen itself tells crews there is a callout.
- *Request access* link for staff without a login: opens a request (uses `requests`, no email needed).

**Decision.** Photo-first "trusted device" sign-in: yes or no? It is the piece that changes the feel the most.

## 5. Document collections

**Today.** 3,003 documents with a category (12 values), a department, and for bulk imports the folder path they came from (`source_folder_name`, 55 names). No user-made grouping.

**Proposal (one new table, needs approval): `collections`** — id, name, parent_id (nesting), description, min_level, owner_id, record links (optional: a project or work order the collection belongs to), created_by. Documents carry `collection_ids uuid[]` (a column, not a join table) so one document can sit in several collections without copies.
- Documents tab gets a *Collections* side tree (like folders), drag documents onto a collection, multi-select › *Add to collection*.
- A collection can be created from a bulk-import folder in one click (the 55 folder names become the starting tree).
- Record pages show *Collections* alongside *Documents*; a project's collection is created automatically when the first document is linked.
- Share a collection as a link (level-gated), print a contents list, export as a zip.

## 6. Work tied to assets (GIS ↔ records)

**Today.** Assets are read live from ArcGIS by `ASSET_ID` (v165/v166). Tasks carry a free-text `asset` field (224 tasks, almost all "Non-Asset"). Field forms save `ASSET_ID`. Nothing links a work order or request to an asset, and the asset panel's work history only finds forms.

**Proposal (no new table): `asset_refs jsonb` on tasks, work_orders and requests** — `[{"layer":"Hydrants","asset_id":"HYD-0412","oid":412,"label":"Hydrant HYD-0412 · 12 Prince St"}]`. A column on the three tables keeps the database lean and lets a work order cover several assets (a water main break touches a main, two valves and a hydrant).
- Pick assets on the map from the record (Add asset › tap on the map or search by ASSET_ID), and the other way: *New work order* / *New task* from an asset panel pre-fills the link (v183 already does this for a map point).
- The asset panel's *Work history* reads every task, work order, request and form with that ASSET_ID: the full life of the hydrant in one list.
- GIS tab: *Show work* overlay colours assets by open work (red = open work order, amber = open task, grey = none).
- **Back-fill** of existing work, three passes, each producing a review list before anything is written: (1) OpenGov records that already carry an asset (the OpenGov `asset` field on tasks, via the field map); (2) ASSET_IDs mentioned in titles, instructions, notes and emails (regex per layer's ID pattern); (3) location text geocoded and matched to the nearest asset of the layer the task's work type implies (a "hydrant flushing" task near one hydrant). Expect pass 1 and 2 to be exact and pass 3 to need Sam's eye.
- Analysis that becomes possible: work per asset, per street, per asset type; repeat visits; cost per asset once invoices link to work orders (§13).

## 7. OpenGov activities

**Today.** `settings.opengov_picklists.non_asset_activities` holds the non-asset list; the asset activities (per asset class, with trade and estimated hours) are not in EOS. `opengov_get()` and the `opengov-snapshot` function can read OpenGov read-only.

**Proposal (one new table, needs approval): `activities`** — opengov_id, code, name, asset_type (matches `settings.asset_hierarchy` types), trade, est_hours, active, synced_at. Loaded by the snapshot function from the OpenGov activities class (read-only, inside the standing rule). Tasks get `activity_id`; the task form offers the activities for the linked asset's type first. The picklist setting keeps the non-asset list until the table replaces it.

## 8. Record IDs

**Today.** Tasks: integer sequence, shown five digits (`00101`), highest 1,369 of 726 live rows (the hydrant re-import used numbers). Work orders: `W-0373`, four digits. Projects: a sequence, 37. Requests `R-0001`, packages `P-0001`, commitments and invoices have sequences too. Documents, people, meetings: UUIDs only. Display padding is set in `settings.id_format`.

**Assessment.** The sequences are integers (2 billion) and never reused, so volume is not a problem. The only limits are the *display* widths: five digits for tasks (99,999) and four for work orders (9,999). At the current pace (~700 tasks in three months, with imports) five digits last about 30 years; four digits for work orders about 25 years. The 1,244-task hydrant import shows that one bulk load can use a year's numbers in a day.

**Proposal.** No prefix by fiscal year (#767) — a prefix breaks "what is the newest" and makes the number longer to say on the radio. Instead: (1) the app pads to `max(digits, length)`, so a number past 99,999 simply shows six digits with no migration; (2) give documents a human number `D-000123` (they are quoted in emails and on invoices), meetings `M-`, and keep UUIDs underneath; (3) one `settings.id_format` entry per record type; (4) a *Find by number* box that accepts any of them (`00101`, `W-16`, `R-3`, `D-123`).

## 9. GIS symbols by default and rotation

**Today.** EOS owns symbology, but it is only saved inside saved maps (`gis_maps.style_overrides`). A fresh sign-in gets the raw layer list with default swatches until someone picks a saved map. The point renderer uses SVG shapes.

**Proposal.**
- `settings.gis_symbology`: one default style per layer (the same style object the saved maps use), plus the default layers that are on. A new sign-in sees the finished map; saved maps still override.
- A *Set as default for everyone* button (level 6) on the current map's styling, so Sam styles once in the app and does not edit JSON.
- **Rotation by field**: each point style can name a rotation field (`ROTATION`, `ANGLE`, `FLOW_DIR`) and an offset. Rendering is a CSS `transform: rotate()` on the SVG marker, so valves, signs and flow arrows point the right way at any zoom. Also a "rotate with the map" switch for north-up symbols. Cost: nothing on the server; the attribute already comes with the feature.
- Line symbols with direction arrows (sewer and storm flow) using the same field.

## 10. Popups

**Today.** EOS draws its own Leaflet popups from raw attributes.

**Proposal.** Read each layer's **popup definition from ArcGIS Online** (`popupInfo` on the item: field order, visibility, aliases, number formats) and render that, with three EOS additions at the bottom: *Open asset*, *New work order here*, *Work history*. One configuration (in AGOL, where the GIS Coordinator already maintains it), no second set of popup settings in EOS. Layers without a popupInfo fall back to the first six non-system fields. If Sam prefers popups configured only in EOS, the alternative is `settings.gis_popups` per layer; the AGOL route is recommended.

## 11. Document geocoding and the import folder — status check

**Facts (2026-10-27).** 3,003 documents; 1,009 have coordinates; 127 have a location text but no coordinates (geocoder could not resolve them, typically a landmark name — `landmarks` is the fix); the last geocode ran today at 18:15. The Drive import folder works: 2,692 documents carry a `source_folder_name`, and the email ingest ran 33 times in the last 24 hours (last 19:02). So both are running. What is missing is visibility: a **System Health card** with *geocoded / with text but unresolved / no location*, the last run, and a list of the 127 to fix by adding landmarks or correcting the text. The nightly check (db/007) can record these counts.

## 12. Notifications

**Today.** Messages poll every five seconds while the tab is open; nothing else notifies anyone.

**Proposal (one new table, needs approval): `notifications`** — person_id, kind (message, mention, request, package, overdue, assigned, mention), title, body, link (route), read_at, created_at. Written by the same functions that create the event (msg_send, req_submit, wp_send, eos_edit when an assignee changes) — no polling job.
- A bell in the header with the unread count; a list grouped by day; *Mark all read*; tap opens the record (mini page).
- Delivery with Supabase Realtime on the `notifications` table (one channel per person), replacing the 5-second poll for Messages too (#1325).
- Phone: Web Push for the installed app (v185 icon) — needs a service worker (#1344), so it comes with the offline work.
- Email: only digests (morning summary of overdue and new assignments) and only once the Gmail path is decided (#1320). Never one email per message.
- Preferences on the account menu: which kinds, and quiet hours.

## 13. Invoices from the email ingest

**Today.** `invoices` has one row; `invoice_rules`, `invoice_intake` and the sign-off functions exist (`eos_invoice_route/sign/release/mark_paid`, `eos_run_checks`, `eos_match_invoice`). Nothing creates invoices from mail.

**Proposal.** A new ingest rule: an email from a vendor domain (organizations with `person_type = vendor`), or with "invoice" in the subject, or with a PDF attachment whose text contains "Invoice" and an amount, is handed to an **invoice extractor** (Edge Function `eos-invoice`, Claude with a strict JSON schema): vendor, invoice number, date, due date, amount, PO number(s), line items, period. It creates the invoice row, attaches the PDF as a document, calls `eos_match_invoice` to find the commitment by PO or vendor, runs `eos_run_checks`, and routes for sign-off. Unmatched invoices land on the Budget › Pipeline board in a *Needs matching* column. The budget line is charged when the invoice is released, so the Budget tab moves without a Munis reload (Munis stays the truth at month end and reconciles).

## 14. CYVL: LiDAR point cloud, 3D view, plans to GIS

**What is needed from CYVL first.** The point cloud format and size (LAS/LAZ, COPC, Potree, or an Esri I3S/SLPK scene layer), the coordinate system, and whether the 360° imagery and the point cloud are already aligned. Their plan-to-GIS workshop notes.

**Proposal for 3D.** The City already runs ArcGIS Online, which hosts **point cloud scene layers** natively. Ask CYVL for I3S (SLPK) — or convert LAZ to I3S once with ArcGIS Pro — publish it to the EOS group, and EOS gains a **3D** button on the GIS tab that opens the ArcGIS Scene Viewer (embedded, signed in with the same ArcGIS account) at the current map position, with the EOS layers (hydrants, valves, work) draped over the point cloud. No new servers, no custom 3D engine, and the GIS Coordinator can manage it like any other layer. If AGOL credits are a concern, the alternative is a self-hosted COPC file on object storage viewed with Potree inside EOS; heavier to build and maintain. Recommendation: AGOL scene layer.

**Plans to GIS.** The pipeline CYVL is working toward is: upload a plan set (PDF/DWG) → georeference the sheets (two or three control points on the map, or the title-block coordinates) → extract features by layer (pipes, structures, curb lines) with AI vision → review on the map → publish to the right ArcGIS layer as *proposed* with the plan as the source document. EOS already has the pieces at the ends: documents with text extraction and location, and the asset layers. The middle (georeference + extract + review) is a Documents › *Read as plan* workflow. Design properly after reading CYVL's notes; do not build twice.

## 15. Records retention (noted, not asked)

Ingested emails, AI conversations and messages are likely Massachusetts public records (the architecture review said so in September; task #1356 is the City Solicitor's deck). Any retention or pruning rule in §3 and §12 should be agreed with the City Clerk before it runs.

## 16. Where the plan lives — settled 2026-10-28

**GitHub holds the record.** `CHANGELOG.md` is the history (every build, newest first, with what shipped in it); `PLAN.md` is the plan (next builds in order, what waits on a decision, the backlog by area). The former Project #8 in EOS was deleted on 2026-10-28; its completed tasks were written into the changelog under the builds that shipped them, and its open tasks into the plan by area. *What's new* in the app renders the two files from the site. Versioning follows commits: the `BUILD` line in `index.html` is the version, and the `version.yml` Action stamps the next number on any commit of `index.html` that does not already carry one, with a changelog line from the commit message. This document holds the reasoning that does not fit in either file.

## 17. Budget: the ledger as snapshots, divisions, funding sources — 2026-10-29

**The ledger is loaded, not synced.** The City ledger (Munis) stays the system of record. EOS keeps one set of `budget_lines` rows per as-of date; the Ytd_Budget_Report workbook is parsed in the browser (SheetJS, already used for export) and sent to `eos_budget_load` (db/017), which replaces that date's rows. Nothing is edited line by line in EOS. The Budget lines tab reads the newest snapshot; `v_budget_snapshots` (one row per date, fund and org) feeds the chart and the Home card, so loading a report every month grows the trend without any new table.

**Divisions come from the codes.** A General Fund org is `1` + the three-digit department code + a category digit (`14101` = Engineering 410, personal services); enterprise funds are one division each. `settings.budget_divisions` names them, so the same codes can drive permissions by division later (foremen see their own lines) without a second mapping. Categories come from the object prefix (51 personal services, 52–53 purchased services, 54–55 supplies, 56–57 other, 58 capital, 59 debt).

**Pace, not forecast.** The read on a tile or card is spending alone against the share of the fiscal year gone by, with 15 points of slack; encumbrances count only toward *over budget*, because a purchase order is the whole year's commitment on day one. The projection is spending to date divided by the share of the year elapsed: honest and easy to explain, wrong for seasonal lines (snow and ice, paving), and the page says so. A run-rate or seasonal model can replace it once there are a year's snapshots to fit.

**Funding sources are the join.** A funding source (appropriation, grant, Chapter 90, capital account) carries the ledger account string; commitments point at a funding source; invoices point at commitments. That is the drill-down from a budget line to the purchase orders, invoices and projects behind it, and it works without changing the commitment model. Funding sources are edited through the standard editor (`settings.editing`, `eos_create`/`eos_edit`) under the *commitments.edit* permission, so every change is in the record history.

**Tabs follow the money (v201).** Budget → Authorizations → Project funding → Contracts → POs → Invoices, left to right in the order a dollar moves: the ledger, the appropriation or grant it may be spent from, the project it is set aside for, the contract, the purchase order, the bill. Nothing changed in the data model for this: Authorizations is the funding-source rollup, Project funding is a read across `projects.budget` / `funding_sources` and the commitments that carry `project_id`, and Contracts and POs are the commitment records split on `commitment_type` (a stand-alone PO is still a commitment row). The Overview and Budget lines are two views inside Budget; the invoice list and the pipeline board are two views inside Invoices. When requisitions and POs are built, the POs tab is where they land.

**Fund tabs follow the meeting.** General, Enterprise (Harbor Management joins when its accounts are pulled), Capital, Chapter 90 and Paving. The last three have no ledger lines yet and show their funding sources instead, so the tab is useful before the accounts are loaded. Paving is kept separate because it is two funding sources and the Commissioner and the City Engineer want it on its own.

**Deferred.** Requisitions and purchase orders (quote → requisition → PO with the Commonwealth checks), projected budgets on projects that become encumbrances when a real PO exists, invoice routing by project owner, and the PO log sync (OneDrive or Google Sheets) are in the plan; the budget module above is built so each of them can attach to a funding source rather than to a ledger line.

## 18. Asset types: one record per type, the register behind the map — 2026-10-29

**Two kinds of type, one hierarchy.** The ISO 55000 hierarchy (portfolio › class › type › asset › attributes) stays in `settings.asset_hierarchy`. A type is backed by exactly one place: an ArcGIS layer (GIS is the record; EOS reads it live and copies nothing) or the `assets` table (EOS is the record). That is the whole rule for "does this go through GIS or through Assets": if GIS staff maintain it and its location is the point, it is a layer; if it is inventory (iPads, printers, radios, tools, vehicles, facility parts), it is a type kept in EOS. A non-spatial asset may carry an address or a pin, but it never becomes a GIS feature.

**Attributes belong to the type.** Types kept in EOS carry `fields` (key, label, type, options); values live in `assets.attributes` (jsonb, db/019). The standard editor draws those inputs through a small per-table hook (`ED_EXTRA`), so there is still one editor and one history. A spreadsheet import maps columns to fields and attributes and can add attributes to the type on the way in, so the iPad spreadsheet loads in one step and the next spreadsheet of the same type maps itself.

**No Assets tab.** Decided 2026-10-29: the register stays behind the GIS map. A separate Assets tab would want its own map, and two maps is the overlap the rule above removes. System Health › Asset layers was renamed Asset types because it now holds both kinds.

