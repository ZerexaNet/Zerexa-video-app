"use client";

/**
 * Login / Register dialog.
 *
 * A single component that switches between two modes based on the
 * `mode` prop. On success the dialog closes and the parent refreshes
 * the auth state.
 */

import * as React from "react";
import { useState } from "react";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
  DialogFooter,
} from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Tabs, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { useAuth } from "@/lib/auth";
import {
  MailIcon,
  LockIcon,
  UserIcon,
  RefreshIcon,
} from "@/components/icons";

interface AuthDialogProps {
  open: boolean;
  onOpenChange: (o: boolean) => void;
  mode: "login" | "register";
  onModeChange: (m: "login" | "register") => void;
}

export function AuthDialog({
  open,
  onOpenChange,
  mode,
  onModeChange,
}: AuthDialogProps) {
  const { login, register, loading, error } = useAuth();
  const [identifier, setIdentifier] = useState("");
  const [username, setUsername] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [confirm, setConfirm] = useState("");
  const [localError, setLocalError] = useState<string | null>(null);

  // React 19 "storing information from previous renders" pattern:
  // clear the local error whenever the dialog is re-opened or the
  // mode changes (login <-> register).
  // See: https://react.dev/reference/react/useState#storing-information-from-previous-renders
  const triggerKey = `${mode}:${open}`;
  const [prevTrigger, setPrevTrigger] = useState(triggerKey);
  if (triggerKey !== prevTrigger) {
    setPrevTrigger(triggerKey);
    if (localError !== null) setLocalError(null);
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLocalError(null);

    if (mode === "register") {
      if (!username.trim() || !email.trim() || !password) {
        setLocalError("请填写所有必填字段");
        return;
      }
      if (password.length < 8) {
        setLocalError("密码长度至少 8 位");
        return;
      }
      if (password !== confirm) {
        setLocalError("两次输入的密码不一致");
        return;
      }
      const ok = await register(username.trim(), email.trim(), password);
      if (ok) {
        onOpenChange(false);
        resetForm();
      }
    } else {
      if (!identifier.trim() || !password) {
        setLocalError("请填写账号与密码");
        return;
      }
      const ok = await login(identifier.trim(), password);
      if (ok) {
        onOpenChange(false);
        resetForm();
      }
    }
  };

  const resetForm = () => {
    setIdentifier("");
    setUsername("");
    setEmail("");
    setPassword("");
    setConfirm("");
    setLocalError(null);
  };

  const shownError = localError ?? error;

  return (
    <Dialog
      open={open}
      onOpenChange={(o) => {
        if (!o) resetForm();
        onOpenChange(o);
      }}
    >
      <DialogContent className="max-w-md">
        <DialogHeader>
          <DialogTitle className="text-2xl">
            {mode === "login" ? "欢迎回来" : "创建账户"}
          </DialogTitle>
          <DialogDescription>
            {mode === "login"
              ? "使用账号、邮箱或 UID 登录 Zerexa Video，享受弹幕、点赞、投币与收藏。"
              : "注册账户后即刻获得上传、评论、弹幕、收藏等完整功能。"}
          </DialogDescription>
        </DialogHeader>

        <Tabs
          value={mode}
          onValueChange={(v) => onModeChange(v as "login" | "register")}
          className="w-full"
        >
          <TabsList className="grid w-full grid-cols-2">
            <TabsTrigger value="login">登录</TabsTrigger>
            <TabsTrigger value="register">注册</TabsTrigger>
          </TabsList>
        </Tabs>

        <form onSubmit={handleSubmit} className="space-y-3">
          {mode === "register" && (
            <div className="space-y-1.5">
              <Label htmlFor="auth-username">用户名</Label>
              <div className="relative">
                <UserIcon
                  size={18}
                  className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-muted-foreground"
                />
                <Input
                  id="auth-username"
                  value={username}
                  onChange={(e) => setUsername(e.target.value)}
                  placeholder="3-20 位字符"
                  className="h-10 pl-10"
                  autoComplete="username"
                  minLength={3}
                  maxLength={20}
                  required
                />
              </div>
            </div>
          )}

          {mode === "register" && (
            <div className="space-y-1.5">
              <Label htmlFor="auth-email">邮箱</Label>
              <div className="relative">
                <MailIcon
                  size={18}
                  className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-muted-foreground"
                />
                <Input
                  id="auth-email"
                  type="email"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  placeholder="you@example.com"
                  className="h-10 pl-10"
                  autoComplete="email"
                  required
                />
              </div>
            </div>
          )}

          {mode === "login" && (
            <div className="space-y-1.5">
              <Label htmlFor="auth-identifier">账号</Label>
              <div className="relative">
                <UserIcon
                  size={18}
                  className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-muted-foreground"
                />
                <Input
                  id="auth-identifier"
                  value={identifier}
                  onChange={(e) => setIdentifier(e.target.value)}
                  placeholder="用户名 / 邮箱 / UID"
                  className="h-10 pl-10"
                  autoComplete="username"
                  required
                />
              </div>
            </div>
          )}

          <div className="space-y-1.5">
            <Label htmlFor="auth-password">密码</Label>
            <div className="relative">
              <LockIcon
                size={18}
                className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-muted-foreground"
              />
              <Input
                id="auth-password"
                type="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                placeholder={mode === "register" ? "至少 8 位" : "请输入密码"}
                className="h-10 pl-10"
                autoComplete={
                  mode === "register" ? "new-password" : "current-password"
                }
                minLength={mode === "register" ? 8 : 1}
                required
              />
            </div>
          </div>

          {mode === "register" && (
            <div className="space-y-1.5">
              <Label htmlFor="auth-confirm">确认密码</Label>
              <div className="relative">
                <LockIcon
                  size={18}
                  className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-muted-foreground"
                />
                <Input
                  id="auth-confirm"
                  type="password"
                  value={confirm}
                  onChange={(e) => setConfirm(e.target.value)}
                  placeholder="再次输入密码"
                  className="h-10 pl-10"
                  autoComplete="new-password"
                  required
                />
              </div>
            </div>
          )}

          {shownError && (
            <p className="rounded-md bg-destructive/10 px-3 py-2 text-sm text-destructive">
              {shownError}
            </p>
          )}

          <DialogFooter>
            <Button
              type="submit"
              className="w-full"
              disabled={loading}
            >
              {loading ? (
                <span className="flex items-center gap-2">
                  <RefreshIcon size={16} className="animate-spin" />
                  处理中...
                </span>
              ) : mode === "login" ? (
                "登录"
              ) : (
                "创建账户"
              )}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
