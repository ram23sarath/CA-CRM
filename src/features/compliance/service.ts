import { createSupabaseServerClient } from "@/lib/supabase/server";
import { requireClientFirmScope } from "@/features/clients/service";
import { addDays, complianceDisplayStatus, isExpiringSoon, todayInTimeZone } from "./dates";
import type { CompliancePeriod, ExpiryRegister } from "./types";
import type { compliancePeriodSchema, complianceTemplateSchema, complianceUpdateSchema, expirySchema } from "./validation";
import type { z } from "zod";

type TemplateInput = z.infer<typeof complianceTemplateSchema>;
type PeriodInput = z.infer<typeof compliancePeriodSchema>;
type UpdateInput = z.infer<typeof complianceUpdateSchema>;
type ExpiryInput = z.infer<typeof expirySchema>;

const periodSelect = "id,client_id,type_code,period_key,period_start,period_end,due_date,status,assigned_to_profile_id,task_id,evidence_document_id,filing_reference,source,last_verified_date,last_updated_by_profile_id,updated_at,created_at";
const expirySelect = "id,register_type,name,client_id,owner_profile_id,custodian_profile_id,expiry_date,reminder_date,status,source,last_verified_date,updated_at";

async function firmContext() {
  const { firmId } = await requireClientFirmScope();
  const supabase = await createSupabaseServerClient();
  const { data: firm, error } = await supabase.from("firms").select("timezone").eq("id", firmId).maybeSingle();
  if (error) throw new Error("Unable to load firm date settings.");
  return { firmId, timeZone: firm?.timezone || "Asia/Kolkata", supabase };
}

async function decoratePeriods(supabase: Awaited<ReturnType<typeof createSupabaseServerClient>>, periods: CompliancePeriod[], firmId: string, timeZone: string) {
  const clientIds = [...new Set(periods.map((period) => period.client_id))];
  const memberIds = [...new Set(periods.flatMap((period) => [period.assigned_to_profile_id, period.last_updated_by_profile_id]).filter(Boolean))] as string[];
  const [clients, members] = await Promise.all([
    clientIds.length ? supabase.from("clients").select("id,display_name").eq("firm_id", firmId).in("id", clientIds) : Promise.resolve({ data: [], error: null }),
    memberIds.length ? supabase.from("profiles").select("id,full_name").in("id", memberIds) : Promise.resolve({ data: [], error: null }),
  ]);
  if (clients.error || members.error) throw new Error("Unable to load compliance links.");
  const clientMap = new Map((clients.data ?? []).map((client) => [client.id, client]));
  const memberMap = new Map((members.data ?? []).map((member) => [member.id, member]));
  const today = todayInTimeZone(timeZone);
  return periods.map((period) => ({ ...period, client: clientMap.get(period.client_id), owner: period.assigned_to_profile_id ? memberMap.get(period.assigned_to_profile_id) : undefined, lastUpdater: period.last_updated_by_profile_id ? memberMap.get(period.last_updated_by_profile_id) : undefined, displayStatus: complianceDisplayStatus(period.due_date, period.status, today) }));
}

export async function complianceOptions() {
  const { firmId, supabase } = await firmContext();
  const [clients, members, templates, taskTemplates, documents] = await Promise.all([
    supabase.from("clients").select("id,display_name").eq("firm_id", firmId).eq("status", "ACTIVE").is("archived_at", null).order("display_name"),
    supabase.from("firm_memberships").select("profile_id,profiles(full_name),role").eq("firm_id", firmId).eq("status", "ACTIVE").is("archived_at", null).order("created_at"),
    supabase.from("compliance_templates").select("id,code,name,period_frequency,due_date_offset_days,task_template_id,is_active").eq("firm_id", firmId).eq("is_active", true).is("archived_at", null).order("code"),
    supabase.from("task_templates").select("id,name,recurrence_frequency").eq("firm_id", firmId).eq("is_active", true).is("archived_at", null).order("name"),
    supabase.from("documents").select("id,file_name,client_id").eq("firm_id", firmId).is("archived_at", null).order("created_at", { ascending: false }).limit(200),
  ]);
  if (clients.error || members.error || templates.error || taskTemplates.error || documents.error) throw new Error("Unable to load compliance options.");
  return { clients: clients.data ?? [], members: members.data ?? [], templates: templates.data ?? [], taskTemplates: taskTemplates.data ?? [], documents: documents.data ?? [] };
}

export async function listCompliance(filters: { client?: string; type?: string; period?: string; dueFrom?: string; dueTo?: string; owner?: string; status?: string }) {
  const { firmId, timeZone, supabase } = await firmContext();
  let query = supabase.from("compliance_periods").select(periodSelect).eq("firm_id", firmId).is("archived_at", null);
  if (filters.client) query = query.eq("client_id", filters.client);
  if (filters.type) query = query.eq("type_code", filters.type);
  if (filters.period) query = query.ilike("period_key", `%${filters.period.replace(/[,%_()]/g, "\\$&")}%`);
  if (filters.dueFrom) query = query.gte("due_date", filters.dueFrom);
  if (filters.dueTo) query = query.lte("due_date", filters.dueTo);
  if (filters.owner) query = query.eq("assigned_to_profile_id", filters.owner);
  if (filters.status && !["DUE", "OVERDUE"].includes(filters.status)) query = query.eq("status", filters.status);
  const { data, error } = await query.order("due_date", { ascending: true }).limit(500);
  if (error) throw new Error("Unable to load compliance periods.");
  const decorated = await decoratePeriods(supabase, (data ?? []) as CompliancePeriod[], firmId, timeZone);
  return { timeZone, periods: filters.status && ["DUE", "OVERDUE"].includes(filters.status) ? decorated.filter((period) => period.displayStatus === filters.status) : decorated };
}

