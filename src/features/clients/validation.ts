import { z } from "zod";

export const PAN_PATTERN = /^[A-Z]{5}[0-9]{4}[A-Z]$/;
export const GSTIN_PATTERN = /^[0-3][0-9][A-Z]{5}[0-9]{4}[A-Z][0-9A-Z]Z[0-9A-Z]$/;

export function normalizeIdentifier(value: string | null | undefined) {
  const normalized = value?.trim().toUpperCase() ?? "";
  return normalized || null;
}

export function isValidPan(value: string | null | undefined) {
  const pan = normalizeIdentifier(value);
  return pan === null || PAN_PATTERN.test(pan);
}

export function isValidGstin(value: string | null | undefined) {
  const gstin = normalizeIdentifier(value);
  if (gstin === null || !GSTIN_PATTERN.test(gstin)) return gstin === null;
  const stateCode = Number(gstin.slice(0, 2));
  return stateCode >= 1 && stateCode <= 38;
}

export const clientInputSchema = z.object({
  legalName: z.string().trim().min(1, "Legal name is required.").max(240),
  displayName: z.string().trim().min(1, "Display name is required.").max(160),
  entityType: z.enum(["INDIVIDUAL", "COMPANY", "LLP", "PARTNERSHIP", "TRUST", "OTHER"]),
  pan: z.string().transform(normalizeIdentifier).nullable().refine(isValidPan, "Enter a PAN in the expected format (for example, ABCDE1234F). This is not government verification."),
  gstin: z.string().transform(normalizeIdentifier).nullable().refine(isValidGstin, "Enter a GSTIN with a valid state code (01–38). This is format validation, not government verification."),
  address: z.string().trim().max(2000),
  relationshipManagerId: z.string().uuid().nullable(),
  serviceTags: z.array(z.string().trim().min(1).max(80)).max(30),
  status: z.enum(["ACTIVE", "INACTIVE"]),
  notes: z.string().trim().max(10000),
  contact: z.object({
    fullName: z.string().trim().max(160),
    email: z.string().trim().max(320).refine((value) => !value || z.email().safeParse(value).success, "Enter a valid contact email."),
    phone: z.string().trim().max(40),
    designation: z.string().trim().max(160),
  }),
});

export type ClientInput = z.infer<typeof clientInputSchema>;

export function clientInputFromFormData(formData: FormData) {
  return clientInputSchema.safeParse({
    legalName: formData.get("legalName") ?? "",
    displayName: formData.get("displayName") ?? "",
    entityType: formData.get("entityType") ?? "OTHER",
    pan: formData.get("pan") ?? "",
    gstin: formData.get("gstin") ?? "",
    address: formData.get("address") ?? "",
    relationshipManagerId: formData.get("relationshipManagerId") || null,
    serviceTags: String(formData.get("serviceTags") ?? "").split(",").map((tag) => tag.trim()).filter(Boolean),
    status: formData.get("status") ?? "ACTIVE",
    notes: formData.get("notes") ?? "",
    contact: { fullName: formData.get("contactFullName") ?? "", email: formData.get("contactEmail") ?? "", phone: formData.get("contactPhone") ?? "", designation: formData.get("contactDesignation") ?? "" },
  });
}

export const allowedDocumentTypes = new Map([
  ["application/pdf", ["pdf"]], ["image/jpeg", ["jpg", "jpeg"]], ["image/png", ["png"]], ["image/webp", ["webp"]], ["text/plain", ["txt"]],
  ["application/msword", ["doc"]], ["application/vnd.openxmlformats-officedocument.wordprocessingml.document", ["docx"]], ["application/vnd.ms-excel", ["xls"]], ["application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", ["xlsx"]],
]);

export function validateDocument(file: File, maximumBytes: number) {
  const extension = file.name.split(".").pop()?.toLowerCase() ?? "";
  const extensions = allowedDocumentTypes.get(file.type);
  if (!extensions?.includes(extension)) return "This file type is not supported. Upload a PDF, image, text file, or common Office document.";
  if (file.size === 0) return "The selected file is empty.";
  if (file.size > maximumBytes) return `The selected file exceeds the ${Math.floor(maximumBytes / 1024 / 1024)} MB limit.`;
  return null;
}

export function sanitizeFilename(name: string) {
  const safe = name.normalize("NFKD").replace(/[^A-Za-z0-9._-]+/g, "-").replace(/\.{2,}/g, ".").replace(/^[.-]+/, "").replace(/-+$/g, "").slice(0, 180);
  return safe || "document";
}
