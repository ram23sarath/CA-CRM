export function leadToday(timeZone = "Asia/Kolkata", now = new Date()): string {
  const parts = new Intl.DateTimeFormat("en-CA", { timeZone, year: "numeric", month: "2-digit", day: "2-digit" }).formatToParts(now);
  const values = Object.fromEntries(parts.filter((part) => part.type !== "literal").map((part) => [part.type, part.value]));
  return `${values.year}-${values.month}-${values.day}`;
}

export function proposalIsExpired(validityDate: string, today: string): boolean { return validityDate < today; }

export function isStaleFollowUp(nextFollowUpDate: string | null, today: string, status: string): boolean { return status === "OPEN" && Boolean(nextFollowUpDate && nextFollowUpDate < today); }
