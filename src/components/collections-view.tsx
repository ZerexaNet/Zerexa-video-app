"use client";

/**
 * Collections (合集) views.
 *
 * - CollectionsList:  ?view=collections          GET /api/collections
 * - CollectionDetail: ?view=collection&cid=ID    GET /api/collections/{id}
 * - CollectionEditor: ?view=collection-edit     POST /api/collections
 *                                              PUT /api/collections/{id}
 *                                              POST /api/collections/{id}/videos
 *                                              DELETE /api/collections/{id}/videos/{vid}
 */

import * as React from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import {
  api,
  type CollectionListItem,
  type CollectionDetail,
  type Paginated,
} from "@/lib/api";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Label } from "@/components/ui/label";
import { Skeleton } from "@/components/ui/skeleton";
import {
  CollectionIcon,
  PlusIcon,
  ArrowLeftIcon,
  PencilSquareIcon,
  TrashIcon,
  XSquareIcon,
  CheckSquareIcon,
} from "@/components/icons";
import { VideoCard } from "@/components/video-card";
import { useAuth } from "@/lib/auth";
import { useToast } from "@/hooks/use-toast";
import { useRoute } from "@/lib/route";
import { formatRelativeTime } from "@/lib/format";

function asArray<T>(data: unknown): T[] {
  if (Array.isArray(data)) return data as T[];
  if (data && typeof data === "object" && "items" in data) {
    const items = (data as Paginated<T>).items;
    if (Array.isArray(items)) return items;
  }
  return [];
}

// ---------- Collection list ----------

export function CollectionsList() {
  const { user } = useAuth();
  const { goCollection, goCollectionEdit } = useRoute();
  const [refreshKey, setRefreshKey] = React.useState(0);

  const query = useQuery({
    queryKey: ["collections", refreshKey],
    queryFn: () => api.listCollections({ limit: 50 }),
    retry: false,
  });

  const items = asArray<CollectionListItem>(query.data);

  return (
    <div>
      <div className="mb-5 flex flex-wrap items-end justify-between gap-3 border-b border-border pb-4">
        <div>
          <h2 className="flex items-center gap-2 text-xl font-bold tracking-tight">
            <CollectionIcon size={22} />
            合集
          </h2>
          <p className="mt-1 text-sm text-muted-foreground">
            浏览社区创建的视频合集。登录后可创建自己的合集。
          </p>
        </div>
        <div className="flex items-center gap-2">
          <Button
            variant="outline"
            size="sm"
            className="h-8"
            onClick={() => setRefreshKey((k) => k + 1)}
            disabled={query.isFetching}
          >
            刷新
          </Button>
          {user && (
            <Button
              size="sm"
              className="h-8"
              onClick={() => goCollectionEdit()}
            >
              <PlusIcon size={14} className="mr-1.5" />
              新建合集
            </Button>
          )}
        </div>
      </div>

      {query.isError && (
        <div className="mb-4 rounded-md border border-red-500/30 bg-red-500/5 px-4 py-3 text-sm text-red-700 dark:text-red-300">
          加载合集失败：{query.error instanceof Error ? query.error.message : "未知错误"}
        </div>
      )}

      {query.isLoading ? (
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {Array.from({ length: 6 }).map((_, i) => (
            <Skeleton key={i} className="h-32 w-full rounded-lg" />
          ))}
        </div>
      ) : items.length === 0 ? (
        <div className="flex flex-col items-center justify-center rounded-md border border-dashed border-border bg-card/50 px-6 py-12 text-center">
          <CollectionIcon size={32} className="mb-3 text-muted-foreground" />
          <p className="text-sm font-medium">暂无合集</p>
          {user && (
            <p className="mt-1 max-w-md text-xs text-muted-foreground">
              点击右上角「新建合集」开始整理视频。
            </p>
          )}
        </div>
      ) : (
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {items.map((c) => (
            <button
              key={c.id}
              onClick={() => goCollection(c.id)}
              className="group flex flex-col overflow-hidden rounded-lg border border-border bg-card text-left shadow-sm transition-all hover:shadow-md"
            >
              <div className="aspect-[16/9] w-full overflow-hidden bg-muted">
                {c.cover_url ? (
                  <img
                    src={c.cover_url}
                    alt={c.title}
                    className="h-full w-full object-cover transition-transform group-hover:scale-105"
                    loading="lazy"
                  />
                ) : (
                  <div className="flex h-full w-full items-center justify-center text-muted-foreground">
                    <CollectionIcon size={40} />
                  </div>
                )}
              </div>
              <div className="flex flex-1 flex-col gap-1 p-3">
                <h3 className="line-clamp-1 text-sm font-semibold">{c.title}</h3>
                {c.description && (
                  <p className="line-clamp-2 text-xs text-muted-foreground">
                    {c.description}
                  </p>
                )}
                <div className="mt-auto flex items-center justify-between pt-2 text-[11px] text-muted-foreground">
                  <span>{c.author_username ?? "—"}</span>
                  <span>{c.video_count ?? 0} 个视频</span>
                </div>
              </div>
            </button>
          ))}
        </div>
      )}
    </div>
  );
}

