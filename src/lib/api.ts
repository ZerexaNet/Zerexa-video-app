/**
 * Zerexa Video API client
 *
 * Upstream base: https://video.zerexa.net
 * Local proxy:   /api/zerexa  (configured in src/app/api/zerexa/[...path]/route.ts)
 *
 * The remote API does not enable CORS, so all browser requests are
 * routed through a server-side proxy at /api/zerexa. This keeps the
 * token inside the browser (still in localStorage as "zv_token") while
 * avoiding CORS pre-flight failures.
 *
 * Auth: JWT Bearer token stored in localStorage under key "zv_token".
 */

export const API_BASE = "/api/zerexa";
export const UPSTREAM_BASE = "https://video.zerexa.net";

// ---------- Types ----------

export type VerificationBadge = "yellow" | "green" | null | string;

export interface VideoListItem {
  id: string;
  title: string;
  views: number;
  category: string;
  created_at: string;
  external_cover_url: string | null;
  external_player_url: string | null;
  author_username: string;
  author_uid: number;
  author_verification_badge: VerificationBadge;
  author_verification_label: string | null;
  author_gravatar_url: string | null;
  likes: number;
  fav_count?: number;
  coin_count?: number;
  confusion_count: number;
  stream_url: string;
  cover_url: string | null;
}

export interface VideoDetail extends VideoListItem {
  description: string | null;
  status: "approved" | "pending" | "rejected" | string;
  source_url: string | null;
  scheduled_at: string | null;
  ip_location: string | null;
  author_ip_location: string | null;
  collection: unknown | null;
}

export interface Announcement {
  id: string;
  title: string;
  content: string;
  /** Truthiness flag; upstream has used both number (0/1) and boolean. */
  is_active: number | boolean;
  created_by: string;
  created_at: string;
  updated_at: string;
}

export interface Comment {
  id: string;
  content: string;
  created_at: string;
  author_uid: number;
  author_username: string;
  author_gravatar_url: string | null;
  author_verification_badge?: VerificationBadge;
  author_verification_label?: string | null;
  parent_id?: string | null;
  likes?: number;
  liked?: boolean;
  replies?: Comment[];
}

export interface CommentList {
  items: Comment[];
  total: number;
  limit: number;
  offset: number;
}

export interface DanmakuItem {
  id?: string;
  text: string;
  time: number; // seconds
  type?: "scroll" | "top" | "bottom";
  color?: string;
  author_username?: string;
}

export interface UserInfo {
  uid: number;
  username: string;
  email?: string;
  role?: string;
  bio?: string | null;
  gravatar_url?: string | null;
  verification_badge?: VerificationBadge;
  verification_label?: string | null;
  created_at?: string;
  points?: number;
  signed_in_today?: boolean;
}

/**
 * Admin-facing user record. The /api/admin/users endpoint returns a
 * richer shape than the public /api/user endpoint: it includes email,
 * role, ban status, and registration metadata that the public API
 * intentionally hides.
 */
export interface AdminUser {
  id: string;
  uid?: number;
  username: string;
  email?: string | null;
  role?: string;
  bio?: string | null;
  gravatar_url?: string | null;
  verification_badge?: VerificationBadge;
  verification_label?: string | null;
  is_banned?: number | boolean;
  banned?: number | boolean;
  status?: string;
  points?: number;
  created_at?: string;
  updated_at?: string;
  last_login_at?: string | null;
  ip_location?: string | null;
  video_count?: number;
  follower_count?: number;
  following_count?: number;
}

/**
 * Admin-facing report record. The exact field set is opaque to us
 * (the upstream API is not documented in detail), so most fields
 * are optional.
 */
export interface AdminReport {
  id: string;
  reporter_uid?: number;
  reporter_username?: string;
  target_type?: string;
  target_id?: string;
  target_title?: string;
  reason?: string;
  status?: string;
  created_at?: string;
  updated_at?: string;
  handler_uid?: number | null;
  handler_username?: string | null;
  resolution?: string | null;
}

export interface AdminAnnouncementInput {
  title: string;
  content: string;
  is_active?: number | boolean;
}

export interface AdminVideoUpdateInput {
  title?: string;
  description?: string | null;
  category?: string;
  status?: "approved" | "pending" | "rejected";
  scheduled_at?: string | null;
}

export interface SearchResult {
  videos: VideoListItem[];
}

export interface Paginated<T> {
  items: T[];
  total: number;
  limit: number;
  offset: number;
}

// ---------- Token helpers ----------

const TOKEN_KEY = "zv_token";

export function getToken(): string | null {
  if (typeof window === "undefined") return null;
  return localStorage.getItem(TOKEN_KEY);
}

export function setToken(token: string | null) {
  if (typeof window === "undefined") return;
  if (token) localStorage.setItem(TOKEN_KEY, token);
  else localStorage.removeItem(TOKEN_KEY);
}

// ---------- Low-level fetch helper ----------

