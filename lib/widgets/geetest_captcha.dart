/// GeeTest v4 captcha challenge rendered in a WebView.
///
/// The upstream login / registration API requires a GeeTest v4
/// verification token. The flow mirrors the official website:
///
///   1. load https://static.geetest.com/v4/gt4.js with the public
///      captcha id (fetched from `GET /api/auth/captcha-config`),
///   2. `initGeetest4({product: "float", language: "zho"}, ...)`
///   3. the user completes the challenge,
///   4. `captchaObj.getValidate()` yields the token map
///      `{lot_number, captcha_output, pass_token, gen_time}`,
///   5. the map is posted back to Dart through a JavaScript channel and
///      submitted as the `geetest` field of the auth request.
///
/// The server-side captcha KEY is never part of the client: only the
/// public id is needed here, verification happens upstream.
///
/// WebView support: Android / iOS / macOS. On Linux / Windows the caller
/// is expected to fall back before reaching this widget (see
/// `geetestSupportedPlatform`).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Whether the current platform can render the WebView captcha.
bool get geetestSupportedPlatform =>
    Platform.isAndroid || Platform.isIOS || Platform.isMacOS;

/// Runs the GeeTest v4 challenge and returns the validate map, or `null`
/// when the user dismissed the dialog / the challenge failed.
Future<Map<String, dynamic>?> showGeetestCaptcha(
  BuildContext context, {
  required String captchaId,
}) {
  return showDialog<Map<String, dynamic>>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _GeetestCaptchaDialog(captchaId: captchaId),
  );
}

class _GeetestCaptchaDialog extends StatefulWidget {
  const _GeetestCaptchaDialog({required this.captchaId});

  final String captchaId;

  @override
  State<_GeetestCaptchaDialog> createState() => _GeetestCaptchaDialogState();
}

class _GeetestCaptchaDialogState extends State<_GeetestCaptchaDialog> {
  late final WebViewController _controller;
  bool _ready = false;
  bool _failed = false;
  Timer? _timeout;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..addJavaScriptChannel('ZxCaptcha', onMessageReceived: _onMessage)
      ..loadHtmlString(_buildHtml(widget.captchaId));

    // If gt4.js cannot boot within 20s (blocked network, captcha service
    // outage) surface a retry affordance instead of an endless spinner.
    _timeout = Timer(const Duration(seconds: 20), () {
      if (mounted && !_ready) setState(() => _failed = true);
    });
  }

  @override
  void dispose() {
    _timeout?.cancel();
    super.dispose();
  }

  void _onMessage(JavaScriptMessage message) {
    if (!mounted) return;
    try {
      final data = jsonDecode(message.message);
      if (data is! Map<String, dynamic>) return;
      switch (data['type']) {
        case 'ready':
          setState(() {
            _ready = true;
            _failed = false;
          });
        case 'success':
          final validate = data['data'];
          _timeout?.cancel();
          if (validate is Map<String, dynamic>) {
            Navigator.of(context).pop(validate);
          }
        case 'error':
          if (mounted) {
            setState(() => _failed = true);
          }
        case 'close':
          // User closed the challenge popup itself; keep the dialog open
          // so they can retry without restarting the flow.
          break;
      }
    } catch (_) {
      // Malformed payloads are ignored.
    }
  }

  void _reload() {
    setState(() {
      _failed = false;
      _ready = false;
    });
    _timeout?.cancel();
    _timeout = Timer(const Duration(seconds: 20), () {
      if (mounted && !_ready) setState(() => _failed = true);
    });
    _controller.reload();
  }

  // ---------- embedded page ----------

  String _buildHtml(String captchaId) => '''
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport"
      content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">
<style>
  html, body {
    margin: 0;
    padding: 0;
    background: transparent;
    font-family: -apple-system, "Segoe UI", "Noto Sans SC", sans-serif;
  }
  #box {
    display: flex;
    justify-content: center;
    padding: 18px 8px 10px;
  }
  #hint {
    text-align: center;
    color: #8a94a6;
    font-size: 12px;
    padding: 0 12px 14px;
  }
</style>
</head>
<body>
<div id="box"></div>
<div id="hint">请完成安全验证后继续登录</div>
<script src="https://static.geetest.com/v4/gt4.js"></script>
<script>
(function () {
  function boot() {
    if (!window.initGeetest4) {
      setTimeout(boot, 200);
      return;
    }
    window.initGeetest4({
      captchaId: '$captchaId',
      product: 'float',
      language: 'zho',
      https: true,
      timeout: 15000,
      onError: function () {
        ZxCaptcha.postMessage(JSON.stringify({type: 'error'}));
      }
    }, function (captchaObj) {
      captchaObj.appendTo('#box');
      ZxCaptcha.postMessage(JSON.stringify({type: 'ready'}));
      captchaObj.onSuccess(function () {
        var v = captchaObj.getValidate();
        if (v) {
          ZxCaptcha.postMessage(JSON.stringify({type: 'success', data: v}));
        }
      });
      captchaObj.onError(function () {
        ZxCaptcha.postMessage(JSON.stringify({type: 'error'}));
      });
      captchaObj.onClose(function () {
        ZxCaptcha.postMessage(JSON.stringify({type: 'close'}));
      });
    });
  }
  boot();
})();
</script>
</body>
</html>
''';

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
              child: Row(children: [
                Icon(Icons.verified_user_outlined,
                    size: 20, color: scheme.primary),
                const SizedBox(width: 8),
                Text('安全验证',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: scheme.onSurface)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  tooltip: '取消',
                  onPressed: () => Navigator.of(context).pop(null),
                ),
              ]),
            ),
            SizedBox(
              width: 344,
              height: 430,
              child: Stack(children: [
                WebViewWidget(controller: _controller),
                if (!_ready)
                  Center(
                    child: _failed
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.wifi_off_outlined,
                                  size: 40, color: scheme.onSurfaceVariant),
                              const SizedBox(height: 12),
                              const Text('验证服务连接失败',
                                  style: TextStyle(fontSize: 13)),
                              const SizedBox(height: 14),
                              OutlinedButton.icon(
                                onPressed: _reload,
                                icon: const Icon(Icons.refresh, size: 18),
                                label: const Text('重试'),
                              ),
                            ],
                          )
                        : const SizedBox(
                            width: 30,
                            height: 30,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          ),
                  ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
