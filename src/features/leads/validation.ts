import { z } from "zod";

const dateOnly = z.string().regex(/^\d{4}-\d{2}-\d{2}$/, "Use a valid calendar date.");
const optionalUuid = z.string().uuid().nullable();
const emptyToNull = (value: FormDataEntryValue | null) => { const text = String(value ?? "").trim(); return text || null; };
const optionalEmail = z.string().trim().max(320).refine((value) => !value || z.email().safeParse(value).success, "Enter a valid email address.");
const optionalMobile = z.string().trim().max(30).refine((value) => !value || /^[0-9+(). -]{7,30}$/.test(value), "Enter a valid mobile number.");

export const leadInputSchema = z.object({
  name: z.string().trim().min(1).max(160), companyName: z.string().trim().max(240), email: optionalEmail, mobile: optionalMobile,
  source: z.string().trim().min(1).max(80), score: z.coerce.number().int().min(0).max(100).nullable(), ownerId: optionalUuid,
  nextFollowUpDate: dateOnly.nullable(), notes: z.string().trim().max(10000),
});
export const leadActivitySchema = z.object({ leadId: z.string().uuid(), body: z.string().trim().min(1).max(10000) });
export const leadContactSchema = z.object({ leadId: z.string().uuid(), fullName: z.string().trim().min(1).max(160), email: optionalEmail, mobile: optionalMobile, designation: z.string().trim().max(160), isPrimary: z.boolean() });
export const followUpSchema = z.object({ leadId: z.string().uuid(), title: z.string().trim().min(1).max(200), dueDate: dateOnly, reminderDate: dateOnly.nullable(), assignedTo: optionalUuid, note: z.string().trim().max(4000) }).refine((value) => !value.reminderDate || value.reminderDate <= value.dueDate, { path: ["reminderDate"], message: "Reminder date must be on or before due date." });
export const proposalSchema = z.object({ leadId: z.string().uuid(), title: z.string().trim().min(1).max(200), serviceScope: z.string().trim().min(1).max(20000), validityDate: dateOnly, feeMinor: z.coerce.number().int().nonnegative(), taxEstimateMinor: z.coerce.number().int().nonnegative(), currency: z.string().trim().toUpperCase().regex(/^[A-Z]{3}$/), notes: z.string().trim().max(10000) });
export const proposalVersionSchema = proposalSchema.omit({ leadId: true }).extend({ proposalId: z.string().uuid() });
export const stageSchema = z.object({ leadId: z.string().uuid(), stage: z.enum(["LEAD", "FOLLOW_UP", "QUOTATION", "PROPOSAL", "WON"]), note: z.string().trim().max(2000) });
export const outcomeSchema = z.object({ proposalId: z.string().uuid(), outcome: z.enum(["ACCEPTED", "REJECTED"]) });
export const demoEventSchema = z.object({ proposalId: z.string().uuid(), event: z.enum(["PREVIEWED", "DEMO_SENT", "VIEWED", "ACTIONED"]) });
export const conversionSchema = z.object({ leadId: z.string().uuid(), proposalId: z.string().uuid(), existingClientId: optionalUuid, entityType: z.enum(["INDIVIDUAL", "COMPANY", "LLP", "PARTNERSHIP", "TRUST", "OTHER"]) });
export const leadStages = ["LEAD", "FOLLOW_UP", "QUOTATION", "PROPOSAL", "WON", "CLIENT"] as const;
export function canAdvanceLeadStage(from: string, to: string) { return leadStages.indexOf(from as (typeof leadStages)[number]) + 1 === leadStages.indexOf(to as (typeof leadStages)[number]); }

export function leadFromFormData(formData: FormData) { return leadInputSchema.safeParse({ name: formData.get("name"), companyName: formData.get("companyName") ?? "", email: formData.get("email") ?? "", mobile: formData.get("mobile") ?? "", source: formData.get("source") ?? "OTHER", score: emptyToNull(formData.get("score")) ? formData.get("score") : null, ownerId: emptyToNull(formData.get("ownerId")), nextFollowUpDate: emptyToNull(formData.get("nextFollowUpDate")), notes: formData.get("notes") ?? "" }); }
export function activityFromFormData(formData: FormData) { return leadActivitySchema.safeParse({ leadId: formData.get("leadId"), body: formData.get("body") }); }
export function contactFromFormData(formData: FormData) { return leadContactSchema.safeParse({ leadId: formData.get("leadId"), fullName: formData.get("fullName"), email: formData.get("email") ?? "", mobile: formData.get("mobile") ?? "", designation: formData.get("designation") ?? "", isPrimary: formData.get("isPrimary") === "on" }); }
export function followUpFromFormData(formData: FormData) { return followUpSchema.safeParse({ leadId: formData.get("leadId"), title: formData.get("title"), dueDate: formData.get("dueDate"), reminderDate: emptyToNull(formData.get("reminderDate")), assignedTo: emptyToNull(formData.get("assignedTo")), note: formData.get("note") ?? "" }); }
export function proposalFromFormData(formData: FormData) { return proposalSchema.safeParse({ leadId: formData.get("leadId"), title: formData.get("title"), serviceScope: formData.get("serviceScope"), validityDate: formData.get("validityDate"), feeMinor: formData.get("feeMinor"), taxEstimateMinor: formData.get("taxEstimateMinor"), currency: formData.get("currency") ?? "INR", notes: formData.get("notes") ?? "" }); }
export function proposalVersionFromFormData(formData: FormData) { return proposalVersionSchema.safeParse({ proposalId: formData.get("proposalId"), serviceScope: formData.get("serviceScope"), validityDate: formData.get("validityDate"), feeMinor: formData.get("feeMinor"), taxEstimateMinor: formData.get("taxEstimateMinor"), currency: formData.get("currency") ?? "INR", notes: formData.get("notes") ?? "" }); }
export function stageFromFormData(formData: FormData) { return stageSchema.safeParse({ leadId: formData.get("leadId"), stage: formData.get("stage"), note: formData.get("note") ?? "" }); }
export function outcomeFromFormData(formData: FormData) { return outcomeSchema.safeParse({ proposalId: formData.get("proposalId"), outcome: formData.get("outcome") }); }
export function demoEventFromFormData(formData: FormData) { return demoEventSchema.safeParse({ proposalId: formData.get("proposalId"), event: formData.get("event") }); }
export function conversionFromFormData(formData: FormData) { return conversionSchema.safeParse({ leadId: formData.get("leadId"), proposalId: formData.get("proposalId"), existingClientId: emptyToNull(formData.get("existingClientId")), entityType: formData.get("entityType") ?? "OTHER" }); }
