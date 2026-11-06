import { z } from "zod";

export const taskInputSchema = z.object({
  title: z.string().trim().min(1).max(240), description: z.string().trim().max(10000), clientId: z.string().uuid().nullable(), serviceId: z.string().uuid().nullable(), ownerId: z.string().uuid().nullable(), assigneeId: z.string().uuid().nullable(), reviewerId: z.string().uuid().nullable(), templateId: z.string().uuid().nullable(), priority: z.enum(["LOW", "MEDIUM", "HIGH", "URGENT"]), dueAt: z.string().datetime().nullable(),
});
export function taskFromFormData(formData: FormData) {
  const dueDate = String(formData.get("dueAt") ?? "");
  return taskInputSchema.safeParse({ title: formData.get("title") ?? "", description: formData.get("description") ?? "", clientId: formData.get("clientId") || null, serviceId: formData.get("serviceId") || null, ownerId: formData.get("ownerId") || null, assigneeId: formData.get("assigneeId") || null, reviewerId: formData.get("reviewerId") || null, templateId: formData.get("templateId") || null, priority: formData.get("priority") ?? "MEDIUM", dueAt: dueDate ? new Date(dueDate).toISOString() : null });
}
export const transitions: Record<string, string[]> = { TODO: ["IN_PROGRESS"], IN_PROGRESS: ["IN_REVIEW"], IN_REVIEW: ["IN_PROGRESS", "COMPLETED"], COMPLETED: [], CANCELLED: [] };
export function canTransition(from: string, to: string) { return transitions[from]?.includes(to) ?? false; }
export function recurrenceKey(templateId: string, clientId: string, periodStart: string) { return `${templateId}:${clientId}:${periodStart}`; }
export function isOverdue(dueAt: string | null, status: string, now = new Date()) { return Boolean(dueAt && !["COMPLETED", "CANCELLED"].includes(status) && new Date(dueAt) < now); }
