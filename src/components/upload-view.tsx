"use client";

/**
 * Upload view.
 *
 * Flow:
 *  1. POST /api/uploads/init  -> { upload_id, chunk_size, total_chunks,
 *     upload_url?, chunk_urls?, headers? }
 *  2. If `upload_url` is present (single-shot presigned URL), PUT the
 *     whole file directly to S3.
 *     Otherwise (or in addition to), if `chunk_urls` is present, PUT
 *     each chunk to its presigned URL. Otherwise fall back to chunked
 *     POST /api/uploads/{upload_id}/chunks which the proxy will route
 *     through the upstream API.
 *  3. POST /api/uploads/complete with ETags (if applicable) and final
 *     metadata (title, description, category) to finalize the video.
 *
 * Progress is shown per-chunk and overall.
 */

import * as React from "react";
import { api } from "@/lib/api";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Label } from "@/components/ui/label";
import { Progress } from "@/components/ui/progress";
import { UploadIcon, CheckIcon, XCircleIcon } from "@/components/icons";
import { useAuth } from "@/lib/auth";
import { useToast } from "@/hooks/use-toast";
import { useRoute } from "@/lib/route";
import { cn } from "@/lib/utils";

const DEFAULT_CHUNK_SIZE = 4 * 1024 * 1024; // 4 MB

type Stage = "idle" | "init" | "uploading" | "completing" | "done" | "error";

