import { describe, expect, it } from "vitest";
import { lineAmounts, outstandingBalance, roundMoney } from "@/features/billing/money";

describe("billing money", () => {
  it("rounds half-up line subtotal and tax", () => expect(lineAmounts(3, 10.005, 18)).toEqual({ subtotal: 30.02, tax: 5.4, total: 35.42 }));
  it("derives balance from append-only ledger entries", () => expect(outstandingBalance(1000, [{ amount: 250, entryType: "PAYMENT" }, { amount: 50, entryType: "REVERSAL" }, { amount: 100, entryType: "PAYMENT" }])).toBe(700));
  it("rounds negative floating noise safely", () => expect(roundMoney(0.1 + 0.2)).toBe(0.3));
});
