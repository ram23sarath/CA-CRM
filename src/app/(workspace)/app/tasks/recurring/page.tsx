import { ButtonLink } from "@/components/ui/button";
import { EmptyState } from "@/components/ui/empty-state";
import { PageHeader } from "@/components/ui/page-header";
import { taskOptions } from "@/features/tasks/service";
import { RecurringGenerator } from "./recurring-generator";
export default async function RecurringPage(){const options=await taskOptions();const templates=options.templates as {id:string;name:string;recurrence_frequency:string}[];const clients=options.clients as {id:string;display_name:string}[];return <><PageHeader eyebrow="Task workflow" title="Generate recurring work" description="Manual, idempotent period generation. No statutory dates are inferred." actions={<ButtonLink href="/app/tasks" variant="secondary">Back to tasks</ButtonLink>}/>{templates.some(t=>t.recurrence_frequency!=="NONE")&&clients.length?<RecurringGenerator templates={templates} clients={clients}/>:<EmptyState title="No recurring template ready" description="Create or configure an active monthly, quarterly, or annual service template before generating a period."/>}</>}
