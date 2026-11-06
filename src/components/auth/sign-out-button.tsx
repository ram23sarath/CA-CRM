"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";

import { Button } from "@/components/ui/button";

export function SignOutButton({ small = false }: { small?: boolean }) {
  const router = useRouter();
  const [pending, setPending] = useState(false);
  async function signOut() {
    setPending(true);
    await fetch("/api/auth/logout", { method: "POST" });
    router.replace("/login");
  }
  return <Button type="button" variant="secondary" small={small} onClick={signOut} disabled={pending}>{pending ? "Signing out…" : "Sign out"}</Button>;
}
