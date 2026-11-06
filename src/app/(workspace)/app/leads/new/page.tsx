import { ButtonLink } from "@/components/ui/button";
import { PageHeader } from "@/components/ui/page-header";
import { LeadForm } from "@/features/leads/lead-forms";
import { leadOptions } from "@/features/leads/service";

export default async function NewLeadPage() { const options = await leadOptions(); return <><PageHeader eyebrow="Growth pipeline" title="Capture a lead" description="Store the prospect context and agree the next follow-up before a proposal exists." actions={<ButtonLink href="/app/leads" variant="secondary">Back to leads</ButtonLink>} /><LeadForm members={options.members} /></>; }
