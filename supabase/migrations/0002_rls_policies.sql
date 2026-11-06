-- Northstar Practice Stage 2: membership helpers and deny-by-default RLS.

begin;

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
    where membership.firm_id = target_firm_id
      and membership.profile_id = auth.uid()
      and membership.status = 'ACTIVE'
      and membership.archived_at is null
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
    where membership.firm_id = target_firm_id
      and membership.profile_id = auth.uid()
      and membership.status = 'ACTIVE'
      and membership.archived_at is null
      and membership.role = any (allowed_roles)
  );
$$;

create or replace function public.can_view_profile(target_profile_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, auth
as $$
  select target_profile_id = auth.uid()
    or exists (
      select 1
      from public.firm_memberships viewer
      join public.firm_memberships target on target.firm_id = viewer.firm_id
      where viewer.profile_id = auth.uid()
        and target.profile_id = target_profile_id
        and viewer.status = 'ACTIVE'
        and viewer.archived_at is null
        and target.status = 'ACTIVE'
        and target.archived_at is null
    );
$$;

create or replace function public.storage_firm_id(storage_path text)
returns uuid
language plpgsql
immutable
set search_path = public
as $$
declare
  first_segment text := split_part(storage_path, '/', 1);
begin
  if first_segment ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    return first_segment::uuid;
  end if;
  return null;
end;
$$;

revoke all on function public.is_firm_member(uuid) from public;
revoke all on function public.has_firm_role(uuid, public.firm_role[]) from public;
revoke all on function public.can_view_profile(uuid) from public;
revoke all on function public.storage_firm_id(text) from public;
grant execute on function public.is_firm_member(uuid) to authenticated, service_role;
grant execute on function public.has_firm_role(uuid, public.firm_role[]) to authenticated, service_role;
grant execute on function public.can_view_profile(uuid) to authenticated, service_role;
grant execute on function public.storage_firm_id(text) to authenticated, service_role;

alter table public.profiles enable row level security;
alter table public.profiles force row level security;
alter table public.firms enable row level security;
alter table public.firms force row level security;
alter table public.firm_memberships enable row level security;
alter table public.firm_memberships force row level security;
alter table public.services enable row level security;
alter table public.services force row level security;
alter table public.clients enable row level security;
alter table public.clients force row level security;
alter table public.client_contacts enable row level security;
alter table public.client_contacts force row level security;
alter table public.task_templates enable row level security;
alter table public.task_templates force row level security;
alter table public.tasks enable row level security;
alter table public.tasks force row level security;
alter table public.task_checklist_items enable row level security;
alter table public.task_checklist_items force row level security;
alter table public.task_comments enable row level security;
alter table public.task_comments force row level security;
alter table public.compliance_obligations enable row level security;
alter table public.compliance_obligations force row level security;
alter table public.compliance_periods enable row level security;
alter table public.compliance_periods force row level security;
alter table public.documents enable row level security;
alter table public.documents force row level security;
alter table public.audit_events enable row level security;
alter table public.audit_events force row level security;

-- Profiles are global identities, but a member can only discover profiles in a shared firm.
create policy profiles_select on public.profiles for select to authenticated using (public.can_view_profile(id));
create policy profiles_insert_self on public.profiles for insert to authenticated with check (id = auth.uid());
create policy profiles_update_self on public.profiles for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

-- A firm may be bootstrapped by an authenticated service-layer request. Membership creation
-- for the first owner is intentionally a server-side bootstrap operation.
create policy firms_select_member on public.firms for select to authenticated using (public.is_firm_member(id));
create policy firms_insert_authenticated on public.firms for insert to authenticated with check (auth.uid() is not null and (created_by_profile_id is null or created_by_profile_id = auth.uid()));
create policy firms_update_manager on public.firms for update to authenticated using (public.has_firm_role(id, array['OWNER', 'PARTNER', 'MANAGER']::public.firm_role[])) with check (public.has_firm_role(id, array['OWNER', 'PARTNER', 'MANAGER']::public.firm_role[]));
create policy firms_delete_owner on public.firms for delete to authenticated using (public.has_firm_role(id, array['OWNER']::public.firm_role[]));

create policy memberships_select_member on public.firm_memberships for select to authenticated using (public.is_firm_member(firm_id));
create policy memberships_insert_manager on public.firm_memberships for insert to authenticated with check (public.has_firm_role(firm_id, array['OWNER', 'MANAGER']::public.firm_role[]));
create policy memberships_update_manager on public.firm_memberships for update to authenticated using (public.has_firm_role(firm_id, array['OWNER', 'MANAGER']::public.firm_role[])) with check (public.has_firm_role(firm_id, array['OWNER', 'MANAGER']::public.firm_role[]));
create policy memberships_delete_manager on public.firm_memberships for delete to authenticated using (public.has_firm_role(firm_id, array['OWNER', 'MANAGER']::public.firm_role[]));

create policy services_select_member on public.services for select to authenticated using (public.is_firm_member(firm_id));
create policy services_insert_manager on public.services for insert to authenticated with check (public.has_firm_role(firm_id, array['OWNER', 'PARTNER', 'MANAGER']::public.firm_role[]));
create policy services_update_manager on public.services for update to authenticated using (public.has_firm_role(firm_id, array['OWNER', 'PARTNER', 'MANAGER']::public.firm_role[])) with check (public.has_firm_role(firm_id, array['OWNER', 'PARTNER', 'MANAGER']::public.firm_role[]));
create policy services_delete_manager on public.services for delete to authenticated using (public.has_firm_role(firm_id, array['OWNER', 'PARTNER', 'MANAGER']::public.firm_role[]));

create policy clients_select_member on public.clients for select to authenticated using (public.is_firm_member(firm_id));
create policy clients_insert_member on public.clients for insert to authenticated with check (public.is_firm_member(firm_id) and (created_by_profile_id is null or created_by_profile_id = auth.uid()));
create policy clients_update_member on public.clients for update to authenticated using (public.is_firm_member(firm_id)) with check (public.is_firm_member(firm_id));
create policy clients_delete_manager on public.clients for delete to authenticated using (public.has_firm_role(firm_id, array['OWNER', 'PARTNER', 'MANAGER']::public.firm_role[]));

create policy client_contacts_select_member on public.client_contacts for select to authenticated using (public.is_firm_member(firm_id));
create policy client_contacts_insert_member on public.client_contacts for insert to authenticated with check (public.is_firm_member(firm_id) and (created_by_profile_id is null or created_by_profile_id = auth.uid()));
create policy client_contacts_update_member on public.client_contacts for update to authenticated using (public.is_firm_member(firm_id)) with check (public.is_firm_member(firm_id));
create policy client_contacts_delete_manager on public.client_contacts for delete to authenticated using (public.has_firm_role(firm_id, array['OWNER', 'PARTNER', 'MANAGER']::public.firm_role[]));

create policy task_templates_select_member on public.task_templates for select to authenticated using (public.is_firm_member(firm_id));
create policy task_templates_insert_manager on public.task_templates for insert to authenticated with check (public.has_firm_role(firm_id, array['OWNER', 'PARTNER', 'MANAGER']::public.firm_role[]));
create policy task_templates_update_manager on public.task_templates for update to authenticated using (public.has_firm_role(firm_id, array['OWNER', 'PARTNER', 'MANAGER']::public.firm_role[])) with check (public.has_firm_role(firm_id, array['OWNER', 'PARTNER', 'MANAGER']::public.firm_role[]));
create policy task_templates_delete_manager on public.task_templates for delete to authenticated using (public.has_firm_role(firm_id, array['OWNER', 'PARTNER', 'MANAGER']::public.firm_role[]));

create policy tasks_select_member on public.tasks for select to authenticated using (public.is_firm_member(firm_id));
create policy tasks_insert_member on public.tasks for insert to authenticated with check (public.is_firm_member(firm_id) and (created_by_profile_id is null or created_by_profile_id = auth.uid()));
create policy tasks_update_participant on public.tasks for update to authenticated using (public.is_firm_member(firm_id) and (public.has_firm_role(firm_id, array['OWNER', 'PARTNER', 'MANAGER']::public.firm_role[]) or owner_profile_id = auth.uid() or assignee_profile_id = auth.uid() or reviewer_profile_id = auth.uid())) with check (public.is_firm_member(firm_id));
create policy tasks_delete_manager on public.tasks for delete to authenticated using (public.has_firm_role(firm_id, array['OWNER', 'PARTNER', 'MANAGER']::public.firm_role[]));

create policy checklist_select_member on public.task_checklist_items for select to authenticated using (public.is_firm_member(firm_id));
create policy checklist_insert_member on public.task_checklist_items for insert to authenticated with check (public.is_firm_member(firm_id));
create policy checklist_update_member on public.task_checklist_items for update to authenticated using (public.is_firm_member(firm_id)) with check (public.is_firm_member(firm_id));
create policy checklist_delete_manager on public.task_checklist_items for delete to authenticated using (public.has_firm_role(firm_id, array['OWNER', 'PARTNER', 'MANAGER']::public.firm_role[]));

create policy comments_select_member on public.task_comments for select to authenticated using (public.is_firm_member(firm_id));
create policy comments_insert_author on public.task_comments for insert to authenticated with check (public.is_firm_member(firm_id) and author_profile_id = auth.uid());
create policy comments_update_author on public.task_comments for update to authenticated using (public.is_firm_member(firm_id) and (author_profile_id = auth.uid() or public.has_firm_role(firm_id, array['OWNER', 'PARTNER', 'MANAGER']::public.firm_role[]))) with check (public.is_firm_member(firm_id));
create policy comments_delete_author on public.task_comments for delete to authenticated using (public.is_firm_member(firm_id) and (author_profile_id = auth.uid() or public.has_firm_role(firm_id, array['OWNER', 'PARTNER', 'MANAGER']::public.firm_role[])));

create policy obligations_select_member on public.compliance_obligations for select to authenticated using (public.is_firm_member(firm_id));
create policy obligations_insert_manager on public.compliance_obligations for insert to authenticated with check (public.has_firm_role(firm_id, array['OWNER', 'PARTNER', 'MANAGER']::public.firm_role[]));
create policy obligations_update_manager on public.compliance_obligations for update to authenticated using (public.has_firm_role(firm_id, array['OWNER', 'PARTNER', 'MANAGER']::public.firm_role[])) with check (public.has_firm_role(firm_id, array['OWNER', 'PARTNER', 'MANAGER']::public.firm_role[]));
create policy obligations_delete_manager on public.compliance_obligations for delete to authenticated using (public.has_firm_role(firm_id, array['OWNER', 'PARTNER', 'MANAGER']::public.firm_role[]));

create policy periods_select_member on public.compliance_periods for select to authenticated using (public.is_firm_member(firm_id));
create policy periods_insert_member on public.compliance_periods for insert to authenticated with check (public.is_firm_member(firm_id));
create policy periods_update_participant on public.compliance_periods for update to authenticated using (public.is_firm_member(firm_id) and (public.has_firm_role(firm_id, array['OWNER', 'PARTNER', 'MANAGER']::public.firm_role[]) or assigned_to_profile_id = auth.uid() or reviewer_profile_id = auth.uid())) with check (public.is_firm_member(firm_id));
create policy periods_delete_manager on public.compliance_periods for delete to authenticated using (public.has_firm_role(firm_id, array['OWNER', 'PARTNER', 'MANAGER']::public.firm_role[]));

create policy documents_select_member on public.documents for select to authenticated using (public.is_firm_member(firm_id));
create policy documents_insert_member on public.documents for insert to authenticated with check (public.is_firm_member(firm_id) and uploaded_by_profile_id = auth.uid());
create policy documents_update_uploader on public.documents for update to authenticated using (public.is_firm_member(firm_id) and (uploaded_by_profile_id = auth.uid() or public.has_firm_role(firm_id, array['OWNER', 'PARTNER', 'MANAGER']::public.firm_role[]))) with check (public.is_firm_member(firm_id));
create policy documents_delete_manager on public.documents for delete to authenticated using (public.is_firm_member(firm_id) and (uploaded_by_profile_id = auth.uid() or public.has_firm_role(firm_id, array['OWNER', 'PARTNER', 'MANAGER']::public.firm_role[])));

create policy audit_events_select_member on public.audit_events for select to authenticated using (public.is_firm_member(firm_id));
create policy audit_events_insert_actor on public.audit_events for insert to authenticated with check (public.is_firm_member(firm_id) and actor_profile_id = auth.uid());
-- There are deliberately no audit_events update/delete policies: the table is append-only.

grant usage on schema public to authenticated;
grant select, insert, update, delete on all tables in schema public to authenticated;
revoke all on all tables in schema public from anon;

commit;
