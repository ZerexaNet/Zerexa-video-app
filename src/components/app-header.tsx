"use client";

/**
 * Top navigation bar.
 *
 * Brand on the left, centred search box, right-hand cluster with
 * theme switcher and account controls. The bar is sticky and
 * shrinks on scroll for a tighter feel on long pages.
 *
 * On desktop the bar also hosts a small quick-launch icon row
 * (upload / dynamics / messages / tickets / votes / articles /
 * collections) so primary destinations are one click away.
 */

import * as React from "react";
import { useEffect, useState } from "react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import {
  Tooltip,
  TooltipContent,
  TooltipProvider,
  TooltipTrigger,
} from "@/components/ui/tooltip";
import { ThemeSwitcher } from "@/components/theme-switcher";
import { AuthDialog } from "@/components/auth-dialog";
import {
  Logo,
  SearchIcon,
  UserIcon,
  LogoutIcon,
  HistoryIcon,
  StarIcon,
  MenuIcon,
  CloseIcon,
  DashboardIcon,
  ArticleIcon,
  DynamicIcon,
  MailIcon,
  TicketIcon,
  VoteIcon,
  UploadIcon,
  CollectionIcon,
  BellIcon,
} from "@/components/icons";
import { useAuth } from "@/lib/auth";
import { useRoute } from "@/lib/route";

interface HeaderProps {
  onOpenNav: () => void;
  categories: { root: string; label: string }[];
  showAdminEntry?: boolean;
}