export function UploadView() {
  const { user } = useAuth();
  const { goHome } = useRoute();
  const { toast } = useToast();
  const [file, setFile] = React.useState<File | null>(null);
  const [title, setTitle] = React.useState("");
  const [description, setDescription] = React.useState("");
  const [category, setCategory] = React.useState("General");
  const [stage, setStage] = React.useState<Stage>("idle");
  const [progress, setProgress] = React.useState(0); // 0-100
  const [statusMessage, setStatusMessage] = React.useState("");
  const [resultUrl, setResultUrl] = React.useState<string | null>(null);

  if (!user) {
    return (
      <div className="mx-auto max-w-2xl rounded-md border border-amber-500/40 bg-amber-500/5 px-4 py-3 text-sm text-amber-700 dark:text-amber-300">
        请先登录后上传视频。
      </div>
    );
  }

  const reset = () => {
    setFile(null);
    setTitle("");
    setDescription("");
    setCategory("General");
    setStage("idle");
    setProgress(0);
    setStatusMessage("");
    setResultUrl(null);
  };

  const onPickFile = (e: React.ChangeEvent<HTMLInputElement>) => {
    const f = e.target.files?.[0];
    if (!f) return;
    if (!f.type.startsWith("video/")) {
      toast({
        title: "文件类型错误",
        description: "请选择视频文件（mp4 / webm / mov 等）",
        variant: "destructive",
      });
      return;
    }
    setFile(f);
    if (!title) {
      // Auto-fill title from filename (strip extension)
      const base = f.name.replace(/\.[^.]+$/, "");
      setTitle(base.slice(0, 100));
    }
  };

  const start = async () => {
    if (!file) return;
    setStage("init");
    setProgress(0);
    setStatusMessage("正在初始化上传...");
    try {
      const init = await api.initUpload({
        filename: file.name,
        size: file.size,
        mime_type: file.type || "video/mp4",
        kind: "video",
      });

      // Direct-to-S3 single presigned URL
      if (init.upload_url && (!init.chunk_urls || init.chunk_urls.length === 0)) {
        setStage("uploading");
        setStatusMessage("正在直传到 S3...");
        await putToUrl(init.upload_url, file, init.headers, (p) =>
          setProgress(p),
        );
      } else if (init.chunk_urls && init.chunk_urls.length > 0) {
        setStage("uploading");
        setStatusMessage("正在分片直传到 S3...");
        const chunkSize = init.chunk_size || DEFAULT_CHUNK_SIZE;
        const total = init.total_chunks || init.chunk_urls.length;
        for (let i = 0; i < total; i++) {
          const start = i * chunkSize;
          const end = Math.min(start + chunkSize, file.size);
          const blob = file.slice(start, end);
          const url = init.chunk_urls[i];
          await putToUrl(url, blob, init.headers, (p) => {
            // Each chunk contributes (1/total) * 100 to overall progress
            const overall = ((i + p / 100) / total) * 100;
            setProgress(overall);
          });
        }
      } else {
        // No presigned URLs; we cannot chunk-POST through the proxy
        // easily because the upstream API path is not standardised.
        // We'll do one final fallback: PUT the entire file through the
        // proxy at /api/uploads/{upload_id} (some servers accept this).
        setStage("uploading");
        setStatusMessage("正在通过代理上传...");
        const url = `${api.resolveAsset("/api/uploads/" + init.upload_id)}`;
        await putToUrl(url, file, { Authorization: `Bearer ${getTokenForProxy()}` }, (p) =>
          setProgress(p),
        );
      }

      // Complete
      setStage("completing");
      setProgress(100);
      setStatusMessage("正在合并分片并创建视频记录...");
      const resp = await api.completeUpload({
        upload_id: init.upload_id,
        title: title.trim(),
        description: description.trim() || undefined,
        category: category.trim() || undefined,
      });
      setStage("done");
      setStatusMessage("上传完成。");
      if (resp && typeof resp === "object" && "video_id" in resp) {
        const vid = (resp as { video_id?: string }).video_id;
        if (vid) {
          setResultUrl(`?v=${vid}`);
        }
      }
      toast({ title: "上传成功", description: "视频已提交处理" });
    } catch (err) {
      setStage("error");
      setStatusMessage(
        err instanceof Error ? err.message : "上传失败，请重试",
      );
      toast({
        title: "上传失败",
        description: err instanceof Error ? err.message : "请稍后重试",
        variant: "destructive",
      });
    }
  };

  return (
    <div className="mx-auto max-w-2xl space-y-6">
      <div className="border-b border-border pb-4">
        <h2 className="flex items-center gap-2 text-xl font-bold tracking-tight">
          <UploadIcon size={22} />
          上传视频
        </h2>
        <p className="mt-1 text-sm text-muted-foreground">
          支持分片上传与预签名 URL 直传。大文件将被切分为 4-8 MB 的分片依次上传。
        </p>
      </div>

      {/* File picker */}
      <div className="space-y-2">
        <Label htmlFor="file">视频文件</Label>
        <label
          htmlFor="file"
          className={cn(
            "flex h-32 cursor-pointer flex-col items-center justify-center rounded-lg border border-dashed border-border bg-card text-center text-sm text-muted-foreground transition-colors hover:border-primary hover:bg-accent/40",
            file && "border-solid",
          )}
        >
          {file ? (
            <>
              <UploadIcon size={32} className="mb-2" />
              <p className="font-medium text-foreground">{file.name}</p>
              <p className="mt-1 text-xs">
                {(file.size / 1024 / 1024).toFixed(2)} MB · {file.type || "未知类型"}
              </p>
            </>
          ) : (
            <>
              <UploadIcon size={32} className="mb-2" />
              <p>点击选择视频文件</p>
              <p className="mt-1 text-xs">支持 mp4 / webm / mov / mkv 等格式</p>
            </>
          )}
          <input
            id="file"
            type="file"
            accept="video/*"
            className="hidden"
            onChange={onPickFile}
            disabled={stage === "init" || stage === "uploading" || stage === "completing"}
          />
        </label>
      </div>

      {/* Metadata */}
      <div className="space-y-3">
        <div className="space-y-1.5">
          <Label htmlFor="up-title">标题</Label>
          <Input
            id="up-title"
            value={title}
            onChange={(e) => setTitle(e.target.value)}
            maxLength={120}
            placeholder="视频标题"
            disabled={stage === "init" || stage === "uploading" || stage === "completing"}
          />
        </div>
        <div className="space-y-1.5">
          <Label htmlFor="up-desc">简介</Label>
          <Textarea
            id="up-desc"
            value={description}
            onChange={(e) => setDescription(e.target.value)}
            rows={4}
            placeholder="视频简介（可选）"
            maxLength={2000}
            disabled={stage === "init" || stage === "uploading" || stage === "completing"}
          />
        </div>
        <div className="space-y-1.5">
          <Label htmlFor="up-cat">分类</Label>
          <Input
            id="up-cat"
            value={category}
            onChange={(e) => setCategory(e.target.value)}
            maxLength={60}
            placeholder="如：Tech / Programming"
            disabled={stage === "init" || stage === "uploading" || stage === "completing"}
          />
        </div>
      </div>

      {/* Progress */}
      {(stage === "init" ||
        stage === "uploading" ||
        stage === "completing" ||
        stage === "done" ||
        stage === "error") && (
        <div className="space-y-2">
          <div className="flex items-center justify-between text-xs">
            <span
              className={cn(
                "font-medium",
                stage === "error" ? "text-red-600 dark:text-red-300" : "text-foreground",
              )}
            >
              {statusMessage}
            </span>
            <span className="tabular-nums text-muted-foreground">
              {progress.toFixed(0)}%
            </span>
          </div>
          <Progress value={progress} className="h-2" />
          {stage === "error" && (
            <Button
              variant="outline"
              size="sm"
              className="h-8"
              onClick={() => setStage("idle")}
            >
              重试
            </Button>
          )}
          {stage === "done" && (
            <div className="flex items-center gap-2 rounded-md border border-emerald-500/30 bg-emerald-500/5 px-3 py-2 text-sm text-emerald-700 dark:text-emerald-300">
              <CheckIcon size={16} />
              上传成功，视频已提交处理。
              {resultUrl && (
                <Button
                  variant="link"
                  size="sm"
                  className="h-auto p-0 text-emerald-700 dark:text-emerald-300"
                  onClick={() => {
                    if (typeof window !== "undefined") {
                      window.location.href = resultUrl;
                    }
                  }}
                >
                  查看视频
                </Button>
              )}
            </div>
          )}
        </div>
      )}

      {/* Action bar */}
      <div className="flex items-center justify-end gap-2 border-t border-border pt-4">
        {stage === "done" ? (
          <>
            <Button variant="outline" size="sm" className="h-9" onClick={reset}>
              再上传一个
            </Button>
            <Button size="sm" className="h-9" onClick={goHome}>
              返回首页
            </Button>
          </>
        ) : (
          <>
            <Button
              variant="outline"
              size="sm"
              className="h-9"
              onClick={reset}
              disabled={
                stage === "init" ||
                stage === "uploading" ||
                stage === "completing"
              }
            >
              重置
            </Button>
            <Button
              size="sm"
              className="h-9"
              onClick={start}
              disabled={
                !file ||
                !title.trim() ||
                stage === "init" ||
                stage === "uploading" ||
                stage === "completing"
              }
            >
              {stage === "init" || stage === "uploading" || stage === "completing"
                ? "上传中..."
                : "开始上传"}
            </Button>
          </>
        )}
      </div>

      <p className="text-xs text-muted-foreground">
        <XCircleIcon size={12} className="mr-1 inline-block" />
        上传过程中请保持页面打开。如果上传中断，未完成的资源将在 24 小时后自动清理。
      </p>
    </div>
  );
}

