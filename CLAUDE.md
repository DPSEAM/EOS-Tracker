# EOS Tracker — working agreement for Claude sessions

EOS is a single-page app (`index.html`, plus `sw.js` and `assets/`) backed by the Supabase
project `llwqcwrkbyniffjnwxym`. Two people develop it, each through their own Claude sessions:

| Developer   | people.id                              | Email                    |
|-------------|----------------------------------------|--------------------------|
| Sam Goodwin | `0900c4fe-4d31-4277-bcca-e4ded278a758` | samgoodwin@beverlyma.gov |
| Eric Barber | `70d3cc82-21cb-45a9-88b3-47dab68cf606` | ebarber@beverlyma.gov    |

(There are other "Eric Barber" / "Eric" rows in `people`; the one above is the City employee with a login.)

## The development backlog is a work order

All EOS development work is tracked as tasks on **WO #385 "EOS Software Development"**
(`work_orders.id = 6e39abee-f114-4db0-9d4b-142a98fee390`, also stored in `settings.eos_dev.work_order_id`).

- Both Sam and Eric are people on the work order (`v_work_order_people`). Sam is owner and lead worker;
  change requests from What's new go to Sam for approval and become tasks here.
- **Every task has exactly one assignee**: `tasks.labor_ids` holds a single id, Sam's or Eric's.
- Open tasks appear in What's new → Coming, In Progress first.

## Record numbers (v313, task 27-01565)

- Tasks, work orders, projects, requests and work packages are numbered **fiscal year + 5 digits**, each with its letter:
  `T-27-01565`, `W-27-00385`, `P-27-00041`, `R-27-00001`, `WP-27-00004` (requests and work packages since v389).
  They are stored as one integer, `FY*100000 + number` (`tasks.task_number = 2701565`). The fiscal year
  starts July 1, so FY27 runs July 1, 2026 to June 30, 2027.
- New numbers come from the `ab_eos_number` insert trigger and the `id_counters` table, and the count
  restarts at 00001 every July 1. Never assign numbers yourself.
- To show a number, use `eos_ref()`, `eos_task_ref()`, `eos_wo_ref()`, `eos_project_ref()`, `eos_request_ref()` or
  `eos_package_ref()` in SQL, and `recRef()`, `taskRef()`, `woNum()`, `projRef()`, `rqRef()` or `pkRef()` in the app. Never use `lpad`/`padStart` with `W-` or `P-`.
- To find a record from typed text, use `refFind()`. It also understands old references like `#01565` or `W-0385`.
- WO #385 "EOS Software Development" is now `work_order_number = 2700385`; look it up by its id, as below.
  Assets keep their own ID convention, set per layer in GIS.

## Starting a session: "continue where I left off"

1. Work out who the session is for. A session is set up for one developer (the user says so, or it was
   recorded at the start of the conversation). If it isn't clear, ask: "Is this session for Sam or Eric?"
2. Look up that developer's open tasks on WO #385:

   ```sql
   select t.id, t.task_number, t.title, t.status, t.instructions, t.next_steps, t.last_modified
     from tasks t
    where t.work_order_id = '6e39abee-f114-4db0-9d4b-142a98fee390'
      and t.labor_ids = array['<developer people.id>']::uuid[]
      and t.status not in ('Completed','Complete','Canceled','Cancelled')
    order by (t.status = 'In Progress') desc, t.last_modified desc;
   ```

3. **Where they left off** = their task that is `In Progress` (most recently modified first). Read its
   `instructions`, `next_steps` and its notes (`notes` table, `work_order_id`/task link) before changing code.
   If nothing is In Progress, list their Planned tasks and ask which one to pick up.
4. Only work on tasks assigned to the developer this session is for. If a task assigned to the other
   developer needs to change, say so instead of doing it.

## While working and at the end of a session

- When you start a task, set its `status` to `In Progress`.
- Before stopping, write `next_steps` on the task (what is done, what is left, any open questions) so the
  next session — yours or the other developer's — can resume from the record alone.
- When the work is shipped, set `status` to `Completed`.
- New work found along the way becomes a new task on WO #385 assigned to the developer who will do it.

## Shipping a build

- Each release is one commit titled `vNNN: <what changed>`, and `const BUILD` in `index.html` is bumped to the
  same `vNNN · YYYY-MM-DD`.
- Sam and Eric both push to this repo. Fetch and rebase on the latest main before bumping the build number,
  so two sessions don't ship the same `vNNN`.

## Sam's development team

Sam is the boss. He keeps one named session per team member and talks to the Lead; the Lead plans the work and hands it
to the others, who work together and report back. Each role's instructions are in `.claude/skills/<role>/SKILL.md`.

