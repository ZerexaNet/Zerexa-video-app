"use client";

/**
 * App shell.
 *
 * Hosts the global header, side drawer, and the active view
 * (home / watch / search / category / profile / admin, plus
 * articles / dynamics / messages / tickets / votes / upload /
 * collections). The view is selected by the route store, which is
 * hydrated from URL search params on mount.
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
import {
  ArticlesList,
  ArticleDetail,
  ArticleEditor,
} from "@/components/articles-view";
import { DynamicsView } from "@/components/dynamics-view";
import { MessagesView } from "@/components/messages-view";
import {
  TicketsList,
  TicketCreate,
  TicketDetail,
} from "@/components/tickets-view";
import { VotesList, VoteDetail } from "@/components/vote-view";
import { UploadView } from "@/components/upload-view";
import {
  CollectionsList,
  CollectionDetailView,
  CollectionEditor,
} from "@/components/collections-view";
import { AdminShell } from "@/components/admin/admin-shell";
import { useRoute } from "@/lib/route";
import { useAuth } from "@/lib/auth";
import { useTheme } from "@/lib/theme";
import { isAdminRole } from "@/lib/api";

export function AppShell() {
  const { view, hydrate } = useRoute();
  const { user, init } = useAuth();
  const [navOpen, setNavOpen] = useState(false);

  // Apply theme to <html> via the hook (no-op on SSR).
  useTheme();

  useEffect(() => {
    hydrate();
    init();
  }, [hydrate, init]);

  // Admin route: render the dedicated admin shell which has its
  // own header / sidebar layout. We do NOT render the public
  // header / footer around it.
  if (view.kind === "admin") {
    return <AdminShell section={view.section} />;
  }

  return (
    <div className="flex min-h-screen flex-col bg-background">
      <AppHeader
        onOpenNav={() => setNavOpen(true)}
        categories={CATEGORIES}
        showAdminEntry={isAdminRole(user?.role)}
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
        {view.kind === "articles" && <ArticlesList />}
        {view.kind === "article" && <ArticleDetail articleId={view.articleId} />}
        {view.kind === "articleEdit" && <ArticleEditor articleId={view.articleId} />}
        {view.kind === "dynamics" && <DynamicsView />}
        {view.kind === "messages" && (
          <MessagesView initialConversationId={view.conversationId} />
        )}
        {view.kind === "notifications" && <MessagesView />}
        {view.kind === "tickets" && <TicketsList />}
        {view.kind === "ticket" && <TicketDetail ticketId={view.ticketId} />}
        {view.kind === "ticketNew" && <TicketCreate />}
        {view.kind === "votes" && <VotesList />}
        {view.kind === "vote" && <VoteDetail voteId={view.voteId} />}
        {view.kind === "upload" && <UploadView />}
        {view.kind === "collections" && <CollectionsList />}
        {view.kind === "collection" && (
          <CollectionDetailView collectionId={view.collectionId} />
        )}
        {view.kind === "collectionEdit" && (
          <CollectionEditor collectionId={view.collectionId} />
        )}
      </main>

      <AppFooter />
    </div>
  );
}