/** PUT a Blob to a presigned URL with progress. */
async function putToUrl(
  url: string,
  blob: Blob,
  headers: Record<string, string> | undefined,
  onProgress: (pct: number) => void,
): Promise<void> {
  return new Promise((resolve, reject) => {
    const xhr = new XMLHttpRequest();
    xhr.open("PUT", url);
    if (headers) {
      for (const [k, v] of Object.entries(headers)) {
        // Skip Authorization header for cross-origin requests — the
        // presigned URL already carries the signature.
        if (k.toLowerCase() === "authorization" && !url.startsWith("/")) {
          continue;
        }
        xhr.setRequestHeader(k, v);
      }
    }
    xhr.upload.onprogress = (e) => {
      if (e.lengthComputable) {
        onProgress((e.loaded / e.total) * 100);
      }
    };
    xhr.onload = () => {
      if (xhr.status >= 200 && xhr.status < 300) resolve();
      else {
        reject(
          new Error(
            `HTTP ${xhr.status} ${xhr.statusText}${
              xhr.responseText ? ` - ${xhr.responseText.slice(0, 200)}` : ""
            }`,
          ),
        );
      }
    };
    xhr.onerror = () => reject(new Error("Network error"));
    xhr.send(blob);
  });
}

function getTokenForProxy(): string {
  if (typeof window === "undefined") return "";
  return localStorage.getItem("zv_token") ?? "";
}
