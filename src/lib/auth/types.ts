export type AccessStatus = "NONE" | "PENDING" | "REJECTED" | "SUSPENDED" | "ACTIVE" | "PLATFORM_ADMIN";

export type AccessState = {
  user_id: string;
  email: string | null;
  full_name: string | null;
  mobile_number: string | null;
  is_platform_admin: boolean;
  firm_id: string | null;
  firm_name: string | null;
  membership_role: "OWNER" | "PARTNER" | "MANAGER" | "STAFF" | "REVIEWER" | null;
  firm_approval_status: "PENDING" | "ACTIVE" | "REJECTED" | "SUSPENDED" | null;
  registration_status: "PENDING" | "APPROVED" | "REJECTED" | null;
  rejection_reason: string | null;
  submitted_at: string | null;
  access_status: AccessStatus;
};
