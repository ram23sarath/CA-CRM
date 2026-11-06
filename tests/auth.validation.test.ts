import { describe, expect, it } from "vitest";

import { loginSchema, signupSchema } from "@/lib/auth/validation";
import { hasSameOrigin } from "@/lib/auth/csrf";

describe("authentication validation", () => {
  it("accepts an Indian mobile number and strong matching password", () => {
    const result = signupSchema.safeParse({ firmName: "Northstar Demo", fullName: "Asha Mehta", email: "asha@example.test", mobileNumber: "+919876543210", password: "northstar9", confirmPassword: "northstar9" });
    expect(result.success).toBe(true);
  });

  it("rejects weak, mismatched, or invalid registration values", () => {
    const result = signupSchema.safeParse({ firmName: "", fullName: "", email: "not-an-email", mobileNumber: "9876543210", password: "short", confirmPassword: "different" });
    expect(result.success).toBe(false);
    if (!result.success) expect(Object.keys(result.error.flatten().fieldErrors)).toEqual(expect.arrayContaining(["firmName", "fullName", "email", "mobileNumber", "password", "confirmPassword"]));
  });

  it("requires both email and password for login", () => {
    expect(loginSchema.safeParse({ email: "", password: "" }).success).toBe(false);
    expect(loginSchema.safeParse({ email: "owner@example.test", password: "secret" }).success).toBe(true);
  });
});

describe("same-origin protection", () => {
  it("accepts only an explicit request origin matching the target", () => {
    expect(hasSameOrigin(new Request("https://app.example.test/api/auth/login", { headers: { origin: "https://app.example.test" } }))).toBe(true);
    expect(hasSameOrigin(new Request("https://app.example.test/api/auth/login", { headers: { origin: "https://attacker.example.test" } }))).toBe(false);
    expect(hasSameOrigin(new Request("https://app.example.test/api/auth/login"))).toBe(false);
  });
});
