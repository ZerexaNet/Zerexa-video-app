"use client";

/**
 * Site footer. Sticks to the bottom of the viewport on short pages
 * and is pushed down naturally on long pages.
 */

import { Logo } from "@/components/icons";
import { useRoute } from "@/lib/route";

export function AppFooter() {
  const { goHome } = useRoute();
  return (
    <footer className="mt-auto border-t border-border bg-background">
      <div className="mx-auto grid gap-8 px-6 py-10 md:grid-cols-4">
        <div className="space-y-3">
          <button
            onClick={goHome}
            className="flex items-center gap-2"
          >
            <Logo size={28} />
            <span className="text-lg font-bold">Zerexa Video</span>
          </button>
          <p className="text-sm text-muted-foreground">
            一个开源的视频、专栏与动态社区，提供弹幕互动、点赞投币收藏、合集与公投等功能。
          </p>
        </div>

        <div className="space-y-3">
          <h3 className="text-sm font-semibold">关于</h3>
          <ul className="space-y-1.5 text-sm text-muted-foreground">
            <li>用户协议</li>
            <li>隐私政策</li>
            <li>帮助中心</li>
          </ul>
        </div>

        <div className="space-y-3">
          <h3 className="text-sm font-semibold">资源</h3>
          <ul className="space-y-1.5 text-sm text-muted-foreground">
            <li>API 文档</li>
            <li>开源仓库</li>
            <li>友情链接</li>
          </ul>
        </div>

        <div className="space-y-3">
          <h3 className="text-sm font-semibold">联系方式</h3>
          <ul className="space-y-1.5 text-sm text-muted-foreground">
            <li>support@zerexa.net</li>
            <li>tg@zerexavideo</li>
          </ul>
        </div>
      </div>
      <div className="border-t border-border">
        <div className="mx-auto flex flex-col items-center justify-between gap-2 px-6 py-4 text-xs text-muted-foreground sm:flex-row">
          <p>(c) 2026 Zerexa Video · 视频内容版权归原作者所有</p>
          <p>Powered by Zerexa Video API</p>
        </div>
      </div>
    </footer>
  );
}
