# Zerexa Video App

Zerexa Video 的**原生跨平台客户端**（Flutter 构建，非网页套壳），一套代码编译出 Android APK、iOS IPA、Linux 与 Windows 原生应用，直连 [video.zerexa.net](https://video.zerexa.net) API。

> 产品要求：代码、README 与应用内**不使用表情符号**，图标一律使用 Material Icons 与 SVG 资源。

## 平台产物

| 平台 | 产物 | 说明 |
|------|------|------|
| Android | `zerexa-video-android-universal-<ver>.apk` | universal APK（arm64 / arm / x86_64） |
| iOS | `zerexa-video-ios-unsigned-<ver>.ipa` | 未签名，TrollStore / AltStore / Sideloadly 侧载 |
| Linux x64 | `zerexa-video-linux-x64-<ver>.tar.gz` | 解压后运行 `./zerexa-video/zerexa_video`（需系统 libmpv） |
| Windows x64 | `zerexa-video-windows-x64-<ver>.zip` | 解压后运行 `zerexa-video\ZerexaVideo.exe` |

全部产物由 GitHub Actions 自动构建并发布到 [Releases](../../releases)。

## 功能一览

- **视频**：原生播放器（media_kit，硬解）、弹幕浮层、字幕轨道加载与切换、点赞 / 收藏 / 投币、评论与楼中楼回复
- **发现**：关键词搜索、分类筛选（分区标签自动从服务端数据提取）、排序（最新 / 最多播放 / 最多点赞）、站点公告栏
- **登录 / 注册**：GeeTest v4 人机验证（WebView 内嵌官方 gt4.js，验证令牌随请求提交）；未登录可正常浏览全部视频
- **公告**：支持查看完整详情（标题、正文、发布者与时间）
- **动态**：时间线、发布动态（支持图片）、点赞、删除自己的动态
- **专栏**：图文创作与阅读、编辑 / 删除、点赞
- **私信与站内信**：会话列表、即时聊天界面、通知中心、未读角标
- **工单**：提交 / 回复 / 关闭 / 重开，状态与优先级
- **公投**：选项投票、实时结果条形图、防重复投票
- **合集**：创建 / 编辑 / 删除合集，添加与移除视频
- **投稿**：视频文件分片上传（预签名 URL），进度显示
- **举报**：完整的举报表单（分类 + 描述），支持举报用户 / 视频 / 评论 / 动态
- **管理后台**：概览统计、用户封禁 / 解禁 / 角色变更、视频审核（通过 / 拒绝 / 删除）、举报处理、公告增删改
- **多主题**：Material You / Win8 Metro / Zerexa Clean（默认）/ Midnight 深色，即时切换并持久化

## 技术栈

- Flutter 3.47 + Dart 3.13，Material 3
- `media_kit` 跨平台视频播放（Android / iOS / Windows / Linux）
- `dio` 网络层（JWT Bearer 自动注入，无 CORS 限制直连上游）
- `provider` 状态管理（AuthStore / ThemeStore / UnreadBadge）
- `shared_preferences` 令牌与主题持久化
- `flutter_svg` + 自绘 SVG 品牌资源
- `file_picker` 跨平台文件选择（分片上传）

## 项目结构

```
lib/
  main.dart               入口：Provider 装配 + MaterialApp
  core/
    api.dart              ZerexaApi：全部上游端点封装
    models.dart           数据模型（宽松 JSON 解析）
    format.dart           数字 / 时间 / 字节格式化
  stores/app_stores.dart  AuthStore（登录态）+ ThemeStore（主题）
  theme/app_themes.dart   四套主题 + ZxSpec 扩展令牌
  widgets/
    common.dart           头像 / 徽章 / 视频卡片 / 空态 / 错误态
    danmaku_overlay.dart  原生弹幕浮层（轨道分配 + 滚动动画）
    report_dialog.dart    举报完整表单
  features/
    app_shell.dart        自适应导航（底部栏 / 侧栏）
    home_view.dart        首页信息流
    discover_view.dart    搜索与分类
    watch_view.dart       播放页（弹幕 / 字幕 / 评论 / 互动）
    auth_view.dart        登录 / 注册
    mine_view.dart        个人中心（收藏 / 历史 / 功能入口）
    user_page_view.dart   用户公开主页
    dynamics_view.dart    动态时间线
    articles_view.dart    专栏（列表 / 详情 / 编辑器）
    collections_view.dart 合集（列表 / 详情 / 编辑器）
    messages_view.dart    消息中心（私信 + 通知）
    chat_screen.dart      聊天会话
    tickets_view.dart     工单
    votes_view.dart       公投
    upload_view.dart      视频投稿（分片上传）
    settings_view.dart    设置（主题 / 关于）
    admin_view.dart       管理后台（五个标签页）
```

## 登录验证码（GeeTest v4）

上游站点的登录与注册受 GeeTest v4 人机验证保护，客户端流程与官网一致：

1. `GET /api/auth/captcha-config` 获取 `geetest_enabled` 与公开的 `geetest_captcha_id`
2. WebView 加载 `https://static.geetest.com/v4/gt4.js`，`initGeetest4`（float 模式）渲染验证组件
3. 用户完成验证后取 `getValidate()` 令牌（`lot_number` / `captcha_output` / `pass_token` / `gen_time`）
4. 令牌作为 `geetest` 字段随登录 / 注册请求提交，由上游服务端用其私钥完成二次校验

安全说明：`CAPTCHA_KEY` 是服务端校验密钥，**只存在于服务端**，客户端代码与二进制中不包含、也不需要它；客户端只使用公开的 captcha id（且优先从接口动态获取，硬编码值仅作兜底）。桌面端（Linux / Windows）暂未内嵌验证码组件，会提示改用移动端或官网登录。

## 本地开发

```bash
flutter pub get
flutter run                 # 连接的设备 / 桌面端
flutter analyze
flutter test
```

覆盖上游地址（默认 `https://video.zerexa.net`）：

```bash
flutter run --dart-define=API_BASE_URL=https://your-mirror.example
```

各平台构建：

```bash
flutter build apk --release                 # Android
flutter build linux --release               # Linux（需 clang/cmake/ninja/libgtk-3-dev/libmpv-dev）
flutter build windows --release             # Windows
flutter build ios --release --no-codesign   # iOS
```

## 发布流程（GitHub Actions）

- push 到 `main`（不带 `v*` tag）→ 自动发 **pre-release**，版本号 `0.0.0-pre.<commit 前 6 位>`，tag `pre-<sha6>`
- push `v*` tag（如 `v0.5.0`）→ 自动发**正式 release** 并抢占 latest
- 四个构建 job（Android / Linux / Windows / iOS）并行执行，全部成功后统一上传产物与 `SHA256SUMS.txt`

## 许可

MIT License，见 [LICENSE](LICENSE)。
