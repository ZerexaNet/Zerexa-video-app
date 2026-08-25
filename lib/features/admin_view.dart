/// 管理后台: admin-only console with overview stats plus management tabs
/// for users, videos, reports and announcements.
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../stores/app_stores.dart';
import '../widgets/common.dart';

class AdminConsole extends StatefulWidget {
  const AdminConsole({super.key});

  @override
  State<AdminConsole> createState() => _AdminConsoleState();
}

class _AdminConsoleState extends State<AdminConsole> {
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthStore>();
    if (auth.initializing) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!auth.isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('管理后台')),
        body: const ZxEmpty(icon: Icons.lock_outline, message: '需要管理员权限'),
      );
    }
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('管理后台'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '概览'),
              Tab(text: '用户'),
              Tab(text: '视频'),
              Tab(text: '举报'),
              Tab(text: '公告'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _OverviewTab(),
            _UsersTab(),
            _VideosTab(),
            _ReportsTab(),
            _AnnouncementsTab(),
          ],
        ),
      ),
    );
  }
}

// ---------------- 概览 ----------------

class _OverviewTab extends StatefulWidget {
  const _OverviewTab();

  @override
  State<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<_OverviewTab> {
  List<AdminUser> _users = [];
  List<VideoItem> _videos = [];
  List<AdminReport> _reports = [];
  List<Announcement> _announcements = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ZxError(message: _error!, onRetry: _load);
    }
    final auth = context.watch<AuthStore>();
    final openReports = _reports
        .where((r) => r.status == 'open' || r.status == 'pending')
        .length;
    final activeAnnouncements = _announcements.where((a) => a.isActive).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
          child: Text(
            '欢迎回来，${auth.user?.username ?? '管理员'}',
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Text(
            '以下是站点当前的整体概况',
            style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final columns =
                  (constraints.maxWidth / 220).ceil().clamp(1, 4).toInt();
              return RefreshIndicator(
                onRefresh: _load,
                child: GridView.count(
                  crossAxisCount: columns,
                  childAspectRatio: 2.2,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    _statCard(context,
                        icon: Icons.people_outline,
                        label: '注册用户',
                        value: _users.length),
                    _statCard(context,
                        icon: Icons.video_library_outlined,
                        label: '视频总数',
                        value: _videos.length),
                    _statCard(context,
                        icon: Icons.report_outlined,
                        label: '待处理举报',
                        value: openReports),
                    _statCard(context,
                        icon: Icons.campaign_outlined,
                        label: '启用中公告',
                        value: activeAnnouncements),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _statCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required int value,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 22, color: scheme.primary),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  formatCount(value),
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                      fontSize: 12, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ],
        ),
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
      final results = await Future.wait([
        api.adminListUsers(limit: 100),
        api.adminListVideos(),
        api.adminListReports(),
        api.adminListAnnouncements(),
      ]);
      if (!mounted) return;
      setState(() {
        _users = results[0] as List<AdminUser>;
        _videos = results[1] as List<VideoItem>;
        _reports = results[2] as List<AdminReport>;
        _announcements = results[3] as List<Announcement>;
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
        _error = '数据加载失败，请稍后重试';
        _loading = false;
      });
    }
  }
}

// ---------------- 用户 ----------------

class _UsersTab extends StatefulWidget {
  const _UsersTab();

