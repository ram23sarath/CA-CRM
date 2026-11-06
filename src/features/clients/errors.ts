export function clientErrorMessage(error: { code?: string; message?: string } | null | undefined) {
  const message = error?.message ?? "Unable to save the client. Please try again.";
  if (error?.code === "23505" || /already exists/i.test(message)) return message;
  if (error?.code === "40001") return "This client was changed elsewhere. Refresh the page and review the latest version.";
  if (error?.code === "42501") return "Only an owner, partner, or manager can change PAN or GSTIN.";
  if (error?.code === "P0002") return "This client is unavailable in the current firm.";
  return message;
}
