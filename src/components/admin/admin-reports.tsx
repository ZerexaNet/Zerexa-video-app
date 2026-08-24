"use client";

/**
 * Admin reports view.
 *
 * Lists reports from /api/admin/reports with status filter
 * (open / closed). The upstream API does not currently expose a
 * public "resolve" / "close" route, so the table is read-only
 * with target deep-link.
 */

import * as React from "react";
import { useQuery } from "@tanstack/react-query";
import { api, type AdminReport } from "@/lib/api";
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
import { FlagIcon } from "@/components/icons";
import { useRoute } from "@/lib/route";
import { formatRelativeTime } from "@/lib/format";

type ReportFilter = "open" | "closed" | undefined;

const FILTERS: { id: ReportFilter; label: string }[] = [
  { id: undefined, label: "全部" },
  { id: "open", label: "待处理" },
  { id: "closed", label: "已关闭" },
];

export function AdminReports() {
  const { goWatch } = useRoute();
  const [filter, setFilter] = React.useState<ReportFilter>(undefined);
  const [page, setPage] = React.useState(0);
  const [refreshKey, setRefreshKey] = React.useState(0);
  const pageSize = 20;

  const query = useQuery({
    queryKey: ["admin", "reports", filter, page, refreshKey],
    queryFn: () =>
      api.adminListReports({
        status: filter,
        limit: pageSize,
        offset: page * pageSize,
      }),
    retry: false,
  });

  const items = asArray<AdminReport>(query.data);

  return (
    <div>
      <AdminSectionHeader
        title="举报处理"
        description="查看社区提交的举报。点击目标可跳转到对应视频详情。"
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
          当前返回 {items.length} 条
        </span>
      </div>

      {query.isError && (
        <ErrorBanner
          message={`加载举报列表失败: ${
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
          title="没有举报记录"
          description="尝试切换过滤条件或刷新。"
          icon={<FlagIcon size={32} />}
        />
      ) : (
        <AdminTable
          head={
            <tr>
              <Th>举报人</Th>
              <Th>目标</Th>
              <Th className="hidden md:table-cell">原因</Th>
              <Th>状态</Th>
              <Th className="hidden sm:table-cell">时间</Th>
              <Th>操作</Th>
            </tr>
          }
        >
          {items.map((r) => {
            const targetId = r.target_id ?? "";
            const isVideo = (r.target_type ?? "").toLowerCase() === "video" ||
              (!!targetId && !r.target_type);
            return (
              <tr
                key={r.id}
                className="hover:bg-accent/40"
              >
                <Td>
                  <p className="text-sm font-medium">
                    {r.reporter_username ?? `UID ${r.reporter_uid ?? "—"}`}
                  </p>
                  {r.reporter_uid != null && (
                    <p className="text-[10px] text-muted-foreground">
                      UID: {r.reporter_uid}
                    </p>
                  )}
                </Td>
                <Td>
                  <p className="truncate text-sm">
                    {r.target_title ?? targetId.slice(0, 12) ?? "—"}
                  </p>
                  <p className="text-[10px] text-muted-foreground">
                    {r.target_type ?? "video"} · {targetId.slice(0, 8)}
                  </p>
                </Td>
                <Td className="hidden md:table-cell text-xs">
                  <p className="line-clamp-2 max-w-md">
                    {r.reason ?? "—"}
                  </p>
                </Td>
                <Td>
                  <StatusBadge status={r.status ?? filter} />
                </Td>
                <Td className="hidden sm:table-cell text-xs text-muted-foreground">
                  {r.created_at ? formatRelativeTime(r.created_at) : "—"}
                </Td>
                <Td>
                  {isVideo && targetId ? (
                    <Button
                      variant="ghost"
                      size="sm"
                      className="h-7"
                      onClick={() => goWatch(targetId)}
                    >
                      查看视频
                    </Button>
                  ) : (
                    <span className="text-xs text-muted-foreground">—</span>
                  )}
                </Td>
              </tr>
            );
          })}
        </AdminTable>
      )}

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
          第 {page + 1} 页
        </span>
        <Button
          variant="outline"
          size="sm"
          className="h-8"
          onClick={() => setPage((p) => p + 1)}
          disabled={items.length < pageSize || query.isFetching}
        >
          下一页
        </Button>
      </div>
    </div>
  );
}
