-- 001 · #990 Pavement: a paving work order's status moves its street sections (v175)
-- Safe to run more than once. Forward moves only; never overrides Complete / Canceled / Deferred sections.
create or replace function public.pavement_wo_status_sync() returns trigger
language plpgsql security definer set search_path to 'public' as $$
begin
  if new.status is not distinct from old.status then return null; end if;
  if new.status = 'In Progress' then
    update pavement_work set status = 'Under construction', updated_at = now()
     where work_order_id = new.id and status in ('Candidate','Planned','Design','Utility coordination','Ready to pave');
  elsif new.status = 'Completed' then
    update pavement_work set status = 'Complete', updated_at = now()
     where work_order_id = new.id and status not in ('Complete','Canceled','Deferred');
  elsif new.status = 'Canceled' then
    update pavement_work set status = 'Canceled', updated_at = now()
     where work_order_id = new.id and status not in ('Complete','Canceled');
  end if;
  return null;
end $$;
drop trigger if exists trg_wo_pavement_sync on public.work_orders;
create trigger trg_wo_pavement_sync after update of status on public.work_orders
  for each row execute function public.pavement_wo_status_sync();
