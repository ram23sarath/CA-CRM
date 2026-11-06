import { createSupabaseServerClient } from "@/lib/supabase/server";
import { requireClientFirmScope } from "@/features/clients/service";
import { leadToday, isStaleFollowUp, proposalIsExpired } from "./dates";
import type { Lead, LeadActivity, LeadContact, LeadFollowUp, Proposal, ProposalEvent, ProposalVersion } from "./types";
import type { z } from "zod";
import type { conversionSchema, followUpSchema, leadContactSchema, leadInputSchema, proposalSchema, proposalVersionSchema } from "./validation";

type LeadInput = z.infer<typeof leadInputSchema>;
type ContactInput = z.infer<typeof leadContactSchema>;
type FollowUpInput = z.infer<typeof followUpSchema>;
type ProposalInput = z.infer<typeof proposalSchema>;
type ProposalVersionInput = z.infer<typeof proposalVersionSchema>;
type ConversionInput = z.infer<typeof conversionSchema>;

const leadSelect = "id,name,company_name,email,mobile,source,score,stage,status,owner_profile_id,next_follow_up_date,notes,converted_client_id,converted_at,updated_at,created_at";
const proposalSelect = "id,lead_id,title,status,current_version_id,accepted_at,rejected_at,created_at,updated_at";

async function firmContext() {
  const { firmId } = await requireClientFirmScope();
  const supabase = await createSupabaseServerClient();
  const { data: firm, error } = await supabase.from("firms").select("timezone").eq("id", firmId).maybeSingle();
  if (error) throw new Error("Unable to load firm date settings.");
  return { firmId, timeZone: firm?.timezone || "Asia/Kolkata", supabase };
}

function escapeSearch(value: string) { return value.replace(/[,%_()]/g, "\\$&"); }

async function decorateLeads(supabase: Awaited<ReturnType<typeof createSupabaseServerClient>>, leads: Lead[], firmId: string, timeZone: string) {
  const ids = [...new Set(leads.map((lead) => lead.owner_profile_id).filter(Boolean))] as string[];
  const { data: profiles, error } = ids.length ? await supabase.from("profiles").select("id,full_name").in("id", ids) : { data: [], error: null };
  if (error) throw new Error("Unable to load lead owners.");
  const names = new Map((profiles ?? []).map((profile) => [profile.id, profile]));
  const today = leadToday(timeZone);
  return leads.map((lead) => ({ ...lead, owner: lead.owner_profile_id ? names.get(lead.owner_profile_id) : undefined, displayStatus: isStaleFollowUp(lead.next_follow_up_date, today, lead.status) ? "STALE" : lead.status }));
}

export async function leadOptions() {
  const { firmId, supabase } = await firmContext();
  const [members, clients] = await Promise.all([
    supabase.from("firm_memberships").select("profile_id,profiles(full_name),role").eq("firm_id", firmId).eq("status", "ACTIVE").is("archived_at", null).order("created_at"),
    supabase.from("clients").select("id,display_name,legal_name,entity_type").eq("firm_id", firmId).eq("status", "ACTIVE").is("archived_at", null).order("display_name"),
  ]);
  if (members.error || clients.error) throw new Error("Unable to load lead options.");
  return { members: members.data ?? [], clients: clients.data ?? [] };
}

export async function listLeads(filters: { search?: string; owner?: string; stage?: string; source?: string; stale?: string }) {
  const { firmId, timeZone, supabase } = await firmContext();
  let query = supabase.from("leads").select(leadSelect).eq("firm_id", firmId).is("archived_at", null);
  if (filters.search?.trim()) { const term = `%${escapeSearch(filters.search.trim())}%`; query = query.or(`name.ilike.${term},company_name.ilike.${term},email.ilike.${term},mobile.ilike.${term}`); }
  if (filters.owner) query = query.eq("owner_profile_id", filters.owner);
  if (filters.stage) query = query.eq("stage", filters.stage);
  if (filters.source) query = query.eq("source", filters.source);
  if (filters.stale === "1") query = query.lt("next_follow_up_date", leadToday(timeZone)).eq("status", "OPEN");
  const { data, error } = await query.order("updated_at", { ascending: false }).limit(300);
  if (error) throw new Error("Unable to load leads.");
  return { timeZone, leads: await decorateLeads(supabase, (data ?? []) as Lead[], firmId, timeZone) };
}

