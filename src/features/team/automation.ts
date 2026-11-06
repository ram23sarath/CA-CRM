export type AutomationTrigger = "COMPLIANCE_DUE_SOON" | "TASK_ASSIGNED" | "TASK_OVERDUE" | "INVOICE_OVERDUE" | "LEAD_FOLLOW_UP_DUE";
export type AutomationChannel = "INTERNAL" | "EMAIL" | "WHATSAPP";
export type AutomationAction = "CREATE_NOTIFICATION" | "CREATE_FOLLOW_UP_TASK" | "QUEUE_MESSAGE_PREVIEW";
export type AutomationRecipient = "ASSIGNEE" | "OWNER" | "MANAGER" | "PROFILE" | "ALL_ACTIVE";

export type AutomationEvent = {
  id: string;
  eventType: AutomationTrigger;
  subjectId: string;
  payload: Record<string, unknown>;
  occurredAt: string;
};

export type AutomationRule = {
  id: string;
  trigger: AutomationTrigger;
  conditions: Record<string, unknown>;
  channel: AutomationChannel;
  action: AutomationAction;
  throttleMinutes: number;
  enabled: boolean;
};

export function recurrenceKey(trigger: AutomationTrigger, subjectId: string, localDate: string) {
  return `${trigger}:${subjectId}:${localDate}`;
}

export function deliveryIdempotencyKey(eventId: string, ruleId: string, recipientId: string) {
  return `${eventId}:${ruleId}:${recipientId}`;
}

export function matchesAutomationRule(event: AutomationEvent, rule: AutomationRule) {
  if (!rule.enabled || rule.trigger !== event.eventType) return false;
  return Object.entries(rule.conditions).every(([key, expected]) => {
    const actual = event.payload[key];
    if (Array.isArray(expected)) return expected.includes(actual);
    return expected === undefined || expected === actual;
  });
}

export function shouldThrottle(lastRunAt: string | null | undefined, now: Date, throttleMinutes: number) {
  if (!lastRunAt || throttleMinutes <= 0) return false;
  return now.getTime() - new Date(lastRunAt).getTime() < throttleMinutes * 60_000;
}

export function retryDelayMs(attempt: number, baseMs = 30_000, maxMs = 3_600_000) {
  const safeAttempt = Math.max(1, Math.floor(attempt));
  return Math.min(maxMs, baseMs * (2 ** (safeAttempt - 1)));
}

export function nextRetryAt(attempt: number, now = new Date()) {
  return new Date(now.getTime() + retryDelayMs(attempt)).toISOString();
}
