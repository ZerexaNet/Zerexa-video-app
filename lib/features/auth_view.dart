/// Full-screen sign-in / registration flow.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api.dart';
import '../stores/app_stores.dart';
import '../widgets/common.dart';

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

  final _identifierCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

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
    setState(() => _busy = true);
    final auth = context.read<AuthStore>();
    try {
      if (_isRegister) {
        await auth.register(
          _usernameCtrl.text.trim(),
          _emailCtrl.text.trim(),
          _passwordCtrl.text,
        );
      } else {
        await auth.login(_identifierCtrl.text.trim(), _passwordCtrl.text);
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
