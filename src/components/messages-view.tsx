"use client";

/**
 * Messages view.
 *
 * Two-column layout on desktop:
 *  - Left: list of conversations (with unread badges).
 *  - Right: selected conversation thread + composer.
 *
 * The view also hosts a "通知" tab that lists site-wide
 * notifications (/api/notifications). The two tabs are switched
 * locally so the URL stays ?view=messages.
 */

import * as React from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import {
  api,
  type Conversation,
  type DirectMessage,
  type SiteNotification,
  type Paginated,
} from "@/lib/api";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import { Skeleton } from "@/components/ui/skeleton";
import {
  MailIcon,
  MessageIcon,
  PaperPlaneIcon,
  BellIcon,
  CheckIcon,
  VerifiedBadge,
  ArrowLeftIcon,
} from "@/components/icons";
import { useAuth } from "@/lib/auth";
import { useToast } from "@/hooks/use-toast";
import { useRoute } from "@/lib/route";
import { formatRelativeTime } from "@/lib/format";
import { cn } from "@/lib/utils";

function asArray<T>(data: unknown): T[] {
  if (Array.isArray(data)) return data as T[];
  if (data && typeof data === "object" && "items" in data) {
    const items = (data as Paginated<T>).items;
    if (Array.isArray(items)) return items;
  }
  return [];
}

type Tab = "conversations" | "notifications";

