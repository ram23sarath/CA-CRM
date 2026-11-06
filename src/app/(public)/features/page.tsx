import { Badge } from "@/components/ui/badge";

const featureGroups = [
  { title: "Client context", description: "Keep the relationship, the work, and the next conversation close enough to understand at a glance.", badge: "Relationships" },
  { title: "Team rhythm", description: "Create a shared language for assignments, review, and the small handoffs that make quality repeatable.", badge: "Operations" },
  { title: "Recurring work", description: "Give important cycles a dependable home with transparent status and room for human review.", badge: "Compliance" },
  { title: "Thoughtful signals", description: "Surface what needs attention without turning every deadline into noise or an opaque automation.", badge: "Reminders" },
  { title: "Commercial clarity", description: "Hold the context behind billing conversations so the commercial picture supports the relationship.", badge: "Billing" },
  { title: "A firm-aware foundation", description: "Build towards clear boundaries, auditability, and policy-aware access from the beginning.", badge: "Trust" },
];

export default function FeaturesPage() {
  return <section className="public-page page-container"><div className="public-page__intro"><p className="eyebrow">Made for the work between deadlines</p><h1>One place for the practice you are building.</h1><p>Northstar is an independent product foundation for professional practices that want less searching, more context, and a better daily rhythm.</p></div><div className="card-grid card-grid--three">{featureGroups.map((feature) => <article className="capability-card capability-card--teal" key={feature.title}><Badge tone="navy">{feature.badge}</Badge><h3>{feature.title}</h3><p>{feature.description}</p></article>)}</div></section>;
}
