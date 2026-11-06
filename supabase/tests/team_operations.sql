-- Stage 9 integration coverage; run after migration 0010 and seed data.
-- psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/tests/team_operations.sql
-- The transaction is rolled back and no provider/network call is possible from SQL.
\set ON_ERROR_STOP on
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', '20000000-0000-0000-0000-000000000003', true);
select set_config('request.jwt.claims', '{"sub":"20000000-0000-0000-0000-000000000003","role":"authenticated"}', true);

do $$ declare session_id uuid; entry_id uuid; begin
  session_id := public.start_attendance(current_date, 'synthetic check-in');
  begin perform public.start_attendance(current_date, 'duplicate'); raise exception 'duplicate open attendance was accepted'; exception when unique_violation then null; end;
  perform public.stop_attendance(session_id, timezone('utc', now()) + interval '1 hour');
  perform public.create_leave_request('ANNUAL', current_date + 3, current_date + 4, 'synthetic leave');
  begin perform public.create_leave_request('PERSONAL', current_date + 4, current_date + 5, 'overlap must fail'); raise exception 'overlapping leave was accepted'; exception when others then null; end;
  entry_id := public.add_timesheet_entry(current_date, 60, 'synthetic time', null, null);
  perform public.lock_timesheet_entry(entry_id);
  begin perform public.add_timesheet_entry(current_date, -1, 'negative must fail', null, null); raise exception 'negative timesheet was accepted'; exception when others then null; end;
end $$;

select set_config('request.jwt.claim.sub', '20000000-0000-0000-0000-000000000002', true);
select set_config('request.jwt.claims', '{"sub":"20000000-0000-0000-0000-000000000002","role":"authenticated"}', true);
do $$ declare rule_id uuid; leave_id uuid; begin
  select id into leave_id from public.leave_requests where requester_profile_id = '20000000-0000-0000-0000-000000000003' and status = 'PENDING' order by created_at desc limit 1;
  perform public.decide_leave_request(leave_id, 'APPROVED', 'manager review');
  rule_id := public.create_automation_rule('Synthetic overdue preview', 'TASK_OVERDUE', '{}'::jsonb, 'MANAGER', null, 'WHATSAPP', 'QUEUE_MESSAGE_PREVIEW', 1440);
  if exists(select 1 from public.automation_rules where id = rule_id and enabled) then raise exception 'new rule was active without explicit activation'; end if;
  perform public.set_automation_rule_state(rule_id, true);
  if not exists(select 1 from public.automation_rules where id = rule_id and enabled) then raise exception 'rule activation was not persisted'; end if;
  perform public.set_automation_kill_switch(true, true);
end $$;

rollback;
