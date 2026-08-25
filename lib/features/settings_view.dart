/// Settings page: theme picker, about section and account actions.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api.dart';
import '../stores/app_stores.dart';
import '../theme/app_themes.dart';
import '../widgets/common.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  bool _pinging = false;

  static const String _appVersion =
      String.fromEnvironment('APP_VERSION', defaultValue: '0.5.0');

  Future<void> _checkConnection() async {
    if (_pinging) return;
    final api = context.read<AuthStore>().api;
    setState(() => _pinging = true);
    try {
      await api.ping();
      if (!mounted) return;
      zxToast(context, '连接正常');
    } on ApiException catch (e) {
      if (mounted) zxToast(context, e.message);
    } catch (_) {
      if (mounted) zxToast(context, '连接失败，请检查网络');
    } finally {
      if (mounted) setState(() => _pinging = false);
    }
  }

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('确定要退出当前账号吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('退出'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await context.read<AuthStore>().logout();
      if (mounted) zxToast(context, '已退出登录');
    } catch (_) {
      if (mounted) zxToast(context, '退出失败，请稍后重试');
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeStore = context.watch<ThemeStore>();
    final auth = context.watch<AuthStore>();
    final api = context.read<AuthStore>().api;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
        children: [
          // ---------- 外观主题 ----------
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader(context, Icons.palette_outlined, '外观主题'),
                RadioListTile<AppThemeMode>(
                  value: AppThemeMode.material,
                  groupValue: themeStore.mode,
                  onChanged: (v) {
                    if (v != null) themeStore.setMode(v);
                  },
                  title: const Text('Material You'),
                  subtitle: const Text('圆角卡片与柔和配色'),
                ),
                RadioListTile<AppThemeMode>(
                  value: AppThemeMode.metro,
                  groupValue: themeStore.mode,
                  onChanged: (v) {
                    if (v != null) themeStore.setMode(v);
                  },
                  title: const Text('Win8 Metro'),
                  subtitle: const Text('扁平色块与硬朗直角'),
                ),
                RadioListTile<AppThemeMode>(
                  value: AppThemeMode.clean,
                  groupValue: themeStore.mode,
                  onChanged: (v) {
                    if (v != null) themeStore.setMode(v);
                  },
                  title: const Text('Zerexa Clean'),
                  subtitle: const Text('纯白底色与藏蓝墨色'),
                ),
                RadioListTile<AppThemeMode>(
                  value: AppThemeMode.midnight,
                  groupValue: themeStore.mode,
                  onChanged: (v) {
                    if (v != null) themeStore.setMode(v);
                  },
                  title: const Text('Midnight 深色'),
                  subtitle: const Text('高对比夜间模式'),
                ),
                const SizedBox(height: 6),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // ---------- 关于 ----------
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader(context, Icons.info_outline, '关于'),
                ListTile(
                  title: const Text('应用名称'),
                  trailing: const Text('Zerexa Video'),
                ),
                ListTile(
                  title: const Text('版本'),
                  trailing: const Text(_appVersion),
                ),
                ListTile(
                  title: const Text('API 服务器'),
                  trailing: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 200),
                    child: Text(
                      api.baseUrl,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12.5, color: scheme.onSurfaceVariant),
                    ),
                  ),
                ),
                ListTile(
                  title: const Text('开源许可'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    showAboutDialog(
                      context: context,
                      applicationName: 'Zerexa Video',
                      applicationLegalese: 'Zerexa Video - MIT License',
                    );
                  },
                ),
                ListTile(
                  title: const Text('检查连接'),
                  subtitle: const Text('测试与服务器的连通性'),
                  trailing: _pinging
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.chevron_right),
                  onTap: _pinging ? null : _checkConnection,
                ),
                const SizedBox(height: 6),
              ],
            ),
          ),
          // ---------- 账号 ----------
          if (auth.isAuthed) ...[
            const SizedBox(height: 14),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionHeader(context, Icons.person_outline, '账号'),
                  ListTile(
                    leading: const Icon(Icons.logout),
                    title: const Text('退出登录'),
                    textColor: scheme.error,
                    iconColor: scheme.error,
                    onTap: _confirmLogout,
                  ),
                  const SizedBox(height: 6),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Tinted icon + bold label used as the header of each settings card.
  Widget _sectionHeader(BuildContext context, IconData icon, String title) {
    final accent = context.zx.accentFor(0);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(context.zx.controlRadius),
            ),
            child: Icon(icon, size: 18, color: accent),
          ),
          const SizedBox(width: 10),
          Text(title,
              style: const TextStyle(
                  fontSize: 15.5, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
