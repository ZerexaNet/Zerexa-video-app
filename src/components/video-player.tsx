"use client";

/**
 * Video player with custom controls and danmaku overlay.
 *
 * Wraps a native <video> element with:
 *   - Custom play/pause / seek / volume / fullscreen controls
 *   - Danmaku canvas layer
 *   - Click-to-toggle-play on the video surface
 *   - Keyboard shortcuts (space, arrows, f, m)
 *   - Danmaku send box
 *   - Subtitle track loading + switching (VTT/SRT through <track>)
 */

import * as React from "react";
import { useCallback, useEffect, useRef, useState } from "react";
import { Button } from "@/components/ui/button";
import { Slider } from "@/components/ui/slider";
import { Input } from "@/components/ui/input";
import {
  Popover,
  PopoverContent,
  PopoverTrigger,
} from "@/components/ui/popover";
import {
  PlayIcon,
  PauseIcon,
  VolumeIcon,
  MuteIcon,
  FullscreenIcon,
  SendIcon,
  CaptionsIcon,
} from "@/components/icons";
import {
  DanmakuLayer,
  type DanmakuHandle,
} from "@/components/danmaku-layer";
import { type DanmakuItem, type SubtitleTrack, api } from "@/lib/api";
import { formatDuration } from "@/lib/format";
import { useAuth } from "@/lib/auth";
import { useToast } from "@/hooks/use-toast";
import { cn } from "@/lib/utils";

interface PlayerProps {
  src: string;
  poster?: string | null;
  danmaku: DanmakuItem[];
  onSendDanmaku: (text: string, color: string) => Promise<void>;
  /** Optional list of subtitle tracks for the current video. */
  subtitles?: SubtitleTrack[];
  /** Optional videoId used to lazy-load subtitles when not provided. */
  videoId?: string;
}

