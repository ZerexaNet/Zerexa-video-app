/**
 * UI helpers: number formatting, dates, durations, and string
 * sanitisation for the danmaku layer.
 */

export function formatViews(n: number): string {
  if (n >= 1_0000_0000) return (n / 1_0000_0000).toFixed(1) + "亿";
  if (n >= 1_0000) return (n / 1_0000).toFixed(1) + "万";
  return String(n);
}

export function formatCount(n: number): string {
  if (n >= 1000) return (n / 1000).toFixed(1) + "K";
  return String(n);
}

export function formatRelativeTime(date: string | Date | null | undefined): string {
  if (date === null || date === undefined) return "未知";
  const d =
    typeof date === "string" ? new Date(date.replace(" ", "T")) : date;
  if (!d || isNaN(d.getTime())) return "未知";
  const diff = Date.now() - d.getTime();
  const s = Math.floor(diff / 1000);
  if (s < 0) return "刚刚";
  if (s < 60) return "刚刚";
  const m = Math.floor(s / 60);
  if (m < 60) return m + "分钟前";
  const h = Math.floor(m / 60);
  if (h < 24) return h + "小时前";
  const day = Math.floor(h / 24);
  if (day < 30) return day + "天前";
  const month = Math.floor(day / 30);
  if (month < 12) return month + "个月前";
  return Math.floor(month / 12) + "年前";
}

export function formatDuration(seconds: number): string {
  const m = Math.floor(seconds / 60);
  const s = Math.floor(seconds % 60);
  return `${m}:${s.toString().padStart(2, "0")}`;
}

export function formatDate(date: string | Date | null | undefined): string {
  if (date === null || date === undefined) return "未知";
  const d =
    typeof date === "string" ? new Date(date.replace(" ", "T")) : date;
  if (!d || isNaN(d.getTime())) return "未知";
  const y = d.getFullYear();
  const m = (d.getMonth() + 1).toString().padStart(2, "0");
  const day = d.getDate().toString().padStart(2, "0");
  return `${y}-${m}-${day}`;
}

/** Split a video category string ("Music / MV") into its display parts. */
export function splitCategory(c: string): { root: string; sub: string | null } {
  const [root, sub] = c.split("/").map((s) => s.trim());
  return { root: root ?? c, sub: sub ?? null };
}

/** Map a category root to a Tailwind gradient class for tile covers. */
export function categoryGradient(category: string): string {
  const { root } = splitCategory(category);
  const map: Record<string, string> = {
    Music: "from-blue-500 via-sky-500 to-cyan-500",
    Gaming: "from-emerald-500 via-teal-500 to-cyan-500",
    Tech: "from-blue-500 via-indigo-500 to-cyan-500",
    Life: "from-amber-500 via-orange-500 to-rose-500",
    Entertainment: "from-rose-500 via-red-500 to-orange-500",
    Sports: "from-lime-500 via-green-500 to-emerald-500",
    Food: "from-orange-500 via-amber-500 to-yellow-500",
    Travel: "from-cyan-500 via-sky-500 to-blue-500",
    Fashion: "from-pink-500 via-rose-500 to-red-500",
    Education: "from-blue-500 via-sky-500 to-teal-500",
    News: "from-slate-500 via-gray-500 to-zinc-500",
    Film: "from-indigo-500 via-blue-500 to-cyan-500",
    Auto: "from-zinc-500 via-slate-500 to-gray-500",
    Art: "from-fuchsia-500 via-pink-500 to-rose-500",
    General: "from-teal-500 via-cyan-500 to-blue-500",
    Charity: "from-emerald-500 via-green-500 to-lime-500",
  };
  return map[root] ?? "from-blue-500 via-sky-500 to-cyan-500";
}

/** Sanitise user-controlled strings before injecting into the DOM. */
export function escapeHtml(s: string): string {
  return s
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

/** Truncate text with an ellipsis. */
export function truncate(s: string, n: number): string {
  return s.length <= n ? s : s.slice(0, n - 1) + "…";
}
