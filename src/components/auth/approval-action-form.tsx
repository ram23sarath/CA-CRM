"use client";

import type { FormEvent } from "react";

import { Button } from "@/components/ui/button";

export function ApprovalActionForm({ action, requestId, status }: { action: (formData: FormData) => void | Promise<void>; requestId: string; status: "APPROVED" | "REJECTED" }) {
  function confirmAction(event: FormEvent<HTMLFormElement>) {
    const message = status === "APPROVED" ? "Approve this firm registration and activate its workspace?" : "Reject this firm registration? A reason is required.";
    if (!window.confirm(message)) event.preventDefault();
  }
  return <form action={action} onSubmit={confirmAction}><input type="hidden" name="requestId" value={requestId} /><input type="hidden" name="status" value={status} />{status === "REJECTED" && <input className="approval-card__reason" name="reason" placeholder="Rejection reason" aria-label="Rejection reason" required />}<Button type="submit" variant={status === "REJECTED" ? "secondary" : "primary"} small>{status === "APPROVED" ? "Approve" : "Reject"}</Button></form>;
}
