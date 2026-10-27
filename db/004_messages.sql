-- 004 · #1306 #1014 Messages v1: direct messages and named group chats, inside EOS only (no email, no Gmail).
-- Who can read a conversation: only its members. There is no level-6 or admin override anywhere in this file.
-- Tables have row security on and no direct access for the app roles; the app reads two views (v_msg_conversations, v_msg_messages,
-- both limited to the signed-in person's own conversations) and writes only through the msg_* functions below.
-- Rules built in: edit your own message for 15 minutes; delete your own message (it shows "message deleted"); anyone with EOS access
-- can start a direct message or a group; "Discuss" on a task or work order opens a group chat with the people on the record.
-- Safe to run twice. Run after 003.
begin;
select set_config('eos.via', 'admin', true);   -- 006 guards view_defs: changes from the SQL editor must say they are an administrator

create table if not exists public.msg_conversations (
  id uuid primary key default gen_random_uuid(),
  kind text not null check (kind in ('dm','group')),
  title text,
  dm_key text unique,                                  -- 'smaller-id:larger-id' so a pair of people has exactly one direct message
  record_table text check (record_table in ('tasks','work_orders')),
  record_id uuid,
  created_by uuid references public.people(id) on delete set null,
  created_at timestamptz not null default now(),
  last_message_at timestamptz
);
create table if not exists public.msg_members (
  conversation_id uuid not null references public.msg_conversations(id) on delete cascade,
  person_id uuid not null references public.people(id) on delete cascade,
  added_at timestamptz not null default now(),
  last_read_at timestamptz not null default now(),
  primary key (conversation_id, person_id)
);
create table if not exists public.msg_messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.msg_conversations(id) on delete cascade,
  sender_id uuid references public.people(id) on delete set null,
  body text not null default '',
  created_at timestamptz not null default now(),
  edited_at timestamptz,
  deleted_at timestamptz,
  check (deleted_at is not null or (length(btrim(body)) > 0 and length(body) <= 4000))
);
create index if not exists msg_messages_conv_time on public.msg_messages (conversation_id, created_at desc);
create index if not exists msg_members_person on public.msg_members (person_id);
create index if not exists msg_conv_record on public.msg_conversations (record_table, record_id);

alter table public.msg_conversations enable row level security;
alter table public.msg_members enable row level security;
alter table public.msg_messages enable row level security;
revoke all on public.msg_conversations, public.msg_members, public.msg_messages from anon, authenticated;
grant all on public.msg_conversations, public.msg_members, public.msg_messages to service_role;   -- Data API change (Oct 30 2026): explicit grants; the app uses functions only

-- ── helpers ──
create or replace function public.msg_me() returns uuid language plpgsql stable security definer set search_path to 'public' as $$
declare me uuid := public.eos_person_id();
begin if me is null then raise exception 'Sign in with EOS access to use Messages'; end if; return me; end $$;

create or replace function public.msg_is_member(p_conv uuid, p_person uuid) returns boolean language sql stable security definer set search_path to 'public' as $$
  select exists (select 1 from public.msg_members where conversation_id = p_conv and person_id = p_person) $$;

create or replace function public.msg_eos_people(p_ids uuid[]) returns uuid[] language sql stable security definer set search_path to 'public' as $$
  select coalesce(array_agg(distinct p.id), '{}') from public.people p where p.id = any(p_ids) and p.login_enabled and not coalesce(p.inactive, false) $$;

-- ── actions the app can call ──
create or replace function public.msg_start_dm(p_person uuid) returns uuid language plpgsql security definer set search_path to 'public' as $$
declare me uuid := public.msg_me(); k text; cid uuid;
begin
  if p_person is null or p_person = me then raise exception 'Choose someone else to message'; end if;
  if cardinality(public.msg_eos_people(array[p_person])) = 0 then raise exception 'That person does not have EOS access'; end if;
  k := case when me::text < p_person::text then me::text || ':' || p_person::text else p_person::text || ':' || me::text end;
  select id into cid from public.msg_conversations where dm_key = k;
  if cid is null then
    insert into public.msg_conversations (kind, dm_key, created_by) values ('dm', k, me) returning id into cid;
    insert into public.msg_members (conversation_id, person_id) values (cid, me), (cid, p_person);
  end if;
  return cid;
end $$;

