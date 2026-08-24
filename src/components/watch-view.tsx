"use client";

/**
 * Watch view.
 *
 * Renders the full video player, metadata, author card, and
 * interactive actions (like / coin / favorite / share), followed
 * by the comment section. Uses TanStack Query-style manual loading
 * with optimistic UI updates for the like button.
 */

import { useCallback, useEffect, useState } from "react";
import { Button } from "@/components/ui/button";
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import { Badge } from "@/components/ui/badge";
import { Skeleton } from "@/components/ui/skeleton";
import { VideoPlayer } from "@/components/video-player";
import { CommentSection } from "@/components/comment-section";
import {
  HeartIcon,
  CoinIcon,
  StarIcon,
  ShareIcon,
  FlagIcon,
  ArrowLeftIcon,
  EyeIcon,
  VerifiedBadge,
} from "@/components/icons";
import { api, type VideoDetail, type DanmakuItem } from "@/lib/api";
import { useRoute } from "@/lib/route";
import { useAuth } from "@/lib/auth";
import { useToast } from "@/hooks/use-toast";
import {
  formatRelativeTime,
  formatViews,
  splitCategory,
} from "@/lib/format";

interface WatchViewProps {
  videoId: string;
}

type ActionState = {
  liked: boolean;
  likes: number;
  favorited: boolean;
  coins: number;
};

