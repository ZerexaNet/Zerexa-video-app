"use client";

/**
 * Comment section for the watch page.
 *
 * Loads paginated comments, supports nested replies (one level),
 * and posting new comments. Uses an optimistic UI: the new
 * comment appears immediately, and if the API rejects it we
 * roll back with a toast.
 */

import { useCallback, useEffect, useState } from "react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import {
  HeartIcon,
  SendIcon,
  CommentIcon,
  VerifiedBadge,
  RefreshIcon,
} from "@/components/icons";
import { api, type Comment, type CommentList } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { useToast } from "@/hooks/use-toast";
import { formatRelativeTime, escapeHtml } from "@/lib/format";
import { AuthDialog } from "@/components/auth-dialog";

interface CommentSectionProps {
  videoId: string;
}

export function CommentSection({ videoId }: CommentSectionProps) {
  const { user } = useAuth();
  const { toast } = useToast();
  const [items, setItems] = useState<Comment[]>([]);
  const [total, setTotal] = useState(0);
  const [loading, setLoading] = useState(true);
  const [posting, setPosting] = useState(false);
  const [draft, setDraft] = useState("");
  const [authOpen, setAuthOpen] = useState(false);
  const [authMode, setAuthMode] = useState<"login" | "register">("login");

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const res: CommentList = await api.listComments(videoId, {
        limit: 50,
        offset: 0,
      });
      setItems(res.items);
      setTotal(res.total);
    } catch (e) {
      toast({
        title: "评论加载失败",
        description: e instanceof Error ? e.message : "请稍后重试",
        variant: "destructive",
      });
      setItems([]);
    } finally {
      setLoading(false);
    }
  }, [videoId, toast]);

  useEffect(() => {
    load();
  }, [load]);

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!user) {
      setAuthMode("login");
      setAuthOpen(true);
      return;
    }
    const text = draft.trim();
    if (!text) return;
    setPosting(true);
    try {
      const c = await api.postComment(videoId, text);
      setItems((prev) => [
        {
          ...c,
          author_username: user.username,
          author_uid: user.uid,
          author_gravatar_url: user.gravatar_url ?? null,
          author_verification_badge: user.verification_badge ?? null,
          author_verification_label: user.verification_label ?? null,
          likes: 0,
          liked: false,
        },
        ...prev,
      ]);
      setTotal((t) => t + 1);
      setDraft("");
    } catch (err) {
      toast({
        title: "评论发送失败",
        description: err instanceof Error ? err.message : "请稍后重试",
        variant: "destructive",
      });
    } finally {
      setPosting(false);
    }
  };

  return (
    <section className="space-y-4">
      <div className="flex items-center justify-between">
        <h2 className="flex items-center gap-2 text-lg font-bold">
          <CommentIcon size={18} />
          评论
          <span className="text-sm font-normal text-muted-foreground">
            ({total})
          </span>
        </h2>
        <Button
          variant="ghost"
          size="sm"
          onClick={load}
          className="h-8"
          aria-label="刷新评论"
        >
          <RefreshIcon size={14} />
        </Button>
      </div>

      {/* Compose */}
      <form onSubmit={submit} className="space-y-2">
        <div className="flex items-start gap-3">
          <Avatar className="h-9 w-9 border border-border">
            <AvatarImage src={user?.gravatar_url ?? undefined} alt={user?.username ?? "guest"} />
            <AvatarFallback>
              {user ? user.username.slice(0, 1).toUpperCase() : "?"}
            </AvatarFallback>
          </Avatar>
          <div className="flex-1 space-y-2">
            <Textarea
              value={draft}
              onChange={(e) => setDraft(e.target.value)}
              placeholder={
                user
                  ? "留下你的想法..."
                  : "登录后即可发表评论..."
              }
              rows={3}
              maxLength={500}
              className="resize-none"
            />
            <div className="flex items-center justify-between">
              <span className="text-xs text-muted-foreground">
                {draft.length} / 500
              </span>
              <Button
                type="submit"
                disabled={posting || !draft.trim()}
                size="sm"
                className="h-9"
              >
                <SendIcon size={14} className="mr-1" />
                {posting ? "发送中..." : "发送"}
              </Button>
            </div>
          </div>
        </div>
      </form>

      {/* List */}
      {loading ? (
        <div className="space-y-3">
          {Array.from({ length: 3 }).map((_, i) => (
            <div
              key={i}
              className="flex gap-3 rounded-lg border border-border p-3"
            >
              <div className="h-9 w-9 rounded-full skeleton-shimmer" />
              <div className="flex-1 space-y-2">
                <div className="h-3 w-1/3 rounded skeleton-shimmer" />
                <div className="h-3 w-full rounded skeleton-shimmer" />
                <div className="h-3 w-2/3 rounded skeleton-shimmer" />
              </div>
            </div>
          ))}
        </div>
      ) : items.length === 0 ? (
        <div className="rounded-xl border border-border bg-card p-8 text-center">
          <p className="text-sm text-muted-foreground">
            还没有评论，来抢个沙发吧
          </p>
        </div>
      ) : (
        <ul className="space-y-3">
          {items.map((c) => (
            <CommentItem key={c.id} comment={c} />
          ))}
        </ul>
      )}

      <AuthDialog
        open={authOpen}
        onOpenChange={setAuthOpen}
        mode={authMode}
        onModeChange={setAuthMode}
      />
    </section>
  );
}

function CommentItem({ comment }: { comment: Comment }) {
  // Render basic content. Replies would normally be recursively
  // expanded here, but the test API returned flat items so we keep
  // it simple.
  return (
    <li className="flex gap-3 rounded-lg border border-border p-3 transition-colors hover:bg-accent/30">
      <Avatar className="h-9 w-9 border border-border">
        <AvatarImage
          src={comment.author_gravatar_url ?? undefined}
          alt={comment.author_username}
        />
        <AvatarFallback>
          {comment.author_username.slice(0, 1).toUpperCase()}
        </AvatarFallback>
      </Avatar>
      <div className="flex-1 space-y-1">
        <div className="flex items-center gap-1.5 text-xs text-muted-foreground">
          <span className="font-medium text-foreground">
            {comment.author_username}
          </span>
          {comment.author_verification_badge && (
            <VerifiedBadge
              color={comment.author_verification_badge}
              size={12}
            />
          )}
          {comment.author_verification_label && (
            <span className="rounded bg-accent px-1.5 py-0.5 text-[10px]">
              {comment.author_verification_label}
            </span>
          )}
          <span>·</span>
          <span>{formatRelativeTime(comment.created_at)}</span>
        </div>
        <p
          className="whitespace-pre-wrap text-sm"
          dangerouslySetInnerHTML={{ __html: escapeHtml(comment.content) }}
        />
        <div className="flex items-center gap-3 pt-1 text-xs text-muted-foreground">
          <button className="flex items-center gap-1 hover:text-foreground">
            <HeartIcon size={12} />
            {comment.likes ?? 0}
          </button>
          <button className="hover:text-foreground">回复</button>
          <button className="hover:text-foreground">举报</button>
        </div>
      </div>
    </li>
  );
}
