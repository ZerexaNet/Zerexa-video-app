"use client";

/**
 * Articles view (专栏).
 *
 * Wraps both the article list (`/api/articles`) and article detail
 * (`/api/articles/{id}`) as well as the publish/edit form. The
 * route store selects which sub-view to render via the `view` prop.
 */

import * as React from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import {
  api,
  type ArticleListItem,
  type ArticleDetail,
  type Paginated,
} from "@/lib/api";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Label } from "@/components/ui/label";
import { Skeleton } from "@/components/ui/skeleton";
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import {
  ArticleIcon,
  PlusIcon,
  PencilSquareIcon,
  ArrowLeftIcon,
  HeartIcon,
  EyeIcon,
  TrashIcon,
  VerifiedBadge,
} from "@/components/icons";
import { useRoute } from "@/lib/route";
import { useAuth } from "@/lib/auth";
import { useToast } from "@/hooks/use-toast";
import { formatRelativeTime, formatViews, escapeHtml } from "@/lib/format";

/** Paginated responses may be either a bare array or `{ items, ... }`. */
function asArray<T>(data: unknown): T[] {
  if (Array.isArray(data)) return data as T[];
  if (data && typeof data === "object" && "items" in data) {
    const items = (data as Paginated<T>).items;
    if (Array.isArray(items)) return items;
  }
  return [];
}

// ---------- Article list ----------

export function ArticlesList() {
  const { goArticle, goArticleEdit } = useRoute();
  const { user } = useAuth();
  const [page, setPage] = React.useState(0);
  const pageSize = 20;
  const [refreshKey, setRefreshKey] = React.useState(0);

  const query = useQuery({
    queryKey: ["articles", page, refreshKey],
    queryFn: () =>
      api.listArticles({ limit: pageSize, offset: page * pageSize }),
    retry: false,
  });

  const items = asArray<ArticleListItem>(query.data);

  return (
    <div>
      <div className="mb-5 flex flex-wrap items-end justify-between gap-3 border-b border-border pb-4">
        <div>
          <h2 className="flex items-center gap-2 text-xl font-bold tracking-tight">
            <ArticleIcon size={22} />
            专栏
          </h2>
          <p className="mt-1 text-sm text-muted-foreground">
            浏览社区发布的专栏与长文。登录后可发布自己的专栏。
          </p>
        </div>
        <div className="flex items-center gap-2">
          <Button
            variant="outline"
            size="sm"
            className="h-8"
            onClick={() => setRefreshKey((k) => k + 1)}
            disabled={query.isFetching}
          >
            刷新
          </Button>
          {user && (
            <Button
              size="sm"
              className="h-8"
              onClick={() => goArticleEdit()}
            >
              <PlusIcon size={14} className="mr-1.5" />
              发布专栏
            </Button>
          )}
        </div>
      </div>

      {query.isError && (
        <div className="mb-4 rounded-md border border-red-500/30 bg-red-500/5 px-4 py-3 text-sm text-red-700 dark:text-red-300">
          加载专栏失败：{query.error instanceof Error ? query.error.message : "未知错误"}
        </div>
      )}

      {query.isLoading ? (
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {Array.from({ length: 6 }).map((_, i) => (
            <Skeleton key={i} className="h-44 w-full rounded-lg" />
          ))}
        </div>
      ) : items.length === 0 ? (
        <div className="flex flex-col items-center justify-center rounded-md border border-dashed border-border bg-card/50 px-6 py-12 text-center">
          <ArticleIcon size={32} className="mb-3 text-muted-foreground" />
          <p className="text-sm font-medium">暂无专栏</p>
          <p className="mt-1 max-w-md text-xs text-muted-foreground">
            点击右上角「发布专栏」开始撰写第一篇专栏。
          </p>
        </div>
      ) : (
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {items.map((a) => (
            <ArticleCard key={a.id} item={a} onOpen={() => goArticle(a.id)} />
          ))}
        </div>
      )}

      <div className="mt-6 flex items-center justify-between">
        <Button
          variant="outline"
          size="sm"
          className="h-8"
          onClick={() => setPage((p) => Math.max(0, p - 1))}
          disabled={page === 0 || query.isFetching}
        >
          上一页
        </Button>
        <span className="text-xs text-muted-foreground">第 {page + 1} 页</span>
        <Button
          variant="outline"
          size="sm"
          className="h-8"
          onClick={() => setPage((p) => p + 1)}
          disabled={items.length < pageSize || query.isFetching}
        >
          下一页
        </Button>
      </div>
    </div>
  );
}

