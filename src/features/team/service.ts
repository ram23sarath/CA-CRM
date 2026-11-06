import { createSupabaseServerClient } from "@/lib/supabase/server";
import { requireClientFirmScope } from "@/features/clients/service";

import type { z } from "zod";
import type { automationRuleSchema, leaveRequestSchema, reimbursementSchema, timesheetSchema } from "./validation";
import type { AttendanceRow, AutomationRuleRow, AutomationSettings, ClientOption, DeliveryRow, JobRow, LeaveRow, NotificationPreferences, NotificationRow, ReimbursementRow, TaskOption, TeamMember, TeamWorkspace, TimesheetRow } from "./types";

type LeaveInput = z.infer<typeof leaveRequestSchema>;
type TimesheetInput = z.infer<typeof timesheetSchema>;
type ReimbursementInput = z.infer<typeof reimbursementSchema>;

async function teamContext() {
  const { firmId, userId } = await requireClientFirmScope();
  const supabase = await createSupabaseServerClient();
  const { data: firm, error } = await supabase.from("firms").select("name,timezone").eq("id", firmId).maybeSingle();
  if (error) throw new Error("Unable to load firm settings.");
  return { firmId, userId, firm: firm ?? { name: "Firm", timezone: "Asia/Kolkata" }, supabase };
}

function rows<T>(value: unknown) { return (value ?? []) as T[]; }

export async function getTeamWorkspace(): Promise<TeamWorkspace> {
  const { firmId, userId, firm, supabase } = await teamContext();
  const [members, attendance, leave, timesheets, reimbursements, notifications, preferences, rules, settings, deliveries, jobs, tasks, clients] = await Promise.all([
    supabase.from("firm_memberships").select("profile_id,role,status,profiles(full_name,display_name)").eq("firm_id", firmId).eq("status", "ACTIVE").is("archived_at", null).order("created_at"),
    supabase.from("attendance_sessions").select("id,profile_id,work_date,checked_in_at,checked_out_at,note").eq("firm_id", firmId).order("checked_in_at", { ascending: false }).limit(20),
    supabase.from("leave_requests").select("id,requester_profile_id,leave_type,start_date,end_date,reason,status,decided_by_profile_id,decision_note,created_at").eq("firm_id", firmId).order("created_at", { ascending: false }).limit(30),
    supabase.from("timesheet_entries").select("id,profile_id,task_id,client_id,work_date,minutes,description,status,created_at").eq("firm_id", firmId).order("work_date", { ascending: false }).order("created_at", { ascending: false }).limit(30),
    supabase.from("employee_reimbursements").select("id,profile_id,amount,currency,expense_date,description,status,created_at").eq("firm_id", firmId).order("created_at", { ascending: false }).limit(20),
    supabase.from("notifications").select("id,kind,title,body,action_url,read_at,created_at").eq("firm_id", firmId).eq("recipient_profile_id", userId).order("created_at", { ascending: false }).limit(20),
    supabase.from("notification_preferences").select("opt_out_all,email_enabled,whatsapp_enabled,preferred_channel").eq("firm_id", firmId).eq("profile_id", userId).maybeSingle(),
    supabase.from("automation_rules").select("id,name,trigger,conditions,recipient_type,recipient_profile_id,channel,action,enabled,paused_at,throttle_minutes,last_run_at,created_at").eq("firm_id", firmId).order("created_at", { ascending: false }),
    supabase.from("automation_settings").select("paused,safe_preview_mode,max_attempts,updated_at").eq("firm_id", firmId).maybeSingle(),
    supabase.from("automation_deliveries").select("id,event_id,rule_id,recipient_profile_id,channel,action,status,preview_only,attempts,last_error,created_at,completed_at").eq("firm_id", firmId).order("created_at", { ascending: false }).limit(30),
    supabase.from("automation_job_history").select("id,job_type,status,preview_mode,claimed_count,success_count,failure_count,dead_letter_count,error,started_at,finished_at").eq("firm_id", firmId).order("started_at", { ascending: false }).limit(10),
    supabase.from("tasks").select("id,title").eq("firm_id", firmId).is("archived_at", null).order("due_date").limit(100),
    supabase.from("clients").select("id,display_name").eq("firm_id", firmId).eq("status", "ACTIVE").is("archived_at", null).order("display_name").limit(100),
  ]);
  const failed = [members, attendance, leave, timesheets, reimbursements, notifications, preferences, rules, settings, deliveries, jobs, tasks, clients].find((result) => result.error);
  if (failed?.error) throw new Error("Unable to load team operations.");
  return { firmId, userId, firm: firm as { name: string; timezone: string }, members: rows<TeamMember>(members.data), attendance: rows<AttendanceRow>(attendance.data), leave: rows<LeaveRow>(leave.data), timesheets: rows<TimesheetRow>(timesheets.data), reimbursements: rows<ReimbursementRow>(reimbursements.data), notifications: rows<NotificationRow>(notifications.data), preferences: (preferences.data ?? { opt_out_all: false, email_enabled: false, whatsapp_enabled: false, preferred_channel: "INTERNAL" }) as NotificationPreferences, rules: rows<AutomationRuleRow>(rules.data), settings: (settings.data ?? { paused: false, safe_preview_mode: true, max_attempts: 5 }) as AutomationSettings, deliveries: rows<DeliveryRow>(deliveries.data), jobs: rows<JobRow>(jobs.data), tasks: rows<TaskOption>(tasks.data), clients: rows<ClientOption>(clients.data) };
}

