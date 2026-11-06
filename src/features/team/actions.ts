"use server";

import { revalidatePath } from "next/cache";
import { decideLeave, decideReimbursement, createAutomationRule, createLeave, createReimbursement, createTimesheet, lockTimesheet, markNotificationRead, setAutomationKillSwitch, setAutomationRuleState, setNotificationPreferences, startAttendance, stopAttendance } from "./service";
import { automationRuleFromFormData, leaveRequestFromFormData, reimbursementFromFormData, timesheetFromFormData } from "./validation";

function fail(error: unknown) { return error instanceof Error ? error.message : "Unable to update team operations."; }
function refresh() { revalidatePath("/app/team"); }

export async function startAttendanceAction(formData: FormData) { try { await startAttendance(String(formData.get("workDate") ?? ""), String(formData.get("note") ?? "")); refresh(); } catch (error) { throw new Error(fail(error)); } }
export async function stopAttendanceAction(formData: FormData) { try { await stopAttendance(String(formData.get("sessionId") ?? "")); refresh(); } catch (error) { throw new Error(fail(error)); } }
export async function createLeaveAction(formData: FormData) { const parsed = leaveRequestFromFormData(formData); if (!parsed.success) throw new Error(parsed.error.issues[0]?.message ?? "Invalid leave request."); try { await createLeave(parsed.data); refresh(); } catch (error) { throw new Error(fail(error)); } }
export async function decideLeaveAction(formData: FormData) { try { await decideLeave(String(formData.get("requestId") ?? ""), String(formData.get("status")) as "APPROVED" | "REJECTED", String(formData.get("note") ?? "")); refresh(); } catch (error) { throw new Error(fail(error)); } }
export async function createTimesheetAction(formData: FormData) { const parsed = timesheetFromFormData(formData); if (!parsed.success) throw new Error(parsed.error.issues[0]?.message ?? "Invalid timesheet entry."); try { await createTimesheet(parsed.data); refresh(); } catch (error) { throw new Error(fail(error)); } }
export async function lockTimesheetAction(formData: FormData) { try { await lockTimesheet(String(formData.get("entryId") ?? "")); refresh(); } catch (error) { throw new Error(fail(error)); } }
export async function createReimbursementAction(formData: FormData) { const parsed = reimbursementFromFormData(formData); if (!parsed.success) throw new Error(parsed.error.issues[0]?.message ?? "Invalid reimbursement."); try { await createReimbursement(parsed.data); refresh(); } catch (error) { throw new Error(fail(error)); } }
export async function decideReimbursementAction(formData: FormData) { try { await decideReimbursement(String(formData.get("reimbursementId") ?? ""), String(formData.get("status")) as "APPROVED" | "REJECTED", String(formData.get("note") ?? "")); refresh(); } catch (error) { throw new Error(fail(error)); } }
export async function markNotificationReadAction(formData: FormData) { try { await markNotificationRead(String(formData.get("notificationId") ?? "")); refresh(); } catch (error) { throw new Error(fail(error)); } }
export async function setNotificationPreferencesAction(formData: FormData) { try { await setNotificationPreferences({ opt_out_all: formData.get("optOutAll") === "on", email_enabled: formData.get("emailEnabled") === "on", whatsapp_enabled: formData.get("whatsappEnabled") === "on", preferred_channel: String(formData.get("preferredChannel") ?? "INTERNAL") as "INTERNAL" | "EMAIL" | "WHATSAPP" }); refresh(); } catch (error) { throw new Error(fail(error)); } }
export async function createAutomationRuleAction(formData: FormData) { const parsed = automationRuleFromFormData(formData); if (!parsed.success) throw new Error(parsed.error.issues[0]?.message ?? "Invalid automation rule."); try { await createAutomationRule(parsed.data); refresh(); } catch (error) { throw new Error(fail(error)); } }
export async function setAutomationRuleStateAction(formData: FormData) { try { await setAutomationRuleState(String(formData.get("ruleId") ?? ""), String(formData.get("enabled")) === "true"); refresh(); } catch (error) { throw new Error(fail(error)); } }
export async function setAutomationKillSwitchAction(formData: FormData) { try { await setAutomationKillSwitch(String(formData.get("paused")) === "true", String(formData.get("safePreviewMode")) !== "false"); refresh(); } catch (error) { throw new Error(fail(error)); } }
