-- Stage 6: firm-configured compliance periods, calendar views, and expiry registers.
-- Due dates are configuration snapshots only. This migration does not connect to
-- government portals or claim that any configured date is authoritative.
begin;

create table if not exists public.compliance_templates (
  id uuid primary key default gen_random_uuid(),
  firm_id uuid not null,
  code text not null check (code ~ '^[A-Z0-9][A-Z0-9_-]{1,31}$'),
  name text not null check (char_length(trim(name)) between 1 and 160),
  period_frequency text not null check (period_frequency in ('MONTHLY', 'QUARTERLY', 'ANNUAL', 'CUSTOM')),
  due_date_offset_days integer,
  task_template_id uuid,
  is_active boolean not null default true,
  created_by_profile_id uuid,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  archived_at timestamptz,
  unique (firm_id, id),
  unique (firm_id, code),
  foreign key (firm_id) references public.firms(id) on delete restrict,
  foreign key (firm_id, task_template_id) references public.task_templates(firm_id, id) on delete restrict,
  foreign key (firm_id, created_by_profile_id) references public.firm_memberships(firm_id, profile_id) on delete restrict,
  check (due_date_offset_days is null or due_date_offset_days between -366 and 366)
);

alter table public.compliance_periods drop constraint if exists compliance_periods_status_check;
update public.compliance_periods set status = 'UPCOMING' where status = 'OVERDUE';
alter table public.compliance_periods add constraint compliance_periods_status_check
  check (status in ('UPCOMING', 'IN_PROGRESS', 'READY_FOR_REVIEW', 'FILED', 'CANCELLED'));
alter table public.compliance_periods add column if not exists client_id uuid;
alter table public.compliance_periods add column if not exists type_code text;
alter table public.compliance_periods add column if not exists period_key text;
alter table public.compliance_periods add column if not exists task_id uuid;
alter table public.compliance_periods add column if not exists evidence_document_id uuid;
alter table public.compliance_periods add column if not exists filing_reference text;
alter table public.compliance_periods add column if not exists source text not null default 'MANUAL';
alter table public.compliance_periods add column if not exists last_verified_date date;
alter table public.compliance_periods add column if not exists last_updated_by_profile_id uuid;

update public.compliance_periods p
set client_id = o.client_id,
    type_code = case when o.category = 'INCOME_TAX' then 'INCOME_TAX' when o.category = 'MCA' then 'MCA_ROC' else o.category end,
    period_key = coalesce(p.period_start::text || '/' || p.period_end::text, p.id::text),
    source = 'MANUAL',
    last_verified_date = coalesce(p.period_start, current_date)
from public.compliance_obligations o
where o.id = p.obligation_id and (p.client_id is null or p.type_code is null or p.period_key is null);

alter table public.compliance_periods alter column client_id set not null;
alter table public.compliance_periods alter column type_code set not null;
alter table public.compliance_periods alter column period_key set not null;
alter table public.compliance_periods add constraint compliance_periods_type_code_check check (type_code ~ '^[A-Z0-9][A-Z0-9_-]{1,31}$');
alter table public.compliance_periods add constraint compliance_periods_source_check check (source in ('MANUAL', 'IMPORTED', 'CONFIGURED'));
alter table public.compliance_periods add constraint compliance_periods_client_fk foreign key (firm_id, client_id) references public.clients(firm_id, id) on delete restrict;
alter table public.compliance_periods add constraint compliance_periods_task_fk foreign key (firm_id, task_id) references public.tasks(firm_id, id) on delete restrict;
alter table public.compliance_periods add constraint compliance_periods_evidence_fk foreign key (firm_id, evidence_document_id) references public.documents(firm_id, id) on delete restrict;
alter table public.compliance_periods add constraint compliance_periods_updated_by_fk foreign key (firm_id, last_updated_by_profile_id) references public.firm_memberships(firm_id, profile_id) on delete restrict;

