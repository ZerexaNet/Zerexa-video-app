"use client";

/**
 * Report user dialog.
 *
 * A complete form that submits to POST /api/reports with:
 *   target_uid, target_type, target_id?, reason, description?, category?
 *
 * Used by profile / comment / dynamic / video surfaces to launch a
 * modal with the right pre-filled target.
 */

import * as React from "react";
import { useMutation } from "@tanstack/react-query";
import { api, type ReportUserInput } from "@/lib/api";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Label } from "@/components/ui/label";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
  DialogFooter,
} from "@/components/ui/dialog";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { FlagIcon, CheckIcon } from "@/components/icons";
import { useAuth } from "@/lib/auth";
import { useToast } from "@/hooks/use-toast";
import { cn } from "@/lib/utils";

interface ReportUserDialogProps {
  open: boolean;
  onOpenChange: (v: boolean) => void;
  /** UID of the user being reported */
  targetUid: number;
  /** Display name shown in the dialog header */
  targetName: string;
  /** Optional type/id of a specific resource (comment/dynamic/video/article) being reported */
  targetType?: ReportUserInput["target_type"];
  targetId?: string;
  /** Optional pre-filled category */
  defaultCategory?: string;
}

const CATEGORIES = [
  { id: "spam", label: "垃圾广告 / 引流" },
  { id: "abuse", label: "辱骂 / 人身攻击" },
  { id: "nsfw", label: "色情 / 低俗" },
  { id: "violence", label: "暴力 / 极端" },
  { id: "illegal", label: "违法 / 违规" },
  { id: "copyright", label: "侵犯版权" },
  { id: "false_info", label: "虚假信息" },
  { id: "other", label: "其它" },
] as const;

const REASONS_PRESET: Record<string, string> = {
  spam: "发布垃圾广告或恶意引流内容",
  abuse: "对其他用户进行辱骂或人身攻击",
  nsfw: "发布色情或低俗内容",
  violence: "宣扬暴力或极端内容",
  illegal: "包含违法或违规信息",
  copyright: "侵犯他人版权或知识产权",
  false_info: "传播虚假或误导性信息",
  other: "其它需要管理员审核的问题",
};

export function ReportUserDialog({
  open,
  onOpenChange,
  targetUid,
  targetName,
  targetType = "user",
  targetId,
  defaultCategory,
}: ReportUserDialogProps) {
  const { user } = useAuth();
  const { toast } = useToast();
  const [category, setCategory] = React.useState<string>(defaultCategory ?? "spam");
  const [reason, setReason] = React.useState("");
  const [description, setDescription] = React.useState("");

  // Sync reason when category changes (if user has not typed yet)
  React.useEffect(() => {
    if (!reason || reason === REASONS_PRESET[category] || REASONS_PRESET[reason]) {
      setReason(REASONS_PRESET[category] ?? "");
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [category]);

  // Reset state when dialog closes
  React.useEffect(() => {
    if (!open) {
      setCategory(defaultCategory ?? "spam");
      setReason("");
      setDescription("");
    }
  }, [open, defaultCategory]);

  const mutation = useMutation({
    mutationFn: (body: ReportUserInput) => api.reportUser(body),
    onSuccess: () => {
      toast({ title: "举报已提交", description: "管理员将尽快处理" });
      onOpenChange(false);
    },
    onError: (e: unknown) =>
      toast({
        title: "提交失败",
        description: e instanceof Error ? e.message : "请稍后重试",
        variant: "destructive",
      }),
  });

  const submit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!user) {
      toast({
        title: "请先登录",
        description: "举报需要登录账号",
        variant: "destructive",
      });
      return;
    }
    if (!reason.trim()) return;
    mutation.mutate({
      target_uid: targetUid,
      target_type: targetType,
      target_id: targetId,
      reason: reason.trim(),
      description: description.trim() || undefined,
      category,
    });
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-lg">
        <DialogHeader>
          <DialogTitle className="flex items-center gap-2">
            <FlagIcon size={18} />
            举报 {targetName}
          </DialogTitle>
          <DialogDescription>
            请选择举报分类并填写理由。管理员将根据社区规则处理。
          </DialogDescription>
        </DialogHeader>

        <form onSubmit={submit} className="space-y-4">
          <div className="space-y-1.5">
            <Label htmlFor="r-cat">分类</Label>
            <Select value={category} onValueChange={setCategory}>
              <SelectTrigger id="r-cat">
                <SelectValue placeholder="选择分类" />
              </SelectTrigger>
              <SelectContent>
                {CATEGORIES.map((c) => (
                  <SelectItem key={c.id} value={c.id}>
                    {c.label}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>

          <div className="space-y-1.5">
            <Label htmlFor="r-reason">举报理由</Label>
            <Input
              id="r-reason"
              value={reason}
              onChange={(e) => setReason(e.target.value)}
              maxLength={200}
              placeholder="一句话描述违规行为"
              required
            />
          </div>

          <div className="space-y-1.5">
            <Label htmlFor="r-desc">详细说明（可选）</Label>
            <Textarea
              id="r-desc"
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              rows={4}
              maxLength={1000}
              placeholder="提供上下文、时间、链接或截图链接"
            />
          </div>

          {/* Meta summary */}
          <div className="rounded-md border border-border bg-muted/30 px-3 py-2 text-xs text-muted-foreground">
            <p>
              目标类型：<strong className="text-foreground">{targetType}</strong>
            </p>
            <p>
              目标 UID：<strong className="text-foreground">{targetUid}</strong>
            </p>
            {targetId && (
              <p>
                目标 ID：<strong className="text-foreground">{targetId.slice(0, 12)}</strong>
              </p>
            )}
          </div>

          <DialogFooter>
            <Button
              type="button"
              variant="outline"
              size="sm"
              onClick={() => onOpenChange(false)}
            >
              取消
            </Button>
            <Button
              type="submit"
              size="sm"
              disabled={mutation.isPending || !reason.trim()}
            >
              {mutation.isPending ? "提交中..." : (
                <>
                  <CheckIcon size={14} className="mr-1" />
                  提交举报
                </>
              )}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}

/**
 * Convenience hook that wires the dialog state. Returns the dialog
 * element and a `open(target)` function.
 *
 * Usage:
 *   const { dialog, openReport } = useReportUser();
 *   return (
 *     <>
 *       <Button onClick={() => openReport({ uid: 123, name: "alice" })}>举报</Button>
 *       {dialog}
 *     </>
 *   );
 */
export function useReportUser() {
  const [open, setOpen] = React.useState(false);
  const [target, setTarget] = React.useState<{
    uid: number;
    name: string;
    type?: ReportUserInput["target_type"];
    id?: string;
  } | null>(null);

  const openReport = (t: {
    uid: number;
    name: string;
    type?: ReportUserInput["target_type"];
    id?: string;
  }) => {
    setTarget(t);
    setOpen(true);
  };

  const dialog = target ? (
    <ReportUserDialog
      open={open}
      onOpenChange={setOpen}
      targetUid={target.uid}
      targetName={target.name}
      targetType={target.type}
      targetId={target.id}
    />
  ) : null;

  return { dialog, openReport };
}
