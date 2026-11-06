import { NextResponse } from "next/server";

import { getAccessState } from "@/lib/auth/state";
import { hasSameOrigin } from "@/lib/auth/csrf";
import { loginSchema, validationErrors } from "@/lib/auth/validation";
import { createSupabaseServerClient } from "@/lib/supabase/server";

export async function POST(request: Request) {
  if (!hasSameOrigin(request)) return NextResponse.json({ error: "Invalid request origin." }, { status: 403 });
  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ error: "Send a valid sign-in request." }, { status: 400 });
  }

  const parsed = loginSchema.safeParse(body);
  if (!parsed.success) return NextResponse.json({ fieldErrors: validationErrors(parsed.error) }, { status: 400 });

  const supabase = await createSupabaseServerClient();
  const { error } = await supabase.auth.signInWithPassword(parsed.data);
  if (error) return NextResponse.json({ error: "Unable to sign in with those details." }, { status: 401 });

  try {
    const state = await getAccessState(supabase);
    return NextResponse.json({ ok: true, state });
  } catch {
    await supabase.auth.signOut();
    return NextResponse.json({ error: "Account access is not configured yet." }, { status: 503 });
  }
}
