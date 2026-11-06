import { fireEvent, render, screen, within } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";

import { AppShell } from "@/components/shell/app-shell";
import { EmptyState } from "@/components/ui/empty-state";
import { LoadingSkeleton } from "@/components/ui/loading-skeleton";

let pathname = "/app";

vi.mock("next/navigation", () => ({ usePathname: () => pathname }));
vi.mock("next/link", () => ({ default: ({ href, children, ...props }: { href: string; children: React.ReactNode }) => <a href={href} {...props}>{children}</a> }));

describe("workspace shell", () => {
  beforeEach(() => { pathname = "/app"; });

  it("opens the mobile drawer, focuses its first link, and closes on Escape", () => {
    render(<AppShell><p>Workspace content</p></AppShell>);
    const toggle = screen.getByRole("button", { name: "Open workspace navigation" });

    fireEvent.click(toggle);
    const dialog = screen.getByRole("dialog", { name: "Mobile workspace navigation" });
    expect(dialog).toBeVisible();
    expect(within(dialog).getByRole("link", { name: "Overview" })).toHaveFocus();

    fireEvent.keyDown(document, { key: "Escape" });
    expect(screen.queryByRole("dialog", { name: "Mobile workspace navigation" })).not.toBeInTheDocument();
    expect(toggle).toHaveFocus();
  });
});

describe("shared UI states", () => {
  it("renders an accessible empty state", () => {
    render(<EmptyState title="No clients yet" description="Connect a workspace to begin." />);
    expect(screen.getByRole("region", { name: "No clients yet" })).toBeVisible();
    expect(screen.getByText("Connect a workspace to begin.")).toBeVisible();
  });

  it("announces a loading preview without real data", () => {
    render(<LoadingSkeleton lines={2} />);
    expect(screen.getByRole("status", { name: "Loading preview" })).toBeVisible();
    expect(screen.getByText("Loading preview")).toHaveClass("visually-hidden");
  });
});
