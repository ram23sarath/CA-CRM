import { createClient } from "@supabase/supabase-js";

import { getSupabaseEnv } from "./env";

export function createSupabaseServiceClient() {
  const { url, serviceRoleKey } = getSupabaseEnv(true);
  return createClient(url, serviceRoleKey!, {
    auth: { autoRefreshToken: false, persistSession: false, detectSessionInUrl: false },
  });
}
