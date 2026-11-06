import Link from "next/link";

import { SignupForm } from "@/components/auth/signup-form";

export default function SignupPage() {
  return <section className="auth-layout"><aside className="auth-aside"><div><p className="eyebrow eyebrow--light">Make room for good work</p><h1>Start with the shape of your practice.</h1><p>Register with email and password. Every new firm stays pending until a platform administrator reviews it.</p></div></aside><div className="auth-form-wrap"><div className="auth-form"><h1>Register a firm</h1><p className="auth-form__intro">Tell us who you are and which firm you are bringing into the workspace.</p><SignupForm /><p className="auth-form__footer">Already registered? <Link href="/login">Sign in</Link></p></div></div></section>;
}
