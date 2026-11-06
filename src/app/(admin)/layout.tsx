import Link from "next/link";
import type { ReactNode } from "react";

import { SignOutButton } from "@/components/auth/sign-out-button";

export default function AdminLayout({ children }: { children: ReactNode }) {
  return <div className="public-frame"><header className="public-header"><Link className="brand" href="/admin/approvals"><span className="brand-mark">N</span><span>Northstar Admin</span></Link><SignOutButton small /></header><main className="public-main">{children}</main></div>;
}
