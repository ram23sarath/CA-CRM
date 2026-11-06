"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";

import { archiveClient, archiveContact, createClient, saveContact, updateClient, uploadClientDocument } from "./service";
import { clientDocumentMaximumBytes } from "./config";
import { sanitizeFilename, clientInputFromFormData, validateDocument } from "./validation";

export type ClientFormState = { error?: string; fieldErrors?: Record<string, string[]> };

function formError(error: unknown) { return error instanceof Error ? error.message : "Unable to save the client. Please try again."; }

export async function createClientAction(_: ClientFormState, formData: FormData): Promise<ClientFormState> {
  const parsed = clientInputFromFormData(formData);
  if (!parsed.success) return { fieldErrors: parsed.error.flatten().fieldErrors };
  try { const clientId = await createClient(parsed.data); redirect(`/app/clients/${clientId}?created=1`); }
  catch (error) { return { error: formError(error) }; }
}

export async function updateClientAction(_: ClientFormState, formData: FormData): Promise<ClientFormState> {
  const parsed = clientInputFromFormData(formData);
  const clientId = String(formData.get("clientId") ?? "");
  const updatedAt = String(formData.get("updatedAt") ?? "");
  if (!parsed.success) return { fieldErrors: parsed.error.flatten().fieldErrors };
  if (!clientId || !updatedAt) return { error: "The client version is missing. Refresh and try again." };
  try { await updateClient(clientId, updatedAt, parsed.data); revalidatePath(`/app/clients/${clientId}`); revalidatePath("/app/clients"); redirect(`/app/clients/${clientId}?saved=1`); }
  catch (error) { return { error: formError(error) }; }
}

export async function archiveClientAction(formData: FormData) {
  const clientId = String(formData.get("clientId") ?? "");
  const archived = String(formData.get("archived")) === "true";
  if (!clientId) return;
  await archiveClient(clientId, archived);
  revalidatePath("/app/clients"); revalidatePath(`/app/clients/${clientId}`);
  redirect(archived ? "/app/clients?archived=1" : `/app/clients/${clientId}?restored=1`);
}

export async function saveContactAction(formData: FormData) {
  const clientId = String(formData.get("clientId") ?? "");
  if (!clientId) return;
  await saveContact(clientId, { id: String(formData.get("contactId") ?? "") || undefined, fullName: String(formData.get("fullName") ?? ""), email: String(formData.get("email") ?? ""), phone: String(formData.get("phone") ?? ""), designation: String(formData.get("designation") ?? ""), isPrimary: formData.get("isPrimary") === "on" });
  revalidatePath(`/app/clients/${clientId}`);
}

export async function archiveContactAction(formData: FormData) {
  const clientId = String(formData.get("clientId") ?? ""); const contactId = String(formData.get("contactId") ?? "");
  if (!clientId || !contactId) return;
  await archiveContact(clientId, contactId);
  revalidatePath(`/app/clients/${clientId}`);
}

export async function uploadClientDocumentAction(_: ClientFormState, formData: FormData): Promise<ClientFormState> {
  const clientId = String(formData.get("clientId") ?? "");
  const file = formData.get("document");
  if (!clientId || !(file instanceof File)) return { error: "Choose a document before uploading." };
  const invalid = validateDocument(file, clientDocumentMaximumBytes());
  if (invalid) return { error: invalid };
  try { await uploadClientDocument(clientId, file, sanitizeFilename(file.name)); revalidatePath(`/app/clients/${clientId}`); return {}; }
  catch (error) { return { error: formError(error) }; }
}
