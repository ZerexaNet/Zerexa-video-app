/// Articles ("专栏") feed, detail reader and editor.
///
/// Three public widgets:
///  - [ArticlesView]        : pull-to-refresh article list.
///  - [ArticleDetailScreen] : full reader with like / edit / delete actions.
///  - [ArticleEditorScreen] : create or update an article.
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../stores/app_stores.dart';
import '../widgets/common.dart';

class ArticlesView extends StatefulWidget {
  const ArticlesView({super.key});

  @override
  State<ArticlesView> createState() => _ArticlesViewState();
}

class _ArticlesViewState extends State<ArticlesView> {
  List<ArticleItem> _items = [];
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
      final items = await api.listArticles(limit: 50);
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

  Future<void> _openEditor() async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const ArticleEditorScreen(),
    ));
    if (mounted) _load();
  }

  Future<void> _openDetail(ArticleItem article) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ArticleDetailScreen(articleId: article.id),
    ));
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthStore>();
    return Scaffold(
      appBar: AppBar(title: const Text('专栏')),
      floatingActionButton: auth.isAuthed
          ? FloatingActionButton.extended(
              onPressed: _openEditor,
              icon: const Icon(Icons.edit_note),
              label: const Text('写专栏'),
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
          ZxEmpty(icon: Icons.article_outlined, message: '还没有专栏文章，快来发布第一篇吧'),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      itemCount: _items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, i) => _ArticleCard(
        article: _items[i],
        onTap: () => _openDetail(_items[i]),
      ),
    );
  }
}

/// Compact article card: optional cover thumbnail, title, summary and
/// author / stats meta rows.
class _ArticleCard extends StatelessWidget {
  const _ArticleCard({required this.article, this.onTap});

  final ArticleItem article;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final api = context.read<AuthStore>().api;
    final cover = api.resolveAsset(article.coverUrl);
    final summary = article.summary;

