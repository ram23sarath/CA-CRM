"use client";

import { useState } from "react";

import type { AccessState } from "@/lib/auth/types";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";

export function LoginForm() {
  const [pending, setPending] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function submit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setPending(true);
    setError(null);
    const values = Object.fromEntries(new FormData(event.currentTarget).entries());
    try {
      const response = await fetch("/api/auth/login", { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify(values) });
      const result = await response.json() as { error?: string; state?: AccessState };
      if (!response.ok) { setError(result.error ?? "Unable to sign in with those details."); return; }
      const destination = result.state?.access_status === "PENDING" ? "/pending-approval" : result.state?.access_status === "REJECTED" ? "/registration-rejected" : result.state?.access_status === "PLATFORM_ADMIN" ? "/admin/approvals" : result.state?.access_status === "ACTIVE" ? "/app" : "/login";
      window.location.assign(destination);
    } catch {
      setError("The sign-in service is unavailable. Please try again.");
    } finally {
      setPending(false);
    }
  }

  return <form className="auth-form__fields" onSubmit={submit} noValidate aria-describedby={error ? "login-error" : undefined}>
    {error && <div className="notice notice--error" id="login-error" role="alert">{error}</div>}
    <Input label="Email address" type="email" name="email" placeholder="you@practice.example" disabled={pending} required />
    <Input label="Password" type="password" name="password" placeholder="Your password" disabled={pending} required />
    <Button type="submit" disabled={pending}>{pending ? "Signing in…" : "Sign in"}</Button>
  </form>;
}
