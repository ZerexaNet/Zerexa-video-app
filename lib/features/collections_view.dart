/// Collections ("合集") list, detail manager and editor.
///
/// Three public widgets:
///  - [CollectionsView]        : pull-to-refresh collection feed.
///  - [CollectionDetailScreen] : videos grid plus owner-side management
///    (add / remove videos, edit, delete).
///  - [CollectionEditorScreen] : create or update a collection.
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../stores/app_stores.dart';
import '../widgets/common.dart';
import 'app_shell.dart';

class CollectionsView extends StatefulWidget {
  const CollectionsView({super.key});

  @override
  State<CollectionsView> createState() => _CollectionsViewState();
}

class _CollectionsViewState extends State<CollectionsView> {
  List<CollectionItem> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = context.read<AuthStore>().api;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await api.listCollections(limit: 50);
      if (!mounted) return;
      setState(() {
        _items = items;
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
        _error = '加载失败，请稍后重试';
        _loading = false;
      });
    }
  }

  Future<void> _create() async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const CollectionEditorScreen(),
    ));
    if (mounted) _load();
  }

  Future<void> _openDetail(CollectionItem item) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CollectionDetailScreen(collectionId: item.id),
    ));
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthStore>();
    return Scaffold(
      appBar: AppBar(title: const Text('合集')),
      floatingActionButton: auth.isAuthed
          ? FloatingActionButton.extended(
              onPressed: _create,
              icon: const Icon(Icons.create_new_folder_outlined),
              label: const Text('新建合集'),
            )
          : null,
      body: _loading
          ? const ZxLoadingGrid()
          : RefreshIndicator(
              onRefresh: _load,
              child: _buildList(),
            ),
    );
  }

  Widget _buildList() {
    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 160),
          ZxError(message: _error!, onRetry: _load),
        ],
      );
    }
    if (_items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 160),
          ZxEmpty(
              icon: Icons.collections_bookmark_outlined,
              message: '还没有合集，新建一个来整理视频吧'),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      itemCount: _items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, i) => _CollectionCard(
        collection: _items[i],
        onTap: () => _openDetail(_items[i]),
      ),
    );
  }
}

/// Collection card: title, description snippet, author and stats.
class _CollectionCard extends StatelessWidget {
  const _CollectionCard({required this.collection, this.onTap});

