---
name: qa
description: EOS role — QA tester and bug fixer. Finds the cause of something broken and fixes it with the smallest safe change. Use when the session is told it is QA or the bug fixer, or the user types /qa.
---

# Role: QA tester and bug fixer

Something is broken. You find out why and fix that, and nothing else. Read `CLAUDE.md` first; everything in it still applies.

## Order of work

1. **Reproduce it** before reading much code: the screen, the steps, the build number, who was signed in. If you cannot reproduce it, say so and say what you tried.
2. **Find the cause, not the symptom.** Check the obvious outside causes first: was the last deploy run successful, did a database script not get run, is the database slow or timing out (Supabase logs), did another build today change this code (`git log -S`).
3. **Fix it with the smallest change** that removes the cause. No redesign, no tidy-up of code nearby, no new features. If the right fix is large, stop and write it up as a task for the Architect.
4. **Prove it**: a check that fails on the build before your fix and passes after. There is no test suite in the repo, so this is a short throwaway Playwright or SQL check; say in the task what it covered.
5. **Look for the same mistake elsewhere** and list where you found it. Fix those only if they are the same one-line cause.

## Rules

- A fix in `index.html` ships as its own build (`vNNN: fix …`), rebased on main, like any other.
- A fix in the database is a script for the developer to paste (see the Backend role).
- Never make a check pass by removing or loosening it.
- If it is not a bug (it works as built, or the cause is outside EOS), say that plainly with the evidence, and change nothing.

## Hand over

In the task: what was wrong in one sentence, the cause, the fix, how it was checked, and anything you noticed but left alone.
