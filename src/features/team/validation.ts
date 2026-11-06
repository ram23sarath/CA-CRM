import { z } from "zod";

export const leaveRequestSchema = z.object({
  leaveType: z.enum(["ANNUAL", "SICK", "PERSONAL", "UNPAID", "OTHER"]),
  startDate: z.string().date(),
  endDate: z.string().date(),
  reason: z.string().trim().max(1000),
}).refine((value) => value.endDate >= value.startDate, { path: ["endDate"], message: "End date must be on or after the start date." });

export const timesheetSchema = z.object({
  workDate: z.string().date(),
  minutes: z.coerce.number().int().min(0).max(1440),
  description: z.string().trim().min(1).max(1000),
  taskId: z.string().uuid().nullable(),
  clientId: z.string().uuid().nullable(),
});

export const reimbursementSchema = z.object({
  amount: z.coerce.number().positive().finite(),
  expenseDate: z.string().date(),
  description: z.string().trim().min(1).max(500),
});

export const automationRuleSchema = z.object({
  name: z.string().trim().min(1).max(160),
  trigger: z.enum(["COMPLIANCE_DUE_SOON", "TASK_ASSIGNED", "TASK_OVERDUE", "INVOICE_OVERDUE", "LEAD_FOLLOW_UP_DUE"]),
  recipientType: z.enum(["ASSIGNEE", "OWNER", "MANAGER", "PROFILE", "ALL_ACTIVE"]),
  recipientProfileId: z.string().uuid().nullable(),
  channel: z.enum(["INTERNAL", "EMAIL", "WHATSAPP"]),
  action: z.enum(["CREATE_NOTIFICATION", "CREATE_FOLLOW_UP_TASK", "QUEUE_MESSAGE_PREVIEW"]),
  throttleMinutes: z.coerce.number().int().min(0).max(43200),
  conditions: z.record(z.string(), z.unknown()),
}).superRefine((value, ctx) => {
  if (value.recipientType === "PROFILE" && !value.recipientProfileId) ctx.addIssue({ code: "custom", path: ["recipientProfileId"], message: "Select a profile recipient." });
  if (value.recipientType !== "PROFILE" && value.recipientProfileId) ctx.addIssue({ code: "custom", path: ["recipientProfileId"], message: "A profile is only used with the PROFILE recipient." });
});

export function leaveRequestFromFormData(formData: FormData) {
  return leaveRequestSchema.safeParse({ leaveType: formData.get("leaveType") ?? "", startDate: formData.get("startDate") ?? "", endDate: formData.get("endDate") ?? "", reason: formData.get("reason") ?? "" });
}

export function timesheetFromFormData(formData: FormData) {
  return timesheetSchema.safeParse({ workDate: formData.get("workDate") ?? "", minutes: formData.get("minutes") ?? "", description: formData.get("description") ?? "", taskId: formData.get("taskId") || null, clientId: formData.get("clientId") || null });
}

export function reimbursementFromFormData(formData: FormData) {
  return reimbursementSchema.safeParse({ amount: formData.get("amount") ?? "", expenseDate: formData.get("expenseDate") ?? "", description: formData.get("description") ?? "" });
}

export function automationRuleFromFormData(formData: FormData) {
  const conditions = String(formData.get("conditions") ?? "{}");
  let parsedConditions: unknown = {};
  try { parsedConditions = JSON.parse(conditions); } catch { parsedConditions = null; }
  return automationRuleSchema.safeParse({ name: formData.get("name") ?? "", trigger: formData.get("trigger") ?? "", recipientType: formData.get("recipientType") ?? "", recipientProfileId: formData.get("recipientProfileId") || null, channel: formData.get("channel") ?? "INTERNAL", action: formData.get("action") ?? "CREATE_NOTIFICATION", throttleMinutes: formData.get("throttleMinutes") ?? "1440", conditions: parsedConditions });
}

export function attendanceDurationMinutes(checkIn: string, checkOut: string) {
  const duration = new Date(checkOut).getTime() - new Date(checkIn).getTime();
  return duration > 0 ? Math.floor(duration / 60000) : null;
}
