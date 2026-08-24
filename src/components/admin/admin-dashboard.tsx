"use client";

/**
 * Admin dashboard.
 *
 * Overview cards aggregated from the four admin list endpoints.
 * Each card shows a count plus a deep link to the relevant
 * section. The dashboard is read-only and degrades gracefully
 * if individual endpoints fail (per-endpoint try/catch).
 */

import * as React from "react";
import { useQuery } from "@tanstack/react-query";
import { api } from "@/lib/api";
import {
  AdminSectionHeader,
  StatCard,
  ErrorBanner,
  asArray,
} from "@/components/admin/admin-shared";
import { AdminRefreshButton } from "@/components/admin/admin-shell";
import {
  VideoIcon,
  UsersIcon,
  FlagIcon,
  BellIcon,
  CheckCircleIcon,
  XCircleIcon,
  ClockIcon,
  InboxIcon,
  ChartIcon,
} from "@/components/icons";
import { useRoute } from "@/lib/route";
import { useAuth } from "@/lib/auth";
import { isAdminRole } from "@/lib/api";

export function AdminDashboard() {
  const { goAdmin } = useRoute();
  const { user } = useAuth();
  const [refreshKey, setRefreshKey] = React.useState(0);

  // Each query is independent so a failure in one doesn't block the others.
  const pendingVideos = useQuery({
    queryKey: ["admin", "videos", "pending", refreshKey],
    queryFn: () => api.adminListVideos({ status: "pending", limit: 1 }),
    retry: false,
  });
  const approvedVideos = useQuery({
    queryKey: ["admin", "videos", "approved", refreshKey],
    queryFn: () => api.adminListVideos({ status: "approved", limit: 1 }),
    retry: false,
  });
  const rejectedVideos = useQuery({
    queryKey: ["admin", "videos", "rejected", refreshKey],
    queryFn: () => api.adminListVideos({ status: "rejected", limit: 1 }),
    retry: false,
  });
  const users = useQuery({
    queryKey: ["admin", "users", refreshKey],
    queryFn: () => api.adminListUsers({ limit: 1 }),
    retry: false,
  });
  const openReports = useQuery({
    queryKey: ["admin", "reports", "open", refreshKey],
    queryFn: () => api.adminListReports({ status: "open", limit: 1 }),
    retry: false,
  });
  const closedReports = useQuery({
    queryKey: ["admin", "reports", "closed", refreshKey],
    queryFn: () => api.adminListReports({ status: "closed", limit: 1 }),
    retry: false,
  });
  const announcements = useQuery({
    queryKey: ["admin", "announcements", refreshKey],
    queryFn: () => api.adminListAnnouncements(),
    retry: false,
  });

  const loading =
    pendingVideos.isLoading ||
    users.isLoading ||
    openReports.isLoading ||
    announcements.isLoading;

  const errors = [
    pendingVideos.error,
    approvedVideos.error,
    rejectedVideos.error,
    users.error,
    openReports.error,
    closedReports.error,
    announcements.error,
  ].filter(Boolean);

  /**
   * Counts the items returned by any of the admin list queries,
   * abstracting over whether the upstream returned a bare array or
   * a `{ items, total }` envelope. Accepts the query result object.
   */
  const count = (q: { data: unknown } | undefined): number => {
    if (!q || !q.data) return 0;
    if (Array.isArray(q.data)) return q.data.length;
    if (q.data && typeof q.data === "object" && "total" in q.data) {
      return Number((q.data as { total: number }).total) || 0;
    }
    return asArray(q.data).length;
  };

  return (
    <div>
      <AdminSectionHeader
        title="管理概览"
        description="汇总各类资源的当前状态。点击任意卡片进入对应管理面板。"
        actions={
          <AdminRefreshButton
            loading={loading}
            onClick={() => setRefreshKey((k) => k + 1)}
          />
        }
      />

      {!user && (
        <ErrorBanner message="未检测到登录状态。管理后台需要管理员账号登录后才能调用受保护的 API。" />
      )}
      {user && !isAdminRole(user.role) && (
        <ErrorBanner message={`当前账号角色为 "${user.role ?? "member"}"，无管理员权限。受保护的 API 将返回 403。`} />
      )}
      {errors.length > 0 && (
        <ErrorBanner
          message={`部分统计请求失败 (${errors.length} 个错误)。可能是权限不足或远端 API 暂不可用。`}
        />
      )}

      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <button
          onClick={() => goAdmin("videos")}
          className="text-left transition-transform hover:-translate-y-0.5"
        >
          <StatCard
            label="待审核视频"
            value={pendingVideos.isLoading ? "..." : count(pendingVideos)}
            hint="新投稿等待审核"
            icon={<ClockIcon size={16} />}
            tone="warning"
          />
        </button>
        <button
          onClick={() => goAdmin("videos")}
          className="text-left transition-transform hover:-translate-y-0.5"
        >
          <StatCard
            label="已通过视频"
            value={approvedVideos.isLoading ? "..." : count(approvedVideos)}
            hint="前台可见的视频"
            icon={<CheckCircleIcon size={16} />}
            tone="success"
          />
        </button>
        <button
          onClick={() => goAdmin("videos")}
          className="text-left transition-transform hover:-translate-y-0.5"
        >
          <StatCard
            label="已拒绝视频"
            value={rejectedVideos.isLoading ? "..." : count(rejectedVideos)}
            hint="被审核拒绝的视频"
            icon={<XCircleIcon size={16} />}
            tone="danger"
          />
        </button>
        <button
          onClick={() => goAdmin("users")}
          className="text-left transition-transform hover:-translate-y-0.5"
        >
          <StatCard
            label="注册用户"
            value={users.isLoading ? "..." : count(users)}
            hint="全站累计注册数"
            icon={<UsersIcon size={16} />}
            tone="primary"
          />
        </button>
        <button
          onClick={() => goAdmin("reports")}
          className="text-left transition-transform hover:-translate-y-0.5"
        >
          <StatCard
            label="待处理举报"
            value={openReports.isLoading ? "..." : count(openReports)}
            hint="等待审核处理的举报"
            icon={<InboxIcon size={16} />}
            tone="warning"
          />
        </button>
        <button
          onClick={() => goAdmin("reports")}
          className="text-left transition-transform hover:-translate-y-0.5"
        >
          <StatCard
            label="已关闭举报"
            value={closedReports.isLoading ? "..." : count(closedReports)}
            hint="历史已处理举报"
            icon={<FlagIcon size={16} />}
            tone="default"
          />
        </button>
        <button
          onClick={() => goAdmin("announcements")}
          className="text-left transition-transform hover:-translate-y-0.5"
        >
          <StatCard
            label="站点公告"
            value={
              announcements.isLoading
                ? "..."
                : announcements.data
                ? announcements.data.length
                : 0
            }
            hint="全站公告总数"
            icon={<BellIcon size={16} />}
            tone="default"
          />
        </button>
        <div className="text-left">
          <StatCard
            label="当前账号"
            value={user?.username ?? "未登录"}
            hint={user?.role ? `角色: ${user.role}` : undefined}
            icon={<UsersIcon size={16} />}
            tone="default"
          />
        </div>
      </div>

      <div className="mt-6 grid grid-cols-1 gap-4 lg:grid-cols-2">
        <div className="rounded-md border border-border bg-card p-4 shadow-sm">
          <div className="flex items-center gap-2">
            <ChartIcon size={18} />
            <h3 className="text-sm font-semibold">快捷入口</h3>
          </div>
          <div className="mt-3 grid grid-cols-2 gap-2">
            <button
              onClick={() => goAdmin("videos")}
              className="flex items-center gap-2 rounded-md border border-border px-3 py-2 text-sm transition-colors hover:bg-accent"
            >
              <VideoIcon size={16} />
              视频审核
            </button>
            <button
              onClick={() => goAdmin("users")}
              className="flex items-center gap-2 rounded-md border border-border px-3 py-2 text-sm transition-colors hover:bg-accent"
            >
              <UsersIcon size={16} />
              用户管理
            </button>
            <button
              onClick={() => goAdmin("reports")}
              className="flex items-center gap-2 rounded-md border border-border px-3 py-2 text-sm transition-colors hover:bg-accent"
            >
              <FlagIcon size={16} />
              举报处理
            </button>
            <button
              onClick={() => goAdmin("announcements")}
              className="flex items-center gap-2 rounded-md border border-border px-3 py-2 text-sm transition-colors hover:bg-accent"
            >
              <BellIcon size={16} />
              公告管理
            </button>
          </div>
        </div>

        <div className="rounded-md border border-border bg-card p-4 shadow-sm">
          <h3 className="text-sm font-semibold">使用提示</h3>
          <ul className="mt-3 space-y-1.5 text-xs text-muted-foreground">
            <li>
              视频审核支持通过 / 拒绝 / 删除操作，结果通过 PUT /api/videos/{`{id}`} 与
              DELETE /api/videos/{`{id}`} 提交。
            </li>
            <li>
              公告管理支持新建（POST /api/admin/announcements）。已发布公告的编辑
              / 删除能力取决于上游 API 当前是否开放对应路由。
            </li>
            <li>
              用户管理与举报处理当前以只读列表为主，远端未公开
              ban / resolve 等管理动作路由。
            </li>
          </ul>
        </div>
      </div>
    </div>
  );
}
