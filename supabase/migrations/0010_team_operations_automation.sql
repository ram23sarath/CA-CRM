-- Stage 9: team operations, durable notifications, and deterministic automation.
-- External delivery is intentionally preview-only in this stage.
begin;

create table public.attendance_sessions (
  id uuid primary key default gen_random_uuid(),
  firm_id uuid not null references public.firms(id) on delete restrict,
  profile_id uuid not null,
  work_date date not null,
  checked_in_at timestamptz not null default timezone('utc', now()),
  checked_out_at timestamptz,
  note text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (firm_id, id),
  foreign key (firm_id, profile_id) references public.firm_memberships(firm_id, profile_id) on delete restrict,
  check (checked_out_at is null or checked_out_at > checked_in_at)
);

create unique index attendance_one_open_session_idx on public.attendance_sessions(firm_id, profile_id) where checked_out_at is null;
create index attendance_firm_date_idx on public.attendance_sessions(firm_id, work_date desc, checked_in_at desc);

create table public.leave_requests (
  id uuid primary key default gen_random_uuid(),
  firm_id uuid not null references public.firms(id) on delete restrict,
  requester_profile_id uuid not null,
  leave_type text not null check (leave_type in ('ANNUAL', 'SICK', 'PERSONAL', 'UNPAID', 'OTHER')),
  start_date date not null,
  end_date date not null,
  reason text,
  status text not null default 'PENDING' check (status in ('PENDING', 'APPROVED', 'REJECTED', 'CANCELLED')),
  decided_by_profile_id uuid,
  decided_at timestamptz,
  decision_note text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (firm_id, id),
  foreign key (firm_id, requester_profile_id) references public.firm_memberships(firm_id, profile_id) on delete restrict,
  foreign key (firm_id, decided_by_profile_id) references public.firm_memberships(firm_id, profile_id) on delete restrict,
  check (end_date >= start_date),
  check ((status in ('PENDING', 'CANCELLED') and decided_at is null and decided_by_profile_id is null) or (status in ('APPROVED', 'REJECTED') and decided_at is not null and decided_by_profile_id is not null))
);

create index leave_requests_firm_dates_idx on public.leave_requests(firm_id, start_date, end_date, status);
create index leave_requests_requester_idx on public.leave_requests(firm_id, requester_profile_id, created_at desc);

create table public.timesheet_entries (
  id uuid primary key default gen_random_uuid(),
  firm_id uuid not null references public.firms(id) on delete restrict,
  profile_id uuid not null,
  task_id uuid,
  client_id uuid,
  work_date date not null,
  minutes integer not null check (minutes >= 0 and minutes <= 1440),
  description text not null check (char_length(trim(description)) between 1 and 1000),
  status text not null default 'OPEN' check (status in ('OPEN', 'LOCKED')),
  locked_at timestamptz,
  locked_by_profile_id uuid,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (firm_id, id),
  foreign key (firm_id, profile_id) references public.firm_memberships(firm_id, profile_id) on delete restrict,
  foreign key (firm_id, task_id) references public.tasks(firm_id, id) on delete restrict,
  foreign key (firm_id, client_id) references public.clients(firm_id, id) on delete restrict,
  foreign key (firm_id, locked_by_profile_id) references public.firm_memberships(firm_id, profile_id) on delete restrict,
  check ((status = 'OPEN' and locked_at is null and locked_by_profile_id is null) or (status = 'LOCKED' and locked_at is not null and locked_by_profile_id is not null))
);

create index timesheet_firm_date_idx on public.timesheet_entries(firm_id, work_date desc, profile_id);
create index timesheet_task_idx on public.timesheet_entries(firm_id, task_id, work_date desc);

create table public.employee_reimbursements (
  id uuid primary key default gen_random_uuid(),
  firm_id uuid not null references public.firms(id) on delete restrict,
  profile_id uuid not null,
  amount numeric(18,2) not null check (amount > 0),
  currency text not null default 'INR' check (currency ~ '^[A-Z]{3}$'),
  expense_date date not null,
  description text not null check (char_length(trim(description)) between 1 and 500),
  status text not null default 'SUBMITTED' check (status in ('SUBMITTED', 'APPROVED', 'REJECTED', 'PAID')),
  decided_by_profile_id uuid,
  decided_at timestamptz,
  decision_note text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (firm_id, id),
  foreign key (firm_id, profile_id) references public.firm_memberships(firm_id, profile_id) on delete restrict,
  foreign key (firm_id, decided_by_profile_id) references public.firm_memberships(firm_id, profile_id) on delete restrict
);

