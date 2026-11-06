import { ButtonLink } from "@/components/ui/button";
import { PageHeader } from "@/components/ui/page-header";
import { createTaskAction } from "@/features/tasks/actions";
import { TaskForm } from "@/features/tasks/task-form";
import { taskOptions } from "@/features/tasks/service";
export default async function NewTask({searchParams}:{searchParams:Promise<{client?:string}>}){const [options,q]=await Promise.all([taskOptions(),searchParams]);return <><PageHeader eyebrow="Workflow" title="Create task" description="Assign preparation and review without inferring any statutory date." actions={<ButtonLink href="/app/tasks" variant="secondary">Back to tasks</ButtonLink>}/><TaskForm action={createTaskAction} options={options} clientId={q.client}/></>}
