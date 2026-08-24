"use client";

/**
 * Shared admin UI helpers.
 *
 * Small presentational components reused across the admin
 * sections: stat cards, empty states, status badges, loading
 * skeletons, and section header.
 */

import * as React from "react";
import { cn } from "@/lib/utils";

export function AdminSectionHeader({
  title,
  description,
  actions,
}: {
  title: string;
  description?: string;
  actions?: React.ReactNode;
}) {
  return (
    <div className="mb-5 flex flex-wrap items-end justify-between gap-3 border-b border-border pb-4">
      <div>
        <h2 className="text-xl font-bold tracking-tight">{title}</h2>
        {description && (
          <p className="mt-1 text-sm text-muted-foreground">{description}</p>
        )}
      </div>
      {actions && <div className="flex items-center gap-2">{actions}</div>}
    </div>
  );
}

export function StatCard({
  label,
  value,
  hint,
  icon,
  tone = "default",
}: {
  label: string;
  value: React.ReactNode;
  hint?: string;
  icon?: React.ReactNode;
  tone?: "default" | "primary" | "warning" | "danger" | "success";
}) {
  const toneCls = {
    default: "bg-card text-foreground",
    primary: "bg-primary/10 text-primary",
    warning: "bg-amber-500/10 text-amber-700 dark:text-amber-300",
    danger: "bg-red-500/10 text-red-700 dark:text-red-300",
    success: "bg-emerald-500/10 text-emerald-700 dark:text-emerald-300",
  }[tone];

  return (
    <div className="rounded-md border border-border bg-card p-4 shadow-sm">
      <div className="flex items-start justify-between gap-2">
        <p className="text-xs font-medium uppercase tracking-wider text-muted-foreground">
          {label}
        </p>
        {icon && (
          <div
            className={cn(
              "flex h-7 w-7 items-center justify-center rounded-md",
              toneCls,
            )}
          >
            {icon}
          </div>
        )}
      </div>
      <p className="mt-2 text-2xl font-bold tabular-nums">{value}</p>
      {hint && <p className="mt-1 text-xs text-muted-foreground">{hint}</p>}
    </div>
  );
}

export function StatusBadge({ status }: { status?: string | null }) {
  if (!status) return <span className="text-xs text-muted-foreground">未知</span>;
  const s = status.toLowerCase();
  let cls = "bg-muted text-foreground/70";
  let label = status;
  if (
    s === "pending" ||
    s === "open" ||
    s === "waiting" ||
    s === "unreviewed"
  ) {
    cls = "bg-amber-500/10 text-amber-700 dark:text-amber-300";
    label = "待处理";
  } else if (
    s === "approved" ||
    s === "resolved" ||
    s === "active" ||
    s === "ok"
  ) {
    cls = "bg-emerald-500/10 text-emerald-700 dark:text-emerald-300";
    label = status === "approved" ? "已通过" : status === "active" ? "已上线" : "已处理";
  } else if (s === "rejected" || s === "closed" || s === "banned") {
    cls = "bg-red-500/10 text-red-700 dark:text-red-300";
    label = status === "rejected" ? "已拒绝" : status === "banned" ? "已封禁" : "已关闭";
  } else if (s === "admin" || s === "moderator") {
    cls = "bg-blue-500/10 text-blue-700 dark:text-blue-300";
    label = status;
  }
  return (
    <span
      className={cn(
        "inline-flex items-center rounded px-1.5 py-0.5 text-[10px] font-semibold uppercase tracking-wider",
        cls,
      )}
    >
      {label}
    </span>
  );
}

export function EmptyState({
  title,
  description,
  icon,
  action,
}: {
  title: string;
  description?: string;
  icon?: React.ReactNode;
  action?: React.ReactNode;
}) {
  return (
    <div className="flex flex-col items-center justify-center rounded-md border border-dashed border-border bg-card/50 px-6 py-12 text-center">
      {icon && <div className="mb-3 text-muted-foreground">{icon}</div>}
      <p className="text-sm font-medium">{title}</p>
      {description && (
        <p className="mt-1 max-w-md text-xs text-muted-foreground">
          {description}
        </p>
      )}
      {action && <div className="mt-4">{action}</div>}
    </div>
  );
}

export function ErrorBanner({ message }: { message: string }) {
  return (
    <div className="mb-4 rounded-md border border-red-500/30 bg-red-500/5 px-4 py-3 text-sm text-red-700 dark:text-red-300">
      {message}
    </div>
  );
}

export function AdminTable({
  head,
  children,
}: {
  head: React.ReactNode;
  children: React.ReactNode;
}) {
  return (
    <div className="overflow-x-auto rounded-md border border-border">
      <table className="w-full text-sm">
        <thead className="bg-muted/50 text-xs uppercase tracking-wider text-muted-foreground">
          {head}
        </thead>
        <tbody className="divide-y divide-border">{children}</tbody>
      </table>
    </div>
  );
}

export function Th({
  children,
  className,
}: {
  children?: React.ReactNode;
  className?: string;
}) {
  return (
    <th className={cn("px-3 py-2 text-left font-medium", className)}>
      {children}
    </th>
  );
}

export function Td({
  children,
  className,
}: {
  children?: React.ReactNode;
  className?: string;
}) {
  return (
    <td className={cn("px-3 py-2 align-middle", className)}>{children}</td>
  );
}

/**
 * Normalises the various list/paginated shapes returned by the
 * admin endpoints into a flat array. The upstream sometimes returns
 * a bare array, sometimes a `{ items, total, ... }` envelope.
 */
export function asArray<T>(data: unknown): T[] {
  if (Array.isArray(data)) return data as T[];
  if (data && typeof data === "object" && "items" in data) {
    const items = (data as { items: unknown }).items;
    if (Array.isArray(items)) return items as T[];
  }
  return [];
}
