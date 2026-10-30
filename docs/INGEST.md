# How the ingest works, and the rules it follows

Decided 2026-10-30. This is the one place that says what the email ingest does, what it writes where, and which date every record gets. The `rules` table holds the same rules (db/020 loads them); the two scheduled-task prompts are in `ingest-prompt-mail.md` and `ingest-prompt-reader.md`. When one of these changes, change the others.

## 1. What was wrong

Two weeks of runs (Oct 16–30), 64 rules and the prompt were read in full.

| Measure | Value |
|---|---|
| Ingestor runs | 472, of which 399 found no new mail |
| Time of a run with nothing new | 8 minutes (median) |
| Runs that never closed or died before closing | 42 |
| Settings loaded by every run | about 300,000 characters |
| of which temporary calendar rows the ingest itself had written into settings | 65,000 characters in 46 rows |
| of which field forms, the deployment log and the editor layout, none used by the ingest | 190,000 characters |
| Rules loaded by every run | 71,000 characters |
| Ingested tasks (60 days) with a start date that is just the day the ingest ran | 199 of 269 that have one |
| Tasks In Progress with no actual start date | 120 of 125 |
| Open work orders using the "Scope: / Funding:" sections one rule prescribes | 0 of 93 |

The pattern: every hour a session loaded a third of a megabyte to learn there was nothing to do, and on the hours there was mail the load was what exhausted the context. The rules had grown by accretion: four keyword rules from before the model-based ingest, two rules that set tags OpenGov does not have, three overlapping note rules, a rule whose whole content was a list of overrides to the prompt, SQL snippets that referenced a `projects` table and lowercase statuses, a "geocode every run" rule beside a "geocoding is paused" rule beside a database job that was in fact geocoding every five minutes, and a work-order rule contradicting the task rule on where detail lives. Dates had one rule for deadlines and one for schedule dates, but the prompt still said "start_date = email date", and in practice the ingest wrote the run date.

The 119 runs on October 28 were not a scheduler fault: the Drop-folder importer writes its own rows into ingest_runs every ten minutes while it files a folder.

## 2. The model

**Procedure in the prompt, policy in the rules, mechanics in the database.** The prompt says the order of phases and nothing else. The rules say when to do what and what never to do, in one fixed shape (*when / do / never*). Triggers and functions do what should never depend on a model's judgement: run locks, the cutoff, the entry date, the note date, the title length, the department, document links and categories, geocoding, hand-edit protection, the change log, calendar matching, duplicate candidates.

**Two scheduled tasks instead of one.**

- **EOS: Ingestor** (hourly, mail only). Opens a run with `eos_ingest_begin('mail')`, searches Gmail with the cutoff, and if there is nothing new and no queue, closes the run in under a minute without loading a rule. Only a run with work loads the policy, through `eos_ingest_settings()` (22 keys, about 6 KB) and the 31 rules (about 30 KB).
- **EOS: Reader** (every three hours). Reads the text of attached documents, looks at imported drawings, and stages the calendar. These are the slow phases and the ones that read images; they no longer sit in the mail run's context.

`eos_ingest_begin()` refuses a second run of the same kind inside 45 minutes and closes, as failed, any run still open after three hours, so the "never finished" rows stop accumulating and two sessions cannot process the same mail.

**The ingest never writes to settings.** The calendar goes through `calendar_sync_staging` and `eos_sync_calendar_staged()`.

**Candidates come from the database.** `eos_task_candidates(text)` returns open tasks that share an identity token (PO number, dollar amount, address, quote or contract id, grant name) or are similar by trigram; `eos_wo_candidates(text)` returns work orders whose name or alias is in the text, that share a street, or are similar. The agent decides; it no longer searches.

## 3. Dates

**Principle: every date in EOS is the date the thing happened in the world, never the date the ingest ran.** `processed_at` on emails and the `ingest_runs` timestamps are the only processing-time stamps.

**The source date** is the moment the source describes: `emails.received_at` (each reply its own), the time a notepad update was typed, or `documents.doc_date` when a document carries its own date (minutes are dated the meeting day, not the day they were emailed). Relative words resolve against the source date in America/New_York:

| The source says | It means |
|---|---|
| today | the source date |
| yesterday, tomorrow | one day either side |
| Monday, this coming Monday | the next Monday after the source date |
| next week | the Monday of the following week, written "Week of YYYY-MM-DD" |
| end of month | the last day of that month |
| 10/19 (no year) | that date in the source year, or the next year if that would be more than 60 days past |
| soon, ASAP, next week (as a deadline) | no date |

**Which field.**

| Record · field | Gets | Written by |
|---|---|---|
| tasks.entry_date, work_orders.entry_date | the earliest received_at of the source emails | trigger `aa_entry_date_from_source` (db/020) |
| tasks.start_date | a planned start: "will start", "scheduled for", "starting Monday" | ingest |
| tasks.start_date_actual | the earliest reported actual start: "is grading today", "started" | ingest; trigger floors it to today when status becomes In Progress without one |
| tasks.stop_date | a planned finish: "through Friday", "wrapping up by the 30th" | ingest |
| tasks.stop_date_actual | the reported finish of the whole task | ingest; trigger floors it to today on Completed |
| tasks.due_date | an explicitly stated deadline only | ingest |
| tasks.next_steps line | a dated step inside a task: "2026-10-23: sidewalk pour" | ingest |
| work_orders.start_date | the planned start of work on that street or job, when NULL or later than the new date | ingest |
| notes.created_at | the source date | trigger `aa_note_event_date` (email date); ingest sets doc_date for notes from a dated document |
| documents.doc_date | the date printed on the document; else the source date for an attachment; NULL for an undated import | ingest / Reader |
| people.first_seen_at, last_contact_at | the source date | ingest |
| meetings.scheduled_at, ends_at | the calendar event | eos_sync_calendar |
| tasks.last_modified, work_orders.last_modified, *.updated_at, status_changed_at, review_flagged_at | when the row changed (system facts) | triggers |

