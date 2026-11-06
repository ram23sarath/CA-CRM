-- Stage 4 client-master integration checks. Run after all migrations and seed data:
-- psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/tests/client_master.sql
-- The transaction rolls back every mutation. It exercises firm scope, contact CRUD,
-- archive/restore, private object policy, and a tampered client ID.
\set ON_ERROR_STOP on
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', '20000000-0000-0000-0000-000000000001', true);
select set_config('request.jwt.claims', '{"sub":"20000000-0000-0000-0000-000000000001","role":"authenticated"}', true);

do $$
declare new_client_id uuid; contact_id uuid;
begin
  new_client_id := public.create_client_master('Stage Four Synthetic', 'Stage Four', 'COMPANY', 'ABCDE1234F', '27ABCDE1234F1Z5', null, null, array['GST'], 'ACTIVE', null, '{"full_name":"Synthetic Contact"}'::jsonb);
  select c.id into contact_id from public.client_contacts c where c.client_id = new_client_id and c.is_primary;
  if contact_id is null then raise exception 'primary contact was not created'; end if;
  perform public.upsert_client_contact(new_client_id, contact_id, 'Changed Contact', 'contact@example.test', null, null, true);
  perform public.archive_client_contact(new_client_id, contact_id);
  if not exists (select 1 from public.client_contacts where id = contact_id and archived_at is not null) then raise exception 'contact was not archived'; end if;
  perform public.set_client_archived(new_client_id, true);
  if not exists (select 1 from public.clients where id = new_client_id and archived_at is not null) then raise exception 'client was not archived'; end if;
  perform public.set_client_archived(new_client_id, false);
end $$;

do $$ begin
  begin
    perform public.create_client_master('Duplicate', 'Duplicate', 'COMPANY', 'ABCDE1234F', null, null, null, '{}', 'ACTIVE', null, '{}'::jsonb);
    raise exception 'duplicate PAN was accepted';
  exception when unique_violation then null;
  end;
end $$;

do $$ begin
  begin
    perform public.set_client_archived('40000000-0000-0000-0000-000000000002', true);
    raise exception 'cross-firm client was reachable';
  exception when no_data_found then null;
  end;
end $$;

do $$ begin
  begin
    insert into storage.objects (bucket_id, name, owner_id) values ('firm-documents', '10000000-0000-0000-0000-000000000002/tampered/file.pdf', auth.uid());
    raise exception 'foreign-firm object upload was allowed';
  exception when insufficient_privilege then null;
  end;
end $$;
rollback;
