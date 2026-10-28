# EOS — City of Beverly, Department of Public Services

EOS is the department's operating system: email-driven intake of work, tasks, work orders, projects, people, documents, budget, GIS and assets, with OpenGov EAM as the system of record.

## What is in this repository

| Path | What it is |
|---|---|
| `index.html` | **The live app.** One self-contained file served by GitHub Pages at https://dpseam.github.io/EOS-Tracker/ |
| `test/index.html` | **Staging.** The next build, served at https://dpseam.github.io/EOS-Tracker/test/ . Same sign-in, same data. Moves to `index.html` when Sam says go. |
| `db/` | Database scripts, numbered, run once each in the Supabase SQL editor in number order (all are safe to run twice). `db/functions/` holds Edge Function source. |
| `CHANGELOG.md` | Every build and what shipped in it, newest first. The GitHub Action adds an entry for each new version; edit it to add detail. |
| `PLAN.md` | What is coming: the next builds in order, what waits on a decision, the backlog by area. |
| `.github/workflows/version.yml` | Stamps a new version into `index.html` on every commit that does not carry one, and adds the changelog entry. |
| `docs/DESIGN.md` | Design notes: the reasoning behind the larger pieces and the decisions taken, so they are not reopened. |
| `CLAUDE.md` | Orientation for Claude sessions: where things are. |

## The plan and the history

`CHANGELOG.md` is the history: every build, newest first, with what shipped in it. `PLAN.md` is the plan: the next builds in order, what waits on a decision, and the backlog by area. *What's new* in the app shows both. There is no project in EOS for this; these two files are the record.

## How a build ships

1. Build against `index.html`, test, put the result at `test/index.html` with the next number in `BUILD`, push `main`, try it at the test URL with real data. Add the build's lines to `PLAN.md` or straight into `CHANGELOG.md` marked *staging*.
2. On "go": copy `test/index.html` over `index.html`, change the changelog entry from *staging* to the date, push `main`. GitHub Pages rebuilds in about a minute; anyone holding the page open sees *New version — reload*.
3. A commit of `index.html` that does not change `BUILD` (for example a file uploaded through the GitHub website) gets the next number and a changelog line from the Action automatically.

Secrets never go in this repository. The app carries only the Supabase publishable key; everything else lives in Supabase Vault, Edge Function secrets or Apps Script properties.

Supabase project: `llwqcwrkbyniffjnwxym` (EOS). Mailbox: dpseam@beverlyma.gov.
