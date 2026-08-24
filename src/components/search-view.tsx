"use client";

/**
 * Search view.
 *
 * Delegates to the /api/search endpoint and renders the result list
 * using the shared VideoCard. The search input is pre-populated from
 * the URL query string (so the page is shareable / bookmarkable).
 *
 * When `q` is empty, falls back to a "热门搜索词" prompt page so the
 * user can pick a quick start.
 */

import { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { VideoCard } from "@/components/video-card";
import { VideoGridSkeleton } from "@/components/video-grid-skeleton";
import {
  SearchIcon,
  FireIcon,
  ArrowLeftIcon,
} from "@/components/icons";
import { api, type VideoListItem } from "@/lib/api";
import { useRoute } from "@/lib/route";

const HOT_SEARCHES = [
  "音乐",
  "动漫",
  "教程",
  "MV",
  "转载",
  "搞笑",
  "游戏",
  "科技",
];

interface SearchViewProps {
  q: string;
}

export function SearchView({ q }: SearchViewProps) {
  const { goHome, goSearch } = useRoute();
  const [input, setInput] = useState(q);

  // React 19 "storing information from previous renders" pattern:
  // when the `q` prop changes, synchronise `input` to match. This
  // is the recommended alternative to using an effect with setState.
  // See: https://react.dev/reference/react/useState#storing-information-from-previous-renders
  const [prevQ, setPrevQ] = useState(q);
  if (q !== prevQ) {
    setPrevQ(q);
    setInput(q);
  }

  // Data fetching via TanStack Query - this is the lint-compliant
  // way to manage server state without manually calling setState
  // inside effects.
  const { data, isLoading, error } = useQuery<{
    videos: VideoListItem[];
  }>({
    queryKey: ["search", q],
    queryFn: () => api.search(q, { limit: 60 }),
    enabled: !!q.trim(),
    staleTime: 30_000,
  });

  const results = data?.videos ?? [];
  const searched = !!q.trim() && (data !== undefined || isLoading);

  const submit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!input.trim()) return;
    goSearch(input.trim());
  };

  return (
    <div className="space-y-5">
      <button
        onClick={goHome}
        className="inline-flex items-center gap-1.5 text-sm text-muted-foreground transition-colors hover:text-foreground"
      >
        <ArrowLeftIcon size={16} />
        返回首页
      </button>

      <form onSubmit={submit} className="flex items-center gap-2">
        <div className="relative flex-1">
          <SearchIcon
            size={18}
            className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-muted-foreground"
          />
          <Input
            value={input}
            onChange={(e) => setInput(e.target.value)}
            placeholder="搜索视频..."
            className="h-12 pl-10 text-base"
            autoFocus
          />
        </div>
        <Button type="submit" size="lg" className="h-12 px-6">
          搜索
        </Button>
      </form>

      {!q.trim() && (
        <div className="rounded-xl border border-border bg-card p-6">
          <h2 className="flex items-center gap-2 text-sm font-semibold">
            <FireIcon size={16} className="text-primary" />
            热门搜索
          </h2>
          <div className="mt-3 flex flex-wrap gap-2">
            {HOT_SEARCHES.map((s) => (
              <button
                key={s}
                onClick={() => goSearch(s)}
                className="rounded-full bg-secondary px-4 py-1.5 text-sm text-secondary-foreground transition-colors hover:bg-accent hover:text-accent-foreground"
              >
                {s}
              </button>
            ))}
          </div>
        </div>
      )}

      {q.trim() && (
        <div>
          <p className="text-sm text-muted-foreground">
            搜索 “<span className="font-medium text-foreground">{q}</span>” 的结果{" "}
            {!isLoading && !error && (
              <span className="text-xs">· 共 {results.length} 条</span>
            )}
          </p>
        </div>
      )}

      {error ? (
        <div className="rounded-xl border border-destructive/30 bg-destructive/5 p-6 text-center">
          <p className="text-sm text-destructive">
            {error instanceof Error ? error.message : "搜索失败"}
          </p>
        </div>
      ) : isLoading ? (
        <VideoGridSkeleton count={10} />
      ) : searched && results.length === 0 ? (
        <div className="rounded-xl border border-border bg-card p-12 text-center">
          <p className="text-sm text-muted-foreground">
            没有找到相关视频，换个关键词试试
          </p>
        </div>
      ) : (
        results.length > 0 && (
          <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5">
            {results.map((v, i) => (
              <VideoCard key={v.id} video={v} priority={i < 10} />
            ))}
          </div>
        )
      )}
    </div>
  );
}
