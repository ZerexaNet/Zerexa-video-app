"use client";

/**
 * Admin users view.
 *
 * Lists users from /api/admin/users with role / banned filters.
 * Provides ban / unban / set-role actions via POST
 * /api/admin/users/action. Each action opens a small dialog so
 * the operator can provide a reason / duration / role.
 */

import * as React from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { api, type AdminUser } from "@/lib/api";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Label } from "@/components/ui/label";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
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
import {
  UsersIcon,
  SearchIcon,
  ShieldIcon,
  ShieldOffIcon,
  PencilSquareIcon,
} from "@/components/icons";
import { useToast } from "@/hooks/use-toast";
import { formatRelativeTime } from "@/lib/format";

type RoleFilter = "all" | "admin" | "member" | "banned";

const ROLE_FILTERS: { id: RoleFilter; label: string }[] = [
  { id: "all", label: "全部" },
  { id: "admin", label: "管理员" },
  { id: "member", label: "普通用户" },
  { id: "banned", label: "已封禁" },
];

export function AdminUsers() {
  const qc = useQueryClient();
  const { toast } = useToast();
  const [roleFilter, setRoleFilter] = React.useState<RoleFilter>("all");
  const [search, setSearch] = React.useState("");
  const [page, setPage] = React.useState(0);
  const [refreshKey, setRefreshKey] = React.useState(0);
  const pageSize = 50;
  const [actionTarget, setActionTarget] = React.useState<AdminUser | null>(null);
  const [actionKind, setActionKind] = React.useState<"ban" | "unban" | "set_role" | null>(null);

  const query = useQuery({
    queryKey: ["admin", "users", roleFilter, refreshKey],
    queryFn: () =>
      api.adminListUsers({
        limit: pageSize,
        offset: page * pageSize,
        role: roleFilter === "admin" ? "admin" : undefined,
        banned: roleFilter === "banned" ? true : undefined,
      }),
    retry: false,
  });

  const allItems = asArray<AdminUser>(query.data);

  // Client-side filter for member vs all and for the search box
  const items = allItems.filter((u) => {
    if (roleFilter === "member") {
      const r = (u.role ?? "").toLowerCase();
      if (r === "admin" || r === "moderator") return false;
    }
    if (search) {
      const q = search.toLowerCase();
      const hay =
        `${u.username ?? ""} ${u.email ?? ""} ${u.uid ?? ""} ${u.id ?? ""}`.toLowerCase();
      if (!hay.includes(q)) return false;
    }
    return true;
  });

  const openAction = (u: AdminUser, kind: "ban" | "unban" | "set_role") => {
    setActionTarget(u);
    setActionKind(kind);
  };

  const closeAction = () => {
    setActionTarget(null);
    setActionKind(null);
  };

  return (
    <div>
      <AdminSectionHeader
        title="用户管理"
        description="查看注册用户并执行封禁 / 解禁 / 角色变更。操作通过 POST /api/admin/users/action 提交。"
        actions={
          <AdminRefreshButton
            loading={query.isFetching}
            onClick={() => setRefreshKey((k) => k + 1)}
          />
        }
      />

      <div className="mb-4 flex flex-wrap items-center gap-2">
        {ROLE_FILTERS.map((f) => {
          const active = roleFilter === f.id;
          return (
            <button
              key={f.id}
              onClick={() => {
                setRoleFilter(f.id);
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
        <div className="relative ml-auto w-full max-w-xs">
          <SearchIcon
            size={16}
            className="pointer-events-none absolute left-2.5 top-1/2 -translate-y-1/2 text-muted-foreground"
          />
          <Input
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="按用户名 / 邮箱 / UID 搜索"
            className="h-8 pl-8 text-xs"
          />
        </div>
      </div>

      {query.isError && (
        <ErrorBanner
          message={`加载用户列表失败: ${
            query.error instanceof Error ? query.error.message : "未知错误"
          }`}
        />
      )}

      {query.isLoading ? (
        <div className="space-y-2">
          {Array.from({ length: 8 }).map((_, i) => (
            <div
              key={i}
              className="h-14 animate-pulse rounded-md bg-muted/50"
            />
          ))}
        </div>
      ) : items.length === 0 ? (
        <EmptyState
          title="没有符合条件的用户"
          description="尝试切换过滤条件或调整搜索关键词。"
          icon={<UsersIcon size={32} />}
        />
      ) : (
        <AdminTable
          head={
            <tr>
              <Th>用户</Th>
              <Th className="hidden md:table-cell">邮箱</Th>
              <Th>角色</Th>
              <Th className="hidden sm:table-cell">注册时间</Th>
              <Th className="hidden lg:table-cell">UID / ID</Th>
              <Th>操作</Th>
            </tr>
          }
        >
          {items.map((u) => {
            const banned =
              u.is_banned ||
              u.banned ||
              (u.status && String(u.status).toLowerCase() === "banned");
            const uid = u.uid ?? u.id;
            return (
              <tr key={u.id ?? u.uid ?? u.username} className="hover:bg-accent/40">
                <Td>
                  <div className="flex items-center gap-2">
                    <div className="flex h-8 w-8 items-center justify-center rounded-full bg-muted text-xs font-semibold text-foreground/70">
                      {u.username.slice(0, 1).toUpperCase()}
                    </div>
                    <div className="min-w-0">
                      <p className="truncate text-sm font-medium">
                        {u.username}
                      </p>
                      {u.bio && (
                        <p className="truncate text-xs text-muted-foreground">
                          {u.bio}
                        </p>
                      )}
                    </div>
                  </div>
                </Td>
                <Td className="hidden md:table-cell text-xs">
                  {u.email ?? "—"}
                </Td>
                <Td>
                  <div className="flex items-center gap-1">
                    <StatusBadge status={u.role ?? "member"} />
                    {banned ? <StatusBadge status="banned" /> : null}
                  </div>
                </Td>
                <Td className="hidden sm:table-cell text-xs text-muted-foreground">
                  {u.created_at ? formatRelativeTime(u.created_at) : "—"}
                </Td>
                <Td className="hidden lg:table-cell text-xs text-muted-foreground">
                  {u.uid ? `UID: ${u.uid}` : u.id?.slice(0, 8)}
                </Td>
                <Td>
                  <div className="flex items-center gap-1">
                    {banned ? (
                      <Button
                        variant="ghost"
                        size="sm"
                        className="h-7 text-emerald-600 hover:bg-emerald-500/10 hover:text-emerald-700"
                        onClick={() => openAction(u, "unban")}
                      >
                        <ShieldIcon size={12} className="mr-1" />
                        解禁
                      </Button>
                    ) : (
                      <Button
                        variant="ghost"
                        size="sm"
                        className="h-7 text-red-600 hover:bg-red-500/10 hover:text-red-700"
                        onClick={() => openAction(u, "ban")}
                      >
                        <ShieldOffIcon size={12} className="mr-1" />
                        封禁
                      </Button>
                    )}
                    <Button
                      variant="ghost"
                      size="sm"
                      className="h-7"
                      onClick={() => openAction(u, "set_role")}
                    >
                      <PencilSquareIcon size={12} className="mr-1" />
                      角色
                    </Button>
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
          第 {page + 1} 页 (每页 {pageSize})
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

      <UserActionDialog
        user={actionTarget}
        kind={actionKind}
        open={!!actionTarget}
        onOpenChange={(o) => !o && closeAction()}
        onDone={() => {
          qc.invalidateQueries({ queryKey: ["admin", "users"] });
          closeAction();
        }}
      />
    </div>
  );
}

function UserActionDialog({
  user,
  kind,
  open,
  onOpenChange,
  onDone,
}: {
  user: AdminUser | null;
  kind: "ban" | "unban" | "set_role" | null;
  open: boolean;
  onOpenChange: (v: boolean) => void;
  onDone: () => void;
}) {
  const { toast } = useToast();
  const [reason, setReason] = React.useState("");
  const [duration, setDuration] = React.useState("");
  const [role, setRole] = React.useState<string>("member");
  const [saving, setSaving] = React.useState(false);

  React.useEffect(() => {
    if (open) {
      setReason("");
      setDuration("");
      setRole(user?.role ?? "member");
    }
  }, [open, user]);

  if (!user || !kind) return null;

  const title =
    kind === "ban" ? `封禁 ${user.username}` :
    kind === "unban" ? `解禁 ${user.username}` :
    `变更 ${user.username} 的角色`;

  const description =
    kind === "ban"
      ? "封禁后该用户将无法登录或发布内容。"
      : kind === "unban"
      ? "解除封禁后该用户可恢复正常使用。"
      : "选择新的角色并提交。";

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    setSaving(true);
    try {
      const uid = user.uid ?? user.id;
      if (kind === "ban") {
        await api.adminBanUser(uid, reason.trim() || undefined, duration.trim() || undefined);
      } else if (kind === "unban") {
        await api.adminUnbanUser(uid);
      } else if (kind === "set_role") {
        await api.adminSetUserRole(uid, role);
      }
      toast({ title: "操作成功" });
      onDone();
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
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle>{title}</DialogTitle>
          <DialogDescription>{description}</DialogDescription>
        </DialogHeader>
        <form onSubmit={submit} className="space-y-4">
          {kind === "ban" && (
            <>
              <div className="space-y-1.5">
                <Label htmlFor="ban-reason">封禁理由（可选）</Label>
                <Textarea
                  id="ban-reason"
                  value={reason}
                  onChange={(e) => setReason(e.target.value)}
                  rows={3}
                  maxLength={500}
                  placeholder="记录封禁原因，便于审计"
                />
              </div>
              <div className="space-y-1.5">
                <Label htmlFor="ban-duration">封禁时长（可选）</Label>
                <Input
                  id="ban-duration"
                  value={duration}
                  onChange={(e) => setDuration(e.target.value)}
                  placeholder="如：7d / 30d / permanent（留空 = 永久）"
                />
              </div>
            </>
          )}
          {kind === "set_role" && (
            <div className="space-y-1.5">
              <Label htmlFor="user-role">新角色</Label>
              <Select value={role} onValueChange={setRole}>
                <SelectTrigger id="user-role">
                  <SelectValue placeholder="选择角色" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="member">普通用户 (member)</SelectItem>
                  <SelectItem value="moderator">版主 (moderator)</SelectItem>
                  <SelectItem value="admin">管理员 (admin)</SelectItem>
                  <SelectItem value="superadmin">超级管理员 (superadmin)</SelectItem>
                </SelectContent>
              </Select>
            </div>
          )}
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
              disabled={saving}
              className={
                kind === "ban"
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
  );
}
