-- Stage 7: firm-scoped lead pipeline, proposal versions, demo-only events,
-- and atomic conversion into the existing client master.
-- No email, e-signature, marketing automation, or external integration is used.
begin;

create table if not exists public.leads (
  id uuid primary key default gen_random_uuid(),
  firm_id uuid not null,
  owner_profile_id uuid,
  created_by_profile_id uuid,
  name text not null check (char_length(trim(name)) between 1 and 160),
  company_name text check (company_name is null or char_length(trim(company_name)) between 1 and 240),
  email text check (email is null or email ~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$'),
  mobile text check (mobile is null or mobile ~ '^[0-9+(). -]{7,30}$'),
  email_normalized text,
  mobile_normalized text,
  source text not null default 'OTHER' check (char_length(trim(source)) between 1 and 80),
  score integer check (score is null or score between 0 and 100),
  stage text not null default 'LEAD' check (stage in ('LEAD', 'FOLLOW_UP', 'QUOTATION', 'PROPOSAL', 'WON', 'CLIENT')),
  status text not null default 'OPEN' check (status in ('OPEN', 'LOST', 'CONVERTED')),
  next_follow_up_date date,
  notes text,
  converted_client_id uuid,
  converted_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  archived_at timestamptz,
  unique (firm_id, id),
  foreign key (firm_id) references public.firms(id) on delete restrict,
  foreign key (firm_id, owner_profile_id) references public.firm_memberships(firm_id, profile_id) on delete restrict,
  foreign key (firm_id, created_by_profile_id) references public.firm_memberships(firm_id, profile_id) on delete restrict,
  foreign key (firm_id, converted_client_id) references public.clients(firm_id, id) on delete restrict
);

create table if not exists public.lead_contacts (
  id uuid primary key default gen_random_uuid(),
  firm_id uuid not null,
  lead_id uuid not null,
  full_name text not null check (char_length(trim(full_name)) between 1 and 160),
  email text check (email is null or email ~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$'),
  mobile text check (mobile is null or mobile ~ '^[0-9+(). -]{7,30}$'),
  designation text,
  is_primary boolean not null default false,
  created_by_profile_id uuid,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  archived_at timestamptz,
  unique (firm_id, id),
  foreign key (firm_id) references public.firms(id) on delete restrict,
  foreign key (firm_id, lead_id) references public.leads(firm_id, id) on delete cascade,
  foreign key (firm_id, created_by_profile_id) references public.firm_memberships(firm_id, profile_id) on delete restrict
);

create table if not exists public.lead_activities (
  id uuid primary key default gen_random_uuid(),
  firm_id uuid not null,
  lead_id uuid not null,
  actor_profile_id uuid not null,
  activity_type text not null check (activity_type in ('NOTE', 'STAGE_CHANGED', 'FOLLOW_UP_CREATED', 'FOLLOW_UP_COMPLETED', 'CONTACT_ADDED', 'PROPOSAL_CREATED', 'PROPOSAL_UPDATED', 'CONVERTED')),
  body text,
  metadata jsonb not null default '{}'::jsonb check (jsonb_typeof(metadata) = 'object'),
  created_at timestamptz not null default timezone('utc', now()),
  foreign key (firm_id) references public.firms(id) on delete restrict,
  foreign key (firm_id, lead_id) references public.leads(firm_id, id) on delete cascade,
  foreign key (firm_id, actor_profile_id) references public.firm_memberships(firm_id, profile_id) on delete restrict
);

create table if not exists public.lead_follow_ups (
  id uuid primary key default gen_random_uuid(),
  firm_id uuid not null,
  lead_id uuid not null,
  assigned_to_profile_id uuid,
  due_date date not null,
  reminder_date date,
  title text not null check (char_length(trim(title)) between 1 and 200),
  note text,
  status text not null default 'OPEN' check (status in ('OPEN', 'DONE', 'CANCELLED')),
  completed_at timestamptz,
  created_by_profile_id uuid not null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  foreign key (firm_id) references public.firms(id) on delete restrict,
  foreign key (firm_id, lead_id) references public.leads(firm_id, id) on delete cascade,
  foreign key (firm_id, assigned_to_profile_id) references public.firm_memberships(firm_id, profile_id) on delete restrict,
  foreign key (firm_id, created_by_profile_id) references public.firm_memberships(firm_id, profile_id) on delete restrict,
  check (reminder_date is null or reminder_date <= due_date)
);

create table if not exists public.proposals (
  id uuid primary key default gen_random_uuid(),
  firm_id uuid not null,
  lead_id uuid not null,
  title text not null check (char_length(trim(title)) between 1 and 200),
  status text not null default 'DRAFT' check (status in ('DRAFT', 'PREVIEW', 'SENT_DEMO', 'VIEWED', 'ACTIONED', 'ACCEPTED', 'REJECTED', 'EXPIRED', 'CONVERTED')),
  current_version_id uuid,
  created_by_profile_id uuid not null,
  accepted_at timestamptz,
  rejected_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (firm_id, id),
  foreign key (firm_id) references public.firms(id) on delete restrict,
  foreign key (firm_id, lead_id) references public.leads(firm_id, id) on delete cascade,
  foreign key (firm_id, created_by_profile_id) references public.firm_memberships(firm_id, profile_id) on delete restrict
);

create table if not exists public.proposal_versions (
  id uuid primary key default gen_random_uuid(),
  firm_id uuid not null,
  proposal_id uuid not null,
  version_number integer not null check (version_number > 0),
  service_scope text not null check (char_length(trim(service_scope)) between 1 and 20000),
  validity_date date not null,
  fee_minor numeric(18,0) not null check (fee_minor >= 0),
  tax_estimate_minor numeric(18,0) not null default 0 check (tax_estimate_minor >= 0),
  currency char(3) not null check (currency ~ '^[A-Z]{3}$'),
  notes text,
  created_by_profile_id uuid not null,
  created_at timestamptz not null default timezone('utc', now()),
  unique (firm_id, id),
  unique (firm_id, proposal_id, version_number),
  foreign key (firm_id) references public.firms(id) on delete restrict,
  foreign key (firm_id, proposal_id) references public.proposals(firm_id, id) on delete cascade,
  foreign key (firm_id, created_by_profile_id) references public.firm_memberships(firm_id, profile_id) on delete restrict
);

alter table public.proposals add constraint proposals_current_version_fk foreign key (firm_id, current_version_id) references public.proposal_versions(firm_id, id) on delete restrict;

create table if not exists public.proposal_events (
  id uuid primary key default gen_random_uuid(),
  firm_id uuid not null,
  proposal_id uuid not null,
  actor_profile_id uuid,
  event_type text not null check (event_type in ('PREVIEWED', 'DEMO_SENT', 'VIEWED', 'ACTIONED', 'ACCEPTED', 'REJECTED', 'EXPIRED', 'VERSION_CREATED', 'CONVERTED')),
  metadata jsonb not null default '{}'::jsonb check (jsonb_typeof(metadata) = 'object'),
  created_at timestamptz not null default timezone('utc', now()),
  foreign key (firm_id) references public.firms(id) on delete restrict,
  foreign key (firm_id, proposal_id) references public.proposals(firm_id, id) on delete cascade,
  foreign key (firm_id, actor_profile_id) references public.firm_memberships(firm_id, profile_id) on delete restrict
);

create unique index if not exists leads_firm_open_email_unique on public.leads (firm_id, email_normalized) where archived_at is null and status = 'OPEN' and email_normalized is not null;
create unique index if not exists leads_firm_open_mobile_unique on public.leads (firm_id, mobile_normalized) where archived_at is null and status = 'OPEN' and mobile_normalized is not null;
create index if not exists leads_firm_pipeline_idx on public.leads (firm_id, status, stage, next_follow_up_date, updated_at desc);
create index if not exists leads_firm_owner_idx on public.leads (firm_id, owner_profile_id, status, stage);
create index if not exists leads_firm_search_idx on public.leads (firm_id, email_normalized, mobile_normalized, company_name);
create index if not exists lead_contacts_firm_lead_idx on public.lead_contacts (firm_id, lead_id, archived_at);
create index if not exists lead_activities_firm_lead_created_idx on public.lead_activities (firm_id, lead_id, created_at desc);
create index if not exists lead_follow_ups_firm_due_idx on public.lead_follow_ups (firm_id, status, due_date, assigned_to_profile_id);
create index if not exists proposals_firm_lead_status_idx on public.proposals (firm_id, lead_id, status, updated_at desc);
create index if not exists proposal_versions_firm_proposal_idx on public.proposal_versions (firm_id, proposal_id, version_number desc);
create index if not exists proposal_events_firm_proposal_created_idx on public.proposal_events (firm_id, proposal_id, created_at desc);

create trigger leads_set_updated_at before update on public.leads for each row execute function public.set_updated_at();
create trigger lead_contacts_set_updated_at before update on public.lead_contacts for each row execute function public.set_updated_at();
create trigger lead_follow_ups_set_updated_at before update on public.lead_follow_ups for each row execute function public.set_updated_at();
create trigger proposals_set_updated_at before update on public.proposals for each row execute function public.set_updated_at();

alter table public.leads enable row level security; alter table public.leads force row level security;
alter table public.lead_contacts enable row level security; alter table public.lead_contacts force row level security;
alter table public.lead_activities enable row level security; alter table public.lead_activities force row level security;
alter table public.lead_follow_ups enable row level security; alter table public.lead_follow_ups force row level security;
alter table public.proposals enable row level security; alter table public.proposals force row level security;
alter table public.proposal_versions enable row level security; alter table public.proposal_versions force row level security;
alter table public.proposal_events enable row level security; alter table public.proposal_events force row level security;

create policy leads_select_member on public.leads for select to authenticated using (public.is_firm_member(firm_id));
create policy lead_contacts_select_member on public.lead_contacts for select to authenticated using (public.is_firm_member(firm_id));
create policy lead_activities_select_member on public.lead_activities for select to authenticated using (public.is_firm_member(firm_id));
create policy lead_follow_ups_select_member on public.lead_follow_ups for select to authenticated using (public.is_firm_member(firm_id));
create policy proposals_select_member on public.proposals for select to authenticated using (public.is_firm_member(firm_id));
create policy proposal_versions_select_member on public.proposal_versions for select to authenticated using (public.is_firm_member(firm_id));
create policy proposal_events_select_member on public.proposal_events for select to authenticated using (public.is_firm_member(firm_id));

create or replace function public.lead_active_membership() returns public.firm_memberships
language plpgsql security definer set search_path = public, auth as $$
declare m public.firm_memberships;
begin m := public.client_active_membership(); return m; end; $$;

create or replace function public.lead_can_edit(p_firm_id uuid, p_owner_id uuid) returns boolean
language sql stable security definer set search_path = public, auth as $$
select public.has_firm_role(p_firm_id, array['OWNER', 'PARTNER', 'MANAGER']::public.firm_role[]) or auth.uid() = p_owner_id;
$$;

create or replace function public.lead_local_date(p_firm_id uuid) returns date
language sql stable security definer set search_path = public as $$
select (timezone('utc', now()) at time zone coalesce((select timezone from public.firms where id = p_firm_id), 'Asia/Kolkata'))::date;
$$;

create or replace function public.lead_write_activity(p_firm_id uuid, p_lead_id uuid, p_type text, p_body text default null, p_metadata jsonb default '{}'::jsonb) returns void
language plpgsql security definer set search_path = public, auth as $$
begin
  insert into public.lead_activities(firm_id, lead_id, actor_profile_id, activity_type, body, metadata) values(p_firm_id, p_lead_id, auth.uid(), p_type, nullif(trim(p_body), ''), coalesce(p_metadata, '{}'::jsonb));
end; $$;

create or replace function public.create_lead(
  p_name text, p_company_name text, p_email text, p_mobile text, p_source text, p_score integer,
  p_owner_profile_id uuid, p_next_follow_up_date date, p_notes text
) returns uuid language plpgsql security definer set search_path = public, auth as $$
declare m public.firm_memberships; result uuid := gen_random_uuid(); existing_id uuid; clean_email text := lower(nullif(trim(p_email), '')); clean_mobile text := nullif(regexp_replace(trim(p_mobile), '[^0-9+]', '', 'g'), '');
begin
  m := public.lead_active_membership();
  if nullif(trim(p_name), '') is null then raise exception 'lead name is required'; end if;
  if clean_email is not null and clean_email !~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' then raise exception 'invalid lead email'; end if;
  if clean_mobile is not null and clean_mobile !~ '^[0-9+]{7,20}$' then raise exception 'invalid lead mobile'; end if;
  if p_score is not null and (p_score < 0 or p_score > 100) then raise exception 'lead score must be between 0 and 100'; end if;
  if p_owner_profile_id is not null and not exists(select 1 from public.firm_memberships where firm_id = m.firm_id and profile_id = p_owner_profile_id and status = 'ACTIVE' and archived_at is null) then raise exception 'lead owner is not active in this firm'; end if;
  select id into existing_id from public.leads where firm_id = m.firm_id and status = 'OPEN' and archived_at is null and ((clean_email is not null and email_normalized = clean_email) or (clean_mobile is not null and mobile_normalized = clean_mobile)) order by created_at desc limit 1 for update;
  if existing_id is not null then
    insert into public.audit_events(firm_id, actor_profile_id, actor_user_id, action, entity_table, entity_id, metadata) values(m.firm_id, auth.uid(), auth.uid(), 'lead.duplicate_ignored', 'leads', existing_id, jsonb_build_object('email_match', clean_email is not null, 'mobile_match', clean_mobile is not null));
    return existing_id;
  end if;
  insert into public.leads(id, firm_id, owner_profile_id, created_by_profile_id, name, company_name, email, mobile, email_normalized, mobile_normalized, source, score, next_follow_up_date, notes)
  values(result, m.firm_id, p_owner_profile_id, auth.uid(), trim(p_name), nullif(trim(p_company_name), ''), nullif(trim(p_email), ''), nullif(trim(p_mobile), ''), clean_email, clean_mobile, coalesce(nullif(trim(p_source), ''), 'OTHER'), p_score, p_next_follow_up_date, nullif(trim(p_notes), ''));
  insert into public.lead_contacts(firm_id, lead_id, full_name, email, mobile, is_primary, created_by_profile_id) values(m.firm_id, result, trim(p_name), nullif(trim(p_email), ''), nullif(trim(p_mobile), ''), true, auth.uid());
  perform public.lead_write_activity(m.firm_id, result, 'NOTE', 'Lead created', jsonb_build_object('source', p_source));
  insert into public.audit_events(firm_id, actor_profile_id, actor_user_id, action, entity_table, entity_id, metadata) values(m.firm_id, auth.uid(), auth.uid(), 'lead.created', 'leads', result, jsonb_build_object('source', p_source, 'owner_profile_id', p_owner_profile_id));
  return result;
exception when unique_violation then
  select id into existing_id from public.leads where firm_id = m.firm_id and status = 'OPEN' and archived_at is null and ((clean_email is not null and email_normalized = clean_email) or (clean_mobile is not null and mobile_normalized = clean_mobile)) order by created_at desc limit 1;
  if existing_id is not null then return existing_id; end if;
  raise;
end; $$;

create or replace function public.set_lead_stage(p_lead_id uuid, p_to_stage text, p_note text default null) returns void language plpgsql security definer set search_path = public, auth as $$
declare m public.firm_memberships; l public.leads; manager boolean; allowed boolean := false;
begin
  m := public.lead_active_membership();
  select * into l from public.leads where id = p_lead_id and firm_id = m.firm_id and archived_at is null for update;
  if l.id is null then raise exception 'lead not found' using errcode = 'P0002'; end if;
  if not public.lead_can_edit(m.firm_id, l.owner_profile_id) then raise exception 'permission denied for this lead' using errcode = '42501'; end if;
  manager := public.has_firm_role(m.firm_id, array['OWNER', 'PARTNER', 'MANAGER']::public.firm_role[]);
  if p_to_stage not in ('LEAD', 'FOLLOW_UP', 'QUOTATION', 'PROPOSAL', 'WON') then raise exception 'invalid lead stage'; end if;
  if p_to_stage = l.stage then return; end if;
  if manager then allowed := true;
  elsif (l.stage = 'LEAD' and p_to_stage = 'FOLLOW_UP') or (l.stage = 'FOLLOW_UP' and p_to_stage = 'QUOTATION') or (l.stage = 'QUOTATION' and p_to_stage = 'PROPOSAL') or (l.stage = 'PROPOSAL' and p_to_stage = 'WON') then allowed := true;
  end if;
  if not allowed then raise exception 'lead stage transition is not allowed' using errcode = '42501'; end if;
  update public.leads set stage = p_to_stage, status = case when status = 'LOST' then 'OPEN' else status end where id = l.id;
  perform public.lead_write_activity(m.firm_id, l.id, 'STAGE_CHANGED', p_note, jsonb_build_object('from_stage', l.stage, 'to_stage', p_to_stage));
  insert into public.audit_events(firm_id, actor_profile_id, actor_user_id, action, entity_table, entity_id, metadata) values(m.firm_id, auth.uid(), auth.uid(), 'lead.stage_changed', 'leads', l.id, jsonb_build_object('from_stage', l.stage, 'to_stage', p_to_stage));
end; $$;

create or replace function public.mark_lead_lost(p_lead_id uuid, p_note text default null) returns void language plpgsql security definer set search_path = public, auth as $$
declare m public.firm_memberships; l public.leads;
begin
  m := public.lead_active_membership(); select * into l from public.leads where id = p_lead_id and firm_id = m.firm_id and archived_at is null for update;
  if l.id is null then raise exception 'lead not found' using errcode = 'P0002'; end if;
  if not public.lead_can_edit(m.firm_id, l.owner_profile_id) then raise exception 'permission denied for this lead' using errcode = '42501'; end if;
  update public.leads set status = 'LOST' where id = l.id;
  perform public.lead_write_activity(m.firm_id, l.id, 'NOTE', p_note, jsonb_build_object('status', 'LOST'));
  insert into public.audit_events(firm_id, actor_profile_id, actor_user_id, action, entity_table, entity_id, metadata) values(m.firm_id, auth.uid(), auth.uid(), 'lead.lost', 'leads', l.id, '{}'::jsonb);
end; $$;

create or replace function public.add_lead_contact(p_lead_id uuid, p_full_name text, p_email text, p_mobile text, p_designation text, p_is_primary boolean) returns uuid language plpgsql security definer set search_path = public, auth as $$
declare m public.firm_memberships; l public.leads; result uuid := gen_random_uuid();
begin
  m := public.lead_active_membership(); select * into l from public.leads where id = p_lead_id and firm_id = m.firm_id and archived_at is null;
  if l.id is null then raise exception 'lead not found' using errcode = 'P0002'; end if;
  if not public.lead_can_edit(m.firm_id, l.owner_profile_id) then raise exception 'permission denied for this lead' using errcode = '42501'; end if;
  if nullif(trim(p_full_name), '') is null then raise exception 'contact name is required'; end if;
  if nullif(trim(p_email), '') is not null and lower(trim(p_email)) !~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' then raise exception 'invalid contact email'; end if;
  if nullif(trim(p_mobile), '') is not null and regexp_replace(trim(p_mobile), '[^0-9+]', '', 'g') !~ '^[0-9+]{7,20}$' then raise exception 'invalid contact mobile'; end if;
  insert into public.lead_contacts(id, firm_id, lead_id, full_name, email, mobile, designation, is_primary, created_by_profile_id) values(result, m.firm_id, l.id, trim(p_full_name), nullif(trim(p_email), ''), nullif(trim(p_mobile), ''), nullif(trim(p_designation), ''), p_is_primary, auth.uid());
  if p_is_primary then update public.lead_contacts set is_primary = false where firm_id = m.firm_id and lead_id = l.id and id <> result and archived_at is null; end if;
  perform public.lead_write_activity(m.firm_id, l.id, 'CONTACT_ADDED', p_full_name, jsonb_build_object('contact_id', result));
  return result;
end; $$;

create or replace function public.add_lead_activity(p_lead_id uuid, p_body text) returns uuid language plpgsql security definer set search_path = public, auth as $$
declare m public.firm_memberships; l public.leads; result uuid := gen_random_uuid();
begin
  m := public.lead_active_membership(); select * into l from public.leads where id = p_lead_id and firm_id = m.firm_id and archived_at is null;
  if l.id is null then raise exception 'lead not found' using errcode = 'P0002'; end if;
  if not public.lead_can_edit(m.firm_id, l.owner_profile_id) then raise exception 'permission denied for this lead' using errcode = '42501'; end if;
  if nullif(trim(p_body), '') is null then raise exception 'activity note is required'; end if;
  insert into public.lead_activities(id, firm_id, lead_id, actor_profile_id, activity_type, body) values(result, m.firm_id, l.id, auth.uid(), 'NOTE', trim(p_body));
  insert into public.audit_events(firm_id, actor_profile_id, actor_user_id, action, entity_table, entity_id, metadata) values(m.firm_id, auth.uid(), auth.uid(), 'lead.activity_added', 'leads', l.id, jsonb_build_object('activity_id', result));
  return result;
end; $$;

create or replace function public.add_lead_follow_up(p_lead_id uuid, p_title text, p_due_date date, p_reminder_date date, p_assigned_to uuid, p_note text) returns uuid language plpgsql security definer set search_path = public, auth as $$
declare m public.firm_memberships; l public.leads; result uuid := gen_random_uuid();
begin
  m := public.lead_active_membership(); select * into l from public.leads where id = p_lead_id and firm_id = m.firm_id and archived_at is null;
  if l.id is null then raise exception 'lead not found' using errcode = 'P0002'; end if;
  if not public.lead_can_edit(m.firm_id, l.owner_profile_id) then raise exception 'permission denied for this lead' using errcode = '42501'; end if;
  if nullif(trim(p_title), '') is null or p_due_date is null then raise exception 'follow-up title and due date are required'; end if;
  if p_reminder_date is not null and p_reminder_date > p_due_date then raise exception 'reminder date must be on or before due date'; end if;
  if p_assigned_to is not null and not exists(select 1 from public.firm_memberships where firm_id = m.firm_id and profile_id = p_assigned_to and status = 'ACTIVE' and archived_at is null) then raise exception 'follow-up assignee is not active in this firm'; end if;
  insert into public.lead_follow_ups(id, firm_id, lead_id, assigned_to_profile_id, due_date, reminder_date, title, note, created_by_profile_id) values(result, m.firm_id, l.id, coalesce(p_assigned_to, l.owner_profile_id), p_due_date, p_reminder_date, trim(p_title), nullif(trim(p_note), ''), auth.uid());
  update public.leads set next_follow_up_date = case when next_follow_up_date is null or p_due_date < next_follow_up_date then p_due_date else next_follow_up_date end where id = l.id;
  perform public.lead_write_activity(m.firm_id, l.id, 'FOLLOW_UP_CREATED', p_title, jsonb_build_object('follow_up_id', result, 'due_date', p_due_date));
  return result;
end; $$;

create or replace function public.complete_lead_follow_up(p_follow_up_id uuid, p_status text default 'DONE') returns void language plpgsql security definer set search_path = public, auth as $$
declare m public.firm_memberships; f public.lead_follow_ups; l public.leads; next_date date;
begin
  m := public.lead_active_membership(); select * into f from public.lead_follow_ups where id = p_follow_up_id and firm_id = m.firm_id for update;
  if f.id is null then raise exception 'follow-up not found' using errcode = 'P0002'; end if;
  select * into l from public.leads where id = f.lead_id and firm_id = m.firm_id and archived_at is null;
  if l.id is null or not public.lead_can_edit(m.firm_id, l.owner_profile_id) then raise exception 'permission denied for this follow-up' using errcode = '42501'; end if;
  if p_status not in ('DONE', 'CANCELLED') then raise exception 'invalid follow-up status'; end if;
  update public.lead_follow_ups set status = p_status, completed_at = timezone('utc', now()) where id = f.id;
  select min(due_date) into next_date from public.lead_follow_ups where firm_id = m.firm_id and lead_id = l.id and status = 'OPEN';
  update public.leads set next_follow_up_date = next_date where id = l.id;
  perform public.lead_write_activity(m.firm_id, l.id, 'FOLLOW_UP_COMPLETED', f.title, jsonb_build_object('follow_up_id', f.id, 'status', p_status));
end; $$;

create or replace function public.create_proposal(
  p_lead_id uuid, p_title text, p_service_scope text, p_validity_date date, p_fee_minor numeric, p_tax_estimate_minor numeric, p_currency text, p_notes text
) returns uuid language plpgsql security definer set search_path = public, auth as $$
declare m public.firm_memberships; l public.leads; proposal_id uuid := gen_random_uuid(); version_id uuid := gen_random_uuid();
begin
  m := public.lead_active_membership(); select * into l from public.leads where id = p_lead_id and firm_id = m.firm_id and archived_at is null for update;
  if l.id is null then raise exception 'lead not found' using errcode = 'P0002'; end if;
  if not public.lead_can_edit(m.firm_id, l.owner_profile_id) then raise exception 'permission denied to edit proposal terms' using errcode = '42501'; end if;
  if nullif(trim(p_title), '') is null or nullif(trim(p_service_scope), '') is null then raise exception 'proposal title and service scope are required'; end if;
  if p_validity_date is null or p_validity_date < public.lead_local_date(m.firm_id) then raise exception 'proposal validity date is expired'; end if;
  if p_fee_minor is null or p_fee_minor < 0 or p_tax_estimate_minor is null or p_tax_estimate_minor < 0 then raise exception 'proposal amounts must be non-negative'; end if;
  if upper(trim(p_currency)) !~ '^[A-Z]{3}$' then raise exception 'currency must be a three-letter code'; end if;
  insert into public.proposals(id, firm_id, lead_id, title, created_by_profile_id) values(proposal_id, m.firm_id, l.id, trim(p_title), auth.uid());
  insert into public.proposal_versions(id, firm_id, proposal_id, version_number, service_scope, validity_date, fee_minor, tax_estimate_minor, currency, notes, created_by_profile_id) values(version_id, m.firm_id, proposal_id, 1, trim(p_service_scope), p_validity_date, p_fee_minor, p_tax_estimate_minor, upper(trim(p_currency)), nullif(trim(p_notes), ''), auth.uid());
  update public.proposals set current_version_id = version_id where id = proposal_id;
  insert into public.proposal_events(firm_id, proposal_id, actor_profile_id, event_type, metadata) values(m.firm_id, proposal_id, auth.uid(), 'VERSION_CREATED', jsonb_build_object('version_number', 1));
  perform public.lead_write_activity(m.firm_id, l.id, 'PROPOSAL_CREATED', p_title, jsonb_build_object('proposal_id', proposal_id));
  return proposal_id;
end; $$;

create or replace function public.create_proposal_version(
  p_proposal_id uuid, p_service_scope text, p_validity_date date, p_fee_minor numeric, p_tax_estimate_minor numeric, p_currency text, p_notes text
) returns uuid language plpgsql security definer set search_path = public, auth as $$
declare m public.firm_memberships; p public.proposals; l public.leads; version_id uuid := gen_random_uuid(); next_version integer;
begin
  m := public.lead_active_membership(); select * into p from public.proposals where id = p_proposal_id and firm_id = m.firm_id for update; if p.id is null then raise exception 'proposal not found' using errcode = 'P0002'; end if;
  select * into l from public.leads where id = p.lead_id and firm_id = m.firm_id and archived_at is null; if l.id is null or not public.lead_can_edit(m.firm_id, l.owner_profile_id) then raise exception 'permission denied to edit proposal terms' using errcode = '42501'; end if;
  if p.status in ('ACCEPTED', 'CONVERTED') then raise exception 'accepted proposal history cannot be edited'; end if;
  if p_validity_date is null or p_validity_date < public.lead_local_date(m.firm_id) then raise exception 'proposal validity date is expired'; end if;
  if p_fee_minor is null or p_fee_minor < 0 or p_tax_estimate_minor is null or p_tax_estimate_minor < 0 then raise exception 'proposal amounts must be non-negative'; end if;
  if upper(trim(p_currency)) !~ '^[A-Z]{3}$' then raise exception 'currency must be a three-letter code'; end if;
  select coalesce(max(version_number), 0) + 1 into next_version from public.proposal_versions where firm_id = m.firm_id and proposal_id = p.id;
  insert into public.proposal_versions(id, firm_id, proposal_id, version_number, service_scope, validity_date, fee_minor, tax_estimate_minor, currency, notes, created_by_profile_id) values(version_id, m.firm_id, p.id, next_version, trim(p_service_scope), p_validity_date, p_fee_minor, p_tax_estimate_minor, upper(trim(p_currency)), nullif(trim(p_notes), ''), auth.uid());
  update public.proposals set current_version_id = version_id, status = 'DRAFT' where id = p.id;
  insert into public.proposal_events(firm_id, proposal_id, actor_profile_id, event_type, metadata) values(m.firm_id, p.id, auth.uid(), 'VERSION_CREATED', jsonb_build_object('version_number', next_version));
  perform public.lead_write_activity(m.firm_id, l.id, 'PROPOSAL_UPDATED', null, jsonb_build_object('proposal_id', p.id, 'version_number', next_version));
  return version_id;
end; $$;

create or replace function public.record_proposal_demo_event(p_proposal_id uuid, p_event text) returns void language plpgsql security definer set search_path = public, auth as $$
declare m public.firm_memberships; p public.proposals; l public.leads; v public.proposal_versions; next_status text := null;
begin
  m := public.lead_active_membership(); select * into p from public.proposals where id = p_proposal_id and firm_id = m.firm_id for update; if p.id is null then raise exception 'proposal not found' using errcode = 'P0002'; end if;
  select * into l from public.leads where id = p.lead_id and firm_id = m.firm_id and archived_at is null; if l.id is null then raise exception 'lead not found' using errcode = 'P0002'; end if;
  select * into v from public.proposal_versions where id = p.current_version_id and firm_id = m.firm_id;
  if v.id is null then raise exception 'proposal version not found'; end if;
  if p.status in ('ACCEPTED', 'REJECTED', 'CONVERTED') then raise exception 'proposal is already closed'; end if;
  if v.validity_date < public.lead_local_date(m.firm_id) then
    update public.proposals set status = 'EXPIRED' where id = p.id;
    insert into public.proposal_events(firm_id, proposal_id, actor_profile_id, event_type, metadata) values(m.firm_id, p.id, auth.uid(), 'EXPIRED', jsonb_build_object('validity_date', v.validity_date));
    raise exception 'proposal validity has expired';
  end if;
  if p_event = 'PREVIEWED' then next_status := 'PREVIEW'; elsif p_event = 'DEMO_SENT' then next_status := 'SENT_DEMO'; elsif p_event = 'VIEWED' then next_status := 'VIEWED'; elsif p_event = 'ACTIONED' then next_status := 'ACTIONED'; else raise exception 'invalid demo proposal event'; end if;
  update public.proposals set status = next_status where id = p.id;
  insert into public.proposal_events(firm_id, proposal_id, actor_profile_id, event_type, metadata) values(m.firm_id, p.id, auth.uid(), p_event, jsonb_build_object('demo_only', true));
end; $$;

create or replace function public.set_proposal_outcome(p_proposal_id uuid, p_outcome text) returns void language plpgsql security definer set search_path = public, auth as $$
declare m public.firm_memberships; p public.proposals; l public.leads; v public.proposal_versions;
begin
  m := public.lead_active_membership(); select * into p from public.proposals where id = p_proposal_id and firm_id = m.firm_id for update; if p.id is null then raise exception 'proposal not found' using errcode = 'P0002'; end if;
  select * into l from public.leads where id = p.lead_id and firm_id = m.firm_id and archived_at is null; if l.id is null or not public.lead_can_edit(m.firm_id, l.owner_profile_id) then raise exception 'permission denied for proposal outcome' using errcode = '42501'; end if;
  select * into v from public.proposal_versions where id = p.current_version_id and firm_id = m.firm_id;
  if p_outcome not in ('ACCEPTED', 'REJECTED') then raise exception 'invalid proposal outcome'; end if;
  if p.status in ('ACCEPTED', 'REJECTED', 'CONVERTED', 'EXPIRED') then raise exception 'proposal is already closed'; end if;
  if p_outcome = 'ACCEPTED' and v.validity_date < public.lead_local_date(m.firm_id) then update public.proposals set status = 'EXPIRED' where id = p.id; insert into public.proposal_events(firm_id, proposal_id, actor_profile_id, event_type, metadata) values(m.firm_id, p.id, auth.uid(), 'EXPIRED', jsonb_build_object('validity_date', v.validity_date)); raise exception 'proposal validity has expired'; end if;
  update public.proposals set status = p_outcome, accepted_at = case when p_outcome = 'ACCEPTED' then timezone('utc', now()) else accepted_at end, rejected_at = case when p_outcome = 'REJECTED' then timezone('utc', now()) else rejected_at end where id = p.id;
  insert into public.proposal_events(firm_id, proposal_id, actor_profile_id, event_type) values(m.firm_id, p.id, auth.uid(), p_outcome);
  perform public.lead_write_activity(m.firm_id, l.id, 'PROPOSAL_UPDATED', p_outcome, jsonb_build_object('proposal_id', p.id, 'outcome', p_outcome));
end; $$;

create or replace function public.convert_lead_to_client(p_lead_id uuid, p_proposal_id uuid, p_existing_client_id uuid, p_entity_type text) returns uuid language plpgsql security definer set search_path = public, auth as $$
declare m public.firm_memberships; l public.leads; p public.proposals; v public.proposal_versions; target_client_id uuid; display_name text; legal_name text;
begin
  m := public.lead_active_membership();
  select * into l from public.leads where id = p_lead_id and firm_id = m.firm_id and archived_at is null for update;
  if l.id is null then raise exception 'lead not found' using errcode = 'P0002'; end if;
  if not public.lead_can_edit(m.firm_id, l.owner_profile_id) then raise exception 'permission denied to convert this lead' using errcode = '42501'; end if;
  if l.converted_client_id is not null then return l.converted_client_id; end if;
  select * into p from public.proposals where id = p_proposal_id and firm_id = m.firm_id and lead_id = l.id for update;
  if p.id is null then raise exception 'an accepted proposal is required for conversion'; end if;
  if p.status <> 'ACCEPTED' then raise exception 'an accepted proposal is required for conversion'; end if;
  select * into v from public.proposal_versions where id = p.current_version_id and firm_id = m.firm_id;
  if v.validity_date < public.lead_local_date(m.firm_id) then update public.proposals set status = 'EXPIRED' where id = p.id; raise exception 'proposal validity has expired'; end if;
  if p_existing_client_id is not null then
    select id into target_client_id from public.clients where id = p_existing_client_id and firm_id = m.firm_id and archived_at is null for update;
    if target_client_id is null then raise exception 'existing client is unavailable'; end if;
    if not exists (select 1 from public.client_contacts cc where cc.firm_id = m.firm_id and cc.client_id = target_client_id and cc.archived_at is null and ((l.email is not null and lower(cc.email) = lower(l.email)) or (l.email is null and lower(cc.full_name) = lower(l.name)))) then
      perform public.upsert_client_contact(target_client_id, null, l.name, l.email, l.mobile, 'Converted lead contact', false);
    end if;
  else
    display_name := coalesce(nullif(trim(l.company_name), ''), trim(l.name)); legal_name := display_name;
    target_client_id := public.create_client_master(legal_name, display_name, coalesce(nullif(p_entity_type, ''), 'OTHER'), null, null, null, l.owner_profile_id, '{}', 'ACTIVE', l.notes, jsonb_build_object('full_name', l.name, 'email', l.email, 'phone', l.mobile, 'designation', 'Converted lead contact'));
  end if;
  update public.leads set stage = 'CLIENT', status = 'CONVERTED', converted_client_id = target_client_id, converted_at = timezone('utc', now()) where id = l.id;
  update public.proposals set status = 'CONVERTED' where id = p.id;
  insert into public.proposal_events(firm_id, proposal_id, actor_profile_id, event_type, metadata) values(m.firm_id, p.id, auth.uid(), 'CONVERTED', jsonb_build_object('client_id', target_client_id));
  perform public.lead_write_activity(m.firm_id, l.id, 'CONVERTED', 'Accepted proposal converted to client', jsonb_build_object('client_id', target_client_id, 'proposal_id', p.id));
  insert into public.audit_events(firm_id, actor_profile_id, actor_user_id, action, entity_table, entity_id, metadata) values(m.firm_id, auth.uid(), auth.uid(), 'lead.converted', 'leads', l.id, jsonb_build_object('client_id', target_client_id, 'proposal_id', p.id, 'existing_client', p_existing_client_id is not null));
  return target_client_id;
end; $$;

revoke all on function public.lead_active_membership() from public;
revoke all on function public.lead_can_edit(uuid, uuid) from public;
revoke all on function public.lead_local_date(uuid) from public;
revoke all on function public.lead_write_activity(uuid, uuid, text, text, jsonb) from public;
revoke all on function public.create_lead(text, text, text, text, text, integer, uuid, date, text) from public;
revoke all on function public.set_lead_stage(uuid, text, text) from public;
revoke all on function public.mark_lead_lost(uuid, text) from public;
revoke all on function public.add_lead_contact(uuid, text, text, text, text, boolean) from public;
revoke all on function public.add_lead_activity(uuid, text) from public;
revoke all on function public.add_lead_follow_up(uuid, text, date, date, uuid, text) from public;
revoke all on function public.complete_lead_follow_up(uuid, text) from public;
revoke all on function public.create_proposal(uuid, text, text, date, numeric, numeric, text, text) from public;
revoke all on function public.create_proposal_version(uuid, text, date, numeric, numeric, text, text) from public;
revoke all on function public.record_proposal_demo_event(uuid, text) from public;
revoke all on function public.set_proposal_outcome(uuid, text) from public;
revoke all on function public.convert_lead_to_client(uuid, uuid, uuid, text) from public;
grant execute on function public.create_lead(text, text, text, text, text, integer, uuid, date, text), public.set_lead_stage(uuid, text, text), public.mark_lead_lost(uuid, text), public.add_lead_contact(uuid, text, text, text, text, boolean), public.add_lead_activity(uuid, text), public.add_lead_follow_up(uuid, text, date, date, uuid, text), public.complete_lead_follow_up(uuid, text), public.create_proposal(uuid, text, text, date, numeric, numeric, text, text), public.create_proposal_version(uuid, text, date, numeric, numeric, text, text), public.record_proposal_demo_event(uuid, text), public.set_proposal_outcome(uuid, text), public.convert_lead_to_client(uuid, uuid, uuid, text) to authenticated, service_role;

commit;
