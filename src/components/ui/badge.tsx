import type { ReactNode } from "react";

type BadgeTone = "teal" | "navy" | "amber" | "success" | "danger";

export function Badge({ tone = "teal", children }: { tone?: BadgeTone; children: ReactNode }) {
  return <span className={`badge badge--${tone}`}>{children}</span>;
}
