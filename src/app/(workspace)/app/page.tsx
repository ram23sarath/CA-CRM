import { PageHeader } from "@/components/ui/page-header";
import { DashboardSummary } from "@/features/compliance/dashboard-summary";
import { dashboardComplianceSummary } from "@/features/compliance/service";

export default async function WorkspaceOverviewPage() {
  const summary = await dashboardComplianceSummary();
  return <><PageHeader eyebrow="Practice overview" title="Keep the next deadline visible." description="A manual operations view for configured compliance dates and document-backed work." /><DashboardSummary summary={summary} /><section className="module-card module-card--wide"><h2>Manual tracker boundary</h2><p>No government portal requests, submissions, scraping, password storage, or authoritative tax advice are performed here. Configure and verify dates with your firm’s approved process.</p></section></>;
}
