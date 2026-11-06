-- Northstar Practice Stage 4: firm-scoped client master and private documents.
-- Client writes are intentionally performed through the RPCs below so the firm is
-- derived from the authenticated membership, never from a browser value.

begin;

alter table public.clients add column if not exists pan text;
alter table public.clients add column if not exists gstin text;
alter table public.clients add column if not exists address text;
alter table public.clients add column if not exists service_tags text[] not null default '{}';

alter table public.clients drop constraint if exists clients_pan_format_check;
alter table public.clients add constraint clients_pan_format_check
  check (pan is null or pan ~ '^[A-Z]{5}[0-9]{4}[A-Z]$');
alter table public.clients drop constraint if exists clients_gstin_format_check;
alter table public.clients add constraint clients_gstin_format_check
  check (gstin is null or (gstin ~ '^[0-3][0-9][A-Z]{5}[0-9]{4}[A-Z][0-9A-Z]Z[0-9A-Z]$' and substring(gstin from 1 for 2)::integer between 1 and 38));
alter table public.clients drop constraint if exists clients_service_tags_check;
alter table public.clients add constraint clients_service_tags_check
  check (cardinality(service_tags) <= 30);

create unique index if not exists clients_firm_pan_unique on public.clients (firm_id, pan) where pan is not null;
create unique index if not exists clients_firm_gstin_unique on public.clients (firm_id, gstin) where gstin is not null;
create index if not exists clients_firm_search_idx on public.clients (firm_id, archived_at, legal_name);

create or replace function public.storage_client_id(storage_path text)
returns uuid
language plpgsql
immutable
set search_path = public
as $$
declare second_segment text := split_part(storage_path, '/', 2);
begin
  if second_segment ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then return second_segment::uuid; end if;
  return null;
end;
$$;

create or replace function public.can_access_client_storage(storage_path text)
returns boolean
language sql
stable
security definer
set search_path = public, auth
as $$
  select public.is_firm_member(public.storage_firm_id(storage_path))
    and exists (select 1 from public.clients c where c.firm_id = public.storage_firm_id(storage_path) and c.id = public.storage_client_id(storage_path));
$$;

revoke all on function public.storage_client_id(text) from public;
revoke all on function public.can_access_client_storage(text) from public;
grant execute on function public.storage_client_id(text), public.can_access_client_storage(text) to authenticated, service_role;

drop policy if exists firm_documents_select on storage.objects;
drop policy if exists firm_documents_insert on storage.objects;
drop policy if exists firm_documents_update on storage.objects;
drop policy if exists firm_documents_delete on storage.objects;
create policy firm_documents_select on storage.objects for select to authenticated using (bucket_id = 'firm-documents' and public.can_access_client_storage(name));
create policy firm_documents_insert on storage.objects for insert to authenticated with check (bucket_id = 'firm-documents' and public.can_access_client_storage(name));
create policy firm_documents_update on storage.objects for update to authenticated using (bucket_id = 'firm-documents' and public.can_access_client_storage(name)) with check (bucket_id = 'firm-documents' and public.can_access_client_storage(name));
create policy firm_documents_delete on storage.objects for delete to authenticated using (bucket_id = 'firm-documents' and public.has_firm_role(public.storage_firm_id(name), array['OWNER', 'PARTNER', 'MANAGER']::public.firm_role[]));

-- Direct authenticated client/contact/document mutations are disabled in favour of
-- the audited RPC surface. Reads continue to be protected by the existing RLS policies.
drop policy if exists clients_insert_member on public.clients;
drop policy if exists clients_update_member on public.clients;
drop policy if exists clients_delete_manager on public.clients;
drop policy if exists client_contacts_insert_member on public.client_contacts;
drop policy if exists client_contacts_update_member on public.client_contacts;
drop policy if exists client_contacts_delete_manager on public.client_contacts;
drop policy if exists documents_insert_member on public.documents;
drop policy if exists documents_update_uploader on public.documents;
drop policy if exists documents_delete_manager on public.documents;

create or replace function public.client_active_membership()
returns public.firm_memberships
language plpgsql
security definer
set search_path = public, auth
as $$
declare membership public.firm_memberships;
begin
  select m.* into membership
  from public.firm_memberships m
  join public.firms f on f.id = m.firm_id
  where m.profile_id = auth.uid()
    and m.status = 'ACTIVE' and m.archived_at is null
    and f.approval_status = 'ACTIVE' and f.archived_at is null
  order by m.created_at desc
  limit 1;
  if membership.id is null then raise exception 'active firm membership is required'; end if;
  return membership;