create unique index if not exists compliance_periods_firm_client_type_period_unique
  on public.compliance_periods (firm_id, client_id, type_code, period_key)
  where archived_at is null;
create index if not exists compliance_periods_firm_client_due_idx
  on public.compliance_periods (firm_id, client_id, due_date, status, archived_at);
create index if not exists compliance_periods_firm_type_idx
  on public.compliance_periods (firm_id, type_code, period_key);
create index if not exists compliance_templates_firm_active_idx
  on public.compliance_templates (firm_id, is_active, archived_at, code);

create table if not exists public.expiry_registers (
  id uuid primary key default gen_random_uuid(),
  firm_id uuid not null,
  register_type text not null check (register_type in ('DSC', 'LICENSE')),
  name text not null check (char_length(trim(name)) between 1 and 200),
  client_id uuid,
  owner_profile_id uuid,
  custodian_profile_id uuid,
  expiry_date date not null,
  reminder_date date,
  status text not null default 'ACTIVE' check (status in ('ACTIVE', 'EXPIRED', 'REVOKED', 'RENEWED')),
  notes text,
  source text not null default 'MANUAL' check (source in ('MANUAL', 'IMPORTED')),
  last_verified_date date,
  last_updated_by_profile_id uuid,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  archived_at timestamptz,
  unique (firm_id, id),
  foreign key (firm_id) references public.firms(id) on delete restrict,
  foreign key (firm_id, client_id) references public.clients(firm_id, id) on delete restrict,
  foreign key (firm_id, owner_profile_id) references public.firm_memberships(firm_id, profile_id) on delete restrict,
  foreign key (firm_id, custodian_profile_id) references public.firm_memberships(firm_id, profile_id) on delete restrict,
  foreign key (firm_id, last_updated_by_profile_id) references public.firm_memberships(firm_id, profile_id) on delete restrict,
  check (reminder_date is null or reminder_date <= expiry_date)
);
create index if not exists expiry_registers_firm_expiry_idx on public.expiry_registers (firm_id, expiry_date, status, archived_at);
create index if not exists expiry_registers_firm_type_idx on public.expiry_registers (firm_id, register_type, status, archived_at);

create trigger compliance_templates_set_updated_at before update on public.compliance_templates for each row execute function public.set_updated_at();
create trigger expiry_registers_set_updated_at before update on public.expiry_registers for each row execute function public.set_updated_at();

alter table public.compliance_templates enable row level security;
alter table public.compliance_templates force row level security;
alter table public.expiry_registers enable row level security;
alter table public.expiry_registers force row level security;

create policy compliance_templates_select_member on public.compliance_templates for select to authenticated using (public.is_firm_member(firm_id));
create policy compliance_templates_insert_manager on public.compliance_templates for insert to authenticated with check (public.has_firm_role(firm_id, array['OWNER', 'PARTNER', 'MANAGER']::public.firm_role[]));
create policy compliance_templates_update_manager on public.compliance_templates for update to authenticated using (public.has_firm_role(firm_id, array['OWNER', 'PARTNER', 'MANAGER']::public.firm_role[])) with check (public.has_firm_role(firm_id, array['OWNER', 'PARTNER', 'MANAGER']::public.firm_role[]));
create policy compliance_templates_delete_manager on public.compliance_templates for delete to authenticated using (public.has_firm_role(firm_id, array['OWNER', 'PARTNER', 'MANAGER']::public.firm_role[]));
create policy expiry_registers_select_member on public.expiry_registers for select to authenticated using (public.is_firm_member(firm_id));
create policy expiry_registers_insert_member on public.expiry_registers for insert to authenticated with check (public.is_firm_member(firm_id));
create policy expiry_registers_update_participant on public.expiry_registers for update to authenticated using (public.is_firm_member(firm_id) and (public.has_firm_role(firm_id, array['OWNER', 'PARTNER', 'MANAGER']::public.firm_role[]) or owner_profile_id = auth.uid() or custodian_profile_id = auth.uid())) with check (public.is_firm_member(firm_id));
create policy expiry_registers_delete_manager on public.expiry_registers for delete to authenticated using (public.has_firm_role(firm_id, array['OWNER', 'PARTNER', 'MANAGER']::public.firm_role[]));

