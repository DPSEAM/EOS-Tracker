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
