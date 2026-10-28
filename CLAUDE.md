# EOS (Executive Operations System) – City of Beverly DPS

Single-file web app (`index.html`) on GitHub Pages, backed by Supabase project `llwqcwrkbyniffjnwxym`.

Where things are:
- `CHANGELOG.md` is the history of every build; `PLAN.md` is what is coming and the backlog. `docs/DESIGN.md` holds design notes and decisions.
- `db/` holds the database scripts, numbered, run once each in the Supabase SQL editor in number order. `db/functions/` holds Edge Function source.
- `index.html` is live; `test/index.html` is staging at https://dpseam.github.io/EOS-Tracker/test/ . The version is the `BUILD` line in the file; the Action in `.github/workflows/version.yml` stamps one on any commit of `index.html` that lacks it.
