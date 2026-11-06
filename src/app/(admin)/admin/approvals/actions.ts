"use server";

import { revalidatePath } from "next/cache";
import { z } from "zod";

import { createSupabaseServerClient } from "@/lib/supabase/server";
import { createSupabaseServiceClient } from "@/lib/supabase/service";

const requestIdSchema = z.string().uuid();

export async function decideRegistration(formData: FormData) {
  const requestId = requestIdSchema.parse(formData.get("requestId"));
  const status = z.enum(["APPROVED", "REJECTED"]).parse(formData.get("status"));
  const reason = String(formData.get("reason") ?? "").trim();
  if (status === "REJECTED" && !reason) throw new Error("A rejection reason is required.");

  const supabase = await createSupabaseServerClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) throw new Error("You must be signed in.");
  const { data: administrator } = await supabase.from("platform_admins").select("user_id").eq("user_id", user.id).eq("enabled", true).maybeSingle();
  if (!administrator) throw new Error("Platform administrator access is required.");

  const service = createSupabaseServiceClient();
  const { error } = await service.rpc("set_firm_signup_request_status", {
    p_request_id: requestId,
    p_status: status,
    p_reviewer_user_id: user.id,
    p_rejection_reason: status === "REJECTED" ? reason : null,
  });
  if (error) throw new Error("The registration decision could not be saved.");
  revalidatePath("/admin/approvals");
}
