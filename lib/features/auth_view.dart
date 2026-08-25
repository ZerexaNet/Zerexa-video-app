/// Full-screen sign-in / registration flow.
///
/// Login and registration are protected by a GeeTest v4 captcha on the
/// upstream server; the challenge is completed in an embedded WebView
/// right before the credentials are submitted.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api.dart';
import '../core/models.dart';
import '../stores/app_stores.dart';
import '../widgets/common.dart';
import '../widgets/geetest_captcha.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isRegister = false;
  bool _obscure = true;
  bool _busy = false;

  /// Captcha settings advertised by the server (cached after first load).
  CaptchaConfig _captcha = const CaptchaConfig();

  final _identifierCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCaptchaConfig();
  }

  Future<void> _loadCaptchaConfig() async {
    final cfg = await context.read<AuthStore>().api.captchaConfig();
    if (mounted) setState(() => _captcha = cfg);
  }

  @override
  void dispose() {
    _identifierCtrl.dispose();
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // The upstream rejects auth requests without a GeeTest token.
    Map<String, dynamic>? geetest;
    if (_captcha.geetestEnabled) {
      if (!geetestSupportedPlatform) {
        _showDesktopCaptchaNotice();
        return;
      }
      if (_captcha.geetestCaptchaId.isEmpty) {
        zxToast(context, '验证码配置加载中，请稍后重试');
        await _loadCaptchaConfig();
        return;
      }
      geetest = await showGeetestCaptcha(
        context,
        captchaId: _captcha.geetestCaptchaId,
      );
      if (geetest == null) {
        zxToast(context, '需要完成安全验证才能继续');
        return;
      }
    }

    setState(() => _busy = true);
    final auth = context.read<AuthStore>();
    try {
      if (_isRegister) {
        await auth.register(
          _usernameCtrl.text.trim(),
          _emailCtrl.text.trim(),
          _passwordCtrl.text,
          geetest: geetest,
        );
      } else {
        await auth.login(
          _identifierCtrl.text.trim(),
          _passwordCtrl.text,
          geetest: geetest,
        );
      }
      if (mounted) {
        zxToast(context, _isRegister ? '注册成功' : '欢迎回来');
        Navigator.of(context).pop();
      }
    } on ApiException catch (e) {
      if (mounted) zxToast(context, e.message);
    } catch (e) {
      if (mounted) zxToast(context, '操作失败，请稍后重试');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Linux / Windows builds cannot render the WebView captcha yet.
  void _showDesktopCaptchaNotice() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('暂不支持验证码登录'),
        content: const Text(
          '登录与注册需要完成 GeeTest 安全验证，当前桌面平台（Linux / Windows）'
          '尚未内置验证码组件。\n\n'
          '你可以在 Android / iOS 客户端或官网完成登录，桌面端浏览视频'
          '不受影响。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(_isRegister ? '注册账号' : '登录')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const ZxLogo(height: 34),
                  const SizedBox(height: 28),
                  Text(
                    _isRegister ? '加入 Zerexa Video' : '欢迎回来',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _isRegister ? '创建账号，开启创作与互动之旅' : '登录以点赞、收藏、评论和投稿',
                    style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13.5),
                  ),
                  const SizedBox(height: 26),
                  if (_isRegister) ...[
                    TextFormField(
                      controller: _usernameCtrl,
                      decoration: const InputDecoration(
                        labelText: '用户名',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().length < 2) ? '用户名至少 2 个字符' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: '邮箱',
                        prefixIcon: Icon(Icons.mail_outline),
                      ),
                      validator: (v) =>
                          (v == null || !v.contains('@')) ? '请输入有效的邮箱地址' : null,
                    ),
                    const SizedBox(height: 14),
                  ] else
                    TextFormField(
                      controller: _identifierCtrl,
                      decoration: const InputDecoration(
                        labelText: '用户名或邮箱',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? '请输入用户名或邮箱' : null,
                    ),
                  TextFormField(
                    controller: _passwordCtrl,
                    obscureText: _obscure,
                    decoration: InputDecoration(
                      labelText: '密码',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    validator: (v) =>
                        (v == null || v.length < 6) ? '密码至少 6 位' : null,
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_isRegister ? '创建账号' : '登录'),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.verified_user_outlined,
                        size: 13,
                        color: scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _captcha.geetestEnabled ? '登录前需完成安全验证' : '安全验证未启用',
                        style: TextStyle(
                            fontSize: 12, color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextButton(
                    onPressed: _busy ? null : () => setState(() => _isRegister = !_isRegister),
                    child: Text(_isRegister ? '已有账号？去登录' : '没有账号？立即注册'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