create table public.notification_preferences (
  firm_id uuid not null references public.firms(id) on delete restrict,
  profile_id uuid not null,
  opt_out_all boolean not null default false,
  email_enabled boolean not null default false,
  whatsapp_enabled boolean not null default false,
  preferred_channel text not null default 'INTERNAL' check (preferred_channel in ('INTERNAL', 'EMAIL', 'WHATSAPP')),
  updated_at timestamptz not null default timezone('utc', now()),
  primary key (firm_id, profile_id),
  foreign key (firm_id, profile_id) references public.firm_memberships(firm_id, profile_id) on delete cascade
);

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  firm_id uuid not null references public.firms(id) on delete restrict,
  recipient_profile_id uuid not null,
  kind text not null,
  title text not null check (char_length(trim(title)) between 1 and 240),
  body text not null check (char_length(trim(body)) between 1 and 2000),
  action_url text,
  source_event_id uuid,
  read_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  unique (firm_id, id),
  foreign key (firm_id, recipient_profile_id) references public.firm_memberships(firm_id, profile_id) on delete cascade
);

create index notifications_recipient_idx on public.notifications(firm_id, recipient_profile_id, read_at, created_at desc);

create table public.automation_settings (
  firm_id uuid primary key references public.firms(id) on delete cascade,
  paused boolean not null default false,
  safe_preview_mode boolean not null default true,
  max_attempts integer not null default 5 check (max_attempts between 1 and 10),
  updated_by_profile_id uuid,
  updated_at timestamptz not null default timezone('utc', now()),
  foreign key (firm_id, updated_by_profile_id) references public.firm_memberships(firm_id, profile_id) on delete set null
);

create table public.automation_rules (
  id uuid primary key default gen_random_uuid(),
  firm_id uuid not null references public.firms(id) on delete restrict,
  name text not null check (char_length(trim(name)) between 1 and 160),
  trigger text not null check (trigger in ('COMPLIANCE_DUE_SOON', 'TASK_ASSIGNED', 'TASK_OVERDUE', 'INVOICE_OVERDUE', 'LEAD_FOLLOW_UP_DUE')),
  conditions jsonb not null default '{}'::jsonb check (jsonb_typeof(conditions) = 'object'),
  recipient_type text not null check (recipient_type in ('ASSIGNEE', 'OWNER', 'MANAGER', 'PROFILE', 'ALL_ACTIVE')),
  recipient_profile_id uuid,
  channel text not null check (channel in ('INTERNAL', 'EMAIL', 'WHATSAPP')),
  action text not null check (action in ('CREATE_NOTIFICATION', 'CREATE_FOLLOW_UP_TASK', 'QUEUE_MESSAGE_PREVIEW')),
  enabled boolean not null default false,
  activated_by_profile_id uuid,
  activated_at timestamptz,
  paused_at timestamptz,
  throttle_minutes integer not null default 1440 check (throttle_minutes between 0 and 43200),
  last_run_at timestamptz,
  created_by_profile_id uuid not null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (firm_id, id),
  foreign key (firm_id, recipient_profile_id) references public.firm_memberships(firm_id, profile_id) on delete restrict,
  foreign key (firm_id, activated_by_profile_id) references public.firm_memberships(firm_id, profile_id) on delete restrict,
  foreign key (firm_id, created_by_profile_id) references public.firm_memberships(firm_id, profile_id) on delete restrict,
  check ((recipient_type = 'PROFILE' and recipient_profile_id is not null) or (recipient_type <> 'PROFILE' and recipient_profile_id is null)),
  check ((enabled = false and activated_at is null and activated_by_profile_id is null) or (enabled = true and activated_at is not null and activated_by_profile_id is not null))
);

create table public.automation_events (
  id uuid primary key default gen_random_uuid(),
  firm_id uuid not null references public.firms(id) on delete restrict,
  event_type text not null,
  subject_table text not null,
  subject_id uuid not null,
  event_key text not null,
  payload jsonb not null default '{}'::jsonb check (jsonb_typeof(payload) = 'object'),
  status text not null default 'PENDING' check (status in ('PENDING', 'PROCESSING', 'DELIVERED', 'FAILED', 'DEAD_LETTER')),
  attempts integer not null default 0 check (attempts >= 0),
  available_at timestamptz not null default timezone('utc', now()),
  lease_until timestamptz,
  leased_by text,
  last_error text,
  created_at timestamptz not null default timezone('utc', now()),
  delivered_at timestamptz,
  unique (firm_id, event_key)
);

create index automation_events_claim_idx on public.automation_events(status, available_at, lease_until);

