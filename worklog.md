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
