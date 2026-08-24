"use client";

/**
 * Theme switcher button + dropdown.
 *
 * Exposes the four supported themes (Material You / Win8 Metro /
 * Zerexa Clean / Midnight) and persists the choice via the theme
 * store. The button shows a small palette glyph and the dropdown
 * shows each theme with a hint description.
 */

import * as React from "react";
import { Button } from "@/components/ui/button";
import {
  Popover,
  PopoverContent,
  PopoverTrigger,
} from "@/components/ui/popover";
import { PaletteIcon, CheckIcon } from "@/components/icons";
import { THEMES, useThemeStore, type ThemeName } from "@/lib/theme";

const swatch: Record<ThemeName, string> = {
  material: "linear-gradient(135deg, #4285F4, #34A853)",
  metro: "linear-gradient(135deg, #2D7DD2, #97CC04)",
  zerexa: "linear-gradient(135deg, #FFFFFF, #1E40AF)",
  dark: "linear-gradient(135deg, #0F172A, #3B82F6)",
};

export function ThemeSwitcher() {
  const theme = useThemeStore((s) => s.theme);
  const setTheme = useThemeStore((s) => s.setTheme);
  const [open, setOpen] = React.useState(false);

  return (
    <Popover open={open} onOpenChange={setOpen}>
      <PopoverTrigger asChild>
        <Button
          variant="ghost"
          size="icon"
          className="h-10 w-10"
          aria-label="切换主题"
        >
          <PaletteIcon size={20} />
        </Button>
      </PopoverTrigger>
      <PopoverContent
        align="end"
        className="w-72 p-2"
        sideOffset={8}
      >
        <div className="px-2 py-2 text-xs font-semibold uppercase tracking-wider text-muted-foreground">
          主题外观
        </div>
        <div className="space-y-1">
          {THEMES.map((t) => (
            <button
              key={t.id}
              onClick={() => {
                setTheme(t.id);
                setOpen(false);
              }}
              className={`flex w-full items-start gap-3 rounded-md p-2 text-left transition-colors hover:bg-accent ${
                theme === t.id ? "bg-accent/60" : ""
              }`}
            >
              <span
                className="mt-0.5 h-9 w-9 shrink-0 rounded-md ring-1 ring-border"
                style={{ background: swatch[t.id] }}
                aria-hidden
              />
              <span className="flex-1">
                <span className="flex items-center gap-1.5 text-sm font-medium">
                  {t.label}
                  {theme === t.id && (
                    <CheckIcon size={14} className="text-primary" />
                  )}
                </span>
                <span className="mt-0.5 block text-xs text-muted-foreground">
                  {t.hint}
                </span>
              </span>
            </button>
          ))}
        </div>
      </PopoverContent>
    </Popover>
  );
}
