"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";

type FieldErrors = Record<string, string[] | undefined>;

export function SignupForm() {
  const router = useRouter();
  const [pending, setPending] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [fieldErrors, setFieldErrors] = useState<FieldErrors>({});

  async function submit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setPending(true);
    setError(null);
    setFieldErrors({});
    const values = Object.fromEntries(new FormData(event.currentTarget).entries());
    try {
      const response = await fetch("/api/auth/signup", { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify(values) });
      const result = await response.json() as { error?: string; fieldErrors?: FieldErrors };
      if (!response.ok) {
        setError(result.error ?? "Please review the form and try again.");
        setFieldErrors(result.fieldErrors ?? {});
        return;
      }
      router.replace("/pending-approval");
    } catch {
      setError("The registration service is unavailable. Please try again.");
    } finally {
      setPending(false);
    }
  }

  const first = (name: string) => fieldErrors[name]?.[0];
  return <form className="auth-form__fields" onSubmit={submit} noValidate aria-describedby={error ? "signup-error" : undefined}>
    {error && <div className="notice notice--error" id="signup-error" role="alert">{error}</div>}
    <Input label="Firm name" name="firmName" placeholder="Your practice name" error={first("firmName")} disabled={pending} required />
    <Input label="Full name" name="fullName" placeholder="Your name" error={first("fullName")} disabled={pending} required />
    <Input label="Email address" type="email" name="email" placeholder="you@practice.example" error={first("email")} disabled={pending} required />
    <Input label="Mobile number" type="tel" name="mobileNumber" placeholder="+919876543210" hint="Use +91 followed by 10 digits." error={first("mobileNumber")} disabled={pending} required />
    <Input label="Password" type="password" name="password" hint="At least 8 characters with a letter and number." error={first("password")} disabled={pending} required />
    <Input label="Confirm password" type="password" name="confirmPassword" error={first("confirmPassword")} disabled={pending} required />
    <Button type="submit" disabled={pending}>{pending ? "Submitting registration…" : "Submit registration"}</Button>
  </form>;
}
