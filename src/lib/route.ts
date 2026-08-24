"use client";

/**
 * Client-side route state.
 *
 * The Next.js project only exposes the `/` route, so view switching is
 * driven entirely off URL search params. This store keeps the URL and
 * the parsed view state in sync, exposing helpers to navigate without
 * reloading the page.
 */

import { create } from "zustand";

export type AdminSection =
  | "dashboard"
  | "videos"
  | "users"
  | "reports"
  | "announcements";

export type PublicView =
  | { kind: "home" }
  | { kind: "watch"; videoId: string }
  | { kind: "search"; q: string }
  | { kind: "profile" }
  | { kind: "category"; category: string }
  | { kind: "articles" }
  | { kind: "article"; articleId: string }
  | { kind: "articleEdit"; articleId?: string }
  | { kind: "dynamics" }
  | { kind: "messages"; conversationId?: string }
  | { kind: "notifications" }
  | { kind: "tickets" }
  | { kind: "ticket"; ticketId: string }
  | { kind: "ticketNew" }
  | { kind: "votes" }
  | { kind: "vote"; voteId: string }
  | { kind: "upload" }
  | { kind: "collections" }
  | { kind: "collection"; collectionId: string }
  | { kind: "collectionEdit"; collectionId?: string };

export type View =
  | PublicView
  | { kind: "admin"; section: AdminSection };

interface RouteState {
  view: View;
  goHome: () => void;
  goWatch: (id: string) => void;
  goSearch: (q: string) => void;
  goProfile: () => void;
  goCategory: (c: string) => void;
  goAdmin: (section?: AdminSection) => void;
  goArticles: () => void;
  goArticle: (id: string) => void;
  goArticleEdit: (id?: string) => void;
  goDynamics: () => void;
  goMessages: (conversationId?: string) => void;
  goNotifications: () => void;
  goTickets: () => void;
  goTicket: (id: string) => void;
  goTicketNew: () => void;
  goVotes: () => void;
  goVote: (id: string) => void;
  goUpload: () => void;
  goCollections: () => void;
  goCollection: (id: string) => void;
  goCollectionEdit: (id?: string) => void;
  hydrate: () => void;
}

function parseView(): View {
  if (typeof window === "undefined") return { kind: "home" };
  const u = new URL(window.location.href);
  const v = u.searchParams.get("v");
  const q = u.searchParams.get("q");
  const view = u.searchParams.get("view");
  const section = u.searchParams.get("section");
  const cat = u.searchParams.get("category");
  const aId = u.searchParams.get("aid");
  const tId = u.searchParams.get("tid");
  const voteId = u.searchParams.get("vote");
  const convId = u.searchParams.get("conv");
  const collId = u.searchParams.get("cid");
  if (v) return { kind: "watch", videoId: v };
  if (q) return { kind: "search", q };
  if (view === "profile") return { kind: "profile" };
  if (view === "articles") return { kind: "articles" };
  if (view === "article" && aId) return { kind: "article", articleId: aId };
  if (view === "article-edit") return { kind: "articleEdit", articleId: aId ?? undefined };
  if (view === "dynamics") return { kind: "dynamics" };
  if (view === "messages") return { kind: "messages", conversationId: convId ?? undefined };
  if (view === "notifications") return { kind: "notifications" };
  if (view === "tickets") return { kind: "tickets" };
  if (view === "ticket" && tId) return { kind: "ticket", ticketId: tId };
  if (view === "ticket-new") return { kind: "ticketNew" };
  if (view === "votes") return { kind: "votes" };
  if (view === "vote" && voteId) return { kind: "vote", voteId };
  if (view === "upload") return { kind: "upload" };
  if (view === "collections") return { kind: "collections" };
  if (view === "collection" && collId) return { kind: "collection", collectionId: collId };
  if (view === "collection-edit") return { kind: "collectionEdit", collectionId: collId ?? undefined };
  if (view === "admin") {
    const s = (section ?? "dashboard") as AdminSection;
    const valid: AdminSection[] = [
      "dashboard",
      "videos",
      "users",
      "reports",
      "announcements",
    ];
    return { kind: "admin", section: valid.includes(s) ? s : "dashboard" };
  }
  if (cat) return { kind: "category", category: cat };
  return { kind: "home" };
}

function pushView(view: View) {
  if (typeof window === "undefined") return;
  const u = new URL(window.location.href);
  u.search = "";
  if (view.kind === "watch") u.searchParams.set("v", view.videoId);
  else if (view.kind === "search") u.searchParams.set("q", view.q);
  else if (view.kind === "profile") u.searchParams.set("view", "profile");
  else if (view.kind === "category") u.searchParams.set("category", view.category);
  else if (view.kind === "articles") u.searchParams.set("view", "articles");
  else if (view.kind === "article") {
    u.searchParams.set("view", "article");
    u.searchParams.set("aid", view.articleId);
  }
  else if (view.kind === "articleEdit") {
    u.searchParams.set("view", "article-edit");
    if (view.articleId) u.searchParams.set("aid", view.articleId);
  }
  else if (view.kind === "dynamics") u.searchParams.set("view", "dynamics");
  else if (view.kind === "messages") {
    u.searchParams.set("view", "messages");
    if (view.conversationId) u.searchParams.set("conv", view.conversationId);
  }
  else if (view.kind === "notifications") u.searchParams.set("view", "notifications");
  else if (view.kind === "tickets") u.searchParams.set("view", "tickets");
  else if (view.kind === "ticket") {
    u.searchParams.set("view", "ticket");
    u.searchParams.set("tid", view.ticketId);
  }
  else if (view.kind === "ticketNew") u.searchParams.set("view", "ticket-new");
  else if (view.kind === "votes") u.searchParams.set("view", "votes");
  else if (view.kind === "vote") {
    u.searchParams.set("view", "vote");
    u.searchParams.set("vote", view.voteId);
  }
  else if (view.kind === "upload") u.searchParams.set("view", "upload");
  else if (view.kind === "collections") u.searchParams.set("view", "collections");
  else if (view.kind === "collection") {
    u.searchParams.set("view", "collection");
    u.searchParams.set("cid", view.collectionId);
  }
  else if (view.kind === "collectionEdit") {
    u.searchParams.set("view", "collection-edit");
    if (view.collectionId) u.searchParams.set("cid", view.collectionId);
  }
  else if (view.kind === "admin") {
    u.searchParams.set("view", "admin");
    u.searchParams.set("section", view.section);
  }
  window.history.pushState({}, "", u.toString());
  // Notify listeners
  window.dispatchEvent(new PopStateEvent("popstate"));
}

