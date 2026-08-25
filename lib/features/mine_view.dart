/// Profile tab ("我的"): account header, quick access to favourites /
/// watch history, and entries to every secondary feature.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/models.dart';
import '../stores/app_stores.dart';
import '../widgets/common.dart';
import 'admin_view.dart';
import 'app_shell.dart';
import 'articles_view.dart';
import 'auth_view.dart';
import 'collections_view.dart';
import 'settings_view.dart';
import 'tickets_view.dart';
import 'upload_view.dart';
import 'user_page_view.dart';
import 'votes_view.dart';

class MineView extends StatelessWidget {
  const MineView({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthStore>();
    if (auth.initializing) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!auth.isAuthed) return const _SignInPrompt();
    return const _SignedInBody();
  }
}

class _SignInPrompt extends StatelessWidget {
  const _SignInPrompt();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const ZxLogo(height: 24)),
      body: ZxEmpty(
        icon: Icons.account_circle_outlined,
        message: '登录后可享受完整功能：收藏、评论、投稿、私信等',
        action: FilledButton.icon(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => const AuthScreen(),
          )),
          icon: const Icon(Icons.login_rounded),
          label: const Text('立即登录'),
        ),
      ),
    );
  }
}

class _SignedInBody extends StatefulWidget {
  const _SignedInBody();

  @override
  State<_SignedInBody> createState() => _SignedInBodyState();
}

class _SignedInBodyState extends State<_SignedInBody> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthStore>().refreshProfile();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthStore>();
    final user = auth.user;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的'),
        actions: [
          IconButton(
            tooltip: '设置',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => _push(context, const SettingsView()),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          // ---- profile header ----
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
            child: Row(children: [
              ZxAvatar(
                  url: user?.gravatarUrl,
                  name: user?.username ?? '?',
                  size: 64,
                  onTap: () => _push(context, UserPageView(uid: user?.uid ?? 0))),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text(
                      user?.username ?? '...',
                      style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 6),
                    ZxBadge(
                        badge: user?.verificationBadge,
                        label: user?.verificationLabel),
                  ]),
                  const SizedBox(height: 4),
                  Text(
                    'UID ${user?.uid ?? ''}'
                    '${user?.points != null ? ' · ${user!.points} 积分' : ''}'
                    '${user?.role != null && user!.role!.isNotEmpty ? ' · ${user.role}' : ''}',
                    style:
                        TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
                  ),
                  if (user?.bio != null && user!.bio!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(user.bio!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12.5, color: scheme.onSurfaceVariant)),
                  ],
                ]),
              ),
              IconButton(
                tooltip: '个人主页',
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: () =>
                    _push(context, UserPageView(uid: user?.uid ?? 0)),
              ),
            ]),
          ),
          const Divider(indent: 20, endIndent: 20),

          // ---- quick tabs: favourites / history ----
          const _FavHistorySection(),

          const Divider(indent: 20, endIndent: 20),

          // ---- feature entries ----
          _entryTile(
            context,
            icon: Icons.video_call_outlined,
            title: '视频投稿',
            subtitle: '分片上传视频，支持大文件',
            onTap: () => _push(context, const UploadView()),
          ),
          _entryTile(
            context,
            icon: Icons.article_outlined,
            title: '专栏',
            subtitle: '图文创作与阅读',
            onTap: () => _push(context, const ArticlesView()),
          ),
          _entryTile(
            context,
            icon: Icons.video_library_outlined,
            title: '合集',
            subtitle: '整理系列视频',
            onTap: () => _push(context, const CollectionsView()),
          ),
          _entryTile(
            context,
            icon: Icons.how_to_vote_outlined,
            title: '公投',
            subtitle: '参与社区投票',
            onTap: () => _push(context, const VotesView()),
          ),
          _entryTile(
            context,
            icon: Icons.support_agent_outlined,
            title: '工单支持',
            subtitle: '问题反馈与求助',
            onTap: () => _push(context, const TicketsView()),
          ),

          const Divider(indent: 20, endIndent: 20),

          if (auth.isAdmin)
            _entryTile(
              context,
              icon: Icons.admin_panel_settings_outlined,
              title: '管理后台',
              subtitle: '用户、视频、举报与公告管理',
              highlight: true,
              onTap: () => _push(context, const AdminConsole()),
            ),
          _entryTile(
            context,
            icon: Icons.settings_outlined,
            title: '设置',
            subtitle: '主题切换与关于',
            onTap: () => _push(context, const SettingsView()),
          ),
          _entryTile(
            context,
            icon: Icons.logout_rounded,
            title: '退出登录',
            onTap: () => _confirmLogout(context),
          ),
        ],
      ),
    );
  }

  Widget _entryTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    bool highlight = false,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(icon, color: highlight ? scheme.primary : null),
      title: Text(title,
          style: TextStyle(
              fontWeight: FontWeight.w600,
              color: highlight ? scheme.primary : null)),
      subtitle: subtitle == null ? null : Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('确定要退出当前账号吗？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(), child: const Text('取消')),
          FilledButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await context.read<AuthStore>().logout();
              if (context.mounted) zxToast(context, '已退出登录');
            },
            child: const Text('退出'),
          ),
        ],
      ),
    );
  }
}

void _push(BuildContext context, Widget page) {
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
}

/// Expandable favourites + watch-history section.
class _FavHistorySection extends StatefulWidget {
  const _FavHistorySection();

  @override
  State<_FavHistorySection> createState() => _FavHistorySectionState();
}

class _FavHistorySectionState extends State<_FavHistorySection> {
  List<VideoItem> _favorites = [];
  List<VideoItem> _history = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = context.read<AuthStore>().api;
    try {
      final fav = await api.favorites().catchError((_) => <VideoItem>[]);
      final his = await api.history().catchError((_) => <VideoItem>[]);
      if (!mounted) return;
      setState(() {
        _favorites = fav;
        _history = his;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = '加载失败';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: ZxError(message: _error!, onRetry: _load),
      );
    }
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: true,
        tilePadding: const EdgeInsets.symmetric(horizontal: 20),
        childrenPadding: const EdgeInsets.only(bottom: 12),
        title: const Text('我的收藏与历史',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        children: [
          _horizontalList('收藏', _favorites),
          const SizedBox(height: 12),
          _horizontalList('历史', _history),
        ],
      ),
    );
  }

  Widget _horizontalList(String label, List<VideoItem> videos) {
    final scheme = Theme.of(context).colorScheme;
    if (videos.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Text('暂无$label记录',
            style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant)),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Text(label,
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: scheme.onSurfaceVariant)),
      ),
      SizedBox(
        height: 132,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          itemCount: videos.length,
          separatorBuilder: (_, _) => const SizedBox(width: 10),
          itemBuilder: (context, i) {
            final v = videos[i];
            return SizedBox(
              width: 150,
              child: ZxVideoCard(video: v, onTap: () => openVideo(context, v)),
            );
          },
        ),
      ),
    ]);
  }
}