end;
$$;

create or replace function public.client_require_manager(p_firm_id uuid)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  if not public.has_firm_role(p_firm_id, array['OWNER', 'PARTNER', 'MANAGER']::public.firm_role[]) then
    raise exception 'permission denied to change sensitive client identifiers' using errcode = '42501';
  end if;
end;
$$;

create or replace function public.create_client_master(
  p_legal_name text, p_display_name text, p_entity_type text, p_pan text,
  p_gstin text, p_address text, p_owner_profile_id uuid, p_service_tags text[],
  p_status text, p_notes text, p_contact jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = public, auth
as $$
declare m public.firm_memberships; new_id uuid := gen_random_uuid(); clean_pan text := nullif(upper(trim(p_pan)), ''); clean_gstin text := nullif(upper(trim(p_gstin)), ''); contact_name text := nullif(trim(coalesce(p_contact->>'full_name', '')), '');
begin
  m := public.client_active_membership();
  if nullif(trim(p_legal_name), '') is null or nullif(trim(p_display_name), '') is null then raise exception 'legal and display names are required'; end if;
  if p_entity_type not in ('INDIVIDUAL', 'COMPANY', 'LLP', 'PARTNERSHIP', 'TRUST', 'OTHER') then raise exception 'invalid entity type'; end if;
  if p_status not in ('ACTIVE', 'INACTIVE') then raise exception 'invalid client status'; end if;
  if clean_pan is not null and exists (select 1 from public.clients where firm_id = m.firm_id and pan = clean_pan) then raise exception 'A client with this PAN already exists in this firm' using errcode = '23505'; end if;
  if clean_gstin is not null and exists (select 1 from public.clients where firm_id = m.firm_id and gstin = clean_gstin) then raise exception 'A client with this GSTIN already exists in this firm' using errcode = '23505'; end if;
  if p_owner_profile_id is not null and not exists (select 1 from public.firm_memberships where firm_id = m.firm_id and profile_id = p_owner_profile_id and status = 'ACTIVE' and archived_at is null) then raise exception 'relationship manager is not active in this firm'; end if;
  insert into public.clients (id, firm_id, owner_profile_id, created_by_profile_id, client_code, legal_name, display_name, entity_type, pan, gstin, address, service_tags, status, notes)
  values (new_id, m.firm_id, p_owner_profile_id, auth.uid(), 'CL-' || upper(replace(new_id::text, '-', '')), trim(p_legal_name), trim(p_display_name), p_entity_type, clean_pan, clean_gstin, nullif(trim(p_address), ''), coalesce(p_service_tags, '{}'), p_status, nullif(trim(p_notes), ''));
  if contact_name is not null then
    insert into public.client_contacts (firm_id, client_id, created_by_profile_id, full_name, email, phone, designation, is_primary)
    values (m.firm_id, new_id, auth.uid(), contact_name, nullif(trim(p_contact->>'email'), ''), nullif(trim(p_contact->>'phone'), ''), nullif(trim(p_contact->>'designation'), ''), true);
  end if;
  insert into public.audit_events (firm_id, actor_profile_id, actor_user_id, action, entity_table, entity_id, metadata)
  values (m.firm_id, auth.uid(), auth.uid(), 'client.created', 'clients', new_id, jsonb_build_object('has_pan', clean_pan is not null, 'has_gstin', clean_gstin is not null));
  return new_id;
end;
$$;

create or replace function public.update_client_master(
  p_client_id uuid, p_updated_at timestamptz, p_legal_name text, p_display_name text,
  p_entity_type text, p_pan text, p_gstin text, p_address text, p_owner_profile_id uuid,
  p_service_tags text[], p_status text, p_notes text
)
returns timestamptz
language plpgsql
security definer
set search_path = public, auth
as $$
declare m public.firm_memberships; old public.clients; clean_pan text := nullif(upper(trim(p_pan)), ''); clean_gstin text := nullif(upper(trim(p_gstin)), ''); changed_identifiers boolean;
begin
  m := public.client_active_membership();
  select * into old from public.clients where id = p_client_id and firm_id = m.firm_id for update;
  if old.id is null then raise exception 'client not found' using errcode = 'P0002'; end if;
  if old.updated_at is distinct from p_updated_at then raise exception 'This client was updated by someone else. Refresh and review the latest version.' using errcode = '40001'; end if;
  if p_entity_type not in ('INDIVIDUAL', 'COMPANY', 'LLP', 'PARTNERSHIP', 'TRUST', 'OTHER') or p_status not in ('ACTIVE', 'INACTIVE') then raise exception 'invalid client values'; end if;
  changed_identifiers := old.pan is distinct from clean_pan or old.gstin is distinct from clean_gstin;
  if changed_identifiers then
    perform public.client_require_manager(m.firm_id);
    if clean_pan is not null and exists (select 1 from public.clients where firm_id = m.firm_id and pan = clean_pan and id <> p_client_id) then raise exception 'A client with this PAN already exists in this firm' using errcode = '23505'; end if;
    if clean_gstin is not null and exists (select 1 from public.clients where firm_id = m.firm_id and gstin = clean_gstin and id <> p_client_id) then raise exception 'A client with this GSTIN already exists in this firm' using errcode = '23505'; end if;
  end if;
  if p_owner_profile_id is not null and not exists (select 1 from public.firm_memberships where firm_id = m.firm_id and profile_id = p_owner_profile_id and status = 'ACTIVE' and archived_at is null) then raise exception 'relationship manager is not active in this firm'; end if;
  update public.clients set legal_name = trim(p_legal_name), display_name = trim(p_display_name), entity_type = p_entity_type, pan = clean_pan, gstin = clean_gstin, address = nullif(trim(p_address), ''), owner_profile_id = p_owner_profile_id, service_tags = coalesce(p_service_tags, '{}'), status = p_status, notes = nullif(trim(p_notes), '') where id = old.id;
  if changed_identifiers then insert into public.audit_events (firm_id, actor_profile_id, actor_user_id, action, entity_table, entity_id, metadata) values (m.firm_id, auth.uid(), auth.uid(), 'client.identifiers_updated', 'clients', old.id, jsonb_build_object('pan_changed', old.pan is distinct from clean_pan, 'gstin_changed', old.gstin is distinct from clean_gstin)); end if;
  return (select updated_at from public.clients where id = old.id);
end;
$$;

create or replace function public.set_client_archived(p_client_id uuid, p_archived boolean)
returns void
language plpgsql security definer set search_path = public, auth as $$
declare m public.firm_memberships; c public.clients;
begin
  m := public.client_active_membership(); perform public.client_require_manager(m.firm_id);
  select * into c from public.clients where id = p_client_id and firm_id = m.firm_id for update;
  if c.id is null then raise exception 'client not found' using errcode = 'P0002'; end if;
  update public.clients set archived_at = case when p_archived then timezone('utc', now()) else null end where id = c.id;
  insert into public.audit_events (firm_id, actor_profile_id, actor_user_id, action, entity_table, entity_id, metadata) values (m.firm_id, auth.uid(), auth.uid(), case when p_archived then 'client.archived' else 'client.restored' end, 'clients', c.id, jsonb_build_object('linked_work_preserved', true));
end;
$$;

create or replace function public.upsert_client_contact(p_client_id uuid, p_contact_id uuid, p_full_name text, p_email text, p_phone text, p_designation text, p_is_primary boolean)
returns uuid
language plpgsql security definer set search_path = public, auth as $$
declare m public.firm_memberships; result_id uuid;
begin
  m := public.client_active_membership();
  if not exists (select 1 from public.clients where id = p_client_id and firm_id = m.firm_id) then raise exception 'client not found' using errcode = 'P0002'; end if;
  if nullif(trim(p_full_name), '') is null then raise exception 'contact name is required'; end if;
  if p_contact_id is null then insert into public.client_contacts (firm_id, client_id, created_by_profile_id, full_name, email, phone, designation, is_primary) values (m.firm_id, p_client_id, auth.uid(), trim(p_full_name), nullif(trim(p_email), ''), nullif(trim(p_phone), ''), nullif(trim(p_designation), ''), p_is_primary) returning id into result_id;
  else update public.client_contacts set full_name = trim(p_full_name), email = nullif(trim(p_email), ''), phone = nullif(trim(p_phone), ''), designation = nullif(trim(p_designation), ''), is_primary = p_is_primary where id = p_contact_id and client_id = p_client_id and firm_id = m.firm_id returning id into result_id; if result_id is null then raise exception 'contact not found' using errcode = 'P0002'; end if; end if;
  if p_is_primary then update public.client_contacts set is_primary = false where firm_id = m.firm_id and client_id = p_client_id and id <> result_id and archived_at is null; end if;
  insert into public.audit_events (firm_id, actor_profile_id, actor_user_id, action, entity_table, entity_id) values (m.firm_id, auth.uid(), auth.uid(), 'client.contact_saved', 'client_contacts', result_id);
  return result_id;
end;
$$;

create or replace function public.archive_client_contact(p_client_id uuid, p_contact_id uuid)
returns void
language plpgsql security definer set search_path = public, auth as $$
declare m public.firm_memberships; remaining_contact uuid;
begin
  m := public.client_active_membership();
  update public.client_contacts set archived_at = timezone('utc', now()) where id = p_contact_id and client_id = p_client_id and firm_id = m.firm_id and archived_at is null;
  if not found then raise exception 'contact not found' using errcode = 'P0002'; end if;
  select id into remaining_contact from public.client_contacts where firm_id = m.firm_id and client_id = p_client_id and archived_at is null order by created_at limit 1;
  if remaining_contact is not null and not exists (select 1 from public.client_contacts where firm_id = m.firm_id and client_id = p_client_id and archived_at is null and is_primary) then update public.client_contacts set is_primary = true where id = remaining_contact; end if;
  insert into public.audit_events (firm_id, actor_profile_id, actor_user_id, action, entity_table, entity_id) values (m.firm_id, auth.uid(), auth.uid(), 'client.contact_archived', 'client_contacts', p_contact_id);
end;
$$;

create or replace function public.create_client_document(p_client_id uuid, p_storage_path text, p_file_name text, p_mime_type text, p_byte_size bigint, p_checksum text)
returns uuid
language plpgsql security definer set search_path = public, auth as $$
declare m public.firm_memberships; document_id uuid := gen_random_uuid();
begin
  m := public.client_active_membership();
  if not exists (select 1 from public.clients where id = p_client_id and firm_id = m.firm_id) then raise exception 'client not found' using errcode = 'P0002'; end if;
  if p_storage_path !~ ('^' || m.firm_id::text || '/' || p_client_id::text || '/') then raise exception 'invalid private document path'; end if;
  insert into public.documents (id, firm_id, client_id, uploaded_by_profile_id, storage_path, file_name, mime_type, byte_size, checksum) values (document_id, m.firm_id, p_client_id, auth.uid(), p_storage_path, p_file_name, p_mime_type, p_byte_size, p_checksum);
  insert into public.audit_events (firm_id, actor_profile_id, actor_user_id, action, entity_table, entity_id, metadata) values (m.firm_id, auth.uid(), auth.uid(), 'client.document_uploaded', 'documents', document_id, jsonb_build_object('client_id', p_client_id, 'byte_size', p_byte_size));
  return document_id;
end;
$$;

revoke all on function public.client_active_membership() from public;
revoke all on function public.client_require_manager(uuid) from public;
revoke all on function public.create_client_master(text, text, text, text, text, text, uuid, text[], text, text, jsonb) from public;
revoke all on function public.update_client_master(uuid, timestamptz, text, text, text, text, text, text, uuid, text[], text, text) from public;
revoke all on function public.set_client_archived(uuid, boolean) from public;
revoke all on function public.upsert_client_contact(uuid, uuid, text, text, text, text, boolean) from public;
revoke all on function public.archive_client_contact(uuid, uuid) from public;
revoke all on function public.create_client_document(uuid, text, text, text, bigint, text) from public;
grant execute on function public.create_client_master(text, text, text, text, text, text, uuid, text[], text, text, jsonb), public.update_client_master(uuid, timestamptz, text, text, text, text, text, text, uuid, text[], text, text), public.set_client_archived(uuid, boolean), public.upsert_client_contact(uuid, uuid, text, text, text, text, boolean), public.archive_client_contact(uuid, uuid), public.create_client_document(uuid, text, text, text, bigint, text) to authenticated, service_role;

-- Keep the bucket private and allow office formats used by the client master.
update storage.buckets set public = false, file_size_limit = 52428800,
  allowed_mime_types = array['application/pdf','image/jpeg','image/png','image/webp','text/plain','application/msword','application/vnd.openxmlformats-officedocument.wordprocessingml.document','application/vnd.ms-excel','application/vnd.openxmlformats-officedocument.spreadsheetml.sheet']
where id = 'firm-documents';

comment on column public.clients.pan is 'Format validation only; this does not verify PAN with a government authority.';
comment on column public.clients.gstin is 'Format and state-code validation only; this does not verify GSTIN with a government authority.';

commit;