create or replace function public.msg_create_group(p_title text, p_members uuid[]) returns uuid language plpgsql security definer set search_path to 'public' as $$
declare me uuid := public.msg_me(); cid uuid; mem uuid[];
begin
  if p_title is null or btrim(p_title) = '' then raise exception 'Give the group a name'; end if;
  mem := public.msg_eos_people(coalesce(p_members, '{}') || me);
  if cardinality(mem) < 2 then raise exception 'Add at least one other person with EOS access'; end if;
  if cardinality(mem) > 50 then raise exception 'A group can have up to 50 people'; end if;
  insert into public.msg_conversations (kind, title, created_by) values ('group', left(btrim(p_title), 120), me) returning id into cid;
  insert into public.msg_members (conversation_id, person_id) select cid, unnest(mem);
  return cid;
end $$;

create or replace function public.msg_discuss(p_table text, p_id uuid) returns uuid language plpgsql security definer set search_path to 'public' as $$
declare me uuid := public.msg_me(); cid uuid; ttl text; ppl uuid[];
begin
  if p_table not in ('tasks','work_orders') then raise exception 'Discuss works on tasks and work orders'; end if;
  select c.id into cid from public.msg_conversations c join public.msg_members m on m.conversation_id = c.id and m.person_id = me
   where c.record_table = p_table and c.record_id = p_id order by c.created_at limit 1;
  if cid is not null then return cid; end if;
  if p_table = 'tasks' then
    select task_id || ' ' || coalesce(title, instructions, ''), coalesce(labor_ids, '{}') || array_remove(array[requested_by_id], null)
      into ttl, ppl from public.v_task_tracker where id = p_id;
  else
    select 'W-' || lpad(work_order_number::text, 4, '0') || ' ' || coalesce(project_name, ''), array_remove(array[lead_worker_id, owner_id], null)
      into ttl, ppl from public.v_work_orders where id = p_id;
  end if;
  if ttl is null then raise exception 'Record not found or not visible to you'; end if;
  insert into public.msg_conversations (kind, title, record_table, record_id, created_by) values ('group', left(btrim(ttl), 120), p_table, p_id, me) returning id into cid;
  insert into public.msg_members (conversation_id, person_id) select cid, unnest(public.msg_eos_people(coalesce(ppl, '{}') || me));
  return cid;
end $$;

create or replace function public.msg_send(p_conv uuid, p_body text) returns uuid language plpgsql security definer set search_path to 'public' as $$
declare me uuid := public.msg_me(); mid uuid; b text := btrim(coalesce(p_body, ''));
begin
  if not public.msg_is_member(p_conv, me) then raise exception 'You are not in this conversation'; end if;
  if b = '' then raise exception 'Type a message first'; end if;
  if length(b) > 4000 then raise exception 'Messages can be up to 4,000 characters'; end if;
  insert into public.msg_messages (conversation_id, sender_id, body) values (p_conv, me, b) returning id into mid;
  update public.msg_conversations set last_message_at = now() where id = p_conv;
  update public.msg_members set last_read_at = now() where conversation_id = p_conv and person_id = me;
  return mid;
end $$;

create or replace function public.msg_edit(p_msg uuid, p_body text) returns void language plpgsql security definer set search_path to 'public' as $$
declare me uuid := public.msg_me(); b text := btrim(coalesce(p_body, ''));
begin
  if b = '' or length(b) > 4000 then raise exception 'Messages must be 1 to 4,000 characters'; end if;
  update public.msg_messages set body = b, edited_at = now()
   where id = p_msg and sender_id = me and deleted_at is null and created_at > now() - interval '15 minutes';
  if not found then raise exception 'You can edit your own message for 15 minutes after sending it'; end if;
end $$;

create or replace function public.msg_delete(p_msg uuid) returns void language plpgsql security definer set search_path to 'public' as $$
declare me uuid := public.msg_me();
begin
  update public.msg_messages set deleted_at = now(), body = '' where id = p_msg and sender_id = me and deleted_at is null;
  if not found then raise exception 'You can delete only your own messages'; end if;
end $$;

create or replace function public.msg_mark_read(p_conv uuid) returns void language sql security definer set search_path to 'public' as $$
  update public.msg_members set last_read_at = now() where conversation_id = p_conv and person_id = public.msg_me() $$;

