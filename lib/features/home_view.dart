/// Home tab: active announcements + latest video feed with infinite scroll.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api.dart';
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
        ]),
        const SizedBox(height: 8),
        for (final a in items.take(3))
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '${a.title} · ${a.content}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5, height: 1.4),
            ),
          ),
      ]),
    );
  }
}
