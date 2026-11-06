import { describe, expect, it } from "vitest";
import { isStaleFollowUp, leadToday, proposalIsExpired } from "@/features/leads/dates";
import { canAdvanceLeadStage, leadInputSchema, proposalSchema } from "@/features/leads/validation";

describe("lead and proposal workflow", () => {
  it("uses the firm-local date for stale follow-ups and proposal validity", () => {
    expect(leadToday("Asia/Kolkata", new Date("2026-05-01T18:29:59Z"))).toBe("2026-05-01");
    expect(leadToday("Asia/Kolkata", new Date("2026-05-01T18:30:00Z"))).toBe("2026-05-02");
    expect(isStaleFollowUp("2026-05-01", "2026-05-02", "OPEN")).toBe(true);
    expect(isStaleFollowUp("2026-05-01", "2026-05-02", "DONE")).toBe(false);
    expect(proposalIsExpired("2026-05-01", "2026-05-02")).toBe(true);
    expect(proposalIsExpired("2026-05-02", "2026-05-02")).toBe(false);
  });

  it("rejects malformed lead contact data", () => {
    expect(leadInputSchema.safeParse({ name: "Prospect", companyName: "", email: "not-an-email", mobile: "", source: "REFERRAL", score: null, ownerId: null, nextFollowUpDate: null, notes: "" }).success).toBe(false);
    expect(leadInputSchema.safeParse({ name: "Prospect", companyName: "Acme", email: "person@example.test", mobile: "+91 98765 43210", source: "REFERRAL", score: 80, ownerId: null, nextFollowUpDate: "2026-05-10", notes: "Context" }).success).toBe(true);
  });

  it("requires non-negative minor-unit proposal amounts and an ISO currency", () => {
    const base = { leadId: "11111111-1111-4111-8111-111111111111", title: "Proposal", serviceScope: "Scope", validityDate: "2026-05-10", feeMinor: 125000, taxEstimateMinor: 22500, currency: "INR", notes: "" };
    expect(proposalSchema.safeParse(base).success).toBe(true);
    expect(proposalSchema.safeParse({ ...base, feeMinor: -1 }).success).toBe(false);
    expect(proposalSchema.safeParse({ ...base, currency: "RUPEES" }).success).toBe(false);
  });

  it("keeps the public pipeline order explicit", () => {
    expect(canAdvanceLeadStage("LEAD", "FOLLOW_UP")).toBe(true);
    expect(canAdvanceLeadStage("FOLLOW_UP", "QUOTATION")).toBe(true);
    expect(canAdvanceLeadStage("QUOTATION", "PROPOSAL")).toBe(true);
    expect(canAdvanceLeadStage("PROPOSAL", "WON")).toBe(true);
    expect(canAdvanceLeadStage("WON", "CLIENT")).toBe(true);
    expect(canAdvanceLeadStage("LEAD", "PROPOSAL")).toBe(false);
  });
});