  final CollectionItem collection;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final description = collection.description;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.collections_bookmark_outlined,
                      size: 20, color: scheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      collection.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 15.5, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              if (description != null && description.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 12.5,
                      color: scheme.onSurfaceVariant,
                      height: 1.45),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ZxAuthor(
                      username: collection.authorUsername,
                      uid: collection.authorUid,
                    ),
                  ),
                  Text('${formatCount(collection.videoCount)} 个视频',
                      style: TextStyle(
                          fontSize: 12, color: scheme.onSurfaceVariant)),
                  const SizedBox(width: 10),
                  Text(formatRelative(collection.createdAt),
                      style: TextStyle(
                          fontSize: 12, color: scheme.onSurfaceVariant)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CollectionDetailScreen extends StatefulWidget {
  const CollectionDetailScreen({super.key, required this.collectionId});

  final String collectionId;

  @override
  State<CollectionDetailScreen> createState() =>
      _CollectionDetailScreenState();
}

class _CollectionDetailScreenState extends State<CollectionDetailScreen> {
  final _videoIdCtrl = TextEditingController();
  CollectionItem? _collection;
  bool _loading = true;
  String? _error;
  bool _adding = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _videoIdCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final api = context.read<AuthStore>().api;
    // Only show the full-screen loader on first load; later refreshes keep
    // the current content visible.
    setState(() {
      _loading = _collection == null;
      _error = null;
    });
    try {
      final collection = await api.getCollection(widget.collectionId);
      if (!mounted) return;
      setState(() {
        _collection = collection;
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
        _error = '加载失败，请稍后重试';
        _loading = false;
      });
    }
  }

  Future<void> _edit() async {
    final collection = _collection;
    if (collection == null) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CollectionEditorScreen(
          collectionId: collection.id, initial: collection),
    ));
    if (mounted) _load();
  }

  Future<void> _delete() async {
    final collection = _collection;
    if (collection == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除合集'),
        content: const Text('确定要删除这个合集吗？合集内的视频不会被删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await context.read<AuthStore>().api.deleteCollection(collection.id);
      if (!mounted) return;
      zxToast(context, '已删除合集');
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) zxToast(context, e.message);
    } catch (_) {
      if (mounted) zxToast(context, '删除失败，请稍后重试');
    }
  }

  Future<void> _addVideo() async {
    final collection = _collection;
    if (collection == null || _adding) return;
    final videoId = _videoIdCtrl.text.trim();
    if (videoId.isEmpty) {
      zxToast(context, '请输入视频 ID');
      return;
    }
    setState(() => _adding = true);
    try {
      await context
          .read<AuthStore>()
          .api
          .addVideoToCollection(collection.id, videoId);
      if (!mounted) return;
      _videoIdCtrl.clear();
      zxToast(context, '已添加到合集');
      await _load();
    } on ApiException catch (e) {
      if (mounted) zxToast(context, e.message);
    } catch (_) {
      if (mounted) zxToast(context, '添加失败，请稍后重试');
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _removeVideo(VideoItem video) async {
    final collection = _collection;
    if (collection == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('移出视频'),
        content: Text('确定要将「${video.title}」移出合集吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('移出'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await context
          .read<AuthStore>()
          .api
          .removeVideoFromCollection(collection.id, video.id);
      if (!mounted) return;
      zxToast(context, '已移出合集');
      await _load();
    } on ApiException catch (e) {
      if (mounted) zxToast(context, e.message);
    } catch (_) {
      if (mounted) zxToast(context, '移出失败，请稍后重试');
    }
  }

  @override
  Widget build(BuildContext context) {
    final myUid = context.watch<AuthStore>().user?.uid;
    final collection = _collection;
    final isOwner =
        collection != null && myUid != null && myUid == collection.authorUid;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          collection?.title ?? '合集详情',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (isOwner) ...[
            IconButton(
              tooltip: '编辑合集',
              icon: const Icon(Icons.edit_outlined),
              onPressed: _edit,
            ),
            IconButton(
              tooltip: '删除合集',
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
          ],
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ZxError(message: _error!, onRetry: _load)
              : collection == null
                  ? const ZxEmpty(
                      icon: Icons.collections_bookmark_outlined,
                      message: '合集不存在或已被删除')
                  : _buildBody(context, collection, isOwner),
    );
  }

  Widget _buildBody(
      BuildContext context, CollectionItem collection, bool isOwner) {
    final scheme = Theme.of(context).colorScheme;
    final cover =
        context.read<AuthStore>().api.resolveAsset(collection.coverUrl);
    final description = collection.description;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header + owner management panel, capped at 55% of the screen so
        // the video grid below always keeps a usable share of the space.
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .55,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (cover.isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: double.infinity,
                      height: 150,
                      child: CachedNetworkImage(
                        imageUrl: cover,
                        fit: BoxFit.cover,
                        placeholder: (_, _) =>
                            Container(color: scheme.surfaceContainerHighest),
                        errorWidget: (_, _, _) => Container(
                          color: scheme.surfaceContainerHighest,
                          child: Icon(Icons.collections_bookmark_outlined,
                              size: 40, color: scheme.onSurfaceVariant),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Text(
                  description == null || description.isEmpty
                      ? '这个合集还没有简介。'
                      : description,
                  style: const TextStyle(fontSize: 14, height: 1.6),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ZxAuthor(
                        username: collection.authorUsername,
                        uid: collection.authorUid,
                      ),
                    ),
                    Text(formatRelative(collection.createdAt),
                        style: TextStyle(
                            fontSize: 12, color: scheme.onSurfaceVariant)),
                  ],
                ),
                const Divider(height: 24),
                if (isOwner) _ownerPanel(context, collection),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: Row(
            children: [
              const Expanded(
                child: Text('合集视频',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
              Text('${formatCount(collection.videos.length)} 个',
                  style: TextStyle(
                      fontSize: 12.5, color: scheme.onSurfaceVariant)),
            ],
          ),
        ),
        Expanded(
          child: collection.videos.isEmpty
              ? const ZxEmpty(
                  icon: Icons.video_library_outlined, message: '合集中还没有视频')
              : ZxVideoGrid(
                  videos: collection.videos,
                  onOpen: (v) => openVideo(context, v),
                ),
        ),
      ],
    );
  }

  /// Owner-only panel: add a video by ID plus per-video remove rows.
  Widget _ownerPanel(BuildContext context, CollectionItem collection) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('添加视频',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _videoIdCtrl,
                enabled: !_adding,
                decoration: const InputDecoration(
                  labelText: '视频 ID',
                  hintText: '输入要添加的视频 ID',
                  isDense: true,
                  prefixIcon: Icon(Icons.link),
                ),
                onSubmitted: (_) => _addVideo(),
              ),
            ),
            const SizedBox(width: 10),
            FilledButton.icon(
              onPressed: _adding ? null : _addVideo,
              icon: _adding
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add),
              label: const Text('添加'),
            ),
          ],
        ),
        if (collection.videos.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text('管理视频',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          for (final video in collection.videos)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: Icon(Icons.movie_outlined, color: scheme.primary),
              title: Text(
                video.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                '${formatCount(video.views)} 播放 · '
                '${video.authorUsername.isEmpty ? '匿名' : video.authorUsername}',
                style: TextStyle(
                    fontSize: 12, color: scheme.onSurfaceVariant),
              ),
              trailing: IconButton(
                tooltip: '移出合集',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _removeVideo(video),
              ),
            ),
        ],
      ],
    );
  }
}

