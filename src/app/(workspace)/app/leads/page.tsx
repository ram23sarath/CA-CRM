import { LeadPipeline } from "@/features/leads/lead-pipeline";
import { leadOptions, listLeads } from "@/features/leads/service";

export default async function LeadsPage({ searchParams }: { searchParams: Promise<Record<string, string | undefined>> }) {
  const params = await searchParams;
  const view = params.view === "kanban" ? "kanban" : "table";
  const filters = { search: params.search, owner: params.owner, stage: params.stage, source: params.source, stale: params.stale };
  const [result, options] = await Promise.all([listLeads(filters), leadOptions()]);
  const message = params.error ?? (params.saved === "created" ? "Lead created." : undefined);
  return <LeadPipeline view={view} filters={filters} leads={result.leads} members={options.members} timeZone={result.timeZone} message={message} />;
}
