"use client";

/**
 * Public vote (公投) views.
 *
 * - VoteList: ?view=votes  -> GET /api/votes
 * - VoteDetail: ?view=vote&vote=ID -> GET /api/votes/{id}, POST /api/votes/{id}/vote
 */

import * as React from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { api, type Vote, type Paginated } from "@/lib/api";
import { Button } from "@/components/ui/button";
import { Skeleton } from "@/components/ui/skeleton";
import {
  VoteIcon,
  ArrowLeftIcon,
  CheckIcon,
} from "@/components/icons";
import { useAuth } from "@/lib/auth";
import { useToast } from "@/hooks/use-toast";
import { useRoute } from "@/lib/route";
import { formatRelativeTime, formatDate } from "@/lib/format";
import { cn } from "@/lib/utils";

function asArray<T>(data: unknown): T[] {
  if (Array.isArray(data)) return data as T[];
  if (data && typeof data === "object" && "items" in data) {
    const items = (data as Paginated<T>).items;
    if (Array.isArray(items)) return items;
  }
  return [];
}

// ---------- Vote list ----------

export function VotesList() {
  const { goVote } = useRoute();
  const [refreshKey, setRefreshKey] = React.useState(0);
  const query = useQuery({
    queryKey: ["votes", refreshKey],
    queryFn: () => api.listVotes({ limit: 50 }),
    retry: false,
  });
  const items = asArray<Vote>(query.data);

  return (
    <div>
      <div className="mb-5 flex flex-wrap items-end justify-between gap-3 border-b border-border pb-4">
        <div>
          <h2 className="flex items-center gap-2 text-xl font-bold tracking-tight">
            <VoteIcon size={22} />
            公投
          </h2>
          <p className="mt-1 text-sm text-muted-foreground">
            社区公投。登录后可参与投票，结果实时显示。
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

      {query.isError && (
        <div className="mb-4 rounded-md border border-red-500/30 bg-red-500/5 px-4 py-3 text-sm text-red-700 dark:text-red-300">
          加载公投失败：{query.error instanceof Error ? query.error.message : "未知错误"}
        </div>
      )}

      {query.isLoading ? (
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
          {Array.from({ length: 4 }).map((_, i) => (
            <Skeleton key={i} className="h-32 w-full rounded-lg" />
          ))}
        </div>
      ) : items.length === 0 ? (
        <div className="flex flex-col items-center justify-center rounded-md border border-dashed border-border bg-card/50 px-6 py-12 text-center">
          <VoteIcon size={32} className="mb-3 text-muted-foreground" />
          <p className="text-sm font-medium">暂无公投</p>
          <p className="mt-1 max-w-md text-xs text-muted-foreground">
            当前没有进行中的公投。
          </p>
        </div>
      ) : (
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
          {items.map((v) => (
            <button
              key={v.id}
              onClick={() => goVote(v.id)}
              className="group flex flex-col rounded-lg border border-border bg-card p-4 text-left shadow-sm transition-all hover:shadow-md"
            >
              <div className="flex items-start justify-between gap-2">
                <h3 className="line-clamp-2 text-sm font-semibold leading-snug">
                  {v.title}
                </h3>
                <span
                  className={cn(
                    "shrink-0 rounded px-1.5 py-0.5 text-[10px] font-semibold uppercase tracking-wider",
                    voteStatusClass(v.status),
                  )}
                >
                  {voteStatusLabel(v.status)}
                </span>
              </div>
              {v.description && (
                <p className="mt-1 line-clamp-2 text-xs text-muted-foreground">
                  {v.description}
                </p>
              )}
              <div className="mt-3 flex items-center gap-3 text-xs text-muted-foreground">
                <span>{v.options?.length ?? 0} 个选项</span>
                {typeof v.total_votes === "number" && (
                  <span>· {v.total_votes} 票</span>
                )}
                {v.end_at && (
                  <span>· 截止 {formatDate(v.end_at)}</span>
                )}
              </div>
            </button>
          ))}
        </div>
      )}
    </div>
  );
}

function voteStatusClass(status?: string): string {
  const s = (status ?? "").toLowerCase();
  if (s === "open") return "bg-emerald-500/10 text-emerald-700 dark:text-emerald-300";
  if (s === "closed") return "bg-muted text-foreground/70";
  if (s === "upcoming") return "bg-amber-500/10 text-amber-700 dark:text-amber-300";
  return "bg-blue-500/10 text-blue-700 dark:text-blue-300";
}

function voteStatusLabel(status?: string): string {
  const s = (status ?? "").toLowerCase();
  if (s === "open") return "进行中";
  if (s === "closed") return "已结束";
  if (s === "upcoming") return "即将开始";
  return s || "未知";
}

// ---------- Vote detail ----------

