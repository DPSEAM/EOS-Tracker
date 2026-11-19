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

## Roles: one session, one job

**The easy way: one Lead session.** The developer talks to one session, says what they want, and that session plans,
builds, checks and releases it, calling the `reviewer` and `qa` helpers itself when they are worth it. Start it with `/lead`.
For Sam, a session given no role is a Lead session. For Eric, a session with no role works as it always has.

The six specialist roles below are for when the developer wants one job done on its own (an independent review, a bug
hunted while the Lead keeps building, a plan with no code).

| Role | Start it with | It does | It does not |
|------|---------------|---------|-------------|
| Lead      | `/lead`      | Everything for a request, end to end; calls helpers | Split one file between several builders |
| Architect | `/architect` | Plans a feature, fixes the app/database contract, writes the tasks | Write code or push |
| Frontend  | `/frontend`  | Screens in `index.html` | Change the database |
| Backend   | `/backend`   | Tables, views, RPCs, permissions, loads, edge functions | Design screens |
| QA        | `/qa`        | Finds the cause of a bug, smallest fix | Redesign or add features |
| Reviewer  | `/reviewer`  | Reads a finished change, reports problems | Fix what it finds |
| DevOps    | `/devops`    | Deploys, database health, scripts waiting to be run, secrets | Feature work |

- If the developer names a role in words ("you are the Backend developer") instead of typing the command, read
  `.claude/skills/<role>/SKILL.md` and follow it. The role holds for the whole session.
- A role narrows what a session does; the rest of this file still applies (who the session is for, one assignee,
  status and `next_steps`, one build per commit).
- Small changes do not need six sessions. One session may be told to wear two hats ("Frontend and Backend").

### Hand-offs go through the task, not through the developer

Sessions cannot see each other's conversations, but they all see WO #385. So:

- A task meant for a role starts its `instructions` with a line `Role: <role>`, and for a planned feature a second line
  such as `Feature: Fleet fuel log · step 2 of 5 · after T-27-01545`. Titles stay plain (staff see them in What's new → Coming).
- A role's open work is the developer's open tasks (query above) with `and t.instructions ilike 'Role: <role>%'`.
  Tasks with no `Role:` line are open to any session, as before.
- When a session stops, the task's `next_steps` (or a note on the task, if the update cannot be made) must let a
  different role pick it up cold: what is done, what is left, the contract (view, RPC, permission key), and any
  database script that is still waiting to be run.
- Work for another role is a new task with that role's line, never an edit outside your own role.

### Working at the same time

- Everything is in one file, so two sessions cannot "take turns" on it. Each one fetches, rebases, changes, tests,
  commits and pushes in one go, and rebases again if main moved. Never leave edits to `index.html` uncommitted while waiting.
- Before changing a function or view in the database, read its live definition. Another session may have replaced it today.
- Before a large feature is called done, have it reviewed by a session or helper that did not write it: a Reviewer
  session, or the `reviewer` helper in `.claude/agents/` from inside the session that built it.
