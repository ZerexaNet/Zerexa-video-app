/// Watch screen: native video playback (media_kit) with danmaku overlay,
/// subtitle track switching, like / favourite / coin interactions and a
/// threaded comment section.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';

import '../core/api.dart';
import '../core/format.dart';
// Both media_kit and our models export `SubtitleTrack`; alias ours.
import '../core/models.dart' hide SubtitleTrack;
import '../core/models.dart' as models show SubtitleTrack;
import '../stores/app_stores.dart';
import '../widgets/common.dart';
import '../widgets/danmaku_overlay.dart';
import '../widgets/report_dialog.dart';
import 'user_page_view.dart';

class WatchView extends StatefulWidget {
  const WatchView({super.key, required this.videoId});

  final String videoId;

  @override
  State<WatchView> createState() => _WatchViewState();
}

class _WatchViewState extends State<WatchView> {
  late final Player _player;
  late final VideoController _controller;
  StreamSubscription<Duration>? _positionSub;
  final _positionNotifier = ValueNotifier<double>(0);

  VideoItem? _video;
  List<DanmakuItem> _danmaku = [];
  List<models.SubtitleTrack> _subtitles = [];
  models.SubtitleTrack? _activeSubtitle;
  bool _danmakuOn = true;
  final bool _fullscreenable = true;
  String? _error;
  bool _loading = true;

  bool _liked = false;
  bool _favorited = false;
  int _likes = 0;
  bool _actionBusy = false;

