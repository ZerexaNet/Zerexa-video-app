/// 消息中心: private conversations + site notifications, with the global
/// [UnreadBadge] kept in sync so the navigation shell can show a red dot.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../stores/app_stores.dart';
import '../widgets/common.dart';
import 'app_shell.dart';
import 'auth_view.dart';
import 'chat_screen.dart';

class MessagesView extends StatefulWidget {
  const MessagesView({super.key});

  @override
  State<MessagesView> createState() => _MessagesViewState();
}

class _MessagesViewState extends State<MessagesView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  List<Conversation> _conversations = [];
  List<SiteNotification> _notifications = [];
  bool _convLoading = true;
  bool _notifLoading = true;
  String? _convError;
  String? _notifError;
  bool _kicked = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    _tabs.removeListener(_onTabChanged);
    _tabs.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabs.indexIsChanging) return;
    if (!context.read<AuthStore>().isAuthed) return;
    _refreshAll();
  }

  Future<void> _refreshAll() async {
    await Future.wait([_loadConversations(), _loadNotifications()]);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthStore>();
    if (!auth.isAuthed) {
      if (_kicked) {
        _kicked = false;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) context.read<UnreadBadge>().count = 0;
        });
      }
      return Scaffold(
        appBar: AppBar(title: const Text('消息中心')),
        body: ZxEmpty(
          icon: Icons.forum_outlined,
          message: '登录后可查看私信与通知',
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
    if (!_kicked) {
      _kicked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _refreshAll();
      });
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('消息中心'),
        actions: [
          if (_tabs.index == 1)
            IconButton(
              tooltip: '全部已读',
              icon: const Icon(Icons.done_all),
              onPressed: _notifLoading ? null : _markAllRead,
            ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: '私信'),
            Tab(text: '通知'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _buildConversationsTab(),
          _buildNotificationsTab(),
        ],
      ),
    );
  }

  // ---------- conversations ----------

  Widget _buildConversationsTab() {
    if (_convLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_convError != null) {
      return ZxError(message: _convError!, onRetry: _loadConversations);
    }
    if (_conversations.isEmpty) {
      return const ZxEmpty(icon: Icons.forum_outlined, message: '暂无私信');
    }
    return RefreshIndicator(
      onRefresh: _loadConversations,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: _conversations.length,
        separatorBuilder: (_, _) =>
            const Divider(height: 1, indent: 80, endIndent: 16),
        itemBuilder: (context, i) => _conversationTile(context, _conversations[i]),
      ),
    );
  }

  Widget _conversationTile(BuildContext context, Conversation c) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: ZxAvatar(url: c.peerGravatarUrl, name: c.peerUsername, size: 48),
      title: Text(
        c.peerUsername.isEmpty ? '匿名用户' : c.peerUsername,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          c.lastMessage.isEmpty ? '暂无消息' : c.lastMessage,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            formatRelative(c.lastMessageAt),
            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 5),
          _UnreadDot(count: c.unreadCount),
        ],
      ),
      onTap: () => _openChat(c),
    );
  }

  Future<void> _openChat(Conversation c) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ChatScreen(
        conversationId: c.id,
        peerUsername: c.peerUsername,
        peerGravatar: c.peerGravatarUrl,
        peerUid: c.peerUid,
      ),
    ));
    if (!mounted) return;
    await _loadConversations();
    _updateBadge();
  }

  Future<void> _loadConversations() async {
    if (!mounted) return;
    setState(() {
      _convLoading = true;
      _convError = null;
    });
    try {
      final api = context.read<AuthStore>().api;
      final convs = await api.listConversations();
      if (!mounted) return;
      setState(() {
        _conversations = convs;
        _convLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _convError = e.message;
        _convLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _convError = '私信加载失败，请稍后重试';
        _convLoading = false;
      });
    }
    if (mounted) _updateBadge();
  }

  // ---------- notifications ----------

  Widget _buildNotificationsTab() {
    if (_notifLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_notifError != null) {
      return ZxError(message: _notifError!, onRetry: _loadNotifications);
    }
    if (_notifications.isEmpty) {
      return const ZxEmpty(icon: Icons.notifications_none, message: '暂无通知');
    }
    return RefreshIndicator(
      onRefresh: _loadNotifications,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: _notifications.length,
        separatorBuilder: (_, _) =>
            const Divider(height: 1, indent: 72, endIndent: 16),
        itemBuilder: (context, i) => _notificationTile(context, i),
      ),
    );
  }

  Widget _notificationTile(BuildContext context, int index) {
    final scheme = Theme.of(context).colorScheme;
    final n = _notifications[index];
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Icon(
        _iconFor(n.type),
        color: n.read ? scheme.onSurfaceVariant : scheme.primary,
      ),
      title: Text(
        n.title.isEmpty ? '系统通知' : n.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: n.read ? FontWeight.w500 : FontWeight.w700,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          n.content,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12.5,
            height: 1.35,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ),
      trailing: Text(
        formatRelative(n.createdAt),
        style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
      ),
      onTap: () => _openNotification(index),
    );
  }

  Future<void> _openNotification(int index) async {
    final n = _notifications[index];
    if (n.read) return;
    final api = context.read<AuthStore>().api;
    try {
      await api.markNotificationRead(n.id);
    } on ApiException catch (e) {
      if (mounted) zxToast(context, e.message);
      return;
    } catch (_) {
      if (mounted) zxToast(context, '操作失败，请稍后重试');
      return;
    }
    if (!mounted) return;
    setState(() {
      _notifications[index] = _copyAsRead(n);
    });
    final badge = context.read<UnreadBadge>();
    badge.count = badge.count > 0 ? badge.count - 1 : 0;
  }

  Future<void> _markAllRead() async {
    final api = context.read<AuthStore>().api;
    try {
      await api.markAllNotificationsRead();
    } on ApiException catch (e) {
      if (mounted) zxToast(context, e.message);
      return;
    } catch (_) {
      if (mounted) zxToast(context, '操作失败，请稍后重试');
      return;
    }
    if (!mounted) return;
    setState(() {
      _notifications = [for (final n in _notifications) _copyAsRead(n)];
    });
    _updateBadge();
    zxToast(context, '已全部标记为已读');
  }

  Future<void> _loadNotifications() async {
    if (!mounted) return;
    setState(() {
      _notifLoading = true;
      _notifError = null;
    });
    try {
      final api = context.read<AuthStore>().api;
      final list = await api.listNotifications();
      if (!mounted) return;
      setState(() {
        _notifications = list;
        _notifLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _notifError = e.message;
        _notifLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _notifError = '通知加载失败，请稍后重试';
        _notifLoading = false;
      });
    }
    if (mounted) _updateBadge();
  }

  // ---------- shared ----------

  SiteNotification _copyAsRead(SiteNotification n) => SiteNotification(
        id: n.id,
        type: n.type,
        title: n.title,
        content: n.content,
        link: n.link,
        read: true,
        createdAt: n.createdAt,
        actorUsername: n.actorUsername,
      );

  void _updateBadge() {
    if (!mounted) return;
    final unread = _conversations.fold<int>(0, (sum, c) => sum + c.unreadCount) +
        _notifications.where((n) => !n.read).length;
    context.read<UnreadBadge>().count = unread;
  }
}

IconData _iconFor(String type) {
  final t = type.toLowerCase();
  if (t.contains('like')) return Icons.favorite_outline;
  if (t.contains('comment') || t.contains('reply')) {
    return Icons.chat_bubble_outline;
  }
  if (t.contains('follow')) return Icons.person_add_outlined;
  return Icons.notifications_outlined;
}

/// Red pill showing the unread count; hidden when zero.
class _UnreadDot extends StatelessWidget {
  const _UnreadDot({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.error,
        borderRadius: BorderRadius.circular(10),
      ),
      constraints: const BoxConstraints(minWidth: 20),
      child: Text(
        count > 99 ? '99+' : '$count',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
