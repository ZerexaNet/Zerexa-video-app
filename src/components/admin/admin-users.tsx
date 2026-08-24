"use client";

/**
 * Admin users view.
 *
 * Lists users from /api/admin/users with role / banned filters.
 * The upstream API does not currently expose ban / unban / set-role
 * routes through paths the front-end can call directly, so the
 * table is read-only with a "view profile" deep-link.
 *
 * A search box filters the loaded rows client-side (the upstream
 * does not advertise a `q=` query parameter for users).
 */

import * as React from "react";
import { useQuery } from "@tanstack/react-query";
import { api, type AdminUser } from "@/lib/api";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
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
import { UsersIcon, SearchIcon } from "@/components/icons";
import { formatRelativeTime } from "@/lib/format";

type RoleFilter = "all" | "admin" | "member" | "banned";

const ROLE_FILTERS: { id: RoleFilter; label: string }[] = [
  { id: "all", label: "全部" },
  { id: "admin", label: "管理员" },
  { id: "member", label: "普通用户" },
  { id: "banned", label: "已封禁" },
];

export function AdminUsers() {
  const [roleFilter, setRoleFilter] = React.useState<RoleFilter>("all");
  const [search, setSearch] = React.useState("");
  const [page, setPage] = React.useState(0);
  const [refreshKey, setRefreshKey] = React.useState(0);
  const pageSize = 50;

  // We fetch a generous slice and filter client-side; the upstream
  // endpoint shape is opaque to us so we keep it simple.
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

  // Client-side filter for member vs all (since the API may not
  // support role=member explicitly) and for the search box.
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

  return (
    <div>
      <AdminSectionHeader
        title="用户管理"
        description="查看全站注册用户。封禁 / 解禁 / 角色变更由远端服务直接管理，前端当前以只读视图呈现。"
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
            </tr>
          }
        >
          {items.map((u) => {
            const banned =
              u.is_banned ||
              u.banned ||
              (u.status && String(u.status).toLowerCase() === "banned");
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
    </div>
  );
}
