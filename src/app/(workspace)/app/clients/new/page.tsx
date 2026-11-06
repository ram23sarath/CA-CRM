import { ButtonLink } from "@/components/ui/button";
import { PageHeader } from "@/components/ui/page-header";
import { createClientAction } from "@/features/clients/actions";
import { ClientForm } from "@/features/clients/client-form";
import { clientMembers } from "@/features/clients/service";

export default async function NewClientPage() {
  const members = await clientMembers();
  return <><PageHeader eyebrow="Client master" title="Create client" description="Add the record before linking work, compliance, or documents." actions={<ButtonLink href="/app/clients" variant="secondary">Back to clients</ButtonLink>} /><ClientForm action={createClientAction} members={members} /></>;
}
