-- Northstar Practice Stage 3: email/password registration approval foundation.
-- New firms are pending by default; only trusted server/database operations can transition them.

begin;

alter type public.firm_role add value if not exists 'REVIEWER';

alter table public.profiles add column if not exists full_name text;
update public.profiles set full_name = display_name where full_name is null;
alter table public.profiles alter column full_name set not null;
alter table public.profiles add column if not exists mobile_number text;
alter table public.profiles drop constraint if exists profiles_mobile_number_check;
alter table public.profiles add constraint profiles_mobile_number_check check (mobile_number is null or mobile_number ~ '^\+91[6-9][0-9]{9}$');
alter table public.profiles drop constraint if exists profiles_full_name_check;
alter table public.profiles add constraint profiles_full_name_check check (char_length(trim(full_name)) between 1 and 160);

alter table public.firms add column if not exists approval_status text not null default 'ACTIVE';
alter table public.firms drop constraint if exists firms_approval_status_check;
alter table public.firms add constraint firms_approval_status_check check (approval_status in ('PENDING', 'ACTIVE', 'REJECTED', 'SUSPENDED'));
alter table public.firms alter column approval_status set default 'PENDING';

alter table public.firm_memberships drop constraint if exists firm_memberships_status_check;
alter table public.firm_memberships add constraint firm_memberships_status_check check (status in ('PENDING', 'ACTIVE', 'INVITED', 'REJECTED', 'SUSPENDED'));

alter table public.audit_events add column if not exists actor_user_id uuid references auth.users(id) on delete set null;
create index if not exists audit_events_actor_user_idx on public.audit_events (actor_user_id, created_at desc);

create table public.firm_signup_requests (
  id uuid primary key default gen_random_uuid(),
  applicant_user_id uuid not null references auth.users(id) on delete restrict,
  profile_id uuid not null references public.profiles(id) on delete restrict,
  firm_id uuid not null references public.firms(id) on delete restrict,
  status text not null default 'PENDING' check (status in ('PENDING', 'APPROVED', 'REJECTED')),
  firm_name_snapshot text not null check (char_length(trim(firm_name_snapshot)) between 1 and 160),
  full_name_snapshot text not null check (char_length(trim(full_name_snapshot)) between 1 and 160),
  email_snapshot text not null check (char_length(trim(email_snapshot)) between 3 and 320),
  mobile_number text not null check (mobile_number ~ '^\+91[6-9][0-9]{9}$'),
  submitted_at timestamptz not null default timezone('utc', now()),
  reviewed_by_user_id uuid references auth.users(id) on delete set null,
  reviewed_at timestamptz,
  rejection_reason text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (applicant_user_id),
  unique (firm_id),
  check (status <> 'REJECTED' or nullif(trim(rejection_reason), '') is not null),
  check (reviewed_at is null or status in ('APPROVED', 'REJECTED')),
  check (status = 'PENDING' or (reviewed_by_user_id is not null and reviewed_at is not null))
);

create table public.platform_admins (
  user_id uuid primary key references auth.users(id) on delete restrict,
  enabled boolean not null default true,
  note text,
  created_by_user_id uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default timezone('utc', now())
);

create index firm_signup_requests_status_submitted_idx on public.firm_signup_requests (status, submitted_at desc);
create index firm_signup_requests_firm_idx on public.firm_signup_requests (firm_id, status);
create index firm_signup_requests_applicant_idx on public.firm_signup_requests (applicant_user_id, status);

create trigger firm_signup_requests_set_updated_at before update on public.firm_signup_requests
for each row execute function public.set_updated_at();

create or replace function public.is_platform_admin(target_user_id uuid default auth.uid())
returns boolean
language sql
stable
security definer
set search_path = public, auth
as $$
  select exists (
    select 1
    from public.platform_admins administrator
    where administrator.user_id = target_user_id
      and administrator.enabled
  );
$$;

