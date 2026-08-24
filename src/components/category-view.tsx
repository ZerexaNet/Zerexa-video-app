"use client";

/**
 * Category view.
 *
 * Lists videos filtered by a category root. Mirrors the home view's
 * infinite scroll behaviour but with a single category fixed.
 */

import { useCallback, useEffect, useRef, useState } from "react";
import { Button } from "@/components/ui/button";
import { VideoCard } from "@/components/video-card";
import { VideoGridSkeleton } from "@/components/video-grid-skeleton";
import { ArrowLeftIcon } from "@/components/icons";
import { api, type VideoListItem } from "@/lib/api";
import { useRoute } from "@/lib/route";
import { CATEGORIES } from "@/components/home-view";

interface CategoryViewProps {
  category: string;
}

export function CategoryView({ category }: CategoryViewProps) {
  const { goHome } = useRoute();
  const [videos, setVideos] = useState<VideoListItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [loadingMore, setLoadingMore] = useState(false);
  const [hasMore, setHasMore] = useState(true);
  const sentinelRef = useRef<HTMLDivElement>(null);

  const label =
    CATEGORIES.find((c) => c.root === category)?.label ?? category;

  const loadFirst = useCallback(async () => {
    setLoading(true);
    setHasMore(true);
    try {
      const data = await api.listVideos({
        category,
        limit: 24,
        offset: 0,
      });
      setVideos(data);
      if (data.length < 24) setHasMore(false);
    } catch {
      setVideos([]);
    } finally {
      setLoading(false);
    }
  }, [category]);

  useEffect(() => {
    loadFirst();
  }, [loadFirst]);

  const loadMore = useCallback(async () => {
    if (loadingMore || !hasMore) return;
    setLoadingMore(true);
    try {
      const data = await api.listVideos({
        category,
        limit: 24,
        offset: videos.length,
      });
      if (data.length === 0) setHasMore(false);
      else {
        setVideos((prev) => [...prev, ...data]);
        if (data.length < 24) setHasMore(false);
      }
    } catch {
      setHasMore(false);
    } finally {
      setLoadingMore(false);
    }
  }, [videos.length, loadingMore, hasMore, category]);

  useEffect(() => {
    const el = sentinelRef.current;
    if (!el) return;
    const ob = new IntersectionObserver(
      (entries) => {
        for (const e of entries) if (e.isIntersecting) loadMore();
      },
      { rootMargin: "200px" },
    );
    ob.observe(el);
    return () => ob.disconnect();
  }, [loadMore]);

  return (
    <div className="space-y-5">
      <button
        onClick={goHome}
        className="inline-flex items-center gap-1.5 text-sm text-muted-foreground transition-colors hover:text-foreground"
      >
        <ArrowLeftIcon size={16} />
        返回首页
      </button>

      <div>
        <h1 className="text-2xl font-bold">{label} 视频</h1>
        <p className="mt-1 text-sm text-muted-foreground">
          共 {videos.length} 条结果
        </p>
      </div>

      {loading ? (
        <VideoGridSkeleton count={12} />
      ) : videos.length === 0 ? (
        <div className="rounded-xl border border-border bg-card p-12 text-center">
          <p className="text-sm text-muted-foreground">
            该分类下暂无视频
          </p>
          <Button onClick={goHome} className="mt-4">
            浏览全部
          </Button>
        </div>
      ) : (
        <>
          <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5">
            {videos.map((v, i) => (
              <VideoCard key={v.id} video={v} priority={i < 10} />
            ))}
          </div>
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
