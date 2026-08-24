"use client";

/**
 * Skeleton placeholder grid shown while video data is loading.
 */

export function VideoGridSkeleton({ count = 12 }: { count?: number }) {
  return (
    <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5">
      {Array.from({ length: count }).map((_, i) => (
        <div
          key={i}
          className="overflow-hidden rounded-xl border border-border bg-card"
        >
          <div className="aspect-video w-full skeleton-shimmer" />
          <div className="space-y-2 p-3">
            <div className="h-4 w-full rounded skeleton-shimmer" />
            <div className="h-3 w-2/3 rounded skeleton-shimmer" />
            <div className="flex items-center gap-2 pt-1">
              <div className="h-6 w-6 rounded-full skeleton-shimmer" />
              <div className="h-3 w-1/3 rounded skeleton-shimmer" />
            </div>
          </div>
        </div>
      ))}
    </div>
  );
}
