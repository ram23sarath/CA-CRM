"use client";

import { useActionState } from "react";
import { Button } from "@/components/ui/button";
import { uploadClientDocumentAction, type ClientFormState } from "./actions";

export function DocumentUploadForm({ clientId, maximumMegabytes }: { clientId: string; maximumMegabytes: number }) {
  const [state, action, pending] = useActionState(uploadClientDocumentAction, {} as ClientFormState);
  return <form className="upload-form" action={action}><input type="hidden" name="clientId" value={clientId} /><label className="field"><span className="field__label">Add private document</span><input className="input" type="file" name="document" required accept=".pdf,.jpg,.jpeg,.png,.webp,.txt,.doc,.docx,.xls,.xlsx" /><span className="field__hint">PDF, images, text, or Office files up to {maximumMegabytes} MB. Files stay private to this firm.</span></label>{state.error && <p className="notice notice--error" role="alert">{state.error}</p>}<Button type="submit" small disabled={pending}>{pending ? "Uploading…" : "Upload"}</Button></form>;
}
