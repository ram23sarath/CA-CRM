# Northstar Practice

Northstar is an independent, clean-room practice-management application foundation for Indian CA/CS firms. It does not reuse Turia code, branding, copy, assets, credentials, or non-public behaviour.

## Foundation stages

The foundation delivers an original responsive application shell, password-based authentication with pending firm approval, a reviewed PostgreSQL/Supabase tenancy foundation, client/task persistence, and a configurable manual compliance calendar. Firm switching, billing records, and integrations remain intentionally unconnected.

### Route inventory

Public routes:

- `/` — independent product home
- `/features` — capability overview
- `/pricing` — directional pricing preview
- `/login` — email/password sign-in
- `/signup` — email/password firm registration with pending approval
- `/pending-approval` — authenticated pending-registration status
- `/registration-rejected` — authenticated rejected-registration status

Workspace routes (protected-layout placeholder only):

- `/app` — practice overview
- `/app/clients` — client context
- `/app/tasks` — assignments and review
- `/app/compliance` — configured compliance periods and expiry registers
- `/app/calendar` — compliance due-date calendar
- `/app/leads` — lead pipeline, follow-ups, proposals, and client conversion
- `/app/billing` — commercial context
- `/app/team` — people and roles
- `/app/reports` — practice perspective
- `/app/settings` — workspace policy and connections
- `/admin/approvals` — platform-administrator-only registration review

The workspace has a desktop sidebar, a responsive mobile drawer with Escape and focus handling, a top-bar firm switcher placeholder, and a user-menu placeholder. Navigation links work; placeholder controls do not claim to save, connect, or authenticate.

## Stack and commands

- Next.js App Router 16.4.3, React 19.3.1, and TypeScript 5.9.3
- Tailwind CSS 4.3.3 through the PostCSS plugin, with original CSS custom-property tokens
- Supabase client packages, Zod, and configurable adapters reserved for later stages
- pnpm 11.25.0 (Node.js `>=22`)
- Vitest 5 + Testing Library + jsdom for the minimal Stage 1 interaction/state tests

```bash
pnpm install
pnpm dev
pnpm lint
pnpm typecheck
pnpm test
pnpm build
```

The production build uses `next build --webpack` because the local Next 16 Turbopack/PostCSS combination exits while launching its CSS subprocess. This is a build-runner choice only; no domain behaviour depends on webpack.

## Project layout

- `src/app/(public)/` — public layout and public screens.
- `src/app/(auth)/` — sign-in and sign-up placeholders with the same public chrome.
- `src/app/(workspace)/app/` — workspace layout and module routes.
- `src/components/shell/` — responsive workspace shell and navigation.
- `src/components/ui/` — PageHeader, Button, Input, Badge, EmptyState, LoadingSkeleton, DataTable, and ConfirmDialog patterns.
- `src/features/workspace/` — route-safe module copy and placeholder overview composition; no persistence or domain services.
- `src/app/globals.css` — original navy, teal, cool off-white, surface, status, spacing, typography, radii, focus, responsive, and reduced-motion tokens.
- `tests/` — focused shell and UI-state tests.
- `supabase/migrations/` — ordered schema, RLS, private-storage, and authentication/approval migrations.
- `docs/clone-baseline.md` — Stage 0 audit and clean-room constraints.

## Environment

`.env.example` contains placeholder-only `SUPABASE_URL`, `SUPABASE_ANON_KEY`, and `SUPABASE_SERVICE_ROLE_KEY` names. The service role key is server-only and is used only by server routes/actions for trusted database functions. Never commit real values or import it into browser code.

## Stage 2 database foundation

The ordered migrations in `supabase/migrations/` define the firm-scoped PostgreSQL schema, composite tenant foreign keys, forced RLS, and a private document bucket policy skeleton. `supabase/seed.sql` is local-only synthetic data; `supabase/tests/rls_isolation.sql` is a rollback-only authenticated-role isolation test. No database was available in this repository, so these files have not been applied here.

Stage 3 adds `0004_auth_approval.sql`. New registrations create a pending firm, pending OWNER membership, and canonical pending signup request through a trusted transaction. The `firm_signup_requests` status is the source of truth; its database trigger synchronizes firm/membership state and audit records for both application decisions and direct SQL decisions. The application never assigns `PLATFORM_ADMIN` from signup or editable Auth metadata.

