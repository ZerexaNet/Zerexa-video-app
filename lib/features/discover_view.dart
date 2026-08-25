/// Discover tab: keyword search + category/sort browsing.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api.dart';
import '../core/models.dart';
import '../stores/app_stores.dart';
import '../widgets/common.dart';
import 'app_shell.dart';

class DiscoverView extends StatefulWidget {
  const DiscoverView({super.key});

  @override
  State<DiscoverView> createState() => _DiscoverViewState();
}

class _DiscoverViewState extends State<DiscoverView> {
  final _searchCtrl = TextEditingController();
  final _scroll = ScrollController();

  List<VideoItem> _results = [];
  bool _searching = false;
  bool _loadingMore = false;
  String? _error;
  int _offset = 0;
  bool _hasMore = true;

  String _category = '';
  String _sort = 'latest';
  String _query = '';

  static const _sorts = [
    ('latest', '最新发布'),
    ('views', '最多播放'),
    ('likes', '最多点赞'),
  ];

  static const _categories = [
    '', '生活', '游戏', '科技', '娱乐', '影视', '音乐', '知识', '动画',
  ];

  @override
  void initState() {
    super.initState();
    _browse();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 400) {
        _loadMore();
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  ZerexaApi get _api => context.read<AuthStore>().api;

  Future<void> _browse() async {
    setState(() {
      _searching = false;
      _error = null;
      _query = '';
      _offset = 0;
    });
    try {
      final videos =
          await _api.listVideos(limit: 24, offset: 0, category: _category.isEmpty ? null : _category, sort: _sort);
      setState(() {
        _results = videos;
        _offset = videos.length;
        _hasMore = videos.length >= 24;
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = '加载失败');
    }
  }

  Future<void> _search(String q) async {
    if (q.trim().isEmpty) return;
    setState(() {
      _searching = true;
      _error = null;
      _query = q.trim();
      _offset = 0;
    });
    try {
      final videos = await _api.search(_query, limit: 40);
      setState(() {
        _results = videos;
        _offset = videos.length;
        _hasMore = false;
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = '搜索失败');
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _searching || _error != null) return;
    setState(() => _loadingMore = true);
    try {
      final more = await _api.listVideos(
          limit: 24, offset: _offset, category: _category.isEmpty ? null : _category, sort: _sort);
      setState(() {
        _results.addAll(more);
        _offset = _results.length;
        _hasMore = more.length >= 24;
      });
    } catch (_) {
      // ignore
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 12,
        title: TextField(
          controller: _searchCtrl,
          textInputAction: TextInputAction.search,
          onSubmitted: _search,
          decoration: InputDecoration(
            hintText: '搜索视频、创作者...',
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: _searchCtrl.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () {
                      _searchCtrl.clear();
                      _browse();
                    },
                  ),
            isDense: true,
          ),
        ),
      ),
      body: CustomScrollView(
        controller: _scroll,
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!_searching) ...[
                    SizedBox(
                      height: 38,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _categories.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (context, i) {
                          final selected = _category == _categories[i];
                          return ChoiceChip(
                            label: Text(_categories[i].isEmpty ? '全部' : _categories[i]),
                            selected: selected,
                            onSelected: (_) {
                              setState(() => _category = _categories[i]);
                              _browse();
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 38,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _sorts.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (context, i) {
                          final selected = _sort == _sorts[i].$1;
                          return ChoiceChip(
                            avatar: Icon(
                              _sorts[i].$1 == 'latest'
                                  ? Icons.schedule
                                  : _sorts[i].$1 == 'views'
                                      ? Icons.visibility_outlined
                                      : Icons.favorite_outline,
                              size: 15,
                            ),
                            label: Text(_sorts[i].$2),
                            selected: selected,
                            onSelected: (_) {
                              setState(() => _sort = _sorts[i].$1);
                              _browse();
                            },
                          );
                        },
                      ),
                    ),
                  ] else
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(children: [
                        const Icon(Icons.search, size: 16),
                        const SizedBox(width: 6),
                        Text('“$_query” 的搜索结果',
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        const Spacer(),
                        TextButton(
                          onPressed: () {
                            _searchCtrl.clear();
                            _browse();
                          },
                          child: const Text('清除'),
                        ),
                      ]),
                    ),
                ],
              ),
            ),
          ),
          if (_error != null)
            SliverFillRemaining(child: ZxError(message: _error!, onRetry: _browse))
          else if (_results.isEmpty && !_searching)
            const SliverFillRemaining(
              child: ZxEmpty(icon: Icons.search_off, message: '没有找到相关视频'),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
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
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      mainAxisSpacing: 18,
                      crossAxisSpacing: 14,
                      childAspectRatio: .78,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, i) =>
                          ZxVideoCard(video: _results[i], onTap: () => openVideo(context, _results[i])),
                      childCount: _results.length,
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
          if (!_hasMore && _results.isNotEmpty && !_searching)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text('已经到底了',
                      style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
