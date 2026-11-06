import { SignOutButton } from "@/components/auth/sign-out-button";
import { Badge } from "@/components/ui/badge";
import { PageHeader } from "@/components/ui/page-header";
import { getAccessState } from "@/lib/auth/state";
import { createSupabaseServerClient } from "@/lib/supabase/server";

export default async function SettingsPage() {
  const supabase = await createSupabaseServerClient();
  const state = await getAccessState(supabase);
  return <><PageHeader eyebrow="Account" title="Your workspace identity." description="A read-only view of the account and firm context used for access decisions." actions={<SignOutButton small />} /><section className="account-card" aria-label="Account details"><dl className="account-details"><div><dt>Full name</dt><dd>{state?.full_name ?? "—"}</dd></div><div><dt>Email</dt><dd>{state?.email ?? "—"}</dd></div><div><dt>Mobile number</dt><dd>{state?.mobile_number ?? "—"}</dd></div><div><dt>Firm name</dt><dd>{state?.firm_name ?? "—"}</dd></div><div><dt>Membership role</dt><dd>{state?.membership_role ? <Badge tone="navy">{state.membership_role}</Badge> : "—"}</dd></div><div><dt>Firm approval</dt><dd><Badge tone={state?.firm_approval_status === "ACTIVE" ? "success" : state?.firm_approval_status === "REJECTED" ? "danger" : "amber"}>{state?.firm_approval_status ?? "UNKNOWN"}</Badge></dd></div></dl><p className="account-note">Profile editing and role changes are intentionally out of scope for this stage. Platform administrators manage approval through the protected admin panel.</p></section></>;
}
