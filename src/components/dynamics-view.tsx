"use client";

/**
 * Dynamics view (动态时间线).
 *
 * Lists dynamics from /api/dynamics with a composer at the top.
 * Supports text + optional media URLs, like, delete (own), and
 * infinite-scroll-style pagination via "load more".
 */

import * as React from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { api, type DynamicItem, type Paginated } from "@/lib/api";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import { Skeleton } from "@/components/ui/skeleton";
import {
  DynamicIcon,
  HeartIcon,
  TrashIcon,
  SendIcon,
  PlusIcon,
  VerifiedBadge,
} from "@/components/icons";
import { useAuth } from "@/lib/auth";
import { useToast } from "@/hooks/use-toast";
import { useRoute } from "@/lib/route";
import { formatRelativeTime, formatViews } from "@/lib/format";

function asArray<T>(data: unknown): T[] {
  if (Array.isArray(data)) return data as T[];
  if (data && typeof data === "object" && "items" in data) {
    const items = (data as Paginated<T>).items;
    if (Array.isArray(items)) return items;
  }
  return [];
}

export function DynamicsView() {
  const { user } = useAuth();
  const { goProfile } = useRoute();
  const { toast } = useToast();
  const qc = useQueryClient();
  const [refreshKey, setRefreshKey] = React.useState(0);
  const [page, setPage] = React.useState(0);
  const pageSize = 20;

  // Composer state
  const [content, setContent] = React.useState("");
  const [mediaUrl, setMediaUrl] = React.useState("");
  const [extraMedia, setExtraMedia] = React.useState<string[]>([]);
  const [sending, setSending] = React.useState(false);

  const query = useQuery({
    queryKey: ["dynamics", page, refreshKey],
    queryFn: () =>
      api.listDynamics({ limit: pageSize, offset: page * pageSize }),
    retry: false,
  });

  const items = asArray<DynamicItem>(query.data);

  const createMutation = useMutation({
    mutationFn: (body: { content: string; media_urls?: string[] }) =>
      api.createDynamic(body),
    onSuccess: () => {
      toast({ title: "动态已发布" });
      setContent("");
      setMediaUrl("");
      setExtraMedia([]);
      qc.invalidateQueries({ queryKey: ["dynamics"] });
    },
    onError: (e: unknown) =>
      toast({
        title: "发布失败",
        description: e instanceof Error ? e.message : "请稍后重试",
        variant: "destructive",
      }),
  });

  const likeMutation = useMutation({
    mutationFn: (id: string) => api.likeDynamic(id),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["dynamics"] }),
    onError: (e: unknown) =>
      toast({
        title: "操作失败",
        description: e instanceof Error ? e.message : "请稍后重试",
        variant: "destructive",
      }),
  });

  const deleteMutation = useMutation({
    mutationFn: (id: string) => api.deleteDynamic(id),
    onSuccess: () => {
      toast({ title: "已删除" });
      qc.invalidateQueries({ queryKey: ["dynamics"] });
    },
    onError: (e: unknown) =>
      toast({
        title: "删除失败",
        description: e instanceof Error ? e.message : "请稍后重试",
        variant: "destructive",
      }),
  });

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!user) {
      toast({
        title: "请先登录",
        description: "发布动态需要登录账号",
        variant: "destructive",
      });
      return;
    }
    const text = content.trim();
    if (!text) return;
    setSending(true);
    try {
      const urls = [
        ...(mediaUrl.trim() ? [mediaUrl.trim()] : []),
        ...extraMedia.filter((u) => u.trim() !== "").map((u) => u.trim()),
      ];
      await createMutation.mutateAsync({
        content: text,
        media_urls: urls.length ? urls : undefined,
      });
    } finally {
      setSending(false);
    }
  };

  return (
    <div className="mx-auto max-w-3xl">
      <div className="mb-5 flex flex-wrap items-end justify-between gap-3 border-b border-border pb-4">
        <div>
          <h2 className="flex items-center gap-2 text-xl font-bold tracking-tight">
            <DynamicIcon size={22} />
            动态
          </h2>
          <p className="mt-1 text-sm text-muted-foreground">
            全站最新动态时间线。登录后可发布自己的动态。
          </p>
        </div>
        <Button
          variant="outline"
          size="sm"
          className="h-8"
          onClick={() => setRefreshKey((k) => k + 1)}
          disabled={query.isFetching}
        >
          刷新
        </Button>
      </div>

      {user && (
        <form
          onSubmit={submit}
          className="mb-6 rounded-lg border border-border bg-card p-4 shadow-sm"
        >
          <Textarea
            value={content}
            onChange={(e) => setContent(e.target.value)}
            placeholder="分享一条动态..."
            rows={3}
            maxLength={500}
            className="resize-none"
          />
          <div className="mt-3 space-y-2">
            <Input
              value={mediaUrl}
              onChange={(e) => setMediaUrl(e.target.value)}
              placeholder="图片 / 视频 URL（可选）"
              type="url"
            />
            {extraMedia.map((url, i) => (
              <div key={i} className="flex items-center gap-2">
                <Input
                  value={url}
                  onChange={(e) =>
                    setExtraMedia((arr) =>
                      arr.map((v, j) => (j === i ? e.target.value : v)),
                    )
                  }
                  placeholder={`附加媒体 URL #${i + 2}`}
                  type="url"
                />
                <Button
                  type="button"
                  variant="ghost"
                  size="icon"
                  className="h-8 w-8"
                  onClick={() =>
                    setExtraMedia((arr) => arr.filter((_, j) => j !== i))
                  }
                >
                  <TrashIcon size={14} />
                </Button>
              </div>
            ))}
            <Button
              type="button"
              variant="outline"
              size="sm"
              className="h-7 text-xs"
              onClick={() => setExtraMedia((arr) => [...arr, ""])}
            >
              <PlusIcon size={12} className="mr-1" />
              添加媒体
            </Button>
          </div>
          <div className="mt-3 flex items-center justify-between">
            <span className="text-xs text-muted-foreground">
              {content.length} / 500
            </span>
            <Button
              type="submit"
              size="sm"
              disabled={sending || !content.trim()}
            >
              <SendIcon size={14} className="mr-1.5" />
              {sending ? "发布中..." : "发布"}
            </Button>
          </div>
        </form>
      )}

      {query.isError && (
        <div className="mb-4 rounded-md border border-red-500/30 bg-red-500/5 px-4 py-3 text-sm text-red-700 dark:text-red-300">
          加载动态失败：{query.error instanceof Error ? query.error.message : "未知错误"}
        </div>
      )}

      {query.isLoading ? (
        <div className="space-y-4">
          {Array.from({ length: 5 }).map((_, i) => (
            <Skeleton key={i} className="h-32 w-full rounded-lg" />
          ))}
        </div>
      ) : items.length === 0 ? (
        <div className="flex flex-col items-center justify-center rounded-md border border-dashed border-border bg-card/50 px-6 py-12 text-center">
          <DynamicIcon size={32} className="mb-3 text-muted-foreground" />
          <p className="text-sm font-medium">暂无动态</p>
          <p className="mt-1 max-w-md text-xs text-muted-foreground">
            发布第一条动态开启社区时间线。
          </p>
        </div>
      ) : (
        <ul className="space-y-4">
          {items.map((d) => (
            <DynamicCard
              key={d.id}
              item={d}
              currentUid={user?.uid}
              onLike={() => likeMutation.mutate(d.id)}
              onDelete={() => {
                if (window.confirm("确认删除这条动态？此操作不可撤销。")) {
                  deleteMutation.mutate(d.id);
                }
              }}
              likePending={likeMutation.isPending}
              onAuthorClick={() => goProfile()}
            />
          ))}
        </ul>
      )}

      {items.length >= pageSize && (
        <div className="mt-6 flex items-center justify-center">
          <Button
            variant="outline"
            size="sm"
            className="h-8"
            onClick={() => setPage((p) => p + 1)}
            disabled={query.isFetching}
          >
            加载更多
          </Button>
        </div>
      )}
    </div>
  );
}