// ---------- Collection detail ----------

export function CollectionDetailView({ collectionId }: { collectionId: string }) {
  const { user } = useAuth();
  const { goCollections, goCollectionEdit, goWatch } = useRoute();
  const { toast } = useToast();
  const qc = useQueryClient();
  const [removingId, setRemovingId] = React.useState<string | null>(null);

  const query = useQuery({
    queryKey: ["collection", collectionId],
    queryFn: () => api.getCollection(collectionId),
    retry: false,
  });

  const removeMutation = useMutation({
    mutationFn: (videoId: string) =>
      api.removeVideoFromCollection(collectionId, videoId),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["collection", collectionId] });
      toast({ title: "已从合集移除" });
    },
    onError: (e: unknown) =>
      toast({
        title: "操作失败",
        description: e instanceof Error ? e.message : "请稍后重试",
        variant: "destructive",
      }),
  });

  if (query.isLoading) {
    return (
      <div className="mx-auto max-w-4xl space-y-3">
        <Skeleton className="h-12 w-2/3" />
        <Skeleton className="h-32 w-full" />
      </div>
    );
  }

  if (query.isError || !query.data) {
    return (
      <div className="mx-auto max-w-4xl rounded-md border border-red-500/30 bg-red-500/5 px-4 py-3 text-sm text-red-700 dark:text-red-300">
        加载合集失败：{query.error instanceof Error ? query.error.message : "未知错误"}
        <Button
          variant="outline"
          size="sm"
          className="ml-3 h-7"
          onClick={goCollections}
        >
          返回列表
        </Button>
      </div>
    );
  }

  const c: CollectionDetail = query.data;
  const isAuthor = user && c.author_uid === user.uid;
  const videos = c.videos ?? [];

  return (
    <div className="mx-auto max-w-4xl">
      <Button
        variant="ghost"
        size="sm"
        className="mb-4 h-8"
        onClick={goCollections}
      >
        <ArrowLeftIcon size={14} className="mr-1" />
        返回合集列表
      </Button>

      <header className="mb-6 border-b border-border pb-4">
        <div className="flex items-start justify-between gap-3">
          <div className="min-w-0 flex-1">
            <h1 className="text-2xl font-bold leading-tight tracking-tight sm:text-3xl">
              {c.title}
            </h1>
            {c.description && (
              <p className="mt-2 whitespace-pre-wrap text-sm text-muted-foreground">
                {c.description}
              </p>
            )}
            <div className="mt-3 flex flex-wrap items-center gap-3 text-xs text-muted-foreground">
              <span>{c.author_username ?? "—"}</span>
              <span>· {videos.length} 个视频</span>
              <span>· 创建于 {formatRelativeTime(c.created_at)}</span>
            </div>
          </div>
          {isAuthor && (
            <Button
              variant="outline"
              size="sm"
              className="h-8"
              onClick={() => goCollectionEdit(c.id)}
            >
              <PencilSquareIcon size={14} className="mr-1.5" />
              编辑
            </Button>
          )}
        </div>
      </header>

      {videos.length === 0 ? (
        <div className="rounded-md border border-dashed border-border bg-card/50 px-6 py-12 text-center text-sm text-muted-foreground">
          合集暂无视频
        </div>
      ) : (
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {videos.map((v) => (
            <div key={v.id} className="relative">
              <VideoCard video={v} />
              {isAuthor && (
                <Button
                  variant="secondary"
                  size="sm"
                  className="absolute right-2 top-2 h-7 bg-background/90 backdrop-blur"
                  onClick={() => {
                    if (window.confirm(`从合集移除「${v.title}」？`)) {
                      setRemovingId(v.id);
                      removeMutation.mutate(v.id);
                    }
                  }}
                  disabled={removingId === v.id && removeMutation.isPending}
                >
                  <XSquareIcon size={12} className="mr-1" />
                  移除
                </Button>
              )}
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

// ---------- Collection editor ----------

export function CollectionEditor({ collectionId }: { collectionId?: string }) {
  const { user } = useAuth();
  const { goCollections, goCollection, goCollectionEdit } = useRoute();
  const { toast } = useToast();
  const [title, setTitle] = React.useState("");
  const [description, setDescription] = React.useState("");
  const [coverUrl, setCoverUrl] = React.useState("");
  const [saving, setSaving] = React.useState(false);
  const [loading, setLoading] = React.useState(!!collectionId);

  // Add video state
  const [videoIdToAdd, setVideoIdToAdd] = React.useState("");
  const [adding, setAdding] = React.useState(false);

  // Existing videos (if editing)
  const [videos, setVideos] = React.useState<
    { id: string; title: string }[] | null
  >(null);

  React.useEffect(() => {
    if (!collectionId) return;
    let cancelled = false;
    (async () => {
      try {
        const c = await api.getCollection(collectionId);
        if (cancelled) return;
        setTitle(c.title ?? "");
        setDescription(c.description ?? "");
        setCoverUrl(c.cover_url ?? "");
        setVideos(
          (c.videos ?? []).map((v) => ({ id: v.id, title: v.title })),
        );
      } catch (e) {
        toast({
          title: "加载合集失败",
          description: e instanceof Error ? e.message : "未知错误",
          variant: "destructive",
        });
      } finally {
        if (!cancelled) setLoading(false);
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [collectionId, toast]);

  if (!user) {
    return (
      <div className="mx-auto max-w-2xl rounded-md border border-amber-500/40 bg-amber-500/5 px-4 py-3 text-sm text-amber-700 dark:text-amber-300">
        请先登录后创建合集。
      </div>
    );
  }

  if (loading) {
    return (
      <div className="mx-auto max-w-2xl space-y-3">
        <Skeleton className="h-10 w-full" />
        <Skeleton className="h-32 w-full" />
      </div>
    );
  }

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!title.trim()) return;
    setSaving(true);
    try {
      const body = {
        title: title.trim(),
        description: description.trim() || undefined,
        cover_url: coverUrl.trim() || null,
      };
      if (collectionId) {
        await api.updateCollection(collectionId, body);
        toast({ title: "合集已更新" });
      } else {
        const resp = (await api.createCollection(body)) as { id?: string };
        toast({ title: "合集已创建" });
        if (resp.id) {
          goCollectionEdit(resp.id);
          return;
        }
      }
      goCollections();
    } catch (err) {
      toast({
        title: "保存失败",
        description: err instanceof Error ? err.message : "请稍后重试",
        variant: "destructive",
      });
    } finally {
      setSaving(false);
    }
  };

  const addVideo = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!collectionId || !videoIdToAdd.trim()) return;
    setAdding(true);
    try {
      await api.addVideoToCollection(collectionId, videoIdToAdd.trim());
      toast({ title: "视频已加入合集" });
      setVideoIdToAdd("");
      // Refresh videos
      const c = await api.getCollection(collectionId);
      setVideos((c.videos ?? []).map((v) => ({ id: v.id, title: v.title })));
    } catch (err) {
      toast({
        title: "添加失败",
        description: err instanceof Error ? err.message : "请稍后重试",
        variant: "destructive",
      });
    } finally {
      setAdding(false);
    }
  };

  const removeVideo = async (vid: string) => {
    if (!collectionId) return;
    if (!window.confirm("从合集移除此视频？")) return;
    try {
      await api.removeVideoFromCollection(collectionId, vid);
      setVideos((arr) => arr?.filter((v) => v.id !== vid) ?? null);
      toast({ title: "已移除" });
    } catch (err) {
      toast({
        title: "操作失败",
        description: err instanceof Error ? err.message : "请稍后重试",
        variant: "destructive",
      });
    }
  };

  return (
    <form onSubmit={submit} className="mx-auto max-w-2xl space-y-5">
      <div className="flex items-center justify-between">
        <h2 className="text-xl font-bold tracking-tight">
          {collectionId ? "编辑合集" : "新建合集"}
        </h2>
        <Button variant="ghost" size="sm" className="h-8" onClick={goCollections}>
          取消
        </Button>
      </div>

      <div className="space-y-1.5">
        <Label htmlFor="c-title">标题</Label>
        <Input
          id="c-title"
          value={title}
          onChange={(e) => setTitle(e.target.value)}
          maxLength={120}
          placeholder="合集标题"
          required
        />
      </div>

      <div className="space-y-1.5">
        <Label htmlFor="c-desc">简介</Label>
        <Textarea
          id="c-desc"
          value={description}
          onChange={(e) => setDescription(e.target.value)}
          rows={4}
          maxLength={500}
          placeholder="合集内容简介（可选）"
        />
      </div>

      <div className="space-y-1.5">
        <Label htmlFor="c-cover">封面 URL（可选）</Label>
        <Input
          id="c-cover"
          value={coverUrl}
          onChange={(e) => setCoverUrl(e.target.value)}
          type="url"
          placeholder="https://..."
        />
      </div>

      {/* Videos management (only in edit mode) */}
      {collectionId && (
        <div className="space-y-3 rounded-md border border-border bg-card p-4">
          <div className="text-sm font-semibold">合集视频</div>
          {videos && videos.length > 0 && (
            <ul className="space-y-1.5">
              {videos.map((v) => (
                <li
                  key={v.id}
                  className="flex items-center justify-between gap-2 rounded-md border border-border px-3 py-2 text-sm"
                >
                  <span className="min-w-0 flex-1 truncate">{v.title}</span>
                  <button
                    type="button"
                    onClick={() => removeVideo(v.id)}
                    className="text-xs text-red-600 hover:text-red-700"
                  >
                    <TrashIcon size={14} />
                  </button>
                </li>
              ))}
            </ul>
          )}
          <div className="flex items-center gap-2">
            <Input
              value={videoIdToAdd}
              onChange={(e) => setVideoIdToAdd(e.target.value)}
              placeholder="输入视频 ID 添加到合集"
              className="flex-1"
            />
            <Button
              type="button"
              variant="outline"
              size="sm"
              className="h-9"
              onClick={addVideo}
              disabled={adding || !videoIdToAdd.trim()}
            >
              <PlusIcon size={14} className="mr-1" />
              添加
            </Button>
          </div>
        </div>
      )}

      <div className="flex items-center justify-end gap-2 border-t border-border pt-4">
        <Button
          type="button"
          variant="outline"
          size="sm"
          onClick={goCollections}
        >
          取消
        </Button>
        <Button
          type="submit"
          size="sm"
          disabled={saving || !title.trim()}
        >
          {saving ? "保存中..." : collectionId ? "更新合集" : "创建合集"}
        </Button>
      </div>

      {collectionId && (
        <div className="flex items-center justify-end border-t border-border pt-4">
          <Button
            type="button"
            variant="ghost"
            size="sm"
            className="h-8"
            onClick={() => goCollection(collectionId)}
          >
            <CheckSquareIcon size={14} className="mr-1" />
            完成编辑
          </Button>
        </div>
      )}
    </form>
  );
}