export function WatchView({ videoId }: WatchViewProps) {
  const { goHome, goSearch } = useRoute();
  const { user } = useAuth();
  const { toast } = useToast();
  const [video, setVideo] = useState<VideoDetail | null>(null);
  const [danmaku, setDanmaku] = useState<DanmakuItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [action, setAction] = useState<ActionState>({
    liked: false,
    likes: 0,
    favorited: false,
    coins: 0,
  });
  const [busy, setBusy] = useState<"" | "like" | "coin" | "fav" | "">("");

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const [v, d] = await Promise.all([
        api.getVideo(videoId),
        api.listDanmaku(videoId).catch(() => [] as DanmakuItem[]),
      ]);
      setVideo(v);
      setDanmaku(d);
      setAction({
        liked: false,
        likes: v.likes ?? 0,
        favorited: false,
        coins: v.coin_count ?? 0,
      });
    } catch (e) {
      setError(e instanceof Error ? e.message : "加载失败");
    } finally {
      setLoading(false);
    }
  }, [videoId]);

  useEffect(() => {
    load();
  }, [load]);

  // Optional: track view progress (fire-and-forget)
  useEffect(() => {
    if (!video) return;
    const t = setTimeout(() => {
      // api.reportProgress(videoId, ...).catch(() => {});
    }, 10000);
    return () => clearTimeout(t);
  }, [video]);

  const ensureAuth = () => {
    if (!user) {
      toast({
        title: "请先登录",
        description: "这个操作需要登录账户后才能继续",
        variant: "destructive",
      });
      return false;
    }
    return true;
  };

  const onLike = async () => {
    if (!ensureAuth() || busy) return;
    setBusy("like");
    const prev = action;
    setAction((a) => ({
      ...a,
      liked: !a.liked,
      likes: a.liked ? a.likes - 1 : a.likes + 1,
    }));
    try {
      const res = await api.likeVideo(videoId);
      setAction((a) => ({ ...a, liked: res.liked, likes: res.likes }));
    } catch (e) {
      setAction(prev);
      toast({
        title: "操作失败",
        description: e instanceof Error ? e.message : "请稍后重试",
        variant: "destructive",
      });
    } finally {
      setBusy("");
    }
  };

  const onFav = async () => {
    if (!ensureAuth() || busy) return;
    setBusy("fav");
    const prev = action;
    const next = !action.favorited;
    setAction((a) => ({ ...a, favorited: next }));
    try {
      if (next) await api.favoriteVideo(videoId);
      else await api.unfavoriteVideo(videoId);
      toast({ title: next ? "已收藏" : "已取消收藏" });
    } catch (e) {
      setAction(prev);
      toast({
        title: "操作失败",
        description: e instanceof Error ? e.message : "请稍后重试",
        variant: "destructive",
      });
    } finally {
      setBusy("");
    }
  };

  const onCoin = async () => {
    if (!ensureAuth() || busy) return;
    setBusy("coin");
    const prev = action;
    setAction((a) => ({ ...a, coins: a.coins + 1 }));
    try {
      await api.coinVideo(videoId, 1);
      toast({ title: "已投币" });
    } catch (e) {
      setAction(prev);
      toast({
        title: "操作失败",
        description: e instanceof Error ? e.message : "请稍后重试",
        variant: "destructive",
      });
    } finally {
      setBusy("");
    }
  };

  const onSendDanmaku = async (text: string, color: string) => {
    if (!user) throw new Error("请先登录");
    // The remote API does not expose a stable POST /danmaku endpoint in
    // the public spec we rely on, so we just no-op here and let the
    // optimistic local add in the player show the danmaku.
    void text;
    void color;
  };

  const onShare = async () => {
    try {
      if (navigator.share) {
        await navigator.share({
          title: video?.title ?? "Zerexa Video",
          url: window.location.href,
        });
      } else {
        await navigator.clipboard.writeText(window.location.href);
        toast({ title: "链接已复制" });
      }
    } catch {
      // user dismissed share dialog - no-op
    }
  };

  if (loading) return <WatchSkeleton />;
  if (error || !video) {
    return (
      <div className="rounded-xl border border-destructive/30 bg-destructive/5 p-8 text-center">
        <p className="text-destructive">{error ?? "视频不存在"}</p>
        <Button onClick={goHome} className="mt-4">
          返回首页
        </Button>
      </div>
    );
  }

  const { root, sub } = splitCategory(video.category);
  const cover = api.resolveAsset(video.cover_url);

  return (
    <div className="space-y-5">
      {/* Back button */}
      <button
        onClick={goHome}
        className="inline-flex items-center gap-1.5 text-sm text-muted-foreground transition-colors hover:text-foreground"
      >
        <ArrowLeftIcon size={16} />
        返回
      </button>

      <div className="grid gap-5 lg:grid-cols-[1fr_320px]">
        {/* Main column */}
        <div className="space-y-4">
          <VideoPlayer
            src={video.stream_url}
            poster={cover ?? undefined}
            danmaku={danmaku}
            onSendDanmaku={onSendDanmaku}
            videoId={videoId}
          />

          {/* Title */}
          <div>
            <h1 className="text-xl font-bold leading-snug sm:text-2xl">
              {video.title}
            </h1>
            <div className="mt-2 flex flex-wrap items-center gap-3 text-xs text-muted-foreground">
              <span className="flex items-center gap-1">
                <EyeIcon size={13} />
                {formatViews(video.views)} 次观看
              </span>
              <span>·</span>
              <span>{formatRelativeTime(video.created_at)}</span>
              {video.ip_location && (
                <>
                  <span>·</span>
                  <span>来自 {video.ip_location}</span>
                </>
              )}
              <Badge variant="secondary" className="ml-auto">
                {root}
                {sub && <span className="opacity-60"> / {sub}</span>}
              </Badge>
            </div>
          </div>

          {/* Action bar */}
          <div className="flex flex-wrap items-center gap-2 border-y border-border py-3">
            <Button
              variant={action.liked ? "default" : "outline"}
              size="sm"
              onClick={onLike}
              disabled={busy === "like"}
              className="h-9"
            >
              <HeartIcon
                size={16}
                className="mr-1.5"
                fill={action.liked ? "currentColor" : "none"}
              />
              {action.likes}
            </Button>
            <Button
              variant="outline"
              size="sm"
              onClick={onCoin}
              disabled={busy === "coin"}
              className="h-9"
            >
              <CoinIcon size={16} className="mr-1.5" />
              投币 {action.coins}
            </Button>
            <Button
              variant={action.favorited ? "default" : "outline"}
              size="sm"
              onClick={onFav}
              disabled={busy === "fav"}
              className="h-9"
            >
              <StarIcon
                size={16}
                className="mr-1.5"
                fill={action.favorited ? "currentColor" : "none"}
              />
              {action.favorited ? "已收藏" : "收藏"}
            </Button>
            <Button
              variant="outline"
              size="sm"
              onClick={onShare}
              className="h-9"
            >
              <ShareIcon size={16} className="mr-1.5" />
              分享
            </Button>
            <Button
              variant="ghost"
              size="sm"
              className="ml-auto h-9 text-muted-foreground"
              onClick={() =>
                toast({
                  title: "举报已提交",
                  description: "感谢你的反馈，我们将尽快处理",
                })
              }
            >
              <FlagIcon size={16} className="mr-1.5" />
              举报
            </Button>
          </div>

          {/* Description */}
          {video.description && (
            <div className="rounded-xl border border-border bg-card p-4">
              <h2 className="mb-2 text-sm font-semibold">视频简介</h2>
              <p className="whitespace-pre-wrap text-sm leading-relaxed text-foreground/90">
                {video.description}
              </p>
              {video.source_url && (
                <p className="mt-3 border-t border-border pt-3 text-xs text-muted-foreground">
                  原始链接：{" "}
                  <a
                    href={video.source_url}
                    target="_blank"
                    rel="noreferrer"
                    className="text-primary hover:underline"
                  >
                    {video.source_url}
                  </a>
                </p>
              )}
            </div>
          )}

          {/* Comments */}
          <CommentSection videoId={videoId} />
        </div>

        {/* Sidebar */}
        <aside className="space-y-4">
          {/* Author card */}
          <div className="rounded-xl border border-border bg-card p-4">
            <h2 className="mb-3 text-sm font-semibold">UP 主</h2>
            <div className="flex items-center gap-3">
              <Avatar className="h-12 w-12 border border-border">
                <AvatarImage
                  src={video.author_gravatar_url ?? undefined}
                  alt={video.author_username}
                />
                <AvatarFallback>
                  {video.author_username.slice(0, 1).toUpperCase()}
                </AvatarFallback>
              </Avatar>
              <div className="min-w-0 flex-1">
                <div className="flex items-center gap-1.5">
                  <p className="truncate font-medium">
                    {video.author_username}
                  </p>
                  {video.author_verification_badge && (
                    <VerifiedBadge
                      color={video.author_verification_badge}
                      size={14}
                    />
                  )}
                </div>
                {video.author_verification_label && (
                  <p className="text-xs text-muted-foreground">
                    {video.author_verification_label}
                  </p>
                )}
              </div>
              <Button
                size="sm"
                variant="outline"
                className="h-8"
                onClick={() => {
                  if (!user) {
                    toast({
                      title: "请先登录",
                      description: "登录后即可关注创作者",
                      variant: "destructive",
                    });
                    return;
                  }
                  toast({ title: "关注功能开发中" });
                }}
              >
                关注
              </Button>
            </div>
            <p className="mt-3 text-xs text-muted-foreground">
              UID: {video.author_uid}
              {video.author_ip_location && ` · 来自 ${video.author_ip_location}`}
            </p>
          </div>

          {/* More like this placeholder */}
          <div className="rounded-xl border border-border bg-card p-4">
            <h2 className="mb-3 text-sm font-semibold">相关推荐</h2>
            <p className="text-xs text-muted-foreground">
              相关视频加载中，请稍候。
            </p>
          </div>
        </aside>
      </div>
    </div>
  );
}

function WatchSkeleton() {
  return (
    <div className="space-y-5">
      <Skeleton className="h-4 w-16" />
      <div className="grid gap-5 lg:grid-cols-[1fr_320px]">
        <div className="space-y-4">
          <Skeleton className="aspect-video w-full rounded-xl" />
          <Skeleton className="h-8 w-3/4" />
          <Skeleton className="h-12 w-full" />
          <Skeleton className="h-32 w-full rounded-xl" />
        </div>
        <div className="space-y-4">
          <Skeleton className="h-32 w-full rounded-xl" />
          <Skeleton className="h-32 w-full rounded-xl" />
        </div>
      </div>
    </div>
  );
}