export async function listExpiryRegisters() {
  const { firmId, timeZone, supabase } = await firmContext();
  const { data, error } = await supabase.from("expiry_registers").select(expirySelect).eq("firm_id", firmId).is("archived_at", null).order("expiry_date");
  if (error) throw new Error("Unable to load expiry registers.");
  const records = (data ?? []) as ExpiryRegister[];
  const clientIds = [...new Set(records.map((record) => record.client_id).filter(Boolean))] as string[];
  const memberIds = [...new Set(records.flatMap((record) => [record.owner_profile_id, record.custodian_profile_id]).filter(Boolean))] as string[];
  const [clients, members] = await Promise.all([
    clientIds.length ? supabase.from("clients").select("id,display_name").eq("firm_id", firmId).in("id", clientIds) : Promise.resolve({ data: [], error: null }),
    memberIds.length ? supabase.from("profiles").select("id,full_name").in("id", memberIds) : Promise.resolve({ data: [], error: null }),
  ]);
  if (clients.error || members.error) throw new Error("Unable to load expiry links.");
  const clientMap = new Map((clients.data ?? []).map((client) => [client.id, client]));
  const memberMap = new Map((members.data ?? []).map((member) => [member.id, member]));
  const today = todayInTimeZone(timeZone);
  return records.map((record) => ({ ...record, client: record.client_id ? clientMap.get(record.client_id) : undefined, owner: record.owner_profile_id ? memberMap.get(record.owner_profile_id) : undefined, custodian: record.custodian_profile_id ? memberMap.get(record.custodian_profile_id) : undefined, effectiveStatus: record.status === "ACTIVE" && record.expiry_date < today ? "EXPIRED" : record.status, expiringSoon: isExpiringSoon(record.expiry_date, record.status, today) }));
}

export async function dashboardComplianceSummary() {
  const { firmId, timeZone, supabase } = await firmContext();
  const today = todayInTimeZone(timeZone);
  const soon = addDays(today, 30);
  const [periods, expiry] = await Promise.all([
    supabase.from("compliance_periods").select("id,due_date,status").eq("firm_id", firmId).is("archived_at", null).not("status", "in", "(FILED,CANCELLED)").lte("due_date", today),
    supabase.from("expiry_registers").select("id,register_type,name,expiry_date,status").eq("firm_id", firmId).is("archived_at", null).eq("status", "ACTIVE").gte("expiry_date", today).lte("expiry_date", soon).order("expiry_date").limit(8),
  ]);
  if (periods.error || expiry.error) throw new Error("Unable to load compliance summary.");
  return { overdueOrDue: periods.data?.length ?? 0, expiringSoon: expiry.data ?? [], timeZone };
}

export async function createComplianceTemplate(input: TemplateInput) {
  const supabase = await createSupabaseServerClient();
  const { error } = await supabase.rpc("create_compliance_template", { p_code: input.code.toUpperCase(), p_name: input.name, p_frequency: input.frequency, p_due_offset_days: input.dueOffsetDays, p_task_template_id: input.taskTemplateId });
  if (error) throw new Error(error.message);
}

export async function generateCompliancePeriod(input: PeriodInput) {
  const supabase = await createSupabaseServerClient();
  const { data, error } = await supabase.rpc("generate_compliance_period", { p_template_id: input.templateId, p_client_id: input.clientId, p_period_key: input.periodKey, p_period_start: input.periodStart, p_period_end: input.periodEnd, p_owner_profile_id: input.ownerId, p_source: input.source });
  if (error) throw new Error(error.message);
  return data as string;
}

export async function updateCompliancePeriod(input: UpdateInput) {
  const supabase = await createSupabaseServerClient();
  const { error } = await supabase.rpc("update_compliance_period", { p_period_id: input.periodId, p_status: input.status, p_assigned_to_profile_id: input.ownerId, p_filing_reference: input.filingReference, p_evidence_document_id: input.evidenceDocumentId, p_confirm_filed: input.confirmFiled, p_source: input.source, p_last_verified_date: input.lastVerifiedDate });
  if (error) throw new Error(error.message);
}

export async function createExpiryRegister(input: ExpiryInput) {
  const supabase = await createSupabaseServerClient();
  const { error } = await supabase.rpc("create_expiry_register", { p_register_type: input.registerType, p_name: input.name, p_client_id: input.clientId, p_owner_profile_id: input.ownerId, p_custodian_profile_id: input.custodianId, p_expiry_date: input.expiryDate, p_reminder_date: input.reminderDate, p_status: input.status, p_notes: input.notes, p_source: input.source, p_last_verified_date: null });
  if (error) throw new Error(error.message);
}

export async function updateExpiryStatus(id: string, status: string) {
  const supabase = await createSupabaseServerClient();
  const { error } = await supabase.rpc("update_expiry_register_status", { p_register_id: id, p_status: status, p_last_verified_date: null });
  if (error) throw new Error(error.message);
}
