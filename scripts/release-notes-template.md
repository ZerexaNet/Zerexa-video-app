# Zerexa Video App __VERSION__

__HEADER_LINE__

> __PRE_NOTE__

## 下载

| 平台 | 文件 | 说明 |
|------|------|------|
| Windows x64 | `zerexa-video-server-win-x64.exe` | 双击运行, 默认监听 :3000 |
| Linux x86_64 | `zerexa-video-server-linux-x64` | `chmod +x` 后执行, 默认监听 :3000 |
| Android | `zerexa-video-app-android-universal-__VERSION__.apk` | universal APK, 同时支持 arm64 / arm / x86_64 |
| iOS | `zerexa-video-app-ios-unsigned-__VERSION__.ipa` | 未签名, 用 TrollStore / AltStore 安装 |

## 校验

```
sha256sum -c SHA256SUMS.txt
```

## 服务端运行

```bash
# Linux
chmod +x zerexa-video-server-linux-x64
./zerexa-video-server-linux-x64           # 监听 :3000
PORT=8080 ./zerexa-video-server-linux-x64 # 监听 :8080

# Windows (cmd / PowerShell)
zerexa-video-server-win-x64.exe
$env:PORT=8080; .\zerexa-video-server-win-x64.exe
```

首次运行会自动解压到 `~/.zerexa-video-server/<hash>/`，后续启动直接复用缓存目录。

## 移动端安装

- **Android:** 直接安装 APK（需在系统设置中允许"未知来源"安装）
- **iOS:** IPA 未签名，需用 [TrollStore](https://github.com/opa334/TrollStore) / [AltStore](https://altstore.io) / [Sideloadly](https://sideloadly.io) sideload

## __COMMIT_LIST_TITLE__

__COMMIT_LIST__

---

Actions Run: [#__RUN_NUMBER__](__RUN_URL__)
