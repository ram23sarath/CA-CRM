import { describe, expect, it } from "vitest";

import { attendanceDurationMinutes, leaveRequestSchema, timesheetSchema } from "@/features/team/validation";
import { deliveryIdempotencyKey, matchesAutomationRule, nextRetryAt, recurrenceKey, shouldThrottle } from "@/features/team/automation";
import { adapterFor, PreviewNotificationAdapter, failedDelivery } from "@/workers/automation";

describe("team operations validation", () => {
  it("rejects inverted leave dates and negative time", () => {
    expect(leaveRequestSchema.safeParse({ leaveType: "ANNUAL", startDate: "2026-05-10", endDate: "2026-05-09", reason: "" }).success).toBe(false);
    expect(timesheetSchema.safeParse({ workDate: "2026-05-10", minutes: -1, description: "Correction", taskId: null, clientId: null }).success).toBe(false);
  });

  it("only returns positive attendance duration", () => {
    expect(attendanceDurationMinutes("2026-05-10T09:00:00.000Z", "2026-05-10T17:30:00.000Z")).toBe(510);
    expect(attendanceDurationMinutes("2026-05-10T17:30:00.000Z", "2026-05-10T09:00:00.000Z")).toBeNull();
  });
});

describe("deterministic automation", () => {
  const event = { id: "event-1", eventType: "TASK_OVERDUE" as const, subjectId: "task-1", payload: { priority: "HIGH", owner_profile_id: "profile-1" }, occurredAt: "2026-05-10T00:00:00.000Z" };
  it("matches trigger and exact conditions", () => {
    expect(matchesAutomationRule(event, { id: "rule-1", trigger: "TASK_OVERDUE", conditions: { priority: ["HIGH", "URGENT"] }, channel: "INTERNAL", action: "CREATE_NOTIFICATION", throttleMinutes: 60, enabled: true })).toBe(true);
    expect(matchesAutomationRule(event, { id: "rule-2", trigger: "TASK_ASSIGNED", conditions: {}, channel: "INTERNAL", action: "CREATE_NOTIFICATION", throttleMinutes: 60, enabled: true })).toBe(false);
  });

  it("builds recurring event and delivery keys without collisions", () => {
    expect(recurrenceKey("TASK_OVERDUE", "task-1", "2026-05-10")).toBe("TASK_OVERDUE:task-1:2026-05-10");
    expect(deliveryIdempotencyKey("event-1", "rule-1", "profile-1")).toBe("event-1:rule-1:profile-1");
    expect(deliveryIdempotencyKey("event-1", "rule-1", "profile-1")).toBe(deliveryIdempotencyKey("event-1", "rule-1", "profile-1"));
  });

  it("throttles repeated reminders and bounds retry backoff", () => {
    const now = new Date("2026-05-10T01:00:00.000Z");
    expect(shouldThrottle("2026-05-10T00:30:00.000Z", now, 60)).toBe(true);
    expect(shouldThrottle("2026-05-09T23:00:00.000Z", now, 60)).toBe(false);
    expect(new Date(nextRetryAt(3, now)).getTime() - now.getTime()).toBe(120_000);
    expect(failedDelivery(5, "provider unavailable", 5, now).status).toBe("DEAD_LETTER");
    expect(failedDelivery(2, "provider unavailable", 5, now).status).toBe("FAILED");
  });

  it("previews every channel without network delivery", async () => {
    const result = await new PreviewNotificationAdapter("WHATSAPP").deliver({ deliveryId: "delivery-1", recipientProfileId: "profile-1", channel: "WHATSAPP", action: "QUEUE_MESSAGE_PREVIEW", title: "Preview", body: "Synthetic", previewOnly: true });
    expect(result.status).toBe("PREVIEWED");
    expect(result.syntheticEvent).toMatchObject({ deliveryId: "delivery-1", channel: "WHATSAPP" });
  });

  it("keeps adapters in preview mode even if a persisted setting is tampered", async () => {
    const result = await adapterFor("EMAIL").deliver({ deliveryId: "delivery-2", recipientProfileId: "profile-1", channel: "EMAIL", action: "QUEUE_MESSAGE_PREVIEW", title: "Preview", body: "Synthetic", previewOnly: false });
    expect(result.status).toBe("PREVIEWED");
    expect(result.providerReference).toBeUndefined();
  });
});
