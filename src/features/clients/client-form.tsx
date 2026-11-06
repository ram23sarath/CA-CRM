"use client";

import { useActionState } from "react";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import type { MemberOption, ClientRecord, ContactRecord } from "./types";
import type { ClientFormState } from "./actions";

const initialState: ClientFormState = {};
const entities = ["INDIVIDUAL", "COMPANY", "LLP", "PARTNERSHIP", "TRUST", "OTHER"];

function SelectField({ label, name, defaultValue, children }: { label: string; name: string; defaultValue?: string | null; children: React.ReactNode }) {
  return <label className="field"><span className="field__label">{label}</span><select className="input" name={name} defaultValue={defaultValue ?? ""}>{children}</select></label>;
}

export function ClientForm({ action, members, client, primaryContact }: { action: (state: ClientFormState, formData: FormData) => Promise<ClientFormState>; members: MemberOption[]; client?: ClientRecord; primaryContact?: ContactRecord }) {
  const [state, formAction, pending] = useActionState(action, initialState);
  const error = (name: string) => state.fieldErrors?.[name]?.[0];
  return (
    <form className="client-form" action={formAction}>
      {client && <><input type="hidden" name="clientId" value={client.id} /><input type="hidden" name="updatedAt" value={client.updated_at} /></>}
      {state.error && <p className="notice notice--error" role="alert">{state.error}</p>}
      <section className="client-form__section"><h2>Identity</h2><p>Identifier checks only validate the expected format; they do not verify government records.</p><div className="client-form__grid">
        <Input label="Legal name" name="legalName" required defaultValue={client?.legal_name} error={error("legalName")} />
        <Input label="Display name" name="displayName" required defaultValue={client?.display_name} error={error("displayName")} />
        <SelectField label="Entity type" name="entityType" defaultValue={client?.entity_type ?? "OTHER"}>{entities.map((value) => <option key={value} value={value}>{value.replace("_", " ")}</option>)}</SelectField>
        <SelectField label="Status" name="status" defaultValue={client?.status ?? "ACTIVE"}><option value="ACTIVE">Active</option><option value="INACTIVE">Inactive</option></SelectField>
        <Input label="PAN" name="pan" defaultValue={client?.pan ?? ""} hint="Format validation only — not government verification." error={error("pan")} maxLength={10} />
        <Input label="GSTIN" name="gstin" defaultValue={client?.gstin ?? ""} hint="Format and state-code validation only — not government verification." error={error("gstin")} maxLength={15} />
        <Input label="Service tags" name="serviceTags" defaultValue={client?.service_tags.join(", ") ?? ""} hint="Separate tags with commas." error={error("serviceTags")} />
        <SelectField label="Relationship manager" name="relationshipManagerId" defaultValue={client?.owner_profile_id}><option value="">Unassigned</option>{members.map((member) => <option key={member.profile_id} value={member.profile_id}>{member.profiles?.full_name ?? member.profile_id} · {member.role}</option>)}</SelectField>
      </div><label className="field"><span className="field__label">Address</span><textarea className="input textarea" name="address" defaultValue={client?.address ?? ""} rows={3} /></label><label className="field"><span className="field__label">Notes</span><textarea className="input textarea" name="notes" defaultValue={client?.notes ?? ""} rows={4} /></label></section>
      {!client && <section className="client-form__section"><h2>Primary contact</h2><p>This is optional. You can add or change contacts later.</p><div className="client-form__grid"><Input label="Full name" name="contactFullName" defaultValue={primaryContact?.full_name ?? ""} /><Input label="Email" name="contactEmail" type="email" defaultValue={primaryContact?.email ?? ""} error={error("contact")} /><Input label="Phone" name="contactPhone" defaultValue={primaryContact?.phone ?? ""} /><Input label="Designation" name="contactDesignation" defaultValue={primaryContact?.designation ?? ""} /></div></section>}
      <div className="client-form__actions"><Button type="submit" disabled={pending}>{pending ? "Saving…" : client ? "Save client" : "Create client"}</Button></div>
    </form>
  );
}