export async function startAttendance(workDate: string, note: string) { const supabase = await createSupabaseServerClient(); const { data, error } = await supabase.rpc("start_attendance", { p_work_date: workDate || null, p_note: note || null }); if (error) throw new Error(error.message); return data as string; }
export async function stopAttendance(id: string) { const supabase = await createSupabaseServerClient(); const { error } = await supabase.rpc("stop_attendance", { p_session_id: id, p_checked_out_at: new Date().toISOString() }); if (error) throw new Error(error.message); }
export async function createLeave(input: LeaveInput) { const supabase = await createSupabaseServerClient(); const { data, error } = await supabase.rpc("create_leave_request", { p_leave_type: input.leaveType, p_start_date: input.startDate, p_end_date: input.endDate, p_reason: input.reason || null }); if (error) throw new Error(error.message); return data as string; }
export async function decideLeave(id: string, status: "APPROVED" | "REJECTED", note: string) { const supabase = await createSupabaseServerClient(); const { error } = await supabase.rpc("decide_leave_request", { p_request_id: id, p_status: status, p_note: note || null }); if (error) throw new Error(error.message); }
export async function createTimesheet(input: TimesheetInput) { const supabase = await createSupabaseServerClient(); const { data, error } = await supabase.rpc("add_timesheet_entry", { p_work_date: input.workDate, p_minutes: input.minutes, p_description: input.description, p_task_id: input.taskId, p_client_id: input.clientId }); if (error) throw new Error(error.message); return data as string; }
export async function lockTimesheet(id: string) { const supabase = await createSupabaseServerClient(); const { error } = await supabase.rpc("lock_timesheet_entry", { p_entry_id: id }); if (error) throw new Error(error.message); }
export async function createReimbursement(input: ReimbursementInput) { const supabase = await createSupabaseServerClient(); const { data, error } = await supabase.rpc("create_reimbursement", { p_amount: input.amount, p_expense_date: input.expenseDate, p_description: input.description }); if (error) throw new Error(error.message); return data as string; }
export async function decideReimbursement(id: string, status: "APPROVED" | "REJECTED", note: string) { const supabase = await createSupabaseServerClient(); const { error } = await supabase.rpc("decide_reimbursement", { p_reimbursement_id: id, p_status: status, p_note: note || null }); if (error) throw new Error(error.message); }
export async function markNotificationRead(id: string) { const { firmId, userId, supabase } = await teamContext(); const { error } = await supabase.from("notifications").update({ read_at: new Date().toISOString() }).eq("firm_id", firmId).eq("id", id).eq("recipient_profile_id", userId); if (error) throw new Error(error.message); }
export async function setNotificationPreferences(input: NotificationPreferences) { const supabase = await createSupabaseServerClient(); const { error } = await supabase.rpc("set_notification_preferences", { p_opt_out_all: input.opt_out_all, p_email_enabled: input.email_enabled, p_whatsapp_enabled: input.whatsapp_enabled, p_preferred_channel: input.preferred_channel }); if (error) throw new Error(error.message); }

export type AutomationRuleInput = z.infer<typeof automationRuleSchema>;
export async function createAutomationRule(input: AutomationRuleInput) { const supabase = await createSupabaseServerClient(); const { data, error } = await supabase.rpc("create_automation_rule", { p_name: input.name, p_trigger: input.trigger, p_conditions: input.conditions, p_recipient_type: input.recipientType, p_recipient_profile_id: input.recipientProfileId, p_channel: input.channel, p_action: input.action, p_throttle_minutes: input.throttleMinutes }); if (error) throw new Error(error.message); return data as string; }
export async function setAutomationRuleState(id: string, enabled: boolean) { const supabase = await createSupabaseServerClient(); const { error } = await supabase.rpc("set_automation_rule_state", { p_rule_id: id, p_enabled: enabled }); if (error) throw new Error(error.message); }
export async function setAutomationKillSwitch(paused: boolean, safePreviewMode: boolean) { const supabase = await createSupabaseServerClient(); const { error } = await supabase.rpc("set_automation_kill_switch", { p_paused: paused, p_safe_preview_mode: safePreviewMode }); if (error) throw new Error(error.message); }

