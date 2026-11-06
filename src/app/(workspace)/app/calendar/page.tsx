import { ComplianceWorkspace } from "@/features/compliance/compliance-workspace";
import { complianceOptions, listCompliance, listExpiryRegisters } from "@/features/compliance/service";

export default async function CalendarPage() {
  const filters = {};
  const [result, expiryRegisters, options] = await Promise.all([listCompliance(filters), listExpiryRegisters(), complianceOptions()]);
  return <ComplianceWorkspace view="calendar" filters={filters} periods={result.periods} expiryRegisters={expiryRegisters} options={options} timeZone={result.timeZone} />;
}
