"use client";

import { Button } from "@/components/ui/button";

export default function WorkspaceError({ reset }: { error: Error & { digest?: string }; reset: () => void }) {
  return <div className="empty-state" role="alert"><div><div className="empty-state__icon" aria-hidden="true">!</div><h2>Something needs another look</h2><p>The workspace preview could not render this screen. No data was changed.</p><Button type="button" onClick={reset}>Try again</Button></div></div>;
}