export const useRoute = create<RouteState>((set) => ({
  view: { kind: "home" },
  goHome: () => {
    pushView({ kind: "home" });
    set({ view: { kind: "home" } });
  },
  goWatch: (id) => {
    pushView({ kind: "watch", videoId: id });
    set({ view: { kind: "watch", videoId: id } });
    if (typeof window !== "undefined") window.scrollTo({ top: 0 });
  },
  goSearch: (q) => {
    pushView({ kind: "search", q });
    set({ view: { kind: "search", q } });
    if (typeof window !== "undefined") window.scrollTo({ top: 0 });
  },
  goProfile: () => {
    pushView({ kind: "profile" });
    set({ view: { kind: "profile" } });
    if (typeof window !== "undefined") window.scrollTo({ top: 0 });
  },
  goCategory: (c) => {
    pushView({ kind: "category", category: c });
    set({ view: { kind: "category", category: c } });
    if (typeof window !== "undefined") window.scrollTo({ top: 0 });
  },
  goAdmin: (section = "dashboard") => {
    pushView({ kind: "admin", section });
    set({ view: { kind: "admin", section } });
    if (typeof window !== "undefined") window.scrollTo({ top: 0 });
  },
  goArticles: () => {
    pushView({ kind: "articles" });
    set({ view: { kind: "articles" } });
    if (typeof window !== "undefined") window.scrollTo({ top: 0 });
  },
  goArticle: (id) => {
    pushView({ kind: "article", articleId: id });
    set({ view: { kind: "article", articleId: id } });
    if (typeof window !== "undefined") window.scrollTo({ top: 0 });
  },
  goArticleEdit: (id) => {
    pushView({ kind: "articleEdit", articleId: id });
    set({ view: { kind: "articleEdit", articleId: id } });
    if (typeof window !== "undefined") window.scrollTo({ top: 0 });
  },
  goDynamics: () => {
    pushView({ kind: "dynamics" });
    set({ view: { kind: "dynamics" } });
    if (typeof window !== "undefined") window.scrollTo({ top: 0 });
  },
  goMessages: (conversationId) => {
    pushView({ kind: "messages", conversationId });
    set({ view: { kind: "messages", conversationId } });
    if (typeof window !== "undefined") window.scrollTo({ top: 0 });
  },
  goNotifications: () => {
    pushView({ kind: "notifications" });
    set({ view: { kind: "notifications" } });
    if (typeof window !== "undefined") window.scrollTo({ top: 0 });
  },
  goTickets: () => {
    pushView({ kind: "tickets" });
    set({ view: { kind: "tickets" } });
    if (typeof window !== "undefined") window.scrollTo({ top: 0 });
  },
  goTicket: (id) => {
    pushView({ kind: "ticket", ticketId: id });
    set({ view: { kind: "ticket", ticketId: id } });
    if (typeof window !== "undefined") window.scrollTo({ top: 0 });
  },
  goTicketNew: () => {
    pushView({ kind: "ticketNew" });
    set({ view: { kind: "ticketNew" } });
    if (typeof window !== "undefined") window.scrollTo({ top: 0 });
  },
  goVotes: () => {
    pushView({ kind: "votes" });
    set({ view: { kind: "votes" } });
    if (typeof window !== "undefined") window.scrollTo({ top: 0 });
  },
  goVote: (id) => {
    pushView({ kind: "vote", voteId: id });
    set({ view: { kind: "vote", voteId: id } });
    if (typeof window !== "undefined") window.scrollTo({ top: 0 });
  },
  goUpload: () => {
    pushView({ kind: "upload" });
    set({ view: { kind: "upload" } });
    if (typeof window !== "undefined") window.scrollTo({ top: 0 });
  },
  goCollections: () => {
    pushView({ kind: "collections" });
    set({ view: { kind: "collections" } });
    if (typeof window !== "undefined") window.scrollTo({ top: 0 });
  },
  goCollection: (id) => {
    pushView({ kind: "collection", collectionId: id });
    set({ view: { kind: "collection", collectionId: id } });
    if (typeof window !== "undefined") window.scrollTo({ top: 0 });
  },
  goCollectionEdit: (id) => {
    pushView({ kind: "collectionEdit", collectionId: id });
    set({ view: { kind: "collectionEdit", collectionId: id } });
    if (typeof window !== "undefined") window.scrollTo({ top: 0 });
  },
  hydrate: () => {
    set({ view: parseView() });
    if (typeof window !== "undefined") {
      window.addEventListener("popstate", () =>
        set({ view: parseView() }),
      );
    }
  },
}));
