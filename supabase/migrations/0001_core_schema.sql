-- Northstar Practice Stage 2: core tenant-scoped schema.
-- This migration is intentionally independent of any original product schema.

begin;

create extension if not exists pgcrypto;

do $$
begin
  create type public.firm_role as enum ('OWNER', 'PARTNER', 'MANAGER', 'STAFF');
exception
  when duplicate_object then null;
end
$$;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;

create or replace function public.prevent_audit_event_mutation()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  raise exception 'audit_events is append-only';
end;
$$;

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null check (char_length(trim(display_name)) between 1 and 160),
  avatar_path text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table public.firms (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(trim(name)) between 1 and 160),
  legal_name text check (legal_name is null or char_length(trim(legal_name)) between 1 and 240),
  plan text not null default 'STARTER' check (plan in ('STARTER', 'GROWTH', 'SCALE')),
  timezone text not null default 'Asia/Kolkata' check (char_length(trim(timezone)) between 1 and 80),
  settings jsonb not null default '{}'::jsonb check (jsonb_typeof(settings) = 'object'),
  created_by_profile_id uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  archived_at timestamptz,
  unique (id)
);

create table public.firm_memberships (
  id uuid primary key default gen_random_uuid(),
  firm_id uuid not null,
  profile_id uuid not null,
  role public.firm_role not null,
  status text not null default 'ACTIVE' check (status in ('ACTIVE', 'INVITED', 'SUSPENDED')),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  archived_at timestamptz,
  unique (firm_id, id),
  unique (firm_id, profile_id),
  foreign key (firm_id) references public.firms(id) on delete restrict,
  foreign key (profile_id) references public.profiles(id) on delete restrict
);

create table public.services (
  id uuid primary key default gen_random_uuid(),
  firm_id uuid not null,
  name text not null check (char_length(trim(name)) between 1 and 160),
  code text not null check (code ~ '^[A-Z0-9][A-Z0-9_-]{1,31}$'),
  description text,
  is_active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  archived_at timestamptz,
  unique (firm_id, id),
  unique (firm_id, code),
  foreign key (firm_id) references public.firms(id) on delete restrict
);

create table public.clients (
  id uuid primary key default gen_random_uuid(),
  firm_id uuid not null,
  owner_profile_id uuid,
  created_by_profile_id uuid,
  client_code text not null check (client_code ~ '^[A-Z0-9][A-Z0-9_-]{1,31}$'),
  legal_name text not null check (char_length(trim(legal_name)) between 1 and 240),
  display_name text not null check (char_length(trim(display_name)) between 1 and 160),
  entity_type text not null default 'OTHER' check (entity_type in ('INDIVIDUAL', 'COMPANY', 'LLP', 'PARTNERSHIP', 'TRUST', 'OTHER')),
  tax_identifier text check (tax_identifier is null or char_length(trim(tax_identifier)) between 1 and 80),
  status text not null default 'ACTIVE' check (status in ('ACTIVE', 'INACTIVE')),
  notes text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  archived_at timestamptz,
  unique (firm_id, id),
  unique (firm_id, client_code),
  foreign key (firm_id) references public.firms(id) on delete restrict,
  foreign key (firm_id, owner_profile_id) references public.firm_memberships(firm_id, profile_id) on delete restrict,
  foreign key (firm_id, created_by_profile_id) references public.firm_memberships(firm_id, profile_id) on delete restrict
);

create table public.client_contacts (
  id uuid primary key default gen_random_uuid(),
  firm_id uuid not null,
  client_id uuid not null,
  created_by_profile_id uuid,
  full_name text not null check (char_length(trim(full_name)) between 1 and 160),
  email text check (email is null or char_length(trim(email)) between 3 and 320),
  phone text check (phone is null or char_length(trim(phone)) between 3 and 40),
  designation text,
  is_primary boolean not null default false,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  archived_at timestamptz,
  unique (firm_id, id),
  foreign key (firm_id) references public.firms(id) on delete restrict,
  foreign key (firm_id, client_id) references public.clients(firm_id, id) on delete restrict,
  foreign key (firm_id, created_by_profile_id) references public.firm_memberships(firm_id, profile_id) on delete restrict
);

create table public.task_templates (
  id uuid primary key default gen_random_uuid(),
  firm_id uuid not null,
  service_id uuid,
  name text not null check (char_length(trim(name)) between 1 and 160),
  description text,
  default_priority text not null default 'MEDIUM' check (default_priority in ('LOW', 'MEDIUM', 'HIGH', 'URGENT')),
  is_active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  archived_at timestamptz,
  unique (firm_id, id),
  foreign key (firm_id) references public.firms(id) on delete restrict,
  foreign key (firm_id, service_id) references public.services(firm_id, id) on delete restrict
);