create or replace function public.msg_add_members(p_conv uuid, p_people uuid[]) returns void language plpgsql security definer set search_path to 'public' as $$
declare me uuid := public.msg_me(); k text; n int;
begin
  select kind into k from public.msg_conversations where id = p_conv;
  if k is distinct from 'group' or not public.msg_is_member(p_conv, me) then raise exception 'Only members can add people to a group'; end if;
  select count(*) into n from public.msg_members where conversation_id = p_conv;
  if n + cardinality(public.msg_eos_people(p_people)) > 50 then raise exception 'A group can have up to 50 people'; end if;
  insert into public.msg_members (conversation_id, person_id) select p_conv, unnest(public.msg_eos_people(p_people)) on conflict do nothing;
end $$;

create or replace function public.msg_rename(p_conv uuid, p_title text) returns void language plpgsql security definer set search_path to 'public' as $$
declare me uuid := public.msg_me();
begin
  if btrim(coalesce(p_title, '')) = '' then raise exception 'Give the group a name'; end if;
  update public.msg_conversations set title = left(btrim(p_title), 120) where id = p_conv and kind = 'group' and public.msg_is_member(p_conv, me);
  if not found then raise exception 'Only members can rename a group'; end if;
end $$;

create or replace function public.msg_leave(p_conv uuid) returns void language plpgsql security definer set search_path to 'public' as $$
declare me uuid := public.msg_me();
begin
  delete from public.msg_members where conversation_id = p_conv and person_id = me
     and exists (select 1 from public.msg_conversations where id = p_conv and kind = 'group');
  if not exists (select 1 from public.msg_members where conversation_id = p_conv) then delete from public.msg_conversations where id = p_conv; end if;
end $$;

revoke all on function public.msg_me(), public.msg_is_member(uuid, uuid), public.msg_eos_people(uuid[]) from public, anon, authenticated;
do $$ declare f text; begin
  foreach f in array array['msg_start_dm(uuid)','msg_create_group(text,uuid[])','msg_discuss(text,uuid)','msg_send(uuid,text)','msg_edit(uuid,text)','msg_delete(uuid)',
                           'msg_mark_read(uuid)','msg_add_members(uuid,uuid[])','msg_rename(uuid,text)','msg_leave(uuid)'] loop
    execute format('revoke all on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop; end $$;

-- ── the two views the app reads (registered like every EOS view; level 1 and up; each person sees only their own conversations) ──
insert into public.view_defs (view_name, base_sql, min_level, row_filter, description) values
('v_msg_conversations', $v$
 SELECT c.id, c.kind, c.title, c.record_table, c.record_id, c.created_by, c.created_at, c.last_message_at,
        (SELECT array_agg(p.id ORDER BY p.full_name) FROM msg_members m2 JOIN people p ON p.id = m2.person_id WHERE m2.conversation_id = c.id) AS member_ids,
        (SELECT array_agg(p.full_name ORDER BY p.full_name) FROM msg_members m2 JOIN people p ON p.id = m2.person_id WHERE m2.conversation_id = c.id) AS member_names,
        mm.last_read_at,
        (SELECT count(*) FROM msg_messages x WHERE x.conversation_id = c.id AND x.created_at > mm.last_read_at AND x.sender_id IS DISTINCT FROM mm.person_id AND x.deleted_at IS NULL)::int AS unread,
        CASE WHEN lm.deleted_at IS NOT NULL THEN 'message deleted' ELSE left(lm.body, 140) END AS last_body,
        lm.sender_id AS last_sender_id
   FROM msg_conversations c
   JOIN msg_members mm ON mm.conversation_id = c.id AND mm.person_id = eos_person_id()
   LEFT JOIN LATERAL (SELECT body, sender_id, deleted_at FROM msg_messages WHERE conversation_id = c.id ORDER BY created_at DESC LIMIT 1) lm ON true
$v$, 1, null, 'My conversations (members only, no admin override).'),
('v_msg_messages', $v$
 SELECT m.id, m.conversation_id, m.sender_id, p.full_name AS sender_name, CASE WHEN m.deleted_at IS NULL THEN m.body END AS body,
        m.created_at, m.edited_at, m.deleted_at, (m.sender_id = mm.person_id) AS mine
   FROM msg_messages m
   JOIN msg_members mm ON mm.conversation_id = m.conversation_id AND mm.person_id = eos_person_id()
   LEFT JOIN people p ON p.id = m.sender_id
$v$, 1, null, 'Messages in my conversations (members only, no admin override).')
on conflict (view_name) do update set base_sql = excluded.base_sql, min_level = excluded.min_level, description = excluded.description, updated_at = now();
select public.rebuild_views();
commit;
