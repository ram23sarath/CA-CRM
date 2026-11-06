# Turia clean-room clone — Stage 0 baseline

**Stage 0 status:** complete baseline audit. This record describes the repository as inspected on 2026-11-02 (Asia/Calcutta). The audit itself did not create or change product code, dependencies, databases, environments, or deployment configuration. Subsequent Stage 1 scaffold work is recorded in the repository README.

## Audit boundary and repository state

- **Operating directory:** `D:\2 JAIME\Jaime\Project\Turia`
- **Repository classification:** empty directory; it is not currently a Git working tree (`.git` is absent).
- **Uncommitted/user work:** not determinable because Git is not initialized. The directory listing and recursive file inventory contained no files, so no user work was observed.
- **Files read:** none. No repository files existed to read at audit time.
- **File created for this stage:** `docs/clone-baseline.md`.
- **Directory created for this stage:** `docs/`, because it was absent and is required to hold this record.

## Inventory

The following expected entry points were explicitly checked and were absent: `README.md`, `README`, `package.json`, `package-lock.json`, `npm-shrinkwrap.json`, `yarn.lock`, `pnpm-lock.yaml`, `bun.lockb`, `bun.lock`, `tsconfig.json`, `jsconfig.json`, `next.config.js`, `next.config.mjs`, `next.config.ts`, `vite.config.ts`, `tailwind.config.js`, `tailwind.config.ts`, `eslint.config.js`, `.eslintrc`, `.eslintrc.json`, `app/`, `pages/`, `src/`, `tests/`, `test/`, `__tests__/`, `supabase/`, `prisma/`, `migrations/`, `.env.example`, `env.example`, `vercel.json`, `docker-compose.yml`, `Dockerfile`, and `.github/`.

Consequently, there is no observed README, package manager, lockfile, language setting, framework, route structure, test suite, migration history, environment-variable contract, CI/deployment definition, or established project convention.

## Baseline checks

| Check | Result | Reason |
| --- | --- | --- |
| Git status / branch | Not available | `.git` is absent. |
| Lint | Not configured / not run | No package manifest or script exists. |
| Type check | Not configured / not run | No TypeScript configuration or script exists. |
| Tests | Not configured / not run | No manifest, test configuration, or tests exist. |
| Build | Not configured / not run | No manifest or build configuration exists. |

No test, build, dependency installation, development server, database, migration, or formatter command was run. The only audit commands were non-destructive directory/path inventory commands and creation of the required `docs/` directory.

## Architecture decision for an empty repository

Adopt the following as the **proposed target stack**, not as a claim about Turia Practice's implementation:

| Concern | Proposal | Stage 0 decision rationale |
| --- | --- | --- |
| Web application | Next.js using the App Router | Suits a server-capable TypeScript application with route-local UI and server-side operations. |
| Language | TypeScript | Makes domain contracts and access boundaries explicit. |
| UI | Tailwind CSS with accessibility-first components and interaction design | Enables consistent, responsive internal-workflow screens while keeping accessible semantics central. |
| Data | PostgreSQL hosted through Supabase | Provides relational modelling appropriate for firms, clients, work items, compliance cycles, and billing. |
| Authentication, file storage | Supabase Auth and Storage | Keeps identity and attachments behind managed, policy-governed services. |
| Authorization | Server-side policy layer plus PostgreSQL Row Level Security (RLS) | Requires every firm-scoped access path to be enforced in both application and database boundaries. |
| Validation | Zod | Provides shared runtime validation for requests, domain inputs, and worker payloads. |
| Async notifications | Database outbox plus worker | Supports deterministic, auditable reminders and retryable delivery. |
| Integrations | Configurable adapter interfaces with mocks | No external account, credential, or live vendor integration is required to begin; do not embed credentials or invent vendor APIs. |

No dependency versions, package manager, hosting provider, provider SDK, data schema, or deployment process is selected yet. At Stage 1, select versions that are supported at that time, record the selection, and add only the dependencies required by the approved scaffold. In the absence of an existing convention, package-manager selection remains an explicit Stage 1 decision rather than an assumption.

## Clean-room constraints and project guardrails

