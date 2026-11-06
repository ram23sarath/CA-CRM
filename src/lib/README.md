# Shared infrastructure

This area contains validated environment access, Supabase SSR/service clients, authorization state helpers, validation, and future integration adapter interfaces. `src/lib/supabase/service.ts` is server-only and must never be imported into browser components; it requires `SUPABASE_SERVICE_ROLE_KEY` only at runtime.
