"use client";

/**
 * Video card / tile.
 *
 * Renders a single video item from the list endpoint. Adapts its
 * visual treatment to the active theme:
 *   - Material You: rounded 16:9 with soft elevation
 *   - Metro: flat solid tiles with hard edges
 *   - Zerexa Purple: subtle purple ring on hover
 *   - Midnight: dark surface with bright accent
 *
 * The cover is either the remote cover image (when available) or a
 * procedurally generated gradient with the title overlaid - this way
 * missing covers do not break the layout.
 */

import { memo, useState } from "react";
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import { VerifiedBadge, PlayIcon, EyeIcon } from "@/components/icons";
import { type VideoListItem } from "@/lib/api";
import { api } from "@/lib/api";
import { useRoute } from "@/lib/route";
import {
  categoryGradient,
  formatRelativeTime,
  formatViews,
  splitCategory,
  truncate,
} from "@/lib/format";
import { useThemeStore } from "@/lib/theme";

interface VideoCardProps {
  video: VideoListItem;
  priority?: boolean;
}

function VideoCardImpl({ video, priority }: VideoCardProps) {
  const { goWatch } = useRoute();
  const theme = useThemeStore((s) => s.theme);
  const [imgError, setImgError] = useState(false);

  const cover = api.resolveAsset(video.cover_url);
  const showImage = cover && !imgError;
  const grad = categoryGradient(video.category);
  const { root } = splitCategory(video.category);

  const aspect =
    theme === "metro" ? "aspect-[16/9]" : "aspect-video";

  return (
    <article
      onClick={() => goWatch(video.id)}
      className={`group relative cursor-pointer overflow-hidden transition-all ${
        theme === "metro"
          ? "metro-tile bg-card text-card-foreground"
          : "rounded-xl bg-card text-card-foreground shadow-[var(--tile-elevation)] hover:shadow-[var(--tile-shadow-hover)] hover:-translate-y-0.5"
      }`}
    >
      <div className={`relative ${aspect} overflow-hidden bg-muted`}>
        {showImage ? (
          <img
            src={cover}
            alt={video.title}
            loading={priority ? "eager" : "lazy"}
            onError={() => setImgError(true)}
            className="absolute inset-0 h-full w-full object-cover transition-transform duration-300 group-hover:scale-105"
          />
        ) : (
          <div
            className={`absolute inset-0 bg-gradient-to-br ${grad} opacity-90`}
          >
            <div className="flex h-full w-full items-center justify-center p-4 text-center">
              <span className="line-clamp-3 text-lg font-bold text-white drop-shadow-md">
                {truncate(video.title, 60)}
              </span>
            </div>
            <div className="absolute bottom-2 left-2 rounded bg-black/40 px-2 py-0.5 text-xs text-white">
              {root}
            </div>
          </div>
        )}

        {/* Hover play overlay */}
        <div className="absolute inset-0 flex items-center justify-center bg-black/0 opacity-0 transition-opacity duration-200 group-hover:bg-black/30 group-hover:opacity-100">
          <span className="flex h-12 w-12 items-center justify-center rounded-full bg-white/90 text-black shadow-lg">
            <PlayIcon size={22} />
          </span>
        </div>

        {/* Category chip */}
        {showImage && (
          <span className="absolute left-2 top-2 rounded bg-black/60 px-2 py-0.5 text-[10px] font-medium uppercase tracking-wide text-white backdrop-blur">
            {root}
          </span>
        )}

        {/* Views overlay */}
        <span className="absolute bottom-2 right-2 flex items-center gap-1 rounded bg-black/60 px-1.5 py-0.5 text-[11px] text-white backdrop-blur">
          <EyeIcon size={11} />
          {formatViews(video.views)}
        </span>
      </div>

      <div className="space-y-2 p-3">
        <h3 className="line-clamp-2 text-sm font-semibold leading-snug">
          {video.title}
        </h3>
        <div className="flex items-center gap-2 text-xs text-muted-foreground">
          <Avatar className="h-6 w-6 border border-border">
            <AvatarImage
              src={video.author_gravatar_url ?? undefined}
              alt={video.author_username}
            />
            <AvatarFallback className="text-[10px]">
              {video.author_username.slice(0, 1).toUpperCase()}
            </AvatarFallback>
          </Avatar>
          <span className="flex items-center gap-1 truncate">
            {video.author_username}
            {video.author_verification_badge && (
              <VerifiedBadge
                color={video.author_verification_badge}
                size={12}
              />
            )}
          </span>
          <span className="ml-auto whitespace-nowrap">
            {formatRelativeTime(video.created_at)}
          </span>
        </div>
      </div>
    </article>
  );
}

export const VideoCard = memo(VideoCardImpl);