create or replace function public.compliance_active_membership() returns public.firm_memberships
language plpgsql security definer set search_path = public, auth as $$ declare m public.firm_memberships; begin m := public.client_active_membership(); return m; end; $$;

create or replace function public.create_compliance_template(
  p_code text, p_name text, p_frequency text, p_due_offset_days integer, p_task_template_id uuid
) returns uuid language plpgsql security definer set search_path = public, auth as $$
declare m public.firm_memberships; result uuid := gen_random_uuid(); clean_code text := upper(trim(p_code));
begin
  m := public.compliance_active_membership();
  if not public.has_firm_role(m.firm_id, array['OWNER', 'PARTNER', 'MANAGER']::public.firm_role[]) then raise exception 'manager permission is required'; end if;
  if clean_code !~ '^[A-Z0-9][A-Z0-9_-]{1,31}$' then raise exception 'template code must use letters, numbers, underscore, or hyphen'; end if;
  if p_frequency not in ('MONTHLY', 'QUARTERLY', 'ANNUAL', 'CUSTOM') then raise exception 'invalid period frequency'; end if;
  if p_due_offset_days is null or p_due_offset_days not between -366 and 366 then raise exception 'a due-date offset between -366 and 366 days is required'; end if;
  if p_task_template_id is not null and not exists (select 1 from public.task_templates where id = p_task_template_id and firm_id = m.firm_id and is_active and archived_at is null) then raise exception 'task template is unavailable'; end if;
  insert into public.compliance_templates(id, firm_id, code, name, period_frequency, due_date_offset_days, task_template_id, created_by_profile_id)
  values(result, m.firm_id, clean_code, trim(p_name), p_frequency, p_due_offset_days, p_task_template_id, auth.uid());
  insert into public.audit_events(firm_id, actor_profile_id, actor_user_id, action, entity_table, entity_id, metadata)
  values(m.firm_id, auth.uid(), auth.uid(), 'compliance.template_created', 'compliance_templates', result, jsonb_build_object('code', clean_code, 'frequency', p_frequency, 'due_offset_days', p_due_offset_days));
  return result;
end; $$;

