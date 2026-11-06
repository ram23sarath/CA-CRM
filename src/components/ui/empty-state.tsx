import type { ReactNode } from "react";

export function EmptyState({ title, description, action, icon = "·" }: { title: string; description: string; action?: ReactNode; icon?: ReactNode }) {
  return (
    <section className="empty-state" aria-label={title}>
      <div>
        <div className="empty-state__icon" aria-hidden="true">{icon}</div>
        <h2>{title}</h2>
        <p>{description}</p>
        {action}
      </div>
    </section>
  );
}