  List<CommentItem> _comments = [];
  bool _commentsLoading = true;
  String? _commentsError;
  int _commentOffset = 0;
  int _commentTotal = -1;
  final _commentCtrl = TextEditingController();
  CommentItem? _replyTo;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _controller = VideoController(
      _player,
      configuration: const VideoControllerConfiguration(
        enableHardwareAcceleration: true,
      ),
    );
    _positionSub = _player.stream.position.listen((d) {
      _positionNotifier.value = d.inMilliseconds / 1000.0;
    });
    _load();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _positionNotifier.dispose();
    _commentCtrl.dispose();
    _player.dispose();
    super.dispose();
  }

  ZerexaApi get _api => context.read<AuthStore>().api;
  AuthStore get _auth => context.read<AuthStore>();

  Future<void> _load() async {
    try {
      final video = await _api.getVideo(widget.videoId);
      final results = await Future.wait([
        _api.listDanmaku(widget.videoId).catchError((_) => <DanmakuItem>[]),
        _api.listSubtitles(widget.videoId).catchError((_) => <models.SubtitleTrack>[]),
      ]);
      if (!mounted) return;
      setState(() {
        _video = video;
        _danmaku = results[0] as List<DanmakuItem>;
        _subtitles = results[1] as List<models.SubtitleTrack>;
        _likes = video.likes;
        _loading = false;
      });

      final stream = _api.resolveAsset(video.streamUrl);
      if (stream.startsWith('http')) {
        await _player.open(Media(stream));
      }
      if (_auth.isAuthed) {
        _api.checkFavorite(video.id).then((v) {
          if (mounted) setState(() => _favorited = v);
        }).catchError((_) {});
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
          _error = '视频加载失败';
          _loading = false;
        });
      }
    }
    _loadComments();
  }

  Future<void> _loadComments() async {
    try {
      final data = await _api.listComments(widget.videoId, limit: 30);
      if (!mounted) return;
      setState(() {
        _comments = data;
        _commentOffset = data.length;
        _commentsLoading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _commentsError = '评论加载失败';
          _commentsLoading = false;
        });
      }
    }
  }

  Future<void> _loadMoreComments() async {
    if (_commentsLoading) return;
    setState(() => _commentsLoading = true);
    try {
      final more =
          await _api.listComments(widget.videoId, limit: 30, offset: _commentOffset);
      if (!mounted) return;
      setState(() {
        _comments.addAll(more);
        _commentOffset = _comments.length;
        if (more.length < 30) _commentTotal = _comments.length;
        _commentsLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _commentsLoading = false);
    }
  }

  Future<void> _submitComment() async {
    final content = _commentCtrl.text.trim();
    if (content.isEmpty) return;
    if (!_auth.isAuthed) {
      zxToast(context, '请先登录');
      return;
    }
    try {
      await _api.postComment(widget.videoId, content, parentId: _replyTo?.id);
      _commentCtrl.clear();
      setState(() => _replyTo = null);
      if (mounted) zxToast(context, '评论成功');
      await _loadComments();
    } on ApiException catch (e) {
      if (mounted) zxToast(context, e.message);
    } catch (_) {
      if (mounted) zxToast(context, '评论失败');
    }
  }

  Future<void> _toggleLike() async {
    if (_actionBusy || !_auth.isAuthed) {
      if (!_auth.isAuthed && mounted) zxToast(context, '请先登录');
      return;
    }
    setState(() => _actionBusy = true);
    try {
      await _api.likeVideo(widget.videoId);
      setState(() {
        _liked = !_liked;
        _likes += _liked ? 1 : -1;
      });
    } on ApiException catch (e) {
      if (mounted) zxToast(context, e.message);
    } catch (_) {
      if (mounted) zxToast(context, '操作失败');
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _toggleFavorite() async {
    if (_actionBusy || !_auth.isAuthed) {
      if (!_auth.isAuthed && mounted) zxToast(context, '请先登录');
      return;
    }
    setState(() => _actionBusy = true);
    try {
      if (_favorited) {
        await _api.unfavoriteVideo(widget.videoId);
      } else {
        await _api.favoriteVideo(widget.videoId);
      }
      setState(() => _favorited = !_favorited);
      if (mounted) {
        zxToast(context, _favorited ? '已加入收藏' : '已取消收藏');
      }
    } on ApiException catch (e) {
      if (mounted) zxToast(context, e.message);
    } catch (_) {
      if (mounted) zxToast(context, '操作失败');
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _coin() async {
    if (_actionBusy || !_auth.isAuthed) {
      if (!_auth.isAuthed && mounted) zxToast(context, '请先登录');
      return;
    }
    final amount = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('投币'),
        children: [
          for (final n in const [1, 2, 5])
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(n),
              child: Text('投 $n 枚硬币'),
            ),
        ],
      ),
    );
    if (amount == null) return;
    setState(() => _actionBusy = true);
    try {
      await _api.coinVideo(widget.videoId, amount: amount);
      if (mounted) zxToast(context, '已投 $amount 枚硬币');
    } on ApiException catch (e) {
      if (mounted) zxToast(context, e.message);
    } catch (_) {
      if (mounted) zxToast(context, '投币失败');
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _pickSubtitle() async {
    if (_subtitles.isEmpty) {
      zxToast(context, '该视频没有可用字幕');
      return;
    }
    final picked = await showModalBottomSheet<models.SubtitleTrack>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('选择字幕', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
            ListTile(
              leading: const Icon(Icons.subtitles_off_outlined),
              title: const Text('关闭字幕'),
              selected: _activeSubtitle == null,
              onTap: () => Navigator.of(context).pop(null),
            ),
            for (final s in _subtitles)
              ListTile(
                leading: const Icon(Icons.subtitles_outlined),
                title: Text(s.label.isEmpty ? s.language : s.label),
                subtitle: Text('${s.language} · ${s.format.toUpperCase()}'),
                selected: _activeSubtitle?.id == s.id,
                onTap: () => Navigator.of(context).pop(s),
              ),
          ],
        ),
      ),
    );
    if (picked == null && _activeSubtitle == null) return;
    if (picked == null) {
      await _player.setSubtitleTrack(SubtitleTrack.no());
      setState(() => _activeSubtitle = null);
      return;
    }
    final url = _api.resolveAsset(picked.url);
    await _player.setSubtitleTrack(SubtitleTrack.uri(url, title: picked.label, language: picked.language));
    setState(() => _activeSubtitle = picked);
    if (mounted) zxToast(context, '字幕已切换');
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _video?.title ?? '视频',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          if (_video != null)
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'report') {
                  showReportDialog(context,
                      targetType: 'video',
                      targetId: _video!.id,
                      targetUid: _video!.authorUid,
                      targetTitle: _video!.title);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                    value: 'report',
                    child: ListTile(
                        dense: true,
                        leading: Icon(Icons.flag_outlined),
                        title: Text('举报视频'))),
              ],
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ZxError(message: _error!, onRetry: _load)
              : wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: _playerColumn()),
                        SizedBox(
                          width: 380,
                          child: _commentsPanel(),
                        ),
                      ],
                    )
                  : SingleChildScrollView(child: _playerColumn()),
    );
  }

  Widget _playerColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _videoArea(),
        _infoSection(),
        const Divider(height: 1),
        if (MediaQuery.sizeOf(context).width < 1000)
          Padding(
            padding: const EdgeInsets.all(16),
            child: _commentsPanel(),
          ),
      ],
    );
  }

  Widget _videoArea() {
    final stream = _video == null ? '' : _api.resolveAsset(_video!.streamUrl);
    return Stack(
      alignment: Alignment.center,
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: stream.startsWith('http')
              ? Video(controller: _controller)
              : Container(
                  color: Colors.black,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.videocam_off_outlined,
                            size: 48, color: Colors.white.withValues(alpha: .7)),
                        const SizedBox(height: 12),
                        Text(
                          '暂无可播放的视频流',
                          style: TextStyle(color: Colors.white.withValues(alpha: .8)),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
        // Danmaku + controls floating above the video.
        Positioned.fill(
          child: DanmakuOverlay(
            items: _danmaku,
            position: _positionNotifier,
            enabled: _danmakuOn && stream.startsWith('http'),
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: Row(children: [
            _overlayButton(
              icon: _danmakuOn ? Icons.comment_bank_rounded : Icons.comments_disabled_outlined,
              label: '弹幕',
              active: _danmakuOn,
              onTap: () => setState(() => _danmakuOn = !_danmakuOn),
            ),
            const SizedBox(width: 6),
            _overlayButton(
              icon: Icons.subtitles_outlined,
              label: '字幕',
              active: _activeSubtitle != null,
              onTap: _pickSubtitle,
            ),
          ]),
        ),
        if (!_fullscreenable) const SizedBox.shrink(),
      ],
    );
  }

  Widget _overlayButton({
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return Material(
      color: active ? Colors.black54 : Colors.black38,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 15, color: active ? Colors.white : Colors.white70),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 11)),
          ]),
        ),
      ),
    );
  }

  Widget _infoSection() {
    final v = _video!;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            v.title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${formatCount(v.views)} 次观看 · ${formatRelative(v.createdAt)}'
            '${v.category.isEmpty ? '' : ' · ${v.category}'}'
            '${v.ipLocation == null || v.ipLocation!.isEmpty ? '' : ' · IP属地 ${v.ipLocation}'}',
            style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: ZxAuthor(
                username: v.authorUsername,
                uid: v.authorUid,
                gravatar: v.authorGravatarUrl,
                badge: v.authorVerificationBadge,
                badgeLabel: v.authorVerificationLabel,
                size: 40,
                onTap: () => _openAuthor(),
              ),
            ),
            if (_auth.isAuthed && _auth.user?.uid == v.authorUid) ...[
              IconButton(
                tooltip: '举报',
                icon: const Icon(Icons.flag_outlined, size: 20),
                onPressed: () => showReportDialog(context,
                    targetType: 'user',
                    targetUid: v.authorUid,
                    targetTitle: v.authorUsername),
              ),
            ] else ...[
              IconButton(
                tooltip: '私信',
                icon: const Icon(Icons.chat_bubble_outline, size: 20),
                onPressed: _auth.isAuthed ? () => _openAuthor(chat: true) : null,
              ),
            ],
          ]),
          if (v.description != null && v.description!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              v.description!,
              style: const TextStyle(fontSize: 13.5, height: 1.6),
            ),
          ],
          const SizedBox(height: 16),
          Row(children: [
            _actionChip(
              icon: _liked ? Icons.thumb_up_rounded : Icons.thumb_up_outlined,
              label: formatCount(_likes),
              active: _liked,
              onTap: _toggleLike,
            ),
            const SizedBox(width: 10),
            _actionChip(
              icon: _favorited ? Icons.star_rounded : Icons.star_outline_rounded,
              label: _favorited ? '已收藏' : '收藏',
              active: _favorited,
              onTap: _toggleFavorite,
            ),
            const SizedBox(width: 10),
            _actionChip(
              icon: Icons.paid_outlined,
              label: '投币',
              onTap: _coin,
            ),
            const SizedBox(width: 10),
            _actionChip(
              icon: Icons.flag_outlined,
              label: '举报',
              onTap: () => showReportDialog(context,
                  targetType: 'video',
                  targetId: v.id,
                  targetUid: v.authorUid,
                  targetTitle: v.title),
            ),
          ]),
        ],
      ),
    );
  }

  void _openAuthor({bool chat = false}) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => UserPageView(uid: _video!.authorUid, startChat: chat),
    ));
  }

  Widget _actionChip({
    required IconData icon,
    required String label,
    bool active = false,
    VoidCallback? onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return ActionChip(
      avatar: Icon(icon, size: 17, color: active ? scheme.primary : scheme.onSurfaceVariant),
      label: Text(label),
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  Widget _commentsPanel() {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            '评论 ${_comments.isEmpty ? '' : '· ${_comments.length}'}',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
        ),
        if (_auth.isAuthed) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _commentCtrl,
                  maxLines: null,
                  decoration: InputDecoration(
                    hintText: _replyTo == null
                        ? '发一条友善的评论'
                        : '回复 @${_replyTo!.authorUsername}',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                icon: const Icon(Icons.send_rounded, size: 18),
                onPressed: _submitComment,
              ),
            ]),
          ),
          if (_replyTo != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: Row(children: [
                Expanded(
                  child: Text(
                    '回复 ${_replyTo!.authorUsername}：${_replyTo!.content}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _replyTo = null),
                  child: const Icon(Icons.close, size: 15),
                ),
              ]),
            ),
        ] else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '登录后即可参与评论',
              style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
            ),
          ),
        const SizedBox(height: 8),
        if (_commentsLoading && _comments.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
          )
        else if (_commentsError != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: ZxError(message: _commentsError!, onRetry: _loadComments),
          )
        else if (_comments.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: ZxEmpty(icon: Icons.chat_bubble_outline, message: '还没有评论，来抢沙发'),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _comments.length + (_commentTotal == _comments.length ? 0 : 1),
            separatorBuilder: (_, _) => const SizedBox(height: 4),
            itemBuilder: (context, i) {
              if (i >= _comments.length) {
                return Padding(
                  padding: const EdgeInsets.all(12),
                  child: Center(
                    child: TextButton(
                      onPressed: _loadMoreComments,
                      child: const Text('加载更多评论'),
                    ),
                  ),
                );
              }
              return _commentTile(_comments[i], topLevel: true);
            },
          ),
      ],
    );
  }

  Widget _commentTile(CommentItem c, {bool topLevel = false}) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, topLevel ? 10 : 0, 16, topLevel ? 10 : 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: ZxAuthor(
              username: c.authorUsername,
              uid: c.authorUid,
              gravatar: c.authorGravatarUrl,
              badge: c.authorVerificationBadge,
              badgeLabel: c.authorVerificationLabel,
              size: 32,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => UserPageView(uid: c.authorUid),
              )),
            ),
          ),
          Text(
            formatRelative(c.createdAt),
            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
          ),
        ]),
        Padding(
          padding: const EdgeInsets.only(left: 42, top: 6),
          child: Text(c.content, style: const TextStyle(fontSize: 13.5, height: 1.5)),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 42),
          child: Row(children: [
            TextButton.icon(
              onPressed: _auth.isAuthed
                  ? () => setState(() => _replyTo = c)
                  : () => zxToast(context, '请先登录'),
              icon: const Icon(Icons.reply, size: 14),
              label: Text(
                c.replies.isEmpty ? '回复' : '回复 (${c.replies.length})',
                style: const TextStyle(fontSize: 12),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ]),
        ),
        for (final r in c.replies)
          Container(
            margin: const EdgeInsets.only(left: 42),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: .5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: _commentTile(r),
          ),
      ]),
    );
  }
}