Every date the ingest writes is also recorded in key_details as `<Start|Started|Finish|Finished|Due|Next step>: <YYYY-MM-DD> — <source phrase> (<sender>, <M/D>)`, so a person can see where it came from. When a later source moves a date, the column changes and the Activity note says so ("Start moved from 10/19 to 10/26 — rained out").

**Status moves with its date and its person.** New tasks are Planned. In Progress needs start_date_actual; Completed needs stop_date_actual and completed_by (the staff sender who reported it, or the labor person named as having done it); a finished step inside a bigger task is a note and a key_details line, not a completion. "On hold" is not a status: waiting_on is. The ingest never moves a status backwards and never closes a work order; those are decisions for a person.

**No date in the source means the column is left alone.** The old habit of putting the run date in start_date is what made 199 start dates meaningless. Those rows can be cleaned once (section 8).

## 4. What is written where

The contract for the fields the ingest touches. *Mode* says what a later source may do to a value that is already there.

**Tasks**

| Field | From | Mode |
|---|---|---|
| title | Title Case noun phrase of what it is about, ≤60 chars, no verb, no numbers or dates | keep first |
| instructions | the directive, verb first, ≤90 chars (trigger splits longer text into notes) | keep first |
| requested_by_id | the person who asked, by name or email, when known | keep first |
| context | what this is and why it matters, one short paragraph | keep first |
| next_steps | one step per line, dated when the source dates it | maintain: add named steps, remove steps reported done |
| waiting_on | "Name — what" | latest; cleared when the blocker is reported gone |
| key_details | reference facts one per line: Amount, PO, Address, Contact, Case, links, every date with its source phrase | append |
| tags | short lowercase words | append |
| notes | everything else word for word, as dated lines, no headers | append |
| status, priority | OpenGov values; priority None unless the source says urgent, ASAP, emergency (Important) | latest |
| work_type, trade, activity, progress_status, asset | OpenGov values; NULL and a flag when nothing fits; asset "Non-Asset" unless one is named | keep first |
| department | the lead's department, then the role, then the text (trigger); set by hand only when the email names it | keep first |
| labor_ids | staff clearly responsible, lead first; roles table when nobody is named; empty is valid | maintain: add a named person, remove only on a correction |
| work_order_id, project_id | the matching order in rule "Match a work order…"; NULL is valid | fill when empty; a person's link is never changed by mail |
| organization_id | the outside party involved, never the City | keep first |
| source_email_ids | every source that touched the task | append |
| review_status, review_reasons, review_flagged_at | only for the seven reasons in rule "Flag for review…" | append reasons |
| completed_by | who reported or did the work, never guessed | set on completion |

**Work orders**: project_name (plain name, old names to aliases), description (one line), summary (2–4 sentences rewritten whenever a task or note changes; NULL until something happened), aliases (append every wording that matched), status (Planned → In Progress when a task starts; Completed and Canceled only by a person), start_date / stop_date, lead_worker_id, owner_id, department, contractor_name, location_1 / location_2, project_id, waiting_on / next_steps / key_details / tags / notes with the same modes as tasks, instructions_scope_details for scope, status_changed_by. The "Scope: / Funding & contract: / Milestones:" sections of the old rule are retired; no work order used them.

**Notes**: content (1–4 sentences of substance), task_id or work_order_id (the topic's own record; standalone only when there is none), source_email_id, author_id (the sender's people.id), created_at (the source date). Notes from a document end with "(from <filename>)".

**Documents**: title, description, document_category (one fixed name; the trigger folds synonyms), department (when clear), doc_date, location_text and location_source (only when plain; the database copies the task's or work order's place otherwise and geocodes every five minutes), work_order_id / task_id / organization_id (inherited by trigger from the source email; set by hand only when wrong), text_processed_at (only when all of the above is done). Never: drive_url, drive_file_id, storage_path, location_status, extracted_text, or a title already set.

**Emails**: work_order_id (single-topic sources only), processing_status, processing_notes (one line, always, when nothing was created), processed_at.

**People and organizations**: see rule "People and organizations". Dates from the email, person types from settings.person_types, one internal organization.

**Never written by the ingest**: settings, rules, data_dictionary, view_defs, record_changes (the trigger logs every ingest change as `ingest_update`; a hand edit that blocks one is logged as `ingest_blocked`), anything in OpenGov.

## 5. Scenarios

What each kind of source becomes. The rules decide the details; this is the map.

