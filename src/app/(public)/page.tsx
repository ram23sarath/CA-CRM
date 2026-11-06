import Link from "next/link";

import { Badge } from "@/components/ui/badge";
import { ButtonLink } from "@/components/ui/button";

const capabilities = [
  { label: "Clients", title: "Every relationship, easy to find.", description: "Keep context, contacts, and next steps together so every handoff feels intentional.", accent: "teal" },
  { label: "Work", title: "A clear view of the work that matters.", description: "Give teams a shared rhythm for assignments, reviews, and recurring obligations.", accent: "navy" },
  { label: "Signals", title: "Fewer surprises at month end.", description: "See what is moving, what needs attention, and where a thoughtful reminder can help.", accent: "amber" },
] as const;

export default function HomePage() {
  return (
    <>
      <section className="public-hero page-container" aria-labelledby="hero-title">
        <div className="public-hero__copy">
          <Badge tone="teal">Independent practice workspace</Badge>
          <h1 id="hero-title" className="heading-xl">Make the work feel lighter.</h1>
          <p className="lead">Northstar brings client context, team momentum, and recurring practice work into one calm place—so your firm can focus on the people behind the deadlines.</p>
          <div className="button-row"><ButtonLink href="/signup">Explore the workspace</ButtonLink><ButtonLink href="/features" variant="secondary">See how it works</ButtonLink></div>
          <p className="microcopy">A clean-room, independent product foundation. No live accounts are connected yet.</p>
        </div>
        <div className="hero-visual" aria-label="Illustration of a connected practice dashboard" role="img"><div className="hero-visual__glow" /><div className="hero-visual__card hero-visual__card--main"><div className="hero-visual__card-topline"><span className="status-dot status-dot--teal" /> Today at a glance</div><div className="hero-visual__metric">12 <span>open loops</span></div><div className="hero-visual__bars"><i /><i /><i /><i /></div></div><div className="hero-visual__card hero-visual__card--float"><span className="status-dot status-dot--amber" /> Review window<strong>3 items need a second look</strong></div></div>
      </section>

      <section className="section page-container" aria-labelledby="capabilities-title"><div className="section-heading"><div><p className="eyebrow">One connected rhythm</p><h2 id="capabilities-title" className="heading-lg">The details that keep a practice moving.</h2></div><Link className="text-link" href="/features">View all capabilities <span aria-hidden="true">→</span></Link></div><div className="card-grid card-grid--three">{capabilities.map((capability) => <article className={`capability-card capability-card--${capability.accent}`} key={capability.label}><span className="card-kicker">{capability.label}</span><h3>{capability.title}</h3><p>{capability.description}</p></article>)}</div></section>

      <section className="callout page-container" aria-labelledby="callout-title"><div><p className="eyebrow eyebrow--light">Start with a better view</p><h2 id="callout-title">Your practice has a north star.</h2><p>Use this preview shell to explore the future shape of your workspace while the connected services are being built.</p></div><ButtonLink href="/app" variant="light">Open workspace preview</ButtonLink></section>
    </>
  );
}