create or replace function public.generate_compliance_period(
  p_template_id uuid, p_client_id uuid, p_period_key text, p_period_start date, p_period_end date,
  p_owner_profile_id uuid, p_source text default 'CONFIGURED'
) returns uuid language plpgsql security definer set search_path = public, auth as $$
declare m public.firm_memberships; tpl public.compliance_templates; obligation_id uuid; period_id uuid; task_id uuid; due date; category text;
begin
  m := public.compliance_active_membership();
  if p_period_end < p_period_start then raise exception 'period end must not precede period start'; end if;
  if nullif(trim(p_period_key), '') is null then raise exception 'period key is required'; end if;
  if p_source not in ('MANUAL', 'IMPORTED', 'CONFIGURED') then raise exception 'invalid compliance source'; end if;
  select * into tpl from public.compliance_templates where id = p_template_id and firm_id = m.firm_id and is_active and archived_at is null for update;
  if tpl.id is null then raise exception 'active compliance template not found'; end if;
  if tpl.due_date_offset_days is null then raise exception 'the compliance template has no due-date configuration'; end if;
  if not exists(select 1 from public.clients where id = p_client_id and firm_id = m.firm_id and archived_at is null) then raise exception 'client is unavailable or archived' using errcode = 'P0002'; end if;
  if p_owner_profile_id is not null and not exists(select 1 from public.firm_memberships where firm_id = m.firm_id and profile_id = p_owner_profile_id and status = 'ACTIVE' and archived_at is null) then raise exception 'owner is not active in this firm'; end if;
  select id into period_id from public.compliance_periods where firm_id = m.firm_id and client_id = p_client_id and type_code = tpl.code and period_key = trim(p_period_key) and archived_at is null;
  if period_id is not null then
    insert into public.audit_events(firm_id, actor_profile_id, actor_user_id, action, entity_table, entity_id, metadata)
    values(m.firm_id, auth.uid(), auth.uid(), 'compliance.period_duplicate_ignored', 'compliance_periods', period_id, jsonb_build_object('client_id', p_client_id, 'type_code', tpl.code, 'period_key', trim(p_period_key), 'source', p_source));
    return period_id;
  end if;
  due := p_period_end + tpl.due_date_offset_days;
  category := case when tpl.code = 'INCOME_TAX' then 'INCOME_TAX' when tpl.code = 'MCA_ROC' then 'MCA' when tpl.code in ('GST', 'TDS') then tpl.code else 'OTHER' end;
  insert into public.compliance_obligations(firm_id, client_id, created_by_profile_id, code, name, category, frequency)
  values(m.firm_id, p_client_id, auth.uid(), tpl.code, tpl.name, category, tpl.period_frequency)
  on conflict (firm_id, client_id, code) do update set name = excluded.name, frequency = excluded.frequency
  returning id into obligation_id;
  if obligation_id is null then select id into obligation_id from public.compliance_obligations where firm_id = m.firm_id and client_id = p_client_id and code = tpl.code; end if;
  if tpl.task_template_id is not null then
    task_id := public.create_recurring_task_for_period(tpl.task_template_id, p_client_id, p_period_start, p_period_end);
    if p_owner_profile_id is not null then update public.tasks set owner_profile_id = p_owner_profile_id where id = task_id and firm_id = m.firm_id; end if;
  end if;
  insert into public.compliance_periods(firm_id, obligation_id, client_id, type_code, period_key, assigned_to_profile_id, period_start, period_end, due_date, status, task_id, source, last_verified_date, last_updated_by_profile_id)
  values(m.firm_id, obligation_id, p_client_id, tpl.code, trim(p_period_key), p_owner_profile_id, p_period_start, p_period_end, due, 'UPCOMING', task_id, p_source, (timezone('utc', now()) at time zone coalesce((select timezone from public.firms where id=m.firm_id), 'Asia/Kolkata'))::date, auth.uid())
  returning id into period_id;
  insert into public.audit_events(firm_id, actor_profile_id, actor_user_id, action, entity_table, entity_id, metadata)
  values(m.firm_id, auth.uid(), auth.uid(), 'compliance.period_generated', 'compliance_periods', period_id, jsonb_build_object('client_id', p_client_id, 'type_code', tpl.code, 'period_key', trim(p_period_key), 'due_date', due, 'task_id', task_id, 'source', p_source));
  return period_id;
exception when unique_violation then
  select id into period_id from public.compliance_periods where firm_id = m.firm_id and client_id = p_client_id and type_code = tpl.code and period_key = trim(p_period_key) and archived_at is null;
  if period_id is not null then
    insert into public.audit_events(firm_id, actor_profile_id, actor_user_id, action, entity_table, entity_id, metadata)
    values(m.firm_id, auth.uid(), auth.uid(), 'compliance.period_duplicate_ignored', 'compliance_periods', period_id, jsonb_build_object('client_id', p_client_id, 'type_code', tpl.code, 'period_key', trim(p_period_key), 'source', p_source));
    return period_id;
  end if;
  raise;
end; $$;