export function AppHeader({
  onOpenNav,
  categories,
  showAdminEntry,
}: HeaderProps) {
  const { user, logout } = useAuth();
  const {
    goHome,
    goSearch,
    goProfile,
    goAdmin,
    goArticles,
    goDynamics,
    goMessages,
    goNotifications,
    goTickets,
    goVotes,
    goUpload,
    goCollections,
  } = useRoute();
  const [query, setQuery] = useState("");
  const [scrolled, setScrolled] = useState(false);
  const [authOpen, setAuthOpen] = useState(false);
  const [authMode, setAuthMode] = useState<"login" | "register">("login");

  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 8);
    onScroll();
    window.addEventListener("scroll", onScroll, { passive: true });
    return () => window.removeEventListener("scroll", onScroll);
  }, []);

  // Sync query from URL when in search view
  useEffect(() => {
    const sync = () => {
      if (typeof window === "undefined") return;
      const u = new URL(window.location.href);
      const q = u.searchParams.get("q");
      if (q !== null) setQuery(q);
    };
    sync();
    window.addEventListener("popstate", sync);
    return () => window.removeEventListener("popstate", sync);
  }, []);

  const submitSearch = (e: React.FormEvent) => {
    e.preventDefault();
    if (!query.trim()) return;
    goSearch(query.trim());
  };

  const openLogin = () => {
    setAuthMode("login");
    setAuthOpen(true);
  };
  const openRegister = () => {
    setAuthMode("register");
    setAuthOpen(true);
  };

  // Quick-launch icons rendered inline on md+ screens. Each is
  // wrapped in a tooltip so the icon meaning is discoverable.
  const quickLinks = [
    { icon: UploadIcon, label: "投稿", action: goUpload, requiresAuth: true },
    { icon: DynamicIcon, label: "动态", action: goDynamics },
    { icon: ArticleIcon, label: "专栏", action: goArticles },
    { icon: CollectionIcon, label: "合集", action: goCollections },
    { icon: VoteIcon, label: "公投", action: goVotes },
    { icon: TicketIcon, label: "工单", action: goTickets, requiresAuth: true },
    {
      icon: MailIcon,
      label: "私信",
      action: goMessages,
      requiresAuth: true,
    },
    {
      icon: BellIcon,
      label: "通知",
      action: goNotifications,
      requiresAuth: true,
    },
  ];

  return (
    <header
      className={`sticky top-0 z-40 border-b border-border bg-background/85 backdrop-blur-xl transition-shadow ${
        scrolled ? "shadow-sm" : ""
      }`}
    >
      <div className="mx-auto flex h-16 items-center gap-2 px-3 sm:gap-3 sm:px-6">
        {/* Mobile: hamburger */}
        <Button
          variant="ghost"
          size="icon"
          className="h-10 w-10 lg:hidden"
          onClick={onOpenNav}
          aria-label="打开导航"
        >
          <MenuIcon size={22} />
        </Button>

        {/* Brand */}
        <button
          onClick={goHome}
          className="flex items-center gap-2 rounded-lg px-1.5 py-1 transition-colors hover:bg-accent/60 sm:px-2"
        >
          <Logo size={32} />
          <div className="hidden flex-col items-start leading-none sm:flex">
            <span className="text-base font-bold tracking-tight">
              Zerexa Video
            </span>
            <span className="text-[10px] uppercase tracking-wider text-muted-foreground">
              视频 · 专栏 · 动态
            </span>
          </div>
        </button>

        {/* Search */}
        <form
          onSubmit={submitSearch}
          className="mx-auto flex w-full max-w-xl items-center gap-1.5"
        >
          <div className="relative flex-1">
            <SearchIcon
              size={18}
              className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-muted-foreground"
            />
            <Input
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              placeholder="搜索视频、作者或关键词..."
              className="h-10 pl-10 pr-3"
              aria-label="搜索"
            />
          </div>
          <Button type="submit" size="sm" className="h-10 px-4">
            搜索
          </Button>
        </form>

        {/* Quick-launch icons (desktop only) */}
        <TooltipProvider delayDuration={300}>
          <div className="hidden items-center gap-0.5 md:flex">
            {quickLinks.map((l) => {
              const Icon = l.icon;
              const handleClick = () => {
                if (l.requiresAuth && !user) {
                  openLogin();
                  return;
                }
                l.action();
              };
              return (
                <Tooltip key={l.label}>
                  <TooltipTrigger asChild>
                    <Button
                      variant="ghost"
                      size="icon"
                      className="h-9 w-9 text-muted-foreground hover:bg-accent/60 hover:text-foreground"
                      onClick={handleClick}
                      aria-label={l.label}
                    >
                      <Icon size={18} />
                    </Button>
                  </TooltipTrigger>
                  <TooltipContent>{l.label}</TooltipContent>
                </Tooltip>
              );
            })}
          </div>
        </TooltipProvider>

        {/* Right cluster */}
        <div className="ml-auto flex items-center gap-1">
          <ThemeSwitcher />

          {user ? (
            <DropdownMenu>
              <DropdownMenuTrigger asChild>
                <button className="ml-1 flex items-center gap-2 rounded-full p-1 pr-2 transition-colors hover:bg-accent/60">
                  <Avatar className="h-8 w-8 border border-border">
                    <AvatarImage
                      src={user.gravatar_url ?? undefined}
                      alt={user.username}
                    />
                    <AvatarFallback>
                      {user.username.slice(0, 1).toUpperCase()}
                    </AvatarFallback>
                  </Avatar>
                  <span className="hidden text-sm font-medium sm:inline">
                    {user.username}
                  </span>
                </button>
              </DropdownMenuTrigger>
              <DropdownMenuContent align="end" className="w-56">
                <div className="px-2 py-1.5">
                  <p className="text-sm font-semibold">{user.username}</p>
                  <p className="text-xs text-muted-foreground">
                    UID: {user.uid}
                  </p>
                </div>
                <DropdownMenuSeparator />
                <DropdownMenuItem onClick={goProfile}>
                  <UserIcon size={16} className="mr-2" />
                  个人主页
                </DropdownMenuItem>
                <DropdownMenuItem onClick={goDynamics}>
                  <DynamicIcon size={16} className="mr-2" />
                  动态
                </DropdownMenuItem>
                <DropdownMenuItem onClick={goArticles}>
                  <ArticleIcon size={16} className="mr-2" />
                  专栏
                </DropdownMenuItem>
                <DropdownMenuItem onClick={goCollections}>
                  <CollectionIcon size={16} className="mr-2" />
                  合集
                </DropdownMenuItem>
                <DropdownMenuItem onClick={goUpload}>
                  <UploadIcon size={16} className="mr-2" />
                  投稿
                </DropdownMenuItem>
                <DropdownMenuSeparator />
                <DropdownMenuItem onClick={() => goMessages()}>
                  <MailIcon size={16} className="mr-2" />
                  私信
                </DropdownMenuItem>
                <DropdownMenuItem onClick={goNotifications}>
                  <BellIcon size={16} className="mr-2" />
                  通知
                </DropdownMenuItem>
                <DropdownMenuItem onClick={goTickets}>
                  <TicketIcon size={16} className="mr-2" />
                  我的工单
                </DropdownMenuItem>
                <DropdownMenuItem onClick={goVotes}>
                  <VoteIcon size={16} className="mr-2" />
                  公投
                </DropdownMenuItem>
                <DropdownMenuItem onClick={goProfile}>
                  <HistoryIcon size={16} className="mr-2" />
                  观看历史
                </DropdownMenuItem>
                <DropdownMenuItem onClick={goProfile}>
                  <StarIcon size={16} className="mr-2" />
                  我的收藏
                </DropdownMenuItem>
                {showAdminEntry && (
                  <>
                    <DropdownMenuSeparator />
                    <DropdownMenuItem onClick={() => goAdmin("dashboard")}>
                      <DashboardIcon size={16} className="mr-2" />
                      管理后台
                    </DropdownMenuItem>
                  </>
                )}
                <DropdownMenuSeparator />
                <DropdownMenuItem
                  onClick={async () => {
                    await logout();
                    goHome();
                  }}
                >
                  <LogoutIcon size={16} className="mr-2" />
                  退出登录
                </DropdownMenuItem>
              </DropdownMenuContent>
            </DropdownMenu>
          ) : (
            <div className="flex items-center gap-1">
              <Button
                variant="ghost"
                size="sm"
                className="hidden h-10 px-3 sm:inline-flex"
                onClick={openLogin}
              >
                登录
              </Button>
              <Button
                size="sm"
                className="h-10 px-3"
                onClick={openRegister}
              >
                注册
              </Button>
            </div>
          )}
        </div>
      </div>

      {/* Category strip on desktop */}
      <nav className="hidden border-t border-border/60 bg-background/60 lg:block">
        <div className="mx-auto flex items-center gap-1 overflow-x-auto px-6 py-1.5 scrollbar-thin">
          <button
            onClick={goHome}
            className="shrink-0 rounded-md px-3 py-1.5 text-sm text-muted-foreground transition-colors hover:bg-accent/60 hover:text-foreground"
          >
            首页
          </button>
          {categories.map((c) => (
            <button
              key={c.root}
              onClick={() => useRoute.getState().goCategory(c.root)}
              className="shrink-0 rounded-md px-3 py-1.5 text-sm text-muted-foreground transition-colors hover:bg-accent/60 hover:text-foreground"
            >
              {c.label}
            </button>
          ))}
        </div>
      </nav>

      <AuthDialog open={authOpen} onOpenChange={setAuthOpen} mode={authMode} onModeChange={setAuthMode} />
    </header>
  );
}
