# Stage 2 database migrations

These ordered migrations define an independent PostgreSQL model for firm-scoped practice operations. They target Supabase PostgreSQL and do not infer or copy any original product schema.

## Order

1. `0001_core_schema.sql` — `pgcrypto`, `firm_role`, shared timestamp trigger, core tables, composite tenant foreign keys, checks, timestamps, soft-archive columns, and indexes.
2. `0002_rls_policies.sql` — security-definer membership/role helpers, forced RLS, and authenticated-role policies. There are no update/delete policies for `audit_events`.
3. `0003_private_storage_policies.sql` — private `firm-documents` bucket skeleton and firm-path policies for `storage.objects`.
4. `0011_release_hardening.sql` — keeps notifications preview-only for this release and aligns the private bucket MIME policy with server upload validation.
4. `0004_auth_approval.sql` — pending firm signup requests, platform-admin registry, access-state helpers, trusted registration/approval functions, status synchronization trigger, and RLS.
5. `0005_client_master.sql` — audited client/contact/document mutation RPCs, identifiers, and private client document policies.
6. `0006_task_workflow.sql` — reviewed task lifecycle, task templates, checklist/history, and idempotent recurring task generation.
7. `0007_compliance_calendar.sql` — configurable compliance periods, task links, expiry registers, local date semantics, and audited manual-only operations.
8. `0008_lead_crm.sql` — firm-scoped lead pipeline, follow-ups, proposal versions/events, demo-only proposal actions, and atomic idempotent client conversion.
9. `0009_billing.sql` — firm billing profiles, draft/proforma/issued/void invoices, decimal line calculations, immutable issue numbers, append-only payment entries, completed-task conversion, and manager-controlled voiding.

## Tenant strategy

Every tenant-owned table has a non-null `firm_id`. Relationships to tenant-owned parents use composite foreign keys such as `(firm_id, client_id)`, so changing an ID cannot connect a record to another firm. Membership helpers use `auth.uid()` and only accept active, non-archived memberships.

The role model is `OWNER`, `PARTNER`, `MANAGER`, and `STAFF`:

- Owners, partners, and managers may manage firm settings, service definitions, templates, compliance definitions, and destructive operations where policies allow.
- Owners and managers manage memberships.
- Staff may work with client/task/contact records and assigned task/compliance records, but cannot update firm settings/plan or manage roles.
- Audit events are append-only. The later service layer must write one material-mutation event with the acting profile, entity, action, and structured metadata.
- Billing amounts use PostgreSQL `numeric(18,2)` and database half-up rounding. Invoice totals are recomputed server-side; issued invoice client/billing snapshots and invoice numbers are immutable. Payment corrections are ledger entries, never updates/deletes. Tax fields are configurable software fields and are not professional tax advice.

The first firm owner is a server-side bootstrap operation. It must not be implemented by allowing arbitrary authenticated users to self-join a firm.

## Local application

The repository does not currently contain Supabase CLI, Docker, `psql`, a Supabase project, or a database connection. No migration has been applied during Stage 2. With the Supabase CLI installed and a local project configured, use the CLI's local workflow (for example, `supabase start` followed by `supabase db reset`) only against that disposable local database. Never run a reset against a remote/shared project.

The local-only `supabase/seed.sql` inserts synthetic demo users, firms, memberships, clients, tasks, compliance records, and an audit event. Demo emails use the reserved `.example.test` domain, passwords are unusable, and identifiers are explicitly fictional/invalid. Do not use this seed in production.

## RLS test

`supabase/tests/rls_isolation.sql` uses `SET ROLE authenticated`, JWT claim settings, and a rollback-only transaction to check:

- Firm A sees only its own rows.
- A cross-firm insert is denied.
- Composite foreign keys reject a cross-firm task/client relationship.
- Staff cannot change firm plan/settings.
- An unaffiliated authenticated user sees no tenant rows.

Run it as a database owner against a disposable local database so the script can switch to the normal `authenticated` role:

```bash
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/tests/rls_isolation.sql
```

`SUPABASE_URL`, `SUPABASE_ANON_KEY`, and `SUPABASE_SERVICE_ROLE_KEY` are the only environment variable names reserved for this stage. The service role key is server-only and must never be used from browser code.

Stage 3 requires Supabase Auth Email/Password enabled with **Confirm email disabled**. OTP, magic-link, phone, and passwordless providers are intentionally not part of this implementation. Use `README.md` for the first platform-admin bootstrap and Dashboard approval procedure.
