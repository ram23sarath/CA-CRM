-- Northstar Practice Stage 2: private firm document storage skeleton.
-- Supabase provides storage.buckets and storage.objects; no public bucket is created.

begin;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'firm-documents',
  'firm-documents',
  false,
  52428800,
  array['application/pdf', 'image/jpeg', 'image/png', 'text/plain']
)
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

create policy firm_documents_select on storage.objects
for select to authenticated
using (
  bucket_id = 'firm-documents'
  and public.is_firm_member(public.storage_firm_id(name))
);

create policy firm_documents_insert on storage.objects
for insert to authenticated
with check (
  bucket_id = 'firm-documents'
  and public.is_firm_member(public.storage_firm_id(name))
);

create policy firm_documents_update on storage.objects
for update to authenticated
using (
  bucket_id = 'firm-documents'
  and public.is_firm_member(public.storage_firm_id(name))
)
with check (
  bucket_id = 'firm-documents'
  and public.is_firm_member(public.storage_firm_id(name))
);

create policy firm_documents_delete on storage.objects
for delete to authenticated
using (
  bucket_id = 'firm-documents'
  and public.has_firm_role(public.storage_firm_id(name), array['OWNER', 'PARTNER', 'MANAGER']::public.firm_role[])
);

commit;
