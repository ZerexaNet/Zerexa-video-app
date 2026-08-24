"use client";

/**
 * Tickets view.
 *
 * List, create, detail, reply, close / reopen.
 * Routes: ?view=tickets, ?view=ticket&tid=, ?view=ticket-new
 */

import * as React from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { api, type Ticket, type Paginated } from "@/lib/api";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Label } from "@/components/ui/label";
import { Skeleton } from "@/components/ui/skeleton";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import {
  TicketIcon,
  PlusIcon,
  ArrowLeftIcon,
  ReplyIcon,
  CheckSquareIcon,
  XSquareIcon,
  InboxIcon,
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

// ---------- Ticket list ----------

const STATUSES: { id: string; label: string }[] = [
  { id: "all", label: "全部" },
  { id: "open", label: "进行中" },
  { id: "pending", label: "待回复" },
  { id: "resolved", label: "已解决" },
  { id: "closed", label: "已关闭" },
];

export function TicketsList() {
  const { user } = useAuth();
  const { goTicket, goTicketNew } = useRoute();
  const [status, setStatus] = React.useState("all");
  const [refreshKey, setRefreshKey] = React.useState(0);

  const query = useQuery({
    queryKey: ["tickets", status, refreshKey],
    queryFn: () =>
      api.listTickets({ status: status === "all" ? undefined : status, limit: 50 }),
    enabled: !!user,
    retry: false,
  });

  const items = asArray<Ticket>(query.data);

  if (!user) {
    return (
      <div className="mx-auto max-w-2xl rounded-md border border-amber-500/40 bg-amber-500/5 px-4 py-3 text-sm text-amber-700 dark:text-amber-300">
        请先登录后查看工单。
      </div>
    );
  }

  return (
    <div>
      <div className="mb-5 flex flex-wrap items-end justify-between gap-3 border-b border-border pb-4">
        <div>
          <h2 className="flex items-center gap-2 text-xl font-bold tracking-tight">
            <TicketIcon size={22} />
            工单
          </h2>
          <p className="mt-1 text-sm text-muted-foreground">
            提交问题反馈、申诉或申请。客服会在工单详情页回复。
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
          <Button size="sm" className="h-8" onClick={goTicketNew}>
            <PlusIcon size={14} className="mr-1.5" />
            提交工单
          </Button>
        </div>
      </div>

      <div className="mb-4 flex flex-wrap items-center gap-2">
        {STATUSES.map((s) => {
          const active = status === s.id;
          return (
            <button
              key={s.id}
              onClick={() => setStatus(s.id)}
              className={cn(
                "rounded-md border px-3 py-1.5 text-xs font-medium transition-colors",
                active
                  ? "border-primary bg-primary text-primary-foreground"
                  : "border-border bg-card hover:bg-accent",
              )}
            >
              {s.label}
            </button>
          );
        })}
      </div>

      {query.isError && (
        <div className="mb-4 rounded-md border border-red-500/30 bg-red-500/5 px-4 py-3 text-sm text-red-700 dark:text-red-300">
          加载工单失败：{query.error instanceof Error ? query.error.message : "未知错误"}
        </div>
      )}

      {query.isLoading ? (
        <div className="space-y-2">
          {Array.from({ length: 4 }).map((_, i) => (
            <Skeleton key={i} className="h-20 w-full" />
          ))}
        </div>
      ) : items.length === 0 ? (
        <div className="flex flex-col items-center justify-center rounded-md border border-dashed border-border bg-card/50 px-6 py-12 text-center">
          <InboxIcon size={32} className="mb-3 text-muted-foreground" />
          <p className="text-sm font-medium">没有工单</p>
          <p className="mt-1 max-w-md text-xs text-muted-foreground">
            点击右上角「提交工单」创建第一个工单。
          </p>
        </div>
      ) : (
        <ul className="divide-y divide-border rounded-md border border-border bg-card">
          {items.map((t) => (
            <li key={t.id}>
              <button
                onClick={() => goTicket(t.id)}
                className="flex w-full items-center justify-between gap-3 px-4 py-3 text-left transition-colors hover:bg-accent/40"
              >
                <div className="min-w-0 flex-1">
                  <p className="truncate text-sm font-medium">{t.title}</p>
                  <p className="mt-0.5 truncate text-xs text-muted-foreground">
                    #{t.id.slice(0, 8)} · {t.category ?? "未分类"} · {formatRelativeTime(t.created_at)}
                  </p>
                </div>
                <span
                  className={cn(
                    "rounded px-1.5 py-0.5 text-[10px] font-semibold uppercase tracking-wider",
                    ticketBadgeClass(t.status),
                  )}
                >
                  {ticketStatusLabel(t.status)}
                </span>
              </button>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}

function ticketBadgeClass(status?: string): string {
  const s = (status ?? "").toLowerCase();
  if (s === "resolved") return "bg-emerald-500/10 text-emerald-700 dark:text-emerald-300";
  if (s === "closed") return "bg-muted text-foreground/70";
  if (s === "pending") return "bg-amber-500/10 text-amber-700 dark:text-amber-300";
  return "bg-blue-500/10 text-blue-700 dark:text-blue-300";
}

function ticketStatusLabel(status?: string): string {
  const s = (status ?? "").toLowerCase();
  if (s === "resolved") return "已解决";
  if (s === "closed") return "已关闭";
  if (s === "pending") return "待回复";
  return "进行中";
}

// ---------- Ticket create ----------

export function TicketCreate() {
  const { user } = useAuth();
  const { goTickets } = useRoute();
  const { toast } = useToast();
  const [title, setTitle] = React.useState("");
  const [content, setContent] = React.useState("");
  const [category, setCategory] = React.useState("general");
  const [priority, setPriority] = React.useState("normal");
  const [saving, setSaving] = React.useState(false);

  if (!user) {
    return (
      <div className="mx-auto max-w-2xl rounded-md border border-amber-500/40 bg-amber-500/5 px-4 py-3 text-sm text-amber-700 dark:text-amber-300">
        请先登录后提交工单。
      </div>
    );
  }

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!title.trim() || !content.trim()) return;
    setSaving(true);
    try {
      const resp = (await api.createTicket({
        title: title.trim(),
        content: content.trim(),
        category,
        priority,
      })) as { id?: string };
      toast({ title: "工单已提交" });
      goTickets();
      if (resp.id) {
        // navigate to detail via the route store
        useRoute.getState().goTicket(resp.id);
      }
    } catch (err) {
      toast({
        title: "提交失败",
        description: err instanceof Error ? err.message : "请稍后重试",
        variant: "destructive",
      });
    } finally {
      setSaving(false);
    }
  };

  return (
    <form onSubmit={submit} className="mx-auto max-w-2xl space-y-5">
      <div className="flex items-center justify-between">
        <h2 className="text-xl font-bold tracking-tight">提交工单</h2>
        <Button variant="ghost" size="sm" className="h-8" onClick={goTickets}>
          <ArrowLeftIcon size={14} className="mr-1" />
          返回列表
        </Button>
      </div>

      <div className="space-y-1.5">
        <Label htmlFor="t-title">标题</Label>
        <Input
          id="t-title"
          value={title}
          onChange={(e) => setTitle(e.target.value)}
          maxLength={120}
          placeholder="简要描述问题"
          required
        />
      </div>

      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
        <div className="space-y-1.5">
          <Label htmlFor="t-cat">分类</Label>
          <Select value={category} onValueChange={setCategory}>
            <SelectTrigger id="t-cat">
              <SelectValue placeholder="选择分类" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="general">综合咨询</SelectItem>
              <SelectItem value="account">账号问题</SelectItem>
              <SelectItem value="content">内容申诉</SelectItem>
              <SelectItem value="billing">充值 / 计费</SelectItem>
              <SelectItem value="bug">功能缺陷</SelectItem>
              <SelectItem value="other">其它</SelectItem>
            </SelectContent>
          </Select>
        </div>
        <div className="space-y-1.5">
          <Label htmlFor="t-pri">优先级</Label>
          <Select value={priority} onValueChange={setPriority}>
            <SelectTrigger id="t-pri">
              <SelectValue placeholder="选择优先级" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="low">低</SelectItem>
              <SelectItem value="normal">普通</SelectItem>
              <SelectItem value="high">高</SelectItem>
              <SelectItem value="urgent">紧急</SelectItem>
            </SelectContent>
          </Select>
        </div>
      </div>

      <div className="space-y-1.5">
        <Label htmlFor="t-content">详细描述</Label>
        <Textarea
          id="t-content"
          value={content}
          onChange={(e) => setContent(e.target.value)}
          rows={8}
          placeholder="详细描述遇到的问题，包含时间、操作步骤、期望结果等"
          required
        />
      </div>

      <div className="flex items-center justify-end gap-2 border-t border-border pt-4">
        <Button
          type="button"
          variant="outline"
          size="sm"
          onClick={goTickets}
        >
          取消
        </Button>
        <Button
          type="submit"
          size="sm"
          disabled={saving || !title.trim() || !content.trim()}
        >
          {saving ? "提交中..." : "提交工单"}
        </Button>
      </div>
    </form>
  );
}

// ---------- Ticket detail ----------

export function TicketDetail({ ticketId }: { ticketId: string }) {
  const { user } = useAuth();
  const { goTickets } = useRoute();
  const { toast } = useToast();
  const qc = useQueryClient();
  const [reply, setReply] = React.useState("");
  const [busy, setBusy] = React.useState(false);

  const query = useQuery({
    queryKey: ["ticket", ticketId],
    queryFn: () => api.getTicket(ticketId),
    enabled: !!user,
    retry: false,
  });

  const replyMutation = useMutation({
    mutationFn: (content: string) => api.replyTicket(ticketId, content),
    onSuccess: () => {
      setReply("");
      qc.invalidateQueries({ queryKey: ["ticket", ticketId] });
      toast({ title: "回复已发送" });
    },
    onError: (e: unknown) =>
      toast({
        title: "回复失败",
        description: e instanceof Error ? e.message : "请稍后重试",
        variant: "destructive",
      }),
  });

  const closeMutation = useMutation({
    mutationFn: () => api.closeTicket(ticketId),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["ticket", ticketId] });
      qc.invalidateQueries({ queryKey: ["tickets"] });
      toast({ title: "工单已关闭" });
    },
    onError: (e: unknown) =>
      toast({
        title: "操作失败",
        description: e instanceof Error ? e.message : "请稍后重试",
        variant: "destructive",
      }),
  });

  const reopenMutation = useMutation({
    mutationFn: () => api.reopenTicket(ticketId),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["ticket", ticketId] });
      qc.invalidateQueries({ queryKey: ["tickets"] });
      toast({ title: "工单已重新打开" });
    },
    onError: (e: unknown) =>
      toast({
        title: "操作失败",
        description: e instanceof Error ? e.message : "请稍后重试",
        variant: "destructive",
      }),
  });

  if (!user) {
    return (
      <div className="mx-auto max-w-2xl rounded-md border border-amber-500/40 bg-amber-500/5 px-4 py-3 text-sm text-amber-700 dark:text-amber-300">
        请先登录后查看工单。
      </div>
    );
  }

  if (query.isLoading) {
    return (
      <div className="mx-auto max-w-3xl space-y-3">
        <Skeleton className="h-10 w-2/3" />
        <Skeleton className="h-32 w-full" />
      </div>
    );
  }

  if (query.isError || !query.data) {
    return (
      <div className="mx-auto max-w-3xl rounded-md border border-red-500/30 bg-red-500/5 px-4 py-3 text-sm text-red-700 dark:text-red-300">
        加载工单失败：{query.error instanceof Error ? query.error.message : "未知错误"}
        <Button
          variant="outline"
          size="sm"
          className="ml-3 h-7"
          onClick={goTickets}
        >
          返回列表
        </Button>
      </div>
    );
  }

  const t = query.data;
  const isClosed = (t.status ?? "").toLowerCase() === "closed";
  const isResolved = (t.status ?? "").toLowerCase() === "resolved";

  const submitReply = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!reply.trim()) return;
    setBusy(true);
    try {
      await replyMutation.mutateAsync(reply.trim());
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="mx-auto max-w-3xl">
      <Button variant="ghost" size="sm" className="mb-4 h-8" onClick={goTickets}>
        <ArrowLeftIcon size={14} className="mr-1" />
        返回列表
      </Button>

      <div className="rounded-lg border border-border bg-card p-5 shadow-sm">
        <div className="flex items-start justify-between gap-3">
          <div className="min-w-0 flex-1">
            <h1 className="text-xl font-bold leading-tight">{t.title}</h1>
            <p className="mt-1 text-xs text-muted-foreground">
              #{t.id.slice(0, 8)} · {t.category ?? "未分类"} · 提交于 {formatRelativeTime(t.created_at)}
              {t.updated_at && ` · 更新于 ${formatRelativeTime(t.updated_at)}`}
            </p>
          </div>
          <span
            className={cn(
              "shrink-0 rounded px-2 py-0.5 text-[10px] font-semibold uppercase tracking-wider",
              ticketBadgeClass(t.status),
            )}
          >
            {ticketStatusLabel(t.status)}
          </span>
        </div>

        <div className="mt-4 whitespace-pre-wrap break-words text-sm text-foreground/90">
          {t.content}
        </div>

        <div className="mt-4 flex items-center gap-2 border-t border-border pt-3 text-xs text-muted-foreground">
          <Avatar className="h-6 w-6 border border-border">
            <AvatarImage src={t.creator_gravatar_url ?? undefined} alt={t.creator_username ?? "创建者"} />
            <AvatarFallback>{(t.creator_username ?? "U").slice(0, 1).toUpperCase()}</AvatarFallback>
          </Avatar>
          <span>{t.creator_username ?? "—"}</span>
          {t.priority && (
            <>
              <span>·</span>
              <span>优先级：{t.priority}</span>
            </>
          )}
        </div>
      </div>

      {/* Replies */}
      <section className="mt-6 space-y-3">
        <h3 className="text-sm font-semibold uppercase tracking-wider text-muted-foreground">
          回复（{t.replies?.length ?? 0}）
        </h3>
        {t.replies && t.replies.length > 0 ? (
          <ul className="space-y-3">
            {t.replies.map((r) => (
              <li
                key={r.id}
                className={cn(
                  "rounded-md border border-border bg-card p-3",
                  r.is_staff && "border-l-4 border-l-primary",
                )}
              >
                <div className="flex items-center gap-2">
                  <Avatar className="h-7 w-7 border border-border">
                    <AvatarImage src={r.author_gravatar_url ?? undefined} alt={r.author_username} />
                    <AvatarFallback>{r.author_username.slice(0, 1).toUpperCase()}</AvatarFallback>
                  </Avatar>
                  <div className="text-xs">
                    <p className="font-medium">{r.author_username}</p>
                    <p className="text-muted-foreground">{formatRelativeTime(r.created_at)}</p>
                  </div>
                  {r.is_staff && (
                    <span className="ml-auto rounded bg-primary/10 px-1.5 py-0.5 text-[10px] font-semibold uppercase text-primary">
                      客服
                    </span>
                  )}
                </div>
                <p className="mt-2 whitespace-pre-wrap break-words text-sm">
                  {r.content}
                </p>
              </li>
            ))}
          </ul>
        ) : (
          <p className="rounded-md border border-dashed border-border px-3 py-6 text-center text-xs text-muted-foreground">
            暂无回复
          </p>
        )}
      </section>

      {/* Action bar */}
      <div className="mt-6 rounded-lg border border-border bg-card p-4 shadow-sm">
        {!isClosed && !isResolved ? (
          <form onSubmit={submitReply} className="space-y-3">
            <Label htmlFor="t-reply">添加回复</Label>
            <Textarea
              id="t-reply"
              value={reply}
              onChange={(e) => setReply(e.target.value)}
              rows={4}
              placeholder="详细描述问题进展或补充信息"
            />
            <div className="flex items-center justify-between">
              <Button
                type="button"
                variant="outline"
                size="sm"
                className="h-8"
                onClick={() => {
                  if (window.confirm("确认关闭此工单？关闭后仍可重新打开。")) {
                    closeMutation.mutate();
                  }
                }}
                disabled={closeMutation.isPending}
              >
                <XSquareIcon size={14} className="mr-1" />
                关闭工单
              </Button>
              <Button
                type="submit"
                size="sm"
                disabled={busy || !reply.trim()}
              >
                <ReplyIcon size={14} className="mr-1" />
                {busy ? "发送中..." : "发送回复"}
              </Button>
            </div>
          </form>
        ) : (
          <div className="flex flex-col items-start gap-3">
            <p className="text-sm text-muted-foreground">
              此工单当前状态为 <strong>{ticketStatusLabel(t.status)}</strong>，无法继续回复。
            </p>
            <Button
              variant="outline"
              size="sm"
              className="h-8"
              onClick={() => reopenMutation.mutate()}
              disabled={reopenMutation.isPending}
            >
              <CheckSquareIcon size={14} className="mr-1" />
              重新打开
            </Button>
          </div>
        )}
      </div>
    </div>
  );
}