create table public.automation_deliveries (
  id uuid primary key default gen_random_uuid(),
  firm_id uuid not null references public.firms(id) on delete restrict,
  event_id uuid not null references public.automation_events(id) on delete restrict,
  rule_id uuid not null references public.automation_rules(id) on delete restrict,
  recipient_profile_id uuid not null,
  channel text not null check (channel in ('INTERNAL', 'EMAIL', 'WHATSAPP')),
  action text not null check (action in ('CREATE_NOTIFICATION', 'CREATE_FOLLOW_UP_TASK', 'QUEUE_MESSAGE_PREVIEW')),
  status text not null default 'PENDING' check (status in ('PENDING', 'PROCESSING', 'PREVIEWED', 'SUCCEEDED', 'FAILED', 'SKIPPED', 'DEAD_LETTER')),
  preview_only boolean not null default true,
  attempts integer not null default 0 check (attempts >= 0),
  available_at timestamptz not null default timezone('utc', now()),
  lease_until timestamptz,
  leased_by text,
  last_error text,
  provider_reference text,
  result jsonb not null default '{}'::jsonb check (jsonb_typeof(result) = 'object'),
  created_at timestamptz not null default timezone('utc', now()),
  completed_at timestamptz,
  unique (firm_id, event_id, rule_id, recipient_profile_id),
  foreign key (firm_id, recipient_profile_id) references public.firm_memberships(firm_id, profile_id) on delete restrict
);

create index automation_deliveries_claim_idx on public.automation_deliveries(status, available_at, lease_until);
create index automation_deliveries_history_idx on public.automation_deliveries(firm_id, created_at desc);

alter table public.notifications add column source_delivery_id uuid references public.automation_deliveries(id) on delete set null;
create unique index notifications_source_delivery_idx on public.notifications(firm_id, source_delivery_id) where source_delivery_id is not null;
alter table public.tasks add column automation_delivery_id uuid references public.automation_deliveries(id) on delete set null;
create unique index tasks_automation_delivery_idx on public.tasks(automation_delivery_id) where automation_delivery_id is not null;

create table public.automation_job_history (
  id uuid primary key default gen_random_uuid(),
  firm_id uuid references public.firms(id) on delete set null,
  job_type text not null,
  status text not null check (status in ('RUNNING', 'SUCCEEDED', 'FAILED')),
  preview_mode boolean not null default true,
  claimed_count integer not null default 0,
  success_count integer not null default 0,
  failure_count integer not null default 0,
  dead_letter_count integer not null default 0,
  error text,
  started_at timestamptz not null default timezone('utc', now()),
  finished_at timestamptz
);

create index automation_job_history_idx on public.automation_job_history(firm_id, started_at desc);

create or replace function public.team_active_membership()
returns public.firm_memberships
language sql stable security definer set search_path = public, auth
as $$ select membership from public.firm_memberships membership join public.firms firm on firm.id = membership.firm_id where membership.profile_id = auth.uid() and membership.status = 'ACTIVE' and membership.archived_at is null and firm.approval_status = 'ACTIVE' limit 1 $$;

create or replace function public.team_local_date(p_firm_id uuid)
returns date language sql stable security definer set search_path = public
as $$ select (now() at time zone coalesce((select timezone from public.firms where id = p_firm_id), 'Asia/Kolkata'))::date $$;

create or replace function public.start_attendance(p_work_date date default null, p_note text default null)
returns uuid language plpgsql security definer set search_path = public, auth as $$
declare m public.firm_memberships; result uuid;
begin
  m := public.team_active_membership();
  if m.firm_id is null then raise exception 'active firm membership required' using errcode = '42501'; end if;
  insert into public.attendance_sessions(firm_id, profile_id, work_date, note)
  values(m.firm_id, auth.uid(), coalesce(p_work_date, public.team_local_date(m.firm_id)), nullif(trim(p_note), '')) returning id into result;
  insert into public.audit_events(firm_id, actor_profile_id, actor_user_id, action, entity_table, entity_id, metadata) values(m.firm_id, auth.uid(), auth.uid(), 'attendance.started', 'attendance_sessions', result, jsonb_build_object('work_date', coalesce(p_work_date, public.team_local_date(m.firm_id))));
  return result;
exception when unique_violation then raise exception 'an open attendance session already exists' using errcode = '23505';
end; $$;

create or replace function public.stop_attendance(p_session_id uuid, p_checked_out_at timestamptz default timezone('utc', now()))
returns void language plpgsql security definer set search_path = public, auth as $$
declare m public.firm_memberships; s public.attendance_sessions;
begin
  m := public.team_active_membership(); select * into s from public.attendance_sessions where id = p_session_id and firm_id = m.firm_id for update;
  if s.id is null then raise exception 'attendance session not found' using errcode = 'P0002'; end if;
  if s.checked_out_at is not null then raise exception 'attendance session is already closed'; end if;
  if s.profile_id <> auth.uid() and not public.has_firm_role(m.firm_id, array['OWNER','PARTNER','MANAGER']::public.firm_role[]) then raise exception 'permission denied' using errcode = '42501'; end if;
  if p_checked_out_at <= s.checked_in_at then raise exception 'check-out must be after check-in'; end if;
  update public.attendance_sessions set checked_out_at = p_checked_out_at where id = s.id;
  insert into public.audit_events(firm_id, actor_profile_id, actor_user_id, action, entity_table, entity_id, metadata) values(m.firm_id, auth.uid(), auth.uid(), 'attendance.stopped', 'attendance_sessions', s.id, jsonb_build_object('checked_out_at', p_checked_out_at));
end; $$;

