import { createHash, randomUUID } from "node:crypto";

import { getAccessState } from "@/lib/auth/state";
import { createSupabaseServerClient } from "@/lib/supabase/server";

import { CLIENT_DOCUMENT_BUCKET, CLIENT_DOCUMENT_SIGNED_URL_SECONDS } from "./config";
import { clientErrorMessage } from "./errors";
import type { ClientInput } from "./validation";
import type { ClientRecord, ContactRecord, DocumentRecord, MemberOption } from "./types";

type FirmScope = { firmId: string; userId: string };

export async function requireClientFirmScope(): Promise<FirmScope> {
  const supabase = await createSupabaseServerClient();
  const [{ data: { user } }, state] = await Promise.all([supabase.auth.getUser(), getAccessState(supabase)]);
  if (!user || !state?.firm_id || state.access_status !== "ACTIVE") throw new Error("An active firm membership is required.");
  return { firmId: state.firm_id, userId: user.id };
}

function queryEscape(value: string) { return value.replace(/[,%_()]/g, "\\$&"); }

export async function listClients(options: { page: number; query?: string; status?: string; entityType?: string; managerId?: string; archived?: boolean }) {
  const { firmId } = await requireClientFirmScope();
  const supabase = await createSupabaseServerClient();
  const pageSize = 20;
  let query = supabase.from("clients").select("id, legal_name, display_name, entity_type, pan, gstin, owner_profile_id, service_tags, status, archived_at, updated_at, created_at", { count: "exact" }).eq("firm_id", firmId);
  query = options.archived ? query.not("archived_at", "is", null) : query.is("archived_at", null);
  if (options.status === "ACTIVE" || options.status === "INACTIVE") query = query.eq("status", options.status);
  if (["INDIVIDUAL", "COMPANY", "LLP", "PARTNERSHIP", "TRUST", "OTHER"].includes(options.entityType ?? "")) query = query.eq("entity_type", options.entityType!);
  if (options.managerId) query = query.eq("owner_profile_id", options.managerId);
  if (options.query?.trim()) {
    const term = `%${queryEscape(options.query.trim())}%`;
    query = query.or(`legal_name.ilike.${term},display_name.ilike.${term},pan.ilike.${term},gstin.ilike.${term}`);
  }
  const { data, count, error } = await query.order("legal_name").range((options.page - 1) * pageSize, options.page * pageSize - 1);
  if (error) throw new Error("Unable to load clients.");
  return { clients: (data ?? []) as ClientRecord[], total: count ?? 0, pageSize };
}

export async function clientMembers() {
  const { firmId } = await requireClientFirmScope();
  const supabase = await createSupabaseServerClient();
  const { data, error } = await supabase.from("firm_memberships").select("profile_id, role, profiles(full_name)").eq("firm_id", firmId).eq("status", "ACTIVE").is("archived_at", null).order("created_at");
  if (error) throw new Error("Unable to load relationship managers.");
  return (data ?? []) as unknown as MemberOption[];
}

export async function getClientDetail(clientId: string) {
  const { firmId } = await requireClientFirmScope();
  const supabase = await createSupabaseServerClient();
  const { data: client, error } = await supabase.from("clients").select("id, legal_name, display_name, entity_type, pan, gstin, address, owner_profile_id, service_tags, status, notes, archived_at, updated_at, created_at").eq("firm_id", firmId).eq("id", clientId).maybeSingle();
  if (error) throw new Error("Unable to load the client.");
  if (!client) return null;
  const [contacts, documents, tasks, compliance] = await Promise.all([
    supabase.from("client_contacts").select("id, full_name, email, phone, designation, is_primary, archived_at").eq("firm_id", firmId).eq("client_id", clientId).is("archived_at", null).order("is_primary", { ascending: false }).order("full_name"),
    supabase.from("documents").select("id, file_name, mime_type, byte_size, created_at").eq("firm_id", firmId).eq("client_id", clientId).is("archived_at", null).order("created_at", { ascending: false }),
    supabase.from("tasks").select("id", { count: "exact", head: true }).eq("firm_id", firmId).eq("client_id", clientId).is("archived_at", null),
    supabase.from("compliance_periods").select("id", { count: "exact", head: true }).eq("firm_id", firmId).eq("client_id", clientId).is("archived_at", null),
  ]);
  if (contacts.error || documents.error || tasks.error || compliance.error) throw new Error("Unable to load linked client work.");
  return { client: client as ClientRecord, contacts: (contacts.data ?? []) as ContactRecord[], documents: (documents.data ?? []) as DocumentRecord[], counts: { tasks: tasks.count ?? 0, compliance: compliance.count ?? 0, documents: documents.data?.length ?? 0 } };
}