export function VoteDetail({ voteId }: { voteId: string }) {
  const { user } = useAuth();
  const { goVotes } = useRoute();
  const { toast } = useToast();
  const qc = useQueryClient();
  const [submitting, setSubmitting] = React.useState(false);
  const [selectedOption, setSelectedOption] = React.useState<string | null>(null);

  const query = useQuery({
    queryKey: ["vote", voteId],
    queryFn: () => api.getVote(voteId),
    retry: false,
  });

  const voteMutation = useMutation({
    mutationFn: (optionId: string) => api.castVote(voteId, optionId),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["vote", voteId] });
      toast({ title: "投票成功" });
    },
    onError: (e: unknown) =>
      toast({
        title: "投票失败",
        description: e instanceof Error ? e.message : "请稍后重试",
        variant: "destructive",
      }),
  });

  if (query.isLoading) {
    return (
      <div className="mx-auto max-w-3xl space-y-3">
        <Skeleton className="h-12 w-2/3" />
        <Skeleton className="h-48 w-full" />
      </div>
    );
  }

  if (query.isError || !query.data) {
    return (
      <div className="mx-auto max-w-3xl rounded-md border border-red-500/30 bg-red-500/5 px-4 py-3 text-sm text-red-700 dark:text-red-300">
        加载公投失败：{query.error instanceof Error ? query.error.message : "未知错误"}
        <Button
          variant="outline"
          size="sm"
          className="ml-3 h-7"
          onClick={goVotes}
        >
          返回公投列表
        </Button>
      </div>
    );
  }

  const v = query.data;
  const isOpen = (v.status ?? "").toLowerCase() === "open";
  const total = v.total_votes ?? v.options.reduce((s, o) => s + (o.vote_count ?? 0), 0);
  const hasVoted = v.has_voted || !!v.voted_option_id;

  const submitVote = async () => {
    if (!user) {
      toast({
        title: "请先登录",
        description: "参与投票需要登录账号",
        variant: "destructive",
      });
      return;
    }
    if (!selectedOption) return;
    setSubmitting(true);
    try {
      await voteMutation.mutateAsync(selectedOption);
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <article className="mx-auto max-w-3xl">
      <Button variant="ghost" size="sm" className="mb-4 h-8" onClick={goVotes}>
        <ArrowLeftIcon size={14} className="mr-1" />
        返回公投列表
      </Button>

      <header className="border-b border-border pb-4">
        <div className="flex items-start justify-between gap-3">
          <h1 className="text-2xl font-bold leading-tight tracking-tight sm:text-3xl">
            {v.title}
          </h1>
          <span
            className={cn(
              "shrink-0 rounded px-2 py-0.5 text-[10px] font-semibold uppercase tracking-wider",
              voteStatusClass(v.status),
            )}
          >
            {voteStatusLabel(v.status)}
          </span>
        </div>
        {v.description && (
          <p className="mt-3 whitespace-pre-wrap text-sm text-muted-foreground">
            {v.description}
          </p>
        )}
        <div className="mt-3 flex flex-wrap items-center gap-3 text-xs text-muted-foreground">
          <span>共 {total} 票</span>
          {v.start_at && <span>· 开始 {formatDate(v.start_at)}</span>}
          {v.end_at && <span>· 截止 {formatDate(v.end_at)}</span>}
          <span>· {formatRelativeTime(v.created_at)}</span>
        </div>
      </header>

      <section className="mt-6 space-y-3">
        {!isOpen && hasVoted && (
          <div className="rounded-md border border-emerald-500/30 bg-emerald-500/5 px-3 py-2 text-xs text-emerald-700 dark:text-emerald-300">
            <CheckIcon size={14} className="mr-1 inline-block" />
            投票已结束，您已参与。
          </div>
        )}
        {!isOpen && !hasVoted && (
          <div className="rounded-md border border-amber-500/30 bg-amber-500/5 px-3 py-2 text-xs text-amber-700 dark:text-amber-300">
            投票已结束，您未参与。
          </div>
        )}
        {isOpen && hasVoted && (
          <div className="rounded-md border border-emerald-500/30 bg-emerald-500/5 px-3 py-2 text-xs text-emerald-700 dark:text-emerald-300">
            <CheckIcon size={14} className="mr-1 inline-block" />
            您已投票，以下为当前结果。
          </div>
        )}

        {v.options.map((o) => {
          const isVoted = v.voted_option_id === o.id || selectedOption === o.id;
          const count = o.vote_count ?? 0;
          const pct = total > 0 ? (count / total) * 100 : 0;
          const oPct = typeof o.percentage === "number" ? o.percentage : pct;
          const selectable = isOpen && !hasVoted;

          return (
            <button
              key={o.id}
              disabled={!selectable}
              onClick={() => setSelectedOption(o.id)}
              className={cn(
                "w-full overflow-hidden rounded-lg border bg-card text-left transition-all",
                isVoted
                  ? "border-primary ring-2 ring-primary/20"
                  : "border-border hover:border-primary/50",
                selectable ? "cursor-pointer" : "cursor-default",
              )}
            >
              <div className="relative px-4 py-3">
                {/* Progress bar background */}
                <div
                  className="absolute inset-0 bg-primary/10"
                  style={{ width: `${oPct}%` }}
                />
                <div className="relative flex items-center justify-between gap-3">
                  <div className="min-w-0 flex-1">
                    <p className="text-sm font-medium">{o.label}</p>
                    {o.description && (
                      <p className="mt-0.5 text-xs text-muted-foreground">
                        {o.description}
                      </p>
                    )}
                  </div>
                  <div className="flex items-center gap-2 text-xs text-muted-foreground">
                    {isVoted && (
                      <CheckIcon size={14} className="text-primary" />
                    )}
                    <span className="tabular-nums">
                      {oPct.toFixed(1)}% · {count} 票
                    </span>
                  </div>
                </div>
              </div>
            </button>
          );
        })}
      </section>

      {isOpen && !hasVoted && (
        <div className="mt-6 flex items-center justify-end gap-3">
          <Button
            variant="outline"
            size="sm"
            className="h-9"
            onClick={goVotes}
          >
            取消
          </Button>
          <Button
            size="sm"
            className="h-9"
            onClick={submitVote}
            disabled={!selectedOption || submitting}
          >
            {submitting ? "提交中..." : "提交投票"}
          </Button>
        </div>
      )}
    </article>
  );
}
