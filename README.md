# Zerexa Video

> 一个面向创作者与观众的视频、专栏与动态社区 Web 应用，基于 Zerexa Video 公开 API 构建。

[![Stack](https://img.shields.io/badge/stack-Next.js%2016%20%2B%20TypeScript%20%2B%20Tailwind%204-blue)]()
[![API](https://img.shields.io/badge/API-zerexa--video.apifox.cn-purple)]()

本项目是一个完整的视频网站前端应用，对接 [Zerexa Video](https://video.zerexa.net) 公开 API（[文档](https://zerexa-video.apifox.cn/)），融合 [video.zerexa.net](https://video.zerexa.net) 的产品形态、Google Material You 的视觉语言以及 Windows 8 Metro 的扁平美学，提供四种可一键切换的整体主题。

---

## 目录

- [功能特性](#功能特性)
- [多主题系统](#多主题系统)
- [技术栈](#技术栈)
- [项目结构](#项目结构)
- [开始使用](#开始使用)
- [核心模块说明](#核心模块说明)
- [API 代理](#api-代理)
- [键盘快捷键](#键盘快捷键)
- [浏览器自验证清单](#浏览器自验证清单)
- [后续路线图](#后续路线图)

---

## 功能特性

### 首页与发现

- **Hero Banner**：渐变式品牌入口，包含"推荐 / 最新 / 热门"三档排序切换。
- **公告条幅**：拉取 `/api/announcements`，6 秒自动轮播，可关闭与手动切换。
- **分类筛选**：15 个一级分类（音乐、游戏、科技、生活、娱乐、体育、美食、旅行、时尚、教育、资讯、影视、汽车、艺术、公益）。
- **视频网格**：响应式 1-5 列自适应布局，IntersectionObserver 驱动的无限滚动。
- **封面降级**：当远端封面缺失或加载失败时，自动使用按分类生成的渐变占位封面 + 标题首屏。

### 视频播放页

- **自定义播放器**：原生 `<video>` + 自绘控制条（播放/暂停、进度条、音量、快进快退、全屏）。
- **弹幕引擎**：基于 `<canvas>` 的多轨道滚动弹幕系统，支持自动避让、颜色预设、暂停时停止渲染。
- **互动操作**：点赞、投币、收藏、分享（带 Web Share API 降级到剪贴板复制）。
- **UP 主卡片**：作者头像、用户名、认证徽章、UID、IP 归属地。
- **评论系统**：分页加载、乐观更新、未登录时引导登录。
- **举报入口**：在 toast 中反馈提交结果。

### 搜索

- 关键词搜索（`/api/search`），结果复用视频卡片。
- 空查询时展示"热门搜索"快捷入口。
- URL 参数 `?q=` 同步搜索状态，结果页可分享、可收藏。

### 分类页

- 按 `/api/videos?category=` 过滤的视频列表，UI 复用首页网格与无限滚动逻辑。

### 用户中心

- 个人资料卡：头像、用户名、UID、角色、认证标签、加入时间、个人简介。
- 每日签到按钮（已签到时降级为提示）。
- Tab 切换：观看历史 / 收藏 / 关注 / 粉丝。
- 未登录时显示登录引导卡片。

### 认证

- 登录 / 注册共用一个对话框，支持 Tab 切换。
- JWT Bearer Token 持久化在 `localStorage`，所有需鉴权的请求自动附加 `Authorization` 头。
- 注册时客户端校验：必填、密码长度（≥8）、两次输入一致。
- 退出登录会同时清理本地 Token 与远端会话。

### 多主题系统

详见 [多主题系统](#多主题系统) 章节。

---

## 多主题系统

应用支持四种整体视觉风格，通过右上角"调色板"按钮一键切换。选择会持久化到 `localStorage`，刷新与重启后保留。

| 主题 ID         | 标签             | 视觉特征                                                            | 参考来源                       |
| --------------- | ---------------- | ------------------------------------------------------------------- | ------------------------------ |
| `material`      | Material You     | 大圆角（`--radius: 1.25rem`）、柔和阴影、温暖中性灰、Google 蓝主色  | Google Material 3              |
| `metro`         | Win8 Metro       | 0px 圆角、扁平色块、无阴影、纯色高饱和度强调色                     | Windows 8 / Windows Phone 8    |
| `zerexa`        | Zerexa Purple    | 中等圆角、紫色（`#9373EE`）主色、米色暖底、轻微悬浮                  | video.zerexa.net 站点默认配色   |
| `dark`          | Midnight         | 深色高对比、紫色高亮、夜间场景                                      | Dark theme fallback            |

实现要点：

1. 所有颜色变量定义在 `src/app/globals.css` 中，通过 `[data-theme="..."]` 选择器切换。
2. `src/lib/theme.ts` 使用 `zustand + persist` 持久化主题选择。
3. `src/app/layout.tsx` 在 `<head>` 内联一段引导脚本，在首屏渲染前就读取 localStorage 并设置 `<html data-theme>`，避免 FOUC（主题闪烁）。
4. Tailwind 4 的 `@theme inline` 语法让所有 `bg-background` / `text-foreground` 等原子类自动响应主题切换。
5. Metro 主题额外通过全局 `border-radius: 0 !important` 规则强制所有 shadcn 组件进入"硬边"状态。

---

## 技术栈

| 层级       | 选型                                                      | 备注                                         |
| ---------- | --------------------------------------------------------- | -------------------------------------------- |
| 框架       | Next.js 16 (App Router, Turbopack)                        | 强制要求，不可替换                           |
| 语言       | TypeScript 5                                              | 全量类型化                                   |
| 样式       | Tailwind CSS 4 + shadcn/ui (New York) + tw-animate-css    | 使用 `@theme inline` 与 CSS 变量             |
| 状态       | Zustand（客户端）+ TanStack Query v5（服务端）             | 路由与主题走 Zustand，数据请求走 Query       |
| UI 库      | Radix UI primitives + Lucide React                         | shadcn/ui 已预置                             |
| 图标       | 手绘 SVG（`src/components/icons.tsx`）                    | 全项目无任何 emoji 字符，所有图标均为 SVG   |
| 字体       | Geist Sans + Geist Mono                                   | 通过 `next/font/google` 加载                 |
| 视频       | 原生 HTML5 `<video>` + Canvas 2D（弹幕）                   | 不引入任何第三方播放器依赖                  |
| 后端代理   | Next.js Route Handler（`/api/zerexa/[...path]`）          | 解决远端 API 不开 CORS 的问题               |

---

## 项目结构

```
src/
├── app/
│   ├── api/
│   │   ├── route.ts                      # 健康检查占位
│   │   └── zerexa/[...path]/route.ts     # 远端 API 反向代理（CORS 透传）
│   ├── globals.css                       # 四主题 CSS 变量定义
│   ├── layout.tsx                        # 根布局 + 主题引导脚本
│   └── page.tsx                          # 唯一可访问路由 /
│
├── components/
│   ├── app-shell.tsx                     # 顶层壳：Header + Nav + Main + Footer
│   ├── app-header.tsx                    # 顶栏：Logo / 搜索 / 主题 / 账户
│   ├── app-nav.tsx                       # 移动端侧滑抽屉
│   ├── app-footer.tsx                    # 站脚
│   ├── theme-switcher.tsx                # 主题切换 Popover
│   ├── auth-dialog.tsx                   # 登录 / 注册共用对话框
│   ├── announcement-bar.tsx              # 公告轮播条
│   ├── home-hero.tsx                     # 首页 Hero Banner
│   ├── home-view.tsx                     # 首页主视图
│   ├── category-view.tsx                 # 分类筛选视图
│   ├── search-view.tsx                   # 搜索视图（TanStack Query）
│   ├── watch-view.tsx                    # 视频播放页视图
│   ├── profile-view.tsx                  # 个人中心视图
│   ├── video-card.tsx                    # 视频卡片（响应式）
│   ├── video-grid-skeleton.tsx           # 加载占位骨架
│   ├── video-player.tsx                  # 自定义播放器 + 控制
│   ├── danmaku-layer.tsx                 # Canvas 弹幕引擎
│   ├── comment-section.tsx               # 评论列表 + 发布
│   ├── query-provider.tsx                # TanStack Query Client Provider
│   └── icons.tsx                         # 全部 SVG 图标
│
├── lib/
│   ├── api.ts                            # API 客户端 + 类型定义
│   ├── auth.ts                           # 认证状态 store
│   ├── route.ts                          # URL 驱动的视图路由 store
│   ├── theme.ts                          # 主题 store + useTheme hook
│   ├── format.ts                         # 数字 / 时间 / 分类格式化
│   ├── db.ts                             # Prisma 客户端（备用）
│   └── utils.ts                          # cn() 工具
│
└── hooks/
    ├── use-mobile.ts                     # 移动端检测 hook
    └── use-toast.ts                      # shadcn toast 适配
```

---

## 开始使用

项目已经初始化完毕，所有依赖均已安装。本地开发命令：

```bash
# 启动开发服务器（已在沙箱环境自动运行）
bun run dev

# 代码质量检查
bun run lint

# 数据库 schema 推送（本项目暂未使用 Prisma）
bun run db:push
```

应用启动后，访问预览面板即可（沙箱环境下不可直接访问 `localhost:3000`）。如果通过 IM 平台接入，请使用提供的预览链接。

---

## 核心模块说明

### API 客户端 (`src/lib/api.ts`)

- 所有远端调用统一通过 `apiFetch()`，自动附加 `Authorization: Bearer <token>` 头。
- Token 存储在 `localStorage["zv_token"]`，登录成功后写入，登出时清除。
- `resolveAsset()` 工具将远端 `/api/s3/object?key=...` 这类同站相对路径转换为通过本地代理的可访问 URL。
- `ApiError` 自定义错误类携带 HTTP 状态码与原始 payload，便于上层展示友好提示。

### 路由 (`src/lib/route.ts`)

由于 Next.js 项目只能暴露 `/` 路由，视图切换通过 URL search params 驱动：

| 参数           | 值                | 渲染视图       |
| -------------- | ----------------- | -------------- |
| `?v=<id>`      | 视频 ID           | WatchView      |
| `?q=<keyword>` | 关键词             | SearchView     |
| `?view=profile`| 固定字符串         | ProfileView    |
| `?category=<r>`| 分类根（如 Music） | CategoryView   |
| （无参数）      | -                 | HomeView       |

`useRoute` store 在 mount 时调用 `hydrate()` 解析当前 URL，并订阅 `popstate` 事件以响应浏览器前进 / 后退。所有 `go*` 方法通过 `history.pushState` 更新 URL 后再触发组件重渲染。

### 弹幕引擎 (`src/components/danmaku-layer.tsx`)

- 单层 `<canvas>` 叠加在 `<video>` 之上，`pointer-events: none` 不阻挡交互。
- 自适应布局：通过 `ResizeObserver` 监听 video 容器尺寸变化，重算轨道数。
- 多轨道分配算法：新弹幕寻找"前一条已经移出右边界足够距离"的轨道；找不到时丢弃以保证流畅度。
- 文字渲染带黑色描边，保证在亮 / 暗视频画面下都可读。
- 通过 `forwardRef` 暴露 `add / clear / seek` 接口，让父组件能在用户发送弹幕或 seek 时介入。

### 视频播放器 (`src/components/video-player.tsx`)

- 进度条 / 音量条复用 shadcn `Slider`，所有控件均带 ARIA 标签。
- 键盘快捷键：空格 / `k` 播放暂停，方向键快进快退，`f` 全屏，`m` 静音，`d` 切换弹幕显示。
- 弹幕发送框内嵌 7 个预设颜色，发送后乐观地加入本地活动集，无需等待远端确认。
- 控制条 3 秒无操作自动隐藏（鼠标移动会重新显示）。
- 全屏 API 失败时静默处理，不抛错。

### 多主题切换 (`src/lib/theme.ts` + `src/app/globals.css`)

- 四种主题对应四组 CSS 变量，全部定义在 `globals.css` 的 `:root / [data-theme="..."]` 块中。
- `useTheme()` hook 在主题变化时同步更新 `<html data-theme>` 与 `.dark` class。
- `layout.tsx` 的内联脚本在 React hydrate 之前就设置好主题，避免任何首屏闪烁。

---

## API 代理

Zerexa Video 的远端 API（`https://video.zerexa.net`）没有启用 CORS，浏览器直接 fetch 会被拦截。本项目通过 Next.js Route Handler 实现了一个通用反向代理：

- 入口：`/api/zerexa/<...path>`
- 上游：`https://video.zerexa.net/<...path>`
- 透传：HTTP 方法、查询字符串、请求体、`Authorization` 头
- 响应：原状态码 + 原 content-type，二进制内容（图片、视频）以 `arrayBuffer` 形式原样回传
- 附加 CORS 头，让浏览器 fetch 不再被预检拦截

客户端通过 `API_BASE = "/api/zerexa"` 使用相对路径调用，例如 `/api/zerexa/api/videos?limit=24` 会被代理转发到 `https://video.zerexa.net/api/videos?limit=24`。

视频流媒体文件（`stream_url`）来自独立的对象存储 CDN（`zerexa-video-sy.cn-sy1.rains3.com`），该 CDN 已开启 CORS，因此播放器直接访问即可，无需经过代理。

---

## 键盘快捷键

在视频播放页生效：

| 按键            | 作用                  |
| --------------- | --------------------- |
| `Space` / `k`   | 播放 / 暂停           |
| `←`             | 后退 5 秒              |
| `→`             | 前进 5 秒              |
| `f`             | 切换全屏              |
| `m`             | 静音 / 取消静音        |
| `d`             | 切换弹幕显示           |

---

## 浏览器自验证清单

应用启动后已通过 Agent Browser 完成以下端到端验证：

- [x] 首页加载，公告条 + Hero + 视频网格正确渲染
- [x] 视频卡片点击跳转到播放页，URL 同步到 `?v=<id>`
- [x] 视频播放：进度条更新，CDN 流媒体返回 206
- [x] 弹幕与评论接口均返回 200
- [x] 主题切换：Material You / Win8 Metro / Zerexa Purple / Midnight 四主题均生效
- [x] 搜索：URL `?q=music` 触发搜索，结果列表正确显示
- [x] 登录 / 注册对话框打开，Tab 切换登录 / 注册表单
- [x] 移动端 (390x844)：抽屉导航正常，网格自适应单列
- [x] Footer 在短页面贴底，长页面被自然推下，无重叠
- [x] 控制台无运行时报错，ESLint 全量通过

---

## 后续路线图

以下功能已在代码中预留接口或部分实现，可在后续迭代补全：

- 视频上传（分片上传 + 直传预签名 URL）
- 专栏（`/api/articles`）发布与阅读
- 动态（`/api/dynamics`）时间线
- 私信与站内信 UI
- 工单系统
- 公投详情与投票
- 管理员后台（用户管理、视频审核、举报处理）
- 字幕加载与切换
- 视频合集编辑
- 用户举报弹窗的完整表单

---

## 许可

本项目为 Zerexa Video 的非官方前端实现，所有视频内容版权归原作者所有。API 文档与远端服务版权归 Zerexa Video 团队。
