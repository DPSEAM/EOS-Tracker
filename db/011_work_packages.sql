-- 011 · Work packages: bundle tasks, work orders, projects, documents, people, assets and map points and give them to one person.
-- Approved by Sam (2026-10-27, "Go ahead and add the table for work_packages"). One new table; the items live on the row as JSON.
--   Anyone with EOS access can send a package. The person it is given to accepts it, ticks items done, sends it back with a
--   question, or marks it done. The sender can cancel it. Level 6 can see every package; everyone else sees what they sent or received.
--   items: [{"t":"tasks","id":"<uuid>","label":"…","done":false,"done_at":null}]   t = tasks | work_orders | projects | documents | people | assets
--          [{"t":"point","lat":42.55,"lng":-70.88,"label":"…","done":false}]        a place on the map
-- Safe to run twice. Run after 010.
begin;
select set_config('eos.via', 'admin', true);   -- 006 guards view_defs: changes from the SQL editor must say they are an administrator

create table if not exists public.work_packages (
  id uuid primary key default gen_random_uuid(),
  package_number int generated always as identity,
  title text not null check (length(btrim(title)) between 3 and 200),
  note text check (note is null or length(note) <= 4000),
  sent_by uuid references public.people(id) on delete set null,
  assigned_to uuid not null references public.people(id) on delete cascade,
  due_date date,
  status text not null default 'sent' check (status in ('sent','accepted','returned','done','canceled')),
  response text check (response is null or length(response) <= 4000),
  items jsonb not null default '[]' check (jsonb_typeof(items) = 'array' and jsonb_array_length(items) between 1 and 200),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists work_packages_to on public.work_packages (assigned_to, status);
create index if not exists work_packages_by on public.work_packages (sent_by, created_at desc);
alter table public.work_packages enable row level security;
revoke all on public.work_packages from anon, authenticated;
grant all on public.work_packages to service_role;     -- Data API change (Oct 30 2026): explicit grants; the app uses the functions and view below

-- clean and check the item list: known kinds only, ids must be uuids, points need coordinates; done flags start false
create or replace function public.wp_clean_items(p_items jsonb) returns jsonb
language plpgsql immutable set search_path to 'public' as $$
declare it jsonb; out jsonb := '[]'; t text;
begin
  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then raise exception 'Add at least one record to the package'; end if;
  if jsonb_array_length(p_items) > 200 then raise exception 'A package can hold up to 200 items'; end if;
  for it in select * from jsonb_array_elements(p_items) loop
    t := it->>'t';
    if t in ('tasks','work_orders','projects','documents','people','assets') then
      if coalesce(it->>'id', '') !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then raise exception 'A package item has no valid record id'; end if;
      out := out || jsonb_build_object('t', t, 'id', it->>'id', 'label', left(coalesce(it->>'label', ''), 200), 'done', false, 'done_at', null);
    elsif t = 'point' then
      if (it->>'lat') is null or (it->>'lng') is null then raise exception 'A map point needs a latitude and longitude'; end if;
      out := out || jsonb_build_object('t', 'point', 'lat', (it->>'lat')::numeric, 'lng', (it->>'lng')::numeric, 'label', left(coalesce(it->>'label', ''), 200), 'done', false, 'done_at', null);
    else raise exception 'Unknown package item: %', coalesce(t, '(none)'); end if;
  end loop;
  return out;
end $$;

create or replace function public.wp_send(p_title text, p_note text, p_assigned_to uuid, p_due date, p_items jsonb) returns uuid
language plpgsql security definer set search_path to 'public' as $$
declare me uuid := public.eos_person_id(); nid uuid;
begin
  if me is null then raise exception 'Sign in with EOS access to send a work package'; end if;
  if not exists (select 1 from public.people where id = p_assigned_to and login_enabled and not coalesce(inactive, false)) then
    raise exception 'That person does not have EOS access'; end if;
  if (select count(*) from public.work_packages where sent_by = me and created_at > now() - interval '1 day') >= 50 then raise exception 'Up to 50 packages a day'; end if;
  insert into public.work_packages (title, note, sent_by, assigned_to, due_date, items)
  values (btrim(p_title), nullif(btrim(coalesce(p_note, '')), ''), me, p_assigned_to, p_due, public.wp_clean_items(p_items))
  returning id into nid;
  return nid;
end $$;

-- the receiver: accept | return (needs a note) | done ; the sender: cancel | resend (after a return, optionally with a new note)
create or replace function public.wp_act(p_id uuid, p_action text, p_note text default null) returns text
language plpgsql security definer set search_path to 'public' as $$
declare me uuid := public.eos_person_id(); w public.work_packages; n text := nullif(btrim(coalesce(p_note, '')), '');
begin
  if me is null then raise exception 'Sign in with EOS access'; end if;
  select * into w from public.work_packages where id = p_id for update;
  if not found then raise exception 'Package not found'; end if;
  if p_action in ('accept','return','done') then
    if w.assigned_to is distinct from me then raise exception 'Only the person the package was given to can do that'; end if;
    if w.status in ('done','canceled') then raise exception 'This package is already closed'; end if;
    if p_action = 'return' and n is null then raise exception 'Say what you need when sending a package back'; end if;
    update public.work_packages set status = case p_action when 'accept' then 'accepted' when 'return' then 'returned' else 'done' end,
           response = coalesce(n, response), updated_at = now() where id = p_id;
  elsif p_action in ('cancel','resend') then
    if w.sent_by is distinct from me and coalesce(public.eos_level(), 0) < 6 then raise exception 'Only the sender can do that'; end if;
    if p_action = 'resend' and w.status <> 'returned' then raise exception 'Only a returned package can be sent again'; end if;
    update public.work_packages set status = case p_action when 'cancel' then 'canceled' else 'sent' end,
           note = case when p_action = 'resend' and n is not null then n else note end, updated_at = now() where id = p_id;
  else raise exception 'Unknown action'; end if;
  return (select status from public.work_packages where id = p_id);
end $$;

-- tick or untick one item (by its position in the list, 0-based); the receiver or the sender can tick
create or replace function public.wp_item_done(p_id uuid, p_index int, p_done boolean) returns jsonb
language plpgsql security definer set search_path to 'public' as $$
declare me uuid := public.eos_person_id(); w public.work_packages;
begin
  select * into w from public.work_packages where id = p_id for update;
  if not found or me is null or (me is distinct from w.assigned_to and me is distinct from w.sent_by) then raise exception 'Package not found'; end if;
  if w.status in ('done','canceled') then raise exception 'This package is already closed'; end if;
  if p_index < 0 or p_index >= jsonb_array_length(w.items) then raise exception 'No such item'; end if;
  update public.work_packages
     set items = jsonb_set(jsonb_set(items, array[p_index::text, 'done'], to_jsonb(coalesce(p_done, false))),
                           array[p_index::text, 'done_at'], case when p_done then to_jsonb(now()) else 'null'::jsonb end),
         status = case when status = 'sent' then 'accepted' else status end, updated_at = now()
   where id = p_id;
  return (select items from public.work_packages where id = p_id);
end $$;

revoke all on function public.wp_clean_items(jsonb) from public, anon, authenticated;
revoke all on function public.wp_send(text, text, uuid, date, jsonb), public.wp_act(uuid, text, text), public.wp_item_done(uuid, int, boolean) from public, anon;
grant execute on function public.wp_send(text, text, uuid, date, jsonb), public.wp_act(uuid, text, text), public.wp_item_done(uuid, int, boolean) to authenticated;

insert into public.view_defs (view_name, base_sql, min_level, row_filter, description) values
('v_work_packages', $v$
 SELECT w.id, w.package_number, w.title, w.note, w.status, w.response, w.due_date, w.items, w.created_at, w.updated_at,
        w.sent_by, sp.full_name AS sent_by_name, w.assigned_to, ap.full_name AS assigned_to_name,
        jsonb_array_length(w.items) AS item_count,
        (SELECT count(*) FROM jsonb_array_elements(w.items) i WHERE (i->>'done')::boolean)::int AS done_count,
        (w.assigned_to = eos_person_id()) AS for_me, (w.sent_by = eos_person_id()) AS from_me
   FROM work_packages w
   LEFT JOIN people sp ON sp.id = w.sent_by
   LEFT JOIN people ap ON ap.id = w.assigned_to
  WHERE w.assigned_to = eos_person_id() OR w.sent_by = eos_person_id() OR eos_level() >= 6
$v$, 1, null, 'Work packages I sent or was given (level 6 sees all).')
on conflict (view_name) do update set base_sql = excluded.base_sql, min_level = excluded.min_level, description = excluded.description, updated_at = now();
select public.rebuild_views();
commit;