export function MessagesView({
  initialConversationId,
}: {
  initialConversationId?: string;
}) {
  const { user } = useAuth();
  const { goMessages } = useRoute();
  const { toast } = useToast();
  const qc = useQueryClient();
  const [tab, setTab] = React.useState<Tab>("conversations");
  const [activeId, setActiveId] = React.useState<string | undefined>(
    initialConversationId,
  );
  const [newMessage, setNewMessage] = React.useState("");
  const [sending, setSending] = React.useState(false);

  const conversationsQ = useQuery({
    queryKey: ["conversations"],
    queryFn: () => api.listConversations(),
    enabled: !!user,
    retry: false,
  });

  const notificationsQ = useQuery({
    queryKey: ["notifications"],
    queryFn: () => api.listNotifications({ limit: 50 }),
    enabled: !!user,
    retry: false,
  });

  const messagesQ = useQuery({
    queryKey: ["messages", activeId],
    queryFn: () =>
      activeId ? api.listMessages(activeId, { limit: 100 }) : Promise.resolve([]),
    enabled: !!activeId && !!user,
    retry: false,
  });

  const messages = asArray<DirectMessage>(messagesQ.data);
  const conversations = asArray<Conversation>(conversationsQ.data);
  const notifications = asArray<SiteNotification>(notificationsQ.data);
  const activeConversation = conversations.find((c) => c.id === activeId);

  // Auto mark-read when active conversation changes
  React.useEffect(() => {
    if (!activeId || !user) return;
    api
      .markConversationRead(activeId)
      .then(() => qc.invalidateQueries({ queryKey: ["conversations"] }))
      .catch(() => {});
  }, [activeId, user, qc]);

  // Scroll to bottom of message list when new messages arrive
  const scrollRef = React.useRef<HTMLDivElement>(null);
  React.useEffect(() => {
    scrollRef.current?.scrollTo({ top: scrollRef.current.scrollHeight });
  }, [messages.length]);

  const sendMessage = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!user || !newMessage.trim()) return;
    if (!activeId && !activeConversation) return;
    setSending(true);
    try {
      await api.sendMessage({
        conversation_id: activeId,
        recipient_uid: activeConversation?.peer_uid,
        content: newMessage.trim(),
      });
      setNewMessage("");
      qc.invalidateQueries({ queryKey: ["messages", activeId] });
      qc.invalidateQueries({ queryKey: ["conversations"] });
    } catch (err) {
      toast({
        title: "发送失败",
        description: err instanceof Error ? err.message : "请稍后重试",
        variant: "destructive",
      });
    } finally {
      setSending(false);
    }
  };

  const markAllNotificationsRead = async () => {
    try {
      await api.markAllNotificationsRead();
      qc.invalidateQueries({ queryKey: ["notifications"] });
      toast({ title: "已全部标记为已读" });
    } catch (err) {
      toast({
        title: "操作失败",
        description: err instanceof Error ? err.message : "请稍后重试",
        variant: "destructive",
      });
    }
  };

  const markNotificationRead = async (id: string) => {
    try {
      await api.markNotificationRead(id);
      qc.invalidateQueries({ queryKey: ["notifications"] });
    } catch (err) {
      toast({
        title: "操作失败",
        description: err instanceof Error ? err.message : "请稍后重试",
        variant: "destructive",
      });
    }
  };

  if (!user) {
    return (
      <div className="mx-auto max-w-2xl rounded-md border border-amber-500/40 bg-amber-500/5 px-4 py-3 text-sm text-amber-700 dark:text-amber-300">
        请先登录后查看消息与通知。
      </div>
    );
  }

  const unreadNotifications = notifications.filter((n) => !n.read).length;

  return (
    <div className="mx-auto max-w-5xl">
      <div className="mb-5 flex flex-wrap items-end justify-between gap-3 border-b border-border pb-4">
        <div>
          <h2 className="flex items-center gap-2 text-xl font-bold tracking-tight">
            <MailIcon size={22} />
            消息中心
          </h2>
          <p className="mt-1 text-sm text-muted-foreground">
            管理私信与站内通知。
          </p>
        </div>
        <div className="flex items-center gap-2">
          <button
            onClick={() => setTab("conversations")}
            className={cn(
              "rounded-md border px-3 py-1.5 text-xs font-medium transition-colors",
              tab === "conversations"
                ? "border-primary bg-primary text-primary-foreground"
                : "border-border bg-card hover:bg-accent",
            )}
          >
            <MessageIcon size={14} className="mr-1 inline-block" />
            私信
          </button>
          <button
            onClick={() => setTab("notifications")}
            className={cn(
              "rounded-md border px-3 py-1.5 text-xs font-medium transition-colors",
              tab === "notifications"
                ? "border-primary bg-primary text-primary-foreground"
                : "border-border bg-card hover:bg-accent",
            )}
          >
            <BellIcon size={14} className="mr-1 inline-block" />
            通知
            {unreadNotifications > 0 && (
              <span className="ml-1 rounded-full bg-red-500 px-1.5 text-[10px] text-white">
                {unreadNotifications}
              </span>
            )}
          </button>
        </div>
      </div>

      {tab === "conversations" ? (
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-[280px_1fr]">
          {/* Conversation list */}
          <aside className="rounded-lg border border-border bg-card">
            <div className="border-b border-border px-3 py-2 text-xs font-semibold uppercase tracking-wider text-muted-foreground">
              会话列表
            </div>
            <ul className="max-h-[480px] overflow-y-auto">
              {conversationsQ.isLoading ? (
                Array.from({ length: 4 }).map((_, i) => (
                  <li key={i} className="px-3 py-2">
                    <Skeleton className="h-12 w-full" />
                  </li>
                ))
              ) : conversations.length === 0 ? (
                <li className="px-3 py-8 text-center text-xs text-muted-foreground">
                  暂无私信会话
                </li>
              ) : (
                conversations.map((c) => (
                  <li key={c.id}>
                    <button
                      onClick={() => {
                        setActiveId(c.id);
                        goMessages(c.id);
                      }}
                      className={cn(
                        "flex w-full items-center gap-2 px-3 py-2 text-left transition-colors hover:bg-accent/50",
                        c.id === activeId && "bg-accent/60",
                      )}
                    >
                      <Avatar className="h-9 w-9 border border-border">
                        <AvatarImage src={c.peer_gravatar_url ?? undefined} alt={c.peer_username} />
                        <AvatarFallback>
                          {c.peer_username.slice(0, 1).toUpperCase()}
                        </AvatarFallback>
                      </Avatar>
                      <div className="min-w-0 flex-1">
                        <div className="flex items-center gap-1">
                          <span className="truncate text-sm font-medium">
                            {c.peer_username}
                          </span>
                          {c.peer_verification_badge && (
                            <VerifiedBadge size={12} color={c.peer_verification_badge ?? "yellow"} />
                          )}
                          {(c.unread_count ?? 0) > 0 && (
                            <span className="ml-auto rounded-full bg-red-500 px-1.5 text-[10px] text-white">
                              {c.unread_count}
                            </span>
                          )}
                        </div>
                        {c.last_message && (
                          <p className="truncate text-xs text-muted-foreground">
                            {c.last_message}
                          </p>
                        )}
                      </div>
                    </button>
                  </li>
                ))
              )}
            </ul>
          </aside>

          {/* Message thread */}
          <section className="flex h-[540px] flex-col rounded-lg border border-border bg-card">
            {!activeId ? (
              <div className="flex h-full flex-col items-center justify-center text-center text-sm text-muted-foreground">
                <MessageIcon size={32} className="mb-3" />
                <p>从左侧选择一个会话，或新建会话开始私信。</p>
              </div>
            ) : messagesQ.isLoading ? (
              <div className="flex-1 space-y-3 p-3">
                {Array.from({ length: 6 }).map((_, i) => (
                  <Skeleton key={i} className="h-12 w-3/4" />
                ))}
              </div>
            ) : (
              <>
                <header className="flex items-center gap-2 border-b border-border px-3 py-2">
                  <Avatar className="h-8 w-8 border border-border">
                    <AvatarImage src={activeConversation?.peer_gravatar_url ?? undefined} />
                    <AvatarFallback>
                      {(activeConversation?.peer_username ?? "U").slice(0, 1).toUpperCase()}
                    </AvatarFallback>
                  </Avatar>
                  <div className="min-w-0">
                    <p className="truncate text-sm font-medium">
                      {activeConversation?.peer_username ?? "—"}
                    </p>
                    {activeConversation?.last_message_at && (
                      <p className="text-xs text-muted-foreground">
                        最近活动 {formatRelativeTime(activeConversation.last_message_at)}
                      </p>
                    )}
                  </div>
                </header>
                <div ref={scrollRef} className="flex-1 space-y-2 overflow-y-auto p-3">
                  {messages.length === 0 ? (
                    <p className="py-8 text-center text-xs text-muted-foreground">
                      暂无消息
                    </p>
                  ) : (
                    messages.map((m) => {
                      const mine = m.sender_uid === user.uid;
                      return (
                        <div
                          key={m.id}
                          className={cn(
                            "flex",
                            mine ? "justify-end" : "justify-start",
                          )}
                        >
                          <div
                            className={cn(
                              "max-w-[78%] rounded-2xl px-3 py-2 text-sm",
                              mine
                                ? "bg-primary text-primary-foreground"
                                : "bg-muted text-foreground",
                            )}
                          >
                            <p className="whitespace-pre-wrap break-words">
                              {m.content}
                            </p>
                            <p
                              className={cn(
                                "mt-1 text-[10px]",
                                mine ? "text-primary-foreground/70" : "text-muted-foreground",
                              )}
                            >
                              {formatRelativeTime(m.created_at)}
                            </p>
                          </div>
                        </div>
                      );
                    })
                  )}
                </div>
                <form
                  onSubmit={sendMessage}
                  className="flex items-end gap-2 border-t border-border p-3"
                >
                  <Textarea
                    value={newMessage}
                    onChange={(e) => setNewMessage(e.target.value)}
                    placeholder="输入消息..."
                    rows={2}
                    maxLength={1000}
                    className="resize-none"
                    onKeyDown={(e) => {
                      if (e.key === "Enter" && !e.shiftKey) {
                        e.preventDefault();
                        sendMessage(e);
                      }
                    }}
                  />
                  <Button
                    type="submit"
                    size="icon"
                    className="h-10 w-10"
                    disabled={sending || !newMessage.trim()}
                    aria-label="发送"
                  >
                    <PaperPlaneIcon size={16} />
                  </Button>
                </form>
              </>
            )}
          </section>
        </div>
      ) : (
        <div>
          <div className="mb-3 flex items-center justify-between">
            <p className="text-sm text-muted-foreground">
              共 {notifications.length} 条通知
              {unreadNotifications > 0 && `（${unreadNotifications} 条未读）`}
            </p>
            <Button
              variant="outline"
              size="sm"
              className="h-8"
              onClick={markAllNotificationsRead}
              disabled={unreadNotifications === 0}
            >
              <CheckIcon size={14} className="mr-1.5" />
              全部标记已读
            </Button>
          </div>
          {notificationsQ.isLoading ? (
            <div className="space-y-2">
              {Array.from({ length: 5 }).map((_, i) => (
                <Skeleton key={i} className="h-16 w-full" />
              ))}
            </div>
          ) : notifications.length === 0 ? (
            <div className="flex flex-col items-center justify-center rounded-md border border-dashed border-border bg-card/50 px-6 py-12 text-center">
              <BellIcon size={32} className="mb-3 text-muted-foreground" />
              <p className="text-sm font-medium">暂无通知</p>
            </div>
          ) : (
            <ul className="space-y-2">
              {notifications.map((n) => (
                <li
                  key={n.id}
                  className={cn(
                    "rounded-md border border-border bg-card p-3",
                    !n.read && "border-l-4 border-l-primary",
                  )}
                >
                  <div className="flex items-start justify-between gap-2">
                    <div className="min-w-0 flex-1">
                      <p className="text-sm font-medium">{n.title ?? "通知"}</p>
                      {n.content && (
                        <p className="mt-1 text-sm text-muted-foreground">{n.content}</p>
                      )}
                      <p className="mt-1 text-xs text-muted-foreground">
                        {formatRelativeTime(n.created_at)}
                        {n.actor_username && ` · 来自 ${n.actor_username}`}
                      </p>
                    </div>
                    <div className="flex items-center gap-1">
                      {n.link && (
                        <Button
                          variant="ghost"
                          size="sm"
                          className="h-7 text-xs"
                          onClick={() => {
                            if (typeof window !== "undefined") {
                              window.open(n.link!, "_blank", "noopener,noreferrer");
                            }
                          }}
                        >
                          查看
                        </Button>
                      )}
                      {!n.read && (
                        <Button
                          variant="ghost"
                          size="sm"
                          className="h-7 text-xs"
                          onClick={() => markNotificationRead(n.id)}
                        >
                          <ArrowLeftIcon size={12} className="mr-1" />
                          标记已读
                        </Button>
                      )}
                    </div>
                  </div>
                </li>
              ))}
            </ul>
          )}
        </div>
      )}
    </div>
  );
}
