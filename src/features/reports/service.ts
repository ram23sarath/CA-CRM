import { createSupabaseServerClient } from "@/lib/supabase/server";
import { requireClientFirmScope } from "@/features/clients/service";
export async function getPracticeReport() {
  const { firmId } = await requireClientFirmScope(); const s = await createSupabaseServerClient();
  const [invoices, payments, tasks, compliance] = await Promise.all([
    s.from("invoices").select("id,total,status,issue_date,due_date").eq("firm_id", firmId),
    s.from("payment_entries").select("amount,entry_type").eq("firm_id", firmId),
    s.from("tasks").select("status").eq("firm_id", firmId).is("archived_at", null),
    s.from("compliance_periods").select("status,due_date").eq("firm_id", firmId).is("archived_at", null),
  ]); if (invoices.error || payments.error || tasks.error || compliance.error) throw new Error("Unable to load practice report.");
  const issued = invoices.data?.filter((i) => i.status === "ISSUED") ?? []; const billed = issued.reduce((n, i) => n + Number(i.total), 0); const collected = payments.data?.reduce((n, p) => n + (p.entry_type === "PAYMENT" ? Number(p.amount) : -Number(p.amount)), 0) ?? 0;
  return { billed, collected, outstanding: billed - collected, overdue: issued.filter((i) => i.due_date && i.due_date < new Date().toISOString().slice(0, 10)).reduce((n, i) => n + Number(i.total), 0), completedTasks: tasks.data?.filter((t) => t.status === "COMPLETED").length ?? 0, openTasks: tasks.data?.filter((t) => !["COMPLETED", "CANCELLED"].includes(t.status)).length ?? 0, complianceDue: compliance.data?.filter((c) => !["FILED", "CANCELLED"].includes(c.status)).length ?? 0 };
}
