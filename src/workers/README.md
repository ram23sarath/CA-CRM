# Workers

`automation-runner.ts` is the trusted-worker entry point for Stage 9. A scheduler/cron process invokes `runAutomationWorkerOnce`; it claims rows through the transactional `claim_automation_events` lease function, applies deterministic rules, writes the per-event/rule/recipient delivery ledger, and retains job results. Browser code must never invoke this module.

Stage 9 uses `PreviewNotificationAdapter` for every channel. It persists synthetic previews and never opens an outbound network connection. Provider adapters may be added later behind the same typed `NotificationAdapter` interface, with credentials held only in worker environment variables.
