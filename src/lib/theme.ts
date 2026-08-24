"use client";

/**
 * Theme system for Zerexa Video.
 *
 * Four discrete visual themes are exposed:
 *  - "material"  : Google Material You look (rounded, soft shadows, default accent)
 *  - "metro"     : Windows 8 Metro / Modern UI (flat, hard edges, vibrant blocks)
 *  - "zerexa"    : Site's signature purple-on-white corporate identity
 *  - "dark"      : A high-contrast dark variant usable on its own
 *
 * The active theme is stored on <html data-theme="..."> and persisted to
 * localStorage so that the choice survives reloads. A small zustand store
 * exposes the current value and a setter for use across the client.
 */

import { create } from "zustand";
import { persist } from "zustand/middleware";
import { useEffect } from "react";

export type ThemeName = "material" | "metro" | "zerexa" | "dark";

export const THEMES: { id: ThemeName; label: string; hint: string }[] = [
  {
    id: "material",
    label: "Material You",
    hint: "Rounded surfaces, soft shadows, warm neutrals",
  },
  {
    id: "metro",
    label: "Win8 Metro",
    hint: "Flat blocks, hard edges, vibrant solid colour",
  },
  {
    id: "zerexa",
    label: "Zerexa Purple",
    hint: "Site signature purple on light surface",
  },
  {
    id: "dark",
    label: "Midnight",
    hint: "High-contrast dark variant",
  },
];

interface ThemeState {
  theme: ThemeName;
  setTheme: (t: ThemeName) => void;
}

export const useThemeStore = create<ThemeState>()(
  persist(
    (set) => ({
      theme: "zerexa",
      setTheme: (t) => set({ theme: t }),
    }),
    {
      name: "zv-theme",
      // Only persist the theme id, not functions.
      partialize: (s) => ({ theme: s.theme }),
    },
  ),
);

/**
 * Synchronises the persisted theme onto the <html> element so CSS can
 * branch via [data-theme="..."] selectors. Also mirrors it onto
 * `class` for "dark" so existing shadcn styles continue to work.
 */
export function useTheme() {
  const theme = useThemeStore((s) => s.theme);
  const setTheme = useThemeStore((s) => s.setTheme);

  useEffect(() => {
    if (typeof document === "undefined") return;
    const root = document.documentElement;
    root.setAttribute("data-theme", theme);
    if (theme === "dark") root.classList.add("dark");
    else root.classList.remove("dark");
  }, [theme]);

  return { theme, setTheme };
}