### Supabase Auth configuration

In Supabase Dashboard → Authentication → Providers → Email, enable Email and Password and disable **Confirm email** for this password-only flow. Do not enable email OTP, magic links, phone providers, or passwordless methods. Configure the site URL and redirect URLs for the deployed application as usual; this implementation does not use an email verification-code or OTP screen.

### First platform administrator

1. Create the administrator's email/password account through the normal Supabase Auth Dashboard flow (or the application signup flow).
2. Copy that Auth user's UUID from Authentication → Users.
3. In SQL Editor, run the trusted bootstrap statement below, replacing only the UUID placeholder with the administrator's UUID:

```sql
insert into public.platform_admins (user_id, note)
values ('<administrator-auth-user-uuid>', 'Initial platform administrator')
on conflict (user_id) do update set enabled = true;
```

This registry is database-controlled and is not editable by ordinary users. Do not store platform-admin authority in `raw_user_meta_data`.

### Dashboard approval procedure

The canonical approval operation is a trusted SQL function. In Supabase Dashboard → SQL Editor, inspect pending requests with:

```sql
select id, firm_name_snapshot, full_name_snapshot, email_snapshot, status, submitted_at
from public.firm_signup_requests
where status = 'PENDING'
order by submitted_at;
```

Approve or reject by calling the function with the pending request UUID and a UUID present in `public.platform_admins`:

```sql
select public.set_firm_signup_request_status('<request-uuid>', 'APPROVED', '<administrator-auth-user-uuid>');
select public.set_firm_signup_request_status('<request-uuid>', 'REJECTED', '<administrator-auth-user-uuid>', 'Please provide the requested firm details.');
```

Both calls lock the request, reject invalid/repeated transitions, update the firm and OWNER membership atomically, and write an audit event. Never manually update three tables separately. Run these commands only as a trusted database administrator; never expose the service-role key.

## Stage 4 client master

Migration `0005_client_master.sql` adds PAN/GSTIN, address, service tags, uniqueness per firm, and audited server-side client mutation RPCs. PAN and GSTIN checks validate only a local format (GSTIN state code `01`–`38`); they do not verify government records. The migration removes direct authenticated writes to client/contact/document rows so the firm is derived from the active membership inside the RPC.

`/app/clients` has server pagination, name/PAN/GSTIN search, filters, archive browsing, and firm-derived relationship-manager choices. `/app/clients/new` creates clients and `/app/clients/[id]` provides Overview, Tasks, Compliance, Documents, Billing, and a clearly unavailable Notices tab.

Client documents use the non-public `firm-documents` bucket under `<firm_id>/<client_id>/<random-key>-<sanitized-file-name>`. Object paths never appear in the UI. Downloads pass through a firm-scoped route that creates a five-minute signed URL. The bucket accepts PDF, JPEG, PNG, WebP, text, Word, and Excel formats; its database size limit remains 50 MB. Set `CLIENT_DOCUMENT_MAX_BYTES` only to a value no greater than that bucket limit (default: `52428800`).

Run local database integration coverage after migrations and seed data are applied:

```bash
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/tests/client_master.sql
```

This checkout has no Playwright dependency, browser configuration, or disposable Supabase database, so those environment-dependent checks are not represented as passed.

## Next-stage prerequisites

## Stage 5 task workflow

Migration `0006_task_workflow.sql` changes the legacy task state model to `TODO → IN_PROGRESS → IN_REVIEW → COMPLETED`. A reviewer can return an in-review task to work only with a comment. Completion is server-authorized for the designated reviewer or a manager; self-review is denied unless firm `settings.allow_self_review` is explicitly `true`. Status changes, checklist changes, comments, document-request changes, assignment creation, review outcomes, and recurring generation write task history and audit events.

Recurring work is intentionally manual in this stage because no scheduler/outbox is configured. The generator uses the firm timezone (default `Asia/Kolkata`) for its due timestamp and returns the same task on retries through a unique `firm_id + recurrence_key` (`template:client:period-start`). It does not infer statutory dates. Configure templates with monthly, quarterly, or annual recurrence through the database/admin workflow before using `/app/tasks/recurring`.