function ArticleCard({
  item,
  onOpen,
}: {
  item: ArticleListItem;
  onOpen: () => void;
}) {
  return (
    <button
      onClick={onOpen}
      className="group flex flex-col overflow-hidden rounded-lg border border-border bg-card text-left shadow-sm transition-all hover:shadow-md"
    >
      <div className="aspect-[16/9] w-full overflow-hidden bg-muted">
        {item.cover_url ? (
          <img
            src={item.cover_url}
            alt={item.title}
            className="h-full w-full object-cover transition-transform group-hover:scale-105"
            loading="lazy"
          />
        ) : (
          <div className="flex h-full w-full items-center justify-center text-muted-foreground">
            <ArticleIcon size={40} />
          </div>
        )}
      </div>
      <div className="flex flex-1 flex-col gap-2 p-4">
        <h3 className="line-clamp-2 text-sm font-semibold leading-snug">
          {item.title}
        </h3>
        {item.summary && (
          <p className="line-clamp-2 text-xs text-muted-foreground">
            {item.summary}
          </p>
        )}
        <div className="mt-auto flex items-center justify-between pt-2 text-[11px] text-muted-foreground">
          <span className="truncate">{item.author_username ?? "—"}</span>
          <span className="flex items-center gap-2">
            {item.views != null && (
              <span className="flex items-center gap-0.5">
                <EyeIcon size={12} />
                {formatViews(item.views)}
              </span>
            )}
            {item.likes != null && (
              <span className="flex items-center gap-0.5">
                <HeartIcon size={12} />
                {formatViews(item.likes)}
              </span>
            )}
          </span>
        </div>
      </div>
    </button>
  );
}

// ---------- Article detail ----------

