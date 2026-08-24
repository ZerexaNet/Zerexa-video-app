---
Task ID: continuation-admin-theme
Agent: Super Z (main agent)
Task: 用户反馈：移除"Zerexa Purple"主题，改为 io.hk.cn 风格清爽设计；完成后台管理面板；推送至 https://github.com/ZerexaNet/Zerexa-video-app

Work Log:
- 探测远端 API (https://video.zerexa.net)，确认 admin 端点存在：
  GET /api/admin/videos?status=...|users?role=...|reports?status=...|announcements
  POST /api/admin/announcements
  PUT /api/videos/{id} / DELETE /api/videos/{id}（资源级动作）
- 主题改造：把 zerexa 主题调色板从紫色 (#9373EE) 改为海军蓝 (#1E40AF)
  + 纯白底，命名为 "Zerexa Clean"。同时更新 dark 主题为蓝色调，
  Logo SVG 渐变、theme-switcher swatch、Hero 渐变、弹幕颜色预设、
  分类占位渐变全部去紫。
- 后台架构：新增 src/components/admin/ 目录，包含
  admin-shell / admin-shared / admin-dashboard / admin-videos /
  admin-users / admin-reports / admin-announcements / index。
  全部以 TanStack Query 取数 + zustand 路由 (?view=admin&section=...)
  + shadcn/ui 表格 + 状态徽章 + 二次确认对话框。
- 扩展 src/lib/api.ts：AdminUser / AdminReport / AdminAnnouncementInput /
  AdminVideoUpdateInput 类型；adminListVideos / Users / Reports /
  Announcements、adminCreateAnnouncement、adminUpdateAnnouncement
  (复用 POST + action 字段)、adminDeleteAnnouncement、updateVideo、
  deleteVideo、isAdminRole() 角色判定。
- 扩展 src/lib/route.ts：View 联合类型新增 {kind:'admin', section}，
  parseView / pushView / goAdmin(section?) 全部支持。
- 更新 src/components/app-shell.tsx：admin 视图直接渲染 AdminShell，
  跳过前台 Header / Footer。app-header 在用户角色为 admin/moderator
  时显示"管理后台"下拉项。
- 新增图标：Dashboard / Users / Plus / Trash / Pencil / Filter /
  CheckCircle / XCircle / ExternalLink / Chart / Alert / Inbox / Clock，
  全部手绘 SVG，无 emoji。
- README 全面重写：新增"管理后台"章节、更新主题表为 Zerexa Clean、
  更新项目结构、路由表、验证清单、路线图。
- 构建 / Lint / 类型检查全部通过：bun run lint (0 errors)、
  bunx tsc --noEmit (src/ 下 0 errors)、bun run build 成功。
- 重启 dev 服务器，验证六条路由全部返回 200：/、/?view=admin、
  /?view=admin&section=videos|users|reports|announcements。
- 推送 GitHub：配置 remote (使用用户提供的 PAT)、commit、
  pull --rebase --allow-unrelated-histories 解决 README 冲突、
  git push 成功（commit 7a7d570）。推送完成后清理 remote URL
  中的 token。

Stage Summary:
- 已上线 Zerexa Clean 主题（取代 Zerexa Purple），全项目零紫色。
- 已建成完整后台管理面板（5 个子页面 + 侧边栏 + 顶栏 + 移动端抽屉）。
- 代码已推送至 https://github.com/ZerexaNet/Zerexa-video-app（main 分支）。
- 已通过 lint / tsc / next build / dev server 路由验证。
- 后台使用入口：登录管理员账号 → 顶栏右上角头像下拉 → "管理后台"。

---
Task ID: continuation-community-features
Agent: Super Z (main agent)
Task: 用户反馈：补全视频上传、专栏、动态、私信/站内信、工单、公投、后台封禁/角色/举报处理/公告编辑、字幕、合集编辑、举报弹窗；询问是否能换成 Flutter

Work Log:
- 扩展 src/lib/api.ts：新增 12 套类型与端点
  Article / Dynamic / Conversation / DirectMessage / SiteNotification /
  Ticket / TicketReply / Vote / VoteOption / UploadInit / UploadComplete /
  SubtitleTrack / Collection / ReportUser / AdminUserAction；端点共
  listArticles / getArticle / createArticle / updateArticle / deleteArticle /
  likeArticle；listDynamics / listDynamicsByUser / createDynamic / deleteDynamic /
  likeDynamic；listConversations / listMessages / sendMessage / startConversation /
  markConversationRead；listNotifications / markNotificationRead /
  markAllNotificationsRead；listTickets / getTicket / createTicket / replyTicket /
  closeTicket / reopenTicket；listVotes / getVote / castVote；initUpload /
  completeUpload / abortUpload；listSubtitles；listCollections / listCollectionsByUser /
  getCollection / createCollection / updateCollection / deleteCollection /
  addVideoToCollection / removeVideoFromCollection；reportUser；adminBanUser /
  adminUnbanUser / adminSetUserRole / adminCloseReport / adminMarkReportProcessed。
- 扩展 src/lib/route.ts：View 联合类型新增 13 种 {articles, article, articleEdit,
  dynamics, messages, notifications, tickets, ticket, ticketNew, votes, vote,
  upload, collections, collection, collectionEdit}；parseView / pushView /
  goArticle(s) / goArticleEdit / goDynamics / goMessages / goNotifications /
  goTickets / goTicket / goTicketNew / goVotes / goVote / goUpload /
  goCollections / goCollection / goCollectionEdit 全部支持。
- 新增 SVG 图标 (零 emoji)：Article / Dynamic / Message / Mail / Ticket / Vote /
  Upload / Captions / Collection / PaperPlane / Pin / Reply / Unlock / ShieldOff /
  Shield / PencilSquare / CheckSquare / XSquare（去重原有 MailIcon /
  LockIcon / ChevronRightIcon）。
- 新建视图组件：
  - src/components/articles-view.tsx (列表 / 详情 / 编辑器)
  - src/components/dynamics-view.tsx (时间线 + 发布器)
  - src/components/messages-view.tsx (双栏私信 + 通知页)
  - src/components/tickets-view.tsx (列表 / 创建 / 详情 + 回复)
  - src/components/vote-view.tsx (列表 + 详情含进度条)
  - src/components/upload-view.tsx (init -> PUT 分片 -> complete)
  - src/components/collections-view.tsx (列表 / 详情 / 编辑器)
  - src/components/report-user-dialog.tsx (8 分类 + useReportUser hook)
- 升级 src/components/video-player.tsx：增加字幕支持
  - <track kind="subtitles"> 元素列表
  - Popover 字幕切换菜单（含"关闭字幕"项）
  - textTracks.mode = "showing" / "disabled" 同步
  - 懒加载 GET /api/videos/{id}/subtitles
  - 键盘快捷键 c 打开字幕菜单
- 升级后台：
  - admin-users.tsx：每行新增"封禁 / 解禁 / 角色"三个按钮，
    弹窗可填理由 / 时长 / 选择角色。
  - admin-reports.tsx：每行新增"已处理" / "关闭"按钮，弹窗可附处理说明。
  - admin-announcements.tsx：复用统一 AnnouncementFormDialog 同时支持新建 +
    编辑（预填当前标题 / 正文 / 上线状态）。
- 升级 src/components/app-shell.tsx：渲染 13 种新视图。
- 升级 src/components/app-nav.tsx：移动端抽屉加入投稿 / 动态 / 专栏 /
  合集 / 公投 / 私信 / 通知 / 工单入口。
- 升级 src/components/app-header.tsx：桌面端搜索框右侧新增 8 个
  快速启动图标 (Tooltip 包裹)，下拉菜单也增加全部新视图入口。
- 升级 src/components/watch-view.tsx：VideoPlayer 增加 videoId 参数
  以触发懒加载字幕。
- 更新 README.md：新增"社区功能（v0.3 扩展）"章节，逐项说明每个新视图
  的路由、API、UI 亮点；路线图全部勾选为已完成。
- 构建 / Lint / 类型检查全部通过：
  - bunx tsc --noEmit：src/ 下 0 errors
  - bun run lint：0 errors, 2 warnings (无害的 eslint-disable 注释)
  - bun run build：成功，1 个静态页面 + 2 个动态 API 路由
- 重启 dev server，验证 21 条路由全部返回 200：
  / / ?view=articles / article / article-edit / dynamics / messages /
  notifications / tickets / ticket / ticket-new / votes / vote / upload /
  collections / collection / collection-edit / admin (5 个 section)。
- 关于 Flutter：用户问"能换成 flutter 吗"。Flutter 是 Dart 语言 + 自有
  widget 体系，与当前 Next.js + TypeScript + shadcn/ui + Tailwind
  体系完全不同，迁移等同重写所有组件（约 50+ 文件）。已在最终回复中
  详细解释取舍：保留 Next.js 作为 Web / PWA，若未来需要原生移动端可
  作为独立项目复用同一上游 API。

Stage Summary:
- 12 项社区功能全部在前端完成实现并通过 dev server 路由验证。
- 全部使用 SVG 图标，无 emoji，符合用户要求。
- TypeScript / ESLint / Next.js build 全部通过。
- 准备推送至 GitHub (https://github.com/ZerexaNet/Zerexa-video-app)。
