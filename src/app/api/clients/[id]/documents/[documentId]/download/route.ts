import { NextResponse } from "next/server";
import { createClientDocumentDownload } from "@/features/clients/service";

export async function GET(_: Request, { params }: { params: Promise<{ id: string; documentId: string }> }) {
  const { id, documentId } = await params;
  try {
    const signedUrl = await createClientDocumentDownload(id, documentId);
    if (!signedUrl) return NextResponse.json({ error: "Document not found or unavailable." }, { status: 404 });
    return NextResponse.redirect(signedUrl);
  } catch { return NextResponse.json({ error: "Unable to create a private download link." }, { status: 403 }); }
}
