# EOS — City of Beverly, Department of Public Services

EOS is the department's operating system: email-driven intake of work, tasks, work orders, projects, people, documents, budget, GIS and assets, with OpenGov EAM as the system of record.

## What is in this repository

| Path | What it is |
|---|---|
| `index.html` | **The live app.** One self-contained file served by GitHub Pages at https://dpseam.github.io/EOS-Tracker/ |
| `sw.js`, `icon-192.png`, `icon-512.png` | The service worker and icons for device notifications. |
| `db/` | Database scripts, numbered, run once each in the Supabase SQL editor in number order (all are safe to run twice). `db/functions/` holds Edge Function source. |
| `CHANGELOG.md` | Every build and what people will notice in it, newest first, in plain language. *What's new* in the app shows this file. The GitHub Action adds an entry for each new version; edit it to add detail. |
| `PLAN.md` | What is coming: the next builds in order, open questions, and everything else by area, in plain language. The *Coming* tab of *What's new* shows this file. |
| `.github/workflows/version.yml` | Stamps a new version into `index.html` on every commit that does not carry one, and adds the changelog entry. |
| `docs/DESIGN.md` | Design notes: the reasoning behind the larger pieces and the decisions taken, so they are not reopened. |
| `docs/REVIEW.md` | The whole-system review of October 30, 2026: what to consolidate, remove and standardize, in the order proposed. |
| `docs/INGEST.md` | How the email ingest works: the rule set, which date every record gets, what a later source may change, and what each kind of email becomes. |
| `docs/ingest-prompt-mail.md`, `docs/ingest-prompt-reader.md` | The two scheduled-task prompts (mail; documents and calendar), kept here so the scheduler and the repository never drift. |

## The plan and the history

`CHANGELOG.md` is the history: every build, newest first, with what shipped in it. `PLAN.md` is the plan: the next builds in order, what waits on a decision, and the backlog by area. *What's new* in the app shows both. There is no project in EOS for this; these two files are the record.

## How a build ships

1. Build and test against `index.html`, give it the next number in `BUILD`, and write the build's entry at the top of `CHANGELOG.md` in plain words that describe what people will see (no task numbers, no database or code references).
2. Push `main`. GitHub Pages rebuilds in about a minute; anyone holding the page open sees *New version — reload*.
3. A commit of `index.html` that does not change `BUILD` (for example a file uploaded through the GitHub website) gets the next number and a changelog line from the Action automatically.

Secrets never go in this repository. The app carries only the Supabase publishable key; everything else lives in Supabase Vault, Edge Function secrets or Apps Script properties.

Access: every person who signs in has one **access profile** (Viewer, Field crew, Crew leader, Supervisor, Division head, Consultant, Administrator), from their job or set on the person. The profile's grants decide what they can do; its **data tier** (Staff, Management, Executive) decides which fields and records they see. Managed in one place: System Health › Access (Users, Jobs, Access profiles).

Supabase project: `llwqcwrkbyniffjnwxym` (EOS). Mailbox: dpseam@beverlyma.gov.
