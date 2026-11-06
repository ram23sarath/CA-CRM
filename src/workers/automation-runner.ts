import { createSupabaseServiceClient } from "@/lib/supabase/service";
import { adapterFor } from "./automation";
import { matchesAutomationRule, nextRetryAt, shouldThrottle, type AutomationEvent, type AutomationRule } from "@/features/team/automation";

type EventRow = { id: string; firm_id: string; event_type: string; subject_id: string; payload: Record<string, unknown>; created_at: string; attempts: number };
type RuleRow = { id: string; trigger: AutomationEvent["eventType"]; conditions: Record<string, unknown>; recipient_type: string; recipient_profile_id: string | null; channel: AutomationRule["channel"]; action: AutomationRule["action"]; enabled: boolean; throttle_minutes: number };
type MemberRow = { profile_id: string; role: string };

function text(value: unknown, fallback: string) { return typeof value === "string" && value.trim() ? value : fallback; }
function profileId(value: unknown) { return typeof value === "string" && value ? value : null; }
function titleFor(event: EventRow) { return text(event.payload?.title, `${String(event.event_type).replaceAll("_", " ")} needs attention`); }
function bodyFor(event: EventRow) { return text(event.payload?.body, `Deterministic reminder for subject ${event.subject_id}.`); }

async function recipients(supabase: ReturnType<typeof createSupabaseServiceClient>, firmId: string, rule: RuleRow, event: EventRow) {
  if (rule.recipient_type === "PROFILE") return rule.recipient_profile_id ? [rule.recipient_profile_id] : [];
  if (rule.recipient_type === "ASSIGNEE") { const id = profileId(event.payload?.assignee_profile_id); return id ? [id] : []; }
  if (rule.recipient_type === "OWNER") { const id = profileId(event.payload?.owner_profile_id); return id ? [id] : []; }
  const { data, error } = await supabase.from("firm_memberships").select("profile_id,role").eq("firm_id", firmId).eq("status", "ACTIVE").is("archived_at", null);
  if (error) throw error;
  return (data ?? []).filter((member: MemberRow) => rule.recipient_type === "ALL_ACTIVE" || ["OWNER", "PARTNER", "MANAGER"].includes(member.role)).map((member: MemberRow) => member.profile_id);
}

