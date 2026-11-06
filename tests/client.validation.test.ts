import { describe, expect, it } from "vitest";

import { clientErrorMessage } from "@/features/clients/errors";
import { clientInputSchema, isValidGstin, isValidPan, sanitizeFilename, validateDocument } from "@/features/clients/validation";

describe("client identifiers", () => {
  it("accepts PAN and GSTIN shapes with an Indian state code", () => {
    expect(isValidPan("abcde1234f")).toBe(true);
    expect(isValidGstin("27ABCDE1234F1Z5")).toBe(true);
  });

  it("rejects malformed identifiers and unsupported GST state codes", () => {
    expect(isValidPan("ABCDE123F")).toBe(false);
    expect(isValidGstin("99ABCDE1234F1Z5")).toBe(false);
    expect(isValidGstin("27ABCDE1234F1Z")).toBe(false);
  });

  it("labels identifier validation as format validation", () => {
    const parsed = clientInputSchema.safeParse({ legalName: "A", displayName: "A", entityType: "OTHER", pan: "bad", gstin: "", address: "", relationshipManagerId: null, serviceTags: [], status: "ACTIVE", notes: "", contact: { fullName: "", email: "", phone: "", designation: "" } });
    expect(parsed.success).toBe(false);
    if (!parsed.success) expect(parsed.error.flatten().fieldErrors.pan?.[0]).toMatch(/not government verification/i);
  });
});

describe("client conflict and private upload safeguards", () => {
  it("maps duplicate identifier errors to a friendly conflict message", () => {
    expect(clientErrorMessage({ code: "23505", message: "A client with this PAN already exists in this firm" })).toMatch(/already exists/i);
  });

  it("sanitizes names and rejects oversized or unsupported uploads", () => {
    expect(sanitizeFilename("../../Tax return (final).pdf")).toBe("Tax-return-final-.pdf");
    expect(validateDocument(new File(["x"], "script.exe", { type: "application/octet-stream" }), 10)).toMatch(/not supported/i);
    expect(validateDocument(new File(["12345678901"], "work.pdf", { type: "application/pdf" }), 10)).toMatch(/exceeds/i);
  });
});
