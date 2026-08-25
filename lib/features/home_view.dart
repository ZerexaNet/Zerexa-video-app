/// Home tab: active announcements + latest video feed with infinite scroll.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../stores/app_stores.dart';
import '../widgets/common.dart';
import 'app_shell.dart';
import 'discover_view.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  final _scroll = ScrollController();
  List<VideoItem> _videos = [];
  List<Announcement> _announcements = [];
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  int _offset = 0;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 400) {
        _loadMore();
      }
    });
    _refresh();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = _videos.isEmpty;
      _error = null;
    });
    final api = context.read<AuthStore>().api;
    try {
      final results = await Future.wait([
        api.listVideos(limit: 24, offset: 0),
        api.listAnnouncements(),
      ]);
      final videos = results[0] as List<VideoItem>;
      final announcements = (results[1] as List<Announcement>)
          .where((a) => a.isActive)
          .toList();
      setState(() {
        _videos = videos;
        _announcements = announcements;
        _offset = videos.length;
        _hasMore = videos.length >= 24;
        _loading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _error = '加载失败，请检查网络';
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _loading || _error != null) return;
    setState(() => _loadingMore = true);
    try {
      final more =
          await context.read<AuthStore>().api.listVideos(limit: 24, offset: _offset);
      setState(() {
        _videos.addAll(more);
        _offset = _videos.length;
        _hasMore = more.length >= 24;
      });
    } catch (_) {
      // silent - next scroll retries
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const ZxLogo(height: 24),
        actions: [
          IconButton(
            tooltip: '搜索',
            icon: const Icon(Icons.search_rounded),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const DiscoverView(),
            )),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _loading
          ? const ZxLoadingGrid()
          : _error != null
              ? ZxError(message: _error!, onRetry: _refresh)
              : RefreshIndicator(
                  onRefresh: _refresh,
                  child: CustomScrollView(
                    controller: _scroll,
                    slivers: [
                      if (_announcements.isNotEmpty)
                        SliverToBoxAdapter(child: _AnnouncementBar(_announcements)),
                      SliverToBoxAdapter(
                        child: ZxSectionTitle('最新视频',
                            trailing: TextButton.icon(
                              onPressed: _refresh,
                              icon: const Icon(Icons.refresh, size: 16),
                              label: const Text('刷新'),
                            )),
                      ),
                      if (_videos.isEmpty)
                        const SliverFillRemaining(
                          child: ZxEmpty(
                            icon: Icons.videocam_off_outlined,
                            message: '暂时没有视频，快去上传第一个吧',
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                          sliver: SliverLayoutBuilder(
                            builder: (context, constraints) {
                              final width = constraints.crossAxisExtent;
                              final columns = width > 1600
                                  ? 6
                                  : width > 1250
                                      ? 5
                                      : width > 950
                                          ? 4
                                          : width > 680
                                              ? 3
                                              : 2;
                              return SliverGrid(
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: columns,
                                  mainAxisSpacing: 18,
                                  crossAxisSpacing: 14,
                                  childAspectRatio: .78,
                                ),
                                delegate: SliverChildBuilderDelegate(
                                  (context, i) => ZxVideoCard(
                                    video: _videos[i],
                                    onTap: () => openVideo(context, _videos[i]),
                                  ),
                                  childCount: _videos.length,
                                ),
                              );
                            },
                          ),
                        ),
                      if (_loadingMore)
                        const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2.5),
                              ),
                            ),
                          ),
                        ),
                      if (!_hasMore && _videos.isNotEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Center(
                              child: Text('已经到底了',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: scheme.onSurfaceVariant)),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }
}

class _AnnouncementBar extends StatelessWidget {
  const _AnnouncementBar(this.items);

  final List<Announcement> items;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final shown = items.take(3).toList();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.primary.withValues(alpha: .18)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.campaign_rounded, size: 18, color: scheme.primary),
          const SizedBox(width: 6),
          Text('站点公告',
              style: TextStyle(
                  color: scheme.primary, fontWeight: FontWeight.w700, fontSize: 13)),
          const Spacer(),
          if (items.length > 3)
            GestureDetector(
              onTap: () => _showAll(context),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text('全部 ${items.length} 条',
                    style: TextStyle(
                        fontSize: 12,
                        color: scheme.primary,
                        fontWeight: FontWeight.w600)),
                Icon(Icons.chevron_right_rounded,
                    size: 16, color: scheme.primary),
              ]),
            ),
        ]),
        const SizedBox(height: 6),
        for (final a in shown)
          InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () => showAnnouncementDetail(context, a),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
              child: Row(children: [
                Expanded(
                  child: Text(
                    a.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 6),
                Icon(Icons.chevron_right_rounded,
                    size: 16, color: scheme.onSurfaceVariant),
              ]),
            ),
          ),
      ]),
    );
  }

  void _showAll(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Text('站点公告（${items.length}）',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 16)),
            ),
            for (final a in items)
              ListTile(
                leading: Icon(Icons.campaign_outlined,
                    size: 22,
                    color: Theme.of(context).colorScheme.primary),
                title: Text(a.title,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  a.content,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Text(formatRelative(a.createdAt),
                    style: const TextStyle(fontSize: 11)),
                onTap: () {
                  Navigator.of(context).pop();
                  showAnnouncementDetail(context, a);
                },
              ),
          ],
        ),
      ),
    );
  }
}

/// Full announcement content viewer.
Future<void> showAnnouncementDetail(
    BuildContext context, Announcement a) {
  final scheme = Theme.of(context).colorScheme;
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(a.title, style: const TextStyle(fontSize: 17)),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.person_outline,
                    size: 14, color: scheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(
                  '${a.createdBy.isEmpty ? '官方' : '发布者 ${a.createdBy.substring(0, a.createdBy.length > 8 ? 8 : a.createdBy.length)}'} · ${formatDate(a.createdAt)}',
                  style: TextStyle(
                      fontSize: 12, color: scheme.onSurfaceVariant),
                ),
              ]),
              const Divider(height: 22),
              Text(
                a.content.isEmpty ? '（无正文内容）' : a.content,
                style: const TextStyle(fontSize: 14.5, height: 1.75),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
    ),
  );
}
