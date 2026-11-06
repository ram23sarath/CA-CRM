import { redirect } from "next/navigation";

import { SignOutButton } from "@/components/auth/sign-out-button";
import { getAccessState } from "@/lib/auth/state";
import { createSupabaseServerClient } from "@/lib/supabase/server";

export default async function PendingApprovalPage() {
  const supabase = await createSupabaseServerClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect("/login");
  const state = await getAccessState(supabase);
  if (!state || state.access_status === "ACTIVE") redirect("/app");
  if (state.access_status === "REJECTED") redirect("/registration-rejected");
  return <section className="status-page page-container" aria-labelledby="pending-title"><div className="status-page__icon" aria-hidden="true">✓</div><p className="eyebrow">Registration received</p><h1 id="pending-title">Your firm is awaiting approval.</h1><p className="status-page__lead">We have submitted the registration for <strong>{state.firm_name ?? "your firm"}</strong>. A platform administrator will review it before workspace access is enabled.</p><dl className="status-details"><div><dt>Registered email</dt><dd>{state.email ?? user.email}</dd></div><div><dt>Firm name</dt><dd>{state.firm_name ?? "—"}</dd></div><div><dt>Registration status</dt><dd><span className="badge badge--amber">Pending approval</span></dd></div></dl><SignOutButton /></section>;
}
