export const CLIENT_DOCUMENT_BUCKET = "firm-documents";
export const CLIENT_DOCUMENT_SIGNED_URL_SECONDS = 300;

export function clientDocumentMaximumBytes() {
  const configured = Number(process.env.CLIENT_DOCUMENT_MAX_BYTES);
  return Number.isSafeInteger(configured) && configured > 0 ? configured : 52_428_800;
}
