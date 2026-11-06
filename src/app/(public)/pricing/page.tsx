import { ButtonLink } from "@/components/ui/button";

const plans = [
  { name: "Starting point", detail: "A clear foundation for a small practice finding its shared rhythm.", items: ["Client context", "Team workspaces", "Reviewable routines"] },
  { name: "Growing practice", detail: "A connected shape for firms balancing more relationships and recurring work.", items: ["Everything in Starting point", "Recurring work views", "Policy-aware roles"] },
  { name: "Thoughtful scale", detail: "A conversation about the operating model your team wants to protect.", items: ["A tailored workspace", "Operational perspectives", "Configurable adapters"] },
];

export default function PricingPage() {
  return <section className="public-page page-container"><div className="public-page__intro"><p className="eyebrow">Pricing preview</p><h1>Choose the rhythm that fits.</h1><p>These are directional packages for an independent product in progress. No plan, payment, or trial is active in this preview.</p></div><div className="card-grid card-grid--three">{plans.map((plan, index) => <article className={`module-card ${index === 1 ? "capability-card--teal" : ""}`} key={plan.name}><p className="eyebrow">{index === 1 ? "Most connected" : "Northstar"}</p><h2>{plan.name}</h2><p>{plan.detail}</p><ul className="plan-list">{plan.items.map((item) => <li key={item}><span aria-hidden="true">✓</span>{item}</li>)}</ul>{index === 2 && <ButtonLink href="/signup" variant="secondary" small>Start a conversation</ButtonLink>}</article>)}</div></section>;
}
