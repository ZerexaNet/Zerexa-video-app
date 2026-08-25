/// 动态 feed: the community timeline tab plus the per-user dynamics tab
/// shown inside [UserPageView]. Publishing, liking, deleting and reporting
/// are all wired to the upstream dynamics endpoints.
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../stores/app_stores.dart';
import '../widgets/common.dart';
import '../widgets/report_dialog.dart';
import 'auth_view.dart';
import 'user_page_view.dart';

/// Community timeline with a composer FAB.
class DynamicsView extends StatefulWidget {
  const DynamicsView({super.key});

  @override
  State<DynamicsView> createState() => _DynamicsViewState();
}

class _DynamicsViewState extends State<DynamicsView> {
  final List<DynamicItem> _items = [];
  bool _loading = true;
  String? _error;
  bool _kicked = false;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthStore>();
    if (!auth.isAuthed) {
      // Reset so the feed reloads after the next successful login.
      _kicked = false;
      return Scaffold(
        appBar: AppBar(title: const Text('动态')),
        body: ZxEmpty(
          icon: Icons.bolt_outlined,
          message: '登录后即可浏览和发布动态',
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
        if (mounted) _load();
      });
    }
    return Scaffold(
      appBar: AppBar(title: const Text('动态')),
      floatingActionButton: FloatingActionButton(
        tooltip: '发布动态',
        onPressed: _showComposer,
        child: const Icon(Icons.edit_note),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ZxError(message: _error!, onRetry: _load);
    }
    if (_items.isEmpty) {
      return const ZxEmpty(
        icon: Icons.bolt_outlined,
        message: '还没有动态，快来发布第一条吧',
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 6),
        itemCount: _items.length,
        itemBuilder: (context, i) =>
            _DynamicCard(item: _items[i], onDeleted: _load),
      ),
    );
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<AuthStore>().api;
      final items = await api.listDynamics(limit: 50);
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(items);
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = '动态加载失败，请稍后重试';
        _loading = false;
      });
    }
  }

  Future<void> _showComposer() async {
    final published = await showDialog<bool>(
      context: context,
      builder: (_) => const _ComposerDialog(),
    );
    if (published == true && mounted) {
      zxToast(context, '发布成功');
      _load();
    }
  }
}

/// Dynamics of a single user, embedded in [UserPageView].
class UserDynamicsTab extends StatefulWidget {
  const UserDynamicsTab({super.key, required this.uid});

  final int uid;

  @override
  State<UserDynamicsTab> createState() => _UserDynamicsTabState();
}

class _UserDynamicsTabState extends State<UserDynamicsTab>
    with AutomaticKeepAliveClientMixin {
  final List<DynamicItem> _items = [];
  bool _loading = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ZxError(message: _error!, onRetry: _load);
    }
    if (_items.isEmpty) {
      return const ZxEmpty(icon: Icons.bolt_outlined, message: 'TA还没有发布动态');
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 6),
        itemCount: _items.length,
        itemBuilder: (context, i) =>
            _DynamicCard(item: _items[i], onDeleted: _load),
      ),
    );
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<AuthStore>().api;
      final items = await api.listDynamicsByUser(widget.uid, limit: 50);
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(items);
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = '动态加载失败，请稍后重试';
        _loading = false;
      });
    }
  }
}

/// One timeline card: author, content, media grid, like + comment footer.
class _DynamicCard extends StatefulWidget {
  const _DynamicCard({required this.item, this.onDeleted});

  final DynamicItem item;
  final VoidCallback? onDeleted;

  @override
  State<_DynamicCard> createState() => _DynamicCardState();
}