| Source | Becomes |
|---|---|
| A request or report about one job (resident, vendor, colleague) | work order matched once and pinned; one task per independent action; one note; attachments as documents |
| A reply on a thread that already produced a task | an Activity note on that task; stated status, dates, owner or blocker applied; the email id appended; no new task |
| Subject "00071 Update" (the Update button), or a notepad entry "Regarding task #00071" | the same, on that task; never flagged for being short |
| A daily, weekly or field update; meeting notes or minutes; a to-do list | multi-topic: no pin; each topic matched on its own words; one task per action; one note per topic; every dated statement written to the date columns of the task and work order it concerns |
| Minutes attached to an email | the Reader processes the text with doc_date as the source date; attendees and decisions on the meetings row when one exists |
| An invoice, pay application or quote | a document with its number and date in the title, a note on the matched work order or task with the amount; a task only when the email asks someone to act (approve, pay, decide). Invoice records themselves are the invoice module's job (plan item "Invoices from email"). |
| A correction from staff ("00071 is two tasks", "X is not a City employee") | applied to the records, a note on each, nothing created from the email itself |
| A weather bulletin, an auto-reply, bulk mail | stored and skipped with a reason |
| "EOS map:" from the Map tab | a gis_maps row |
| A roster, fee schedule, policy or other reference with no home | one line in the run summary |
| A forwarded email re-sending an earlier attachment | the existing document linked; no second row |
| A file dropped in the import folder | a document read as images by the Reader: transcription, title, category, department, location, date; never a task |
| A calendar invitation to the mailbox | a meetings row via the calendar sync, not via mail |

## 6. The rules

Thirty-one rules replace sixty-four. Each is loaded by every run that has work, in this order.

### Skip

**1. Skip auto-replies and bounces**  
*When* The subject or sender shows an automatic response: auto-reply, out of office, automatic reply, do not reply, noreply, undeliverable, delivery status.  
*Do* Store the email (2a) and close it as skipped with processing_notes 'auto-reply'.
  
*Never* Never create a task, note or document from one.

**2. Skip newsletters and bulk mail**  
*When* The message carries a List-Unsubscribe header, or the subject reads as a newsletter, digest or roundup, and nothing in it asks the City to act.  
*Do* Store it and close it as skipped with processing_notes 'bulk mail'.
  
*Never* Never skip a vendor or agency message that asks for a decision, a payment or a reply just because it is formatted like a mailing.

**3. Weather bulletins are reference, not work**  
*When* The sender is Precision Weather Forecasting (snowandice.com): storm warnings, daily forecasts, certified weather statements.  
*Do* Store the email with its full body (the Home weather gadget reads v_weather_bulletins) and close it as skipped with processing_notes 'weather bulletin'.
  
*Never* Never create tasks or notes from a bulletin. An invoice, contract or renewal from the same sender is business mail and is processed normally.

**4. Inline images and signature logos are not documents**  
*When* An image attachment is a signature logo, social icon or Outlook/Word temp image: names like image001.png, ~WRD0001.jpg, a long run of digits, outlook*.png; referenced by cid: in the body; sitting in or below the signature.  
*Do* Write nothing to documents and add 'inline image skipped: <filename>' to emails.processing_notes so v_documents_missing clears.
  
*Never* Never drop a photo, scan or marked-up screenshot the sender attached on purpose. When unsure whether an image is content, keep it.


### Classify

**5. Decide single-topic or multi-topic before anything else**  
*When* Every source: an email body, a notepad update, or the text of an attached document.  
*Do* Single-topic (one street, one project, one request): match the work order once and pin it on emails.work_order_id; tasks, notes and documents inherit it. Multi-topic (meeting notes, minutes, daily or weekly updates, digests, mass or field updates, to-do lists, anything whose items concern different streets, projects or people): leave emails.work_order_id NULL and match each task, note and document on its own words. After writing the tasks, if they landed on more than one work order the source was multi-topic: clear emails.work_order_id (v_pinning_conflicts lists any left behind).
  
*Never* Never let one task's work order bleed onto its neighbours.

**6. One action per task; title, instructions and the detail columns**  
*When* A source asks for, reports on, or decides something that someone has to do.  
*Do* Each independent action is its own task (a to-do list, agenda or minutes is several tasks). title = a Title Case noun phrase of what it is about, 60 characters or fewer, no verb, no dates, amounts or PO numbers ("Procore Annual Invoice Payment"). instructions = the one-line directive, verb first, 90 characters maximum, named from its context ("Inspect and free water gate valves on Arbella St"); the trigger tasks_title_guard cuts anything longer. Detail goes in its own column, never as headers inside notes: requested_by_id (people.id of who asked), context (what this is and why, one short paragraph), next_steps (one per line, dated when the source dates them), waiting_on ("Name — what"), key_details (reference facts one per line: Amount, PO, Address, Contact, Case, links, and every date written with its source phrase), tags (short lowercase text[]), notes (everything else word for word, dated lines "YYYY-MM-DD: …"). Picklist fields take OpenGov values only (rule 'OpenGov vocabulary and the data dictionary'); asset = 'Non-Asset' unless a specific asset is named; organization_id = the outside party involved, NULL for internal work.
  
*Never* Never pack several actions into one task, never put a date, amount or PO number in the title, never write section headers into notes.

**7. Every source leaves notes: one per topic, and one for every update**  
*When* Any non-skipped source with real content: status, decisions, amounts, dates, commitments, names, places.  
*Do* Write one note per topic, 1–4 sentences of substance (who said what, figures, dates), attached to the task that topic produced, else the work order it matches, else standalone. Every update to an existing task or work order (a thread reply, a '<number> Update', a line in a daily update, a correction) also inserts a notes row on that record saying what changed ("Status moved to In Progress; start 10/26") — the Activity timeline is built only from notes, so a column change alone is invisible. notes.source_email_id = the email, author_id = the sender's people.id, created_at = when it was said (rule 'Every date is the date it happened'). Notes made from a document's text end with "(from <filename>)".
  
