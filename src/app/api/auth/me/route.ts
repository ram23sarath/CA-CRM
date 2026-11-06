import { NextResponse } from "next/server";

import { getAccessState } from "@/lib/auth/state";
import { createSupabaseServerClient } from "@/lib/supabase/server";

export async function GET() {
  const supabase = await createSupabaseServerClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return NextResponse.json({ authenticated: false }, { status: 401 });
  try {
    return NextResponse.json({ authenticated: true, state: await getAccessState(supabase) });
  } catch {
    return NextResponse.json({ error: "Account access is not configured yet." }, { status: 503 });
  }
}