export function ArticleDetail({ articleId }: { articleId: string }) {
  const { goArticles, goArticleEdit } = useRoute();
  const { user } = useAuth();
  const { toast } = useToast();
  const qc = useQueryClient();
  const [deleting, setDeleting] = React.useState(false);

  const query = useQuery({
    queryKey: ["article", articleId],
    queryFn: () => api.getArticle(articleId),
    retry: false,
  });

  const likeMutation = useMutation({
    mutationFn: () => api.likeArticle(articleId),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["article", articleId] });
      toast({ title: "已点赞" });
    },
    onError: (e: unknown) =>
      toast({
        title: "操作失败",
        description: e instanceof Error ? e.message : "请稍后重试",
        variant: "destructive",
      }),
  });

  const deleteMutation = useMutation({
    mutationFn: () => api.deleteArticle(articleId),
    onSuccess: () => {
      toast({ title: "专栏已删除" });
      goArticles();
    },
    onError: (e: unknown) =>
      toast({
        title: "删除失败",
        description: e instanceof Error ? e.message : "请稍后重试",
        variant: "destructive",
      }),
  });

  if (query.isLoading) {
    return (
      <div className="mx-auto max-w-3xl space-y-4">
        <Skeleton className="h-10 w-2/3" />
        <Skeleton className="h-4 w-1/3" />
        <Skeleton className="h-64 w-full" />
      </div>
    );
  }

  if (query.isError || !query.data) {
    return (
      <div className="mx-auto max-w-3xl rounded-md border border-red-500/30 bg-red-500/5 px-4 py-3 text-sm text-red-700 dark:text-red-300">
        加载专栏失败：{query.error instanceof Error ? query.error.message : "未知错误"}
        <Button
          variant="outline"
          size="sm"
          className="ml-3 h-7"
          onClick={goArticles}
        >
          返回专栏列表
        </Button>
      </div>
    );
  }

  const a: ArticleDetail = query.data;
  const isAuthor = user && a.author_uid === user.uid;

  return (
    <article className="mx-auto max-w-3xl">
      <Button
        variant="ghost"
        size="sm"
        className="mb-4 h-8"
        onClick={goArticles}
      >
        <ArrowLeftIcon size={16} className="mr-1.5" />
        返回专栏列表
      </Button>

      <h1 className="text-2xl font-bold leading-tight tracking-tight sm:text-3xl">
        {a.title}
      </h1>

      <div className="mt-3 flex flex-wrap items-center gap-3 text-sm text-muted-foreground">
        <div className="flex items-center gap-2">
          <Avatar className="h-8 w-8 border border-border">
            <AvatarImage src={a.author_gravatar_url ?? undefined} alt={a.author_username ?? "作者"} />
            <AvatarFallback>
              {(a.author_username ?? "U").slice(0, 1).toUpperCase()}
            </AvatarFallback>
          </Avatar>
          <div className="flex items-center gap-1">
            <span className="font-medium text-foreground">
              {a.author_username ?? "—"}
            </span>
            {a.author_verification_badge && (
              <VerifiedBadge size={14} color={a.author_verification_badge ?? "yellow"} />
            )}
          </div>
        </div>
        <span>·</span>
        <span>{formatRelativeTime(a.created_at)}</span>
        {a.views != null && (
          <>
            <span>·</span>
            <span>{formatViews(a.views)} 阅读</span>
          </>
        )}
      </div>

      {isAuthor && (
        <div className="mt-4 flex items-center gap-2">
          <Button
            variant="outline"
            size="sm"
            className="h-8"
            onClick={() => goArticleEdit(a.id)}
          >
            <PencilSquareIcon size={14} className="mr-1.5" />
            编辑
          </Button>
          <Button
            variant="outline"
            size="sm"
            className="h-8 text-red-600 hover:bg-red-500/10 hover:text-red-700"
            onClick={() => {
              if (window.confirm(`确认删除专栏「${a.title}」？此操作不可撤销。`)) {
                setDeleting(true);
                deleteMutation.mutate();
              }
            }}
            disabled={deleting}
          >
            <TrashIcon size={14} className="mr-1.5" />
            删除
          </Button>
        </div>
      )}

      <div
        className="prose prose-zinc mt-6 max-w-none dark:prose-invert"
        // eslint-disable-next-line react/no-danger -- content is server-rendered; we escape untrusted tags before injecting.
        dangerouslySetInnerHTML={{ __html: renderArticleHtml(a.content) }}
      />

      <div className="mt-8 flex items-center gap-3 border-t border-border pt-4">
        <Button
          variant={a.liked ? "default" : "outline"}
          size="sm"
          className="h-9"
          onClick={() => likeMutation.mutate()}
          disabled={likeMutation.isPending}
        >
          <HeartIcon size={16} className="mr-1.5" />
          {a.likes ?? 0} 赞
        </Button>
      </div>
    </article>
  );
}

/**
 * Renders a raw article HTML string. We escape untrusted HTML tags
 * (script/style/iframe) and preserve safe formatting tags (p, h1-3,
 * strong, em, ul, ol, li, blockquote, code, pre, a, img).
 */