*Never* Never write one summary note for a multi-topic source, never carry one topic's sentences into another topic's note, never repeat the task title as the note.

**8. Staff emails that correct EOS are instructions, not work**  
*When* A sender in settings.review_correction_senders (or a level 4–6 login) writes about EOS records: 'EOS review', 'EOS correction', instructions naming task numbers (00071; 0071 and 71 mean the same task), or statements about people ('X is not a City employee', 'X is with <company>', 'X left', '<mailbox> is monitored by …').  
*Do* Task corrections: SPLIT (keep the original for the first action, insert the second copying work order, source emails and organization); REASSIGN (labor_ids, lead first); RELINK (work_order_id by number, name or alias, or NULL); MERGE (merge_task_into(newer, older)); STATUS or DUE (OpenGov values; dates per the date rules); 'fine' or 'correct as is' (no change); 'should be a note' (note on the work order, task Canceled). Every task touched gets a note 'Corrected per <sender> review email <date>: <instruction>', review_status = 'resolved', review_resolution = one line. Directory corrections: set people.organization_id / person_type / department / inactive as stated; create a missing outside organization; a shared mailbox is person_type 'other' with a note on who monitors it; every change gets a people.notes line '<correction> (<sender>, <date>)'. A person with opengov_labor_id is in OpenGov's Labor list: add the note and list them in processing_notes for Sam instead of changing them. Close the email processed with processing_notes 'corrections applied: N' (plus any 'who is X?' names and rule-change requests, which are never turned into tasks).
  
*Never* Never create tasks or notes from the correction itself beyond those above; never delete a person; never treat a request to change how the ingest behaves as a task.

**9. 'EOS map:' emails save a map, nothing else**  
*When* The subject starts with 'EOS map:' and the body is the JSON object the Map tab sends (layer_names, style_overrides, basemap, center_lat, center_lng, zoom, optional description).  
*Do* Upsert gis_maps by name (map name = subject after the prefix). min_level and created_by_level = the sender's people.visibility_level, 6 when they have none. Drop layer_names not present in gis_layers and say so in the run summary. Mark the email processed with processing_notes 'map <name> saved'.
  
*Never* Never create a task, note, work order or document from one.


### Link to existing work

**10. An update to existing work goes to the existing record**  
*When* Before creating any task, in this order.  
*Do* 1. Subject '<task number> Update' (any of '00071 Update', '71 - update', 'Task 00071 — Update'): a note on that task, never a new one; status or dates only when the body states them; append to next_steps or waiting_on only when the body gives a new one; processing_notes 'update applied to task <number>'. No such task: process the email normally and say so in the summary. 2. A notepad entry beginning 'Regarding task #…', 'work order W-…' or 'project #…' names its record: treat it the same way. 3. Same Gmail thread, or the same normalized subject (Fwd:/Re:/FW: stripped) as a source email of an open task within settings.dedup_lookback_days: update that task. 4. SELECT * FROM eos_task_candidates(<title and body>, dedup_lookback_days): rows with shared identity tokens (PO, quote/SFID/contract number, street address, dollar amount, grant name) are the same task; rows with similarity ≥ settings.task_similarity_threshold are the same task; 0.5 to threshold is a possible duplicate — link only if the text plainly agrees, otherwise create and flag 'Possible duplicate of <number>'. On every link: append the email id to source_email_ids, write the Activity note, apply any stated status, dates, owner or blocker (date rules), and set work_order_id if the task had none and this source resolved one. Count it in tasks_linked.
  
*Never* Never create a second task for the same PO number, address, quote or grant. Never flag a one-sentence update for review just because it is short.


### Deduplicate

**11. A person can have several email addresses**  
*When* Resolving a sender or a named person.  
*Do* SELECT eos_person_by_email('<address>') checks email_address and other_emails ignoring case. The upsert INSERT … ON CONFLICT (email_address) DO UPDATE is safe: the database routes an address in other_emails to that person's main row. If two Directory rows are plainly the same person, say so in the run summary for Sam.
  
*Never* Never create a second person for an address already in other_emails; never merge people yourself.

**12. Documents are upserted, never duplicated**  
*When* Recording an attachment.  
*Do* One documents row per (source_email_id, filename): INSERT … ON CONFLICT (source_email_id, filename) DO UPDATE filling blanks only (description, work_order_id, task_id, organization_id with COALESCE). The Document Filer may already have created the row with Drive fields. A re-sent file on a forward or reply: if a document with the same filename exists from an earlier email in the thread or on the same record, link that one instead of creating a second and mention the resend in the note. Only attachments actually on this message get a row; files merely described in quoted text do not.
  
*Never* Never overwrite drive_url, drive_file_id, storage_path, location_status, extracted_text or a title that is already set.


### Work orders and projects

**13. Match a work order in a fixed order; none is a valid answer**  
*When* A single-topic source, or each task of a multi-topic source.  
*Do* 1. Thread: an earlier email in the same Gmail thread pinned to a work order. 2. Exact: opengov_id ('26-0034'), project_name, or an alias contained in the subject or first 500 characters. 3. Identity: a PO number, address, quote or contract id, or grant name that appears in a work order's description, aliases or its tasks. 4. Candidates: SELECT * FROM eos_wo_candidates(<text>) — link above settings.work_order_match_threshold; between work_order_review_band_low and the threshold read both descriptions and decide, flagging 'Work order uncertain' if you link; below, no match. Same street, facility, park or equipment means the same work order even when the wording differs. 5. Standing program: routine field work (a gate valve, a pothole, a street tree) belongs on the standing program work order that plainly covers it — only when the fit is obvious; an administrative task, a grant, a purchase or an IT request has no field work order. 6. Otherwise work_order_id NULL. When you link under a new wording, add it to work_orders.aliases so the next email matches at step 2.
  
