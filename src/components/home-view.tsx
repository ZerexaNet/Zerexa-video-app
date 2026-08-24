"use client";

/**
 * Home view.
 *
 * Top-level landing page. Combines:
 *   - Announcement bar
 *   - Hero banner with sort selector (推荐 / 最新 / 热门)
 *   - Category chip row
 *   - Video grid (lazy-loaded, infinite-scroll)
 *
 * Data is fetched directly from the Zerexa Video public API; the
 * grid uses an IntersectionObserver sentinel to load the next page.
 */

import { useCallback, useEffect, useRef, useState } from "react";
import { Button } from "@/components/ui/button";
import { AnnouncementBar } from "@/components/announcement-bar";
import { HomeHero } from "@/components/home-hero";
import { VideoCard } from "@/components/video-card";
import { VideoGridSkeleton } from "@/components/video-grid-skeleton";
import { api, type VideoListItem } from "@/lib/api";
import { useRoute } from "@/lib/route";

type Sort = "recommended" | "latest" | "hot";

export const CATEGORIES: { root: string; label: string }[] = [
  { root: "Music", label: "音乐" },
  { root: "Gaming", label: "游戏" },
  { root: "Tech", label: "科技" },
  { root: "Life", label: "生活" },
  { root: "Entertainment", label: "娱乐" },
  { root: "Sports", label: "体育" },
  { root: "Food", label: "美食" },
  { root: "Travel", label: "旅行" },
  { root: "Fashion", label: "时尚" },
  { root: "Education", label: "教育" },
  { root: "News", label: "资讯" },
  { root: "Film", label: "影视" },
  { root: "Auto", label: "汽车" },
  { root: "Art", label: "艺术" },
  { root: "Charity", label: "公益" },
];

export function HomeView() {
  const { goCategory } = useRoute();
  const [sort, setSort] = useState<Sort>("recommended");
  const [videos, setVideos] = useState<VideoListItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [loadingMore, setLoadingMore] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [activeCat, setActiveCat] = useState<string | null>(null);
  const [hasMore, setHasMore] = useState(true);
  const sentinelRef = useRef<HTMLDivElement>(null);

  const loadFirst = useCallback(
    async (s: Sort, cat: string | null) => {
      setLoading(true);
      setError(null);
      setHasMore(true);
      try {
        const params: Parameters<typeof api.listVideos>[0] = {
          limit: 24,
          offset: 0,
        };
        if (cat) params.category = cat;
        if (s === "latest") params.sort = "latest";
        if (s === "hot") params.sort = "hot";
        const data = await api.listVideos(params);
        setVideos(data);
        if (data.length < 24) setHasMore(false);
      } catch (e) {
        setError(e instanceof Error ? e.message : "加载失败");
        setVideos([]);
      } finally {
        setLoading(false);
      }
    },
    [],
  );

  useEffect(() => {
    loadFirst(sort, activeCat);
  }, [sort, activeCat, loadFirst]);

  const loadMore = useCallback(async () => {
    if (loadingMore || !hasMore) return;
    setLoadingMore(true);
    try {
      const params: Parameters<typeof api.listVideos>[0] = {
        limit: 24,
        offset: videos.length,
      };
      if (activeCat) params.category = activeCat;
      if (sort === "latest") params.sort = "latest";
      if (sort === "hot") params.sort = "hot";
      const data = await api.listVideos(params);
      if (data.length === 0) {
        setHasMore(false);
      } else {
        setVideos((prev) => [...prev, ...data]);
        if (data.length < 24) setHasMore(false);
      }
    } catch {
      setHasMore(false);
    } finally {
      setLoadingMore(false);
    }
  }, [videos.length, loadingMore, hasMore, activeCat, sort]);

  // Infinite scroll observer
  useEffect(() => {
    const el = sentinelRef.current;
    if (!el) return;
    const ob = new IntersectionObserver(
      (entries) => {
        for (const entry of entries) {
          if (entry.isIntersecting) loadMore();
        }
      },
      { rootMargin: "200px" },
    );
    ob.observe(el);
    return () => ob.disconnect();
  }, [loadMore]);

  return (
    <div className="space-y-6">
      <AnnouncementBar />
      <HomeHero onPickSort={setSort} activeSort={sort} />

      {/* Category chips */}
      <div className="-mx-1 flex items-center gap-2 overflow-x-auto px-1 pb-1 scrollbar-thin">
        <button
          onClick={() => setActiveCat(null)}
          className={`shrink-0 rounded-full px-4 py-1.5 text-sm transition-colors ${
            activeCat === null
              ? "bg-primary text-primary-foreground"
              : "bg-secondary text-secondary-foreground hover:bg-accent"
          }`}
        >
          全部
        </button>
        {CATEGORIES.map((c) => (
          <button
            key={c.root}
            onClick={() => {
              setActiveCat(c.root);
              goCategory(c.root);
            }}
            className={`shrink-0 rounded-full px-4 py-1.5 text-sm transition-colors ${
              activeCat === c.root
                ? "bg-primary text-primary-foreground"
                : "bg-secondary text-secondary-foreground hover:bg-accent"
            }`}
          >
            {c.label}
          </button>
        ))}
      </div>

      {/* Sort summary */}
      <div className="flex items-center justify-between">
        <h2 className="text-lg font-bold">
          {activeCat
            ? `${CATEGORIES.find((c) => c.root === activeCat)?.label ?? activeCat} 视频`
            : sort === "recommended"
            ? "为你推荐"
            : sort === "latest"
            ? "最新发布"
            : "热门视频"}
          <span className="ml-2 text-sm font-normal text-muted-foreground">
            ({videos.length})
          </span>
        </h2>
      </div>

      {error ? (
        <div className="rounded-xl border border-destructive/30 bg-destructive/5 p-6 text-center">
          <p className="text-sm text-destructive">{error}</p>
          <Button
            variant="outline"
            size="sm"
            className="mt-3"
            onClick={() => loadFirst(sort, activeCat)}
          >
            重新加载
          </Button>
        </div>
      ) : loading ? (
        <VideoGridSkeleton count={12} />
      ) : videos.length === 0 ? (
        <div className="rounded-xl border border-border bg-card p-12 text-center">
          <p className="text-sm text-muted-foreground">
            暂无视频，换个分类看看？
          </p>
        </div>
      ) : (
        <>
          <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5">
            {videos.map((v, i) => (
              <VideoCard key={v.id} video={v} priority={i < 10} />
            ))}
          </div>

          {/* Sentinel + loading more */}
          <div ref={sentinelRef} className="h-12" />
          {loadingMore && <VideoGridSkeleton count={5} />}
          {!hasMore && videos.length > 0 && (
            <p className="py-4 text-center text-sm text-muted-foreground">
              已经到底了
            </p>
          )}
        </>
      )}
    </div>
  );
}
