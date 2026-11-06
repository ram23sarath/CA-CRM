type SupabaseEnv = {
  url: string;
  anonKey: string;
  serviceRoleKey?: string;
};

export function getSupabaseEnv(requireServiceRole = false): SupabaseEnv {
  const url = process.env.SUPABASE_URL;
  const anonKey = process.env.SUPABASE_ANON_KEY;
  const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

  if (!url || !anonKey || (requireServiceRole && !serviceRoleKey)) {
    throw new Error("Supabase server configuration is missing. Set the documented environment variables.");
  }

  return { url, anonKey, serviceRoleKey };
}