## Stage 6 compliance calendar and expiry registers

Migration `0007_compliance_calendar.sql` adds firm-scoped `compliance_templates` and `expiry_registers`, and extends the existing `compliance_periods` table with a client/type/period identity, due-date snapshot, task link, evidence document link, filing reference, provenance, last verified date, and last-updated actor. The unique active-period identity is `firm_id + client_id + type_code + period_key`; duplicate generation/import attempts return the existing record and append an audit event. Templates affect future generated periods only because the period due date is stored as a snapshot.

The MVP supports configurable `GST`, `TDS`, `INCOME_TAX`, and `MCA_ROC` templates while allowing other firm codes. A template stores `MONTHLY`, `QUARTERLY`, `ANNUAL`, or `CUSTOM` frequency and a configurable day offset from period end. A configured Stage 5 recurring task template can be linked; generation calls the Stage 5 idempotent task service and stores the task link. A missing due-date offset or archived/late-created client blocks generation with an explicit error.

Compliance workflow states are `UPCOMING`, `IN_PROGRESS`, `READY_FOR_REVIEW`, `FILED`, and `CANCELLED`. `DUE` and `OVERDUE` are display-only derived states: for an unresolved record, due date equal to the firm-local date is `DUE`, and a due date before it is `OVERDUE`. `FILED` requires explicit user confirmation; reminders, dates, or task completion never mark it filed. Date-only fields are used for period and expiry dates. Event timestamps remain UTC; local calendar comparisons use the persisted firm timezone and default to `Asia/Kolkata`.

`/app/compliance` provides list/calendar views and filters for client, configurable type, period key, due range, owner, and workflow/derived status. `/app/calendar` opens the same calendar view. The DSC and License Register stores owner/custodian, optional client, expiry, reminder, status, provenance, and verification date; active records expiring within 30 local days appear on the dashboard. All writes are audited RPCs and no portal request is made. There is no government login, scraping, CAPTCHA handling, unofficial endpoint, filing submission, paid notice credit, or legal due-date recommendation.

### Stage 7 prerequisites

- Apply `0007_compliance_calendar.sql` and run `supabase/tests/compliance_calendar.sql` plus the existing RLS/task/client scripts against a disposable Supabase database.
- Approve an authoritative, versioned due-date source and legal/compliance review process before importing statutory rules or presenting dates as recommendations.
- Define reminder channels, consent/opt-out, delivery retries, idempotency, and an outbox/worker ownership model; Stage 6 stores reminder dates but sends nothing.
- Decide the production audit retention/export policy, evidence document retention policy, and whether period/task assignment must synchronize bidirectionally.
- Add browser E2E coverage against a disposable authenticated tenant and verify mobile calendar/list interaction after the database environment is available.

## Stage 7 lead CRM and proposals

Migration `0008_lead_crm.sql` adds firm-scoped leads, lead contacts, append-only lead activity, follow-up reminders, proposal records, immutable proposal versions, and proposal event history. The pipeline is `LEAD → FOLLOW_UP → QUOTATION → PROPOSAL → WON → CLIENT`; `LOST` is a separate lead status. Lead creation deduplicates active leads by normalized email or mobile and records a `lead.duplicate_ignored` audit event.

`/app/leads` supports table and kanban views with search, owner, stage, source, and stale-follow-up filters. Lead detail contains contacts, notes/activity, follow-ups, proposal versions, HTML preview, demo-only send/view/action events, accepted/rejected/expired status, and conversion. Proposal validity is compared with the firm-local date; expired proposals cannot be accepted or converted. Fee and tax estimates are stored as non-negative integer minor units with an explicit ISO currency.

Conversion is performed by `convert_lead_to_client` in one database transaction. It locks the lead and accepted proposal, either validates a selected existing client or calls the existing audited `create_client_master` RPC to create a client and primary contact, then marks the lead `CONVERTED` and proposal `CONVERTED`. Repeated conversion returns the stored client ID, preserving the original lead, proposal versions, events, and source. Commercial terms and conversion require a lead owner or OWNER/PARTNER/MANAGER role. Demo send never sends email; there is no e-signature, marketing campaign, accounting integration, or live external delivery.

