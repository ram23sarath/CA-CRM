# Stage 10 release readiness and handover

## Release decision

**Not release-ready.** The application has source-level tenancy controls, private-storage policy, preview-only notification adapters, and a Stage 10 hardening migration, but this checkout has neither a disposable Supabase/PostgreSQL environment nor a browser E2E runner. The database migrations and RLS fixtures therefore have not been executed, and required cross-tenant/browser evidence does not yet exist.

Do not deploy to production until the blocked checks below pass against an isolated non-production environment and a reviewer records the results.

## Controls reviewed

| Control | Evidence / current state |
| --- | --- |
| Tenant isolation | Tenant-owned records carry `firm_id`; composite tenant foreign keys and forced RLS are introduced in migrations `0001` and `0002`. Application services additionally filter by the active firm. Database execution remains required. |
| Privileged access | The service-role client is isolated in `src/lib/supabase/service.ts`; its use is limited to registration approval/setup and the trusted worker. No credential values are in the repository; `.env.example` contains placeholders only. |
| Private documents | `firm-documents` is non-public; policies derive the firm from object paths. Signed download links are created only after firm/client/document lookup. Migration `0011` aligns bucket MIME rules with upload validation. |
| Authentication and CSRF | Protected routes verify Supabase user state and access status. API mutations now require an explicit same-origin `Origin` header. Supabase session cookie flags must still be verified in the deployed Auth configuration. |
| External notifications | Every current adapter is `PreviewNotificationAdapter` and makes no network call. Migration `0011` makes `safe_preview_mode` permanently true for this release. |
| XSS and PII logging | No `dangerouslySetInnerHTML` or application `console.*` use was found in `src`; React rendering escapes free text. Database/browser XSS regression remains required. |
| Browser hardening | CSP, anti-framing, nosniff, strict referrer, Permissions Policy, and HSTS headers are set in `next.config.ts`. Validate CSP against the production Supabase/custom-domain setup before go-live. |
| Audit and recoverability | Domain mutations are routed through audited RPCs; worker failures/dead letters remain visible in automation history. Backup/restore must be proven in the target infrastructure. |

## Required verification matrix

Run from a clean checkout using Node 22 and pnpm 11. Do not label an unrun command as passed.

| Scope | Command / method | Release gate |
| --- | --- | --- |
| Static checks | `pnpm lint`, `pnpm typecheck`, `pnpm test`, `pnpm build` | Must pass |
| Dependency audit | `pnpm audit --prod` | Review all findings; do not silently waive production findings |
| RLS and storage | Apply migrations to a disposable DB, seed synthetic data, then run every `supabase/tests/*.sql` with `psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f <file>` | Must pass |
| Tenant tampering | In the disposable DB/browser, attempt cross-firm reads/writes with replaced client, task, document, invoice, lead, leave, and notification IDs | Must deny or return no data |
| Role escalation | Attempt staff approval, automation activation, billing issue/payment, registration approval, and manager-only mutation routes | Must deny |
| Critical workflows | Browser E2E: signup/login, client create, task/review, recurring generation, compliance calendar, invoice/payment, lead conversion, leave approval, notification preview | Must pass |
| Security regression | Browser/API checks for cross-origin POST, replay/duplicate request, free-text XSS, private storage URL, session expiry/refresh, worker retry/idempotency | Must pass |
| Accessibility and responsive | Keyboard-only traversal of the listed workflows plus 320 px and common mobile viewport smoke checks | Must pass |
| Restore | Restore a fresh encrypted backup into an isolated project and run an authenticated read-only smoke test | Must pass and be recorded |

The repository currently has no Playwright/Cypress configuration and no provisioned disposable database; these rows are explicitly **blocked**, not passed.

## Deployment prerequisites

