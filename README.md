# EOS — City of Beverly, Department of Public Services

EOS is the department's operating system: email-driven intake of work, tasks, work orders, projects, people, documents, budget, GIS and assets, with OpenGov EAM as the system of record.

## What is in this repository

| Path | What it is |
|---|---|
| `index.html` | **The live app.** One self-contained file served by GitHub Pages at https://dpseam.github.io/EOS-Tracker/ |
| `test/index.html` | **Staging.** The next build, served at https://dpseam.github.io/EOS-Tracker/test/ . Same sign-in, same data. Moves to `index.html` when Sam says go. |
| `db/` | Database scripts, numbered, run once each in the Supabase SQL editor in number order (all are safe to run twice). `db/functions/` holds Edge Function source. |
| `CHANGELOG.md` | What each build changed, newest first. An export of EOS Project #8 for people outside EOS; regenerated when a build ships. |
| `docs/DESIGN.md` | Design notes: the reasoning behind the larger pieces and the decisions taken, so they are not reopened. |
| `CLAUDE.md` | Working rules for Claude sessions. |

## Where the plan and the history live

**EOS Project #8 "EOS System Development" is the only plan.** One work order per build (`v189 · Work packages`); the tasks under it are the features and fixes in that build. Open work waits in the *Backlog · <area>* work orders until it is scheduled into a build. Planned builds are work orders named `Next · …` with no number yet. *What's new* in the app reads this directly: Released = completed build work orders, Coming = the rest. GitHub holds the code and an exported changelog; nothing is planned in GitHub.

## How a build ships

1. Build against the live file (`index.html`), test headless, stamp the next number into `BUILD`. Put it at `test/index.html`, push `main`, try it on the test URL with real data. The build's work order on Project #8 is *In Progress* with its tasks.
2. On "go": in Supabase, `select eos_claim_build('<one-line note>', <work order number>, null, array[<task numbers to pull in>])`. That claims the number, names the work order `vNNN · title`, completes it with today's date and completes its tasks. Then copy `test/index.html` over `index.html`, regenerate `CHANGELOG.md`, push `main`. GitHub Pages rebuilds in about a minute; anyone holding the page open sees *New version — reload*.

Secrets never go in this repository. The app carries only the Supabase publishable key; everything else lives in Supabase Vault, Edge Function secrets or Apps Script properties.

Supabase project: `llwqcwrkbyniffjnwxym` (EOS). Mailbox: dpseam@beverlyma.gov.
