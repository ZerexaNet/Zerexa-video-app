"use client";

/**
 * Admin reports view.
 *
 * Lists reports from /api/admin/reports with status filter.
 * Per-row actions: 关闭 / 标记已处理（POST
 * /api/admin/reports/{id}/close or /resolve). The admin can attach
 * a resolution note that is persisted on the report record.
 */

import * as React from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { api, type AdminReport } from "@/lib/api";
import { Button } from "@/components/ui/button";
import { Textarea } from "@/components/ui/textarea";
import { Label } from "@/components/ui/label";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
  DialogFooter,
} from "@/components/ui/dialog";
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
import { FlagIcon, XSquareIcon, CheckSquareIcon } from "@/components/icons";
import { useRoute } from "@/lib/route";
import { useToast } from "@/hooks/use-toast";
import { formatRelativeTime } from "@/lib/format";

type ReportFilter = "open" | "closed" | undefined;

const FILTERS: { id: ReportFilter; label: string }[] = [
  { id: undefined, label: "全部" },
  { id: "open", label: "待处理" },
  { id: "closed", label: "已关闭" },
];

export function AdminReports() {
  const qc = useQueryClient();
  const { toast } = useToast();
  const { goWatch } = useRoute();
  const [filter, setFilter] = React.useState<ReportFilter>(undefined);
  const [page, setPage] = React.useState(0);
  const [refreshKey, setRefreshKey] = React.useState(0);
  const pageSize = 20;

  const [resolutionTarget, setResolutionTarget] = React.useState<AdminReport | null>(null);
  const [resolutionKind, setResolutionKind] = React.useState<"close" | "resolve" | null>(null);
  const [resolution, setResolution] = React.useState("");
  const [saving, setSaving] = React.useState(false);

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

  const openResolution = (r: AdminReport, kind: "close" | "resolve") => {
    setResolutionTarget(r);
    setResolutionKind(kind);
    setResolution("");
  };

  const closeResolution = () => {
    setResolutionTarget(null);
    setResolutionKind(null);
    setResolution("");
  };

  const submitResolution = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!resolutionTarget || !resolutionKind) return;
    setSaving(true);
    try {
      const note = resolution.trim() || undefined;
      if (resolutionKind === "close") {
        await api.adminCloseReport(resolutionTarget.id, note);
      } else {
        await api.adminMarkReportProcessed(resolutionTarget.id, note);
      }
      toast({ title: "操作成功" });
      qc.invalidateQueries({ queryKey: ["admin", "reports"] });
      closeResolution();
    } catch (err) {
      toast({
        title: "操作失败",
        description: err instanceof Error ? err.message : "请稍后重试",
        variant: "destructive",
      });
    } finally {
      setSaving(false);
    }
  };

  return (
    <div>
      <AdminSectionHeader
        title="举报处理"
        description="查看社区提交的举报并执行关闭 / 标记已处理。每个操作可附带处理说明。"
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
            const isVideo =
              (r.target_type ?? "").toLowerCase() === "video" ||
              (!!targetId && !r.target_type);
            const status = (r.status ?? "").toLowerCase();
            const isClosed = status === "closed";
            return (
              <tr key={r.id} className="hover:bg-accent/40">
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
                  <div className="flex items-center gap-1">
                    {isVideo && targetId ? (
                      <Button
                        variant="ghost"
                        size="sm"
                        className="h-7"
                        onClick={() => goWatch(targetId)}
                      >
                        查看
                      </Button>
                    ) : null}
                    {!isClosed && (
                      <>
                        <Button
                          variant="ghost"
                          size="sm"
                          className="h-7 text-emerald-600 hover:bg-emerald-500/10 hover:text-emerald-700"
                          onClick={() => openResolution(r, "resolve")}
                        >
                          <CheckSquareIcon size={12} className="mr-1" />
                          已处理
                        </Button>
                        <Button
                          variant="ghost"
                          size="sm"
                          className="h-7 text-red-600 hover:bg-red-500/10 hover:text-red-700"
                          onClick={() => openResolution(r, "close")}
                        >
                          <XSquareIcon size={12} className="mr-1" />
                          关闭
                        </Button>
                      </>
                    )}
                    {isClosed && (
                      <span className="text-xs text-muted-foreground">已关闭</span>
                    )}
                  </div>
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

      {/* Resolution dialog */}
      <Dialog
        open={!!resolutionTarget}
        onOpenChange={(o) => !o && closeResolution()}
      >
        <DialogContent className="sm:max-w-md">
          <DialogHeader>
            <DialogTitle>
              {resolutionKind === "close" ? "关闭举报" : "标记举报已处理"}
            </DialogTitle>
            <DialogDescription>
              可附上处理说明（可选），便于后续审计。提交后该举报将标记为
              {resolutionKind === "close" ? "已关闭" : "已处理"}。
            </DialogDescription>
          </DialogHeader>
          <form onSubmit={submitResolution} className="space-y-4">
            <div className="space-y-1.5">
              <Label htmlFor="resolution">处理说明（可选）</Label>
              <Textarea
                id="resolution"
                value={resolution}
                onChange={(e) => setResolution(e.target.value)}
                rows={4}
                maxLength={500}
                placeholder="如：已联系当事人核实 / 已删除违规内容 / 已封禁对应用户"
              />
            </div>
            <DialogFooter>
              <Button
                type="button"
                variant="outline"
                size="sm"
                onClick={closeResolution}
              >
                取消
              </Button>
              <Button
                type="submit"
                size="sm"
                disabled={saving}
                className={
                  resolutionKind === "close"
                    ? "bg-red-600 text-white hover:bg-red-700"
                    : ""
                }
              >
                {saving ? "处理中..." : "确认"}
              </Button>
            </DialogFooter>
          </form>
        </DialogContent>
      </Dialog>
    </div>
  );
}
