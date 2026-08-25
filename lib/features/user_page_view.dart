/// Public profile page for any user: their videos + dynamics, with
/// options to start a private chat or report the account.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../stores/app_stores.dart';
import '../widgets/common.dart';
import '../widgets/report_dialog.dart';
import 'app_shell.dart';
import 'chat_screen.dart';
import 'dynamics_view.dart';

class UserPageView extends StatefulWidget {
  const UserPageView({super.key, required this.uid, this.startChat = false});

  final int uid;
  final bool startChat;

  @override
  State<UserPageView> createState() => _UserPageViewState();
}

class _UserPageViewState extends State<UserPageView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  UserInfo? _user;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  ZerexaApi get _api => context.read<AuthStore>().api;

  Future<void> _load() async {
    try {
      final user = await _api.getUserPublic(widget.uid);
      if (!mounted) return;
      setState(() {
        _user = user;
        _loading = false;
      });
      if (widget.startChat) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _startChat());
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = '用户信息加载失败';
          _loading = false;
        });
      }
    }
  }

  Future<void> _startChat() async {
    final auth = context.read<AuthStore>();
    if (!auth.isAuthed) {
      zxToast(context, '请先登录');
      return;
    }
    if (auth.user?.uid == widget.uid) {
      zxToast(context, '不能给自己发私信');
      return;
    }
    try {
      final conversationId = await _api.startConversation(widget.uid);
      if (!mounted) return;
      if (conversationId.isEmpty) {
        zxToast(context, '会话创建失败');
        return;
      }
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ChatScreen(
          conversationId: conversationId,
          peerUsername: _user?.username ?? '',
          peerGravatar: _user?.gravatarUrl,
          peerUid: widget.uid,
        ),
      ));
    } on ApiException catch (e) {
      if (mounted) zxToast(context, e.message);
    } catch (_) {
      if (mounted) zxToast(context, '无法创建会话');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final auth = context.watch<AuthStore>();
    final isSelf = auth.user?.uid == widget.uid && auth.isAuthed;

    return Scaffold(
      appBar: AppBar(
        title: Text(_user?.username ?? '用户'),
        actions: [
          IconButton(
            tooltip: '私信',
            icon: const Icon(Icons.chat_bubble_outline),
            onPressed: isSelf ? null : _startChat,
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'report') {
                showReportDialog(context,
                    targetType: 'user',
                    targetUid: widget.uid,
                    targetTitle: _user?.username ?? '');
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                  value: 'report',
                  child: ListTile(
                      dense: true,
                      leading: Icon(Icons.flag_outlined),
                      title: Text('举报该用户'))),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ZxError(message: _error!, onRetry: _load)
              : NestedScrollView(
                  headerSliverBuilder: (context, _) => [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(children: [
                          ZxAvatar(
                              url: _user?.gravatarUrl,
                              name: _user?.username ?? '?',
                              size: 68),
                          const SizedBox(width: 18),
                          Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    Text(
                                      _user?.username ?? '',
                                      style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w700),
                                    ),
                                    const SizedBox(width: 6),
                                    ZxBadge(
                                        badge: _user?.verificationBadge,
                                        label: _user?.verificationLabel),
                                  ]),
                                  const SizedBox(height: 4),
                                  Text(
                                    'UID ${_user?.uid ?? widget.uid}'
                                    '${_user?.createdAt != null ? ' · 加入于 ${formatDate(_user!.createdAt!)}' : ''}',
                                    style: TextStyle(
                                        fontSize: 12.5,
                                        color: scheme.onSurfaceVariant),
                                  ),
                                  if (_user?.bio != null &&
                                      _user!.bio!.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      _user!.bio!,
                                      style: const TextStyle(
                                          fontSize: 13, height: 1.5),
                                    ),
                                  ],
                                ]),
                          ),
                        ]),
                      ),
                    ),
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _SliverTabBarDelegate(
                        tabBar: TabBar(controller: _tabs, tabs: const [
                          Tab(text: '视频'),
                          Tab(text: '动态'),
                        ]),
                      ),
                    ),
                  ],
                  body: TabBarView(
                    controller: _tabs,
                    children: [
                      _UserVideosTab(uid: widget.uid),
                      UserDynamicsTab(uid: widget.uid),
                    ],
                  ),
                ),
    );
  }
}

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverTabBarDelegate({required this.tabBar});

  final TabBar tabBar;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: tabBar,
    );
  }

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) =>
      tabBar != oldDelegate.tabBar;
}

class _UserVideosTab extends StatefulWidget {
  const _UserVideosTab({required this.uid});

  final int uid;

  @override
  State<_UserVideosTab> createState() => _UserVideosTabState();
}

class _UserVideosTabState extends State<_UserVideosTab>
    with AutomaticKeepAliveClientMixin {
  List<VideoItem> _videos = [];
  bool _loading = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      // The upstream has no dedicated per-user video route; filter the
      // global feed by author client-side (best effort).
      final all = await context.read<AuthStore>().api.listVideos(limit: 100);
      if (!mounted) return;
      setState(() {
        _videos = all.where((v) => v.authorUid == widget.uid).toList();
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '视频加载失败';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) return const ZxLoadingGrid();
    if (_error != null) return ZxError(message: _error!, onRetry: _load);
    if (_videos.isEmpty) {
      return const ZxEmpty(icon: Icons.videocam_off_outlined, message: '该用户还没有发布视频');
    }
    return ZxVideoGrid(
      videos: _videos,
      onOpen: (v) => openVideo(context, v),
    );
  }
}
