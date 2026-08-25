# Zerexa Video App __VERSION__

__HEADER_LINE__

> __PRE_NOTE__

原生 Flutter 应用（非网页套壳），一套代码同时构建 Android / iOS / Linux / Windows 四端。

## 下载

| 平台 | 文件 | 说明 |
|------|------|------|
| Android | `zerexa-video-android-universal-__VERSION__.apk` | universal APK, 同时支持 arm64 / arm / x86_64 |
| iOS | `zerexa-video-ios-unsigned-__VERSION__.ipa` | 未签名, 用 TrollStore / AltStore 安装 |
| Linux x86_64 | `zerexa-video-linux-x64-__VERSION__.tar.gz` | 解压后运行 `./zerexa-video/zerexa_video` |
| Windows x64 | `zerexa-video-windows-x64-__VERSION__.zip` | 解压后运行 `zerexa-video\ZerexaVideo.exe` |

## 校验

```
sha256sum -c SHA256SUMS.txt
```

## 桌面端运行

```bash
# Linux (需要系统 libmpv: sudo apt install libmpv2)
tar xzf zerexa-video-linux-x64-__VERSION__.tar.gz
./zerexa-video/zerexa_video
```

```powershell
# Windows: 解压 zip 后双击
zerexa-video\ZerexaVideo.exe
```

## 移动端安装

- **Android:** 直接安装 APK（需在系统设置中允许"未知来源"安装）
- **iOS:** IPA 未签名，需用 [TrollStore](https://github.com/opa334/TrollStore) / [AltStore](https://altstore.io) / [Sideloadly](https://sideloadly.io) sideload

## __COMMIT_LIST_TITLE__

__COMMIT_LIST__

---

Actions Run: [#__RUN_NUMBER__](__RUN_URL__)
