"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useEffect, useRef, useState, type ReactNode } from "react";

const navigation = [
  { href: "/app", label: "Overview", icon: "◈" },
  { href: "/app/clients", label: "Clients", icon: "○" },
  { href: "/app/tasks", label: "Tasks", icon: "✓" },
  { href: "/app/compliance", label: "Compliance", icon: "◌" },
  { href: "/app/calendar", label: "Calendar", icon: "□" },
  { href: "/app/leads", label: "Leads", icon: "✦" },
  { href: "/app/billing", label: "Billing", icon: "₹" },
  { href: "/app/team", label: "Team", icon: "♧" },
  { href: "/app/reports", label: "Reports", icon: "▥" },
  { href: "/app/settings", label: "Settings", icon: "⚙" },
];

function Navigation({ pathname, onNavigate }: { pathname: string; onNavigate?: () => void }) {
  return (
    <nav className="workspace-nav" aria-label="Workspace navigation">
      {navigation.map((item) => {
        const active = item.href === "/app" ? pathname === item.href : pathname.startsWith(item.href);
        return <Link className="workspace-nav__link" href={item.href} aria-current={active ? "page" : undefined} onClick={onNavigate} key={item.href}><span className="workspace-nav__icon" aria-hidden="true">{item.icon}</span>{item.label}</Link>;
      })}
    </nav>
  );
}

function Brand() {
  return <Link className="brand" href="/app"><span className="brand-mark">N</span><span>Northstar</span></Link>;
}

export function AppShell({ children }: { children: ReactNode }) {
  const pathname = usePathname();
  const [drawerOpen, setDrawerOpen] = useState(false);
  const toggleRef = useRef<HTMLButtonElement>(null);
  const drawerRef = useRef<HTMLElement>(null);

  useEffect(() => {
    if (!drawerOpen) return;
    const drawer = drawerRef.current;
    const focusable = drawer?.querySelectorAll<HTMLElement>("a[href], button:not([disabled])");
    const firstNavigationLink = drawer?.querySelector<HTMLElement>(".workspace-nav__link");
    (firstNavigationLink ?? focusable?.[0])?.focus();
    const onKeyDown = (event: KeyboardEvent) => {
      if (event.key === "Escape") { setDrawerOpen(false); return; }
      if (event.key !== "Tab" || !focusable?.length) return;
      const first = focusable[0];
      const last = focusable[focusable.length - 1];
      if (event.shiftKey && document.activeElement === first) { event.preventDefault(); last.focus(); }
      else if (!event.shiftKey && document.activeElement === last) { event.preventDefault(); first.focus(); }
    };
    document.addEventListener("keydown", onKeyDown);
    document.body.style.overflow = "hidden";
    return () => { document.removeEventListener("keydown", onKeyDown); document.body.style.overflow = ""; };
  }, [drawerOpen]);

  useEffect(() => {
    if (!drawerOpen) toggleRef.current?.focus();
  }, [drawerOpen]);

  return (
    <div className="workspace-shell">
      <aside className="workspace-sidebar" aria-label="Workspace sidebar">
        <div className="workspace-sidebar__brand"><Brand /></div>
        <p className="workspace-sidebar__label">Workspace</p>
        <Navigation pathname={pathname} />
        <div className="workspace-sidebar__footer"><strong>Preview mode</strong><p>Account connections arrive in a later stage.</p></div>
      </aside>

      <div className="workspace-main">
        <header className="workspace-topbar">
          <button ref={toggleRef} className="mobile-menu-toggle" type="button" aria-label="Open workspace navigation" aria-expanded={drawerOpen} aria-controls="mobile-workspace-navigation" onClick={() => setDrawerOpen(true)}>
            <svg aria-hidden="true" width="20" height="20" viewBox="0 0 20 20" fill="none"><path d="M3 5h14M3 10h14M3 15h14" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" /></svg>
          </button>
          <div className="workspace-topbar__actions">
            <div className="workspace-topbar__placeholder" aria-label="Firm switcher preview"><span className="status-dot status-dot--teal" /><strong>Northstar Demo Firm</strong><span aria-hidden="true">⌄</span></div>
            <div className="workspace-avatar" aria-label="User menu preview">JD</div>
          </div>
        </header>
        <div className="workspace-content">
          <div className="shell-notice" role="status"><span aria-hidden="true">✦</span><div><strong>Workspace preview</strong><p>Navigation and screens are ready. Sign-in, saved data, and firm switching are not connected yet.</p></div></div>
          {children}
        </div>
      </div>

      {drawerOpen && <button className="drawer-backdrop" type="button" aria-label="Close navigation" onClick={() => setDrawerOpen(false)} />}
      {drawerOpen && <aside id="mobile-workspace-navigation" ref={drawerRef} className="drawer" role="dialog" aria-modal="true" aria-label="Mobile workspace navigation"><div className="drawer__header"><Brand /><button className="drawer__close" type="button" aria-label="Close workspace navigation" onClick={() => setDrawerOpen(false)}><span aria-hidden="true">✕</span></button></div><div className="workspace-sidebar__label">Workspace</div><Navigation pathname={pathname} onNavigate={() => setDrawerOpen(false)} /><div className="drawer__footer">Preview mode · no account connected</div></aside>}
    </div>
  );
}