  @override
  State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab> {
  final _queryCtrl = TextEditingController();
  List<AdminUser> _users = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _queryCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: TextField(
            controller: _queryCtrl,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: '搜索用户名',
              prefixIcon: Icon(Icons.search),
              isDense: true,
            ),
          ),
        ),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ZxError(message: _error!, onRetry: _load);
    }
    final query = _queryCtrl.text.trim().toLowerCase();
    final users = query.isEmpty
        ? _users
        : _users
            .where((u) => u.username.toLowerCase().contains(query))
            .toList();
    if (users.isEmpty) {
      return ZxEmpty(
        icon: Icons.people_outline,
        message: query.isEmpty ? '暂无用户' : '未找到匹配的用户',
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: users.length,
        separatorBuilder: (_, _) =>
            const Divider(height: 1, indent: 78, endIndent: 16),
        itemBuilder: (context, i) => _userTile(context, users[i]),
      ),
    );
  }

  Widget _userTile(BuildContext context, AdminUser u) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: ZxAvatar(name: u.username, size: 46),
      title: Row(
        children: [
          Expanded(
            child: Text(
              u.username,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 6),
          _roleTag(context, u.role),
          if (u.banned) ...[
            const SizedBox(width: 6),
            _tag(scheme.error, '已封禁'),
          ],
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Text(
          _userSubtitle(u),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
        ),
      ),
      trailing: PopupMenuButton<String>(
        tooltip: '管理用户',
        icon: const Icon(Icons.more_vert, size: 20),
        onSelected: (v) {
          if (v == 'ban') {
            _banUser(u);
          } else if (v == 'unban') {
            _unbanUser(u);
          } else if (v == 'setAdmin') {
            _setRole(u, 'admin');
          } else if (v == 'setMember') {
            _setRole(u, 'member');
          }
        },
        itemBuilder: (_) => [
          if (u.banned)
            const PopupMenuItem(
              value: 'unban',
              child: ListTile(
                dense: true,
                leading: Icon(Icons.lock_open_rounded),
                title: Text('解封'),
              ),
            )
          else
            const PopupMenuItem(
              value: 'ban',
              child: ListTile(
                dense: true,
                leading: Icon(Icons.block_outlined),
                title: Text('封禁'),
              ),
            ),
          const PopupMenuItem(
            value: 'setAdmin',
            child: ListTile(
              dense: true,
              leading: Icon(Icons.admin_panel_settings_outlined),
              title: Text('设为管理员'),
            ),
          ),
          const PopupMenuItem(
            value: 'setMember',
            child: ListTile(
              dense: true,
              leading: Icon(Icons.person_outline),
              title: Text('设为普通用户'),
            ),
          ),
        ],
      ),
    );
  }

  String _userSubtitle(AdminUser u) {
    final bits = <String>[
      if (u.email != null && u.email!.isNotEmpty) u.email!,
      if (u.points != null) '${u.points} 积分',
      if (u.ipLocation != null && u.ipLocation!.isNotEmpty)
        'IP属地 ${u.ipLocation}',
      formatRelative(u.createdAt),
    ];
    return bits.join(' · ');
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<AuthStore>().api;
      final users = await api.adminListUsers(limit: 100);
      if (!mounted) return;
      setState(() {
        _users = users;
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
        _error = '用户列表加载失败，请稍后重试';
        _loading = false;
      });
    }
  }

  Future<void> _banUser(AdminUser u) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _BanDialog(uid: u.uid, username: u.username),
    );
    if (ok == true && mounted) {
      zxToast(context, '已封禁 ${u.username}');
      _load();
    }
  }

  Future<void> _unbanUser(AdminUser u) async {
    try {
      final api = context.read<AuthStore>().api;
      await api.adminUnbanUser(u.uid);
      if (!mounted) return;
      zxToast(context, '已解封 ${u.username}');
      _load();
    } on ApiException catch (e) {
      if (mounted) zxToast(context, e.message);
    } catch (_) {
      if (mounted) zxToast(context, '操作失败，请稍后重试');
    }
  }

  Future<void> _setRole(AdminUser u, String role) async {
    final toAdmin = role == 'admin';
    final ok = await _confirmDialog(
      context,
      title: toAdmin ? '设为管理员' : '设为普通用户',
      message: '确定将 ${u.username} ${toAdmin ? '设为管理员' : '设为普通用户'}吗？',
    );
    if (!ok || !mounted) return;
    try {
      final api = context.read<AuthStore>().api;
      await api.adminSetUserRole(u.uid, role);
      if (!mounted) return;
      zxToast(context, '已更新角色');
      _load();
    } on ApiException catch (e) {
      if (mounted) zxToast(context, e.message);
    } catch (_) {
      if (mounted) zxToast(context, '操作失败，请稍后重试');
    }
  }
}

// ---------------- 视频 ----------------

class _VideosTab extends StatefulWidget {
  const _VideosTab();

  @override
  State<_VideosTab> createState() => _VideosTabState();
}

