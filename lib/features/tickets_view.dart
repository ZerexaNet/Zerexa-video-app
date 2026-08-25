/// 工单支持: the ticket list with status filters plus the detail screen
/// with replies, a reply composer and close/reopen actions.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../stores/app_stores.dart';
import '../widgets/common.dart';

class TicketsView extends StatefulWidget {
  const TicketsView({super.key});

  @override
  State<TicketsView> createState() => _TicketsViewState();
}

class _TicketsViewState extends State<TicketsView> {
  /// The upstream returns only the caller's own tickets, and a single
  /// `status` query value cannot express open+pending, so filtering is done
  /// client-side after fetching the full list.
  List<Ticket> _all = [];
  String _filter = 'all';
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
      appBar: AppBar(title: const Text('工单支持')),
      floatingActionButton: FloatingActionButton(
        tooltip: '新建工单',
        onPressed: _createTicket,
        child: const Icon(Icons.add),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Wrap(
              spacing: 8,
              children: [
                _filterChip('全部', 'all'),
                _filterChip('进行中', 'active'),
                _filterChip('已解决', 'done'),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String value) {
    return ChoiceChip(
      label: Text(label),
      selected: _filter == value,
      onSelected: (_) {
        if (_filter == value) return;
        setState(() => _filter = value);
      },
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ZxError(message: _error!, onRetry: _load);
    }
    final visible = _visible;
    if (visible.isEmpty) {
      return const ZxEmpty(
        icon: Icons.support_agent_outlined,
        message: '暂无工单',
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 6),
        itemCount: visible.length,
        itemBuilder: (context, i) => _ticketCard(context, visible[i]),
      ),
    );
  }

  List<Ticket> get _visible {
    switch (_filter) {
      case 'active':
        return _all
            .where((t) => t.status == 'open' || t.status == 'pending')
            .toList();
      case 'done':
        return _all
            .where((t) => t.status == 'resolved' || t.status == 'closed')
            .toList();
      default:
        return _all;
    }
  }

  Widget _ticketCard(BuildContext context, Ticket t) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        onTap: () => _openDetail(t),
        title: Row(
          children: [
            Expanded(
              child: Text(
                t.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 8),
            _ticketStatusTag(t.status),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '${_categoryLabel(t.category)} · ${t.creatorUsername} · ${formatRelative(t.createdAt)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
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
      final tickets = await api.listTickets();
      if (!mounted) return;
      setState(() {
        _all = tickets;
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
        _error = '工单加载失败，请稍后重试';
        _loading = false;
      });
    }
  }

  Future<void> _createTicket() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => const _CreateTicketDialog(),
    );
    if (created == true && mounted) {
      zxToast(context, '工单已提交');
      _load();
    }
  }

  Future<void> _openDetail(Ticket t) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => TicketDetailScreen(ticketId: t.id),
    ));
    if (mounted) _load();
  }
}

class TicketDetailScreen extends StatefulWidget {
  const TicketDetailScreen({super.key, required this.ticketId});

  final String ticketId;

