"use client";

/**
 * Admin announcements view.
 *
 * Lists announcements from /api/admin/announcements and offers:
 *  - 新建公告   -> POST /api/admin/announcements {title, content, is_active}
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
        description="发布、上线、下线站点公告。新建通过 POST /api/admin/announcements 提交。"
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
            // `is_active` is typed as number on the Announcement
            // interface, but some upstreams return boolean. Accept
            // both shapes.
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

      <CreateAnnouncementDialog
        open={createOpen}
        onOpenChange={setCreateOpen}
        onSubmit={(body) => createMutation.mutate(body)}
        loading={createMutation.isPending}
      />
    </div>
  );
}

function CreateAnnouncementDialog({
  open,
  onOpenChange,
  onSubmit,
  loading,
}: {
  open: boolean;
  onOpenChange: (v: boolean) => void;
  onSubmit: (body: {
    title: string;
    content: string;
    is_active: number;
  }) => void;
  loading: boolean;
}) {
  const [title, setTitle] = React.useState("");
  const [content, setContent] = React.useState("");
  const [isActive, setIsActive] = React.useState(true);

  // Reset form when dialog closes
  React.useEffect(() => {
    if (!open) {
      setTitle("");
      setContent("");
      setIsActive(true);
    }
  }, [open]);

  const submit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!title.trim() || !content.trim()) return;
    onSubmit({
      title: title.trim(),
      content: content.trim(),
      is_active: isActive ? 1 : 0,
    });
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-lg">
        <DialogHeader>
          <DialogTitle>新建站点公告</DialogTitle>
          <DialogDescription>
            填写标题与正文，选择是否立即上线。提交后将在公告列表中显示。
          </DialogDescription>
        </DialogHeader>
        <form onSubmit={submit} className="space-y-4">
          <div className="space-y-1.5">
            <Label htmlFor="ann-title">标题</Label>
            <Input
              id="ann-title"
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              placeholder="例如：站点升级维护通知"
              maxLength={120}
              required
            />
          </div>
          <div className="space-y-1.5">
            <Label htmlFor="ann-content">正文</Label>
            <Textarea
              id="ann-content"
              value={content}
              onChange={(e) => setContent(e.target.value)}
              placeholder="公告内容..."
              rows={5}
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
              disabled={loading || !title.trim() || !content.trim()}
            >
              {loading ? "提交中..." : "发布"}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
