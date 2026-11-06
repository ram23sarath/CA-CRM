import { redirect } from "next/navigation";

import { SignOutButton } from "@/components/auth/sign-out-button";
import { getAccessState } from "@/lib/auth/state";
import { createSupabaseServerClient } from "@/lib/supabase/server";

export default async function RegistrationRejectedPage() {
  const supabase = await createSupabaseServerClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect("/login");
  const state = await getAccessState(supabase);
  if (!state || state.access_status === "ACTIVE") redirect("/app");
  if (state.access_status === "PENDING") redirect("/pending-approval");
  return <section className="status-page page-container" aria-labelledby="rejected-title"><div className="status-page__icon status-page__icon--danger" aria-hidden="true">!</div><p className="eyebrow">Registration update</p><h1 id="rejected-title">This firm registration was not approved.</h1><p className="status-page__lead">Workspace access remains disabled. If you need clarification, use the administrator message below or contact your platform administrator.</p><dl className="status-details"><div><dt>Firm name</dt><dd>{state.firm_name ?? "—"}</dd></div><div><dt>Registration status</dt><dd><span className="badge badge--danger">Rejected</span></dd></div>{state.rejection_reason && <div><dt>Administrator message</dt><dd>{state.rejection_reason}</dd></div>}</dl><SignOutButton /></section>;
}
