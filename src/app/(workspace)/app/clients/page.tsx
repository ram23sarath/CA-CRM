import Link from "next/link";

import { Badge } from "@/components/ui/badge";
import { ButtonLink } from "@/components/ui/button";
import { EmptyState } from "@/components/ui/empty-state";
import { PageHeader } from "@/components/ui/page-header";
import { DataTable } from "@/components/ui/data-table";
import { clientMembers, listClients } from "@/features/clients/service";

type Query = { page?: string; q?: string; status?: string; entity?: string; manager?: string; archived?: string };

export default async function ClientsPage({ searchParams }: { searchParams: Promise<Query> }) {
  const query = await searchParams;
  const page = Math.max(1, Number(query.page) || 1);
  const archived = query.archived === "1";
  const [{ clients, total, pageSize }, members] = await Promise.all([listClients({ page, query: query.q, status: query.status, entityType: query.entity, managerId: query.manager, archived }), clientMembers()]);
  const pages = Math.max(1, Math.ceil(total / pageSize));
  const filters = new URLSearchParams();
  if (query.q) filters.set("q", query.q); if (query.status) filters.set("status", query.status); if (query.entity) filters.set("entity", query.entity); if (query.manager) filters.set("manager", query.manager); if (archived) filters.set("archived", "1");
  const pageHref = (nextPage: number) => { const copy = new URLSearchParams(filters); copy.set("page", String(nextPage)); return `/app/clients?${copy}`; };
  return <>
    <PageHeader eyebrow="Client master" title="Clients" description="Firm-scoped client records, contacts, and private documents." actions={<ButtonLink href="/app/clients/new">Create client</ButtonLink>} />
    <form className="client-filters" action="/app/clients"><input className="input" aria-label="Search clients" name="q" defaultValue={query.q} placeholder="Search name, PAN, or GSTIN" /><select className="input" name="status" defaultValue={query.status ?? ""}><option value="">All statuses</option><option value="ACTIVE">Active</option><option value="INACTIVE">Inactive</option></select><select className="input" name="entity" defaultValue={query.entity ?? ""}><option value="">All entity types</option>{["INDIVIDUAL", "COMPANY", "LLP", "PARTNERSHIP", "TRUST", "OTHER"].map((entity) => <option key={entity} value={entity}>{entity.replace("_", " ")}</option>)}</select><select className="input" name="manager" defaultValue={query.manager ?? ""}><option value="">All relationship managers</option>{members.map((member) => <option key={member.profile_id} value={member.profile_id}>{member.profiles?.full_name ?? member.profile_id}</option>)}</select>{archived && <input type="hidden" name="archived" value="1" />}<button className="button button--secondary button--small" type="submit">Apply filters</button></form>
    <div className="client-list__meta"><p>{total} {total === 1 ? "client" : "clients"}{archived ? " archived" : ""}</p><Link href={archived ? "/app/clients" : "/app/clients?archived=1"}>{archived ? "View active clients" : "View archived clients"}</Link></div>
    {clients.length ? <><DataTable caption="Client records" rowKey={(client) => client.id} columns={[{ key: "display_name", label: "Client", render: (client) => <Link className="table-link" href={`/app/clients/${client.id}`}>{client.display_name}<span>{client.legal_name}</span></Link> }, { key: "entity_type", label: "Entity", render: (client) => client.entity_type.replace("_", " ") }, { key: "pan", label: "PAN" }, { key: "gstin", label: "GSTIN" }, { key: "status", label: "Status", render: (client) => <Badge tone={client.status === "ACTIVE" ? "success" : "amber"}>{client.status}</Badge> }]} rows={clients} /><nav className="pagination" aria-label="Client pages"><span>Page {page} of {pages}</span>{page > 1 && <ButtonLink href={pageHref(page - 1)} variant="secondary" small>Previous</ButtonLink>}{page < pages && <ButtonLink href={pageHref(page + 1)} variant="secondary" small>Next</ButtonLink>}</nav></> : <EmptyState title={archived ? "No archived clients" : "No clients found"} description={query.q || query.status || query.entity || query.manager ? "Try clearing one or more filters." : "Create your first firm client record to begin."} action={!archived ? <ButtonLink href="/app/clients/new" small>Create client</ButtonLink> : undefined} icon="○" />}
  </>;
}
