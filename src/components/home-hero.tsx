"use client";

/**
 * Home page hero banner.
 *
 * A bold purple gradient panel with the site tagline, three primary
 * call-to-action buttons (推荐 / 最新 / 热门), and a small grid of
 * quick stats. Visual treatment adjusts per active theme.
 */

import { Button } from "@/components/ui/button";
import {
  CompassIcon,
  FireIcon,
  RefreshIcon,
  PlayIcon,
} from "@/components/icons";
import { useRoute } from "@/lib/route";
import { useThemeStore } from "@/lib/theme";

interface HomeHeroProps {
  onPickSort: (s: "recommended" | "latest" | "hot") => void;
  activeSort: "recommended" | "latest" | "hot";
}

export function HomeHero({ onPickSort, activeSort }: HomeHeroProps) {
  const { goHome } = useRoute();
  const theme = useThemeStore((s) => s.theme);

  return (
    <section
      className={`relative overflow-hidden ${
        theme === "metro" ? "metro-tile" : "rounded-2xl"
      }`}
      style={{ background: "var(--hero-gradient)" }}
    >
      {/* Decorative grid */}
      <div
        className="absolute inset-0 opacity-20"
        style={{
          backgroundImage:
            "linear-gradient(to right, rgba(255,255,255,0.1) 1px, transparent 1px), linear-gradient(to bottom, rgba(255,255,255,0.1) 1px, transparent 1px)",
          backgroundSize: "32px 32px",
        }}
      />

      {/* Decorative blobs */}
      <div className="absolute -right-32 -top-32 h-72 w-72 rounded-full bg-white/15 blur-3xl" />
      <div className="absolute -bottom-32 -left-32 h-72 w-72 rounded-full bg-black/15 blur-3xl" />

      <div className="relative px-6 py-12 sm:px-10 sm:py-16">
        <div className="max-w-3xl">
          <span className="inline-flex items-center gap-1.5 rounded-full bg-white/15 px-3 py-1 text-xs font-medium text-white backdrop-blur">
            <PlayIcon size={12} />
            Zerexa Video 2.0
          </span>
          <h1 className="mt-4 text-4xl font-extrabold leading-tight text-white sm:text-5xl">
            视频 · 专栏 · 动态
            <br />
            全新社区体验
          </h1>
          <p className="mt-4 max-w-xl text-base text-white/85 sm:text-lg">
            弹幕互动、点赞投币、合集收藏、公投共治 —— 在这里发现有趣的内容、
            关注志同道合的创作者、参与社区治理。
          </p>

          <div className="mt-7 flex flex-wrap items-center gap-2">
            <Button
              onClick={() => onPickSort("recommended")}
              variant={activeSort === "recommended" ? "secondary" : "outline"}
              className={`h-11 px-5 ${
                activeSort === "recommended"
                  ? "bg-white text-primary hover:bg-white/90"
                  : "border-white/40 bg-white/10 text-white hover:bg-white/20"
              }`}
            >
              <CompassIcon size={18} className="mr-1.5" />
              推荐
            </Button>
            <Button
              onClick={() => onPickSort("latest")}
              variant={activeSort === "latest" ? "secondary" : "outline"}
              className={`h-11 px-5 ${
                activeSort === "latest"
                  ? "bg-white text-primary hover:bg-white/90"
                  : "border-white/40 bg-white/10 text-white hover:bg-white/20"
              }`}
            >
              <RefreshIcon size={18} className="mr-1.5" />
              最新
            </Button>
            <Button
              onClick={() => onPickSort("hot")}
              variant={activeSort === "hot" ? "secondary" : "outline"}
              className={`h-11 px-5 ${
                activeSort === "hot"
                  ? "bg-white text-primary hover:bg-white/90"
                  : "border-white/40 bg-white/10 text-white hover:bg-white/20"
              }`}
            >
              <FireIcon size={18} className="mr-1.5" />
              热门
            </Button>
          </div>
        </div>

        {/* Quick stats */}
        <div className="mt-10 grid grid-cols-2 gap-3 sm:grid-cols-4 sm:gap-4">
          {[
            { label: "在线视频", value: "1,200+" },
            { label: "活跃创作者", value: "320+" },
            { label: "弹幕互动", value: "实时" },
            { label: "公投议题", value: "进行中" },
          ].map((s) => (
            <div
              key={s.label}
              className={`bg-white/10 p-3 backdrop-blur ${
                theme === "metro" ? "" : "rounded-lg"
              }`}
            >
              <p className="text-xs text-white/70">{s.label}</p>
              <p className="mt-1 text-lg font-bold text-white">{s.value}</p>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