1. Provision a separate Supabase project/database for test, staging, and production. Never run migrations, seed data, resets, or test fixtures against production.
2. Configure Supabase Email/Password only as described in `README.md`; set approved site and redirect URLs; verify secure, HttpOnly, SameSite session cookies over HTTPS.
3. Store production secrets only in the deployment secret manager. Restrict `SUPABASE_SERVICE_ROLE_KEY` to the worker and server routes; never expose it with a `NEXT_PUBLIC_` name.
4. Configure the immutable public `APP_ORIGIN` for the deployed site, enable HTTPS at the edge, and verify the response headers in production.
5. Keep `AUTOMATION_MODE=preview` and `AUTOMATION_WORKER_ENABLED=false` unless an approved scheduler, alerting, consent policy, and separately reviewed provider adapter exist. This release cannot send external messages.
6. Set database backups, point-in-time recovery, retention, encryption, access review, and alert ownership in the managed platform. These are deployment controls, not claims made by this repository.

## Environment inventory

| Name | Required | Description |
| --- | --- | --- |
| `SUPABASE_URL` | Yes | Server-side URL for the selected Supabase project. |
| `SUPABASE_ANON_KEY` | Yes | Publishable/anonymous key used by the server-side SSR client. |
| `SUPABASE_SERVICE_ROLE_KEY` | Worker and trusted admin paths | Privileged server-only key. Never expose to browsers or commit. |
| `APP_ORIGIN` | Production | Canonical HTTPS public origin for request-origin validation, for example `https://app.example.com`. |
| `CLIENT_DOCUMENT_MAX_BYTES` | No | Server upload cap; must not exceed the bucket's 50 MB policy. |
| `AUTOMATION_MODE` | Yes | Keep `preview` for this release. |
| `AUTOMATION_WORKER_ENABLED` | Yes | Keep `false` until the worker is safely deployed and operated. |
| `DATABASE_URL` | CI/local integration only | Privileged disposable-database connection used by `psql` fixtures. Never set it to production. |

## Migration and rollback procedure

1. Take and verify a backup, record the current migration set and deployment revision, and announce a maintenance window.
2. Apply ordered SQL migrations `0001` through `0011` to a freshly restored staging database first. Run all SQL fixtures and browser regressions there.
3. For production, apply only the next unapplied migration using the platform's reviewed migration mechanism. Do not use `supabase/seed.sql`.
4. Validate bucket privacy, RLS checks, header responses, login, read-only tenant access, and worker preview mode before opening traffic.
5. Rollback is **deploy rollback plus database restore**: redeploy the prior application revision, pause the worker, and restore the pre-migration backup to a new isolated database/project. Validate there, then perform the provider-approved cutover. Do not drop migrations or run destructive reset commands in production.

`0011_release_hardening.sql` is safe to re-run only through the migration framework once; its automation constraint is intentionally not a switch for live delivery.

## Backup/restore and incident checklist

Backup/restore evidence must include backup timestamp, source project, encrypted destination, restore project, migration version, sanitized row-count/read-only smoke results, operator, and disposal time for the restore environment. Never paste secrets or PII into the record.

For a suspected incident:

1. Pause automation, restrict service-role access, and preserve audit/job-history evidence.
2. Rotate affected secrets/sessions through the platform; do not log their values.
3. Establish impacted firms, records, time window, and data exposure using the audit trail and provider logs.
4. Notify the security/privacy owner and follow the organization’s legal and customer-notification process.
5. Restore service only after containment, root-cause review, and regression verification; retain a dated post-incident record.

## Known limitations and backlog

- **P0 blocker:** database integration/RLS/storage tests and cross-tenant tampering tests are not executed in this checkout.
- **P0 blocker:** browser E2E, accessibility scan, mobile workflow test, performance measurement, and backup-restore evidence are absent.
- **P1:** No distributed rate limiter is configured for signup/login. Apply managed edge/auth rate limits before internet exposure; an in-process limiter would be misleading for multi-instance deployment.
- **P1:** CSP permits inline Next runtime assets and Supabase hosted connections; test and tighten it per the chosen deployment domain.
- **P2:** No CI pipeline exists. Add one only after selecting the project’s database and browser-test provisioning model.
