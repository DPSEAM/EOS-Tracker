-- 020 · Ingest rules consolidated, dates, and the overwrite policy — 2026-10-30
-- Run once in the Supabase SQL editor. Database-only; no build change.
-- What it does:
--   1. Replaces the 64 ingest rules with the 31-rule set in docs/INGEST.md (the old rows are kept in rules_archive).
--   2. Cleans settings: removes the 46 temporary calendar rows the ingest had been writing there, fixes
--      default_task_priority ('medium' is not an OpenGov value), adds settings.ingest.
--   3. Adds the helpers the slimmed ingest prompt calls: eos_ingest_begin() (run lock + cutoff + queue counts),
--      eos_ingest_settings() (only the keys the ingest needs, ~6 KB instead of ~300 KB), eos_task_candidates(),
--      eos_wo_candidates(), and calendar_sync_staging + eos_sync_calendar_staged().
--   4. Dates: entry_date on tasks and work orders comes from the first source email (trigger); In Progress sets a
--      start_date_actual floor the way Completed already sets stop_date_actual.
--   5. v_documents_ungeocoded stops counting imports the geocoder gave up on more than 14 days ago.
--   6. data_dictionary rows brought up to date.
-- The two new scheduled-task prompts are in docs/ingest-prompt-mail.md and docs/ingest-prompt-reader.md.

begin;

-- ───────────────────────────── 1. rules ─────────────────────────────
create table if not exists public.rules_archive (like public.rules including all);
alter table public.rules_archive add column if not exists archived_at timestamptz not null default now();
alter table public.rules_archive add column if not exists archived_reason text;
insert into public.rules_archive (id, name, description, rule_type, conditions, actions, priority, is_active, created_at, updated_at, archived_reason)
select id, name, description, rule_type, conditions, actions, priority, is_active, created_at, updated_at, 'replaced by db/020 consolidated rule set'
from public.rules
on conflict (id) do nothing;
delete from public.rules;