class CollectionEditorScreen extends StatefulWidget {
  const CollectionEditorScreen({super.key, this.collectionId, this.initial});

  final String? collectionId;
  final CollectionItem? initial;

  @override
  State<CollectionEditorScreen> createState() =>
      _CollectionEditorScreenState();
}

class _CollectionEditorScreenState extends State<CollectionEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _coverCtrl = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial != null) {
      _titleCtrl.text = initial.title;
      _descriptionCtrl.text = initial.description ?? '';
      _coverCtrl.text = initial.coverUrl ?? '';
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descriptionCtrl.dispose();
    _coverCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    final auth = context.read<AuthStore>();
    if (!auth.isAuthed) {
      zxToast(context, '请先登录后再操作');
      return;
    }
    setState(() => _busy = true);
    final body = <String, dynamic>{
      'title': _titleCtrl.text.trim(),
      if (_descriptionCtrl.text.trim().isNotEmpty)
        'description': _descriptionCtrl.text.trim(),
      if (_coverCtrl.text.trim().isNotEmpty)
        'cover_url': _coverCtrl.text.trim(),
    };
    final editing = widget.collectionId != null;
    try {
      if (editing) {
        await auth.api.updateCollection(widget.collectionId!, body);
      } else {
        await auth.api.createCollection(body);
      }
      if (!mounted) return;
      zxToast(context, editing ? '已保存修改' : '创建成功');
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) zxToast(context, e.message);
    } catch (_) {
      if (mounted) zxToast(context, '提交失败，请稍后重试');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.collectionId != null;
    return Scaffold(
      appBar: AppBar(title: Text(editing ? '编辑合集' : '新建合集')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _titleCtrl,
                    enabled: !_busy,
                    decoration: const InputDecoration(
                      labelText: '合集标题',
                      prefixIcon: Icon(Icons.title),
                    ),
                    textInputAction: TextInputAction.next,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? '请输入合集标题' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _descriptionCtrl,
                    enabled: !_busy,
                    decoration: const InputDecoration(
                      labelText: '简介（可选）',
                      prefixIcon: Icon(Icons.notes),
                      alignLabelWithHint: true,
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _coverCtrl,
                    enabled: !_busy,
                    decoration: const InputDecoration(
                      labelText: '封面地址（可选）',
                      prefixIcon: Icon(Icons.image_outlined),
                    ),
                    keyboardType: TextInputType.url,
                  ),
                  const SizedBox(height: 22),
                  FilledButton.icon(
                    onPressed: _busy ? null : _submit,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check),
                    label: Text(editing ? '保存修改' : '创建合集'),
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
