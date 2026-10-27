# EOS (Executive Operations System) – City of Beverly DPS

Single-file web app (`index.html`) on GitHub Pages, backed by Supabase project `llwqcwrkbyniffjnwxym`.

Before working, read:
- `CHANGELOG.md` – what each build did, newest first.
- `PLAN.md` – the open build plan (Project #8 in EOS), what waits on Sam, and the build rules.
- `db/` – SQL files, run in numeric order in the Supabase SQL editor (safe to run twice). `db/functions/` holds Edge Functions.

Branches: `main` is the live site and only changes when Sam says so. `test` is staging for new builds.
Never put a secret in `index.html`. Keep the app one file. Update `CHANGELOG.md` and `PLAN.md` with every build.
