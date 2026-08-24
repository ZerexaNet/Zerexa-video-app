# Zerexa Video - Mobile App

Flutter mobile client for Zerexa Video. Wraps the web app at `https://video.zerexa.net`
inside a native WebView shell with Material 3 chrome.

## Build locally

```bash
cd flutter_app
flutter pub get
flutter build apk --release          # Android
flutter build ios --release --no-codesign   # iOS (unsigned)
```

To point the WebView at a different URL:

```bash
flutter run --dart-define=ZEREXA_WEBVIEW_URL=https://your-staging.example.com
```

## CI

Built automatically by `.github/workflows/release.yml` together with
the desktop server binaries (`zerexa-video-server-linux-x64` and
`zerexa-video-server-win-x64.exe`).

The iOS `.ipa` produced by CI is **unsigned** — install it via
[TrollStore](https://github.com/opa334/TrollStore),
[AltStore](https://altstore.io), or [Sideloadly](https://sideloadly.io).