export function VideoPlayer({
  src,
  poster,
  danmaku,
  onSendDanmaku,
  subtitles: initialSubtitles,
  videoId,
}: PlayerProps) {
  const videoRef = useRef<HTMLVideoElement>(null);
  const danmakuRef = useRef<DanmakuHandle>(null);
  const containerRef = useRef<HTMLDivElement>(null);
  const [playing, setPlaying] = useState(false);
  const [current, setCurrent] = useState(0);
  const [duration, setDuration] = useState(0);
  const [volume, setVolume] = useState(0.85);
  const [muted, setMuted] = useState(false);
  const [fullscreen, setFullscreen] = useState(false);
  const [showControls, setShowControls] = useState(true);
  const [danmakuOn, setDanmakuOn] = useState(true);
  const [danmakuInput, setDanmakuInput] = useState("");
  const [danmakuColor, setDanmakuColor] = useState("#FFFFFF");
  const [sending, setSending] = useState(false);
  const [buffering, setBuffering] = useState(false);
  const [subtitles, setSubtitles] = useState<SubtitleTrack[]>(initialSubtitles ?? []);
  const [activeSubtitle, setActiveSubtitle] = useState<SubtitleTrack | null>(null);
  const [subtitleOpen, setSubtitleOpen] = useState(false);
  const [subtitleLoading, setSubtitleLoading] = useState(!initialSubtitles && !!videoId);
  const hideTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const { user } = useAuth();
  const { toast } = useToast();

  // Lazy-load subtitles when only videoId is provided
  useEffect(() => {
    if (initialSubtitles && initialSubtitles.length > 0) {
      setSubtitles(initialSubtitles);
      setSubtitleLoading(false);
      // Pick default track if any
      const def = initialSubtitles.find((t) => t.default) ?? null;
      setActiveSubtitle(def);
      return;
    }
    if (!videoId) {
      setSubtitleLoading(false);
      return;
    }
    let cancelled = false;
    setSubtitleLoading(true);
    (async () => {
      try {
        const tracks = await api.listSubtitles(videoId);
        if (cancelled) return;
        const resolved = (tracks ?? []).map((t) => ({
          ...t,
          url: api.resolveAsset(t.url) ?? t.url,
        }));
        setSubtitles(resolved);
        const def = resolved.find((t) => t.default) ?? null;
        setActiveSubtitle(def);
      } catch {
        if (!cancelled) setSubtitles([]);
      } finally {
        if (!cancelled) setSubtitleLoading(false);
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [initialSubtitles, videoId]);

  // Sync video events
  useEffect(() => {
    const v = videoRef.current;
    if (!v) return;
    const onTime = () => setCurrent(v.currentTime);
    const onDur = () => setDuration(v.duration || 0);
    const onPlay = () => setPlaying(true);
    const onPause = () => setPlaying(false);
    const onWaiting = () => setBuffering(true);
    const onPlaying = () => setBuffering(false);
    const onVol = () => {
      setVolume(v.volume);
      setMuted(v.muted);
    };
    v.addEventListener("timeupdate", onTime);
    v.addEventListener("durationchange", onDur);
    v.addEventListener("loadedmetadata", onDur);
    v.addEventListener("play", onPlay);
    v.addEventListener("pause", onPause);
    v.addEventListener("waiting", onWaiting);
    v.addEventListener("playing", onPlaying);
    v.addEventListener("volumechange", onVol);
    return () => {
      v.removeEventListener("timeupdate", onTime);
      v.removeEventListener("durationchange", onDur);
      v.removeEventListener("loadedmetadata", onDur);
      v.removeEventListener("play", onPlay);
      v.removeEventListener("pause", onPause);
      v.removeEventListener("waiting", onWaiting);
      v.removeEventListener("playing", onPlaying);
      v.removeEventListener("volumechange", onVol);
    };
  }, []);

  // Fullscreen change
  useEffect(() => {
    const onFs = () => setFullscreen(!!document.fullscreenElement);
    document.addEventListener("fullscreenchange", onFs);
    return () => document.removeEventListener("fullscreenchange", onFs);
  }, []);

  const togglePlay = useCallback(() => {
    const v = videoRef.current;
    if (!v) return;
    if (v.paused) v.play().catch(() => {});
    else v.pause();
  }, []);

  const seek = (t: number) => {
    const v = videoRef.current;
    if (!v) return;
    v.currentTime = Math.max(0, Math.min(t, v.duration || 0));
    danmakuRef.current?.seek(t);
  };

  const skip = (delta: number) => {
    const v = videoRef.current;
    if (!v) return;
    seek(v.currentTime + delta);
  };

  const toggleMute = () => {
    const v = videoRef.current;
    if (!v) return;
    v.muted = !v.muted;
  };

  const setVol = (val: number) => {
    const v = videoRef.current;
    if (!v) return;
    v.volume = val;
    if (val > 0 && v.muted) v.muted = false;
  };

  const toggleFullscreen = () => {
    const el = containerRef.current;
    if (!el) return;
    if (document.fullscreenElement) {
      document.exitFullscreen().catch(() => {});
    } else {
      el.requestFullscreen().catch(() => {});
    }
  };

  // Switch subtitle track by writing to <track>.mode
  useEffect(() => {
    const v = videoRef.current;
    if (!v) return;
    const tracks = v.textTracks;
    for (let i = 0; i < tracks.length; i++) {
      const t = tracks[i];
      // Match by label (we set the track label to its language)
      const targetLabel = activeSubtitle?.language ?? activeSubtitle?.label ?? "";
      if (t.label === targetLabel || t.language === activeSubtitle?.language) {
        t.mode = "showing";
      } else if (t.mode === "showing") {
        t.mode = "disabled";
      }
    }
    // If no active subtitle, disable all
    if (!activeSubtitle) {
      for (let i = 0; i < tracks.length; i++) {
        tracks[i].mode = "disabled";
      }
    }
  }, [activeSubtitle]);

  // Keyboard shortcuts
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.target instanceof HTMLInputElement || e.target instanceof HTMLTextAreaElement) return;
      switch (e.key) {
        case " ":
        case "k":
          e.preventDefault();
          togglePlay();
          break;
        case "ArrowRight":
          skip(5);
          break;
        case "ArrowLeft":
          skip(-5);
          break;
        case "f":
          toggleFullscreen();
          break;
        case "m":
          toggleMute();
          break;
        case "d":
          setDanmakuOn((s) => !s);
          break;
        case "c":
          // Cycle through subtitles
          setSubtitleOpen(true);
          break;
      }
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [togglePlay]);

  // Auto-hide controls
  const showControlsTemporarily = useCallback(() => {
    setShowControls(true);
    if (hideTimerRef.current) clearTimeout(hideTimerRef.current);
    hideTimerRef.current = setTimeout(() => {
      if (playing) setShowControls(false);
    }, 3000);
  }, [playing]);

  useEffect(() => {
    showControlsTemporarily();
  }, [playing, showControlsTemporarily]);

  const sendDanmaku = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!user) {
      toast({
        title: "请先登录",
        description: "发送弹幕需要登录账户",
        variant: "destructive",
      });
      return;
    }
    const text = danmakuInput.trim();
    if (!text) return;
    setSending(true);
    try {
      await onSendDanmaku(text, danmakuColor);
      // Optimistically render locally
      const v = videoRef.current;
      const t = v?.currentTime ?? 0;
      danmakuRef.current?.add({
        text,
        time: t,
        color: danmakuColor,
        author_username: user.username,
      });
      setDanmakuInput("");
      toast({ title: "弹幕已发送" });
    } catch (err) {
      toast({
        title: "发送失败",
        description: err instanceof Error ? err.message : "请稍后重试",
        variant: "destructive",
      });
    } finally {
      setSending(false);
    }
  };

  const DANMAKU_COLORS = [
    "#FFFFFF",
    "#FF4D4F",
    "#FFD24C",
    "#34D27B",
    "#4D9DFF",
    "#FF6FB5",
    "#3B82F6",
  ];

  return (
    <div
      ref={containerRef}
      className="group relative aspect-video w-full overflow-hidden rounded-xl bg-black"
      onMouseMove={showControlsTemporarily}
      onMouseLeave={() => playing && setShowControls(false)}
    >
      <video
        ref={videoRef}
        src={src}
        poster={poster ?? undefined}
        className="absolute inset-0 h-full w-full object-contain"
        playsInline
        onClick={togglePlay}
        onDoubleClick={toggleFullscreen}
        preload="metadata"
        crossOrigin="anonymous"
      >
        {/* Subtitle tracks */}
        {subtitles.map((t) => {
          const isActive = activeSubtitle?.url === t.url;
          return (
            <track
              key={t.id ?? t.url}
              kind="subtitles"
              src={t.url}
              srcLang={t.language}
              label={t.label ?? t.language}
              default={isActive}
            />
          );
        })}
      </video>

      {/* Danmaku overlay */}
      <DanmakuLayer
        ref={danmakuRef}
        items={danmaku}
        videoRef={videoRef}
        active={danmakuOn}
      />

      {/* Buffering spinner */}
      {buffering && (
        <div className="pointer-events-none absolute inset-0 flex items-center justify-center">
          <div className="h-10 w-10 animate-spin rounded-full border-2 border-white/30 border-t-white" />
        </div>
      )}

      {/* Center play button when paused */}
      {!playing && !buffering && (
        <button
          onClick={togglePlay}
          className="absolute inset-0 z-20 flex items-center justify-center"
          aria-label="播放"
        >
          <span className="flex h-16 w-16 items-center justify-center rounded-full bg-black/60 text-white backdrop-blur transition-transform hover:scale-110">
            <PlayIcon size={28} />
          </span>
        </button>
      )}

      {/* Controls overlay */}
      <div
        className={cn(
          "absolute inset-x-0 bottom-0 z-30 bg-gradient-to-t from-black/85 via-black/40 to-transparent px-3 pb-2 pt-8 transition-opacity duration-200",
          showControls ? "opacity-100" : "opacity-0 pointer-events-none",
        )}
      >
        {/* Progress bar */}
        <div className="flex items-center gap-2">
          <span className="text-xs tabular-nums text-white/90">
            {formatDuration(current)}
          </span>
          <Slider
            value={[current]}
            max={duration || 1}
            step={0.1}
            onValueChange={(v) => seek(v[0])}
            className="flex-1"
            aria-label="进度条"
          />
          <span className="text-xs tabular-nums text-white/90">
            {formatDuration(duration)}
          </span>
        </div>

        {/* Buttons */}
        <div className="mt-1 flex items-center gap-2">
          <Button
            variant="ghost"
            size="icon"
            className="h-9 w-9 text-white hover:bg-white/15"
            onClick={togglePlay}
            aria-label={playing ? "暂停" : "播放"}
          >
            {playing ? <PauseIcon size={18} /> : <PlayIcon size={18} />}
          </Button>
          <Button
            variant="ghost"
            size="icon"
            className="h-9 w-9 text-white hover:bg-white/15"
            onClick={() => skip(-5)}
            aria-label="后退 5 秒"
          >
            <SkipBackIcon size={18} />
          </Button>
          <Button
            variant="ghost"
            size="icon"
            className="h-9 w-9 text-white hover:bg-white/15"
            onClick={() => skip(5)}
            aria-label="前进 5 秒"
          >
            <SkipForwardIcon size={18} />
          </Button>
          <div className="group/vol relative flex items-center">
            <Button
              variant="ghost"
              size="icon"
              className="h-9 w-9 text-white hover:bg-white/15"
              onClick={toggleMute}
              aria-label={muted ? "取消静音" : "静音"}
            >
              {muted || volume === 0 ? (
                <MuteIcon size={18} />
              ) : (
                <VolumeIcon size={18} />
              )}
            </Button>
            <div className="hidden w-20 group-hover/vol:block">
              <Slider
                value={[muted ? 0 : volume * 100]}
                max={100}
                step={1}
                onValueChange={(v) => setVol(v[0] / 100)}
                aria-label="音量"
              />
            </div>
          </div>

          {/* Subtitle selector */}
          <Popover open={subtitleOpen} onOpenChange={setSubtitleOpen}>
            <PopoverTrigger asChild>
              <Button
                variant="ghost"
                size="sm"
                className={`h-9 px-2 text-xs text-white hover:bg-white/15 ${
                  activeSubtitle ? "bg-white/15" : "opacity-70"
                }`}
                aria-label="切换字幕"
                title="字幕"
              >
                <CaptionsIcon size={16} />
                {activeSubtitle && (
                  <span className="ml-1 hidden sm:inline">
                    {activeSubtitle.label ?? activeSubtitle.language}
                  </span>
                )}
              </Button>
            </PopoverTrigger>
            <PopoverContent
              className="w-56 p-1"
              side="top"
              align="center"
            >
              <div className="px-2 py-1.5 text-[10px] font-semibold uppercase tracking-wider text-muted-foreground">
                字幕
              </div>
              <button
                onClick={() => {
                  setActiveSubtitle(null);
                  setSubtitleOpen(false);
                }}
                className={cn(
                  "flex w-full items-center justify-between rounded px-2 py-1.5 text-sm hover:bg-accent",
                  !activeSubtitle && "bg-accent/60",
                )}
              >
                <span>关闭字幕</span>
                {!activeSubtitle && <span className="text-xs">●</span>}
              </button>
              {subtitleLoading ? (
                <p className="px-2 py-2 text-xs text-muted-foreground">
                  加载中...
                </p>
              ) : subtitles.length === 0 ? (
                <p className="px-2 py-2 text-xs text-muted-foreground">
                  此视频暂无字幕
                </p>
              ) : (
                subtitles.map((t) => {
                  const isActive = activeSubtitle?.url === t.url;
                  return (
                    <button
                      key={t.id ?? t.url}
                      onClick={() => {
                        setActiveSubtitle(t);
                        setSubtitleOpen(false);
                      }}
                      className={cn(
                        "flex w-full items-center justify-between rounded px-2 py-1.5 text-sm hover:bg-accent",
                        isActive && "bg-accent/60",
                      )}
                    >
                      <span className="truncate">
                        {t.label ?? t.language}
                      </span>
                      <span className="ml-2 text-[10px] text-muted-foreground">
                        {t.format?.toUpperCase() ?? "VTT"}
                      </span>
                    </button>
                  );
                })
              )}
            </PopoverContent>
          </Popover>

          {/* Danmaku input */}
          <form onSubmit={sendDanmaku} className="ml-2 flex flex-1 items-center gap-2">
            <Button
              type="button"
              variant="ghost"
              size="sm"
              className={`h-9 px-2 text-xs text-white hover:bg-white/15 ${
                danmakuOn ? "bg-white/15" : "opacity-50"
              }`}
              onClick={() => setDanmakuOn((s) => !s)}
              aria-label="切换弹幕显示"
            >
              弹 {danmakuOn ? "ON" : "OFF"}
            </Button>
            <div className="hidden items-center gap-1 sm:flex">
              {DANMAKU_COLORS.map((c) => (
                <button
                  key={c}
                  type="button"
                  onClick={() => setDanmakuColor(c)}
                  className={`h-4 w-4 rounded-full border ${
                    danmakuColor === c ? "border-white ring-2 ring-white/40" : "border-white/30"
                  }`}
                  style={{ background: c }}
                  aria-label={`选择颜色 ${c}`}
                />
              ))}
            </div>
            <Input
              value={danmakuInput}
              onChange={(e) => setDanmakuInput(e.target.value)}
              maxLength={50}
              placeholder="发条弹幕见证当下..."
              className="h-9 flex-1 border-white/20 bg-black/40 text-sm text-white placeholder:text-white/50"
            />
            <Button
              type="submit"
              size="icon"
              disabled={sending || !danmakuInput.trim()}
              className="h-9 w-9 bg-primary text-primary-foreground hover:bg-primary/90"
              aria-label="发送弹幕"
            >
              <SendIcon size={16} />
            </Button>
          </form>

          <Button
            variant="ghost"
            size="icon"
            className="h-9 w-9 text-white hover:bg-white/15"
            onClick={toggleFullscreen}
            aria-label="全屏"
          >
            <FullscreenIcon size={18} />
          </Button>
        </div>
      </div>
    </div>
  );
}

// Skip icons - defined locally to keep imports tidy
function SkipBackIcon({ size = 24 }: { size?: number }) {
  return (
    <svg
      xmlns="http://www.w3.org/2000/svg"
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth={2}
      strokeLinecap="round"
      strokeLinejoin="round"
    >
      <polygon points="19 20 9 12 19 4 19 20" fill="currentColor" stroke="none" />
      <line x1="5" y1="19" x2="5" y2="5" />
    </svg>
  );
}
function SkipForwardIcon({ size = 24 }: { size?: number }) {
  return (
    <svg
      xmlns="http://www.w3.org/2000/svg"
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth={2}
      strokeLinecap="round"
      strokeLinejoin="round"
    >
      <polygon points="5 4 15 12 5 20 5 4" fill="currentColor" stroke="none" />
      <line x1="19" y1="5" x2="19" y2="19" />
    </svg>
  );
}
