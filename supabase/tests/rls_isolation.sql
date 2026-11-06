-- RLS integration checks for a local Supabase database.
-- Run as the database owner so SET ROLE can exercise the normal authenticated role:
--   psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/tests/rls_isolation.sql
-- The transaction is rolled back and never changes seed data.

\set ON_ERROR_STOP on

begin;
set local role authenticated;

-- Firm A owner sees only Firm A.
select set_config('request.jwt.claim.sub', '20000000-0000-0000-0000-000000000001', true);
select set_config('request.jwt.claims', '{"sub":"20000000-0000-0000-0000-000000000001","role":"authenticated"}', true);

do $$
declare
  firm_count integer;
  client_count integer;
begin
  select count(*) into firm_count from public.firms;
  if firm_count <> 1 then raise exception 'owner should see one firm, saw %', firm_count; end if;
  select count(*) into client_count from public.clients;
  if client_count <> 1 then raise exception 'owner should see one client, saw %', client_count; end if;
end
$$;

-- Changing firm_id must not permit a cross-tenant insert.
do $$
begin
  begin
    insert into public.clients (firm_id, created_by_profile_id, client_code, legal_name, display_name)
    values ('10000000-0000-0000-0000-000000000002', '20000000-0000-0000-0000-000000000001', 'RLS-ESCAPE', 'Should Never Persist', 'Should Never Persist');
    raise exception 'cross-tenant client insert was allowed';
  exception when insufficient_privilege then
    null;
  end;
end
$$;

-- Composite foreign keys prevent connecting a Firm B client to a Firm A task.
do $$
begin
  begin
    insert into public.tasks (firm_id, client_id, created_by_profile_id, title)
    values ('10000000-0000-0000-0000-000000000001', '40000000-0000-0000-0000-000000000002', '20000000-0000-0000-0000-000000000001', 'Cross-tenant task must fail');
    raise exception 'cross-tenant task foreign key was allowed';
  exception when foreign_key_violation then
    null;
  end;
end
$$;

-- Staff can work with tenant rows but cannot update firm plan/settings.
select set_config('request.jwt.claim.sub', '20000000-0000-0000-0000-000000000003', true);
select set_config('request.jwt.claims', '{"sub":"20000000-0000-0000-0000-000000000003","role":"authenticated"}', true);
do $$
declare
  changed integer;
begin
  update public.firms set plan = 'SCALE', settings = '{"staff_attempt":true}'::jsonb where id = '10000000-0000-0000-0000-000000000001';
  get diagnostics changed = row_count;
  if changed <> 0 then raise exception 'staff changed firm settings'; end if;
end
$$;

-- A user with no active membership sees no tenant rows.
select set_config('request.jwt.claim.sub', '20000000-0000-0000-0000-000000000099', true);
select set_config('request.jwt.claims', '{"sub":"20000000-0000-0000-0000-000000000099","role":"authenticated"}', true);
do $$
declare
  firm_count integer;
  client_count integer;
begin
  select count(*) into firm_count from public.firms;
  select count(*) into client_count from public.clients;
  if firm_count <> 0 or client_count <> 0 then raise exception 'unaffiliated user saw tenant rows: firms %, clients %', firm_count, client_count; end if;
end
$$;

rollback;