class _DynamicCardState extends State<_DynamicCard> {
  late bool _liked = widget.item.liked;
  late int _likes = widget.item.likes;
  bool _likeBusy = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final api = context.read<AuthStore>().api;
    final item = widget.item;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPress: _showActions,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ZxAuthor(
                username: item.authorUsername,
                uid: item.authorUid,
                gravatar: item.authorGravatarUrl,
                badge: item.authorVerificationBadge,
                badgeLabel: item.authorVerificationLabel,
                size: 24,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => UserPageView(uid: item.authorUid),
                )),
              ),
              if (item.content.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    item.content,
                    style: const TextStyle(fontSize: 14.5, height: 1.5),
                  ),
                ),
              if (item.mediaUrls.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final url in item.mediaUrls)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            width: 104,
                            height: 104,
                            child: CachedNetworkImage(
                              imageUrl: api.resolveAsset(url),
                              fit: BoxFit.cover,
                              placeholder: (_, _) =>
                                  Container(color: scheme.surfaceContainerHighest),
                              errorWidget: (_, _, _) => Container(
                                color: scheme.surfaceContainerHighest,
                                child: Icon(
                                  Icons.broken_image_outlined,
                                  size: 22,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              _buildFooter(context, item),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context, DynamicItem item) {
    final scheme = Theme.of(context).colorScheme;
    final meta = formatRelative(item.createdAt) +
        ((item.ipLocation == null || item.ipLocation!.isEmpty)
            ? ''
            : ' · IP属地 ${item.ipLocation}');
    return Row(
      children: [
        Expanded(
          child: Text(
            meta,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: '点赞',
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          padding: EdgeInsets.zero,
          onPressed: _likeBusy ? null : _toggleLike,
          icon: Icon(
            _liked ? Icons.favorite : Icons.favorite_outline,
            size: 18,
            color: _liked ? scheme.error : scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 2),
        Text('$_likes',
            style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant)),
        const SizedBox(width: 14),
        Icon(Icons.chat_bubble_outline,
            size: 16, color: scheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text('${item.comments}',
            style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant)),
      ],
    );
  }

  Future<void> _toggleLike() async {
    final auth = context.read<AuthStore>();
    if (!auth.isAuthed) {
      zxToast(context, '请先登录后再点赞');
      return;
    }
    if (_likeBusy) return;
    setState(() => _likeBusy = true);
    final prevLiked = _liked;
    final prevLikes = _likes;
    setState(() {
      _liked = !_liked;
      _likes = _liked ? _likes + 1 : _likes - 1;
    });
    try {
      await auth.api.likeDynamic(widget.item.id);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _liked = prevLiked;
          _likes = prevLikes;
        });
        zxToast(context, e.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _liked = prevLiked;
          _likes = prevLikes;
        });
        zxToast(context, '操作失败，请稍后重试');
      }
    } finally {
      if (mounted) setState(() => _likeBusy = false);
    }
  }

  void _showActions() {
    final auth = context.read<AuthStore>();
    final isOwn = auth.user?.uid == widget.item.authorUid;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: const Text('举报该动态'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                showReportDialog(
                  context,
                  targetType: 'dynamic',
                  targetId: widget.item.id,
                  targetUid: widget.item.authorUid,
                  targetTitle: widget.item.authorUsername,
                );
              },
            ),
            if (isOwn)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('删除动态'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _confirmDelete();
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除动态'),
        content: const Text('删除后无法恢复，确定删除这条动态吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final api = context.read<AuthStore>().api;
    try {
      await api.deleteDynamic(widget.item.id);
      if (mounted) zxToast(context, '已删除');
      widget.onDeleted?.call();
    } on ApiException catch (e) {
      if (mounted) zxToast(context, e.message);
    } catch (_) {
      if (mounted) zxToast(context, '删除失败，请稍后重试');
    }
  }
}

/// Full-screen-ish dialog used to publish a new text-only dynamic.
class _ComposerDialog extends StatefulWidget {
  const _ComposerDialog();

  @override
  State<_ComposerDialog> createState() => _ComposerDialogState();
}

class _ComposerDialogState extends State<_ComposerDialog> {
  final _ctrl = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('发布动态'),
      content: SizedBox(
        width: 460,
        child: TextField(
          controller: _ctrl,
          autofocus: true,
          maxLength: 1000,
          maxLines: 6,
          minLines: 4,
          keyboardType: TextInputType.multiline,
          decoration: const InputDecoration(
            hintText: '分享此刻的想法...',
            alignLabelWithHint: true,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _busy ? null : _publish,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('发布'),
        ),
      ],
    );
  }

  Future<void> _publish() async {
    final content = _ctrl.text.trim();
    if (content.isEmpty) {
      zxToast(context, '动态内容不能为空');
      return;
    }
    setState(() => _busy = true);
    try {
      final api = context.read<AuthStore>().api;
      await api.createDynamic({'content': content});
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) {
        zxToast(context, '发布失败：${e.message}');
        setState(() => _busy = false);
      }
    } catch (_) {
      if (mounted) {
        zxToast(context, '发布失败，请稍后重试');
        setState(() => _busy = false);
      }
    }
  }
}
