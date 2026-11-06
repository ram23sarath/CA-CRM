-- Stage 7 lead CRM integration checks. Run after all migrations and seed:
-- psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/tests/lead_crm.sql
-- Every mutation is rolled back.
\set ON_ERROR_STOP on

begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', '20000000-0000-0000-0000-000000000001', true);
select set_config('request.jwt.claims', '{"sub":"20000000-0000-0000-0000-000000000001","role":"authenticated"}', true);

do $$
declare lead_id uuid; duplicate_id uuid; proposal_id uuid; client_id uuid; repeated_client_id uuid; existing_lead_id uuid; existing_proposal_id uuid; existing_result uuid;
begin
  lead_id := public.create_lead('Synthetic Prospect', 'Stage Seven Demo', 'prospect@stage-seven.example.test', '+919876543210', 'REFERRAL', 85, '20000000-0000-0000-0000-000000000002', '2027-01-05', 'Synthetic lead for rollback-only coverage.');
  duplicate_id := public.create_lead('Duplicate Prospect', 'Should not create', 'prospect@stage-seven.example.test', null, 'WEB', 10, null, null, null);
  if lead_id is distinct from duplicate_id then raise exception 'duplicate lead was not idempotent'; end if;
  if (select count(*) from public.leads where firm_id = '10000000-0000-0000-0000-000000000001' and email_normalized = 'prospect@stage-seven.example.test') <> 1 then raise exception 'duplicate lead row exists'; end if;
  proposal_id := public.create_proposal(lead_id, 'Synthetic proposal', 'Monthly practice operations', '2027-01-31', 125000, 22500, 'INR', 'No external send.');
  perform public.set_proposal_outcome(proposal_id, 'ACCEPTED');
  client_id := public.convert_lead_to_client(lead_id, proposal_id, null, 'COMPANY');
  repeated_client_id := public.convert_lead_to_client(lead_id, proposal_id, null, 'COMPANY');
  if client_id is distinct from repeated_client_id then raise exception 'conversion was not idempotent'; end if;
  if not exists (select 1 from public.leads where id = lead_id and status = 'CONVERTED' and stage = 'CLIENT' and converted_client_id = client_id) then raise exception 'lead conversion state was not preserved'; end if;
  if not exists (select 1 from public.proposals where id = proposal_id and status = 'CONVERTED') then raise exception 'proposal history was not preserved'; end if;
  if not exists (select 1 from public.client_contacts cc where cc.client_id = client_id and cc.email = 'prospect@stage-seven.example.test') then raise exception 'lead contact was not mapped to the client'; end if;
  existing_lead_id := public.create_lead('Existing Client Prospect', 'Acme Orchard', 'existing@stage-seven.example.test', null, 'REFERRAL', 40, '20000000-0000-0000-0000-000000000002', null, null);
  existing_proposal_id := public.create_proposal(existing_lead_id, 'Existing client proposal', 'Additional scope', '2027-01-31', 100, 0, 'INR', null);
  perform public.set_proposal_outcome(existing_proposal_id, 'ACCEPTED');
  existing_result := public.convert_lead_to_client(existing_lead_id, existing_proposal_id, '40000000-0000-0000-0000-000000000001', 'COMPANY');
  if existing_result <> '40000000-0000-0000-0000-000000000001' then raise exception 'conversion did not use the selected existing client'; end if;
end $$;

do $$
declare lead_id uuid; proposal_id uuid;
begin
  lead_id := public.create_lead('Authorization Prospect', null, 'auth@stage-seven.example.test', null, 'REFERRAL', null, '20000000-0000-0000-0000-000000000002', null, null);
  proposal_id := public.create_proposal(lead_id, 'Authorization proposal', 'Scope', '2027-01-31', 1, 0, 'INR', null);
  select set_config('request.jwt.claim.sub', '20000000-0000-0000-0000-000000000003', true);
  select set_config('request.jwt.claims', '{"sub":"20000000-0000-0000-0000-000000000003","role":"authenticated"}', true);
  begin
    perform public.create_proposal_version(proposal_id, 'Tamper', '2027-01-31', 2, 0, 'INR', null);
    raise exception 'non-owner edited commercial terms';
  exception when others then
    if position('permission denied' in sqlerrm) = 0 then raise; end if;
  end;
end $$;

select set_config('request.jwt.claim.sub', '20000000-0000-0000-0000-000000000004', true);
select set_config('request.jwt.claims', '{"sub":"20000000-0000-0000-0000-000000000004","role":"authenticated"}', true);
do $$
declare visible_leads integer; visible_proposals integer;
begin
  select count(*) into visible_leads from public.leads where firm_id = '10000000-0000-0000-0000-000000000001';
  select count(*) into visible_proposals from public.proposals where firm_id = '10000000-0000-0000-0000-000000000001';
  if visible_leads <> 0 or visible_proposals <> 0 then raise exception 'cross-tenant lead or proposal rows were visible'; end if;
end $$;

rollback;
