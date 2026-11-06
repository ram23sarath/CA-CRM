import { Badge } from "@/components/ui/badge";
import { EmptyState } from "@/components/ui/empty-state";
import { LoadingSkeleton } from "@/components/ui/loading-skeleton";
import { PageHeader } from "@/components/ui/page-header";

import type { ModuleCopy } from "./module-copy";

export function ModuleOverview({ module }: { module: ModuleCopy }) {
  return (
    <>
      <PageHeader eyebrow={module.eyebrow} title={module.title} description={module.description} />
      <div className="module-grid" aria-label="Module overview cards">
        {module.cards.map((card) => <article className="module-card" key={card.label}><Badge tone="teal">{card.label}</Badge><h2>{card.title}</h2><p>{card.description}</p></article>)}
      </div>
      <EmptyState icon={module.icon} title={module.emptyTitle} description={module.emptyDescription} />
      <div className="module-grid" style={{ marginBlockStart: "1rem" }}>
        <article className="module-card module-card--wide"><Badge tone="navy">Loading pattern</Badge><h2>Ready for connected records</h2><LoadingSkeleton lines={2} /></article>
        <article className="module-card"><Badge tone="danger">Error pattern</Badge><h2>Safe when a connection fails</h2><div className="notice notice--info" role="alert"><strong>No live service connected</strong><span>Errors will be surfaced with a retry path once data services exist.</span></div></article>
      </div>
    </>
  );
}