- Build an independent functional alternative from public workflow-level knowledge only. Do not use original Turia code, authenticated screens, backend behavior, proprietary copy, assets, branding/identity, credentials, or datasets.
- Treat the target stack above as an independent design decision, not evidence about the original product architecture.
- Read existing code before editing it once code exists; preserve established conventions and compatibility unless a documented migration authorizes change.
- Keep credentials exclusively in runtime environment variables. Documentation and examples may name variables, but must use placeholders and must never contain values.
- Use a server-side authorization layer and RLS for tenant/firm isolation; client-side visibility is never sufficient authorization.
- Prefer additive, reversible changes. Do not reset databases, rewrite lockfiles, run destructive commands, or overwrite user data.
- Do not invent APIs, credentials, datasets, migration results, test results, or compliance deadlines. Model regulatory rules as reviewable configuration and validate them before any production use.
- Add behavioral tests with future implementation changes and run only relevant, discovered checks. Report failures as baseline facts rather than repairing unrelated work.
- Document setup, schema, environment-variable names, and workflow changes as they are introduced.

## Evidence limitations and known unknowns

The only supplied functional evidence is a high-level public-workflow description: client master, assignment/review, recurring GST/TDS/Income Tax/MCA work, compliance status, billing, team operations, and deterministic reminders. Authenticated screens and original backend are explicitly unavailable. Therefore, the following remain unknown and must not be inferred as fact:

- exact user roles, permissions, workflow states, review/approval rules, notification timing, escalation logic, templates, terminology, and field-level requirements;
- source-of-truth regulatory calendars, jurisdictional exceptions, filing forms, due-date calculation rules, and audit/retention requirements;
- data-import/export formats, attachment limits, integration providers, tenancy model, scale, performance targets, availability objectives, and backup/recovery requirements;
- design system, content, visual identity, accessibility target level, localization, legal/privacy obligations, and deployment environment;
- ownership of firm/client data, retention/deletion policy, and security/compliance obligations.

These uncertainties are blockers only where a later stage needs their exact answer. Until then, use explicitly labelled configurable domain policies and mock adapters rather than simulating undisclosed original behavior.

## Planned modules (not implemented)

1. Firm tenancy, user/team membership, roles, and authorization boundaries.
2. Client master and scoped client-contact/document records.
3. Work management: task templates, assignment, review, statuses, activity/audit trail.
4. Recurring compliance engine for configured GST, TDS, Income Tax, and MCA obligations.
5. Compliance dashboard/status views and deterministic reminder orchestration through an outbox.
6. Billing records and configurable firm workflows.
7. Attachment storage, search/reporting/export capabilities, and operational administration as separately approved.

## Stage dependency checklist

### Required before Stage 1 scaffold

- [ ] Confirm this empty directory is the intended project root and whether Git initialization is authorized.
- [ ] Choose and document a package manager; install a supported Node.js runtime locally if one is not available.
- [ ] Confirm the independent product name and visual/content direction, ensuring no Turia identity or proprietary assets/copy are used.
- [ ] Approve the proposed Next.js + TypeScript + Tailwind + PostgreSQL/Supabase + Zod + outbox-worker architecture, or provide substitutions.
- [ ] Decide whether Stage 1 may create the initial application scaffold and dependency manifest.
- [ ] Define the initial tenant model and minimum roles; this gates secure schema/RLS design.
- [ ] Decide whether a real Supabase project is available for development. If not, Stage 1 must use documented placeholders/mocks only and must not require credentials.
- [ ] Establish initial regulatory-scope assumptions, review ownership, and authoritative due-date sources before compliance automation is designed.

### Required before production-capable modules

- [ ] Obtain approved domain requirements, authorization matrix, audit/retention policy, and privacy/security obligations.
- [ ] Establish an authoritative regulatory rules process and legal/compliance review.
- [ ] Configure real environment variables and Supabase resources through a secure deployment process; never commit values.
- [ ] Define notification channels, provider contracts, consent/opt-out rules, retry/escalation behavior, and operational monitoring.
- [ ] Define test, CI, backup/recovery, incident-response, and deployment requirements.

## Stage 0 conclusion

The repository is a clean, empty starting point. The recommended architecture is recorded as a proposal only. There are no existing failing checks to repair, and no code or infrastructure has been altered. Stage 1 can begin only after its scaffold authorization and the listed foundational decisions are confirmed.