create table public.tasks (
  id uuid primary key default gen_random_uuid(),
  firm_id uuid not null,
  client_id uuid,
  service_id uuid,
  template_id uuid,
  owner_profile_id uuid,
  assignee_profile_id uuid,
  reviewer_profile_id uuid,
  created_by_profile_id uuid,
  title text not null check (char_length(trim(title)) between 1 and 240),
  description text,
  status text not null default 'OPEN' check (status in ('OPEN', 'IN_PROGRESS', 'WAITING', 'IN_REVIEW', 'COMPLETED', 'CANCELLED')),
  priority text not null default 'MEDIUM' check (priority in ('LOW', 'MEDIUM', 'HIGH', 'URGENT')),
  due_date date,
  completed_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  archived_at timestamptz,
  unique (firm_id, id),
  foreign key (firm_id) references public.firms(id) on delete restrict,
  foreign key (firm_id, client_id) references public.clients(firm_id, id) on delete restrict,
  foreign key (firm_id, service_id) references public.services(firm_id, id) on delete restrict,
  foreign key (firm_id, template_id) references public.task_templates(firm_id, id) on delete restrict,
  foreign key (firm_id, owner_profile_id) references public.firm_memberships(firm_id, profile_id) on delete restrict,
  foreign key (firm_id, assignee_profile_id) references public.firm_memberships(firm_id, profile_id) on delete restrict,
  foreign key (firm_id, reviewer_profile_id) references public.firm_memberships(firm_id, profile_id) on delete restrict,
  foreign key (firm_id, created_by_profile_id) references public.firm_memberships(firm_id, profile_id) on delete restrict,
  check (completed_at is null or status = 'COMPLETED')
);

create table public.task_checklist_items (
  id uuid primary key default gen_random_uuid(),
  firm_id uuid not null,
  task_id uuid not null,
  completed_by_profile_id uuid,
  position integer not null default 0 check (position >= 0),
  label text not null check (char_length(trim(label)) between 1 and 240),
  is_completed boolean not null default false,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  archived_at timestamptz,
  unique (firm_id, id),
  foreign key (firm_id) references public.firms(id) on delete restrict,
  foreign key (firm_id, task_id) references public.tasks(firm_id, id) on delete restrict,
  foreign key (firm_id, completed_by_profile_id) references public.firm_memberships(firm_id, profile_id) on delete restrict
);

create table public.task_comments (
  id uuid primary key default gen_random_uuid(),
  firm_id uuid not null,
  task_id uuid not null,
  author_profile_id uuid not null,
  body text not null check (char_length(trim(body)) between 1 and 10000),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  foreign key (firm_id) references public.firms(id) on delete restrict,
  foreign key (firm_id, task_id) references public.tasks(firm_id, id) on delete restrict,
  foreign key (firm_id, author_profile_id) references public.firm_memberships(firm_id, profile_id) on delete restrict
);

create table public.compliance_obligations (
  id uuid primary key default gen_random_uuid(),
  firm_id uuid not null,
  client_id uuid not null,
  service_id uuid,
  created_by_profile_id uuid,
  code text not null check (code ~ '^[A-Z0-9][A-Z0-9_-]{1,31}$'),
  name text not null check (char_length(trim(name)) between 1 and 200),
  category text not null check (category in ('GST', 'TDS', 'INCOME_TAX', 'MCA', 'OTHER')),
  frequency text not null default 'CONFIGURED' check (char_length(trim(frequency)) between 1 and 40),
  is_active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  archived_at timestamptz,
  unique (firm_id, id),
  unique (firm_id, client_id, code),
  foreign key (firm_id) references public.firms(id) on delete restrict,
  foreign key (firm_id, client_id) references public.clients(firm_id, id) on delete restrict,
  foreign key (firm_id, service_id) references public.services(firm_id, id) on delete restrict,
  foreign key (firm_id, created_by_profile_id) references public.firm_memberships(firm_id, profile_id) on delete restrict
);

create table public.compliance_periods (
  id uuid primary key default gen_random_uuid(),
  firm_id uuid not null,
  obligation_id uuid not null,
  assigned_to_profile_id uuid,
  reviewer_profile_id uuid,
  period_start date not null,
  period_end date not null,
  due_date date not null,
  status text not null default 'UPCOMING' check (status in ('UPCOMING', 'IN_PROGRESS', 'READY_FOR_REVIEW', 'FILED', 'OVERDUE', 'CANCELLED')),
  reference text,
  completed_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  archived_at timestamptz,
  unique (firm_id, id),
  unique (firm_id, obligation_id, period_start, period_end),
  foreign key (firm_id) references public.firms(id) on delete restrict,
  foreign key (firm_id, obligation_id) references public.compliance_obligations(firm_id, id) on delete restrict,
  foreign key (firm_id, assigned_to_profile_id) references public.firm_memberships(firm_id, profile_id) on delete restrict,
  foreign key (firm_id, reviewer_profile_id) references public.firm_memberships(firm_id, profile_id) on delete restrict,
  check (period_end >= period_start),
  check (completed_at is null or status = 'FILED')
);