*Never* Never force a work order: a wrong link is worse than none. Never put anything on 'EOS System Development' except work on the EOS system itself (database, ingest, configuration, data quality).

**14. Paving work is tracked by street**  
*When* An email or task concerns paving, reclaiming, sidewalks, berm, curbing, or water work ahead of paving.  
*Do* Match the street first: work orders are named '<year> Paving - <Street>' and carry the street in aliases, so 'Lincoln Street', 'Lincoln St' and 'Lincoln St neighborhood' all resolve to the same one. One action covering two streets goes on the first street with a note naming the other and a review flag so a person decides whether to split. The programme work order ('2026 Paving Program') is only for items that span the programme: a status roundup, a mayor paving meeting, the paving budget.
  
*Never* Never file a single street on the programme; never create a street work order yourself — say in the run summary that the street has none.

**15. Create a new work order only with enough signals**  
*When* No work order matched and settings.auto_create_work_orders is true.  
*Do* Create one only when the source shows at least settings.work_order_min_signals of: a named initiative, a specific location or asset, multi-step scope, several parties, a timeline or milestone. Seed aliases from the subject. Otherwise the task stands alone with work_order_id NULL.
  
*Never* Never create a work order for a one-off action, and never a project (rule 'Projects sit above work orders').

**16. Projects sit above work orders; tasks below**  
*When* Filing anything that belongs to an initiative.  
*Do* PROJECT (projects, kind Project or Program) is the why: goal, funding, contract, milestones, an end date for a Project, none for a Program. WORK ORDER is a specific job at a place or asset, under a project via project_id or standing alone. TASK is one action by one person inside a work order; coordination or admin actions for a project sit on the project via tasks.project_id with no work order. Match the project first (name, aliases, opengov_project_name, contractor, contract or PO number), then a work order inside it; a new work order for an existing project gets project_id. project_type, project_category and phase take OpenGov values (a trigger rejects anything else); milestones are {name, target, done}.
  
*Never* Never create a project from an email: a distinct initiative with its own goal plus funding, a contract, a schedule or several work orders is a decision for a person — say so in the run summary.

**17. Keep each work order's record current**  
*When* A task or note on a work order is created or changed.  
*Do* project_name = a short plain name for the work (no prefixes; an old name goes to aliases); description = one line of scope; summary = 2–4 plain sentences for someone who has not been following it: what the work is, where it stands, what is next, who is waiting on whom, with the date or amount that matters — rewritten from the notes and tasks whenever they change, NULL until something has happened. Detail lives in the same columns as tasks: waiting_on, next_steps, key_details, tags, notes (dated lines, no headers); scope in instructions_scope_details; funding, contract and PO numbers in key_details. department from the lead worker; contractor_name from the outside organization; location_1/location_2 = the place.
  
*Never* Never list the tasks in the summary, never write placeholder text, never write section headers into notes.


### People and routing

**18. People and organizations**  
*When* Every sender, recipient and named person.  
*Do* Organization: a staff domain (settings.staff_domains, beverlyschools.org) → the single internal organization 'City of Beverly'; a known domain → that organization; a generic provider (gmail, yahoo, outlook, hotmail, comcast, verizon, aol, icloud, live) → none (a resident unless the signature says otherwise); otherwise the signature's company or agency, fuzzy-matched at 0.6, else created with its domain (organizations are cheap; work orders are not). Learn a domain when you link a person to an organization. Person: upsert on email_address with COALESCE for names, phone, title, department, organization_id; City domain → person_type 'employee' with an OpenGov department name; engineering or professional-services firm → 'consultant'; contractor or supplier → 'vendor'; elected or appointed → 'official'; else 'other'. first_seen_at and last_contact_at = the email's received_at, contact_count + 1. Write email_people (sender, to, cc). tasks.organization_id and work_orders.organization_id/contractor_name name the OUTSIDE party only.
  
*Never* Never create 'DPS', a division or the Schools as an organization; never downgrade an existing employee; never set the City as a task's organization.

**19. Who the work is assigned to**  
*When* Setting tasks.labor_ids or work_orders.lead_worker_id.  
*Do* Only people with a staff domain can be labor or lead worker; the person clearly responsible goes first (addressed directly, named as responsible, or replied with a commitment). When nobody is named, match the work to the roles table (keywords and summary: a gate valve is Water Maintenance, a street tree is Forestry, a catch basin is Infrastructure, a vehicle is Fleet) and then people.role_id: exactly one holder → assign; several → the Crew Leader, or the Superintendent for decisions, budget and contractor coordination; none on file → leave labor empty, set the department, flag 'No one on file holds <role>'. Department: the database fills tasks.department from the lead's department, then the role, then the text (trigger tasks_department_guard; tune settings.department_signals, not the task); set it yourself only when the email names the department outright.
  
*Never* Never assign a person whose role does not cover the work, never assign the EOS mailboxes (settings.system_mailboxes) as labor, lead, owner or attendee — 'EOS will …' means labor empty and a review flag. An empty labor list with the right department is a good outcome.


### Governance

