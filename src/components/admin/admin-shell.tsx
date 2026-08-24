"use client";

/**
 * Admin shell.
 *
 * Layout scaffold for the administrator back-office. Renders a
 * fixed left sidebar with section navigation, a sticky top bar
 * carrying the back-to-site and refresh controls, and the active
 * admin section in the main content area.
 *
 * The shell is intentionally visually distinct from the public
 * app shell: tighter spacing, a darker sidebar surface, and
 * hairline borders instead of soft shadows. This mirrors the
 * io.hk.cn back-office style.
 */

import * as React from "react";
import { Button } from "@/components/ui/button";
import {
  DashboardIcon,
  VideoIcon,
  UsersIcon,
  FlagIcon,
  BellIcon,
  ArrowLeftIcon,
  RefreshIcon,
} from "@/components/icons";
import { useRoute, type AdminSection } from "@/lib/route";
import { useAuth } from "@/lib/auth";
import {
  AdminDashboard,
  AdminVideos,
  AdminUsers,
  AdminReports,
  AdminAnnouncements,
} from "@/components/admin";

interface NavItem {
  id: AdminSection;
  label: string;
  icon: React.ComponentType<{ size?: number; className?: string }>;
}

const NAV: NavItem[] = [
  { id: "dashboard", label: "概览", icon: DashboardIcon },
  { id: "videos", label: "视频审核", icon: VideoIcon },
  { id: "users", label: "用户管理", icon: UsersIcon },
  { id: "reports", label: "举报处理", icon: FlagIcon },
  { id: "announcements", label: "公告管理", icon: BellIcon },
];

interface AdminShellProps {
  section: AdminSection;
}

export function AdminShell({ section }: AdminShellProps) {
  const { goAdmin, goHome } = useRoute();
  const { user } = useAuth();
  const [mobileNavOpen, setMobileNavOpen] = React.useState(false);

  const current = NAV.find((n) => n.id === section) ?? NAV[0];

  return (
    <div className="flex min-h-screen bg-background">
      {/* Sidebar - desktop */}
      <aside className="sticky top-0 hidden h-screen w-60 shrink-0 flex-col border-r border-border bg-sidebar lg:flex">
        <div className="flex items-center gap-2 border-b border-border px-5 py-5">
          <div className="flex h-8 w-8 items-center justify-center rounded-md bg-primary text-primary-foreground">
            <DashboardIcon size={18} />
          </div>
          <div className="leading-tight">
            <p className="text-sm font-bold">管理后台</p>
            <p className="text-[10px] uppercase tracking-wider text-muted-foreground">
              Zerexa Video Admin
            </p>
          </div>
        </div>

        <nav className="flex-1 overflow-y-auto p-3">
          <p className="px-2 py-1.5 text-[10px] font-semibold uppercase tracking-wider text-muted-foreground">
            管理
          </p>
          <ul className="space-y-0.5">
            {NAV.map((item) => {
              const Icon = item.icon;
              const active = section === item.id;
              return (
                <li key={item.id}>
                  <button
                    onClick={() => goAdmin(item.id)}
                    className={`flex w-full items-center gap-2.5 rounded-md px-3 py-2 text-sm transition-colors ${
                      active
                        ? "bg-primary text-primary-foreground"
                        : "text-foreground/80 hover:bg-accent hover:text-foreground"
                    }`}
                  >
                    <Icon size={16} />
                    <span className="flex-1 text-left">{item.label}</span>
                  </button>
                </li>
              );
            })}
          </ul>
        </nav>

        <div className="border-t border-border p-3">
          <button
            onClick={goHome}
            className="flex w-full items-center gap-2.5 rounded-md px-3 py-2 text-sm text-foreground/80 transition-colors hover:bg-accent hover:text-foreground"
          >
            <ArrowLeftIcon size={16} />
            返回前台
          </button>
        </div>
      </aside>

      {/* Mobile sidebar */}
      {mobileNavOpen && (
        <div
          className="fixed inset-0 z-50 bg-black/40 lg:hidden"
          onClick={() => setMobileNavOpen(false)}
        >
          <aside
            className="absolute left-0 top-0 h-full w-64 max-w-[80vw] bg-sidebar shadow-xl"
            onClick={(e) => e.stopPropagation()}
          >
            <div className="flex items-center justify-between border-b border-border px-4 py-4">
              <span className="text-sm font-bold">管理后台</span>
              <Button
                variant="ghost"
                size="icon"
                className="h-8 w-8"
                onClick={() => setMobileNavOpen(false)}
                aria-label="关闭导航"
              >
                <ArrowLeftIcon size={16} />
              </Button>
            </div>
            <nav className="p-3">
              <ul className="space-y-0.5">
                {NAV.map((item) => {
                  const Icon = item.icon;
                  const active = section === item.id;
                  return (
                    <li key={item.id}>
                      <button
                        onClick={() => {
                          goAdmin(item.id);
                          setMobileNavOpen(false);
                        }}
                        className={`flex w-full items-center gap-2.5 rounded-md px-3 py-2 text-sm transition-colors ${
                          active
                            ? "bg-primary text-primary-foreground"
                            : "text-foreground/80 hover:bg-accent hover:text-foreground"
                        }`}
                      >
                        <Icon size={16} />
                        <span className="flex-1 text-left">{item.label}</span>
                      </button>
                    </li>
                  );
                })}
              </ul>
            </nav>
          </aside>
        </div>
      )}

      {/* Main */}
      <div className="flex min-w-0 flex-1 flex-col">
        {/* Top bar */}
        <header className="sticky top-0 z-30 flex h-14 items-center gap-3 border-b border-border bg-background/85 px-4 backdrop-blur-xl sm:px-6">
          <Button
            variant="ghost"
            size="icon"
            className="h-9 w-9 lg:hidden"
            onClick={() => setMobileNavOpen(true)}
            aria-label="打开管理导航"
          >
            <DashboardIcon size={18} />
          </Button>
          <h1 className="text-base font-bold">{current.label}</h1>
          <div className="ml-auto flex items-center gap-2">
            <span className="hidden text-xs text-muted-foreground sm:inline">
              {user?.username ? `当前账号: ${user.username}` : "未登录"}
            </span>
            <Button
              variant="outline"
              size="sm"
              className="h-8"
              onClick={() => goHome()}
            >
              <ArrowLeftIcon size={14} className="mr-1.5" />
              前台
            </Button>
          </div>
        </header>

        {/* Section content */}
        <main className="flex-1 px-4 py-5 sm:px-6 sm:py-6">
          {section === "dashboard" && <AdminDashboard />}
          {section === "videos" && <AdminVideos />}
          {section === "users" && <AdminUsers />}
          {section === "reports" && <AdminReports />}
          {section === "announcements" && <AdminAnnouncements />}
        </main>
      </div>
    </div>
  );
}

export function AdminRefreshButton({
  onClick,
  loading,
}: {
  onClick: () => void;
  loading?: boolean;
}) {
  return (
    <Button
      variant="outline"
      size="sm"
      className="h-8"
      onClick={onClick}
      disabled={loading}
      aria-label="刷新"
    >
      <RefreshIcon
        size={14}
        className={`mr-1.5 ${loading ? "animate-spin" : ""}`}
      />
      刷新
    </Button>
  );
}
