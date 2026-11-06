import { createServerClient } from "@supabase/ssr";
import { NextResponse, type NextRequest } from "next/server";

import { getSupabaseEnv } from "@/lib/supabase/env";

function copyCookies(source: NextResponse, target: NextResponse) {
  source.cookies.getAll().forEach((cookie) => target.cookies.set(cookie));
  return target;
}

function redirect(request: NextRequest, destination: string, response: NextResponse) {
  return copyCookies(response, NextResponse.redirect(new URL(destination, request.url)));
}

export default async function proxy(request: NextRequest) {
  const pathname = request.nextUrl.pathname;
  const isWorkspace = pathname === "/app" || pathname.startsWith("/app/");
  const isAdmin = pathname === "/admin" || pathname.startsWith("/admin/");
  const isStatusPage = pathname === "/pending-approval" || pathname === "/registration-rejected";
  if (!isWorkspace && !isAdmin && !isStatusPage) return NextResponse.next();

  let env: ReturnType<typeof getSupabaseEnv>;
  try {
    env = getSupabaseEnv();
  } catch {
    return NextResponse.json({ error: "Supabase authentication is not configured." }, { status: 503 });
  }

  const response = NextResponse.next({ request });
  const supabase = createServerClient(env.url, env.anonKey, {
    cookies: {
      getAll: () => request.cookies.getAll(),
      setAll(cookiesToSet) {
        cookiesToSet.forEach(({ name, value, options }) => {
          request.cookies.set(name, value);
          response.cookies.set(name, value, options);
        });
      },
    },
  });
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return redirect(request, "/login", response);

  const { data: state, error } = await supabase.rpc("get_my_access_state");
  if (error || !state) return NextResponse.json({ error: "Account access is not configured." }, { status: 503 });
  const accessStatus = state.access_status as string;

  if (isAdmin && accessStatus !== "PLATFORM_ADMIN") return redirect(request, accessStatus === "PENDING" ? "/pending-approval" : accessStatus === "REJECTED" ? "/registration-rejected" : "/login", response);
  if (isWorkspace && accessStatus !== "ACTIVE") return redirect(request, accessStatus === "PENDING" ? "/pending-approval" : accessStatus === "REJECTED" ? "/registration-rejected" : "/login", response);
  if (isStatusPage) {
    if (accessStatus === "PENDING" && pathname !== "/pending-approval") return redirect(request, "/pending-approval", response);
    if (accessStatus === "REJECTED" && pathname !== "/registration-rejected") return redirect(request, "/registration-rejected", response);
    if (accessStatus === "ACTIVE") return redirect(request, "/app", response);
    if (accessStatus === "PLATFORM_ADMIN") return redirect(request, "/admin/approvals", response);
    if (accessStatus === "SUSPENDED") return redirect(request, "/login", response);
  }

  return response;
}

export const config = { matcher: ["/app/:path*", "/admin/:path*", "/pending-approval", "/registration-rejected"] };