  @override
  State<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<TicketDetailScreen> {
  final _replyCtrl = TextEditingController();
  Ticket? _ticket;
  bool _loading = true;
  bool _busy = false;
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
    _replyCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<AuthStore>().api;
      final ticket = await api.getTicket(widget.ticketId);
      if (!mounted) return;
      setState(() {
        _ticket = ticket;
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
        _error = '工单加载失败，请稍后重试';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = _ticket;
    final isOpen = t != null && (t.status == 'open' || t.status == 'pending');
    return Scaffold(
      appBar: AppBar(
        title: const Text('工单详情'),
        actions: [
          if (t != null && !_loading)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton.icon(
                onPressed: _busy ? null : (isOpen ? _closeTicket : _reopenTicket),
                icon: Icon(
                  isOpen ? Icons.close : Icons.lock_open_rounded,
                  size: 18,
                ),
                label: Text(isOpen ? '关闭工单' : '重新打开'),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ZxError(message: _error!, onRetry: _load)
              : t == null
                  ? const ZxEmpty(
                      icon: Icons.support_agent_outlined,
                      message: '工单不存在',
                    )
                  : _buildBody(context, t),
      bottomNavigationBar: (_error == null && t != null)
          ? _buildReplyBar(context)
          : null,
    );
  }

  Widget _buildBody(BuildContext context, Ticket t) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _ticketStatusTag(t.status),
            _tag(
              _priorityColor(t.priority),
              _priorityLabel(t.priority),
            ),
            _tag(Colors.blueGrey, _categoryLabel(t.category)),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          t.title,
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 10),
        Text(t.content, style: const TextStyle(fontSize: 14, height: 1.55)),
        const SizedBox(height: 10),
        Text(
          '创建人 ${t.creatorUsername} · ${formatDate(t.createdAt)}',
          style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
        ),
        const Divider(height: 32),
        Text('回复 (${t.replies.length})',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        if (t.replies.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '暂无回复，等待客服处理',
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
          )
        else
          for (final r in t.replies) _replyTile(context, r),
      ],
    );
  }

  Widget _replyTile(BuildContext context, TicketReply r) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ZxAuthor(username: r.authorUsername, size: 22),
              if (r.isStaff) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '官方',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: scheme.primary,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              Text(
                formatRelative(r.createdAt),
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(r.content,
              style: const TextStyle(fontSize: 13.5, height: 1.5)),
        ],
      ),
    );
  }

  Widget _buildReplyBar(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _replyCtrl,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendReply(),
                decoration: const InputDecoration(
                  hintText: '回复工单...',
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              tooltip: '发送',
              onPressed: _busy ? null : _sendReply,
              icon: const Icon(Icons.send_rounded),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendReply() async {
    final text = _replyCtrl.text.trim();
    if (text.isEmpty || _busy) return;
    setState(() => _busy = true);
    final api = context.read<AuthStore>().api;
    try {
      await api.replyTicket(widget.ticketId, text);
      if (!mounted) return;
      _replyCtrl.clear();
      zxToast(context, '回复成功');
      await _load();
    } on ApiException catch (e) {
      if (mounted) zxToast(context, e.message);
    } catch (_) {
      if (mounted) zxToast(context, '回复失败，请稍后重试');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _closeTicket() async {
    final ok = await _confirm(
      context,
      title: '关闭工单',
      message: '关闭后将无法继续回复，确定关闭该工单吗？',
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    final api = context.read<AuthStore>().api;
    try {
      await api.closeTicket(widget.ticketId);
      if (!mounted) return;
      zxToast(context, '工单已关闭');
      await _load();
    } on ApiException catch (e) {
      if (mounted) zxToast(context, e.message);
    } catch (_) {
      if (mounted) zxToast(context, '操作失败，请稍后重试');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reopenTicket() async {
    if (_busy) return;
    setState(() => _busy = true);
    final api = context.read<AuthStore>().api;
    try {
      await api.reopenTicket(widget.ticketId);
      if (!mounted) return;
      zxToast(context, '已重新打开');
      await _load();
    } on ApiException catch (e) {
      if (mounted) zxToast(context, e.message);
    } catch (_) {
      if (mounted) zxToast(context, '操作失败，请稍后重试');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

/// Form dialog used to submit a new ticket.
class _CreateTicketDialog extends StatefulWidget {
  const _CreateTicketDialog();

  @override
  State<_CreateTicketDialog> createState() => _CreateTicketDialogState();
}

class _CreateTicketDialogState extends State<_CreateTicketDialog> {
  static const _categories = <String, String>{
    'general': '通用',
    'account': '账号',
    'video': '视频',
    'report': '举报',
    'other': '其他',
  };

  static const _priorities = <String, String>{
    'low': '低',
    'normal': '普通',
    'high': '高',
    'urgent': '紧急',
  };

  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  String _category = 'general';
  String _priority = 'normal';
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
      title: const Text('新建工单'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _titleCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: '标题',
                  hintText: '简要描述问题',
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: _category,
                decoration: const InputDecoration(labelText: '分类'),
                items: [
                  for (final e in _categories.entries)
                    DropdownMenuItem(value: e.key, child: Text(e.value)),
                ],
                onChanged: (v) => setState(() => _category = v ?? 'general'),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: _priority,
                decoration: const InputDecoration(labelText: '优先级'),
                items: [
                  for (final e in _priorities.entries)
                    DropdownMenuItem(value: e.key, child: Text(e.value)),
                ],
                onChanged: (v) => setState(() => _priority = v ?? 'normal'),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _contentCtrl,
                maxLines: 5,
                minLines: 3,
                decoration: const InputDecoration(
                  labelText: '问题描述',
                  hintText: '请详细描述遇到的问题',
                  alignLabelWithHint: true,
                ),
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
              : const Text('提交工单'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    final content = _contentCtrl.text.trim();
    if (title.isEmpty) {
      zxToast(context, '请输入工单标题');
      return;
    }
    if (content.isEmpty) {
      zxToast(context, '请描述遇到的问题');
      return;
    }
    setState(() => _busy = true);
    try {
      final api = context.read<AuthStore>().api;
      await api.createTicket({
        'title': title,
        'category': _category,
        'priority': _priority,
        'content': content,
      });
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) {
        zxToast(context, e.message);
        setState(() => _busy = false);
      }
    } catch (_) {
      if (mounted) {
        zxToast(context, '提交失败，请稍后重试');
        setState(() => _busy = false);
      }
    }
  }
}

// ---------- shared helpers ----------

Future<bool> _confirm(
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

Widget _ticketStatusTag(String status) => switch (status) {
      'open' => _tag(Colors.blue, '待处理'),
      'pending' => _tag(Colors.orange, '处理中'),
      'resolved' => _tag(Colors.green, '已解决'),
      'closed' => _tag(Colors.grey, '已关闭'),
      _ => _tag(Colors.grey, status),
    };

Color _priorityColor(String p) => switch (p) {
      'low' => Colors.grey,
      'high' => Colors.orange,
      'urgent' => Colors.redAccent,
      _ => Colors.blue,
    };

String _priorityLabel(String p) => switch (p) {
      'low' => '低',
      'high' => '高',
      'urgent' => '紧急',
      _ => '普通',
    };

String _categoryLabel(String c) => switch (c) {
      'general' => '通用',
      'account' => '账号',
      'video' => '视频',
      'report' => '举报',
      'other' => '其他',
      _ => c,
    };
