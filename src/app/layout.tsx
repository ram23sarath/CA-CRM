import type { Metadata } from "next";
import type { ReactNode } from "react";

import "./globals.css";

export const metadata: Metadata = {
  title: {
    default: "Northstar Practice",
    template: "%s · Northstar Practice",
  },
  description: "A calm, connected workspace for modern professional practices.",
};

export default function RootLayout({ children }: Readonly<{ children: ReactNode }>) {
  return (
    <html lang="en">
      <body className="site-body">{children}</body>
    </html>
  );
}