create table public.documents (
  id uuid primary key default gen_random_uuid(),
  firm_id uuid not null,
  client_id uuid,
  task_id uuid,
  compliance_period_id uuid,
  uploaded_by_profile_id uuid not null,
  storage_path text not null check (char_length(trim(storage_path)) between 1 and 1024),
  file_name text not null check (char_length(trim(file_name)) between 1 and 255),
  mime_type text,
  byte_size bigint check (byte_size is null or byte_size >= 0),
  checksum text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  archived_at timestamptz,
  unique (firm_id, id),
  unique (firm_id, storage_path),
  foreign key (firm_id) references public.firms(id) on delete restrict,
  foreign key (firm_id, client_id) references public.clients(firm_id, id) on delete restrict,
  foreign key (firm_id, task_id) references public.tasks(firm_id, id) on delete restrict,
  foreign key (firm_id, compliance_period_id) references public.compliance_periods(firm_id, id) on delete restrict,
  foreign key (firm_id, uploaded_by_profile_id) references public.firm_memberships(firm_id, profile_id) on delete restrict,
  check (client_id is not null or task_id is not null or compliance_period_id is not null)
);

create table public.audit_events (
  id uuid primary key default gen_random_uuid(),
  firm_id uuid not null,
  actor_profile_id uuid,
  action text not null check (action ~ '^[a-z][a-z0-9_.-]{1,80}$'),
  entity_table text not null check (entity_table ~ '^[a-z][a-z0-9_]{1,80}$'),
  entity_id uuid,
  metadata jsonb not null default '{}'::jsonb check (jsonb_typeof(metadata) = 'object'),
  created_at timestamptz not null default timezone('utc', now()),
  foreign key (firm_id) references public.firms(id) on delete restrict,
  foreign key (firm_id, actor_profile_id) references public.firm_memberships(firm_id, profile_id) on delete restrict
);

create trigger audit_events_append_only before update or delete on public.audit_events
for each row execute function public.prevent_audit_event_mutation();

create index firms_active_idx on public.firms (archived_at, created_at desc);
create index firm_memberships_profile_idx on public.firm_memberships (profile_id, status);
create index firm_memberships_firm_role_idx on public.firm_memberships (firm_id, role, status);
create index clients_firm_status_idx on public.clients (firm_id, status, archived_at);
create index clients_firm_owner_idx on public.clients (firm_id, owner_profile_id);
create index client_contacts_firm_client_idx on public.client_contacts (firm_id, client_id, archived_at);
create index services_firm_active_idx on public.services (firm_id, is_active, archived_at);
create index task_templates_firm_service_idx on public.task_templates (firm_id, service_id, is_active);
create index tasks_firm_status_due_idx on public.tasks (firm_id, status, due_date);
create index tasks_firm_client_idx on public.tasks (firm_id, client_id, archived_at);
create index tasks_firm_assignee_idx on public.tasks (firm_id, assignee_profile_id, status);
create index task_checklist_items_task_position_idx on public.task_checklist_items (firm_id, task_id, position);
create index task_comments_task_created_idx on public.task_comments (firm_id, task_id, created_at);
create index compliance_obligations_firm_client_idx on public.compliance_obligations (firm_id, client_id, is_active);
create index compliance_periods_firm_status_due_idx on public.compliance_periods (firm_id, status, due_date);
create index compliance_periods_firm_assignee_idx on public.compliance_periods (firm_id, assigned_to_profile_id, status);
create index documents_firm_client_idx on public.documents (firm_id, client_id, archived_at);
create index documents_firm_task_idx on public.documents (firm_id, task_id, archived_at);
create index audit_events_firm_created_idx on public.audit_events (firm_id, created_at desc);
create index audit_events_entity_idx on public.audit_events (firm_id, entity_table, entity_id, created_at desc);

create trigger profiles_set_updated_at before update on public.profiles for each row execute function public.set_updated_at();
create trigger firms_set_updated_at before update on public.firms for each row execute function public.set_updated_at();
create trigger firm_memberships_set_updated_at before update on public.firm_memberships for each row execute function public.set_updated_at();
create trigger services_set_updated_at before update on public.services for each row execute function public.set_updated_at();
create trigger clients_set_updated_at before update on public.clients for each row execute function public.set_updated_at();
create trigger client_contacts_set_updated_at before update on public.client_contacts for each row execute function public.set_updated_at();
create trigger task_templates_set_updated_at before update on public.task_templates for each row execute function public.set_updated_at();
create trigger tasks_set_updated_at before update on public.tasks for each row execute function public.set_updated_at();
create trigger task_checklist_items_set_updated_at before update on public.task_checklist_items for each row execute function public.set_updated_at();
create trigger task_comments_set_updated_at before update on public.task_comments for each row execute function public.set_updated_at();
create trigger compliance_obligations_set_updated_at before update on public.compliance_obligations for each row execute function public.set_updated_at();
create trigger compliance_periods_set_updated_at before update on public.compliance_periods for each row execute function public.set_updated_at();
create trigger documents_set_updated_at before update on public.documents for each row execute function public.set_updated_at();

comment on table public.firms is 'Tenant root. Firm settings are mutable only by owner, partner, or manager policies.';
comment on table public.audit_events is 'Append-only service-layer audit trail. No update/delete policy is intentionally defined.';
comment on column public.documents.storage_path is 'Private bucket path, conventionally <firm_id>/<object-key>.';

commit;
