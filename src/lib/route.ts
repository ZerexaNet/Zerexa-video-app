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

export type View =
  | { kind: "home" }
  | { kind: "watch"; videoId: string }
  | { kind: "search"; q: string }
  | { kind: "profile" }
  | { kind: "category"; category: string }
  | { kind: "admin"; section: AdminSection };

interface RouteState {
  view: View;
  goHome: () => void;
  goWatch: (id: string) => void;
  goSearch: (q: string) => void;
  goProfile: () => void;
  goCategory: (c: string) => void;
  goAdmin: (section?: AdminSection) => void;
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
  if (v) return { kind: "watch", videoId: v };
  if (q) return { kind: "search", q };
  if (view === "profile") return { kind: "profile" };
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
  hydrate: () => {
    set({ view: parseView() });
    if (typeof window !== "undefined") {
      window.addEventListener("popstate", () =>
        set({ view: parseView() }),
      );
    }
  },
}));
