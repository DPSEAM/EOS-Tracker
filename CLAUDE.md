# EOS (Executive Operations System) – City of Beverly DPS

Single-file web app (`index.html`) on GitHub Pages, backed by Supabase project `llwqcwrkbyniffjnwxym`.

Before working, read:
- **EOS Project #8** (query it: work orders with tag `build` on project_number 8, and their tasks). It is the only plan and the only history: one work order per build, tasks = features and fixes, `Backlog · <area>` work orders hold unscheduled work, `Next · …` work orders are planned builds. Do not keep a plan in this repository.
- `docs/DESIGN.md` – design notes and decisions for the larger pieces, so a new conversation does not re-open settled questions.
- `CHANGELOG.md` – an export of Project #8 for people; regenerate it when a build ships.
- `db/` – SQL files, run in numeric order in the Supabase SQL editor (safe to run twice). `db/functions/` holds Edge Function source.

Layout: `main` is the only branch that matters. `index.html` is live; `test/index.html` is staging (https://dpseam.github.io/EOS-Tracker/test/). Build to `test/` first; copy to `index.html` only when Sam says go, and ship then with `select eos_claim_build('<note>', <work order number>, null, array[<task numbers>])`, which claims the number and completes the build's work order and tasks. While building, keep the build's work order on Project #8 current: create it (or rename a `Next · …` one), add one task per feature or fix (tag `feature` or `fix`), status In Progress while on staging. Writes go through `eos_create` / `eos_edit` from the app, or SQL Sam pastes.

Rules:
- Keep the app one file. Never put a secret in it. Base every edit on the current `index.html` in `main`.
- The database is read through `v_*` views (signed-in users only; the anon key reads nothing) and written through `eos_*` functions. Structural changes are numbered files in `db/`, each with `select set_config('eos.via','admin',true)` inside its transaction (db/006 guards view_defs). New tables need Sam's approval.
- Behaviour lives in tables (`settings`, `rules`, `data_dictionary`, `view_defs`), not in prompts or code.
- Never write to OpenGov without an approved change list.
- Test every build headless (desktop and phone widths) with no console errors before it goes to `test/`. Regenerate `CHANGELOG.md` from Project #8 when a build ships.
- Supabase MCP tool: reads work from a Claude session; any write (DDL, UPDATE, function calls that write) opens an approval prompt that times out. Give Sam the SQL to paste instead.
