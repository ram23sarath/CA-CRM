import { ComplianceWorkspace } from "@/features/compliance/compliance-workspace";
import { complianceOptions, listCompliance, listExpiryRegisters } from "@/features/compliance/service";

type SearchParams = Promise<Record<string, string | undefined>>;

export default async function CompliancePage({ searchParams }: { searchParams: SearchParams }) {
  const params = await searchParams;
  const view = params.view === "calendar" ? "calendar" : "list";
  const filters = { client: params.client, type: params.type, period: params.period, dueFrom: params.dueFrom, dueTo: params.dueTo, owner: params.owner, status: params.status };
  const [result, expiryRegisters, options] = await Promise.all([listCompliance(filters), listExpiryRegisters(), complianceOptions()]);
  const message = params.error ?? (params.saved === "template" ? "Compliance template saved." : params.saved === "period" ? "Compliance period updated. Filing was recorded only after explicit confirmation." : params.saved === "expiry" ? "Expiry record saved." : params.generated ? "Compliance period generated idempotently and linked to its task when configured." : undefined);
  return <ComplianceWorkspace view={view} filters={filters} periods={result.periods} expiryRegisters={expiryRegisters} options={options} timeZone={result.timeZone} message={message} />;
}
