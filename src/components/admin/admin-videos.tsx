"use client";

/**
 * Admin videos view.
 *
 * Lists videos from /api/admin/videos with a status filter
 * (pending / approved / rejected). For each row exposes:
 *  - 通过 (approve)   -> PUT /api/videos/{id} {status:"approved"}
 *  - 拒绝 (reject)    -> PUT /api/videos/{id} {status:"rejected"}
 *  - 删除 (delete)    -> DELETE /api/videos/{id}
 *
 * The list uses TanStack Query for caching and refetches after
 * each mutation. Optimistic UI is intentionally avoided for
 * admin actions - we wait for the server's verdict before
 * touching the cache so we never show a misleading state.
 */

import * as React from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { api, type VideoListItem, type Paginated } from "@/lib/api";
import { Button } from "@/components/ui/button";
import {
  AdminSectionHeader,
  AdminTable,
  Th,
  Td,
  StatusBadge,
  EmptyState,
  ErrorBanner,
  asArray,
} from "@/components/admin/admin-shared";
import { AdminRefreshButton } from "@/components/admin/admin-shell";
import {
  CheckCircleIcon,
  XCircleIcon,
  TrashIcon,
  EyeIcon,
  ExternalLinkIcon,
  VideoIcon,
} from "@/components/icons";
import { useToast } from "@/hooks/use-toast";
import { useRoute } from "@/lib/route";
import { formatRelativeTime, formatViews, splitCategory } from "@/lib/format";

type StatusFilter = "pending" | "approved" | "rejected" | undefined;

const FILTERS: { id: StatusFilter; label: string }[] = [
  { id: undefined, label: "全部" },
  { id: "pending", label: "待审核" },
  { id: "approved", label: "已通过" },
  { id: "rejected", label: "已拒绝" },
];

