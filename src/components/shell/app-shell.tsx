"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useEffect, useRef, useState, useSyncExternalStore, type ReactNode } from "react";

type NavigationIconName = "overview" | "clients" | "tasks" | "compliance" | "calendar" | "leads" | "billing" | "team" | "reports" | "settings";
const themeStorageKey = "northstar-theme";

function subscribeToTheme(onChange: () => void) {
  window.addEventListener("storage", onChange);
  window.addEventListener("northstar-theme-change", onChange);
  return () => {
    window.removeEventListener("storage", onChange);
    window.removeEventListener("northstar-theme-change", onChange);
  };
}

function getThemeSnapshot() {
  return window.localStorage.getItem(themeStorageKey) === "dark";
}

function getServerThemeSnapshot() {
  return false;
}

const navigation: { href: string; label: string; icon: NavigationIconName }[] = [
  { href: "/app", label: "Overview", icon: "overview" },
  { href: "/app/clients", label: "Clients", icon: "clients" },
  { href: "/app/tasks", label: "Tasks", icon: "tasks" },
  { href: "/app/compliance", label: "Compliance", icon: "compliance" },
  { href: "/app/calendar", label: "Calendar", icon: "calendar" },
  { href: "/app/leads", label: "Leads", icon: "leads" },
  { href: "/app/billing", label: "Billing", icon: "billing" },
  { href: "/app/team", label: "Team", icon: "team" },
  { href: "/app/reports", label: "Reports", icon: "reports" },
  { href: "/app/settings", label: "Settings", icon: "settings" },
];

function NavigationIcon({ name }: { name: NavigationIconName }) {
  const common = { fill: "none", stroke: "currentColor", strokeLinecap: "round" as const, strokeLinejoin: "round" as const, strokeWidth: 1.7 };
  const paths = {
    overview: <><rect x="3.5" y="3.5" width="5.5" height="5.5" rx="1" {...common} /><rect x="11" y="3.5" width="5.5" height="5.5" rx="1" {...common} /><rect x="3.5" y="11" width="5.5" height="5.5" rx="1" {...common} /><rect x="11" y="11" width="5.5" height="5.5" rx="1" {...common} /></>,
    clients: <><circle cx="8" cy="7" r="2.5" {...common} /><path d="M3.5 16c.4-2.5 2-3.8 4.5-3.8s4.1 1.3 4.5 3.8M13 5.2c1.7.2 2.8 1.3 2.8 3M14 12.4c1.5.4 2.3 1.5 2.5 3.1" {...common} /></>,
    tasks: <><path d="m3.5 9.5 3.2 3.2 6.8-7" {...common} /><path d="M3.5 16.5h13" {...common} /></>,
    compliance: <><circle cx="10" cy="10" r="6.5" {...common} /><path d="M10 6v4l2.5 1.5" {...common} /></>,
    calendar: <><rect x="3.5" y="4.5" width="13" height="12" rx="1.5" {...common} /><path d="M6.5 3v3M13.5 3v3M3.5 8h13" {...common} /></>,
    leads: <><path d="m10 3 1.8 5.2L17 10l-5.2 1.8L10 17l-1.8-5.2L3 10l5.2-1.8L10 3Z" {...common} /></>,
    billing: <><path d="M12.8 5.5H7.2a2.2 2.2 0 0 0 0 4.4h5.1a2.2 2.2 0 0 1 0 4.4H6.5M10 3.5v13" {...common} /></>,
    team: <><circle cx="10" cy="6" r="2.3" {...common} /><path d="M5.2 15.8c.3-2.4 2-3.8 4.8-3.8s4.5 1.4 4.8 3.8M4.2 9.5c-1.4.3-2.2 1.2-2.4 2.7M15.8 9.5c1.4.3 2.2 1.2 2.4 2.7" {...common} /></>,
    reports: <><path d="M4 16.5V9.8M8 16.5V6.2M12 16.5V3.5M16 16.5v-5.1" {...common} /></>,
    settings: <><circle cx="10" cy="10" r="2.5" {...common} /><path d="m16 10 1.2-1-.9-1.6-1.5.4a5.8 5.8 0 0 0-1.3-.8l-.2-1.5h-1.9l-.2 1.5c-.5.2-.9.4-1.3.8l-1.5-.4-.9 1.6 1.2 1c0 .2-.1.5-.1.8s0 .5.1.8l-1.2 1 .9 1.6 1.5-.4c.4.3.8.6 1.3.8l.2 1.5h1.9l.2-1.5c.5-.2.9-.4 1.3-.8l1.5.4.9-1.6-1.2-1c0-.2.1-.5.1-.8s0-.5-.1-.8Z" {...common} /></>,
  };
  return <svg className="workspace-nav__svg" aria-hidden="true" viewBox="0 0 20 20">{paths[name]}</svg>;
}

function Navigation({ pathname, onNavigate }: { pathname: string; onNavigate?: () => void }) {
  return (
    <nav className="workspace-nav" aria-label="Workspace navigation">
      {navigation.map((item) => {
        const active = item.href === "/app" ? pathname === item.href : pathname.startsWith(item.href);
        return <Link className="workspace-nav__link" href={item.href} aria-current={active ? "page" : undefined} onClick={onNavigate} key={item.href}><span className="workspace-nav__icon"><NavigationIcon name={item.icon} /></span>{item.label}</Link>;
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
  const darkMode = useSyncExternalStore(subscribeToTheme, getThemeSnapshot, getServerThemeSnapshot);
  const toggleRef = useRef<HTMLButtonElement>(null);
  const drawerRef = useRef<HTMLElement>(null);

  function toggleDarkMode() {
    window.localStorage.setItem(themeStorageKey, darkMode ? "light" : "dark");
    window.dispatchEvent(new Event("northstar-theme-change"));
  }

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
    <div className="workspace-shell" data-theme={darkMode ? "dark" : "light"}>
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
            <button className="theme-toggle" type="button" aria-label={darkMode ? "Switch to light mode" : "Switch to dark mode"} aria-pressed={darkMode} onClick={toggleDarkMode}>
              <svg aria-hidden="true" viewBox="0 0 20 20">
                {darkMode ? <path d="M16.5 12.5A6.8 6.8 0 0 1 7.5 3.5a6.8 6.8 0 1 0 9 9Z" /> : <><circle cx="10" cy="10" r="3.2" /><path d="M10 2v1.5M10 16.5V18M2 10h1.5M16.5 10H18M4.3 4.3l1 1M14.7 14.7l1 1M15.7 4.3l-1 1M5.3 14.7l-1 1" /></>}
              </svg>
              <span>{darkMode ? "Light" : "Dark"}</span>
            </button>
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
