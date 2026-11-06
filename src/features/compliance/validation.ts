import { z } from "zod";

const dateOnly = z.string().regex(/^\d{4}-\d{2}-\d{2}$/, "Use a valid calendar date.");
const optionalUuid = z.string().uuid().nullable();
const emptyToNull = (value: FormDataEntryValue | null) => {
  const text = String(value ?? "").trim();
  return text || null;
};

export const complianceTemplateSchema = z.object({
  code: z.string().trim().min(2).max(32).regex(/^[A-Za-z0-9][A-Za-z0-9_-]*$/),
  name: z.string().trim().min(1).max(160),
  frequency: z.enum(["MONTHLY", "QUARTERLY", "ANNUAL", "CUSTOM"]),
  dueOffsetDays: z.coerce.number().int().min(-366).max(366),
  taskTemplateId: optionalUuid,
});

export const compliancePeriodSchema = z.object({
  templateId: z.string().uuid(), clientId: z.string().uuid(), periodKey: z.string().trim().min(1).max(80),
  periodStart: dateOnly, periodEnd: dateOnly, ownerId: optionalUuid, source: z.enum(["MANUAL", "IMPORTED", "CONFIGURED"]),
}).refine((value) => value.periodEnd >= value.periodStart, { message: "Period end must not precede period start.", path: ["periodEnd"] });

export const complianceUpdateSchema = z.object({
  periodId: z.string().uuid(), status: z.enum(["UPCOMING", "IN_PROGRESS", "READY_FOR_REVIEW", "FILED", "CANCELLED"]),
  ownerId: optionalUuid, filingReference: z.string().trim().max(160), evidenceDocumentId: optionalUuid,
  confirmFiled: z.boolean(), source: z.enum(["MANUAL", "IMPORTED", "CONFIGURED"]), lastVerifiedDate: dateOnly.nullable(),
});

export const expirySchema = z.object({
  registerType: z.enum(["DSC", "LICENSE"]), name: z.string().trim().min(1).max(200), clientId: optionalUuid,
  ownerId: optionalUuid, custodianId: optionalUuid, expiryDate: dateOnly, reminderDate: dateOnly.nullable(),
  status: z.enum(["ACTIVE", "EXPIRED", "REVOKED", "RENEWED"]), notes: z.string().trim().max(2000), source: z.enum(["MANUAL", "IMPORTED"]),
}).refine((value) => !value.reminderDate || value.reminderDate <= value.expiryDate, { message: "Reminder date must be on or before expiry date.", path: ["reminderDate"] });

export function templateFromFormData(formData: FormData) {
  return complianceTemplateSchema.safeParse({ code: formData.get("code"), name: formData.get("name"), frequency: formData.get("frequency"), dueOffsetDays: formData.get("dueOffsetDays"), taskTemplateId: emptyToNull(formData.get("taskTemplateId")) });
}

export function periodFromFormData(formData: FormData) {
  return compliancePeriodSchema.safeParse({ templateId: formData.get("templateId"), clientId: formData.get("clientId"), periodKey: formData.get("periodKey"), periodStart: formData.get("periodStart"), periodEnd: formData.get("periodEnd"), ownerId: emptyToNull(formData.get("ownerId")), source: formData.get("source") || "MANUAL" });
}

export function updateFromFormData(formData: FormData) {
  return complianceUpdateSchema.safeParse({ periodId: formData.get("periodId"), status: formData.get("status"), ownerId: emptyToNull(formData.get("ownerId")), filingReference: formData.get("filingReference") ?? "", evidenceDocumentId: emptyToNull(formData.get("evidenceDocumentId")), confirmFiled: formData.get("confirmFiled") === "on", source: formData.get("source") || "MANUAL", lastVerifiedDate: emptyToNull(formData.get("lastVerifiedDate")) });
}

export function expiryFromFormData(formData: FormData) {
  return expirySchema.safeParse({ registerType: formData.get("registerType"), name: formData.get("name"), clientId: emptyToNull(formData.get("clientId")), ownerId: emptyToNull(formData.get("ownerId")), custodianId: emptyToNull(formData.get("custodianId")), expiryDate: formData.get("expiryDate"), reminderDate: emptyToNull(formData.get("reminderDate")), status: formData.get("status") || "ACTIVE", notes: formData.get("notes") ?? "", source: formData.get("source") || "MANUAL" });
}
