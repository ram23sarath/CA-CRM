import { createSupabaseServerClient } from "@/lib/supabase/server";
import { requireClientFirmScope } from "@/features/clients/service";
import type { z } from "zod";
import type { taskInputSchema } from "./validation";

type TaskInput = z.infer<typeof taskInputSchema>;
const taskSelect = "id,title,description,status,priority,due_at,client_id,service_id,owner_profile_id,assignee_profile_id,reviewer_profile_id,template_id,updated_at,created_at,period_start,period_end";

export async function taskOptions() {
  const { firmId } = await requireClientFirmScope(); const supabase = await createSupabaseServerClient();
  const [clients, services, members, templates] = await Promise.all([
    supabase.from("clients").select("id,display_name").eq("firm_id", firmId).is("archived_at", null).order("display_name"), supabase.from("services").select("id,name").eq("firm_id", firmId).is("archived_at", null).eq("is_active", true).order("name"), supabase.from("firm_memberships").select("profile_id,role,profiles(full_name)").eq("firm_id", firmId).eq("status", "ACTIVE").is("archived_at", null), supabase.from("task_templates").select("id,name,service_id,recurrence_frequency").eq("firm_id", firmId).eq("is_active", true).is("archived_at", null),
  ]);
  if (clients.error || services.error || members.error || templates.error) throw new Error("Unable to load task form options.");
  return { clients: clients.data ?? [], services: services.data ?? [], members: members.data ?? [], templates: templates.data ?? [] };
}

export async function listTasks(filters: { page: number; view?: string; client?: string; service?: string; owner?: string; priority?: string; status?: string; due?: string }) {
  const { firmId } = await requireClientFirmScope(); const supabase = await createSupabaseServerClient(); const size = 20;
  let query = supabase.from("tasks").select(taskSelect, { count: "exact" }).eq("firm_id", firmId).is("archived_at", null);
  for (const [key, column] of [[filters.client,"client_id"],[filters.service,"service_id"],[filters.owner,"owner_profile_id"],[filters.priority,"priority"],[filters.status,"status"]] as const) if (key) query = query.eq(column, key);
  if (filters.due === "overdue") query = query.lt("due_at", new Date().toISOString()).not("status", "in", "(COMPLETED,CANCELLED)");
  if (filters.due === "today") { const start = new Date(); start.setHours(0,0,0,0); const end = new Date(start); end.setDate(end.getDate()+1); query = query.gte("due_at", start.toISOString()).lt("due_at", end.toISOString()); }
  const { data, count, error } = await query.order("due_at", { ascending: true, nullsFirst: false }).range((filters.page - 1)*size, filters.page*size-1);
  if (error) throw new Error("Unable to load tasks."); return { tasks: data ?? [], total: count ?? 0, pageSize: size };
}

export async function getTask(id: string) {
  const { firmId } = await requireClientFirmScope(); const supabase = await createSupabaseServerClient();
  const { data: task, error } = await supabase.from("tasks").select(taskSelect).eq("firm_id", firmId).eq("id", id).maybeSingle(); if (error) throw new Error("Unable to load task."); if (!task) return null;
  const [checklist, comments, history, requests] = await Promise.all([supabase.from("task_checklist_items").select("id,label,position,is_completed").eq("firm_id",firmId).eq("task_id",id).is("archived_at",null).order("position"),supabase.from("task_comments").select("id,body,author_profile_id,created_at").eq("firm_id",firmId).eq("task_id",id).order("created_at"),supabase.from("task_history").select("id,event_type,from_status,to_status,note,created_at").eq("firm_id",firmId).eq("task_id",id).order("created_at",{ascending:false}),supabase.from("task_document_requests").select("id,label,status,created_at").eq("firm_id",firmId).eq("task_id",id).is("archived_at",null)]);
  if (checklist.error||comments.error||history.error||requests.error) throw new Error("Unable to load task activity."); return { task, checklist:checklist.data??[], comments:comments.data??[], history:history.data??[], requests:requests.data??[] };
}
export async function createTask(input: TaskInput) { const supabase=await createSupabaseServerClient(); const {data,error}=await supabase.rpc("create_task_workflow",{p_title:input.title,p_client_id:input.clientId,p_service_id:input.serviceId,p_owner:input.ownerId,p_assignee:input.assigneeId,p_reviewer:input.reviewerId,p_priority:input.priority,p_due_at:input.dueAt,p_description:input.description,p_template_id:input.templateId}); if(error) throw new Error(error.message); return data as string; }
export async function transitionTask(id:string,updatedAt:string,status:string,note:string){const s=await createSupabaseServerClient();const {error}=await s.rpc("transition_task_workflow",{p_task_id:id,p_expected_updated_at:updatedAt,p_to_status:status,p_note:note});if(error)throw new Error(error.message);}
export async function toggleChecklist(id:string,item:string,complete:boolean){const s=await createSupabaseServerClient();const {error}=await s.rpc("set_task_checklist_item",{p_task_id:id,p_item_id:item,p_completed:complete});if(error)throw new Error(error.message);}
export async function addComment(id:string,body:string){const s=await createSupabaseServerClient();const {error}=await s.rpc("add_task_comment_workflow",{p_task_id:id,p_body:body});if(error)throw new Error(error.message);}
export async function saveDocumentRequest(id:string,requestId:string|undefined,label:string,status:string){const s=await createSupabaseServerClient();const {error}=await s.rpc("save_task_document_request",{p_task_id:id,p_request_id:requestId??null,p_label:label,p_status:status});if(error)throw new Error(error.message);}
export async function generateRecurring(template:string,client:string,start:string,end:string){const s=await createSupabaseServerClient();const {data,error}=await s.rpc("create_recurring_task_for_period",{p_template_id:template,p_client_id:client,p_period_start:start,p_period_end:end});if(error)throw new Error(error.message);return data as string;}
