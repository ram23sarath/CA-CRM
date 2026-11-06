-- Local-only synthetic seed data for Northstar Practice.
-- These users have no usable passwords and are not production credentials.
-- Identifiers are deliberately fictional/example values.

begin;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values
  ('20000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'owner@northstar.example.test', '', null, '{"provider":"email","providers":["email"]}'::jsonb, '{"display_name":"Asha Mehta"}'::jsonb, timezone('utc', now()), timezone('utc', now())),
  ('20000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'manager@northstar.example.test', '', null, '{"provider":"email","providers":["email"]}'::jsonb, '{"display_name":"Rohan Sen"}'::jsonb, timezone('utc', now()), timezone('utc', now())),
  ('20000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'staff@northstar.example.test', '', null, '{"provider":"email","providers":["email"]}'::jsonb, '{"display_name":"Mira Shah"}'::jsonb, timezone('utc', now()), timezone('utc', now())),
  ('20000000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'other-firm@northstar.example.test', '', null, '{"provider":"email","providers":["email"]}'::jsonb, '{"display_name":"Kabir Rao"}'::jsonb, timezone('utc', now()), timezone('utc', now())
on conflict (id) do nothing;

insert into public.profiles (id, display_name)
values
  ('20000000-0000-0000-0000-000000000001', 'Asha Mehta'),
  ('20000000-0000-0000-0000-000000000002', 'Rohan Sen'),
  ('20000000-0000-0000-0000-000000000003', 'Mira Shah'),
  ('20000000-0000-0000-0000-000000000004', 'Kabir Rao')
on conflict (id) do update set display_name = excluded.display_name;

insert into public.firms (id, name, legal_name, plan, approval_status, created_by_profile_id)
values
  ('10000000-0000-0000-0000-000000000001', 'Northstar Demo Firm', 'Northstar Demo Firm (Synthetic)', 'GROWTH', 'ACTIVE', '20000000-0000-0000-0000-000000000001'),
  ('10000000-0000-0000-0000-000000000002', 'Harbor Ledger Demo', 'Harbor Ledger Demo (Synthetic)', 'STARTER', 'ACTIVE', '20000000-0000-0000-0000-000000000004')
on conflict (id) do nothing;

insert into public.firm_memberships (firm_id, profile_id, role)
values
  ('10000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001', 'OWNER'),
  ('10000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000002', 'MANAGER'),
  ('10000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000003', 'STAFF'),
  ('10000000-0000-0000-0000-000000000002', '20000000-0000-0000-0000-000000000004', 'OWNER')
on conflict (firm_id, profile_id) do update set role = excluded.role, status = 'ACTIVE', archived_at = null;

insert into public.services (id, firm_id, name, code, description)
values
  ('30000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 'GST compliance', 'GST', 'Synthetic service for local policy and RLS testing.'),
  ('30000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000001', 'TDS compliance', 'TDS', 'Synthetic service for local policy and RLS testing.'),
  ('30000000-0000-0000-0000-000000000003', '10000000-0000-0000-0000-000000000002', 'Annual accounts', 'ACCOUNTS', 'Synthetic service in a separate demo firm.')
on conflict (id) do nothing;

insert into public.clients (id, firm_id, owner_profile_id, created_by_profile_id, client_code, legal_name, display_name, entity_type, tax_identifier)
values
  ('40000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000002', '20000000-0000-0000-0000-000000000001', 'DEMO-ACME', 'Acme Orchard Private Limited (Synthetic)', 'Acme Orchard', 'COMPANY', 'DEMO-INVALID-PAN-001'),
  ('40000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000002', '20000000-0000-0000-0000-000000000004', '20000000-0000-0000-0000-000000000004', 'DEMO-HARBOR', 'Harbor Ledger LLP (Synthetic)', 'Harbor Ledger', 'LLP', 'DEMO-INVALID-PAN-002')
on conflict (id) do nothing;

insert into public.client_contacts (firm_id, client_id, created_by_profile_id, full_name, email, designation, is_primary)
values
  ('10000000-0000-0000-0000-000000000001', '40000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001', 'Nila Kapoor', 'nila@acme-orchard.example.test', 'Synthetic finance contact', true);

insert into public.task_templates (id, firm_id, service_id, name, description, default_priority, recurrence_frequency, default_due_offset_days)
values
  ('50000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000001', 'Monthly GST review', 'Synthetic template; no statutory dates are implied.', 'HIGH', 'MONTHLY', 0)
on conflict (id) do nothing;

insert into public.tasks (id, firm_id, client_id, service_id, template_id, owner_profile_id, assignee_profile_id, reviewer_profile_id, created_by_profile_id, title, description, status, priority, due_date)
values
  ('60000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', '40000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000001', '50000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000002', '20000000-0000-0000-0000-000000000003', '20000000-0000-0000-0000-000000000002', '20000000-0000-0000-0000-000000000001', 'Review synthetic GST workpaper', 'Local-only demo task.', 'IN_REVIEW', 'HIGH', current_date + 14)
on conflict (id) do nothing;

insert into public.task_checklist_items (firm_id, task_id, position, label)
values
  ('10000000-0000-0000-0000-000000000001', '60000000-0000-0000-0000-000000000001', 0, 'Confirm synthetic source files are present'),
  ('10000000-0000-0000-0000-000000000001', '60000000-0000-0000-0000-000000000001', 1, 'Record reviewer note');

insert into public.task_comments (firm_id, task_id, author_profile_id, body)
values
  ('10000000-0000-0000-0000-000000000001', '60000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000003', 'Synthetic comment for local UI and RLS testing.');

insert into public.compliance_obligations (id, firm_id, client_id, service_id, created_by_profile_id, code, name, category, frequency)
values
  ('70000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', '40000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000002', 'DEMO-GST', 'Synthetic GST obligation', 'GST', 'MONTHLY')
on conflict (id) do nothing;

insert into public.compliance_periods (firm_id, obligation_id, client_id, type_code, period_key, assigned_to_profile_id, reviewer_profile_id, period_start, period_end, due_date, status, reference, source, last_verified_date, last_updated_by_profile_id)
values
  ('10000000-0000-0000-0000-000000000001', '70000000-0000-0000-0000-000000000001', '40000000-0000-0000-0000-000000000001', 'GST', 'DEMO-2026-03', '20000000-0000-0000-0000-000000000003', '20000000-0000-0000-0000-000000000002', current_date - 30, current_date - 1, current_date + 21, 'IN_PROGRESS', 'SYNTHETIC-PERIOD-001', 'MANUAL', current_date, '20000000-0000-0000-0000-000000000001')
on conflict (firm_id, obligation_id, period_start, period_end) do nothing;

insert into public.audit_events (firm_id, actor_profile_id, action, entity_table, entity_id, metadata)
values
  ('10000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001', 'seed.created', 'firms', '10000000-0000-0000-0000-000000000001', '{"synthetic":true}'::jsonb);

commit;