create or replace function public.create_leave_request(p_leave_type text, p_start_date date, p_end_date date, p_reason text default null)
returns uuid language plpgsql security definer set search_path = public, auth as $$
declare m public.firm_memberships; result uuid;
begin
  m := public.team_active_membership();
  if m.firm_id is null then raise exception 'active firm membership required' using errcode = '42501'; end if;
  if p_leave_type not in ('ANNUAL','SICK','PERSONAL','UNPAID','OTHER') or p_start_date is null or p_end_date < p_start_date then raise exception 'invalid leave request'; end if;
  perform pg_advisory_xact_lock(hashtextextended(m.firm_id::text || ':' || auth.uid()::text, 0));
  if exists(select 1 from public.leave_requests where firm_id = m.firm_id and requester_profile_id = auth.uid() and status in ('PENDING','APPROVED') and daterange(start_date, end_date, '[]') && daterange(p_start_date, p_end_date, '[]')) then raise exception 'leave dates overlap an existing request'; end if;
  insert into public.leave_requests(firm_id, requester_profile_id, leave_type, start_date, end_date, reason) values(m.firm_id, auth.uid(), p_leave_type, p_start_date, p_end_date, nullif(trim(p_reason), '')) returning id into result;
  insert into public.audit_events(firm_id, actor_profile_id, actor_user_id, action, entity_table, entity_id, metadata) values(m.firm_id, auth.uid(), auth.uid(), 'leave.requested', 'leave_requests', result, jsonb_build_object('start_date', p_start_date, 'end_date', p_end_date));
  return result;
end; $$;

create or replace function public.decide_leave_request(p_request_id uuid, p_status text, p_note text default null)
returns void language plpgsql security definer set search_path = public, auth as $$
declare m public.firm_memberships; r public.leave_requests;
begin
  m := public.team_active_membership();
  if not public.has_firm_role(m.firm_id, array['OWNER','PARTNER','MANAGER']::public.firm_role[]) then raise exception 'manager approval required' using errcode = '42501'; end if;
  select * into r from public.leave_requests where id = p_request_id and firm_id = m.firm_id for update;
  if r.id is null or r.status <> 'PENDING' then raise exception 'pending leave request not found'; end if;
  if r.requester_profile_id = auth.uid() then raise exception 'requester cannot approve their own leave'; end if;
  if p_status not in ('APPROVED','REJECTED') then raise exception 'invalid leave decision'; end if;
  update public.leave_requests set status = p_status, decided_by_profile_id = auth.uid(), decided_at = timezone('utc', now()), decision_note = nullif(trim(p_note), '') where id = r.id;
  insert into public.audit_events(firm_id, actor_profile_id, actor_user_id, action, entity_table, entity_id, metadata) values(m.firm_id, auth.uid(), auth.uid(), 'leave.' || lower(p_status), 'leave_requests', r.id, jsonb_build_object('requester_profile_id', r.requester_profile_id));
end; $$;

create or replace function public.add_timesheet_entry(p_work_date date, p_minutes integer, p_description text, p_task_id uuid default null, p_client_id uuid default null)
returns uuid language plpgsql security definer set search_path = public, auth as $$
declare m public.firm_memberships; result uuid;
begin
  m := public.team_active_membership();
  if m.firm_id is null then raise exception 'active firm membership required' using errcode = '42501'; end if;
  if p_minutes < 0 or p_minutes > 1440 or p_work_date is null or nullif(trim(p_description), '') is null then raise exception 'invalid timesheet entry'; end if;
  if p_task_id is not null and not exists(select 1 from public.tasks where id = p_task_id and firm_id = m.firm_id) then raise exception 'task is not in this firm'; end if;
  if p_client_id is not null and not exists(select 1 from public.clients where id = p_client_id and firm_id = m.firm_id) then raise exception 'client is not in this firm'; end if;
  insert into public.timesheet_entries(firm_id, profile_id, task_id, client_id, work_date, minutes, description) values(m.firm_id, auth.uid(), p_task_id, p_client_id, p_work_date, p_minutes, trim(p_description)) returning id into result;
  insert into public.audit_events(firm_id, actor_profile_id, actor_user_id, action, entity_table, entity_id, metadata) values(m.firm_id, auth.uid(), auth.uid(), 'timesheet.created', 'timesheet_entries', result, jsonb_build_object('minutes', p_minutes));
  return result;
end; $$;

