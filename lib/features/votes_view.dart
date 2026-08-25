/// 公投: the vote list with status filters plus the detail screen with
/// either live voting controls or result bars.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../stores/app_stores.dart';
import '../widgets/common.dart';
import 'auth_view.dart';

class VotesView extends StatefulWidget {
  const VotesView({super.key});

  @override
  State<VotesView> createState() => _VotesViewState();
}

class _VotesViewState extends State<VotesView> {
  List<Vote> _votes = [];
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
    return Scaffold(
      appBar: AppBar(title: const Text('公投')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Wrap(
              spacing: 8,
              children: [
                _statusChip('全部', null),
                _statusChip('进行中', 'open'),
                _statusChip('已结束', 'closed'),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _statusChip(String label, String? value) {
    return ChoiceChip(
      label: Text(label),
      selected: _status == value,
      onSelected: (_) {
        if (_status == value) return;
        setState(() => _status = value);
        _load();
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
    if (_votes.isEmpty) {
      return const ZxEmpty(icon: Icons.how_to_vote_outlined, message: '暂无公投');
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 6),
        itemCount: _votes.length,
        itemBuilder: (context, i) => _voteCard(context, _votes[i]),
      ),
    );
  }

  Widget _voteCard(BuildContext context, Vote v) {
    final scheme = Theme.of(context).colorScheme;
    final deadline = v.endAt == null
        ? ''
        : '截止 ${DateFormat('yyyy-MM-dd').format(v.endAt!)}';
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: InkWell(
        onTap: () => _openDetail(v),
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
                      v.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _voteStatusTag(v.status),
                ],
              ),
              if (v.description != null && v.description!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    v.description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.how_to_vote_outlined,
                      size: 14, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(
                    '总票数 ${formatCount(v.totalVotes)}',
                    style: TextStyle(
                        fontSize: 12, color: scheme.onSurfaceVariant),
                  ),
                  const Spacer(),
                  if (deadline.isNotEmpty) ...[
                    Icon(Icons.schedule,
                        size: 14, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(
                      deadline,
                      style: TextStyle(
                          fontSize: 12, color: scheme.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
            ],
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
      final votes = await api.listVotes(status: _status);
      if (!mounted) return;
      setState(() {
        _votes = votes;
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
        _error = '公投加载失败，请稍后重试';
        _loading = false;
      });
    }
  }

  Future<void> _openDetail(Vote v) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => VoteDetailScreen(voteId: v.id),
    ));
    if (mounted) _load();
  }
}

class VoteDetailScreen extends StatefulWidget {
  const VoteDetailScreen({super.key, required this.voteId});

  final String voteId;

  @override
  State<VoteDetailScreen> createState() => _VoteDetailScreenState();
}

class _VoteDetailScreenState extends State<VoteDetailScreen> {
  Vote? _vote;
  String? _selected;
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

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<AuthStore>().api;
      final vote = await api.getVote(widget.voteId);
      if (!mounted) return;
      setState(() {
        _vote = vote;
        _selected = null;
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
        _error = '公投加载失败，请稍后重试';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('投票详情')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ZxError(message: _error!, onRetry: _load)
              : _vote == null
                  ? const ZxEmpty(
                      icon: Icons.how_to_vote_outlined,
                      message: '公投不存在',
                    )
                  : _buildBody(context, _vote!),
    );
  }

  Widget _buildBody(BuildContext context, Vote vote) {
    final auth = context.watch<AuthStore>();
    final showResults = vote.hasVoted || vote.status != 'open';
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                vote.title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  height: 1.3,
                ),
              ),
            ),
            const SizedBox(width: 8),
            _voteStatusTag(vote.status),
          ],
        ),
        if (vote.description != null && vote.description!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(vote.description!,
              style: const TextStyle(fontSize: 14, height: 1.5)),
        ],
        const SizedBox(height: 12),
        _metaRow(context, '开始时间', formatDate(vote.startAt)),
        const SizedBox(height: 6),
        _metaRow(context, '截止时间', formatDate(vote.endAt)),
        const SizedBox(height: 6),
        _metaRow(context, '总票数', formatCount(vote.totalVotes)),
        const Divider(height: 30),
        Text('投票选项',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        if (showResults)
          _buildResults(context, vote)
        else if (!auth.isAuthed)
          _buildLoginPrompt(context)
        else
          _buildVotingForm(context, vote),
      ],
    );
  }

  Widget _metaRow(BuildContext context, String label, String value) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 76,
          child: Text(
            label,
            style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
          ),
        ),
        Expanded(
          child: Text(value, style: const TextStyle(fontSize: 13)),
        ),
      ],
    );
  }

  Widget _buildResults(BuildContext context, Vote vote) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          vote.hasVoted
              ? '你已参与投票，结果如下'
              : (vote.status == 'closed' ? '投票已结束' : '投票尚未开始'),
          style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 14),
        for (final o in vote.options) _resultOption(context, vote, o),
      ],
    );
  }

  Widget _resultOption(BuildContext context, Vote vote, VoteOption o) {
    final scheme = Theme.of(context).colorScheme;
    final isMine = vote.votedOptionId != null && vote.votedOptionId == o.id;
    var pct = o.percentage;
    if (pct <= 0) {
      pct = vote.totalVotes > 0 ? o.voteCount / vote.totalVotes * 100 : 0;
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (isMine) ...[
                Icon(Icons.check_circle, size: 16, color: scheme.primary),
                const SizedBox(width: 4),
              ],
              Expanded(
                child: Text(
                  o.label,
                  style: TextStyle(
                    fontWeight: isMine ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ),
              if (isMine) ...[
                Text(
                  '你的选择',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                '${formatCount(o.voteCount)} 票 · ${pct.toStringAsFixed(1)}%',
                style: TextStyle(
                    fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (pct / 100).clamp(0.0, 1.0).toDouble(),
              minHeight: 8,
              color: isMine ? scheme.primary : Colors.grey,
              backgroundColor: scheme.surfaceContainerHighest,
            ),
          ),
          if (o.description != null && o.description!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(
                o.description!,
                style: TextStyle(
                    fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVotingForm(BuildContext context, Vote vote) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final o in vote.options)
          RadioListTile<String>(
            value: o.id,
            groupValue: _selected,
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            title: Text(
              o.label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: (o.description == null || o.description!.isEmpty)
                ? null
                : Text(
                    o.description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
            onChanged: _busy
                ? null
                : (value) => setState(() => _selected = value),
          ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: (_selected == null || _busy) ? null : _confirmVote,
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.how_to_vote_outlined),
            label: const Text('投出你的一票'),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginPrompt(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '登录后即可参与投票',
          style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _goLogin,
          icon: const Icon(Icons.login_rounded),
          label: const Text('立即登录'),
        ),
      ],
    );
  }

  Future<void> _goLogin() async {
    await Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => const AuthScreen(),
    ));
    if (mounted) _load();
  }

  Future<void> _confirmVote() async {
    final vote = _vote;
    final optionId = _selected;
    if (vote == null || optionId == null || _busy) return;
    var label = '';
    for (final o in vote.options) {
      if (o.id == optionId) {
        label = o.label;
        break;
      }
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('确认投票'),
        content: Text('确定投给「$label」吗？提交后不可更改。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('确认投票'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    final api = context.read<AuthStore>().api;
    try {
      await api.castVote(widget.voteId, optionId);
      if (!mounted) return;
      zxToast(context, '投票成功');
      await _load();
    } on ApiException catch (e) {
      if (mounted) zxToast(context, e.message);
    } catch (_) {
      if (mounted) zxToast(context, '投票失败，请稍后重试');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

// ---------- shared helpers ----------

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

Widget _voteStatusTag(String status) => switch (status) {
      'open' => _tag(Colors.blue, '进行中'),
      'upcoming' => _tag(Colors.orange, '未开始'),
      'closed' => _tag(Colors.grey, '已结束'),
      _ => _tag(Colors.grey, status),
    };