create or replace function public.update_compliance_period(
  p_period_id uuid, p_status text, p_assigned_to_profile_id uuid, p_filing_reference text,
  p_evidence_document_id uuid, p_confirm_filed boolean, p_source text, p_last_verified_date date
) returns void language plpgsql security definer set search_path = public, auth as $$
declare m public.firm_memberships; old public.compliance_periods; manager boolean;
begin
  m := public.compliance_active_membership();
  select * into old from public.compliance_periods where id = p_period_id and firm_id = m.firm_id and archived_at is null for update;
  if old.id is null then raise exception 'compliance period not found' using errcode = 'P0002'; end if;
  manager := public.has_firm_role(m.firm_id, array['OWNER', 'PARTNER', 'MANAGER']::public.firm_role[]);
  if not manager and auth.uid() is distinct from old.assigned_to_profile_id then raise exception 'permission denied for this compliance period' using errcode = '42501'; end if;
  if p_status not in ('UPCOMING', 'IN_PROGRESS', 'READY_FOR_REVIEW', 'FILED', 'CANCELLED') then raise exception 'invalid compliance status'; end if;
  if p_status = 'FILED' and not p_confirm_filed then raise exception 'explicit filing confirmation is required'; end if;
  if p_assigned_to_profile_id is not null and not exists(select 1 from public.firm_memberships where firm_id = m.firm_id and profile_id = p_assigned_to_profile_id and status = 'ACTIVE' and archived_at is null) then raise exception 'owner is not active in this firm'; end if;
  if p_evidence_document_id is not null and not exists(select 1 from public.documents where id = p_evidence_document_id and firm_id = m.firm_id and client_id = old.client_id and archived_at is null) then raise exception 'evidence document is not linked to this client'; end if;
  if p_source not in ('MANUAL', 'IMPORTED', 'CONFIGURED') then raise exception 'invalid compliance source'; end if;
  update public.compliance_periods set status = p_status, assigned_to_profile_id = p_assigned_to_profile_id, filing_reference = nullif(trim(p_filing_reference), ''), evidence_document_id = p_evidence_document_id, source = p_source, last_verified_date = coalesce(p_last_verified_date, (timezone('utc', now()) at time zone coalesce((select timezone from public.firms where id=m.firm_id), 'Asia/Kolkata'))::date), last_updated_by_profile_id = auth.uid(), completed_at = case when p_status = 'FILED' then coalesce(completed_at, timezone('utc', now())) else null end where id = old.id;
  insert into public.audit_events(firm_id, actor_profile_id, actor_user_id, action, entity_table, entity_id, metadata)
  values(m.firm_id, auth.uid(), auth.uid(), 'compliance.period_updated', 'compliance_periods', old.id, jsonb_build_object('from_status', old.status, 'to_status', p_status, 'assigned_to_profile_id', p_assigned_to_profile_id, 'filing_reference_changed', old.filing_reference is distinct from nullif(trim(p_filing_reference), ''), 'evidence_document_id', p_evidence_document_id, 'source', p_source));
end; $$;

create or replace function public.create_expiry_register(
  p_register_type text, p_name text, p_client_id uuid, p_owner_profile_id uuid, p_custodian_profile_id uuid,
  p_expiry_date date, p_reminder_date date, p_status text, p_notes text, p_source text, p_last_verified_date date
) returns uuid language plpgsql security definer set search_path = public, auth as $$
declare m public.firm_memberships; result uuid := gen_random_uuid();
begin
  m := public.compliance_active_membership();
  if p_register_type not in ('DSC', 'LICENSE') then raise exception 'invalid register type'; end if;
  if nullif(trim(p_name), '') is null or p_expiry_date is null then raise exception 'name and expiry date are required'; end if;
  if p_reminder_date is not null and p_reminder_date > p_expiry_date then raise exception 'reminder date must be on or before expiry date'; end if;
  if p_status not in ('ACTIVE', 'EXPIRED', 'REVOKED', 'RENEWED') then raise exception 'invalid expiry status'; end if;
  if p_source not in ('MANUAL', 'IMPORTED') then raise exception 'invalid expiry source'; end if;
  if p_client_id is not null and not exists(select 1 from public.clients where id = p_client_id and firm_id = m.firm_id and archived_at is null) then raise exception 'client is unavailable or archived'; end if;
  if p_owner_profile_id is not null and not exists(select 1 from public.firm_memberships where firm_id = m.firm_id and profile_id = p_owner_profile_id and status = 'ACTIVE' and archived_at is null) then raise exception 'owner is not active in this firm'; end if;
  if p_custodian_profile_id is not null and not exists(select 1 from public.firm_memberships where firm_id = m.firm_id and profile_id = p_custodian_profile_id and status = 'ACTIVE' and archived_at is null) then raise exception 'custodian is not active in this firm'; end if;
  insert into public.expiry_registers(id, firm_id, register_type, name, client_id, owner_profile_id, custodian_profile_id, expiry_date, reminder_date, status, notes, source, last_verified_date, last_updated_by_profile_id)
  values(result, m.firm_id, p_register_type, trim(p_name), p_client_id, p_owner_profile_id, p_custodian_profile_id, p_expiry_date, p_reminder_date, p_status, nullif(trim(p_notes), ''), p_source, coalesce(p_last_verified_date, (timezone('utc', now()) at time zone coalesce((select timezone from public.firms where id=m.firm_id), 'Asia/Kolkata'))::date), auth.uid());
  insert into public.audit_events(firm_id, actor_profile_id, actor_user_id, action, entity_table, entity_id, metadata)
  values(m.firm_id, auth.uid(), auth.uid(), 'compliance.expiry_created', 'expiry_registers', result, jsonb_build_object('register_type', p_register_type, 'client_id', p_client_id, 'expiry_date', p_expiry_date, 'source', p_source));
  return result;