function DynamicCard({
  item,
  currentUid,
  onLike,
  onDelete,
  likePending,
  onAuthorClick,
}: {
  item: DynamicItem;
  currentUid?: number;
  onLike: () => void;
  onDelete: () => void;
  likePending: boolean;
  onAuthorClick: () => void;
}) {
  const isAuthor = currentUid != null && item.author_uid === currentUid;
  return (
    <li className="rounded-lg border border-border bg-card p-4 shadow-sm">
      <div className="flex items-start gap-3">
        <button onClick={onAuthorClick} className="shrink-0">
          <Avatar className="h-10 w-10 border border-border">
            <AvatarImage src={item.author_gravatar_url ?? undefined} alt={item.author_username} />
            <AvatarFallback>
              {item.author_username.slice(0, 1).toUpperCase()}
            </AvatarFallback>
          </Avatar>
        </button>
        <div className="min-w-0 flex-1">
          <div className="flex items-center gap-1.5 text-sm">
            <button
              onClick={onAuthorClick}
              className="font-medium hover:underline"
            >
              {item.author_username}
            </button>
            {item.author_verification_badge && (
              <VerifiedBadge size={14} color={item.author_verification_badge ?? "yellow"} />
            )}
            <span className="text-xs text-muted-foreground">
              · {formatRelativeTime(item.created_at)}
            </span>
            {item.ip_location && (
              <span className="text-xs text-muted-foreground">
                · 来自 {item.ip_location}
              </span>
            )}
          </div>
          <div className="mt-1 whitespace-pre-wrap break-words text-sm">
            {item.content}
          </div>
          {item.media_urls && item.media_urls.length > 0 && (
            <div className="mt-3 grid grid-cols-2 gap-2 sm:grid-cols-3">
              {item.media_urls.map((url, i) => (
                <a
                  key={i}
                  href={url}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="block overflow-hidden rounded-md border border-border bg-muted"
                >
                  {/\.(png|jpe?g|gif|webp|bmp)$/i.test(url) ? (
                    <img
                      src={url}
                      alt={`媒体 ${i + 1}`}
                      className="h-32 w-full object-cover"
                      loading="lazy"
                    />
                  ) : (
                    <div className="flex h-32 items-center justify-center text-xs text-muted-foreground">
                      {url.split("/").pop() ?? url}
                    </div>
                  )}
                </a>
              ))}
            </div>
          )}
          <div className="mt-3 flex items-center gap-4 text-xs text-muted-foreground">
            <button
              onClick={onLike}
              disabled={likePending}
              className={`flex items-center gap-1 transition-colors hover:text-primary ${
                item.liked ? "text-primary" : ""
              }`}
            >
              <HeartIcon size={14} />
              {item.likes ?? 0}
            </button>
            {item.comments != null && (
              <span className="flex items-center gap-1">
                <DynamicIcon size={14} />
                {formatViews(item.comments)}
              </span>
            )}
            {isAuthor && (
              <button
                onClick={onDelete}
                className="ml-auto flex items-center gap-1 text-red-600 hover:text-red-700"
              >
                <TrashIcon size={14} />
                删除
              </button>
            )}
          </div>
        </div>
      </div>
    </li>
  );
}
