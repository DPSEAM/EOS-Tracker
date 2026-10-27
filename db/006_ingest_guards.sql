-- 006: ingest guards (P9: tasks #843 #892 #787 #122).  Run once in the Supabase SQL editor; safe to run again.
--
-- 1. people.email_verified  - false = the address was guessed (for example built from an OpenGov user name),
--    not read from a real email.  The Directory shows an "Unverified address" chip (build v182).
-- 2. eos_people_ingest_guard - email ingest cannot ADD a City employee (an address on settings.staff_domains).
--    A person already in the Directory is never blocked.  An explicit level 4 or 6 directive is passed by the
--    ingest as   select set_config('eos.directive','admin',true);   in the same call as the insert.
--    A blocked add is written to record_changes (action ingest_blocked) and the insert returns no row.
-- 3. eos_guard_structure - rules, data_dictionary and view_defs can only be changed from the app or by an
--    administrator (select set_config('eos.via','admin',true);), never by the scheduled email ingest.
-- 4. eos_note_event_date - a note created from an email takes the date the email was RECEIVED, not the ingest time.

-- 1 -------------------------------------------------------------------------------------------------------
alter table public.people add column if not exists email_verified boolean not null default true;
comment on column public.people.email_verified is 'false when the address was guessed rather than read from an email (OpenGov user name + domain)';

-- show it in the Directory view (views change only through view_defs + rebuild_views)
update public.view_defs
   set base_sql = replace(base_sql, E'    p.notes\n   FROM people p', E'    p.notes,\n    p.email_verified\n   FROM people p')
 where view_name = 'v_people_directory' and base_sql not like '%email_verified%';
select public.rebuild_views();

-- 2 -------------------------------------------------------------------------------------------------------
create or replace function public.eos_people_ingest_guard() returns trigger
language plpgsql security definer set search_path = public as $$
declare via text := coalesce(current_setting('eos.via', true), '');
        dir text := coalesce(current_setting('eos.directive', true), '');
        doms jsonb; dom text;
begin
  if via = 'app' then return new; end if;
  -- someone already in the Directory (main or other address) is an update, not an add
  if exists (select 1 from public.people p
              where lower(p.email_address) = lower(new.email_address) or lower(new.email_address) = any(p.other_emails)) then
    return new;
  end if;
  select value into doms from public.settings where key = 'staff_domains';
  dom := lower(split_part(coalesce(new.email_address, ''), '@', 2));
  if doms is null or jsonb_typeof(doms) <> 'array' or not (doms ? dom) then return new; end if;   -- not a City address
  if dir = 'admin' then
    insert into public.record_changes (table_name, record_id, field, old_value, new_value, action, source, note)
    values ('people', new.id, 'email_address', null, to_jsonb(new.email_address), 'ingest_directive', 'ingest',
            'City employee added on an explicit level 4 or 6 directive');
    return new;
  end if;
  insert into public.record_changes (table_name, record_id, field, old_value, new_value, action, source, note)
  values ('people', new.id, 'email_address', null, to_jsonb(new.email_address), 'ingest_blocked', 'ingest',
          'City employee not added: ingest needs an explicit level 4 or 6 directive');
  return null;
end $$;

drop trigger if exists ab_people_ingest_guard on public.people;
create trigger ab_people_ingest_guard before insert on public.people
  for each row execute function public.eos_people_ingest_guard();

-- 3 -------------------------------------------------------------------------------------------------------
create or replace function public.eos_guard_structure() returns trigger
language plpgsql set search_path = public as $$
begin
  if coalesce(current_setting('eos.via', true), '') in ('app', 'admin') then
    return case when tg_op = 'DELETE' then old else new end;
  end if;
  raise exception 'Rules, the data dictionary and view definitions change only from the app or by an administrator, not from email ingest (set eos.via = admin first)';
end $$;

do $$ declare t text; begin
  foreach t in array array['rules', 'data_dictionary', 'view_defs'] loop
    execute format('drop trigger if exists aa_structure_guard on public.%I', t);
    execute format('create trigger aa_structure_guard before insert or update or delete on public.%I for each row execute function public.eos_guard_structure()', t);
  end loop;
end $$;

-- 4 -------------------------------------------------------------------------------------------------------
create or replace function public.eos_note_event_date() returns trigger
language plpgsql security definer set search_path = public as $$
declare r timestamptz;
begin
  if new.source_email_id is null or coalesce(current_setting('eos.via', true), '') = 'app' then return new; end if;
  select received_at into r from public.emails where id = new.source_email_id;
  if r is not null and r < new.created_at then new.created_at := r; end if;
  return new;
end $$;

drop trigger if exists aa_note_event_date on public.notes;
create trigger aa_note_event_date before insert on public.notes
  for each row execute function public.eos_note_event_date();
