-- Stage 6 compliance calendar integration checks. Run after all migrations and seed:
-- psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/tests/compliance_calendar.sql
-- Every mutation is rolled back.
\set ON_ERROR_STOP on

begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', '20000000-0000-0000-0000-000000000001', true);
select set_config('request.jwt.claims', '{"sub":"20000000-0000-0000-0000-000000000001","role":"authenticated"}', true);

do $$
declare template_id uuid; first_period uuid; repeated_period uuid;
begin
  template_id := public.create_compliance_template('GST', 'Synthetic GST calendar', 'MONTHLY', 5, '50000000-0000-0000-0000-000000000001');
  first_period := public.generate_compliance_period(template_id, '40000000-0000-0000-0000-000000000001', '2026-04', '2026-04-01', '2026-04-30', '20000000-0000-0000-0000-000000000003', 'CONFIGURED');
  repeated_period := public.generate_compliance_period(template_id, '40000000-0000-0000-0000-000000000001', '2026-04', '2026-04-01', '2026-04-30', '20000000-0000-0000-0000-000000000003', 'IMPORTED');
  if first_period is distinct from repeated_period then raise exception 'compliance period generation was not idempotent'; end if;
  if not exists (select 1 from public.compliance_periods where id = first_period and client_id = '40000000-0000-0000-0000-000000000001' and type_code = 'GST' and due_date = '2026-05-05' and task_id is not null) then raise exception 'period did not snapshot client, due date, or Stage 5 task link'; end if;
end $$;

do $$
declare period_id uuid;
begin
  select id into period_id from public.compliance_periods where firm_id = '10000000-0000-0000-0000-000000000001' and client_id = '40000000-0000-0000-0000-000000000001' and type_code = 'GST' and period_key = '2026-04';
  begin
    perform public.update_compliance_period(period_id, 'FILED', '20000000-0000-0000-0000-000000000003', null, null, false, 'MANUAL', current_date);
    raise exception 'filing without explicit confirmation was accepted';
  exception when others then
    if position('explicit filing confirmation' in sqlerrm) = 0 then raise; end if;
  end;
  perform public.update_compliance_period(period_id, 'FILED', '20000000-0000-0000-0000-000000000003', 'SYNTHETIC-REF', null, true, 'MANUAL', current_date);
  if not exists (select 1 from public.compliance_periods where id = period_id and status = 'FILED' and filing_reference = 'SYNTHETIC-REF') then raise exception 'explicit filing update was not stored'; end if;
end $$;

do $$
begin
  begin
    perform public.generate_compliance_period((select id from public.compliance_templates where firm_id = '10000000-0000-0000-0000-000000000001' and code = 'GST'), '40000000-0000-0000-0000-000000000002', 'CROSS-FIRM', '2026-04-01', '2026-04-30', null, 'IMPORTED');
    raise exception 'cross-firm client was accepted';
  exception when others then
    if position('client is unavailable' in sqlerrm) = 0 then raise; end if;
  end;
end $$;

select set_config('request.jwt.claim.sub', '20000000-0000-0000-0000-000000000004', true);
select set_config('request.jwt.claims', '{"sub":"20000000-0000-0000-0000-000000000004","role":"authenticated"}', true);
do $$
declare visible_periods integer; visible_templates integer;
begin
  select count(*) into visible_periods from public.compliance_periods where firm_id = '10000000-0000-0000-0000-000000000001';
  select count(*) into visible_templates from public.compliance_templates where firm_id = '10000000-0000-0000-0000-000000000001';
  if visible_periods <> 0 or visible_templates <> 0 then raise exception 'cross-tenant compliance rows were visible'; end if;
end $$;

rollback;