async function processEvent(supabase: ReturnType<typeof createSupabaseServiceClient>, event: EventRow, workerId: string) {
  const { data: settings } = await supabase.from("automation_settings").select("paused,safe_preview_mode,max_attempts").eq("firm_id", event.firm_id).maybeSingle();
  if (settings?.paused) {
    await supabase.from("automation_events").update({ status: "PENDING", available_at: new Date(Date.now() + 60_000).toISOString(), lease_until: null, leased_by: null }).eq("id", event.id);
    return { success: 0, failure: 0, dead: 0, deferred: true };
  }
  const { data: rules, error: rulesError } = await supabase.from("automation_rules").select("id,trigger,conditions,recipient_type,recipient_profile_id,channel,action,enabled,throttle_minutes").eq("firm_id", event.firm_id).eq("enabled", true);
  if (rulesError) throw rulesError;
  const automationEvent: AutomationEvent = { id: event.id, eventType: event.event_type as AutomationEvent["eventType"], subjectId: event.subject_id, payload: event.payload ?? {}, occurredAt: event.created_at };
  let success = 0; let failure = 0; let dead = 0;
  const maxAttempts = Number(settings?.max_attempts ?? 5);
  for (const ruleRow of (rules ?? []) as RuleRow[]) {
    const rule: AutomationRule = { id: ruleRow.id, trigger: ruleRow.trigger, conditions: ruleRow.conditions ?? {}, channel: ruleRow.channel, action: ruleRow.action, throttleMinutes: ruleRow.throttle_minutes, enabled: ruleRow.enabled };
    if (!matchesAutomationRule(automationEvent, rule)) continue;
    for (const recipientId of await recipients(supabase, event.firm_id, ruleRow, event)) {
      const { data: preference } = await supabase.from("notification_preferences").select("opt_out_all,email_enabled,whatsapp_enabled,preferred_channel").eq("firm_id", event.firm_id).eq("profile_id", recipientId).maybeSingle();
      if (preference?.opt_out_all) { await supabase.from("automation_deliveries").upsert({ firm_id: event.firm_id, event_id: event.id, rule_id: rule.id, recipient_profile_id: recipientId, channel: rule.channel, action: rule.action, status: "SKIPPED", result: { reason: "opt_out" }, completed_at: new Date().toISOString() }, { onConflict: "firm_id,event_id,rule_id,recipient_profile_id", ignoreDuplicates: true }); continue; }
      if (rule.channel === "EMAIL" && (!preference?.email_enabled || preference.preferred_channel !== "EMAIL")) continue;
      if (rule.channel === "WHATSAPP" && (!preference?.whatsapp_enabled || preference.preferred_channel !== "WHATSAPP")) continue;
      const { data: existing } = await supabase.from("automation_deliveries").select("id,status,attempts,created_at").eq("firm_id", event.firm_id).eq("event_id", event.id).eq("rule_id", rule.id).eq("recipient_profile_id", recipientId).maybeSingle();
      if (existing && ["PREVIEWED", "SUCCEEDED", "SKIPPED", "DEAD_LETTER"].includes(existing.status)) continue;
      if (!existing) {
        const since = new Date(Date.now() - rule.throttleMinutes * 60_000).toISOString();
        const { data: recent } = await supabase.from("automation_deliveries").select("id,created_at").eq("firm_id", event.firm_id).eq("rule_id", rule.id).eq("recipient_profile_id", recipientId).gte("created_at", since).limit(1);
        if (shouldThrottle(recent?.[0]?.created_at ?? null, new Date(), rule.throttleMinutes)) continue;
      }
      let deliveryId = existing?.id as string | undefined;
      const attempt = Number(existing?.attempts ?? 0) + 1;
      if (!deliveryId) {
        const { data: delivery, error: deliveryError } = await supabase.from("automation_deliveries").insert({ firm_id: event.firm_id, event_id: event.id, rule_id: rule.id, recipient_profile_id: recipientId, channel: rule.channel, action: rule.action, preview_only: settings?.safe_preview_mode !== false }).select("id").single();
        if (deliveryError || !delivery?.id) continue;
        deliveryId = delivery.id as string;
      }
      const adapter = adapterFor(rule.channel);
      const result = await adapter.deliver({ deliveryId, recipientProfileId: recipientId, channel: rule.channel, action: rule.action, title: titleFor(event), body: bodyFor(event), previewOnly: settings?.safe_preview_mode !== false });
      if (result.status === "FAILED") { failure += 1; const terminal = attempt >= maxAttempts; if (terminal) dead += 1; await supabase.from("automation_deliveries").update({ status: terminal ? "DEAD_LETTER" : "FAILED", attempts: attempt, last_error: result.error ?? "provider adapter failed", available_at: terminal ? null : nextRetryAt(attempt), result }).eq("id", deliveryId); continue; }
      if (rule.action === "CREATE_NOTIFICATION") await supabase.from("notifications").insert({ firm_id: event.firm_id, recipient_profile_id: recipientId, kind: event.event_type, title: titleFor(event), body: bodyFor(event), source_event_id: event.id, source_delivery_id: deliveryId });
      if (rule.action === "CREATE_FOLLOW_UP_TASK") await supabase.from("tasks").insert({ firm_id: event.firm_id, title: `Follow up: ${titleFor(event)}`, description: bodyFor(event), status: "TODO", priority: "MEDIUM", due_date: new Date().toISOString().slice(0, 10), assignee_profile_id: recipientId, owner_profile_id: recipientId, created_by_profile_id: recipientId, automation_delivery_id: deliveryId });
      success += 1;
      await supabase.from("automation_deliveries").update({ status: result.status === "PREVIEWED" ? "PREVIEWED" : "SUCCEEDED", attempts: attempt, result: result.syntheticEvent ? { synthetic_event: result.syntheticEvent } : {}, provider_reference: result.providerReference ?? null, completed_at: new Date().toISOString() }).eq("id", deliveryId);
    }
  }
  await supabase.from("automation_events").update({ status: failure > 0 ? "FAILED" : "DELIVERED", available_at: failure > 0 ? nextRetryAt(event.attempts) : event.created_at, delivered_at: failure > 0 ? null : new Date().toISOString(), lease_until: null, leased_by: workerId }).eq("id", event.id);
  return { success, failure, dead, deferred: false };
}

/** Invoke from a trusted scheduler/cron process only. No browser may call this module. */
export async function runAutomationWorkerOnce(workerId = `automation-${process.pid}`) {
  const supabase = createSupabaseServiceClient();
  await supabase.rpc("enqueue_due_automation_events", { p_firm_id: null });
  const { data: events, error } = await supabase.rpc("claim_automation_events", { p_worker_id: workerId, p_limit: 25 });
  if (error) throw new Error(`Unable to claim automation events: ${error.message}`);
  let success = 0; let failure = 0; let dead = 0;
  for (const event of (events ?? []) as EventRow[]) {
    try { const result = await processEvent(supabase, event, workerId); success += result.success; failure += result.failure; dead += result.dead; }
    catch (workerError) { failure += 1; await supabase.from("automation_events").update({ status: "FAILED", available_at: nextRetryAt(event.attempts), last_error: workerError instanceof Error ? workerError.message : "worker failure", lease_until: null, leased_by: workerId }).eq("id", event.id); }
  }
  const firmIds = [...new Set((events ?? []).map((event: EventRow) => event.firm_id))];
  for (const firmId of firmIds) {
    await supabase.from("automation_job_history").insert({ firm_id: firmId, job_type: "AUTOMATION_WORKER", status: failure ? "FAILED" : "SUCCEEDED", preview_mode: true, claimed_count: (events ?? []).filter((event: EventRow) => event.firm_id === firmId).length, success_count: success, failure_count: failure, dead_letter_count: dead, finished_at: new Date().toISOString() });
  }
  return { claimed: (events ?? []).length, success, failure, dead };
}
