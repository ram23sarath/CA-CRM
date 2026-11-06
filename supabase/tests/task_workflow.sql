-- Stage 5 integration coverage; run after migration 0006 and seed data.
-- psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/tests/task_workflow.sql
\set ON_ERROR_STOP on
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', '20000000-0000-0000-0000-000000000001', true);
select set_config('request.jwt.claims', '{"sub":"20000000-0000-0000-0000-000000000001","role":"authenticated"}', true);
do $$ declare task_id uuid; repeated uuid; begin
 task_id:=public.create_task_workflow('Stage 5 synthetic','40000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000003','20000000-0000-0000-0000-000000000002','MEDIUM',timezone('utc',now()),null,null);
 perform public.transition_task_workflow(task_id,(select updated_at from public.tasks where id=task_id),'IN_PROGRESS',null);
 perform public.transition_task_workflow(task_id,(select updated_at from public.tasks where id=task_id),'IN_REVIEW',null);
 perform public.transition_task_workflow(task_id,(select updated_at from public.tasks where id=task_id),'COMPLETED','Approved in integration check');
 if not exists(select 1 from public.task_history where task_id=task_id and event_type='task.review_approved') then raise exception 'review history missing'; end if;
 begin perform public.create_task_workflow('Foreign client','40000000-0000-0000-0000-000000000002',null,null,null,null,'LOW',null,null,null); raise exception 'foreign client was accepted'; exception when no_data_found then null; end;
 repeated:=public.create_recurring_task_for_period('50000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000001','2026-04-01','2026-04-30');
 if repeated is distinct from public.create_recurring_task_for_period('50000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000001','2026-04-01','2026-04-30') then raise exception 'recurrence was not idempotent'; end if;
end $$;
rollback;