class _VideosTabState extends State<_VideosTab> {
  List<VideoItem> _videos = [];
  String? _status;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Wrap(
            spacing: 8,
            children: [
              _statusChip('全部', null),
              _statusChip('待审核', 'pending'),
              _statusChip('已通过', 'approved'),
              _statusChip('已拒绝', 'rejected'),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _statusChip(String label, String? value) {
    return ChoiceChip(
      label: Text(label),
      selected: _status == value,
      onSelected: (_) => _changeStatus(value),
    );
  }

  void _changeStatus(String? value) {
    if (_status == value) return;
    setState(() => _status = value);
    _load();
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ZxError(message: _error!, onRetry: _load);
    }
    if (_videos.isEmpty) {
      return const ZxEmpty(
        icon: Icons.video_library_outlined,
        message: '暂无视频',
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: _videos.length,
        separatorBuilder: (_, _) =>
            const Divider(height: 1, indent: 108, endIndent: 16),
        itemBuilder: (context, i) => _videoTile(context, _videos[i]),
      ),
    );
  }

  Widget _videoTile(BuildContext context, VideoItem v) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: _videoThumb(context, v),
      onTap: () => _showVideoActions(v),
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              v.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 8),
          _tag(_videoStatusColor(v.status), _videoStatusLabel(v.status)),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Text(
          '${v.authorUsername} · ${formatCount(v.views)} 次观看 · ${formatRelative(v.createdAt)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
        ),
      ),
    );
  }

  Widget _videoThumb(BuildContext context, VideoItem v) {
    final scheme = Theme.of(context).colorScheme;
    final url =
        context.read<AuthStore>().api.resolveAsset(v.displayCover);
    Widget fallback() => Container(
          width: 76,
          height: 44,
          color: scheme.surfaceContainerHighest,
          alignment: Alignment.center,
          child: Icon(Icons.movie_outlined,
              size: 18, color: scheme.onSurfaceVariant),
        );
    if (!url.startsWith('http')) return fallback();
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: 76,
        height: 44,
        child: CachedNetworkImage(
          imageUrl: url,
          width: 76,
          height: 44,
          fit: BoxFit.cover,
          placeholder: (_, _) => fallback(),
          errorWidget: (_, _, _) => fallback(),
        ),
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
      final videos = await api.adminListVideos(status: _status);
      if (!mounted) return;
      setState(() {
        _videos = videos;
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
        _error = '视频列表加载失败，请稍后重试';
        _loading = false;
      });
    }
  }

  Future<void> _showVideoActions(VideoItem v) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final scheme = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          title: const Text('视频管理'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                v.title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                '${v.authorUsername} · ${formatCount(v.views)} 次观看 · ${formatRelative(v.createdAt)}',
                style: TextStyle(
                    fontSize: 12.5, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _deleteVideo(v);
              },
              child: Text('删除', style: TextStyle(color: scheme.error)),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _setStatus(v, 'rejected');
              },
              child: const Text('拒绝'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _setStatus(v, 'approved');
              },
              child: const Text('通过'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _setStatus(VideoItem v, String status) async {
    try {
      final api = context.read<AuthStore>().api;
      await api.updateVideo(v.id, {'status': status});
      if (!mounted) return;
      zxToast(context, status == 'approved' ? '已通过' : '已拒绝');
      _load();
    } on ApiException catch (e) {
      if (mounted) zxToast(context, e.message);
    } catch (_) {
      if (mounted) zxToast(context, '操作失败，请稍后重试');
    }
  }

  Future<void> _deleteVideo(VideoItem v) async {
    final ok = await _confirmDialog(
      context,
      title: '删除视频',
      message: '删除后无法恢复，确定删除「${v.title}」吗？',
      confirmLabel: '删除',
    );
    if (!ok || !mounted) return;
    try {
      final api = context.read<AuthStore>().api;
      await api.deleteVideo(v.id);
      if (!mounted) return;
      zxToast(context, '已删除');
      _load();
    } on ApiException catch (e) {
      if (mounted) zxToast(context, e.message);
    } catch (_) {
      if (mounted) zxToast(context, '操作失败，请稍后重试');
    }
  }
}

// ---------------- 举报 ----------------

class _ReportsTab extends StatefulWidget {
  const _ReportsTab();