    Widget thumbnail;
    if (cover.isNotEmpty) {
      thumbnail = ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 128,
          height: 82,
          child: CachedNetworkImage(
            imageUrl: cover,
            fit: BoxFit.cover,
            placeholder: (_, _) =>
                Container(color: scheme.surfaceContainerHighest),
            errorWidget: (_, _, _) => Container(
              color: scheme.surfaceContainerHighest,
              child: Icon(Icons.article_outlined, color: scheme.onSurfaceVariant),
            ),
          ),
        ),
      );
    } else {
      thumbnail = Container(
        width: 128,
        height: 82,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.article_outlined, color: scheme.onSurfaceVariant),
      );
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              thumbnail,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      article.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                    ),
                    if (summary != null && summary.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        summary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: scheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    ZxAuthor(
                      username: article.authorUsername,
                      uid: article.authorUid,
                      gravatar: article.authorGravatarUrl,
                      badge: article.authorVerificationBadge,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.visibility_outlined,
                            size: 13, color: scheme.onSurfaceVariant),
                        const SizedBox(width: 3),
                        Text(formatCount(article.views),
                            style: TextStyle(
                                fontSize: 11.5,
                                color: scheme.onSurfaceVariant)),
                        const SizedBox(width: 10),
                        Icon(Icons.favorite_outline,
                            size: 13, color: scheme.onSurfaceVariant),
                        const SizedBox(width: 3),
                        Text(formatCount(article.likes),
                            style: TextStyle(
                                fontSize: 11.5,
                                color: scheme.onSurfaceVariant)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            formatRelative(article.createdAt),
                            textAlign: TextAlign.right,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 11.5,
                                color: scheme.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ArticleDetailScreen extends StatefulWidget {
  const ArticleDetailScreen({super.key, required this.articleId});

  final String articleId;

  @override
  State<ArticleDetailScreen> createState() => _ArticleDetailScreenState();
}

class _ArticleDetailScreenState extends State<ArticleDetailScreen> {
  ArticleItem? _article;
  bool _loading = true;
  String? _error;
  bool _liked = false;
  int _likes = 0;
  bool _likeBusy = false;

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
      final article = await api.getArticle(widget.articleId);
      if (!mounted) return;
      setState(() {
        _article = article;
        _liked = article.liked;
        _likes = article.likes;
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

  Future<void> _toggleLike() async {
    final article = _article;
    if (article == null || _likeBusy) return;
    final auth = context.read<AuthStore>();
    if (!auth.isAuthed) {
      zxToast(context, '请先登录后再点赞');
      return;
    }
    if (_liked) {
      zxToast(context, '已经点过赞了');
      return;
    }
    setState(() => _likeBusy = true);
    try {
      await auth.api.likeArticle(article.id);
      if (!mounted) return;
      setState(() {
        _liked = true;
        _likes += 1;
      });
    } on ApiException catch (e) {
      if (mounted) zxToast(context, e.message);
    } catch (_) {
      if (mounted) zxToast(context, '点赞失败，请稍后重试');
    } finally {
      if (mounted) setState(() => _likeBusy = false);
    }
  }

  Future<void> _edit() async {
    final article = _article;
    if (article == null) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ArticleEditorScreen(articleId: article.id, initial: article),
    ));
    if (mounted) _load();
  }

  Future<void> _delete() async {
    final article = _article;
    if (article == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除专栏'),
        content: const Text('确定要删除这篇专栏文章吗？删除后无法恢复。'),
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
      await context.read<AuthStore>().api.deleteArticle(article.id);
      if (!mounted) return;
      zxToast(context, '已删除');
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) zxToast(context, e.message);
    } catch (_) {
      if (mounted) zxToast(context, '删除失败，请稍后重试');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final myUid = context.watch<AuthStore>().user?.uid;
    final article = _article;
    final isOwner =
        article != null && myUid != null && myUid == article.authorUid;
    final ready = !_loading && _error == null && article != null;

    return Scaffold(
      appBar: AppBar(title: const Text('专栏详情')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ZxError(message: _error!, onRetry: _load)
              : article == null
                  ? const ZxEmpty(
                      icon: Icons.article_outlined, message: '专栏不存在或已被删除')
                  : _buildContent(context, article),
      bottomNavigationBar: !ready
          ? null
          : BottomAppBar(
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: _likeBusy ? null : _toggleLike,
                    icon: Icon(
                      _liked ? Icons.favorite : Icons.favorite_border,
                      color: _liked ? scheme.error : scheme.onSurfaceVariant,
                    ),
                    label: Text(formatCount(_likes)),
                  ),
                  const Spacer(),
                  if (isOwner) ...[
                    IconButton(
                      tooltip: '编辑',
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: _edit,
                    ),
                    IconButton(
                      tooltip: '删除',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: _delete,
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildContent(BuildContext context, ArticleItem article) {
    final scheme = Theme.of(context).colorScheme;
    final paragraphs = article.content
        .split(RegExp(r'\n+'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            article.title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          ZxAuthor(
            username: article.authorUsername,
            uid: article.authorUid,
            gravatar: article.authorGravatarUrl,
            badge: article.authorVerificationBadge,
            size: 24,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.schedule, size: 14, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(formatDate(article.createdAt),
                      style: TextStyle(
                          fontSize: 12.5, color: scheme.onSurfaceVariant)),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.visibility_outlined,
                      size: 14, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text('${formatCount(article.views)} 观看',
                      style: TextStyle(
                          fontSize: 12.5, color: scheme.onSurfaceVariant)),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.favorite_outline,
                      size: 14, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text('${formatCount(article.likes)} 点赞',
                      style: TextStyle(
                          fontSize: 12.5, color: scheme.onSurfaceVariant)),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.chat_bubble_outline,
                      size: 14, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text('${formatCount(article.comments)} 评论',
                      style: TextStyle(
                          fontSize: 12.5, color: scheme.onSurfaceVariant)),
                ],
              ),
            ],
          ),
          const Divider(height: 28),
          if (paragraphs.isEmpty)
            const ZxEmpty(
                icon: Icons.article_outlined, message: '这篇专栏还没有正文内容')
          else
            ...paragraphs.map(
              (p) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Text(
                  p,
                  style: const TextStyle(fontSize: 15, height: 1.8),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class ArticleEditorScreen extends StatefulWidget {
  const ArticleEditorScreen({super.key, this.articleId, this.initial});

  final String? articleId;
  final ArticleItem? initial;

  @override
  State<ArticleEditorScreen> createState() => _ArticleEditorScreenState();
}

class _ArticleEditorScreenState extends State<ArticleEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  final _summaryCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial != null) {
      _titleCtrl.text = initial.title;
      _categoryCtrl.text = initial.category ?? '';
      _summaryCtrl.text = initial.summary ?? '';
      _contentCtrl.text = initial.content;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _categoryCtrl.dispose();
    _summaryCtrl.dispose();
    _contentCtrl.dispose();
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
      'content': _contentCtrl.text.trim(),
      if (_categoryCtrl.text.trim().isNotEmpty)
        'category': _categoryCtrl.text.trim(),
      if (_summaryCtrl.text.trim().isNotEmpty)
        'summary': _summaryCtrl.text.trim(),
      'status': 'published',
    };
    final editing = widget.articleId != null;
    try {
      if (editing) {
        await auth.api.updateArticle(widget.articleId!, body);
      } else {
        await auth.api.createArticle(body);
      }
      if (!mounted) return;
      zxToast(context, editing ? '已保存修改' : '发布成功');
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
    final editing = widget.articleId != null;
    return Scaffold(
      appBar: AppBar(title: Text(editing ? '编辑专栏' : '写专栏')),
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
                      labelText: '标题',
                      prefixIcon: Icon(Icons.title),
                    ),
                    textInputAction: TextInputAction.next,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? '请输入专栏标题' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _categoryCtrl,
                    enabled: !_busy,
                    decoration: const InputDecoration(
                      labelText: '分类（可选）',
                      prefixIcon: Icon(Icons.category_outlined),
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _summaryCtrl,
                    enabled: !_busy,
                    decoration: const InputDecoration(
                      labelText: '摘要（可选）',
                      prefixIcon: Icon(Icons.notes),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _contentCtrl,
                    enabled: !_busy,
                    decoration: const InputDecoration(
                      labelText: '正文',
                      hintText: '输入专栏正文，空行分段',
                      alignLabelWithHint: true,
                    ),
                    maxLines: 12,
                    minLines: 8,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? '请输入正文内容' : null,
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
                        : const Icon(Icons.send_outlined),
                    label: Text(editing ? '保存修改' : '发布专栏'),
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
