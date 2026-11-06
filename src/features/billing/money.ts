export const MONEY_SCALE = 2;

/** Billing uses decimal arithmetic and half-up rounding at the paise boundary. */
export function roundMoney(value: number): number {
  return Math.round((value + Number.EPSILON) * 100) / 100;
}

export function lineAmounts(quantity: number, rate: number, taxRate: number) {
  const subtotal = roundMoney(quantity * rate);
  const tax = roundMoney((subtotal * taxRate) / 100);
  return { subtotal, tax, total: roundMoney(subtotal + tax) };
}

export function outstandingBalance(total: number, payments: Array<{ amount: number; entryType: "PAYMENT" | "REVERSAL" | "ADJUSTMENT" }>) {
  return roundMoney(total - payments.reduce((sum, entry) => sum + (entry.entryType === "PAYMENT" ? entry.amount : -entry.amount), 0));
}