create or replace function public.lock_timesheet_entry(p_entry_id uuid)
returns void language plpgsql security definer set search_path = public, auth as $$
declare m public.firm_memberships; e public.timesheet_entries;
begin
  m := public.team_active_membership(); select * into e from public.timesheet_entries where id = p_entry_id and firm_id = m.firm_id for update;
  if e.id is null then raise exception 'timesheet entry not found' using errcode = 'P0002'; end if;
  if e.status = 'LOCKED' then return; end if;
  if e.profile_id <> auth.uid() and not public.has_firm_role(m.firm_id, array['OWNER','PARTNER','MANAGER']::public.firm_role[]) then raise exception 'permission denied' using errcode = '42501'; end if;
  update public.timesheet_entries set status = 'LOCKED', locked_at = timezone('utc', now()), locked_by_profile_id = auth.uid() where id = e.id;
  insert into public.audit_events(firm_id, actor_profile_id, actor_user_id, action, entity_table, entity_id, metadata) values(m.firm_id, auth.uid(), auth.uid(), 'timesheet.locked', 'timesheet_entries', e.id, '{}'::jsonb);
end; $$;

create or replace function public.create_reimbursement(p_amount numeric, p_expense_date date, p_description text)
returns uuid language plpgsql security definer set search_path = public, auth as $$
declare m public.firm_memberships; result uuid;
begin
  m := public.team_active_membership();
  if m.firm_id is null or p_amount <= 0 or p_expense_date is null or nullif(trim(p_description), '') is null then raise exception 'invalid reimbursement'; end if;
  insert into public.employee_reimbursements(firm_id, profile_id, amount, expense_date, description) values(m.firm_id, auth.uid(), round(p_amount, 2), p_expense_date, trim(p_description)) returning id into result;
  insert into public.audit_events(firm_id, actor_profile_id, actor_user_id, action, entity_table, entity_id, metadata) values(m.firm_id, auth.uid(), auth.uid(), 'reimbursement.submitted', 'employee_reimbursements', result, jsonb_build_object('amount', round(p_amount, 2))); return result;
end; $$;

create or replace function public.decide_reimbursement(p_reimbursement_id uuid, p_status text, p_note text default null)
returns void language plpgsql security definer set search_path = public, auth as $$
declare m public.firm_memberships; r public.employee_reimbursements;
begin
  m := public.team_active_membership(); if not public.has_firm_role(m.firm_id, array['OWNER','PARTNER','MANAGER']::public.firm_role[]) then raise exception 'manager approval required' using errcode = '42501'; end if;
  select * into r from public.employee_reimbursements where id = p_reimbursement_id and firm_id = m.firm_id for update; if r.id is null or r.status <> 'SUBMITTED' then raise exception 'submitted reimbursement not found'; end if;
  if p_status not in ('APPROVED','REJECTED') then raise exception 'invalid reimbursement decision'; end if;
  update public.employee_reimbursements set status = p_status, decided_by_profile_id = auth.uid(), decided_at = timezone('utc', now()), decision_note = nullif(trim(p_note), '') where id = r.id;
  insert into public.audit_events(firm_id, actor_profile_id, actor_user_id, action, entity_table, entity_id, metadata) values(m.firm_id, auth.uid(), auth.uid(), 'reimbursement.' || lower(p_status), 'employee_reimbursements', r.id, '{}'::jsonb);
end; $$;

create or replace function public.create_automation_rule(p_name text, p_trigger text, p_conditions jsonb, p_recipient_type text, p_recipient_profile_id uuid, p_channel text, p_action text, p_throttle_minutes integer default 1440)
returns uuid language plpgsql security definer set search_path = public, auth as $$
declare m public.firm_memberships; result uuid;
begin
  m := public.team_active_membership(); if not public.has_firm_role(m.firm_id, array['OWNER','PARTNER','MANAGER']::public.firm_role[]) then raise exception 'manager automation permission required' using errcode = '42501'; end if;
  if p_trigger not in ('COMPLIANCE_DUE_SOON','TASK_ASSIGNED','TASK_OVERDUE','INVOICE_OVERDUE','LEAD_FOLLOW_UP_DUE') or p_recipient_type not in ('ASSIGNEE','OWNER','MANAGER','PROFILE','ALL_ACTIVE') or p_channel not in ('INTERNAL','EMAIL','WHATSAPP') or p_action not in ('CREATE_NOTIFICATION','CREATE_FOLLOW_UP_TASK','QUEUE_MESSAGE_PREVIEW') then raise exception 'invalid automation rule'; end if;
  if p_recipient_type = 'PROFILE' and p_recipient_profile_id is null then raise exception 'profile recipient is required'; end if;
  insert into public.automation_rules(firm_id, name, trigger, conditions, recipient_type, recipient_profile_id, channel, action, throttle_minutes, created_by_profile_id) values(m.firm_id, trim(p_name), p_trigger, coalesce(p_conditions, '{}'::jsonb), p_recipient_type, p_recipient_profile_id, p_channel, p_action, coalesce(p_throttle_minutes, 1440), auth.uid()) returning id into result;
  insert into public.audit_events(firm_id, actor_profile_id, actor_user_id, action, entity_table, entity_id, metadata) values(m.firm_id, auth.uid(), auth.uid(), 'automation.rule_created', 'automation_rules', result, jsonb_build_object('trigger', p_trigger)); return result;
end; $$;

