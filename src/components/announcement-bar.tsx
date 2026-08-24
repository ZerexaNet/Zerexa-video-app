"use client";

/**
 * Announcement banner.
 *
 * Pulls the latest announcements from /api/announcements and
 * rotates through them with a dismissible marquee-like strip at
 * the top of the home page.
 */

import { useEffect, useState } from "react";
import {
  BellIcon,
  ChevronRightIcon,
  CloseIcon,
} from "@/components/icons";
import { api, type Announcement } from "@/lib/api";
import {
  Tooltip,
  TooltipContent,
  TooltipProvider,
  TooltipTrigger,
} from "@/components/ui/tooltip";
import { formatRelativeTime } from "@/lib/format";

export function AnnouncementBar() {
  const [items, setItems] = useState<Announcement[]>([]);
  const [idx, setIdx] = useState(0);
  const [closed, setClosed] = useState(false);

  useEffect(() => {
    let alive = true;
    api
      .listAnnouncements()
      .then((d) => {
        if (alive) setItems(d);
      })
      .catch(() => {});
    return () => {
      alive = false;
    };
  }, []);

  useEffect(() => {
    if (items.length <= 1) return;
    const t = setInterval(() => {
      setIdx((i) => (i + 1) % items.length);
    }, 6000);
    return () => clearInterval(t);
  }, [items.length]);

  if (closed || items.length === 0) return null;
  const cur = items[idx];

  return (
    <div className="border-b border-border bg-gradient-to-r from-primary/10 via-primary/5 to-transparent">
      <div className="mx-auto flex max-w-7xl items-center gap-2 px-4 py-2 sm:px-6">
        <span className="flex h-7 w-7 shrink-0 items-center justify-center rounded-full bg-primary/15 text-primary">
          <BellIcon size={14} />
        </span>
        <TooltipProvider>
          <Tooltip>
            <TooltipTrigger asChild>
              <p className="line-clamp-1 flex-1 cursor-pointer text-sm">
                <span className="font-semibold text-primary">
                  公告
                </span>
                <span className="mx-2 text-muted-foreground">·</span>
                <span className="text-foreground/90">{cur.title}</span>
                <span className="ml-2 text-xs text-muted-foreground">
                  {formatRelativeTime(cur.created_at)}
                </span>
              </p>
            </TooltipTrigger>
            <TooltipContent className="max-w-sm">
              <p className="text-xs">{cur.content}</p>
            </TooltipContent>
          </Tooltip>
        </TooltipProvider>
        {items.length > 1 && (
          <span className="hidden text-xs text-muted-foreground sm:inline">
            {idx + 1} / {items.length}
          </span>
        )}
        <button
          onClick={() => setIdx((i) => (i + 1) % items.length)}
          className="hidden h-6 w-6 items-center justify-center rounded-full text-muted-foreground transition-colors hover:bg-accent hover:text-foreground sm:flex"
          aria-label="下一条"
        >
          <ChevronRightIcon size={14} />
        </button>
        <button
          onClick={() => setClosed(true)}
          className="flex h-6 w-6 items-center justify-center rounded-full text-muted-foreground transition-colors hover:bg-accent hover:text-foreground"
          aria-label="关闭公告"
        >
          <CloseIcon size={14} />
        </button>
      </div>
    </div>
  );
}
