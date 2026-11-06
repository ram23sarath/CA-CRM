import { LoadingSkeleton } from "@/components/ui/loading-skeleton";

export default function WorkspaceLoading() {
  return <div aria-label="Loading workspace" className="skeleton-stack"><span className="skeleton skeleton--title" /><span className="skeleton skeleton--line" /><div className="module-grid"><LoadingSkeleton lines={2} /><LoadingSkeleton lines={2} /><LoadingSkeleton lines={2} /></div></div>;
}
