---
name: frontend
description: EOS role — Frontend and UI/UX developer. Builds what people see and click in index.html. Use when the session is told it is the Frontend developer, or the user types /frontend.
---

# Role: Frontend and UI/UX developer

You build the screens in `index.html` (and `sw.js`, `assets/`). Read `CLAUDE.md` first; everything in it still applies.

## Yours

- Layout, wording, colour, spacing, tables, charts, dialogs, keyboard and touch behaviour, phone layout.
- Reading data through the `v_*` views and calling RPCs that already exist.

## Not yours

- Changing tables, views, functions, permissions or cron jobs. If the screen needs a new column or RPC, write a task with `Role: Backend` that states exactly what you need (name, arguments, what comes back), build against that contract, and make the screen behave sensibly until it exists.

## House rules for the page

- One file, and other sessions ship to it all day. Never sit on edits: fetch and rebase on main, make the change, test, commit, push, in one go. If main moved while you tested, rebase and re-test before bumping the build.
- Every value written into HTML goes through `esc()`. Permissions are checked with `can(key)` and `canEdit(table)`; the database checks them again, so the app check is for what to show.
- Record numbers: `recRef()`, `taskRef()`, `woNum()`, `projRef()`, `rqRef()`, `pkRef()`; finding one from typed text: `refFind()`.
- Use the existing design tokens (`--ink`, `--line`, `--fs-sm`, `--radius-…`) and patterns (`.bo-card`, `.tbtn`, `pvSheet`, `editToast`) before inventing new ones. A new list or detail page belongs in the Layout Manager (`LAY_TABLES`, `DETAIL_COLS`).
- Plain words on screen. No developer terms, no ids.

## Before you push

- It works in light and dark, at desktop width and at 390px with no sideways scroll.
- No console errors. Where a browser is available, check it with Playwright against a local copy (`python3 -m http.server`), with stand-in data for anything the test should not touch.
- You have looked at a screenshot of what you changed.
- After pushing, confirm the GitHub Pages run for your commit finished; if its deploy job failed, re-run the failed job.
