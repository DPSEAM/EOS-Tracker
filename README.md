# EOS — City of Beverly, Department of Public Services

EOS is the department's operating system: email-driven intake of work, tasks, work orders, projects, people, documents, budget, GIS and assets, with OpenGov EAM as the system of record.

## What is in this repository

| Path | What it is |
|---|---|
| `index.html` | **The live app.** One self-contained file served by GitHub Pages at https://dpseam.github.io/EOS-Tracker/ |
| `test/index.html` | **Staging.** The next build, served at https://dpseam.github.io/EOS-Tracker/test/ . Same sign-in, same data. Moves to `index.html` when Sam says go. |
| `db/` | Database scripts, numbered, run once each in the Supabase SQL editor in number order (all are safe to run twice). `db/functions/` holds Edge Function source. |
| `CHANGELOG.md` | What each build changed, newest first. The same log lives in the database (`settings.deployment.log`) and feeds *What's new* in the app. |
| `PLAN.md` | The build plan: what is next, what is planned, what waits on a decision. The live plan is EOS Project #8. |
| `docs/DESIGN.md` | Design notes and proposals for the larger pieces (permissions, AI, GIS links, CYVL, notifications, invoices …). |
| `CLAUDE.md` | Working rules for Claude sessions. |

## How a build ships

1. Build against the live file (`index.html`), test headless, stamp the next number into `BUILD`.
2. Put it at `test/index.html` and push `main`. Try it on the test URL with real data.
3. On "go": `select eos_claim_build('<one-line note>')` in Supabase (claims the number and writes the log), copy `test/index.html` over `index.html`, update `CHANGELOG.md` and `PLAN.md`, push `main`. GitHub Pages rebuilds in about a minute; anyone holding the page open sees *New version — reload*.

Secrets never go in this repository. The app carries only the Supabase publishable key; everything else lives in Supabase Vault, Edge Function secrets or Apps Script properties.

Supabase project: `llwqcwrkbyniffjnwxym` (EOS). Mailbox: dpseam@beverlyma.gov.
