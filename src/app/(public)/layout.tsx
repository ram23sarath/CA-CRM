import Link from "next/link";
import type { ReactNode } from "react";

import { ButtonLink } from "@/components/ui/button";

export default function PublicLayout({ children }: { children: ReactNode }) {
  return (
    <div className="public-frame">
      <header className="public-header">
        <Link className="brand" href="/"><span className="brand-mark">N</span><span>Northstar</span></Link>
        <nav className="public-nav" aria-label="Public navigation">
          <Link href="/features">Features</Link>
          <Link href="/pricing">Pricing</Link>
          <Link href="/login">Sign in</Link>
          <ButtonLink href="/signup" small>Get started</ButtonLink>
        </nav>
      </header>
      <main className="public-main">{children}</main>
      <footer className="public-footer"><div className="public-footer__inner page-container"><span>Northstar Practice · Independent clean-room foundation</span><span>Built for thoughtful teams.</span></div></footer>
    </div>
  );
}
