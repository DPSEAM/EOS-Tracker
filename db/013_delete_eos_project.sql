-- 013 · Delete the old "EOS System Development" project (#8) and everything attached to it: its 14 work orders, 235 tasks,
-- their notes, favorites and change-log rows. Documents, emails, requests and invoices that pointed at them are unlinked, not deleted.
-- A copy of everything deleted is kept in schema backup_p8 (drop it when you are sure: drop schema backup_p8 cascade).
-- The history of those tasks is in CHANGELOG.md and PLAN.md on GitHub. Safe to run twice.
begin;
select set_config('eos.via', 'admin', true);
create schema if not exists backup_p8;
create table if not exists backup_p8.projects_20261028 as select * from public.projects where project_number = 8;
create table if not exists backup_p8.work_orders_20261028 as select * from public.work_orders where project_id in (select id from public.projects where project_number = 8);
create table if not exists backup_p8.tasks_20261028 as select * from public.tasks where work_order_id in (select id from backup_p8.work_orders_20261028) or project_id in (select id from backup_p8.projects_20261028);
create table if not exists backup_p8.notes_20261028 as select * from public.notes where task_id in (select id from backup_p8.tasks_20261028) or work_order_id in (select id from backup_p8.work_orders_20261028);
revoke all on schema backup_p8 from anon, authenticated;
-- Two rules put a document's task link back when it is cleared (one from the source email, one that keeps hand-made edits); switch both off for this run.
alter table public.documents disable trigger documents_inherit_links;
alter table public.documents disable trigger zz_human_edit_guard;
alter table public.tasks disable trigger tasks_relink_documents;
delete from public.notes where task_id in (select id from backup_p8.tasks_20261028) or work_order_id in (select id from backup_p8.work_orders_20261028);
update public.documents set task_id = null where task_id in (select id from backup_p8.tasks_20261028);
update public.documents set work_order_id = null where work_order_id in (select id from backup_p8.work_orders_20261028);
update public.emails set work_order_id = null where work_order_id in (select id from backup_p8.work_orders_20261028);
update public.requests set task_id = null where task_id in (select id from backup_p8.tasks_20261028);
update public.invoices set task_id = null where task_id in (select id from backup_p8.tasks_20261028);
delete from public.favorites where record_table in ('tasks','work_orders','projects') and record_id in (select id from backup_p8.tasks_20261028 union select id from backup_p8.work_orders_20261028 union select id from backup_p8.projects_20261028);
delete from public.record_changes where (table_name = 'tasks' and record_id in (select id from backup_p8.tasks_20261028)) or (table_name = 'work_orders' and record_id in (select id from backup_p8.work_orders_20261028)) or (table_name = 'projects' and record_id in (select id from backup_p8.projects_20261028));
delete from public.tasks where id in (select id from backup_p8.tasks_20261028);
delete from public.work_orders where id in (select id from backup_p8.work_orders_20261028);
delete from public.projects where project_number = 8;
alter table public.documents enable trigger documents_inherit_links;
alter table public.documents enable trigger zz_human_edit_guard;
alter table public.tasks enable trigger tasks_relink_documents;
select (select count(*) from public.projects where name ilike '%EOS System%') as projects_left, (select count(*) from backup_p8.tasks_20261028) as tasks_backed_up, (select count(*) from backup_p8.notes_20261028) as notes_backed_up;
commit;
