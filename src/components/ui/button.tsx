import type { ButtonHTMLAttributes, ReactNode, Ref } from "react";

import Link from "next/link";

type ButtonVariant = "primary" | "secondary" | "ghost" | "light";

export function buttonClassName(variant: ButtonVariant = "primary", small = false) {
  return `button button--${variant}${small ? " button--small" : ""}`;
}

type ButtonProps = ButtonHTMLAttributes<HTMLButtonElement> & {
  variant?: ButtonVariant;
  small?: boolean;
  children: ReactNode;
  ref?: Ref<HTMLButtonElement>;
};

export function Button({ variant = "primary", small = false, className, children, ref, ...props }: ButtonProps) {
  return <button ref={ref} className={[buttonClassName(variant, small), className].filter(Boolean).join(" ")} {...props}>{children}</button>;
}

type ButtonLinkProps = {
  href: string;
  variant?: ButtonVariant;
  small?: boolean;
  children: ReactNode;
  className?: string;
};

export function ButtonLink({ href, variant = "primary", small = false, className, children }: ButtonLinkProps) {
  return <Link className={[buttonClassName(variant, small), className].filter(Boolean).join(" ")} href={href}>{children}</Link>;
}