export async function getLeadDetail(id: string) {
  const { firmId, timeZone, supabase } = await firmContext();
  const { data: lead, error: leadError } = await supabase.from("leads").select(leadSelect).eq("firm_id", firmId).eq("id", id).maybeSingle();
  if (leadError) throw new Error("Unable to load the lead.");
  if (!lead) return null;
  const [contacts, activities, followUps, proposals, members, clients] = await Promise.all([
    supabase.from("lead_contacts").select("id,full_name,email,mobile,designation,is_primary,created_at").eq("firm_id", firmId).eq("lead_id", id).is("archived_at", null).order("is_primary", { ascending: false }).order("full_name"),
    supabase.from("lead_activities").select("id,activity_type,body,metadata,created_at,actor_profile_id").eq("firm_id", firmId).eq("lead_id", id).order("created_at", { ascending: false }),
    supabase.from("lead_follow_ups").select("id,assigned_to_profile_id,due_date,reminder_date,title,note,status,completed_at,created_at").eq("firm_id", firmId).eq("lead_id", id).order("due_date"),
    supabase.from("proposals").select(proposalSelect).eq("firm_id", firmId).eq("lead_id", id).order("updated_at", { ascending: false }),
    supabase.from("firm_memberships").select("profile_id,profiles(full_name),role").eq("firm_id", firmId).eq("status", "ACTIVE").is("archived_at", null).order("created_at"),
    supabase.from("clients").select("id,display_name,legal_name,entity_type").eq("firm_id", firmId).eq("status", "ACTIVE").is("archived_at", null).order("display_name"),
  ]);
  if (contacts.error || activities.error || followUps.error || proposals.error || members.error || clients.error) throw new Error("Unable to load lead activity.");
  const profileIds = [...new Set([...(activities.data ?? []).map((item) => item.actor_profile_id), ...(followUps.data ?? []).map((item) => item.assigned_to_profile_id)].filter(Boolean))] as string[];
  const { data: profiles, error: profileError } = profileIds.length ? await supabase.from("profiles").select("id,full_name").in("id", profileIds) : { data: [], error: null };
  if (profileError) throw new Error("Unable to load lead actors.");
  const profileMap = new Map((profiles ?? []).map((profile) => [profile.id, profile]));
  const proposalRows = (proposals.data ?? []) as Proposal[];
  const proposalIds = proposalRows.map((proposal) => proposal.id);
  const [versions, events] = await Promise.all([
    proposalIds.length ? supabase.from("proposal_versions").select("id,proposal_id,version_number,service_scope,validity_date,fee_minor,tax_estimate_minor,currency,notes,created_at,created_by_profile_id").eq("firm_id", firmId).in("proposal_id", proposalIds).order("version_number", { ascending: false }) : Promise.resolve({ data: [], error: null }),
    proposalIds.length ? supabase.from("proposal_events").select("id,proposal_id,event_type,metadata,created_at,actor_profile_id").eq("firm_id", firmId).in("proposal_id", proposalIds).order("created_at", { ascending: false }) : Promise.resolve({ data: [], error: null }),
  ]);
  if (versions.error || events.error) throw new Error("Unable to load proposal history.");
  const today = leadToday(timeZone);
  const versionRows = (versions.data ?? []) as (ProposalVersion & { proposal_id: string })[];
  const eventRows = (events.data ?? []) as (ProposalEvent & { proposal_id: string; actor_profile_id: string | null })[];
  const proposalDetails = proposalRows.map((proposal) => {
    const proposalVersions = versionRows.filter((version) => version.proposal_id === proposal.id).map((version) => ({ id: version.id, version_number: version.version_number, service_scope: version.service_scope, validity_date: version.validity_date, fee_minor: Number(version.fee_minor), tax_estimate_minor: Number(version.tax_estimate_minor), currency: version.currency, notes: version.notes, created_at: version.created_at, created_by_profile_id: version.created_by_profile_id }));
    const proposalEvents = eventRows.filter((event) => event.proposal_id === proposal.id).map((event) => ({ id: event.id, event_type: event.event_type, metadata: event.metadata, created_at: event.created_at, actor: event.actor_profile_id ? profileMap.get(event.actor_profile_id) : undefined }));
    const currentVersion = proposalVersions.find((version) => version.id === proposal.current_version_id);
    return { ...proposal, versions: proposalVersions, events: proposalEvents, currentVersion, displayStatus: proposal.status !== "ACCEPTED" && proposal.status !== "REJECTED" && proposal.status !== "CONVERTED" && currentVersion && proposalIsExpired(currentVersion.validity_date, today) ? "EXPIRED" : proposal.status };
  });
  return { lead: (await decorateLeads(supabase, [lead as Lead], firmId, timeZone))[0], contacts: (contacts.data ?? []) as LeadContact[], activities: (activities.data ?? []).map((item) => ({ ...item, actor: profileMap.get(item.actor_profile_id) })) as LeadActivity[], followUps: (followUps.data ?? []).map((item) => ({ ...item, assignee: item.assigned_to_profile_id ? profileMap.get(item.assigned_to_profile_id) : undefined })) as LeadFollowUp[], proposals: proposalDetails, members: members.data ?? [], clients: clients.data ?? [], timeZone };
}

