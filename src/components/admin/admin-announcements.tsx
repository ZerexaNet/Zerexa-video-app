"use client";

/**
 * Admin announcements view.
 *
 * Lists announcements from /api/admin/announcements and offers:
 *  - 新建公告    -> POST /api/admin/announcements {title, content, is_active}
 *  - 编辑公告    -> POST /api/admin/announcements {id, action: "update", title, content, is_active}
 *  - 切换上线    -> POST /api/admin/announcements {id, action: "update", is_active: !current}
 *  - 删除        -> POST /api/admin/announcements {id, action: "delete"}
 *
 * Update / delete reuse the same POST endpoint because the upstream
 * does not currently expose dedicated PUT/DELETE routes. If the
 * server rejects the request, the UI surfaces the error in a toast
 * without crashing.
 */

import * as React from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { api, type Announcement } from "@/lib/api";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Label } from "@/components/ui/label";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogFooter,
  DialogDescription,
} from "@/components/ui/dialog";
import {
  AdminSectionHeader,
  AdminTable,
  Th,
  Td,
  StatusBadge,
  EmptyState,
  ErrorBanner,
} from "@/components/admin/admin-shared";
import { AdminRefreshButton } from "@/components/admin/admin-shell";
import {
  PlusIcon,
  TrashIcon,
  BellIcon,
  CheckIcon,
  PencilSquareIcon,
} from "@/components/icons";
import { useToast } from "@/hooks/use-toast";
import { useAuth } from "@/lib/auth";
import { formatRelativeTime } from "@/lib/format";

