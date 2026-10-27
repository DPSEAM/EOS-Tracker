-- 008 · #1007 My Favorites: star a task, work order, project, person or document and find it again from Home.
-- Approved by Sam as part of P14: new table favorites. Each person sees only their own stars.
-- Safe to run twice. Run after 007.
begin;

create table if not exists public.favorites (
  person_id uuid not null references public.people(id) on delete cascade,
  record_table text not null check (record_table in ('tasks','work_orders','projects','people','documents')),
  record_id uuid not null,
  created_at timestamptz not null default now(),
  primary key (person_id, record_table, record_id)
);
alter table public.favorites enable row level security;
revoke all on public.favorites from anon, authenticated;
grant all on public.favorites to service_role;       -- Data API change (Oct 30 2026): explicit grants; the app uses the function and view below

-- star / un-star; returns true when the record is now a favorite
create or replace function public.fav_toggle(p_table text, p_id uuid) returns boolean
language plpgsql security definer set search_path to 'public' as $$
declare me uuid := public.eos_person_id();
begin
  if me is null then raise exception 'Sign in with EOS access to use favorites'; end if;
  if p_table not in ('tasks','work_orders','projects','people','documents') then raise exception 'That kind of record cannot be starred'; end if;
  if exists (select 1 from public.favorites where person_id = me and record_table = p_table and record_id = p_id) then
    delete from public.favorites where person_id = me and record_table = p_table and record_id = p_id;
    return false;
  end if;
  if (select count(*) from public.favorites where person_id = me) >= 200 then raise exception 'You can star up to 200 records'; end if;
  insert into public.favorites (person_id, record_table, record_id) values (me, p_table, p_id);
  return true;
end $$;
revoke all on function public.fav_toggle(text, uuid) from public, anon;
grant execute on function public.fav_toggle(text, uuid) to authenticated;

insert into public.view_defs (view_name, base_sql, min_level, row_filter, description) values
('v_my_favorites', $v$
 SELECT f.record_table, f.record_id, f.created_at FROM favorites f WHERE f.person_id = eos_person_id()
$v$, 1, null, 'My starred records (each person sees only their own).')
on conflict (view_name) do update set base_sql = excluded.base_sql, min_level = excluded.min_level, description = excluded.description, updated_at = now();
select public.rebuild_views();
commit;