create or replace function public.set_automation_rule_state(p_rule_id uuid, p_enabled boolean)
returns void language plpgsql security definer set search_path = public, auth as $$
declare m public.firm_memberships; r public.automation_rules;
begin
  m := public.team_active_membership(); if not public.has_firm_role(m.firm_id, array['OWNER','PARTNER','MANAGER']::public.firm_role[]) then raise exception 'manager automation permission required' using errcode = '42501'; end if;
  select * into r from public.automation_rules where id = p_rule_id and firm_id = m.firm_id for update; if r.id is null then raise exception 'automation rule not found'; end if;
  update public.automation_rules set enabled = p_enabled, activated_by_profile_id = case when p_enabled then auth.uid() else null end, activated_at = case when p_enabled then timezone('utc', now()) else null end, paused_at = case when p_enabled then null else timezone('utc', now()) end where id = r.id;
  insert into public.audit_events(firm_id, actor_profile_id, actor_user_id, action, entity_table, entity_id, metadata) values(m.firm_id, auth.uid(), auth.uid(), case when p_enabled then 'automation.rule_activated' else 'automation.rule_paused' end, 'automation_rules', r.id, '{}'::jsonb);
end; $$;

create or replace function public.set_automation_kill_switch(p_paused boolean, p_safe_preview_mode boolean default true)
returns void language plpgsql security definer set search_path = public, auth as $$
declare m public.firm_memberships;
begin
  m := public.team_active_membership(); if not public.has_firm_role(m.firm_id, array['OWNER','PARTNER','MANAGER']::public.firm_role[]) then raise exception 'manager automation permission required' using errcode = '42501'; end if;
  insert into public.automation_settings(firm_id, paused, safe_preview_mode, updated_by_profile_id) values(m.firm_id, p_paused, p_safe_preview_mode, auth.uid()) on conflict (firm_id) do update set paused = excluded.paused, safe_preview_mode = excluded.safe_preview_mode, updated_by_profile_id = excluded.updated_by_profile_id, updated_at = timezone('utc', now());
  insert into public.audit_events(firm_id, actor_profile_id, actor_user_id, action, entity_table, metadata) values(m.firm_id, auth.uid(), auth.uid(), 'automation.settings_updated', 'automation_settings', jsonb_build_object('paused', p_paused, 'safe_preview_mode', p_safe_preview_mode));
end; $$;

create or replace function public.set_notification_preferences(p_opt_out_all boolean, p_email_enabled boolean, p_whatsapp_enabled boolean, p_preferred_channel text)
returns void language plpgsql security definer set search_path = public, auth as $$
declare m public.firm_memberships;
begin
  m := public.team_active_membership();
  if m.firm_id is null then raise exception 'active firm membership required' using errcode = '42501'; end if;
  if p_preferred_channel not in ('INTERNAL','EMAIL','WHATSAPP') then raise exception 'invalid notification channel'; end if;
  insert into public.notification_preferences(firm_id, profile_id, opt_out_all, email_enabled, whatsapp_enabled, preferred_channel) values(m.firm_id, auth.uid(), p_opt_out_all, p_email_enabled, p_whatsapp_enabled, p_preferred_channel)
  on conflict (firm_id, profile_id) do update set opt_out_all = excluded.opt_out_all, email_enabled = excluded.email_enabled, whatsapp_enabled = excluded.whatsapp_enabled, preferred_channel = excluded.preferred_channel, updated_at = timezone('utc', now());
end; $$;

create or replace function public.enqueue_automation_event(p_firm_id uuid, p_event_type text, p_subject_table text, p_subject_id uuid, p_event_key text, p_payload jsonb)
returns uuid language plpgsql security definer set search_path = public as $$
declare result uuid;
begin
  insert into public.automation_events(firm_id, event_type, subject_table, subject_id, event_key, payload) values(p_firm_id, p_event_type, p_subject_table, p_subject_id, p_event_key, coalesce(p_payload, '{}'::jsonb)) on conflict (firm_id, event_key) do update set payload = excluded.payload returning id into result;
  return result;
end; $$;

create or replace function public.emit_task_assignment_event()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.automation_delivery_id is null and new.assignee_profile_id is not null and (tg_op = 'INSERT' or new.assignee_profile_id is distinct from old.assignee_profile_id) then
    perform public.enqueue_automation_event(new.firm_id, 'TASK_ASSIGNED', 'tasks', new.id, 'task-assigned:' || new.id::text || ':' || new.assignee_profile_id::text, jsonb_build_object('task_id', new.id, 'assignee_profile_id', new.assignee_profile_id, 'owner_profile_id', new.owner_profile_id, 'title', new.title));
  end if;
  return new;
end; $$;

create trigger tasks_automation_assignment_event after insert or update of assignee_profile_id on public.tasks for each row execute function public.emit_task_assignment_event();

