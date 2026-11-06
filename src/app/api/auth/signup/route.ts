import { NextResponse } from "next/server";

import { signupSchema, validationErrors } from "@/lib/auth/validation";
import { hasSameOrigin } from "@/lib/auth/csrf";
import { createSupabaseServerClient } from "@/lib/supabase/server";
import { createSupabaseServiceClient } from "@/lib/supabase/service";

export async function POST(request: Request) {
  if (!hasSameOrigin(request)) return NextResponse.json({ error: "Invalid request origin." }, { status: 403 });
  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ error: "Send a valid registration request." }, { status: 400 });
  }

  const parsed = signupSchema.safeParse(body);
  if (!parsed.success) return NextResponse.json({ fieldErrors: validationErrors(parsed.error) }, { status: 400 });

  const values = parsed.data;
  const supabase = await createSupabaseServerClient();
  const { data, error } = await supabase.auth.signUp({
    email: values.email,
    password: values.password,
    options: { data: { full_name: values.fullName } },
  });

  if (error || !data.user) {
    return NextResponse.json({ error: "Unable to create an account with those details." }, { status: 400 });
  }
  if (!data.user.identities?.length) {
    return NextResponse.json({ error: "Unable to create an account with those details." }, { status: 409 });
  }
  if (!data.session) {
    return NextResponse.json({ error: "Email confirmation is enabled. Disable it in Supabase Auth for this password-only flow." }, { status: 503 });
  }

  try {
    const service = createSupabaseServiceClient();
    const { data: registration, error: registrationError } = await service.rpc("register_firm_pending", {
      p_user_id: data.user.id,
      p_email: values.email,
      p_full_name: values.fullName,
      p_mobile_number: values.mobileNumber,
      p_firm_name: values.firmName,
    });

    if (registrationError) throw registrationError;
    return NextResponse.json({ ok: true, status: registration?.status ?? "PENDING" });
  } catch {
    const service = createSupabaseServiceClient();
    await service.auth.admin.deleteUser(data.user.id);
    return NextResponse.json({ error: "Registration could not be completed. Please try again." }, { status: 500 });
  }
}