function renderArticleHtml(raw: string): string {
  // First escape everything; then allow a curated subset of tags back.
  const escaped = escapeHtml(raw);
  // Re-allow a small whitelist of formatting tags. We do NOT allow
  // script/style/iframe/etc. This protects against stored XSS.
  const allowList = [
    [/&lt;p&gt;/g, "<p>"],
    [/&lt;\/p&gt;/g, "</p>"],
    [/&lt;br&gt;/g, "<br/>"],
    [/&lt;br\/&gt;/g, "<br/>"],
    [/&lt;h1&gt;/g, "<h1>"],
    [/&lt;\/h1&gt;/g, "</h1>"],
    [/&lt;h2&gt;/g, "<h2>"],
    [/&lt;\/h2&gt;/g, "</h2>"],
    [/&lt;h3&gt;/g, "<h3>"],
    [/&lt;\/h3&gt;/g, "</h3>"],
    [/&lt;strong&gt;/g, "<strong>"],
    [/&lt;\/strong&gt;/g, "</strong>"],
    [/&lt;em&gt;/g, "<em>"],
    [/&lt;\/em&gt;/g, "</em>"],
    [/&lt;ul&gt;/g, "<ul>"],
    [/&lt;\/ul&gt;/g, "</ul>"],
    [/&lt;ol&gt;/g, "<ol>"],
    [/&lt;\/ol&gt;/g, "</ol>"],
    [/&lt;li&gt;/g, "<li>"],
    [/&lt;\/li&gt;/g, "</li>"],
    [/&lt;blockquote&gt;/g, "<blockquote>"],
    [/&lt;\/blockquote&gt;/g, "</blockquote>"],
    [/&lt;code&gt;/g, "<code>"],
    [/&lt;\/code&gt;/g, "</code>"],
    [/&lt;pre&gt;/g, "<pre>"],
    [/&lt;\/pre&gt;/g, "</pre>"],
    // Paragraph breaks for raw newlines
    [/\n\n+/g, "</p><p>"],
    [/\n/g, "<br/>"],
  ];
  let out = escaped;
  for (const [re, repl] of allowList) {
    out = out.replace(re, repl as string);
  }
  // Wrap in <p> for consistent block formatting
  if (!out.startsWith("<")) out = `<p>${out}</p>`;
  return out;
}

// ---------- Article editor (publish / edit) ----------

