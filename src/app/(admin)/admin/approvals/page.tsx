import { redirect } from "next/navigation";

import { ApprovalActionForm } from "@/components/auth/approval-action-form";
import { Badge } from "@/components/ui/badge";
import { EmptyState } from "@/components/ui/empty-state";
import { getAccessState } from "@/lib/auth/state";
import { createSupabaseServerClient } from "@/lib/supabase/server";

import { decideRegistration } from "./actions";

export default async function AdminApprovalsPage() {
  const supabase = await createSupabaseServerClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect("/login");
  const state = await getAccessState(supabase);
  if (!state?.is_platform_admin) redirect("/app");
  const { data: requests, error } = await supabase.from("firm_signup_requests").select("id, firm_name_snapshot, full_name_snapshot, email_snapshot, mobile_number, status, submitted_at").eq("status", "PENDING").order("submitted_at", { ascending: true });
  if (error) throw new Error("Unable to load registration requests.");

  return <section className="admin-page" aria-labelledby="approvals-title"><header className="admin-page__header"><div><p className="eyebrow">Platform administration</p><h1 id="approvals-title">Firm registrations</h1><p>Review pending firms before workspace access is activated.</p></div><Badge tone="navy">Administrator only</Badge></header>{!requests?.length ? <EmptyState title="No pending registrations" description="New firm registrations will appear here after password-based signup." /> : <div className="approval-list">{requests.map((request) => <article className="approval-card" key={request.id}><div className="approval-card__top"><div><h2>{request.firm_name_snapshot}</h2><p>{request.full_name_snapshot}</p></div><Badge tone="amber">{request.status}</Badge></div><dl className="approval-card__meta"><div><dt>Email</dt><dd>{request.email_snapshot}</dd></div><div><dt>Mobile</dt><dd>{request.mobile_number}</dd></div><div><dt>Submitted</dt><dd>{new Date(request.submitted_at).toLocaleString("en-IN", { dateStyle: "medium" })}</dd></div><div><dt>Request</dt><dd>{request.id.slice(0, 8)}…</dd></div></dl><div className="approval-card__actions"><ApprovalActionForm action={decideRegistration} requestId={request.id} status="APPROVED" /><ApprovalActionForm action={decideRegistration} requestId={request.id} status="REJECTED" /></div></article>)}</div>}</section>;
}