create or replace function public.enqueue_due_automation_events(p_firm_id uuid default null)
returns integer language plpgsql security definer set search_path = public as $$
declare f record; local_today date; n integer := 0; r record;
begin
  for f in select id, timezone from public.firms where archived_at is null and approval_status = 'ACTIVE' and (p_firm_id is null or id = p_firm_id) loop
    local_today := (now() at time zone coalesce(f.timezone, 'Asia/Kolkata'))::date;
    for r in select cp.id, cp.due_date, cp.assigned_to_profile_id from public.compliance_periods cp where cp.firm_id = f.id and cp.status not in ('FILED','CANCELLED') and cp.due_date between local_today and local_today + 7 loop
      perform public.enqueue_automation_event(f.id, 'COMPLIANCE_DUE_SOON', 'compliance_periods', r.id, 'compliance-due-soon:' || r.id::text || ':' || local_today::text, jsonb_build_object('compliance_period_id', r.id, 'due_date', r.due_date, 'assigned_to_profile_id', r.assigned_to_profile_id)); n := n + 1;
    end loop;
    for r in select t.id, t.due_date, t.assignee_profile_id, t.owner_profile_id from public.tasks t where t.firm_id = f.id and t.archived_at is null and t.status not in ('COMPLETED','CANCELLED') and t.due_date < local_today loop
      perform public.enqueue_automation_event(f.id, 'TASK_OVERDUE', 'tasks', r.id, 'task-overdue:' || r.id::text || ':' || local_today::text, jsonb_build_object('task_id', r.id, 'due_date', r.due_date, 'assignee_profile_id', r.assignee_profile_id, 'owner_profile_id', r.owner_profile_id)); n := n + 1;
    end loop;
    for r in select i.id, i.due_date, i.created_by_profile_id from public.invoices i where i.firm_id = f.id and i.status = 'ISSUED' and i.due_date < local_today and (select coalesce(sum(case when pe.entry_type = 'PAYMENT' then pe.amount else -pe.amount end), 0) from public.payment_entries pe where pe.firm_id = f.id and pe.invoice_id = i.id) < i.total loop
      perform public.enqueue_automation_event(f.id, 'INVOICE_OVERDUE', 'invoices', r.id, 'invoice-overdue:' || r.id::text || ':' || local_today::text, jsonb_build_object('invoice_id', r.id, 'due_date', r.due_date, 'owner_profile_id', r.created_by_profile_id)); n := n + 1;
    end loop;
    for r in select fup.id, fup.due_date, fup.assigned_to_profile_id from public.lead_follow_ups fup where fup.firm_id = f.id and fup.status = 'OPEN' and fup.due_date <= local_today loop
      perform public.enqueue_automation_event(f.id, 'LEAD_FOLLOW_UP_DUE', 'lead_follow_ups', r.id, 'lead-follow-up-due:' || r.id::text || ':' || local_today::text, jsonb_build_object('follow_up_id', r.id, 'due_date', r.due_date, 'assigned_to_profile_id', r.assigned_to_profile_id)); n := n + 1;
    end loop;
  end loop;
  return n;
end; $$;

create or replace function public.claim_automation_events(p_worker_id text, p_limit integer default 25)
returns setof public.automation_events language plpgsql security definer set search_path = public as $$
begin
  update public.automation_events evt set status = 'DEAD_LETTER', lease_until = null, last_error = coalesce(last_error, 'maximum event attempts exceeded') where evt.status in ('FAILED','PROCESSING') and evt.attempts >= coalesce((select max_attempts from public.automation_settings where firm_id = evt.firm_id), 5);
  return query with claimed as (
    select id from public.automation_events evt where evt.status in ('PENDING','FAILED') and evt.attempts < coalesce((select max_attempts from public.automation_settings where firm_id = evt.firm_id), 5) and evt.available_at <= timezone('utc', now()) and (evt.lease_until is null or evt.lease_until < timezone('utc', now())) order by evt.available_at, evt.created_at for update skip locked limit greatest(1, least(p_limit, 100))
  ) update public.automation_events e set status = 'PROCESSING', attempts = e.attempts + 1, lease_until = timezone('utc', now()) + interval '5 minutes', leased_by = p_worker_id from claimed where e.id = claimed.id returning e.*;
end; $$;