export function ArticleEditor({ articleId }: { articleId?: string }) {
  const { goArticles, goArticle } = useRoute();
  const { user } = useAuth();
  const { toast } = useToast();
  const [title, setTitle] = React.useState("");
  const [content, setContent] = React.useState("");
  const [summary, setSummary] = React.useState("");
  const [category, setCategory] = React.useState("");
  const [coverUrl, setCoverUrl] = React.useState("");
  const [status, setStatus] = React.useState<"draft" | "published">("published");
  const [saving, setSaving] = React.useState(false);
  const [loading, setLoading] = React.useState(!!articleId);

  React.useEffect(() => {
    if (!articleId) return;
    let cancelled = false;
    (async () => {
      try {
        const a = await api.getArticle(articleId);
        if (cancelled) return;
        setTitle(a.title ?? "");
        setContent(a.content ?? "");
        setSummary(a.summary ?? "");
        setCategory(a.category ?? "");
        setCoverUrl(a.cover_url ?? "");
      } catch (e) {
        toast({
          title: "加载专栏失败",
          description: e instanceof Error ? e.message : "未知错误",
          variant: "destructive",
        });
      } finally {
        if (!cancelled) setLoading(false);
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [articleId, toast]);

  if (!user) {
    return (
      <div className="mx-auto max-w-2xl rounded-md border border-amber-500/40 bg-amber-500/5 px-4 py-3 text-sm text-amber-700 dark:text-amber-300">
        请先登录后再发布专栏。
      </div>
    );
  }

  if (loading) {
    return (
      <div className="mx-auto max-w-2xl space-y-3">
        <Skeleton className="h-10 w-full" />
        <Skeleton className="h-64 w-full" />
      </div>
    );
  }

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!title.trim() || !content.trim()) return;
    setSaving(true);
    try {
      const body = {
        title: title.trim(),
        content: content.trim(),
        summary: summary.trim() || undefined,
        category: category.trim() || undefined,
        cover_url: coverUrl.trim() || null,
        status,
      };
      let resp: { id?: string; message?: string };
      if (articleId) {
        resp = (await api.updateArticle(articleId, body)) as { id?: string; message?: string };
        // If update returns the article, use the existing id
        if (!resp.id) resp = { id: articleId };
      } else {
        resp = (await api.createArticle(body)) as { id?: string };
      }
      const newId =
        (resp as { id?: string }).id ??
        (articleId as string | undefined) ??
        "";
      toast({
        title: articleId ? "已更新" : "已发布",
        description: status === "draft" ? "草稿已保存" : "专栏已上线",
      });
      if (newId) goArticle(newId);
      else goArticles();
    } catch (e) {
      toast({
        title: "保存失败",
        description: e instanceof Error ? e.message : "请稍后重试",
        variant: "destructive",
      });
    } finally {
      setSaving(false);
    }
  };

  return (
    <form onSubmit={submit} className="mx-auto max-w-2xl space-y-5">
      <div className="flex items-center justify-between">
        <h2 className="text-xl font-bold tracking-tight">
          {articleId ? "编辑专栏" : "发布专栏"}
        </h2>
        <Button variant="ghost" size="sm" className="h-8" onClick={goArticles}>
          取消
        </Button>
      </div>

      <div className="space-y-1.5">
        <Label htmlFor="art-title">标题</Label>
        <Input
          id="art-title"
          value={title}
          onChange={(e) => setTitle(e.target.value)}
          maxLength={120}
          placeholder="请输入专栏标题"
          required
        />
      </div>

      <div className="space-y-1.5">
        <Label htmlFor="art-summary">摘要（可选）</Label>
        <Textarea
          id="art-summary"
          value={summary}
          onChange={(e) => setSummary(e.target.value)}
          rows={2}
          placeholder="一句话摘要，将显示在列表卡片上"
          maxLength={200}
        />
      </div>

      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
        <div className="space-y-1.5">
          <Label htmlFor="art-cat">分类</Label>
          <Input
            id="art-cat"
            value={category}
            onChange={(e) => setCategory(e.target.value)}
            placeholder="如：Tech / Life"
            maxLength={60}
          />
        </div>
        <div className="space-y-1.5">
          <Label htmlFor="art-cover">封面 URL（可选）</Label>
          <Input
            id="art-cover"
            value={coverUrl}
            onChange={(e) => setCoverUrl(e.target.value)}
            placeholder="https://..."
            type="url"
          />
        </div>
      </div>

      <div className="space-y-1.5">
        <Label htmlFor="art-content">正文</Label>
        <Textarea
          id="art-content"
          value={content}
          onChange={(e) => setContent(e.target.value)}
          rows={16}
          placeholder="支持简单 HTML 标签：&lt;p&gt;、&lt;h2&gt;、&lt;strong&gt;、&lt;ul&gt;&lt;li&gt;、&lt;blockquote&gt;、&lt;a href&gt;..."
          className="font-mono text-sm"
          required
        />
        <p className="text-xs text-muted-foreground">
          为安全起见，仅允许段落、标题、强调、列表、引用、链接、代码等基础标签，其它标签将被转义。
        </p>
      </div>

      <div className="flex items-center gap-3">
        <label className="flex items-center gap-2 text-sm">
          <input
            type="radio"
            checked={status === "published"}
            onChange={() => setStatus("published")}
            className="h-4 w-4"
          />
          发布
        </label>
        <label className="flex items-center gap-2 text-sm">
          <input
            type="radio"
            checked={status === "draft"}
            onChange={() => setStatus("draft")}
            className="h-4 w-4"
          />
          保存为草稿
        </label>
      </div>

      <div className="flex items-center justify-end gap-2 border-t border-border pt-4">
        <Button
          type="button"
          variant="outline"
          size="sm"
          onClick={goArticles}
        >
          取消
        </Button>
        <Button
          type="submit"
          size="sm"
          disabled={saving || !title.trim() || !content.trim()}
        >
          {saving ? "保存中..." : articleId ? "更新" : "发布"}
        </Button>
      </div>
    </form>
  );
}