The proposal document is an original server-rendered HTML preview; no PDF dependency was added because PDF support was not configured in the repository. Use the browser print flow if a local copy is needed. No external email or portal request is made.

Stage 8 adds `/app/billing/invoices`, invoice detail, client billing links, manual payments, and `/app/reports`. Billing uses firm-scoped numeric amounts rounded half-up to two decimals, INR by default, server-calculated totals, immutable issued invoice numbers/snapshots, and append-only payment entries. Completed tasks can be converted idempotently into draft invoice lines. The browser print dialog provides the MVP PDF/print path; there is no payment gateway, accounting sync, bank reconciliation, tax filing, or claim of legal GST compliance. Configurable tax fields are software fields only and require firm review.

## Stage 9 team operations and deterministic automation

Migration `0010_team_operations_automation.sql` adds attendance sessions, leave requests, timesheet entries, employee reimbursements, notification preferences/inbox, automation rules, a transactional automation outbox, per-rule/recipient delivery idempotency, leases, bounded retry/dead-letter fields, and job history. `/app/team` provides the directory, check-in/out, leave request/manager approval, non-negative timesheet entry/locking, reimbursement approval, notification action center, opt-out/channel preferences, paused rule definitions, delivery history, and the admin kill switch. Attendance stores timestamps only; no geolocation is captured.

MVP deterministic triggers are compliance due soon, task assigned, task overdue, invoice overdue, and lead follow-up due. Actions are internal notification, follow-up task, or queued email/WhatsApp preview. New rules are paused until an OWNER/PARTNER/MANAGER explicitly activates them. `src/workers/automation-runner.ts` is a trusted scheduler/cron entry point; it claims events with database leases and uses the preview adapter for every channel. It must not be invoked from a browser. No provider token is logged or shipped to client code, and Stage 9 sends no live messages.

Run the focused unit suite with `pnpm test`. Database integration coverage is in `supabase/tests/team_operations.sql`; apply the ordered migrations and seed data to a disposable local Supabase/PostgreSQL environment before running it. This checkout has no disposable database or browser E2E runner, so the SQL integration and E2E checks are not represented as passed here.

### Stage 8 prerequisites

- Approve the firm’s proposal template, commercial approval matrix, currency/minor-unit policy, and legal review for terms before adding production exports or signatures.
- Define an authenticated external sharing/e-signature contract, recipient consent, expiry/revocation semantics, and security controls; Stage 7 remains internal and demo-only.
- Decide lead retention, duplicate merge, contact provenance, and conversion reconciliation policies for already-existing clients.
- Provide a disposable Supabase environment and browser E2E runner to execute the lead CRM SQL fixture, concurrent conversion checks, cross-tenant RLS checks, and mobile pipeline tests.

### Stage 10 prerequisites

- Apply and review migration `0010_team_operations_automation.sql` against a disposable database; run team/RLS integration fixtures and authenticated browser E2E coverage.
- Choose a production scheduler/worker runtime with secret-managed provider credentials, lease monitoring, dead-letter operations, and alerting; keep `AUTOMATION_MODE=preview` until provider contracts and consent are approved.
- Define production email/WhatsApp adapters, verified sender/number ownership, opt-out retention, template review, delivery limits, and incident/retry policy. Do not enable live sends from Stage 9 defaults.
- Approve attendance/time retention, leave policy, reimbursement evidence and accounting handoff, and the audit/job-history retention policy.

Before adding domain CRUD and production operations, approve:

1. A disposable local Supabase/Docker/PostgreSQL environment and a migration review run; never reset a shared/remote database.
2. A configured Supabase Auth provider and secure deployment environment containing the documented variables.
3. Service-layer audit emission for every material mutation and authenticated-role RLS integration tests.
4. Tenant/firm boundaries, minimum roles, and an authorization matrix for future CRUD permissions.
5. Authoritative compliance-rule sources, review ownership, due-date assumptions, and the policy for deterministic reminders.
6. Review of the account/session UX before adding profile editing, invitations, or domain CRUD.

Stage 3 must not infer original Turia behaviour from this schema. It should add reviewed auth/session contracts before implementing login, CRUD, recurring-task generation, uploads, or integrations.
