import type { SupabaseClient } from "@supabase/supabase-js";

import type { AccessState } from "./types";

export async function getAccessState(client: SupabaseClient) {
  const { data, error } = await client.rpc("get_my_access_state");
  if (error) throw new Error("Unable to read account access state.");
  return (data as AccessState | null) ?? null;
}
