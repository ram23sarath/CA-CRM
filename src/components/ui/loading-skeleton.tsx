export function LoadingSkeleton({ lines = 3 }: { lines?: number }) {
  return (
    <div className="skeleton-stack skeleton-stack--card" role="status" aria-label="Loading preview">
      <span className="skeleton skeleton--title" />
      {Array.from({ length: lines }, (_, index) => <span className="skeleton skeleton--line" key={index} />)}
      <span className="visually-hidden">Loading preview</span>
    </div>
  );
}