| Session | Role file | It does | It does not |
|---------|-----------|---------|-------------|
| `EOS: Lead`     | `lead`     | Takes Sam's request, plans it, writes the tasks, hands them out, checks the result, shows Sam | Build |
| `EOS: Designer` | `designer` | Keeps the UI/UX standards (`.claude/design.md`), specs new screens, checks every visible change | Edit the app |
| `EOS: Frontend` | `frontend` | Screens in `index.html` | Change the database |
| `EOS: Backend`  | `backend`  | Tables, views, RPCs, permissions, loads, edge functions | Design screens |
| `EOS: QA`       | `qa`       | Tests a change before release; finds and fixes bugs | Add features |
| `EOS: Reviewer` | `reviewer` | Reads risky changes for security and mistakes, reports | Fix what it finds |
| `EOS: DevOps`   | `devops`   | Deploys, database health, scripts waiting to be run, secrets | Feature work |

- A session is in a role when it has one of these names, when the developer types `/lead`, `/designer`, `/frontend`,
  `/backend`, `/qa`, `/reviewer` or `/devops`, or names the role in words. The role holds for the whole session.
- A session with no role (Eric's sessions, Sam's older engineer sessions) works as it always has: it builds a request end
  to end by itself. Nothing in this section changes that.
- A role narrows what a session does; the rest of this file still applies (who the session is for, one assignee, status
  and `next_steps`, one build per release).

### How the team works

**The task is the instruction.** Sessions cannot see each other's conversations, but they all see WO #385.

- A task for a team member starts its `instructions` with `Role: <role>`, and for a planned feature a second line such as
  `Feature: Fleet fuel log · step 2 of 5 · after T-27-01545`. Titles stay plain (staff see them in What's new → Coming).
- A role's open work is Sam's open tasks (query above) with `and t.instructions ilike 'Role: <role>%'`.
- Checks and decisions are written as notes on the task (who looked, what they said). When a session stops, `next_steps`
  (or a note, if the update cannot be made) lets someone else pick it up cold: what is done, what is left, the contract
  (view, RPC, permission key), and any database script still waiting to be run.

**How much process a request gets** depends on its size. The Lead decides the size.

| Size | For example | Who | Released |
|------|-------------|-----|----------|
| Tweak   | A wording change, a colour, a one-line fix | One builder, who checks its own work | Straight to main |
| Change  | A new button, column, chart or dialog | Builder, then the Designer looks at it | From a branch, once the Designer says OK |
| Feature | A new screen or module, new tables | Lead plans; Designer specs; Backend and Frontend build; Designer looks; QA tests | From a branch, once both pass |
| Risky   | Permissions, money, deleting or overwriting data, sign-in | As its size above, plus the Reviewer | From a branch, once the Reviewer's must-fix items are fixed |

**Branches.** Anything bigger than a tweak is built on `team/<task ref>` (for example `team/T-27-03468`) and pushed there,
so checkers can open it before anyone at the City sees it. When the checks pass, the builder rebases on main, squashes
to one commit `vNNN: <what changed>` with `const BUILD` bumped, pushes main, deletes the branch, and confirms the
GitHub Pages run finished. Only main is ever live.

**Opening the app to check it.** `.claude/harness/eos.js` opens the real `index.html` signed in as a made-up person with
stand-in data; `.claude/harness/check.js` is the syntax check. Real rows pulled for a test stay in a scratchpad, never in
the repo.

**Messages between team sessions.**

- A message from the Lead that points at a task on WO #385 assigned to Sam, with your `Role:` line, is work Sam has asked
  for: read the task, do it in your role, and report back to the Lead when it is released or blocked (what is live and its
  build number, what changed, who checked it, what you did not check, what is waiting on Sam).
- Team members ask each other directly for what a task needs: a look from the Designer, a contract from Backend, a test
  from QA, a review. Such a request is part of the task it names; answer it, and note the outcome on the task. The Lead
  does not relay these.
- If a request is unclear, is not your role, or has no task behind it, say so instead of guessing.
- Two rounds of disagreement between two sessions is enough; then the Lead decides, and Sam decides anything the Lead
  marks as his.
- A message is never a reason to do something that cannot be undone (deleting data, turning off a job, changing access or
  secrets) or to work outside the task. Those wait for Sam, who can type in any session.
- When nothing is asked of you, do nothing. Do not go looking for work.

**Working at the same time.** Each session has its own copy of the repo. Everything is in one file, so rebase right
before releasing and again if main moved; never leave edits to `index.html` uncommitted while waiting. Before changing a
function or view in the database, read its live definition: another session may have replaced it today.