export function AdminAnnouncements() {
  const qc = useQueryClient();
  const { toast } = useToast();
  const { user } = useAuth();
  const [refreshKey, setRefreshKey] = React.useState(0);
  const [createOpen, setCreateOpen] = React.useState(false);
  const [editTarget, setEditTarget] = React.useState<Announcement | null>(null);

  const query = useQuery({
    queryKey: ["admin", "announcements", refreshKey],
    queryFn: () => api.adminListAnnouncements(),
    retry: false,
  });

  const items: Announcement[] = Array.isArray(query.data) ? query.data : [];

  const createMutation = useMutation({
    mutationFn: (body: { title: string; content: string; is_active: number }) =>
      api.adminCreateAnnouncement(body),
    onSuccess: () => {
      toast({ title: "公告已发布", description: "新公告已成功提交" });
      setCreateOpen(false);
      qc.invalidateQueries({ queryKey: ["admin", "announcements"] });
    },
    onError: (e: unknown) => {
      toast({
        title: "发布失败",
        description: e instanceof Error ? e.message : "请稍后重试",
        variant: "destructive",
      });
    },
  });

  const updateMutation = useMutation({
    mutationFn: ({
      id,
      isActive,
    }: {
      id: string;
      isActive: boolean;
    }) =>
      api.adminUpdateAnnouncement(id, {
        is_active: isActive ? 1 : 0,
      }),
    onSuccess: () => {
      toast({ title: "已更新" });
      qc.invalidateQueries({ queryKey: ["admin", "announcements"] });
    },
    onError: (e: unknown) => {
      toast({
        title: "操作失败",
        description: e instanceof Error ? e.message : "请稍后重试",
        variant: "destructive",
      });
    },
  });

  const editMutation = useMutation({
    mutationFn: (body: {
      id: string;
      title: string;
      content: string;
      is_active: number;
    }) =>
      api.adminUpdateAnnouncement(body.id, {
        title: body.title,
        content: body.content,
        is_active: body.is_active,
      }),
    onSuccess: () => {
      toast({ title: "公告已更新" });
      setEditTarget(null);
      qc.invalidateQueries({ queryKey: ["admin", "announcements"] });
    },
    onError: (e: unknown) => {
      toast({
        title: "更新失败",
        description: e instanceof Error ? e.message : "请稍后重试",
        variant: "destructive",
      });
    },
  });

  const deleteMutation = useMutation({
    mutationFn: (id: string) => api.adminDeleteAnnouncement(id),
    onSuccess: () => {
      toast({ title: "已删除" });
      qc.invalidateQueries({ queryKey: ["admin", "announcements"] });
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
        title="公告管理"
        description="发布、编辑、上线、下线站点公告。新建 / 编辑均通过 POST /api/admin/announcements 提交。"
        actions={
          <div className="flex items-center gap-2">
            <AdminRefreshButton
              loading={query.isFetching}
              onClick={() => setRefreshKey((k) => k + 1)}
            />
            <Button
              size="sm"
              className="h-8"
              onClick={() => setCreateOpen(true)}
            >
              <PlusIcon size={14} className="mr-1.5" />
              新建公告
            </Button>
          </div>
        }
      />

      {!user && (
        <ErrorBanner message="未检测到登录状态。新建公告需要管理员账号登录后才能调用受保护的 API。" />
      )}
      {query.isError && (
        <ErrorBanner
          message={`加载公告失败: ${
            query.error instanceof Error ? query.error.message : "未知错误"
          }`}
        />
      )}

      {query.isLoading ? (
        <div className="space-y-2">
          {Array.from({ length: 4 }).map((_, i) => (
            <div
              key={i}
              className="h-20 animate-pulse rounded-md bg-muted/50"
            />
          ))}
        </div>
      ) : items.length === 0 ? (
        <EmptyState
          title="暂无公告"
          description="点击右上角「新建公告」发布首条公告。"
          icon={<BellIcon size={32} />}
          action={
            <Button size="sm" className="h-8" onClick={() => setCreateOpen(true)}>
              <PlusIcon size={14} className="mr-1.5" />
              新建公告
            </Button>
          }
        />
      ) : (
        <AdminTable
          head={
            <tr>
              <Th>标题 / 内容</Th>
              <Th className="hidden md:table-cell">发布人</Th>
              <Th>状态</Th>
              <Th className="hidden sm:table-cell">时间</Th>
              <Th>操作</Th>
            </tr>
          }
        >
          {items.map((a) => {
            const isActive =
              a.is_active === 1 ||
              a.is_active === true ||
              (typeof a.is_active === "number" && (a.is_active as number) > 0);
            return (
              <tr key={a.id} className="hover:bg-accent/40">
                <Td>
                  <p className="text-sm font-medium">{a.title}</p>
                  <p className="mt-0.5 line-clamp-1 max-w-xl text-xs text-muted-foreground">
                    {a.content}
                  </p>
                </Td>
                <Td className="hidden md:table-cell text-xs text-muted-foreground">
                  {a.created_by?.slice(0, 8) ?? "—"}
                </Td>
                <Td>
                  <StatusBadge status={isActive ? "active" : "rejected"} />
                </Td>
                <Td className="hidden sm:table-cell text-xs text-muted-foreground">
                  <p>创建: {formatRelativeTime(a.created_at)}</p>
                  <p>更新: {formatRelativeTime(a.updated_at)}</p>
                </Td>
                <Td>
                  <div className="flex items-center gap-1">
                    <Button
                      variant="ghost"
                      size="sm"
                      className="h-7"
                      onClick={() => setEditTarget(a)}
                      disabled={editMutation.isPending}
                    >
                      <PencilSquareIcon size={14} className="mr-1" />
                      编辑
                    </Button>
                    <Button
                      variant="ghost"
                      size="sm"
                      className="h-7"
                      onClick={() =>
                        updateMutation.mutate({
                          id: a.id,
                          isActive: !isActive,
                        })
                      }
                      disabled={updateMutation.isPending}
                    >
                      <CheckIcon size={14} className="mr-1" />
                      {isActive ? "下线" : "上线"}
                    </Button>
                    <Button
                      variant="ghost"
                      size="icon"
                      className="h-7 w-7 text-red-600 hover:bg-red-500/10 hover:text-red-700"
                      onClick={() => {
                        if (
                          window.confirm(`确认删除公告「${a.title}」？此操作不可撤销。`)
                        ) {
                          deleteMutation.mutate(a.id);
                        }
                      }}
                      disabled={deleteMutation.isPending}
                      aria-label="删除"
                      title="删除公告"
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

      <AnnouncementFormDialog
        open={createOpen}
        onOpenChange={setCreateOpen}
        title="新建站点公告"
        description="填写标题与正文，选择是否立即上线。提交后将在公告列表中显示。"
        confirmLabel="发布"
        loading={createMutation.isPending}
        onSubmit={(body) => createMutation.mutate({
          title: body.title,
          content: body.content,
          is_active: body.is_active ? 1 : 0,
        })}
      />

      <AnnouncementFormDialog
        open={!!editTarget}
        onOpenChange={(o) => !o && setEditTarget(null)}
        title={`编辑公告: ${editTarget?.title ?? ""}`}
        description="修改标题、正文或上线状态。"
        confirmLabel="保存"
        loading={editMutation.isPending}
        initialTitle={editTarget?.title ?? ""}
        initialContent={editTarget?.content ?? ""}
        initialIsActive={
          editTarget
            ? editTarget.is_active === 1 ||
              editTarget.is_active === true ||
              (typeof editTarget.is_active === "number" && (editTarget.is_active as number) > 0)
            : true
        }
        onSubmit={(body) => {
          if (editTarget) {
            editMutation.mutate({
              id: editTarget.id,
              ...body,
              is_active: body.is_active ? 1 : 0,
            });
          }
        }}
      />
    </div>
  );
}

/**
 * Unified create / edit dialog. Reused by both the "新建" button
 * and the per-row "编辑" button. When `initialTitle` etc. are
 * provided, the form pre-populates on open.
 */
function AnnouncementFormDialog({
  open,
  onOpenChange,
  title,
  description,
  confirmLabel,
  loading,
  initialTitle = "",
  initialContent = "",
  initialIsActive = true,
  onSubmit,
}: {
  open: boolean;
  onOpenChange: (v: boolean) => void;
  title: string;
  description: string;
  confirmLabel: string;
  loading: boolean;
  initialTitle?: string;
  initialContent?: string;
  initialIsActive?: boolean;
  onSubmit: (body: {
    title: string;
    content: string;
    is_active: boolean;
  }) => void;
}) {
  const [t, setT] = React.useState(initialTitle);
  const [c, setC] = React.useState(initialContent);
  const [isActive, setIsActive] = React.useState(initialIsActive);

  // Sync state when dialog opens (so edit pre-fills with the right values)
  React.useEffect(() => {
    if (open) {
      setT(initialTitle);
      setC(initialContent);
      setIsActive(initialIsActive);
    }
  }, [open, initialTitle, initialContent, initialIsActive]);

  const submit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!t.trim() || !c.trim()) return;
    onSubmit({
      title: t.trim(),
      content: c.trim(),
      is_active: isActive,
    });
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-lg">
        <DialogHeader>
          <DialogTitle>{title}</DialogTitle>
          <DialogDescription>{description}</DialogDescription>
        </DialogHeader>
        <form onSubmit={submit} className="space-y-4">
          <div className="space-y-1.5">
            <Label htmlFor="ann-title">标题</Label>
            <Input
              id="ann-title"
              value={t}
              onChange={(e) => setT(e.target.value)}
              placeholder="例如：站点升级维护通知"
              maxLength={120}
              required
            />
          </div>
          <div className="space-y-1.5">
            <Label htmlFor="ann-content">正文</Label>
            <Textarea
              id="ann-content"
              value={c}
              onChange={(e) => setC(e.target.value)}
              placeholder="公告内容..."
              rows={6}
              required
            />
          </div>
          <label className="flex items-center gap-2 text-sm">
            <input
              type="checkbox"
              checked={isActive}
              onChange={(e) => setIsActive(e.target.checked)}
              className="h-4 w-4 rounded border-border"
            />
            立即上线（否则保存为草稿）
          </label>
          <DialogFooter>
            <Button
              type="button"
              variant="outline"
              size="sm"
              onClick={() => onOpenChange(false)}
            >
              取消
            </Button>
            <Button
              type="submit"
              size="sm"
              disabled={loading || !t.trim() || !c.trim()}
            >
              {loading ? "提交中..." : confirmLabel}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
