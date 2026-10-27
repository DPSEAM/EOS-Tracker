# EOS (Executive Operations System) – City of Beverly DPS

Single-file web app (`index.html`) on GitHub Pages, backed by Supabase project `llwqcwrkbyniffjnwxym`.

Before working, read:
- `CHANGELOG.md` – what each build did, newest first.
- `PLAN.md` – the open build plan (Project #8 in EOS), what waits on Sam, and the build rules.
- `docs/DESIGN.md` – design notes for the larger pieces, so a new conversation does not re-open settled questions.
- `db/` – SQL files, run in numeric order in the Supabase SQL editor (safe to run twice). `db/functions/` holds Edge Function source.

Layout: `main` is the only branch that matters. `index.html` is live; `test/index.html` is staging (https://dpseam.github.io/EOS-Tracker/test/). Build to `test/` first; copy to `index.html` only when Sam says go, and claim the number then with `select eos_claim_build('…')`.

Rules:
- Keep the app one file. Never put a secret in it. Base every edit on the current `index.html` in `main`.
- The database is read through `v_*` views (signed-in users only; the anon key reads nothing) and written through `eos_*` functions. Structural changes are numbered files in `db/`, each with `select set_config('eos.via','admin',true)` inside its transaction (db/006 guards view_defs). New tables need Sam's approval.
- Behaviour lives in tables (`settings`, `rules`, `data_dictionary`, `view_defs`), not in prompts or code.
- Never write to OpenGov without an approved change list.
- Test every build headless (desktop and phone widths) with no console errors before it goes to `test/`. Update `CHANGELOG.md` and `PLAN.md` with every build.
- Supabase MCP tool: reads work from a Claude session; any write (DDL, UPDATE, function calls that write) opens an approval prompt that times out. Give Sam the SQL to paste instead.