  @override
  State<_ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<_ReportsTab> {
  List<AdminReport> _reports = [];
  String? _status;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Wrap(
            spacing: 8,
            children: [
              _statusChip('全部', null),
              _statusChip('待处理', 'open'),
              _statusChip('已处理', 'resolved'),
              _statusChip('已关闭', 'closed'),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _statusChip(String label, String? value) {
    return ChoiceChip(
      label: Text(label),
      selected: _status == value,
      onSelected: (_) => _changeStatus(value),
    );
  }

  void _changeStatus(String? value) {
    if (_status == value) return;
    setState(() => _status = value);
    _load();
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ZxError(message: _error!, onRetry: _load);
    }
    if (_reports.isEmpty) {
      return const ZxEmpty(icon: Icons.report_outlined, message: '暂无举报');
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 6),
        itemCount: _reports.length,
        itemBuilder: (context, i) => _reportCard(context, _reports[i]),
      ),
    );
  }

  Widget _reportCard(BuildContext context, AdminReport r) {
    final scheme = Theme.of(context).colorScheme;
    final open = r.status == 'open' || r.status == 'pending';
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    '${r.reporterUsername} 举报 ${_targetTypeLabel(r.targetType)}',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 8),
                _tag(_reportStatusColor(r.status),
                    _reportStatusLabel(r.status)),
              ],
            ),
            if (r.targetTitle.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Text(
                  '目标：${r.targetTitle}',
                  style: TextStyle(
                      fontSize: 12.5, color: scheme.onSurfaceVariant),
                ),
              ),
            const SizedBox(height: 5),
            Text(
              r.reason.isEmpty ? '未填写理由' : r.reason,
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 6),
            Text(
              formatRelative(r.createdAt),
              style: TextStyle(
                  fontSize: 11.5, color: scheme.onSurfaceVariant),
            ),
            if (open) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  FilledButton.tonal(
                    onPressed: () => _handleReportAction(r, close: false),
                    child: const Text('标记已处理'),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton(
                    onPressed: () => _handleReportAction(r, close: true),
                    child: const Text('关闭'),
                  ),
                ],
              ),
            ],
          ],
        ),
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
      final reports = await api.adminListReports(status: _status);
      if (!mounted) return;
      setState(() {
        _reports = reports;
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
        _error = '举报列表加载失败，请稍后重试';
        _loading = false;
      });
    }
  }

  Future<void> _handleReportAction(AdminReport r,
      {required bool close}) async {
    final result = await showDialog<({bool cancelled, String? note})>(
      context: context,
      builder: (_) => _NoteDialog(
        title: close ? '关闭举报' : '标记已处理',
        hint: close ? '关闭说明（可选）' : '处理说明（可选）',
      ),
    );
    if (result == null || result.cancelled) return;
    if (!mounted) return;
    try {
      final api = context.read<AuthStore>().api;
      if (close) {
        await api.adminCloseReport(r.id, resolution: result.note);
      } else {
        await api.adminResolveReport(r.id, resolution: result.note);
      }
      if (!mounted) return;
      zxToast(context, close ? '举报已关闭' : '已标记为已处理');
      _load();
    } on ApiException catch (e) {
      if (mounted) zxToast(context, e.message);
    } catch (_) {
      if (mounted) zxToast(context, '操作失败，请稍后重试');
    }
  }
}

// ---------------- 公告 ----------------

class _AnnouncementsTab extends StatefulWidget {
  const _AnnouncementsTab();

  @override
  State<_AnnouncementsTab> createState() => _AnnouncementsTabState();
}

