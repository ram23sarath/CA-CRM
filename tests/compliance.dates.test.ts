import { describe, expect, it } from "vitest";
import { complianceDisplayStatus, isExpiringSoon, todayInTimeZone } from "@/features/compliance/dates";

describe("compliance date semantics", () => {
  it("uses the firm local date at the IST midnight boundary", () => {
    expect(todayInTimeZone("Asia/Kolkata", new Date("2026-04-30T18:29:59.999Z"))).toBe("2026-04-30");
    expect(todayInTimeZone("Asia/Kolkata", new Date("2026-04-30T18:30:00.000Z"))).toBe("2026-05-01");
  });

  it("derives due and overdue without changing the workflow state", () => {
    expect(complianceDisplayStatus("2026-05-01", "UPCOMING", "2026-05-01")).toBe("DUE");
    expect(complianceDisplayStatus("2026-04-30", "IN_PROGRESS", "2026-05-01")).toBe("OVERDUE");
    expect(complianceDisplayStatus("2026-04-30", "FILED", "2026-05-01")).toBe("FILED");
    expect(complianceDisplayStatus("2026-04-30", "CANCELLED", "2026-05-01")).toBe("CANCELLED");
  });

  it("only marks active records in the configured 30-day reminder window", () => {
    expect(isExpiringSoon("2026-05-30", "ACTIVE", "2026-05-01")).toBe(true);
    expect(isExpiringSoon("2026-06-01", "ACTIVE", "2026-05-01")).toBe(false);
    expect(isExpiringSoon("2026-05-30", "RENEWED", "2026-05-01")).toBe(false);
  });
});