end; $$;

create or replace function public.update_expiry_register_status(p_register_id uuid, p_status text, p_last_verified_date date) returns void language plpgsql security definer set search_path = public, auth as $$
declare m public.firm_memberships; old public.expiry_registers;
begin
  m := public.compliance_active_membership();
  select * into old from public.expiry_registers where id = p_register_id and firm_id = m.firm_id and archived_at is null for update;
  if old.id is null then raise exception 'expiry register record not found' using errcode = 'P0002'; end if;
  if not public.has_firm_role(m.firm_id, array['OWNER', 'PARTNER', 'MANAGER']::public.firm_role[]) and auth.uid() not in (old.owner_profile_id, old.custodian_profile_id) then raise exception 'permission denied for this expiry record' using errcode = '42501'; end if;
  if p_status not in ('ACTIVE', 'EXPIRED', 'REVOKED', 'RENEWED') then raise exception 'invalid expiry status'; end if;
  update public.expiry_registers set status = p_status, last_verified_date = coalesce(p_last_verified_date, (timezone('utc', now()) at time zone coalesce((select timezone from public.firms where id=m.firm_id), 'Asia/Kolkata'))::date), last_updated_by_profile_id = auth.uid() where id = old.id;
  insert into public.audit_events(firm_id, actor_profile_id, actor_user_id, action, entity_table, entity_id, metadata) values(m.firm_id, auth.uid(), auth.uid(), 'compliance.expiry_status_updated', 'expiry_registers', old.id, jsonb_build_object('from_status', old.status, 'to_status', p_status));
end; $$;

revoke all on function public.compliance_active_membership() from public;
revoke all on function public.create_compliance_template(text, text, text, integer, uuid) from public;
revoke all on function public.generate_compliance_period(uuid, uuid, text, date, date, uuid, text) from public;
revoke all on function public.update_compliance_period(uuid, text, uuid, text, uuid, boolean, text, date) from public;
revoke all on function public.create_expiry_register(text, text, uuid, uuid, uuid, date, date, text, text, text, date) from public;
revoke all on function public.update_expiry_register_status(uuid, text, date) from public;
grant execute on function public.create_compliance_template(text, text, text, integer, uuid), public.generate_compliance_period(uuid, uuid, text, date, date, uuid, text), public.update_compliance_period(uuid, text, uuid, text, uuid, boolean, text, date), public.create_expiry_register(text, text, uuid, uuid, uuid, date, date, text, text, text, date), public.update_expiry_register_status(uuid, text, date) to authenticated, service_role;

commit;