revoke all on function public.team_active_membership(), public.team_local_date(uuid), public.start_attendance(date,text), public.stop_attendance(uuid,timestamptz), public.create_leave_request(text,date,date,text), public.decide_leave_request(uuid,text,text), public.add_timesheet_entry(date,integer,text,uuid,uuid), public.lock_timesheet_entry(uuid), public.create_reimbursement(numeric,date,text), public.decide_reimbursement(uuid,text,text), public.create_automation_rule(text,text,jsonb,text,uuid,text,text,integer), public.set_automation_rule_state(uuid,boolean), public.set_automation_kill_switch(boolean,boolean), public.set_notification_preferences(boolean,boolean,boolean,text) from public;
grant execute on function public.team_active_membership(), public.team_local_date(uuid), public.start_attendance(date,text), public.stop_attendance(uuid,timestamptz), public.create_leave_request(text,date,date,text), public.decide_leave_request(uuid,text,text), public.add_timesheet_entry(date,integer,text,uuid,uuid), public.lock_timesheet_entry(uuid), public.create_reimbursement(numeric,date,text), public.decide_reimbursement(uuid,text,text), public.create_automation_rule(text,text,jsonb,text,uuid,text,text,integer), public.set_automation_rule_state(uuid,boolean), public.set_automation_kill_switch(boolean,boolean), public.set_notification_preferences(boolean,boolean,boolean,text) to authenticated, service_role;
revoke all on function public.enqueue_automation_event(uuid,text,text,uuid,text,jsonb), public.enqueue_due_automation_events(uuid), public.claim_automation_events(text,integer) from public;
grant execute on function public.enqueue_automation_event(uuid,text,text,uuid,text,jsonb), public.enqueue_due_automation_events(uuid), public.claim_automation_events(text,integer) to service_role;

alter table public.attendance_sessions enable row level security; alter table public.attendance_sessions force row level security;
alter table public.leave_requests enable row level security; alter table public.leave_requests force row level security;
alter table public.timesheet_entries enable row level security; alter table public.timesheet_entries force row level security;
alter table public.employee_reimbursements enable row level security; alter table public.employee_reimbursements force row level security;
alter table public.notification_preferences enable row level security; alter table public.notification_preferences force row level security;
alter table public.notifications enable row level security; alter table public.notifications force row level security;
alter table public.automation_settings enable row level security; alter table public.automation_settings force row level security;
alter table public.automation_rules enable row level security; alter table public.automation_rules force row level security;
alter table public.automation_events enable row level security; alter table public.automation_events force row level security;
alter table public.automation_deliveries enable row level security; alter table public.automation_deliveries force row level security;
alter table public.automation_job_history enable row level security; alter table public.automation_job_history force row level security;

create policy attendance_member on public.attendance_sessions for select to authenticated using (public.is_firm_member(firm_id));
create policy leave_member on public.leave_requests for select to authenticated using (public.is_firm_member(firm_id));
create policy timesheet_member on public.timesheet_entries for select to authenticated using (public.is_firm_member(firm_id));
create policy reimbursement_member on public.employee_reimbursements for select to authenticated using (public.is_firm_member(firm_id));
create policy preference_member on public.notification_preferences for select to authenticated using (public.is_firm_member(firm_id) and profile_id = auth.uid());
create policy notification_recipient on public.notifications for select to authenticated using (public.is_firm_member(firm_id) and recipient_profile_id = auth.uid());
create policy automation_settings_manager on public.automation_settings for select to authenticated using (public.has_firm_role(firm_id, array['OWNER','PARTNER','MANAGER']::public.firm_role[]));
create policy automation_rules_manager on public.automation_rules for select to authenticated using (public.has_firm_role(firm_id, array['OWNER','PARTNER','MANAGER']::public.firm_role[]));
create policy automation_events_manager on public.automation_events for select to authenticated using (public.has_firm_role(firm_id, array['OWNER','PARTNER','MANAGER']::public.firm_role[]));
create policy automation_deliveries_manager on public.automation_deliveries for select to authenticated using (public.has_firm_role(firm_id, array['OWNER','PARTNER','MANAGER']::public.firm_role[]));
create policy automation_jobs_manager on public.automation_job_history for select to authenticated using (firm_id is null or public.has_firm_role(firm_id, array['OWNER','PARTNER','MANAGER']::public.firm_role[]));

grant select, insert, update on public.attendance_sessions, public.leave_requests, public.timesheet_entries, public.employee_reimbursements, public.notification_preferences, public.notifications, public.automation_settings, public.automation_rules, public.automation_events, public.automation_deliveries, public.automation_job_history to authenticated;
grant all on public.attendance_sessions, public.leave_requests, public.timesheet_entries, public.employee_reimbursements, public.notification_preferences, public.notifications, public.automation_settings, public.automation_rules, public.automation_events, public.automation_deliveries, public.automation_job_history to service_role;

create trigger attendance_set_updated_at before update on public.attendance_sessions for each row execute function public.set_updated_at();
create trigger leave_set_updated_at before update on public.leave_requests for each row execute function public.set_updated_at();
create trigger timesheet_set_updated_at before update on public.timesheet_entries for each row execute function public.set_updated_at();
create trigger reimbursement_set_updated_at before update on public.employee_reimbursements for each row execute function public.set_updated_at();
create trigger automation_rules_set_updated_at before update on public.automation_rules for each row execute function public.set_updated_at();

comment on table public.automation_events is 'Transactional outbox. Only trusted workers claim and process rows.';
comment on table public.automation_deliveries is 'Per event/rule/recipient idempotency ledger. External channels remain preview-only in Stage 9.';
comment on table public.attendance_sessions is 'Attendance timestamps only; no geolocation is captured.';

commit;