export async function createLead(input: LeadInput) { const supabase = await createSupabaseServerClient(); const { data, error } = await supabase.rpc("create_lead", { p_name: input.name, p_company_name: input.companyName, p_email: input.email || null, p_mobile: input.mobile || null, p_source: input.source, p_score: input.score, p_owner_profile_id: input.ownerId, p_next_follow_up_date: input.nextFollowUpDate, p_notes: input.notes }); if (error) throw new Error(error.message); return data as string; }
export async function setLeadStage(id: string, stage: string, note: string) { const supabase = await createSupabaseServerClient(); const { error } = await supabase.rpc("set_lead_stage", { p_lead_id: id, p_to_stage: stage, p_note: note }); if (error) throw new Error(error.message); }
export async function markLeadLost(id: string, note: string) { const supabase = await createSupabaseServerClient(); const { error } = await supabase.rpc("mark_lead_lost", { p_lead_id: id, p_note: note }); if (error) throw new Error(error.message); }
export async function addLeadActivity(input: { leadId: string; body: string }) { const supabase = await createSupabaseServerClient(); const { error } = await supabase.rpc("add_lead_activity", { p_lead_id: input.leadId, p_body: input.body }); if (error) throw new Error(error.message); }
export async function addLeadContact(input: ContactInput) { const supabase = await createSupabaseServerClient(); const { error } = await supabase.rpc("add_lead_contact", { p_lead_id: input.leadId, p_full_name: input.fullName, p_email: input.email || null, p_mobile: input.mobile || null, p_designation: input.designation, p_is_primary: input.isPrimary }); if (error) throw new Error(error.message); }
export async function addLeadFollowUp(input: FollowUpInput) { const supabase = await createSupabaseServerClient(); const { error } = await supabase.rpc("add_lead_follow_up", { p_lead_id: input.leadId, p_title: input.title, p_due_date: input.dueDate, p_reminder_date: input.reminderDate, p_assigned_to: input.assignedTo, p_note: input.note }); if (error) throw new Error(error.message); }
export async function completeLeadFollowUp(id: string, status: string) { const supabase = await createSupabaseServerClient(); const { error } = await supabase.rpc("complete_lead_follow_up", { p_follow_up_id: id, p_status: status }); if (error) throw new Error(error.message); }
export async function createProposal(input: ProposalInput) { const supabase = await createSupabaseServerClient(); const { data, error } = await supabase.rpc("create_proposal", { p_lead_id: input.leadId, p_title: input.title, p_service_scope: input.serviceScope, p_validity_date: input.validityDate, p_fee_minor: input.feeMinor, p_tax_estimate_minor: input.taxEstimateMinor, p_currency: input.currency, p_notes: input.notes }); if (error) throw new Error(error.message); return data as string; }
export async function createProposalVersion(input: ProposalVersionInput) { const supabase = await createSupabaseServerClient(); const { data, error } = await supabase.rpc("create_proposal_version", { p_proposal_id: input.proposalId, p_service_scope: input.serviceScope, p_validity_date: input.validityDate, p_fee_minor: input.feeMinor, p_tax_estimate_minor: input.taxEstimateMinor, p_currency: input.currency, p_notes: input.notes }); if (error) throw new Error(error.message); return data as string; }
export async function recordProposalDemoEvent(id: string, event: string) { const supabase = await createSupabaseServerClient(); const { error } = await supabase.rpc("record_proposal_demo_event", { p_proposal_id: id, p_event: event }); if (error) throw new Error(error.message); }
export async function setProposalOutcome(id: string, outcome: string) { const supabase = await createSupabaseServerClient(); const { error } = await supabase.rpc("set_proposal_outcome", { p_proposal_id: id, p_outcome: outcome }); if (error) throw new Error(error.message); }
export async function convertLead(input: ConversionInput) { const supabase = await createSupabaseServerClient(); const { data, error } = await supabase.rpc("convert_lead_to_client", { p_lead_id: input.leadId, p_proposal_id: input.proposalId, p_existing_client_id: input.existingClientId, p_entity_type: input.entityType }); if (error) throw new Error(error.message); return data as string; }
