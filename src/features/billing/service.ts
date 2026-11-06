import { createSupabaseServerClient } from "@/lib/supabase/server";
import { requireClientFirmScope } from "@/features/clients/service";

export async function listInvoices(clientId?: string) {
  const { firmId } = await requireClientFirmScope(); const s = await createSupabaseServerClient();
  let q = s.from("invoices").select("id,client_id,status,invoice_number,currency,issue_date,due_date,subtotal,tax_total,total,client_name_snapshot").eq("firm_id", firmId).order("created_at", { ascending: false });
  if (clientId) q = q.eq("client_id", clientId);
  const { data, error } = await q; if (error) throw new Error("Unable to load invoices.");
  return data ?? [];
}

export async function getInvoice(id: string) {
  const { firmId } = await requireClientFirmScope(); const s = await createSupabaseServerClient();
  const [invoice, lines, payments] = await Promise.all([
    s.from("invoices").select("*").eq("firm_id", firmId).eq("id", id).maybeSingle(),
    s.from("invoice_lines").select("id,description,quantity,rate,tax_rate,tax_code,line_subtotal,line_tax,line_total,service_id,task_id").eq("firm_id", firmId).eq("invoice_id", id).order("created_at"),
    s.from("payment_entries").select("id,entry_type,amount,payment_date,reference,note,created_at").eq("firm_id", firmId).eq("invoice_id", id).order("created_at", { ascending: false }),
  ]);
  if (invoice.error || lines.error || payments.error) throw new Error("Unable to load invoice.");
  if (!invoice.data) return null;
  const paid = (payments.data ?? []).reduce((sum, p) => sum + (p.entry_type === "PAYMENT" ? Number(p.amount) : -Number(p.amount)), 0);
  return { invoice: invoice.data, lines: lines.data ?? [], payments: payments.data ?? [], paid, balance: Number(invoice.data.total) - paid };
}

export async function createInvoice(clientId: string, status: "DRAFT" | "PROFORMA", dueDate: string, notes: string) { const s = await createSupabaseServerClient(); const { data, error } = await s.rpc("create_invoice", { p_client_id: clientId, p_status: status, p_due_date: dueDate || null, p_notes: notes || null }); if (error) throw new Error(error.message); return data as string; }
export async function addInvoiceLine(input: { invoiceId: string; description: string; quantity: number; rate: number; taxRate: number; taxCode: string; serviceId?: string; taskId?: string }) { const s = await createSupabaseServerClient(); const { error } = await s.rpc("add_invoice_line", { p_invoice_id: input.invoiceId, p_description: input.description, p_quantity: input.quantity, p_rate: input.rate, p_tax_rate: input.taxRate, p_tax_code: input.taxCode || null, p_service_id: input.serviceId || null, p_task_id: input.taskId || null }); if (error) throw new Error(error.message); }
export async function issueInvoice(id: string) { const s = await createSupabaseServerClient(); const { data, error } = await s.rpc("issue_invoice", { p_invoice_id: id }); if (error) throw new Error(error.message); return data as string; }
export async function recordPayment(id: string, amount: number, date: string, reference: string) { const s = await createSupabaseServerClient(); const { error } = await s.rpc("record_invoice_payment", { p_invoice_id: id, p_amount: amount, p_payment_date: date, p_reference: reference || null, p_note: null, p_entry_type: "PAYMENT" }); if (error) throw new Error(error.message); }