class _AnnouncementsTabState extends State<_AnnouncementsTab> {
  List<Announcement> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        tooltip: '新建公告',
        onPressed: _create,
        child: const Icon(Icons.add),
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
      return const ZxEmpty(icon: Icons.campaign_outlined, message: '暂无公告');
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 6),
        itemCount: _items.length,
        itemBuilder: (context, i) => _announcementCard(context, _items[i]),
      ),
    );
  }

  Widget _announcementCard(BuildContext context, Announcement a) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    a.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14.5, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 8),
                _tag(
                  a.isActive ? Colors.green : Colors.grey,
                  a.isActive ? '启用中' : '已停用',
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              a.content,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 12.5,
                  height: 1.4,
                  color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  formatDate(a.createdAt),
                  style: TextStyle(
                      fontSize: 11.5, color: scheme.onSurfaceVariant),
                ),
                const Spacer(),
                PopupMenuButton<String>(
                  tooltip: '管理公告',
                  icon: const Icon(Icons.more_vert, size: 20),
                  onSelected: (v) {
                    if (v == 'edit') {
                      _edit(a);
                    } else if (v == 'toggle') {
                      _toggleActive(a);
                    } else if (v == 'delete') {
                      _delete(a);
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: ListTile(
                        dense: true,
                        leading: Icon(Icons.edit_outlined),
                        title: Text('编辑'),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'toggle',
                      child: ListTile(
                        dense: true,
                        leading: Icon(a.isActive
                            ? Icons.pause_circle_outline
                            : Icons.play_circle_outline),
                        title: Text(a.isActive ? '停用' : '启用'),
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        dense: true,
                        leading: Icon(Icons.delete_outline),
                        title: Text('删除'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
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
      final items = await api.adminListAnnouncements();
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
        _error = '公告加载失败，请稍后重试';
        _loading = false;
      });
    }
  }

  Future<void> _create() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => const _AnnouncementDialog(),
    );
    if (ok == true && mounted) {
      zxToast(context, '公告已创建');
      _load();
    }
  }

  Future<void> _edit(Announcement a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _AnnouncementDialog(existing: a),
    );
    if (ok == true && mounted) {
      zxToast(context, '公告已更新');
      _load();
    }
  }

  Future<void> _toggleActive(Announcement a) async {
    try {
      final api = context.read<AuthStore>().api;
      await api.adminUpdateAnnouncement(
          a.id, {'is_active': a.isActive ? 0 : 1});
      if (!mounted) return;
      zxToast(context, a.isActive ? '已停用' : '已启用');
      _load();
    } on ApiException catch (e) {
      if (mounted) zxToast(context, e.message);
    } catch (_) {
      if (mounted) zxToast(context, '操作失败，请稍后重试');
    }
  }

  Future<void> _delete(Announcement a) async {
    final ok = await _confirmDialog(
      context,
      title: '删除公告',
      message: '确定删除公告「${a.title}」吗？',
      confirmLabel: '删除',
    );
    if (!ok || !mounted) return;
    try {
      final api = context.read<AuthStore>().api;
      await api.adminDeleteAnnouncement(a.id);
      if (!mounted) return;
      zxToast(context, '公告已删除');
      _load();
    } on ApiException catch (e) {
      if (mounted) zxToast(context, e.message);
    } catch (_) {
      if (mounted) zxToast(context, '操作失败，请稍后重试');
    }
  }
}

// ---------------- dialogs ----------------

/// Ban dialog: optional reason + preset duration.
class _BanDialog extends StatefulWidget {
  const _BanDialog({required this.uid, required this.username});

  final int uid;
  final String username;

  @override
  State<_BanDialog> createState() => _BanDialogState();
}

class _BanDialogState extends State<_BanDialog> {
  static const _durations = <String, String>{
    '1d': '1 天',
    '7d': '7 天',
    '30d': '30 天',
    'permanent': '永久',
  };

  final _reasonCtrl = TextEditingController();
  String _duration = '1d';
  bool _busy = false;

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('封禁 ${widget.username}'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _reasonCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: '封禁原因（可选）',
                hintText: '将展示给该用户',
              ),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: _duration,
              decoration: const InputDecoration(labelText: '封禁时长'),
              items: [
                for (final e in _durations.entries)
                  DropdownMenuItem(value: e.key, child: Text(e.value)),
              ],
              onChanged: (v) => setState(() => _duration = v ?? '1d'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('确认封禁'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    final reason = _reasonCtrl.text.trim();
    try {
      final api = context.read<AuthStore>().api;
      await api.adminBanUser(
        widget.uid,
        reason: reason.isEmpty ? null : reason,
        duration: _duration,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) {
        zxToast(context, e.message);
        setState(() => _busy = false);
      }
    } catch (_) {
      if (mounted) {
        zxToast(context, '操作失败，请稍后重试');
        setState(() => _busy = false);
      }
    }
  }
}

/// Generic note dialog used for report resolution / close notes.
class _NoteDialog extends StatefulWidget {
  const _NoteDialog({required this.title, required this.hint});