export async function createClient(input: ClientInput) {
  const supabase = await createSupabaseServerClient();
  const { data, error } = await supabase.rpc("create_client_master", {
    p_legal_name: input.legalName, p_display_name: input.displayName, p_entity_type: input.entityType, p_pan: input.pan, p_gstin: input.gstin, p_address: input.address, p_owner_profile_id: input.relationshipManagerId, p_service_tags: input.serviceTags, p_status: input.status, p_notes: input.notes,
    p_contact: { full_name: input.contact.fullName, email: input.contact.email, phone: input.contact.phone, designation: input.contact.designation },
  });
  if (error) throw new Error(clientErrorMessage(error));
  return data as string;
}

export async function updateClient(clientId: string, updatedAt: string, input: ClientInput) {
  const supabase = await createSupabaseServerClient();
  const { error } = await supabase.rpc("update_client_master", {
    p_client_id: clientId, p_updated_at: updatedAt, p_legal_name: input.legalName, p_display_name: input.displayName, p_entity_type: input.entityType, p_pan: input.pan, p_gstin: input.gstin, p_address: input.address, p_owner_profile_id: input.relationshipManagerId, p_service_tags: input.serviceTags, p_status: input.status, p_notes: input.notes,
  });
  if (error) throw new Error(clientErrorMessage(error));
}

export async function archiveClient(clientId: string, archived: boolean) {
  const supabase = await createSupabaseServerClient();
  const { error } = await supabase.rpc("set_client_archived", { p_client_id: clientId, p_archived: archived });
  if (error) throw new Error(clientErrorMessage(error));
}

export async function saveContact(clientId: string, contact: { id?: string; fullName: string; email: string; phone: string; designation: string; isPrimary: boolean }) {
  const supabase = await createSupabaseServerClient();
  const { error } = await supabase.rpc("upsert_client_contact", { p_client_id: clientId, p_contact_id: contact.id ?? null, p_full_name: contact.fullName, p_email: contact.email, p_phone: contact.phone, p_designation: contact.designation, p_is_primary: contact.isPrimary });
  if (error) throw new Error(clientErrorMessage(error));
}

export async function archiveContact(clientId: string, contactId: string) {
  const supabase = await createSupabaseServerClient();
  const { error } = await supabase.rpc("archive_client_contact", { p_client_id: clientId, p_contact_id: contactId });
  if (error) throw new Error(clientErrorMessage(error));
}

export async function uploadClientDocument(clientId: string, file: File, fileName: string) {
  const { firmId } = await requireClientFirmScope();
  const supabase = await createSupabaseServerClient();
  const path = `${firmId}/${clientId}/${randomUUID()}-${fileName}`;
  const bytes = Buffer.from(await file.arrayBuffer());
  const checksum = createHash("sha256").update(bytes).digest("hex");
  const { error: uploadError } = await supabase.storage.from(CLIENT_DOCUMENT_BUCKET).upload(path, bytes, { contentType: file.type, upsert: false });
  if (uploadError) throw new Error("The document could not be uploaded. Please try again.");
  const { error: metadataError } = await supabase.rpc("create_client_document", { p_client_id: clientId, p_storage_path: path, p_file_name: fileName, p_mime_type: file.type, p_byte_size: file.size, p_checksum: checksum });
  if (metadataError) {
    await supabase.storage.from(CLIENT_DOCUMENT_BUCKET).remove([path]);
    throw new Error(clientErrorMessage(metadataError));
  }
}

export async function createClientDocumentDownload(clientId: string, documentId: string) {
  const { firmId } = await requireClientFirmScope();
  const supabase = await createSupabaseServerClient();
  const { data: document, error } = await supabase.from("documents").select("storage_path").eq("firm_id", firmId).eq("client_id", clientId).eq("id", documentId).is("archived_at", null).maybeSingle();
  if (error || !document) return null;
  const { data, error: signedUrlError } = await supabase.storage.from(CLIENT_DOCUMENT_BUCKET).createSignedUrl(document.storage_path, CLIENT_DOCUMENT_SIGNED_URL_SECONDS);
  if (signedUrlError || !data?.signedUrl) return null;
  return data.signedUrl;
}
