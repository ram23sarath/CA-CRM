import Link from "next/link";

import { LoginForm } from "@/components/auth/login-form";

export default function LoginPage() {
  return <section className="auth-layout"><aside className="auth-aside"><div><p className="eyebrow eyebrow--light">Welcome back</p><h1>Come back to a calmer day.</h1><p>Sign in with the email and password for your Northstar workspace. There are no OTP or passwordless steps.</p></div></aside><div className="auth-form-wrap"><div className="auth-form"><h1>Sign in</h1><p className="auth-form__intro">Use your work email and password to continue.</p><LoginForm /><p className="auth-form__footer">New to Northstar? <Link href="/signup">Register a firm</Link></p></div></div></section>;
}