  final String title;
  final String hint;

  @override
  State<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<_NoteDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 420,
        child: TextField(
          controller: _ctrl,
          maxLines: 3,
          autofocus: true,
          decoration: InputDecoration(hintText: widget.hint),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop((cancelled: true, note: null)),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            final text = _ctrl.text.trim();
            Navigator.of(context).pop(
              (cancelled: false, note: text.isEmpty ? null : text),
            );
          },
          child: const Text('确认'),
        ),
      ],
    );
  }
}

/// Create / edit announcement dialog.
class _AnnouncementDialog extends StatefulWidget {
  const _AnnouncementDialog({this.existing});

  final Announcement? existing;

  @override
  State<_AnnouncementDialog> createState() => _AnnouncementDialogState();
}

class _AnnouncementDialogState extends State<_AnnouncementDialog> {
  late final TextEditingController _titleCtrl =
      TextEditingController(text: widget.existing?.title ?? '');
  late final TextEditingController _contentCtrl =
      TextEditingController(text: widget.existing?.content ?? '');
  late bool _active = widget.existing?.isActive ?? true;
  bool _busy = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? '新建公告' : '编辑公告'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _titleCtrl,
                autofocus: true,
                decoration: const InputDecoration(labelText: '标题'),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _contentCtrl,
                maxLines: 6,
                minLines: 4,
                decoration: const InputDecoration(
                  labelText: '内容',
                  alignLabelWithHint: true,
                ),
              ),
              SwitchListTile(
                title: const Text('启用公告'),
                value: _active,
                onChanged: (v) => setState(() => _active = v),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('保存'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    final content = _contentCtrl.text.trim();
    if (title.isEmpty) {
      zxToast(context, '请输入公告标题');
      return;
    }
    if (content.isEmpty) {
      zxToast(context, '请输入公告内容');
      return;
    }
    setState(() => _busy = true);
    final body = <String, dynamic>{
      'title': title,
      'content': content,
      'is_active': _active ? 1 : 0,
    };
    try {
      final api = context.read<AuthStore>().api;
      if (widget.existing == null) {
        await api.adminCreateAnnouncement(body);
      } else {
        await api.adminUpdateAnnouncement(widget.existing!.id, body);
      }
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) {
        zxToast(context, e.message);
        setState(() => _busy = false);
      }
    } catch (_) {
      if (mounted) {
        zxToast(context, '保存失败，请稍后重试');
        setState(() => _busy = false);
      }
    }
  }
}

// ---------------- shared helpers ----------------

Future<bool> _confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = '确认',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result == true;
}

Widget _tag(Color color, String label) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(5),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 10.5,
        fontWeight: FontWeight.w600,
        color: color,
      ),
    ),
  );
}

Widget _roleTag(BuildContext context, String? role) {
  final scheme = Theme.of(context).colorScheme;
  final r = (role ?? '').toLowerCase();
  if (r == 'admin' || r == 'superadmin' || r == 'super_admin') {
    return _tag(scheme.error, '管理员');
  }
  if (r == 'moderator') {
    return _tag(Colors.blueAccent, '版主');
  }
  return _tag(Colors.grey, '用户');
}

String _targetTypeLabel(String type) => switch (type) {
      'video' => '视频',
      'comment' => '评论',
      'dynamic' => '动态',
      'article' => '专栏',
      'user' => '用户',
      _ => type,
    };

Color _reportStatusColor(String s) => switch (s) {
      'open' => Colors.blue,
      'pending' => Colors.orange,
      'resolved' => Colors.green,
      'closed' => Colors.grey,
      _ => Colors.grey,
    };

String _reportStatusLabel(String s) => switch (s) {
      'open' => '待处理',
      'pending' => '处理中',
      'resolved' => '已处理',
      'closed' => '已关闭',
      _ => s,
    };

Color _videoStatusColor(String? s) => switch (s) {
      'pending' => Colors.orange,
      'approved' => Colors.green,
      'rejected' => Colors.redAccent,
      _ => Colors.grey,
    };

String _videoStatusLabel(String? s) => switch (s) {
      'pending' => '待审核',
      'approved' => '已通过',
      'rejected' => '已拒绝',
      _ => '未知',
    };
