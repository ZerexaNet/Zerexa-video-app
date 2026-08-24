"use client";

/**
 * App shell.
 *
 * Hosts the global header, side drawer, and the active view
 * (home / watch / search / category / profile). The view is
 * selected by the route store, which is hydrated from URL search
 * params on mount.
 */

import { useEffect, useState } from "react";
import { AppHeader } from "@/components/app-header";
import { AppNav } from "@/components/app-nav";
import { AppFooter } from "@/components/app-footer";
import { HomeView, CATEGORIES } from "@/components/home-view";
import { WatchView } from "@/components/watch-view";
import { SearchView } from "@/components/search-view";
import { CategoryView } from "@/components/category-view";
import { ProfileView } from "@/components/profile-view";
import { useRoute } from "@/lib/route";
import { useAuth } from "@/lib/auth";
import { useTheme } from "@/lib/theme";

export function AppShell() {
  const { view, hydrate } = useRoute();
  const { init } = useAuth();
  const [navOpen, setNavOpen] = useState(false);

  // Apply theme to <html> via the hook (no-op on SSR).
  useTheme();

  useEffect(() => {
    hydrate();
    init();
  }, [hydrate, init]);

  return (
    <div className="flex min-h-screen flex-col bg-background">
      <AppHeader
        onOpenNav={() => setNavOpen(true)}
        categories={CATEGORIES}
      />
      <AppNav
        open={navOpen}
        onOpenChange={setNavOpen}
        categories={CATEGORIES}
      />

      <main className="mx-auto w-full max-w-7xl flex-1 px-3 py-5 sm:px-6 sm:py-6">
        {view.kind === "home" && <HomeView />}
        {view.kind === "watch" && <WatchView videoId={view.videoId} />}
        {view.kind === "search" && <SearchView q={view.q} />}
        {view.kind === "category" && <CategoryView category={view.category} />}
        {view.kind === "profile" && <ProfileView />}
      </main>

      <AppFooter />
    </div>
  );
}