create or replace function public.is_firm_member(target_firm_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, auth
as $$
  select exists (
    select 1
    from public.firm_memberships membership
    join public.firms firm on firm.id = membership.firm_id
    where membership.firm_id = target_firm_id
      and membership.profile_id = auth.uid()
      and membership.status = 'ACTIVE'
      and membership.archived_at is null
      and firm.approval_status = 'ACTIVE'
      and firm.archived_at is null
  );
$$;

create or replace function public.has_firm_role(target_firm_id uuid, allowed_roles public.firm_role[])
returns boolean
language sql
stable
security definer
set search_path = public, auth
as $$
  select exists (
    select 1
    from public.firm_memberships membership
    join public.firms firm on firm.id = membership.firm_id
    where membership.firm_id = target_firm_id
      and membership.profile_id = auth.uid()
      and membership.status = 'ACTIVE'
      and membership.archived_at is null
      and firm.approval_status = 'ACTIVE'
      and firm.archived_at is null
      and membership.role = any (allowed_roles)
  );
$$;

create or replace function public.get_my_access_state()
returns jsonb
language sql
stable
security invoker
set search_path = public, auth
as $$
  with current_profile as (
    select id, full_name, display_name, mobile_number
    from public.profiles
    where id = auth.uid()
  ), latest_request as (
    select request.id, request.firm_id, request.status, request.firm_name_snapshot, request.email_snapshot, request.submitted_at, request.rejection_reason
    from public.firm_signup_requests request
    where request.applicant_user_id = auth.uid()
    order by request.submitted_at desc
    limit 1
  ), current_membership as (
    select membership.firm_id, membership.role, membership.status, firm.name as firm_name, firm.approval_status
    from public.firm_memberships membership
    join public.firms firm on firm.id = membership.firm_id
    where membership.profile_id = auth.uid()
    order by membership.created_at desc
    limit 1
  )
  select jsonb_build_object(
    'user_id', auth.uid(),
    'email', coalesce(auth.jwt() ->> 'email', latest_request.email_snapshot),
    'full_name', current_profile.full_name,
    'mobile_number', current_profile.mobile_number,
    'is_platform_admin', public.is_platform_admin(auth.uid()),
    'firm_id', coalesce(current_membership.firm_id, latest_request.firm_id),
    'firm_name', coalesce(current_membership.firm_name, latest_request.firm_name_snapshot),
    'membership_role', current_membership.role,
    'firm_approval_status', coalesce(current_membership.approval_status, latest_request.status),
    'registration_status', latest_request.status,
    'rejection_reason', latest_request.rejection_reason,
    'submitted_at', latest_request.submitted_at,
    'access_status', case
      when public.is_platform_admin(auth.uid()) then 'PLATFORM_ADMIN'
      when current_membership.status = 'ACTIVE' and current_membership.approval_status = 'ACTIVE' then 'ACTIVE'
      when current_membership.status = 'SUSPENDED' or current_membership.approval_status = 'SUSPENDED' then 'SUSPENDED'
      when current_membership.status = 'REJECTED' or current_membership.approval_status = 'REJECTED' or latest_request.status = 'REJECTED' then 'REJECTED'
      when current_membership.status in ('PENDING', 'INVITED') or current_membership.approval_status = 'PENDING' or latest_request.status = 'PENDING' then 'PENDING'
      else 'NONE'
    end
  )
  from (select auth.uid() as user_id) subject
  left join current_profile on true
  left join latest_request on true
  left join current_membership on true;
$$;

create or replace function public.sync_firm_signup_request_status()
returns trigger
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  if new.status in ('APPROVED', 'REJECTED') and not public.is_platform_admin(new.reviewed_by_user_id) then
    raise exception 'reviewer is not a platform administrator';
  end if;
  if old.status <> 'PENDING' and new.status <> old.status then
    raise exception 'registration request is already finalized';
  end if;

  if new.status = 'APPROVED' and old.status = 'PENDING' then
    update public.firms
    set approval_status = 'ACTIVE', archived_at = null
    where id = new.firm_id;

    update public.firm_memberships
    set status = 'ACTIVE', archived_at = null
    where firm_id = new.firm_id and profile_id = new.profile_id and role = 'OWNER';

    insert into public.audit_events (firm_id, actor_user_id, action, entity_table, entity_id, metadata)
    values (new.firm_id, new.reviewed_by_user_id, 'registration.approved', 'firm_signup_requests', new.id, jsonb_build_object('status', new.status));
  elsif new.status = 'REJECTED' and old.status = 'PENDING' then
    update public.firms
    set approval_status = 'REJECTED'
    where id = new.firm_id;

    update public.firm_memberships
    set status = 'REJECTED', archived_at = null
    where firm_id = new.firm_id and profile_id = new.profile_id and role = 'OWNER';

    insert into public.audit_events (firm_id, actor_user_id, action, entity_table, entity_id, metadata)
    values (new.firm_id, new.reviewed_by_user_id, 'registration.rejected', 'firm_signup_requests', new.id, jsonb_build_object('status', new.status, 'reason', new.rejection_reason));
  end if;

  return new;
end;
$$;

create trigger firm_signup_requests_sync_status
after update of status on public.firm_signup_requests
for each row when (old.status is distinct from new.status)
execute function public.sync_firm_signup_request_status();

create or replace function public.register_firm_pending(
  p_user_id uuid,
  p_email text,
  p_full_name text,
  p_mobile_number text,
  p_firm_name text
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  existing_request public.firm_signup_requests;
  auth_email text;
  new_profile public.profiles;
  new_firm public.firms;
  new_request public.firm_signup_requests;
begin
  if p_user_id is null or p_full_name is null or char_length(trim(p_full_name)) not between 1 and 160 then
    raise exception 'invalid registration identity';
  end if;
  if p_firm_name is null or char_length(trim(p_firm_name)) not between 1 and 160 then
    raise exception 'invalid firm name';
  end if;
  if p_mobile_number is null or p_mobile_number !~ '^\+91[6-9][0-9]{9}$' then
    raise exception 'invalid mobile number';
  end if;

  select email into auth_email from auth.users where id = p_user_id;
  if auth_email is null or lower(trim(auth_email)) <> lower(trim(p_email)) then
    raise exception 'registration email does not match auth account';
  end if;

  select * into existing_request
  from public.firm_signup_requests
  where applicant_user_id = p_user_id
  for update;
  if found then
    return jsonb_build_object('request_id', existing_request.id, 'firm_id', existing_request.firm_id, 'status', existing_request.status);
  end if;

  if exists (select 1 from public.firm_memberships where profile_id = p_user_id and status in ('ACTIVE', 'PENDING', 'INVITED')) then
    raise exception 'user already belongs to a firm or has a pending registration';
  end if;

  insert into public.profiles (id, display_name, full_name, mobile_number)
  values (p_user_id, trim(p_full_name), trim(p_full_name), p_mobile_number)
  on conflict (id) do update set display_name = excluded.display_name, full_name = excluded.full_name, mobile_number = excluded.mobile_number
  returning * into new_profile;

  insert into public.firms (name, legal_name, created_by_profile_id, approval_status)
  values (trim(p_firm_name), trim(p_firm_name), p_user_id, 'PENDING')
  returning * into new_firm;

  insert into public.firm_memberships (firm_id, profile_id, role, status)
  values (new_firm.id, p_user_id, 'OWNER', 'PENDING');

  insert into public.firm_signup_requests (applicant_user_id, profile_id, firm_id, firm_name_snapshot, full_name_snapshot, email_snapshot, mobile_number)
  values (p_user_id, p_user_id, new_firm.id, trim(p_firm_name), trim(p_full_name), lower(trim(p_email)), p_mobile_number)
  returning * into new_request;

  insert into public.audit_events (firm_id, actor_user_id, action, entity_table, entity_id, metadata)
  values (new_firm.id, p_user_id, 'registration.submitted', 'firm_signup_requests', new_request.id, jsonb_build_object('status', 'PENDING'));

  return jsonb_build_object('request_id', new_request.id, 'firm_id', new_firm.id, 'status', new_request.status);
end;
$$;

create or replace function public.set_firm_signup_request_status(
  p_request_id uuid,
  p_status text,
  p_reviewer_user_id uuid,
  p_rejection_reason text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  request_row public.firm_signup_requests;
begin
  if p_status not in ('APPROVED', 'REJECTED') then
    raise exception 'unsupported registration status';
  end if;
  if p_reviewer_user_id is null or not public.is_platform_admin(p_reviewer_user_id) then
    raise exception 'reviewer is not a platform administrator';
  end if;
  if p_status = 'REJECTED' and nullif(trim(p_rejection_reason), '') is null then
    raise exception 'rejection reason is required';
  end if;

  select * into request_row from public.firm_signup_requests where id = p_request_id for update;
  if not found then raise exception 'registration request not found'; end if;
  if request_row.status = p_status then
    return jsonb_build_object('request_id', request_row.id, 'firm_id', request_row.firm_id, 'status', request_row.status);
  end if;
  if request_row.status <> 'PENDING' then
    raise exception 'registration request is already finalized';
  end if;

  update public.firm_signup_requests
  set status = p_status,
      reviewed_by_user_id = p_reviewer_user_id,
      reviewed_at = timezone('utc', now()),
      rejection_reason = case when p_status = 'REJECTED' then nullif(trim(p_rejection_reason), '') else null end
  where id = p_request_id;

  return jsonb_build_object('request_id', p_request_id, 'firm_id', request_row.firm_id, 'status', p_status);
end;
$$;

revoke all on function public.is_platform_admin(uuid) from public;
revoke all on function public.get_my_access_state() from public;
revoke all on function public.register_firm_pending(uuid, text, text, text, text) from public;
revoke all on function public.set_firm_signup_request_status(uuid, text, uuid, text) from public;
grant execute on function public.is_platform_admin(uuid) to authenticated, service_role;
grant execute on function public.get_my_access_state() to authenticated, service_role;
grant execute on function public.register_firm_pending(uuid, text, text, text, text) to service_role;
grant execute on function public.set_firm_signup_request_status(uuid, text, uuid, text) to service_role;

alter table public.firm_signup_requests enable row level security;
alter table public.firm_signup_requests force row level security;
alter table public.platform_admins enable row level security;
alter table public.platform_admins force row level security;

create policy signup_requests_select_self_or_admin on public.firm_signup_requests
for select to authenticated
using (applicant_user_id = auth.uid() or public.is_platform_admin(auth.uid()));

create policy platform_admins_select_self_or_admin on public.platform_admins
for select to authenticated
using (user_id = auth.uid() or public.is_platform_admin(auth.uid()));

create policy memberships_select_self on public.firm_memberships
for select to authenticated
using (profile_id = auth.uid());

create policy firms_select_own_membership on public.firms
for select to authenticated
using (exists (select 1 from public.firm_memberships membership where membership.firm_id = id and membership.profile_id = auth.uid()));

grant usage on schema public to authenticated;
grant select on public.firm_signup_requests, public.platform_admins to authenticated;

comment on table public.firm_signup_requests is 'Canonical registration approval state. Use set_firm_signup_request_status for trusted transitions.';
comment on table public.platform_admins is 'Trusted registry of platform administrators; never derived from editable Auth metadata.';
comment on column public.firms.approval_status is 'PENDING by default for new firms; only the trusted approval workflow may activate it.';

commit;