interface FetchOpts {
  method?: "GET" | "POST" | "PUT" | "DELETE" | "PATCH";
  body?: unknown;
  query?: Record<string, string | number | boolean | undefined | null>;
  auth?: boolean;
  // When `raw` is true, return the raw Response instead of parsed JSON
  // (useful for non-JSON endpoints such as image proxies).
  raw?: boolean;
  signal?: AbortSignal;
}

function buildUrl(path: string, query?: FetchOpts["query"]) {
  // Compose the relative path first, then attach query params via
  // URLSearchParams so we don't need a base URL (the browser treats
  // relative paths as same-origin).
  const base = `${API_BASE}${path}`;
  if (!query) return base;
  const params = new URLSearchParams();
  for (const [k, v] of Object.entries(query)) {
    if (v === undefined || v === null) continue;
    params.set(k, String(v));
  }
  const qs = params.toString();
  return qs ? `${base}?${qs}` : base;
}

export class ApiError extends Error {
  status: number;
  detail?: unknown;
  constructor(message: string, status: number, detail?: unknown) {
    super(message);
    this.status = status;
    this.detail = detail;
  }
}

export async function apiFetch<T>(
  path: string,
  opts: FetchOpts = {},
): Promise<T> {
  const url = buildUrl(path, opts.query);
  const headers: Record<string, string> = {
    Accept: "application/json",
  };
  if (opts.auth) {
    const t = getToken();
    if (t) headers["Authorization"] = `Bearer ${t}`;
  }
  if (opts.body !== undefined) {
    headers["Content-Type"] = "application/json";
  }
  let resp: Response;
  try {
    resp = await fetch(url, {
      method: opts.method ?? "GET",
      headers,
      body: opts.body !== undefined ? JSON.stringify(opts.body) : undefined,
      signal: opts.signal,
    });
  } catch (e) {
    throw new ApiError(
      `Network error: ${e instanceof Error ? e.message : "unknown"}`,
      0,
    );
  }
  if (opts.raw) return resp as unknown as T;
  if (resp.status === 204) return undefined as T;
  let data: unknown = null;
  const ct = resp.headers.get("content-type") ?? "";
  if (ct.includes("application/json")) {
    try {
      data = await resp.json();
    } catch {
      data = null;
    }
  } else {
    data = await resp.text();
  }
  if (!resp.ok) {
    const msg =
      (data && typeof data === "object" && "message" in data
        ? String((data as { message: unknown }).message)
        : null) ?? `HTTP ${resp.status}`;
    throw new ApiError(msg, resp.status, data);
  }
  return data as T;
}

// ---------- Endpoints ----------