export function AdminVideos() {
  const qc = useQueryClient();
  const { toast } = useToast();
  const { goWatch } = useRoute();
  const [filter, setFilter] = React.useState<StatusFilter>(undefined);
  const [page, setPage] = React.useState(0);
  const pageSize = 20;
  const [refreshKey, setRefreshKey] = React.useState(0);

  const query = useQuery({
    queryKey: ["admin", "videos", filter, page, refreshKey],
    queryFn: () =>
      api.adminListVideos({
        status: filter,
        limit: pageSize,
        offset: page * pageSize,
      }),
    retry: false,
  });

  const items = asArray<VideoListItem>(query.data);
  const total =
    query.data && !Array.isArray(query.data) &&
    typeof query.data === "object" && "total" in query.data
      ? Number((query.data as Paginated<VideoListItem>).total)
      : items.length;

  const updateMutation = useMutation({
    mutationFn: ({ id, status }: { id: string; status: "approved" | "rejected" }) =>
      api.updateVideo(id, { status }),
    onSuccess: (_d, vars) => {
      toast({
        title: vars.status === "approved" ? "已通过" : "已拒绝",
        description: `视频 ${vars.id} 已更新状态`,
      });
      qc.invalidateQueries({ queryKey: ["admin", "videos"] });
    },
    onError: (e: unknown) => {
      toast({
        title: "操作失败",
        description: e instanceof Error ? e.message : "请稍后重试",
        variant: "destructive",
      });
    },
  });

  const deleteMutation = useMutation({
    mutationFn: (id: string) => api.deleteVideo(id),
    onSuccess: (_d, id) => {
      toast({ title: "已删除", description: `视频 ${id} 已删除` });
      qc.invalidateQueries({ queryKey: ["admin", "videos"] });
    },
    onError: (e: unknown) => {
      toast({
        title: "删除失败",
        description: e instanceof Error ? e.message : "请稍后重试",
        variant: "destructive",
      });
    },
  });

  return (
    <div>
      <AdminSectionHeader
        title="视频审核"
        description="列出全站视频，按状态过滤，并执行通过 / 拒绝 / 删除操作。"
        actions={
          <AdminRefreshButton
            loading={query.isFetching}
            onClick={() => setRefreshKey((k) => k + 1)}
          />
        }
      />

      <div className="mb-4 flex flex-wrap items-center gap-2">
        {FILTERS.map((f) => {
          const active = filter === f.id;
          return (
            <button
              key={f.label}
              onClick={() => {
                setFilter(f.id);
                setPage(0);
              }}
              className={`rounded-md border px-3 py-1.5 text-xs font-medium transition-colors ${
                active
                  ? "border-primary bg-primary text-primary-foreground"
                  : "border-border bg-card hover:bg-accent"
              }`}
            >
              {f.label}
            </button>
          );
        })}
        <span className="ml-auto text-xs text-muted-foreground">
          共 {total} 条
        </span>
      </div>

      {query.isError && (
        <ErrorBanner
          message={`加载视频列表失败: ${
            query.error instanceof Error ? query.error.message : "未知错误"
          }`}
        />
      )}

      {query.isLoading ? (
        <div className="space-y-2">
          {Array.from({ length: 6 }).map((_, i) => (
            <div
              key={i}
              className="h-16 animate-pulse rounded-md bg-muted/50"
            />
          ))}
        </div>
      ) : items.length === 0 ? (
        <EmptyState
          title="没有符合条件的视频"
          description="尝试切换过滤条件或刷新。"
          icon={<VideoIcon size={32} />}
        />
      ) : (
        <AdminTable
          head={
            <tr>
              <Th>视频</Th>
              <Th className="hidden md:table-cell">UP 主</Th>
              <Th className="hidden sm:table-cell">分类</Th>
              <Th className="hidden md:table-cell">数据</Th>
              <Th>状态</Th>
              <Th>操作</Th>
            </tr>
          }
        >
          {items.map((v) => {
            const { root } = splitCategory(v.category);
            return (
              <tr key={v.id} className="hover:bg-accent/40">
                <Td>
                  <div className="flex items-center gap-2">
                    <div className="h-10 w-16 shrink-0 overflow-hidden rounded bg-muted">
                      {v.cover_url || v.external_cover_url ? (
                        <img
                          src={
                            api.resolveAsset(v.cover_url) ??
                            v.external_cover_url ??
                            ""
                          }
                          alt=""
                          className="h-full w-full object-cover"
                          loading="lazy"
                        />
                      ) : (
                        <div className="flex h-full items-center justify-center text-muted-foreground">
                          <VideoIcon size={16} />
                        </div>
                      )}
                    </div>
                    <div className="min-w-0">
                      <p className="truncate text-sm font-medium">
                        {v.title}
                      </p>
                      <p className="text-xs text-muted-foreground">
                        {formatRelativeTime(v.created_at)}
                      </p>
                    </div>
                  </div>
                </Td>
                <Td className="hidden md:table-cell">
                  <span className="text-xs">{v.author_username}</span>
                  <p className="text-[10px] text-muted-foreground">
                    UID: {v.author_uid}
                  </p>
                </Td>
                <Td className="hidden sm:table-cell text-xs">{root}</Td>
                <Td className="hidden md:table-cell text-xs text-muted-foreground">
                  <p>播放 {formatViews(v.views)}</p>
                  <p>点赞 {formatViews(v.likes)}</p>
                </Td>
                <Td>
                  <StatusBadge
                    status={
                      // The admin list endpoint may or may not include
                      // status. When absent we infer from the active
                      // filter so the badge still reads correctly.
                      (v as VideoListItem & { status?: string }).status ??
                      filter
                    }
                  />
                </Td>
                <Td>
                  <div className="flex items-center gap-1">
                    <Button
                      variant="ghost"
                      size="icon"
                      className="h-7 w-7"
                      onClick={() => goWatch(v.id)}
                      aria-label="观看"
                      title="在前台观看"
                    >
                      <EyeIcon size={14} />
                    </Button>
                    <Button
                      variant="ghost"
                      size="icon"
                      className="h-7 w-7 text-emerald-600 hover:bg-emerald-500/10 hover:text-emerald-700"
                      onClick={() =>
                        updateMutation.mutate({ id: v.id, status: "approved" })
                      }
                      disabled={
                        updateMutation.isPending ||
                        filter === "approved"
                      }
                      aria-label="通过"
                      title="通过审核"
                    >
                      <CheckCircleIcon size={14} />
                    </Button>
                    <Button
                      variant="ghost"
                      size="icon"
                      className="h-7 w-7 text-amber-600 hover:bg-amber-500/10 hover:text-amber-700"
                      onClick={() =>
                        updateMutation.mutate({ id: v.id, status: "rejected" })
                      }
                      disabled={
                        updateMutation.isPending ||
                        filter === "rejected"
                      }
                      aria-label="拒绝"
                      title="拒绝审核"
                    >
                      <XCircleIcon size={14} />
                    </Button>
                    <Button
                      variant="ghost"
                      size="icon"
                      className="h-7 w-7 text-red-600 hover:bg-red-500/10 hover:text-red-700"
                      onClick={() => {
                        if (
                          window.confirm(
                            `确认删除视频「${v.title}」？此操作不可撤销。`,
                          )
                        ) {
                          deleteMutation.mutate(v.id);
                        }
                      }}
                      disabled={deleteMutation.isPending}
                      aria-label="删除"
                      title="删除视频"
                    >
                      <TrashIcon size={14} />
                    </Button>
                  </div>
                </Td>
              </tr>
            );
          })}
        </AdminTable>
      )}

      {/* Pagination */}
      {total > pageSize && (
        <div className="mt-4 flex items-center justify-between">
          <Button
            variant="outline"
            size="sm"
            className="h-8"
            onClick={() => setPage((p) => Math.max(0, p - 1))}
            disabled={page === 0 || query.isFetching}
          >
            上一页
          </Button>
          <span className="text-xs text-muted-foreground">
            第 {page + 1} 页 / 共 {Math.max(1, Math.ceil(total / pageSize))} 页
          </span>
          <Button
            variant="outline"
            size="sm"
            className="h-8"
            onClick={() =>
              setPage((p) =>
                Math.min(Math.max(0, Math.ceil(total / pageSize) - 1), p + 1),
              )
            }
            disabled={
              page >= Math.ceil(total / pageSize) - 1 || query.isFetching
            }
          >
            下一页
          </Button>
        </div>
      )}

      <p className="mt-4 flex items-center gap-1 text-xs text-muted-foreground">
        <ExternalLinkIcon size={12} />
        操作通过 PUT /api/videos/{`{id}`} 与 DELETE /api/videos/{`{id}`} 提交。
      </p>
    </div>
  );
}
