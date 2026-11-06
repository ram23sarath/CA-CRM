"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { createComplianceTemplate, createExpiryRegister, generateCompliancePeriod, updateCompliancePeriod, updateExpiryStatus } from "./service";
import { expiryFromFormData, periodFromFormData, templateFromFormData, updateFromFormData } from "./validation";

export type ComplianceActionState = { error?: string; fieldErrors?: Record<string, string[]> };
const fail = (error: unknown) => error instanceof Error ? error.message : "Unable to update compliance data.";

export async function createComplianceTemplateAction(_: ComplianceActionState, formData: FormData): Promise<ComplianceActionState> {
  const parsed = templateFromFormData(formData); if (!parsed.success) return { fieldErrors: parsed.error.flatten().fieldErrors };
  try { await createComplianceTemplate(parsed.data); revalidatePath("/app/compliance"); redirect("/app/compliance?saved=template"); } catch (error) { return { error: fail(error) }; }
}

export async function generateCompliancePeriodAction(_: ComplianceActionState, formData: FormData): Promise<ComplianceActionState> {
  const parsed = periodFromFormData(formData); if (!parsed.success) return { fieldErrors: parsed.error.flatten().fieldErrors };
  try { const id = await generateCompliancePeriod(parsed.data); revalidatePath("/app/compliance"); revalidatePath("/app/calendar"); redirect(`/app/compliance?generated=${id}`); } catch (error) { return { error: fail(error) }; }
}

export async function updateCompliancePeriodAction(formData: FormData) {
  const parsed = updateFromFormData(formData); if (!parsed.success) redirect(`/app/compliance?error=${encodeURIComponent(parsed.error.issues[0]?.message ?? "Invalid compliance update.")}`);
  try { await updateCompliancePeriod(parsed.data); revalidatePath("/app/compliance"); revalidatePath("/app/calendar"); revalidatePath("/app"); redirect("/app/compliance?saved=period"); } catch (error) { redirect(`/app/compliance?error=${encodeURIComponent(fail(error))}`); }
}

export async function createExpiryRegisterAction(_: ComplianceActionState, formData: FormData): Promise<ComplianceActionState> {
  const parsed = expiryFromFormData(formData); if (!parsed.success) return { fieldErrors: parsed.error.flatten().fieldErrors };
  try { await createExpiryRegister(parsed.data); revalidatePath("/app/compliance"); revalidatePath("/app"); redirect("/app/compliance?saved=expiry"); } catch (error) { return { error: fail(error) }; }
}

export async function updateExpiryStatusAction(formData: FormData) {
  try { await updateExpiryStatus(String(formData.get("registerId")), String(formData.get("status"))); revalidatePath("/app/compliance"); revalidatePath("/app"); } catch (error) { redirect(`/app/compliance?error=${encodeURIComponent(fail(error))}`); }
}