export const api = {
  ping: () => apiFetch<{ pong: boolean }>("/api/ping"),

  // Auth
  checkUsername: (username: string) =>
    apiFetch<{ available: boolean }>(
      "/api/auth/check-username",
      { query: { username }, method: "GET" },
    ),
  register: (body: {
    username: string;
    email: string;
    password: string;
  }) =>
    apiFetch<{ token?: string; message?: string }>(
      "/api/auth/register",
      { method: "POST", body },
    ),
  login: (body: { identifier: string; password: string }) =>
    apiFetch<{ token?: string; message?: string }>(
      "/api/auth/login",
      { method: "POST", body },
    ),
  logout: () =>
    apiFetch<{ message?: string }>("/api/auth/logout", {
      method: "POST",
      auth: true,
    }),

  // User
  me: () => apiFetch<UserInfo>("/api/user", { auth: true }),
  getUserPublic: (uid: number) =>
    apiFetch<UserInfo>(`/api/user/${uid}`),
  history: () =>
    apiFetch<unknown[]>("/api/user/history", { auth: true }),
  favorites: () =>
    apiFetch<unknown[]>("/api/user/favorites", { auth: true }),
  following: () =>
    apiFetch<unknown[]>("/api/user/following", { auth: true }),
  followers: () =>
    apiFetch<unknown[]>("/api/user/followers", { auth: true }),

  // Videos
  listVideos: (params: {
    limit?: number;
    offset?: number;
    category?: string;
    sort?: string;
  } = {}) =>
    apiFetch<VideoListItem[]>("/api/videos", { query: params }),
  getVideo: (id: string) =>
    apiFetch<VideoDetail>(`/api/videos/${id}`),
  likeVideo: (id: string) =>
    apiFetch<{ liked: boolean; likes: number }>(
      `/api/videos/${id}/like`,
      { method: "POST", auth: true },
    ),
  favoriteVideo: (id: string) =>
    apiFetch<{ favorited: boolean }>("/api/favorites", {
      method: "POST",
      auth: true,
      body: { video_id: id },
    }),
  unfavoriteVideo: (id: string) =>
    apiFetch<{ favorited: boolean }>(
      `/api/favorites/${id}`,
      { method: "DELETE", auth: true },
    ),
  checkFavorite: (id: string) =>
    apiFetch<{ favorited: boolean }>(
      `/api/favorites/${id}/check`,
      { auth: true },
    ),
  coinVideo: (id: string, amount = 1) =>
    apiFetch<{ ok: boolean }>(`/api/videos/${id}/coin`, {
      method: "POST",
      auth: true,
      body: { amount },
    }),

  // Comments & Danmaku
  listComments: (id: string, opts: { limit?: number; offset?: number } = {}) =>
    apiFetch<CommentList>(`/api/videos/${id}/comments`, {
      query: opts,
    }),
  postComment: (id: string, content: string, parentId?: string) =>
    apiFetch<Comment>(`/api/videos/${id}/comments`, {
      method: "POST",
      auth: true,
      body: { content, parent_id: parentId ?? null },
    }),
  listDanmaku: (id: string) =>
    apiFetch<DanmakuItem[]>(`/api/videos/${id}/danmaku`),

  // Search & Announcements
  search: (q: string, opts: { limit?: number; offset?: number } = {}) =>
    apiFetch<SearchResult>("/api/search", {
      query: { q, ...opts },
    }),
  listAnnouncements: () =>
    apiFetch<Announcement[]>("/api/announcements"),

  // Helpers
  resolveAsset: (path: string | null | undefined) => {
    if (!path) return null;
    // Already absolute URL (e.g. gravatar) - return as-is.
    if (path.startsWith("http://") || path.startsWith("https://")) return path;
    // Paths under /api/* on the upstream server (cover images, S3
    // objects, subtitles) are routed through our local proxy at
    // /api/zerexa/<...> so the browser sees them as same-origin.
    if (path.startsWith("/api/")) {
      return `${API_BASE}/${path.replace(/^\/api\//, "")}`;
    }
    // Any other relative path is treated as upstream-relative.
    return `${API_BASE}${path}`;
  },

  // ---------- Admin ----------
  adminListVideos: (params: {
    status?: "pending" | "approved" | "rejected";
    limit?: number;
    offset?: number;
  } = {}) =>
    apiFetch<VideoListItem[] | Paginated<VideoListItem>>("/api/admin/videos", {
      query: params as Record<string, string | number | undefined>,
      auth: true,
    }),
  adminListUsers: (params: {
    role?: string;
    banned?: boolean;
    limit?: number;
    offset?: number;
  } = {}) =>
    apiFetch<AdminUser[] | Paginated<AdminUser>>("/api/admin/users", {
      query: params as Record<string, string | number | boolean | undefined>,
      auth: true,
    }),
  adminListReports: (params: {
    status?: "open" | "closed" | "resolved" | "pending";
    limit?: number;
    offset?: number;
  } = {}) =>
    apiFetch<AdminReport[] | Paginated<AdminReport>>("/api/admin/reports", {
      query: params as Record<string, string | number | undefined>,
      auth: true,
    }),
  adminListAnnouncements: () =>
    apiFetch<Announcement[]>("/api/admin/announcements", { auth: true }),
  adminCreateAnnouncement: (body: AdminAnnouncementInput) =>
    apiFetch<Announcement | { message?: string }>("/api/admin/announcements", {
      method: "POST",
      auth: true,
      body: body as unknown as Record<string, unknown>,
    }),
  adminUpdateAnnouncement: (
    id: string,
    body: Partial<AdminAnnouncementInput> & { id?: string },
  ) =>
    // The upstream does not expose a dedicated PUT/DELETE route for
    // individual announcements, so we re-use the same POST endpoint
    // with an extended body carrying id + action. The admin UI
    // degrades gracefully if the upstream rejects the call.
    apiFetch<Announcement | { message?: string }>("/api/admin/announcements", {
      method: "POST",
      auth: true,
      body: { ...body, id, action: "update" } as unknown as Record<string, unknown>,
    }),
  adminDeleteAnnouncement: (id: string) =>
    apiFetch<{ message?: string } | null>("/api/admin/announcements", {
      method: "POST",
      auth: true,
      body: { id, action: "delete" } as unknown as Record<string, unknown>,
    }),

  // Resource-level actions used by both authors and admins
  updateVideo: (id: string, body: AdminVideoUpdateInput) =>
    apiFetch<VideoDetail | { message?: string }>(`/api/videos/${id}`, {
      method: "PUT",
      auth: true,
      body: body as unknown as Record<string, unknown>,
    }),
  deleteVideo: (id: string) =>
    apiFetch<{ message?: string } | null>(`/api/videos/${id}`, {
      method: "DELETE",
      auth: true,
    }),
};

// Convenience helper used across components for "now safe to call auth" checks.
export function isAuthed(): boolean {
  return !!getToken();
}

/**
 * Inspects a UserInfo record and reports whether the holder has
 * administrator privileges. The upstream API uses a `role` field
 * whose value is a string ("admin", "moderator", "member", ...).
 * We treat both "admin" and "moderator" as admin-capable so that
 * moderation staff can also open the admin shell.
 */
export function isAdminRole(role: string | undefined | null): boolean {
  if (!role) return false;
  const r = role.toLowerCase();
  return r === "admin" || r === "moderator" || r === "superadmin" || r === "super_admin";
}
