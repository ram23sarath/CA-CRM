export type ComplianceDisplayStatus = "UPCOMING" | "DUE" | "OVERDUE" | "IN_PROGRESS" | "READY_FOR_REVIEW" | "FILED" | "CANCELLED";

export function todayInTimeZone(timeZone = "Asia/Kolkata", now = new Date()): string {
  const parts = new Intl.DateTimeFormat("en-CA", { timeZone, year: "numeric", month: "2-digit", day: "2-digit" }).formatToParts(now);
  const values = Object.fromEntries(parts.filter((part) => part.type !== "literal").map((part) => [part.type, part.value]));
  return `${values.year}-${values.month}-${values.day}`;
}

export function addDays(date: string, days: number): string {
  const value = new Date(`${date}T12:00:00Z`);
  value.setUTCDate(value.getUTCDate() + days);
  return value.toISOString().slice(0, 10);
}

export function complianceDisplayStatus(dueDate: string, workflowStatus: string, today: string): ComplianceDisplayStatus {
  if (workflowStatus === "FILED") return "FILED";
  if (workflowStatus === "CANCELLED") return "CANCELLED";
  if (dueDate < today) return "OVERDUE";
  if (dueDate === today) return "DUE";
  if (workflowStatus === "IN_PROGRESS" || workflowStatus === "READY_FOR_REVIEW") return workflowStatus;
  return "UPCOMING";
}

export function isExpiringSoon(expiryDate: string, status: string, today: string, windowDays = 30): boolean {
  return status === "ACTIVE" && expiryDate >= today && expiryDate <= addDays(today, windowDays);
}