**20. OpenGov vocabulary and the data dictionary**  
*When* Writing any field.  
*Do* settings.opengov_picklists holds the only allowed values: tasks.status Planned | In Progress | Completed | Canceled | Projected; work_orders.status Planned | In Progress | Completed | Canceled; priority None | Low | Medium | High | Important (default None; 'urgent', 'ASAP', 'emergency' = Important); work_type, trade, department, progress_status / progress_phase, project_type, project_category as listed; tasks.activity an OpenGov Activity name (non_asset_activities for office work). If no value fits, leave NULL and flag. data_dictionary says what belongs in each table and what does not; file where what_belongs matches. Reference information with no home (rosters, fee schedules, inventories, policies) is mentioned in one line of the run summary, not forced into a task or note.
  
*Never* Never invent a picklist value, never write a lowercase or legacy status, never stretch a table to hold what its what_does_not excludes.

**21. Every date is the date it happened, never the date the ingest ran**  
*When* Any date or timestamp written to any record.  
*Do* Dates are calendar dates in America/New_York of the moment the source describes. The SOURCE DATE is emails.received_at (each reply its own), the time a notepad update was typed, or documents.doc_date when a document's text carries its own date (minutes dated the meeting day). Relative words resolve against the source date: today = that day; yesterday / tomorrow = ±1; a weekday name = the next occurrence after the source date (the source date itself only with 'today'); 'next week' = the Monday of the following week, written as 'Week of'; 'end of month' = its last day; a date without a year = the source year unless that is more than 60 days past, then the next year. FIELDS. tasks.entry_date and work_orders.entry_date = the source date of the first source (the trigger sets it from source_email_ids). start_date = a PLANNED start ('will start', 'scheduled for', 'starting Monday'); start_date_actual = the EARLIEST reported actual start ('is grading today', 'started'); stop_date = a PLANNED finish ('through Friday', 'wrapping up by the 30th'); stop_date_actual = the reported finish of the WHOLE task; due_date = an explicitly stated deadline only ('by October 15', 'due 10/15', 'needs to be done by Friday', a regulatory or billing deadline). A dated next step inside a task is a next_steps line '<YYYY-MM-DD or Week of YYYY-MM-DD>: <step>'. A date about a work order's work ('reclamation starts Monday on Wilson and Sargent') goes on EACH named street's work order (start_date when NULL or later) and on that work order's task for the activity, creating '<Street> <Activity>' (Planned, start_date set) when there is none. notes.created_at = the source date (the trigger enforces the email's date; set doc_date yourself for notes from a dated document). documents.doc_date = the date printed on the document, else the source date for an attachment, NULL for an undated import. people.last_contact_at = the source date. RECORD every date written in key_details as '<Start|Started|Finish|Finished|Due|Next step>: <YYYY-MM-DD> — <source phrase> (<sender>, <M/D>)'. When a later source moves a date, change the column and say so in the Activity note ('Start moved from 10/19 to 10/26 — rained out').
  
*Never* Never write the run's own date into a record (processed_at and ingest_runs are the only processing-time stamps). Never derive due_date from a start date, an event, a meeting or vague timing ('soon', 'ASAP', 'next week'). Never move start_date_actual later. Never invent a date: no date in the source means the column is left alone.

**22. Status moves with its date and its person**  
*When* A source reports that work is planned, started, finished or dropped.  
*Do* A new task is Planned; In Progress when the source says work is under way (start_date_actual = the reported date, else the source date); Completed when the whole task is reported done (stop_date_actual = the reported date, else the source date; completed_by = the staff sender who reported it or the labor person named as having done it). Planned → In Progress when a start is reported; → Completed when the whole task is done; a finished STEP ('curbing went in yesterday' on a sidewalk-and-curbing task) is an Activity note and a key_details line, not a completion. Canceled when the source says the work is dropped, with the reason in the note; stop_date_actual stays NULL. 'On hold' or 'waiting' is not a status: keep the status, set waiting_on, note it. Work orders: the ingest may move Planned → In Progress when a task under it starts (set work_orders.start_date when NULL) and sets status_changed_by to the staff sender; Completed and Canceled on a work order are decisions for a person — note and flag instead.
  
*Never* Never move a status backwards from an email (Completed → In Progress): add the note and flag 'Contradiction'. Never guess completed_by. Never mark a task Completed without stop_date_actual.

**23. What a later source may change on an existing record**  
*When* Updating a task or work order that already exists.  
*Do* KEEP FIRST (set once, changed only by a staff correction or by hand): title, instructions, requested_by_id, context, entry_date, organization_id, work order or project links once a person set them. REPLACE WITH THE LATEST (the newest source states the current fact; the old value is in the change log and the Activity note): status, priority, due_date, start_date, stop_date, stop_date_actual, waiting_on (cleared when the source says the blocker is gone), summary. EARLIEST WINS: start_date_actual. MAINTAIN: next_steps is the live list — add steps the source names, remove steps it reports done; labor_ids — add the person a source names as responsible, remove only on a correction; key_details, tags, aliases, source_email_ids, notes — append, never rewrite. Hand edits in the app always win: the database keeps the person's value, logs the attempt (record_changes ingest_blocked), adds a note and flags the task — do not retry or work around it. Field changes are logged by trigger (ingest_update); never write record_changes rows yourself.
  
*Never* Never rewrite a column to drop what a person wrote; never write action 'update' to record_changes (that locks the field as a hand edit).

**24. Flag for review only when something is really unclear**  
*When* Deciding whether a task needs a person.  
*Do* Set review_status = 'open', append one short reason to review_reasons and set review_flagged_at (COALESCE with the existing) only for: COMPOUND (two independent actions you could not separate); OWNER UNCLEAR (DPS must act but no one is clearly responsible, or the lead was inferred from a CC); WORK ORDER UNCERTAIN (linked inside the review band, or two fit equally); POSSIBLE DUPLICATE (0.5 to threshold, or a shared token with different wording, not merged); DATE OR AMOUNT INFERRED; CONTRADICTION with the task's current state; NO ACTIVITY FITS. Everything a person must decide appears in v_review_queue (the Review tab and badge read only that view). Target: well under 20% of new tasks.
  
*Never* Never flag a task because it is standalone, has no work order, or is short.

**25. Nothing is lost: pending and failed mail comes back, and processed means a trace exists**  
*When* Phase 1, and closing each email.  
*Do* Besides mail after the cutoff, pick up every emails row left pending, processing or failed (a mishandled email would otherwise never be looked at again, because the cutoff is MAX(received_at)). An email may be marked processed only when it produced a task, a note or a document, or processing_notes says in one sentence why not ('acknowledgement only', 'duplicate of the earlier message in this thread'). A reply on a thread that already has a task is not nothing: it is an Activity note. Use 'skipped' with a reason when it is genuinely nothing. Mark an email or document processed only after all its child rows are written.
  
*Never* Never mark an email processed with empty processing_notes and no child rows; that is the one failure that loses work silently.

**26. The document record: title, category, department, date, location**  
*When* A documents row is created from an attachment or its text is processed.  
*Do* title (display only, never renames the file): the document's own heading, else built from the email (what it is + who or what + a distinguishing number or date: 'Hydro pay app #4, Apr–May 2026 — meter installation'), else the cleaned filename; 40–80 characters, Title Case, no extension, identifying numbers kept, siblings on one email distinguishable. document_category: exactly one name from settings.document_categories (a trigger folds synonyms; unknown → Other; Health Department documents use that department's entries). department: the city department it belongs to, when clear, using the task/people department names. doc_date: per the date rule. description: one or two sentences. location_text: the street, intersection or named site the document concerns, only when it is plain, with location_source 'document' — the database copies the task's or work order's location when the document has none, and the eos-geocode-documents job places anything with a location_text on the map every five minutes. work_order_id, task_id and organization_id are inherited from the source email by trigger; set them by hand only when the automatic link is wrong. Set text_processed_at only when all of this is done.
  
*Never* Never call the geocoder yourself, never invent coordinates, never give a city-wide program, an invoice, a catalogue or a standard a location, never leave a document untitled that you processed.

**27. Every real attachment becomes a documents row**  
*When* Each run, and whenever an email has attachments.  
*Do* The Document Filer normally files attachments before the ingest sees the email. Check v_documents_missing (has_attachments and no row): insert the row yourself from what the email says — filename, title from context, source_email_id, location_status 'referenced_only' — so the Filer can add the Drive fields later. An inline image or .ics is not a document: say so in processing_notes and the row clears. Documents uploaded in the app wait for the Filer (location_status in_storage until in_drive); fields the uploader typed are kept by the database.
  
*Never* Never leave an email with a real attachment and no documents row.

**28. The text of an attached document is a source**  
*When* documents with extracted_text and no text_processed_at (Phase 2½, oldest first, settings.ingest.document_batch per run).  
*Do* Give it a title first if it has none, then treat the text as the body of its source email from the same sender: single- or multi-topic, tasks, notes, people, work orders, with source_email_ids = [the document's source_email_id] so links form, and the document's own date as the source date when it carries one. Minutes are multi-topic. If the document is the minutes of a meeting in meetings (same title and date), set meetings.minutes = COALESCE(minutes, <concise summary>). Then text_processed_at = now(); on failure leave it NULL and name the document in the run summary.
  
*Never* Never process a document's text as a correction email, never apply its tasks to the email's pinned work order when the document is multi-topic.

**29. Imported documents are read as images and never make work**  
*When* documents with source_email_id NULL, drive_file_id set and text_processed_at NULL (Phase 2¾, settings.import_reader.batch_per_run per run, oldest first).  
*Do* Download the file, render up to max_pages_per_doc pages at render_dpi (images as they are; office and text files use the stored text) and LOOK at every page: sheet title, street labels, cross streets, house numbers, owners, manhole, hydrant and valve ids, pipe sizes, dates, neighborhoods. extracted_text = '[Read from image <date>]' + a clean transcription grouped by panel (keep stored text that is already clean). location_text as precise as the page allows ('<number> <street>', '<street> between <cross> and <cross>', '<street> & <street>', a landmark), location_source 'drawing', clearing latitude/longitude/geocoded_at when the location changed. Then title, description, document_category, department (settings.drive_import_folder.department_hints, else the title block when clear), doc_date (printed on the sheet), text_processed_at = now(). Finish each document, including its UPDATE, before the next; work in a scratch folder and delete the files when done; report the count and the backlog in the summary.
  
*Never* Never create tasks or notes from an import, never guess characters you cannot read, never call the geocoder; a file that cannot be read keeps text_processed_at NULL and is named in the summary.

**30. Names follow settings.naming_conventions**  
*When* Creating or renaming a document, report, meeting, work order or task.  
*Do* Documents are 'YYYY-MM-DD - <Subject> - <Type>' (the date is doc_date). Reports are '<Audience> <Cadence> <Kind>'. Meetings are '<Group> <Cadence> Meeting'. Work orders are named plainly for the work. Tasks follow the title and instructions rule. When renaming, keep the old name in aliases.
  
*Never* Never rename a file in Drive; never prefix a task with the work order's name.

**31. What the database already does, so the ingest does not**  
*When* Every write.  
*Do* Triggers handle: hand-edit protection and the ingest change log (record_changes ingest_update / ingest_blocked); task titles over 90 characters (overflow to notes); tasks.department; entry_date from the first source email; notes.created_at from the source email; completed_by and stop_date_actual floors on completion, start_date_actual on In Progress; documents' links, location and category normalization; document geocoding (job every five minutes); the EOS mailboxes never being assigned; calendar matching (eos_sync_calendar_staged). Use the helper functions instead of ad-hoc SQL: eos_ingest_begin(), eos_ingest_settings(), eos_task_candidates(), eos_wo_candidates(), eos_person_by_email(), eos_task_ref(), merge_task_into(), eos_sync_calendar_staged().
  
*Never* Never write to settings, rules, data_dictionary, view_defs or record_changes; never write to OpenGov; never create people, organizations, emails, tasks, work orders, documents or meetings twice.


## 7. What was removed, and why

| Old rule | Fate |
|---|---|
| Vendor invoice to task; Resident service request to task; Contract or RFP to document; Meeting notes to note | removed: keyword rules from before the model-based ingest, with lowercase priorities OpenGov rejects, "Review: {subject}" titles that break the title rule, tags that have no column, and "one note for the minutes" that the multi-topic rule forbids |
| Overrides to the scheduled-task prompt | removed: the prompt is rewritten; nothing is left to override |
| Every build handed to EOS states whether GitHub needs updating | removed: a chat-era process note, not an ingest rule |
| Geocode document locations every run | removed: the eos-geocode-documents job has done this every five minutes since October; the ingest only sets location_text |
| Follow-up on a thread updates the existing task; Deduplicate tasks across all open tasks; Subject "<number> Update"; Standalone task is acceptable | merged into "An update to existing work goes to the existing record" and the matching rule; the broken SQL (lowercase statuses, tasks.created_at, a projects table) is replaced by eos_task_candidates() |
| Inherit work order from thread; Match by alias; Match by fuzzy name; Same location means same work order; Prefer no work order over a wrong one; Link to a standing OpenGov work order; EOS System Development | merged into "Match a work order in a fixed order; none is a valid answer" (the opengov_only mirror it referred to was removed on 2026-09-16) |
| Work orders group work (fields part); Keep a running summary | merged into "Keep each work order's record current", resolving the contradiction with the task rule: detail lives in columns, scope in instructions_scope_details, no section headers |
| One note per topic; Always capture a note; Every update is an Activity note | merged into one note rule |
| Apply corrections from an EOS review email; Apply directory corrections | merged into one correction rule |
| One City organization; Resolve organization from domain; Learn a new organization; Task is grouped under the outside organization; Lead labor must be DPS staff; Use city role definitions; Every task carries a department | merged into "People and organizations" and "Who the work is assigned to" |
| Consult the data dictionary; Use OpenGov EAM vocabulary | merged |
| Pick up re-queued emails; Every processed email must leave a trace | merged |
| Set a due date only when the source states one; Write schedule dates from status updates; Record who completed a task | merged into the date rule and the status rule, extended to entry_date, doc_date, notes and people |
| Give every document a clear title; One category; Department when clear; Documents inherit links | merged into "The document record" |
| App uploads wait for the Filer | folded into "Every real attachment becomes a documents row" |
| Hand edits in the app win | folded into "What a later source may change" and "What the database already does" |
| The Review tab is v_review_queue | folded into the review-flag rule |

The old rows are kept in `rules_archive`.

## 8. Applying it

1. Run `db/020_ingest_rules.sql` in the Supabase SQL editor. It is one transaction: rules, settings, helpers, triggers, the review-queue view, the data dictionary.
2. Replace the "EOS: Ingestor" prompt with `ingest-prompt-mail.md` (below the line), and create "EOS: Reader" from `ingest-prompt-reader.md` on a three-hour schedule at 20 past the hour, with the Supabase, Google Drive and Google Calendar connectors.
3. The nightly "EOS: Security" check looks for a scheduled task named "Gmail Ingest"; point it at "EOS: Ingestor".
4. Optional clean-up of the dates the old prompt polluted, after a look at the list:

```sql
-- start dates that are just the day the ingest ran, with nothing in key_details to justify them
select eos_task_ref(task_number), title, start_date, entry_date::date
  from tasks
 where sync_status = 'eos_only' and source_email_ids is not null
   and start_date = (entry_date at time zone 'America/New_York')::date
   and coalesce(key_details,'') !~ 'Start';
-- then, if the list looks right:
-- update tasks set start_date = null where … the same where clause …;
```

## 9. Open points

- **Ungeocoded imports.** 350 imported documents carry a place name the street geocoder cannot resolve. They are a landmarks job (add the facility or neighbourhood to `landmarks` and the job places them), so db/020 stops counting them on the Review tab after 14 days. A short list of the most common unresolved names is worth doing once.
- **Invoices.** Until the invoice intake exists, an invoice email is a document and a note, and a task only when someone must act. When the intake is built it takes the invoice path before the mail rules run.
- **Weekday ambiguity.** "Monday" in an email received on a Monday means the following Monday unless the text says "today". If staff turn out to write "Monday" meaning the same day, the date rule changes, not the data.