-- RULES BEGIN (generated from the rule source; edit the rules, not this block)
insert into public.rules (name, rule_type, priority, description, conditions, actions) values
('Skip auto-replies and bounces', 'skip', 1, 'WHEN The subject or sender shows an automatic response: auto-reply, out of office, automatic reply, do not reply, noreply, undeliverable, delivery status.
DO Store the email (2a) and close it as skipped with processing_notes ''auto-reply''.
NEVER Never create a task, note or document from one.', '{"subject_match": ["auto-reply", "out of office", "automatic reply", "do not reply", "noreply", "undeliverable", "delivery status"]}'::jsonb, '{"skip": true}'::jsonb),
('Skip newsletters and bulk mail', 'skip', 2, 'WHEN The message carries a List-Unsubscribe header, or the subject reads as a newsletter, digest or roundup, and nothing in it asks the City to act.
DO Store it and close it as skipped with processing_notes ''bulk mail''.
NEVER Never skip a vendor or agency message that asks for a decision, a payment or a reply just because it is formatted like a mailing.', '{"header_match": {"list-unsubscribe": true}, "subject_match": ["newsletter", "digest", "weekly roundup"]}'::jsonb, '{"skip": true}'::jsonb),
('Weather bulletins are reference, not work', 'skip', 3, 'WHEN The sender is Precision Weather Forecasting (snowandice.com): storm warnings, daily forecasts, certified weather statements.
DO Store the email with its full body (the Home weather gadget reads v_weather_bulletins) and close it as skipped with processing_notes ''weather bulletin''.
NEVER Never create tasks or notes from a bulletin. An invoice, contract or renewal from the same sender is business mail and is processed normally.', '{"from_domains": ["snowandice.com"], "except_when": "invoice, contract, renewal or other business correspondence"}'::jsonb, '{"skip": true, "keep_body": true}'::jsonb),
('Inline images and signature logos are not documents', 'skip', 4, 'WHEN An image attachment is a signature logo, social icon or Outlook/Word temp image: names like image001.png, ~WRD0001.jpg, a long run of digits, outlook*.png; referenced by cid: in the body; sitting in or below the signature.
DO Write nothing to documents and add ''inline image skipped: <filename>'' to emails.processing_notes so v_documents_missing clears.
NEVER Never drop a photo, scan or marked-up screenshot the sender attached on purpose. When unsure whether an image is content, keep it.', '{"filename_patterns": ["^image\\d{3}\\.(png|jpe?g|gif)$", "^~WRD\\d+\\.(jpe?g|png)$", "^\\d{12,}\\.(png|jpe?g|gif)$", "^outlook.*\\.png$"]}'::jsonb, '{"skip_document_row": true, "processing_note": "inline image skipped: <filename>"}'::jsonb),
('Decide single-topic or multi-topic before anything else', 'classification', 1, 'WHEN Every source: an email body, a notepad update, or the text of an attached document.
DO Single-topic (one street, one project, one request): match the work order once and pin it on emails.work_order_id; tasks, notes and documents inherit it. Multi-topic (meeting notes, minutes, daily or weekly updates, digests, mass or field updates, to-do lists, anything whose items concern different streets, projects or people): leave emails.work_order_id NULL and match each task, note and document on its own words. After writing the tasks, if they landed on more than one work order the source was multi-topic: clear emails.work_order_id (v_pinning_conflicts lists any left behind).
NEVER Never let one task''s work order bleed onto its neighbours.', '{"multi_topic_signals": ["meeting notes", "minutes", "daily update", "weekly update", "supervisors meeting", "mass update", "field updates", "to-do", "several unrelated items"]}'::jsonb, '{"single_topic": "pin emails.work_order_id; children inherit", "multi_topic": "no pin; match per task", "validator_view": "v_pinning_conflicts"}'::jsonb),
('One action per task; title, instructions and the detail columns', 'classification', 2, 'WHEN A source asks for, reports on, or decides something that someone has to do.
DO Each independent action is its own task (a to-do list, agenda or minutes is several tasks). title = a Title Case noun phrase of what it is about, 60 characters or fewer, no verb, no dates, amounts or PO numbers ("Procore Annual Invoice Payment"). instructions = the one-line directive, verb first, 90 characters maximum, named from its context ("Inspect and free water gate valves on Arbella St"); the trigger tasks_title_guard cuts anything longer. Detail goes in its own column, never as headers inside notes: requested_by_id (people.id of who asked), context (what this is and why, one short paragraph), next_steps (one per line, dated when the source dates them), waiting_on ("Name — what"), key_details (reference facts one per line: Amount, PO, Address, Contact, Case, links, and every date written with its source phrase), tags (short lowercase text[]), notes (everything else word for word, dated lines "YYYY-MM-DD: …"). Picklist fields take OpenGov values only (rule ''OpenGov vocabulary and the data dictionary''); asset = ''Non-Asset'' unless a specific asset is named; organization_id = the outside party involved, NULL for internal work.
NEVER Never pack several actions into one task, never put a date, amount or PO number in the title, never write section headers into notes.', '{"table": "tasks"}'::jsonb, '{"title": "Title Case noun phrase <=60", "instructions": "verb first <=90, enforced by trigger", "detail_columns": ["requested_by_id", "context", "next_steps", "waiting_on", "key_details", "tags", "notes"]}'::jsonb),
('Every source leaves notes: one per topic, and one for every update', 'classification', 3, 'WHEN Any non-skipped source with real content: status, decisions, amounts, dates, commitments, names, places.
DO Write one note per topic, 1–4 sentences of substance (who said what, figures, dates), attached to the task that topic produced, else the work order it matches, else standalone. Every update to an existing task or work order (a thread reply, a ''<number> Update'', a line in a daily update, a correction) also inserts a notes row on that record saying what changed ("Status moved to In Progress; start 10/26") — the Activity timeline is built only from notes, so a column change alone is invisible. notes.source_email_id = the email, author_id = the sender''s people.id, created_at = when it was said (rule ''Every date is the date it happened''). Notes made from a document''s text end with "(from <filename>)".
NEVER Never write one summary note for a multi-topic source, never carry one topic''s sentences into another topic''s note, never repeat the task title as the note.', '{"applies_to": ["notes"]}'::jsonb, '{"note_per": "topic", "on_update": "one notes row per record touched", "attach_to": "task, else work order, else standalone"}'::jsonb),
('Staff emails that correct EOS are instructions, not work', 'classification', 4, 'WHEN A sender in settings.review_correction_senders (or a level 4–6 login) writes about EOS records: ''EOS review'', ''EOS correction'', instructions naming task numbers (00071; 0071 and 71 mean the same task), or statements about people (''X is not a City employee'', ''X is with <company>'', ''X left'', ''<mailbox> is monitored by …'').
DO Task corrections: SPLIT (keep the original for the first action, insert the second copying work order, source emails and organization); REASSIGN (labor_ids, lead first); RELINK (work_order_id by number, name or alias, or NULL); MERGE (merge_task_into(newer, older)); STATUS or DUE (OpenGov values; dates per the date rules); ''fine'' or ''correct as is'' (no change); ''should be a note'' (note on the work order, task Canceled). Every task touched gets a note ''Corrected per <sender> review email <date>: <instruction>'', review_status = ''resolved'', review_resolution = one line. Directory corrections: set people.organization_id / person_type / department / inactive as stated; create a missing outside organization; a shared mailbox is person_type ''other'' with a note on who monitors it; every change gets a people.notes line ''<correction> (<sender>, <date>)''. A person with opengov_labor_id is in OpenGov''s Labor list: add the note and list them in processing_notes for Sam instead of changing them. Close the email processed with processing_notes ''corrections applied: N'' (plus any ''who is X?'' names and rule-change requests, which are never turned into tasks).
NEVER Never create tasks or notes from the correction itself beyond those above; never delete a person; never treat a request to change how the ingest behaves as a task.', '{"sender_setting": "review_correction_senders", "signals": ["EOS review", "EOS correction", "review corrections", "task 00", "is not a City employee", "is with", "no longer with", "monitored by"]}'::jsonb, '{"task_corrections": ["split", "reassign", "relink", "merge", "status", "due", "cancel-to-note"], "directory_corrections": ["organization_id", "person_type", "department", "inactive", "notes"], "never": "treat the email as new work"}'::jsonb),
('''EOS map:'' emails save a map, nothing else', 'classification', 5, 'WHEN The subject starts with ''EOS map:'' and the body is the JSON object the Map tab sends (layer_names, style_overrides, basemap, center_lat, center_lng, zoom, optional description).
DO Upsert gis_maps by name (map name = subject after the prefix). min_level and created_by_level = the sender''s people.visibility_level, 6 when they have none. Drop layer_names not present in gis_layers and say so in the run summary. Mark the email processed with processing_notes ''map <name> saved''.
NEVER Never create a task, note, work order or document from one.', '{"subject_prefix": "EOS map:"}'::jsonb, '{"upsert": "gis_maps ON CONFLICT (name)", "min_level": "sender''s visibility_level, else 6"}'::jsonb),
('An update to existing work goes to the existing record', 'task_linking', 1, 'WHEN Before creating any task, in this order.
DO 1. Subject ''<task number> Update'' (any of ''00071 Update'', ''71 - update'', ''Task 00071 — Update''): a note on that task, never a new one; status or dates only when the body states them; append to next_steps or waiting_on only when the body gives a new one; processing_notes ''update applied to task <number>''. No such task: process the email normally and say so in the summary. 2. A notepad entry beginning ''Regarding task #…'', ''work order W-…'' or ''project #…'' names its record: treat it the same way. 3. Same Gmail thread, or the same normalized subject (Fwd:/Re:/FW: stripped) as a source email of an open task within settings.dedup_lookback_days: update that task. 4. SELECT * FROM eos_task_candidates(<title and body>, dedup_lookback_days): rows with shared identity tokens (PO, quote/SFID/contract number, street address, dollar amount, grant name) are the same task; rows with similarity ≥ settings.task_similarity_threshold are the same task; 0.5 to threshold is a possible duplicate — link only if the text plainly agrees, otherwise create and flag ''Possible duplicate of <number>''. On every link: append the email id to source_email_ids, write the Activity note, apply any stated status, dates, owner or blocker (date rules), and set work_order_id if the task had none and this source resolved one. Count it in tasks_linked.
NEVER Never create a second task for the same PO number, address, quote or grant. Never flag a one-sentence update for review just because it is short.', '{"order": ["subject ''<number> Update''", "notepad ''Regarding …''", "thread or normalized subject", "eos_task_candidates()"]}'::jsonb, '{"on_match": ["append source_email_ids", "Activity note", "apply stated changes", "fill empty work_order_id"], "candidates": "SELECT * FROM eos_task_candidates(p_text, p_days)"}'::jsonb),
('A person can have several email addresses', 'deduplication', 2, 'WHEN Resolving a sender or a named person.
DO SELECT eos_person_by_email(''<address>'') checks email_address and other_emails ignoring case. The upsert INSERT … ON CONFLICT (email_address) DO UPDATE is safe: the database routes an address in other_emails to that person''s main row. If two Directory rows are plainly the same person, say so in the run summary for Sam.
NEVER Never create a second person for an address already in other_emails; never merge people yourself.', '{"table": "people"}'::jsonb, '{"lookup": "eos_person_by_email(address)"}'::jsonb),
('Documents are upserted, never duplicated', 'deduplication', 3, 'WHEN Recording an attachment.
DO One documents row per (source_email_id, filename): INSERT … ON CONFLICT (source_email_id, filename) DO UPDATE filling blanks only (description, work_order_id, task_id, organization_id with COALESCE). The Document Filer may already have created the row with Drive fields. A re-sent file on a forward or reply: if a document with the same filename exists from an earlier email in the thread or on the same record, link that one instead of creating a second and mention the resend in the note. Only attachments actually on this message get a row; files merely described in quoted text do not.
NEVER Never overwrite drive_url, drive_file_id, storage_path, location_status, extracted_text or a title that is already set.', '{"table": "documents", "unique_key": ["source_email_id", "filename"]}'::jsonb, '{"insert": "ON CONFLICT DO UPDATE, blanks only"}'::jsonb),
('Match a work order in a fixed order; none is a valid answer', 'work_order_matching', 1, 'WHEN A single-topic source, or each task of a multi-topic source.
DO 1. Thread: an earlier email in the same Gmail thread pinned to a work order. 2. Exact: opengov_id (''26-0034''), project_name, or an alias contained in the subject or first 500 characters. 3. Identity: a PO number, address, quote or contract id, or grant name that appears in a work order''s description, aliases or its tasks. 4. Candidates: SELECT * FROM eos_wo_candidates(<text>) — link above settings.work_order_match_threshold; between work_order_review_band_low and the threshold read both descriptions and decide, flagging ''Work order uncertain'' if you link; below, no match. Same street, facility, park or equipment means the same work order even when the wording differs. 5. Standing program: routine field work (a gate valve, a pothole, a street tree) belongs on the standing program work order that plainly covers it — only when the fit is obvious; an administrative task, a grant, a purchase or an IT request has no field work order. 6. Otherwise work_order_id NULL. When you link under a new wording, add it to work_orders.aliases so the next email matches at step 2.
NEVER Never force a work order: a wrong link is worse than none. Never put anything on ''EOS System Development'' except work on the EOS system itself (database, ingest, configuration, data quality).', '{"order": ["thread", "opengov_id | project_name | alias", "identity token", "eos_wo_candidates()", "standing program", "none"]}'::jsonb, '{"candidates": "SELECT * FROM eos_wo_candidates(p_text)", "learn": "aliases", "threshold_settings": ["work_order_match_threshold", "work_order_review_band_low"]}'::jsonb),
('Paving work is tracked by street', 'work_order_matching', 2, 'WHEN An email or task concerns paving, reclaiming, sidewalks, berm, curbing, or water work ahead of paving.
DO Match the street first: work orders are named ''<year> Paving - <Street>'' and carry the street in aliases, so ''Lincoln Street'', ''Lincoln St'' and ''Lincoln St neighborhood'' all resolve to the same one. One action covering two streets goes on the first street with a note naming the other and a review flag so a person decides whether to split. The programme work order (''2026 Paving Program'') is only for items that span the programme: a status roundup, a mayor paving meeting, the paving budget.
NEVER Never file a single street on the programme; never create a street work order yourself — say in the run summary that the street has none.', '{"when": "paving, reclaiming, sidewalks, berm, curbing, water work ahead of paving"}'::jsonb, '{"match": "street first via aliases"}'::jsonb),
('Create a new work order only with enough signals', 'work_order_matching', 3, 'WHEN No work order matched and settings.auto_create_work_orders is true.
DO Create one only when the source shows at least settings.work_order_min_signals of: a named initiative, a specific location or asset, multi-step scope, several parties, a timeline or milestone. Seed aliases from the subject. Otherwise the task stands alone with work_order_id NULL.
NEVER Never create a work order for a one-off action, and never a project (rule ''Projects sit above work orders'').', '{"settings": ["auto_create_work_orders", "work_order_min_signals"]}'::jsonb, '{"on_pass": "create and seed alias", "on_fail": "standalone task"}'::jsonb),
('Projects sit above work orders; tasks below', 'work_order_matching', 4, 'WHEN Filing anything that belongs to an initiative.
DO PROJECT (projects, kind Project or Program) is the why: goal, funding, contract, milestones, an end date for a Project, none for a Program. WORK ORDER is a specific job at a place or asset, under a project via project_id or standing alone. TASK is one action by one person inside a work order; coordination or admin actions for a project sit on the project via tasks.project_id with no work order. Match the project first (name, aliases, opengov_project_name, contractor, contract or PO number), then a work order inside it; a new work order for an existing project gets project_id. project_type, project_category and phase take OpenGov values (a trigger rejects anything else); milestones are {name, target, done}.
NEVER Never create a project from an email: a distinct initiative with its own goal plus funding, a contract, a schedule or several work orders is a decision for a person — say so in the run summary.', '{"levels": ["project", "work_order", "task"]}'::jsonb, '{"match_order": ["project", "work order", "task"], "never": "create projects"}'::jsonb),
('Keep each work order''s record current', 'work_order_matching', 5, 'WHEN A task or note on a work order is created or changed.
DO project_name = a short plain name for the work (no prefixes; an old name goes to aliases); description = one line of scope; summary = 2–4 plain sentences for someone who has not been following it: what the work is, where it stands, what is next, who is waiting on whom, with the date or amount that matters — rewritten from the notes and tasks whenever they change, NULL until something has happened. Detail lives in the same columns as tasks: waiting_on, next_steps, key_details, tags, notes (dated lines, no headers); scope in instructions_scope_details; funding, contract and PO numbers in key_details. department from the lead worker; contractor_name from the outside organization; location_1/location_2 = the place.
NEVER Never list the tasks in the summary, never write placeholder text, never write section headers into notes.', '{"table": "work_orders"}'::jsonb, '{"summary": "2-4 sentences, rewritten", "detail_columns": ["waiting_on", "next_steps", "key_details", "tags", "notes", "instructions_scope_details"]}'::jsonb),
('People and organizations', 'routing', 1, 'WHEN Every sender, recipient and named person.
DO Organization: a staff domain (settings.staff_domains, beverlyschools.org) → the single internal organization ''City of Beverly''; a known domain → that organization; a generic provider (gmail, yahoo, outlook, hotmail, comcast, verizon, aol, icloud, live) → none (a resident unless the signature says otherwise); otherwise the signature''s company or agency, fuzzy-matched at 0.6, else created with its domain (organizations are cheap; work orders are not). Learn a domain when you link a person to an organization. Person: upsert on email_address with COALESCE for names, phone, title, department, organization_id; City domain → person_type ''employee'' with an OpenGov department name; engineering or professional-services firm → ''consultant''; contractor or supplier → ''vendor''; elected or appointed → ''official''; else ''other''. first_seen_at and last_contact_at = the email''s received_at, contact_count + 1. Write email_people (sender, to, cc). tasks.organization_id and work_orders.organization_id/contractor_name name the OUTSIDE party only.
NEVER Never create ''DPS'', a division or the Schools as an organization; never downgrade an existing employee; never set the City as a task''s organization.', '{"tables": ["people", "organizations", "email_people"]}'::jsonb, '{"org_type_hints": {"epa|fema|usace": "federal_agency", "town of|city of": "municipality", "massdep|massdot|mass.gov": "state_agency", "construction|paving|contract": "contractor", "water|gas|electric|national grid": "utility", "engineering|consult|associates|tech": "consultant"}}'::jsonb),
('Who the work is assigned to', 'routing', 2, 'WHEN Setting tasks.labor_ids or work_orders.lead_worker_id.
DO Only people with a staff domain can be labor or lead worker; the person clearly responsible goes first (addressed directly, named as responsible, or replied with a commitment). When nobody is named, match the work to the roles table (keywords and summary: a gate valve is Water Maintenance, a street tree is Forestry, a catch basin is Infrastructure, a vehicle is Fleet) and then people.role_id: exactly one holder → assign; several → the Crew Leader, or the Superintendent for decisions, budget and contractor coordination; none on file → leave labor empty, set the department, flag ''No one on file holds <role>''. Department: the database fills tasks.department from the lead''s department, then the role, then the text (trigger tasks_department_guard; tune settings.department_signals, not the task); set it yourself only when the email names the department outright.
NEVER Never assign a person whose role does not cover the work, never assign the EOS mailboxes (settings.system_mailboxes) as labor, lead, owner or attendee — ''EOS will …'' means labor empty and a review flag. An empty labor list with the right department is a good outcome.', '{"signals": ["addressed directly in To", "named as responsible", "replied with a commitment"]}'::jsonb, '{"fallback": "roles.keywords → people.role_id", "department": "trigger tasks_department_guard"}'::jsonb),
('OpenGov vocabulary and the data dictionary', 'governance', 1, 'WHEN Writing any field.
DO settings.opengov_picklists holds the only allowed values: tasks.status Planned | In Progress | Completed | Canceled | Projected; work_orders.status Planned | In Progress | Completed | Canceled; priority None | Low | Medium | High | Important (default None; ''urgent'', ''ASAP'', ''emergency'' = Important); work_type, trade, department, progress_status / progress_phase, project_type, project_category as listed; tasks.activity an OpenGov Activity name (non_asset_activities for office work). If no value fits, leave NULL and flag. data_dictionary says what belongs in each table and what does not; file where what_belongs matches. Reference information with no home (rosters, fee schedules, inventories, policies) is mentioned in one line of the run summary, not forced into a task or note.
NEVER Never invent a picklist value, never write a lowercase or legacy status, never stretch a table to hold what its what_does_not excludes.', '{"source_of_truth": "OpenGov EAM", "lookup": "settings.opengov_picklists"}'::jsonb, '{"on_no_fit": "NULL + review flag"}'::jsonb),
('Every date is the date it happened, never the date the ingest ran', 'governance', 2, 'WHEN Any date or timestamp written to any record.
DO Dates are calendar dates in America/New_York of the moment the source describes. The SOURCE DATE is emails.received_at (each reply its own), the time a notepad update was typed, or documents.doc_date when a document''s text carries its own date (minutes dated the meeting day). Relative words resolve against the source date: today = that day; yesterday / tomorrow = ±1; a weekday name = the next occurrence after the source date (the source date itself only with ''today''); ''next week'' = the Monday of the following week, written as ''Week of''; ''end of month'' = its last day; a date without a year = the source year unless that is more than 60 days past, then the next year. FIELDS. tasks.entry_date and work_orders.entry_date = the source date of the first source (the trigger sets it from source_email_ids). start_date = a PLANNED start (''will start'', ''scheduled for'', ''starting Monday''); start_date_actual = the EARLIEST reported actual start (''is grading today'', ''started''); stop_date = a PLANNED finish (''through Friday'', ''wrapping up by the 30th''); stop_date_actual = the reported finish of the WHOLE task; due_date = an explicitly stated deadline only (''by October 15'', ''due 10/15'', ''needs to be done by Friday'', a regulatory or billing deadline). A dated next step inside a task is a next_steps line ''<YYYY-MM-DD or Week of YYYY-MM-DD>: <step>''. A date about a work order''s work (''reclamation starts Monday on Wilson and Sargent'') goes on EACH named street''s work order (start_date when NULL or later) and on that work order''s task for the activity, creating ''<Street> <Activity>'' (Planned, start_date set) when there is none. notes.created_at = the source date (the trigger enforces the email''s date; set doc_date yourself for notes from a dated document). documents.doc_date = the date printed on the document, else the source date for an attachment, NULL for an undated import. people.last_contact_at = the source date. RECORD every date written in key_details as ''<Start|Started|Finish|Finished|Due|Next step>: <YYYY-MM-DD> — <source phrase> (<sender>, <M/D>)''. When a later source moves a date, change the column and say so in the Activity note (''Start moved from 10/19 to 10/26 — rained out'').
NEVER Never write the run''s own date into a record (processed_at and ingest_runs are the only processing-time stamps). Never derive due_date from a start date, an event, a meeting or vague timing (''soon'', ''ASAP'', ''next week''). Never move start_date_actual later. Never invent a date: no date in the source means the column is left alone.', '{"applies_to": "every date column on tasks, work_orders, notes, documents, people"}'::jsonb, '{"source_date": "emails.received_at | notepad received_at | documents.doc_date when dated", "map": {"planned_start": "start_date", "actual_start": "start_date_actual (earliest)", "planned_finish": "stop_date", "actual_finish": "stop_date_actual (whole task)", "deadline": "due_date (explicit only)", "dated_step": "next_steps line"}, "record_in": "key_details"}'::jsonb),
('Status moves with its date and its person', 'governance', 3, 'WHEN A source reports that work is planned, started, finished or dropped.
DO A new task is Planned; In Progress when the source says work is under way (start_date_actual = the reported date, else the source date); Completed when the whole task is reported done (stop_date_actual = the reported date, else the source date; completed_by = the staff sender who reported it or the labor person named as having done it). Planned → In Progress when a start is reported; → Completed when the whole task is done; a finished STEP (''curbing went in yesterday'' on a sidewalk-and-curbing task) is an Activity note and a key_details line, not a completion. Canceled when the source says the work is dropped, with the reason in the note; stop_date_actual stays NULL. ''On hold'' or ''waiting'' is not a status: keep the status, set waiting_on, note it. Work orders: the ingest may move Planned → In Progress when a task under it starts (set work_orders.start_date when NULL) and sets status_changed_by to the staff sender; Completed and Canceled on a work order are decisions for a person — note and flag instead.
NEVER Never move a status backwards from an email (Completed → In Progress): add the note and flag ''Contradiction''. Never guess completed_by. Never mark a task Completed without stop_date_actual.', '{"tables": ["tasks", "work_orders"]}'::jsonb, '{"new": "Planned", "started": "In Progress + start_date_actual", "done": "Completed + stop_date_actual + completed_by", "dropped": "Canceled, reason in note", "work_order_close": "person decides"}'::jsonb),
('What a later source may change on an existing record', 'governance', 4, 'WHEN Updating a task or work order that already exists.
DO KEEP FIRST (set once, changed only by a staff correction or by hand): title, instructions, requested_by_id, context, entry_date, organization_id, work order or project links once a person set them. REPLACE WITH THE LATEST (the newest source states the current fact; the old value is in the change log and the Activity note): status, priority, due_date, start_date, stop_date, stop_date_actual, waiting_on (cleared when the source says the blocker is gone), summary. EARLIEST WINS: start_date_actual. MAINTAIN: next_steps is the live list — add steps the source names, remove steps it reports done; labor_ids — add the person a source names as responsible, remove only on a correction; key_details, tags, aliases, source_email_ids, notes — append, never rewrite. Hand edits in the app always win: the database keeps the person''s value, logs the attempt (record_changes ingest_blocked), adds a note and flags the task — do not retry or work around it. Field changes are logged by trigger (ingest_update); never write record_changes rows yourself.
NEVER Never rewrite a column to drop what a person wrote; never write action ''update'' to record_changes (that locks the field as a hand edit).', '{"tables": ["tasks", "work_orders"]}'::jsonb, '{"keep_first": ["title", "instructions", "requested_by_id", "context", "entry_date", "organization_id"], "latest": ["status", "priority", "due_date", "start_date", "stop_date", "stop_date_actual", "waiting_on", "summary"], "earliest": ["start_date_actual"], "maintain": ["next_steps", "labor_ids"], "append": ["key_details", "tags", "aliases", "source_email_ids", "notes"]}'::jsonb),
('Flag for review only when something is really unclear', 'governance', 5, 'WHEN Deciding whether a task needs a person.
DO Set review_status = ''open'', append one short reason to review_reasons and set review_flagged_at (COALESCE with the existing) only for: COMPOUND (two independent actions you could not separate); OWNER UNCLEAR (DPS must act but no one is clearly responsible, or the lead was inferred from a CC); WORK ORDER UNCERTAIN (linked inside the review band, or two fit equally); POSSIBLE DUPLICATE (0.5 to threshold, or a shared token with different wording, not merged); DATE OR AMOUNT INFERRED; CONTRADICTION with the task''s current state; NO ACTIVITY FITS. Everything a person must decide appears in v_review_queue (the Review tab and badge read only that view). Target: well under 20% of new tasks.
NEVER Never flag a task because it is standalone, has no work order, or is short.', '{"field": "tasks.review_status", "target_rate": "under 20% of new tasks"}'::jsonb, '{"view": "v_review_queue"}'::jsonb),
('Nothing is lost: pending and failed mail comes back, and processed means a trace exists', 'governance', 6, 'WHEN Phase 1, and closing each email.
DO Besides mail after the cutoff, pick up every emails row left pending, processing or failed (a mishandled email would otherwise never be looked at again, because the cutoff is MAX(received_at)). An email may be marked processed only when it produced a task, a note or a document, or processing_notes says in one sentence why not (''acknowledgement only'', ''duplicate of the earlier message in this thread''). A reply on a thread that already has a task is not nothing: it is an Activity note. Use ''skipped'' with a reason when it is genuinely nothing. Mark an email or document processed only after all its child rows are written.
NEVER Never mark an email processed with empty processing_notes and no child rows; that is the one failure that loses work silently.', '{"checked_by": "v_ingest_exceptions (email_left_no_trace, email_failed)"}'::jsonb, '{"requeue": "processing_status in (pending, processing, failed)"}'::jsonb),
('The document record: title, category, department, date, location', 'governance', 7, 'WHEN A documents row is created from an attachment or its text is processed.
DO title (display only, never renames the file): the document''s own heading, else built from the email (what it is + who or what + a distinguishing number or date: ''Hydro pay app #4, Apr–May 2026 — meter installation''), else the cleaned filename; 40–80 characters, Title Case, no extension, identifying numbers kept, siblings on one email distinguishable. document_category: exactly one name from settings.document_categories (a trigger folds synonyms; unknown → Other; Health Department documents use that department''s entries). department: the city department it belongs to, when clear, using the task/people department names. doc_date: per the date rule. description: one or two sentences. location_text: the street, intersection or named site the document concerns, only when it is plain, with location_source ''document'' — the database copies the task''s or work order''s location when the document has none, and the eos-geocode-documents job places anything with a location_text on the map every five minutes. work_order_id, task_id and organization_id are inherited from the source email by trigger; set them by hand only when the automatic link is wrong. Set text_processed_at only when all of this is done.
NEVER Never call the geocoder yourself, never invent coordinates, never give a city-wide program, an invoice, a catalogue or a standard a location, never leave a document untitled that you processed.', '{"table": "documents"}'::jsonb, '{"fields": ["title", "document_category", "department", "doc_date", "description", "location_text"], "geocoding": "database job"}'::jsonb),
('Every real attachment becomes a documents row', 'governance', 8, 'WHEN Each run, and whenever an email has attachments.
DO The Document Filer normally files attachments before the ingest sees the email. Check v_documents_missing (has_attachments and no row): insert the row yourself from what the email says — filename, title from context, source_email_id, location_status ''referenced_only'' — so the Filer can add the Drive fields later. An inline image or .ics is not a document: say so in processing_notes and the row clears. Documents uploaded in the app wait for the Filer (location_status in_storage until in_drive); fields the uploader typed are kept by the database.
NEVER Never leave an email with a real attachment and no documents row.', '{"check_view": "v_documents_missing"}'::jsonb, '{"insert_with": "location_status = referenced_only"}'::jsonb),
('The text of an attached document is a source', 'governance', 9, 'WHEN documents with extracted_text and no text_processed_at (Phase 2½, oldest first, settings.ingest.document_batch per run).
DO Give it a title first if it has none, then treat the text as the body of its source email from the same sender: single- or multi-topic, tasks, notes, people, work orders, with source_email_ids = [the document''s source_email_id] so links form, and the document''s own date as the source date when it carries one. Minutes are multi-topic. If the document is the minutes of a meeting in meetings (same title and date), set meetings.minutes = COALESCE(minutes, <concise summary>). Then text_processed_at = now(); on failure leave it NULL and name the document in the run summary.
NEVER Never process a document''s text as a correction email, never apply its tasks to the email''s pinned work order when the document is multi-topic.', '{"source": "documents where extracted_text is not null and text_processed_at is null and source_email_id is not null"}'::jsonb, '{"treat_as": "email body", "on_done": "text_processed_at = now()"}'::jsonb),
('Imported documents are read as images and never make work', 'governance', 10, 'WHEN documents with source_email_id NULL, drive_file_id set and text_processed_at NULL (Phase 2¾, settings.import_reader.batch_per_run per run, oldest first).
DO Download the file, render up to max_pages_per_doc pages at render_dpi (images as they are; office and text files use the stored text) and LOOK at every page: sheet title, street labels, cross streets, house numbers, owners, manhole, hydrant and valve ids, pipe sizes, dates, neighborhoods. extracted_text = ''[Read from image <date>]'' + a clean transcription grouped by panel (keep stored text that is already clean). location_text as precise as the page allows (''<number> <street>'', ''<street> between <cross> and <cross>'', ''<street> & <street>'', a landmark), location_source ''drawing'', clearing latitude/longitude/geocoded_at when the location changed. Then title, description, document_category, department (settings.drive_import_folder.department_hints, else the title block when clear), doc_date (printed on the sheet), text_processed_at = now(). Finish each document, including its UPDATE, before the next; work in a scratch folder and delete the files when done; report the count and the backlog in the summary.
NEVER Never create tasks or notes from an import, never guess characters you cannot read, never call the geocoder; a file that cannot be read keeps text_processed_at NULL and is named in the summary.', '{"settings": "import_reader"}'::jsonb, '{"phase": "2¾"}'::jsonb),
('Names follow settings.naming_conventions', 'governance', 11, 'WHEN Creating or renaming a document, report, meeting, work order or task.
DO Documents are ''YYYY-MM-DD - <Subject> - <Type>'' (the date is doc_date). Reports are ''<Audience> <Cadence> <Kind>''. Meetings are ''<Group> <Cadence> Meeting''. Work orders are named plainly for the work. Tasks follow the title and instructions rule. When renaming, keep the old name in aliases.
NEVER Never rename a file in Drive; never prefix a task with the work order''s name.', '{"read_setting": "naming_conventions"}'::jsonb, '{"preserve_old_name_in": "aliases"}'::jsonb),
('What the database already does, so the ingest does not', 'governance', 12, 'WHEN Every write.
DO Triggers handle: hand-edit protection and the ingest change log (record_changes ingest_update / ingest_blocked); task titles over 90 characters (overflow to notes); tasks.department; entry_date from the first source email; notes.created_at from the source email; completed_by and stop_date_actual floors on completion, start_date_actual on In Progress; documents'' links, location and category normalization; document geocoding (job every five minutes); the EOS mailboxes never being assigned; calendar matching (eos_sync_calendar_staged). Use the helper functions instead of ad-hoc SQL: eos_ingest_begin(), eos_ingest_settings(), eos_task_candidates(), eos_wo_candidates(), eos_person_by_email(), eos_task_ref(), merge_task_into(), eos_sync_calendar_staged().
NEVER Never write to settings, rules, data_dictionary, view_defs or record_changes; never write to OpenGov; never create people, organizations, emails, tasks, work orders, documents or meetings twice.', '{"applies_to": "all"}'::jsonb, '{"helpers": ["eos_ingest_begin", "eos_ingest_settings", "eos_task_candidates", "eos_wo_candidates", "eos_person_by_email", "eos_task_ref", "merge_task_into", "eos_sync_calendar_staged"]}'::jsonb);
-- RULES END

-- ───────────────────────────── 2. settings ─────────────────────────────
delete from public.settings where key like '\_cal\_ev\_%' or key = '_cal_sync_temp';

update public.settings set value = '"None"'::jsonb,
  description = 'OpenGov priority a new task gets when the source gives none (None | Low | Medium | High | Important).'
where key = 'default_task_priority';

insert into public.settings (key, value, description) values
('ingest', '{"run_lock_minutes": 45, "stale_run_minutes": 180, "document_batch": 20, "calendar_days_back": 7, "calendar_days_ahead": 60, "quiet_run_note": "nothing new"}'::jsonb,
 'Knobs for the EOS: Ingestor and EOS: Reader scheduled tasks. run_lock_minutes: a second run of the same kind inside this window exits at once. stale_run_minutes: a run still open after this long is closed as failed by the next one. document_batch: attachments whose text is read per Reader run (imports use import_reader.batch_per_run). calendar_days_back/ahead: the window handed to eos_sync_calendar_staged().')
on conflict (key) do update set value = excluded.value, description = excluded.description;

update public.settings set description = 'Senders whose emails about EOS records are corrections (rule "Staff emails that correct EOS are instructions, not work"). A bare domain means every address at it.'
where key = 'review_correction_senders';

-- ───────────────────────────── 3. helpers ─────────────────────────────
alter table public.ingest_runs add column if not exists kind text not null default 'mail';

-- Open a run, or refuse one. Closes runs of the same kind that never finished.
create or replace function public.eos_ingest_begin(p_kind text default 'mail')
returns jsonb language plpgsql security definer set search_path = public as $$
declare cfg jsonb; lock_min int; stale_min int; lookback int; running record; rid uuid; cut timestamptz; out jsonb;
begin
  select value into cfg from settings where key = 'ingest';
  lock_min  := coalesce((cfg->>'run_lock_minutes')::int, 45);
  stale_min := coalesce((cfg->>'stale_run_minutes')::int, 180);
  select coalesce((value#>>'{}')::int, 48) into lookback from settings where key = 'lookback_hours_if_empty';

  update ingest_runs set status = 'failed', finished_at = now(),
         error = coalesce(error, 'never closed; marked stale by the next run after ' || stale_min || ' min')
   where kind = p_kind and finished_at is null and started_at < now() - make_interval(mins => stale_min);

  select id, started_at into running from ingest_runs
   where kind = p_kind and finished_at is null and started_at >= now() - make_interval(mins => lock_min)
   order by started_at desc limit 1;
  if running.id is not null then
    return jsonb_build_object('ok', false, 'reason', 'a ' || p_kind || ' run started ' || to_char(running.started_at at time zone 'America/New_York', 'HH24:MI') || ' is still open', 'run_id', running.id);
  end if;

  insert into ingest_runs (kind) values (p_kind) returning id into rid;
  select max(received_at) into cut from emails where id not like 'notepad-%';
  cut := coalesce(cut, now() - make_interval(hours => lookback));
  update ingest_runs set cutoff_used = cut where id = rid;

  out := jsonb_build_object('ok', true, 'run_id', rid, 'kind', p_kind,
    'cutoff', cut, 'cutoff_gmail', to_char(cut at time zone 'America/New_York', 'YYYY/MM/DD'),
    'pending_emails', (select count(*) from emails where id not like 'notepad-%' and processing_status in ('pending','processing','failed')),
    'notepad_pending', (select count(*) from emails where id like 'notepad-%' and processing_status = 'pending'),
    'attachments_missing', (select count(*) from v_documents_missing),
    'document_text_pending', (select count(*) from documents where extracted_text is not null and text_processed_at is null and source_email_id is not null),
    'imports_pending', (select count(*) from documents where source_email_id is null and drive_file_id is not null and text_processed_at is null));
  return out;
end $$;

-- Only the settings the ingest reads. Everything else in settings (forms, deployment log, layouts…) stays out of the run.
create or replace function public.eos_ingest_settings()
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_object_agg(key, value) from settings
   where key in ('ingest','lookback_hours_if_empty','max_threads_per_run','body_max_chars','dedup_lookback_days',
                 'task_similarity_threshold','work_order_match_threshold','work_order_review_band_low','work_order_min_signals',
                 'auto_create_work_orders','default_task_priority','review_correction_senders','staff_domains','system_mailboxes',
                 'review_mailbox','person_types','id_format','import_reader','naming_conventions','opengov_picklists',
                 'document_text_types','drive_import_folder')
$$;

create or replace function public.eos_ingest_document_categories()
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_agg(jsonb_build_object('name', e->>'name', 'covers', e->>'covers', 'department', e->>'department'))
    from settings, jsonb_array_elements(value->'list') e where key = 'document_categories'
$$;

create extension if not exists pg_trgm;

-- Identity tokens the dedup rules care about, pulled from free text.
create or replace function public.eos_identity_tokens(p_text text)
returns text[] language sql immutable as $$
  select coalesce(array_agg(distinct lower(m[1])), '{}') from (
    select m from regexp_matches(coalesce(p_text,''),
      '(PO\s?#?\s?\d{2}-\d{3,}|PO\s?#?\s?\d{4,}|\$\s?[\d,]{4,}(?:\.\d\d)?|\d{1,5}\s+[A-Z][a-z]+(?:\s+[A-Z][a-z]+)?\s+(?:St|Street|Rd|Road|Ave|Avenue|Dr|Drive|Ln|Lane|Way|Ct|Court|Pl|Place|Ter|Terrace)\y|SFID\s?\d+|QU-\d+|Q\d{2}\.\d{3}|Contract\s?#?\s?\d{2}-\d{3}|CO\s?#?\s?\d+|WRAP|RAP grant|MS4|LCR|Lead and Copper)',
      'gi') m) s
$$;

-- Open tasks that may be the same work as p_text: shared identity tokens first, then trigram similarity.
create or replace function public.eos_task_candidates(p_text text, p_days int default 90, p_limit int default 8)
returns table (id uuid, task_number int, ref text, title text, instructions text, status text, work_order_id uuid, score numeric, shared_tokens text[])
language sql stable security definer set search_path = public as $$
  with toks as (select eos_identity_tokens(p_text) t),
  cand as (
    select t.id, t.task_number, eos_task_ref(t.task_number) as ref, t.title, t.instructions, t.status, t.work_order_id,
           round(greatest(word_similarity(coalesce(t.title,''), p_text), word_similarity(coalesce(t.instructions,''), p_text),
                          similarity(coalesce(t.title,'') || ' ' || coalesce(t.instructions,''), p_text))::numeric, 3) as score,
           (select coalesce(array_agg(x), '{}') from unnest((select t from toks)) x
             where lower(concat_ws(' ', t.title, t.instructions, t.key_details, t.context, t.notes)) like '%' || x || '%') as shared_tokens
      from tasks t
     where t.status not in ('Completed','Canceled')
       and t.entry_date > now() - make_interval(days => p_days))
  select * from cand
   where cardinality(shared_tokens) > 0 or score >= 0.3
   order by cardinality(shared_tokens) desc, score desc
   limit p_limit
$$;

-- Open work orders that p_text may belong to: alias or name contained in the text, a shared street, then similarity.
create or replace function public.eos_wo_candidates(p_text text, p_limit int default 8)
returns table (id uuid, work_order_number int, project_name text, aliases text[], status text, project_id uuid, score numeric, reason text)
language sql stable security definer set search_path = public as $$
  with t as (select lower(coalesce(p_text,'')) x),
  cand as (
    select w.id, w.work_order_number, w.project_name, w.aliases, w.status, w.project_id,
      case
        when exists (select 1 from unnest(coalesce(w.aliases,'{}') || array[w.project_name]) a where length(a) >= 4 and (select x from t) like '%' || lower(a) || '%') then 1.0
        when nullif(w.location_1,'') is not null and (select x from t) like '%' || lower(regexp_replace(w.location_1, '\s+(St|Street|Rd|Road|Ave|Avenue)\.?$', '', 'i')) || '%' then 0.85
        else round(greatest(word_similarity(coalesce(w.project_name,''), p_text), similarity(coalesce(w.project_name,''), p_text))::numeric, 3)
      end as score,
      case
        when exists (select 1 from unnest(coalesce(w.aliases,'{}') || array[w.project_name]) a where length(a) >= 4 and (select x from t) like '%' || lower(a) || '%') then 'name or alias in text'
        when nullif(w.location_1,'') is not null and (select x from t) like '%' || lower(regexp_replace(w.location_1, '\s+(St|Street|Rd|Road|Ave|Avenue)\.?$', '', 'i')) || '%' then 'same street'
        else 'similar name'
      end as reason
    from work_orders w where w.status not in ('Completed','Canceled'))
  select * from cand where score >= 0.25 order by score desc limit p_limit
$$;

-- Calendar: the ingest stages the events it fetched, the database matches them. No more temp rows in settings.
create table if not exists public.calendar_sync_staging (
  run_id uuid not null, event jsonb not null, added_at timestamptz not null default now());
create index if not exists calendar_sync_staging_run on public.calendar_sync_staging (run_id);

create or replace function public.eos_sync_calendar_staged(p_run uuid, p_from timestamptz, p_to timestamptz)
returns jsonb language plpgsql security definer set search_path = public as $$
declare evs jsonb; res jsonb; n int;
begin
  select jsonb_agg(event order by added_at), count(*) into evs, n from calendar_sync_staging where run_id = p_run;
  if coalesce(n, 0) = 0 then
    return jsonb_build_object('skipped', true, 'reason', 'no events staged for this run; nothing was changed');
  end if;
  res := eos_sync_calendar(evs, p_from, p_to);
  delete from calendar_sync_staging where run_id = p_run or added_at < now() - interval '2 days';
  return res || jsonb_build_object('staged', n);
end $$;

-- ───────────────────────────── 4. dates ─────────────────────────────
-- entry_date is when the request existed, not when the ingest ran: the earliest received_at of the source emails.
create or replace function public.eos_entry_date_from_source()
returns trigger language plpgsql security definer set search_path = public as $$
declare r timestamptz;
begin
  if coalesce(current_setting('eos.via', true), '') = 'app' then return new; end if;
  if new.source_email_ids is null or cardinality(new.source_email_ids) = 0 then return new; end if;
  select min(received_at) into r from emails where id = any(new.source_email_ids);
  if r is not null and r < coalesce(new.entry_date, now()) then new.entry_date := r; end if;
  return new;
end $$;
drop trigger if exists aa_entry_date_from_source on public.tasks;
create trigger aa_entry_date_from_source before insert on public.tasks
  for each row execute function public.eos_entry_date_from_source();
drop trigger if exists aa_entry_date_from_source on public.work_orders;
create trigger aa_entry_date_from_source before insert on public.work_orders
  for each row execute function public.eos_entry_date_from_source();

-- In Progress always carries an actual start (the ingest writes the reported date first; this is the floor).
create or replace function public.task_track_started()
returns trigger language plpgsql set search_path = public as $$
begin
  if new.status = 'In Progress' and (tg_op = 'INSERT' or old.status is distinct from 'In Progress') and new.start_date_actual is null then
    new.start_date_actual := (now() at time zone 'America/New_York')::date;
  end if;
  return new;
end $$;
drop trigger if exists trg_task_started on public.tasks;
create trigger trg_task_started before insert or update of status on public.tasks
  for each row execute function public.task_track_started();

-- ───────────────────────────── 5. review queue ─────────────────────────────
-- Imports the geocoder has already given up on are a landmarks job, not a review item every night.
update public.view_defs set base_sql = $v$ SELECT id,
    COALESCE(title, filename) AS label,
    location_text,
    location_source,
    created_at
   FROM documents d
  WHERE location_text IS NOT NULL AND btrim(location_text) <> ''::text AND latitude IS NULL
    AND (source_email_id IS NOT NULL OR geocoded_at IS NULL OR created_at > now() - interval '14 days')$v$
where view_name = 'v_documents_ungeocoded';
select public.rebuild_views();

-- ───────────────────────────── 6. data dictionary ─────────────────────────────
update public.data_dictionary set
  what_belongs = 'One concrete action per row. title = Title Case label (<=60); instructions = the one-line directive, verb first (<=90, OpenGov has no title); detail in its own columns: requested_by_id, context, next_steps, waiting_on, key_details, tags, notes (dated lines, no headers); repair_notes = field outcome. activity must be an OpenGov Activity; status/priority/work_type/trade/progress_status/department from settings.opengov_picklists. labor_ids[] = staff assigned (first = lead). asset = "Non-Asset" unless a specific asset is named. Dates: entry_date = when the request existed (first source email); start_date / stop_date planned; start_date_actual / stop_date_actual reported; due_date only an explicitly stated deadline. EOS-only: task_number, source_email_ids[], organization_id, project_id, review_status/reasons/resolution.',
  what_does_not = 'Multi-step initiatives (work_orders). Projects (projects). Reference data with no home. Section headers inside notes. A date the source did not give.'
where table_name = 'tasks';

update public.data_dictionary set
  what_belongs = 'One rule per row: WHEN it applies, DO what, NEVER what — the policy the ingest follows. rule_type groups them; priority orders them within a type. conditions/actions hold the same thing in a machine-readable shape. The full set with the reasoning is docs/INGEST.md in the repository.',
  what_does_not = 'Procedure (that is the scheduled task''s prompt), thresholds and toggles (settings), one-off instructions. A rule nobody could violate is not a rule.'
where table_name = 'rules';

update public.data_dictionary set
  what_belongs = 'Numbers, switches and lists the app and the ingest read. The ingest loads only what eos_ingest_settings() returns.',
  what_does_not = 'Logic (rules). Temporary data of any kind: the ingest never writes here.'
where table_name = 'settings';

update public.data_dictionary set
  what_belongs = 'Assets EOS keeps itself (types in settings.asset_hierarchy marked as kept in EOS: iPads, printers, vehicles, facility parts) with their attributes in assets.attributes. Spatial asset types are ArcGIS layers read live from the map; nothing is copied.',
  what_does_not = 'Anything an ArcGIS layer is the record for. GIS layers that are not assets.'
where table_name = 'assets';

update public.data_dictionary set
  what_belongs = 'One row per Gmail message: headers, body, processing status, and the work order it was pinned to. Notepad rows (id notepad-…) are updates typed in the app''s Add update box and are processed like mail from that person.',
  what_does_not = 'Anything derived or interpreted — that goes in tasks/notes/documents'
where table_name = 'emails';

update public.data_dictionary set
  what_belongs = 'Counters and a written summary per run; kind = mail (EOS: Ingestor) or reader (EOS: Reader). eos_ingest_begin() opens a run and refuses a second one of the same kind inside settings.ingest.run_lock_minutes.',
  what_does_not = 'Per-email detail (emails.processing_notes)'
where table_name = 'ingest_runs';

commit;
