/// Complete report dialog for users / videos / comments / dynamics / articles.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api.dart';
import '../stores/app_stores.dart';
import '../widgets/common.dart';

Future<void> showReportDialog(
  BuildContext context, {
  required String targetType,
  String? targetId,
  int? targetUid,
  String targetTitle = '',
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _ReportDialog(
      targetType: targetType,
      targetId: targetId,
      targetUid: targetUid,
      targetTitle: targetTitle,
    ),
  );
}

class _ReportDialog extends StatefulWidget {
  const _ReportDialog({
    required this.targetType,
    this.targetId,
    this.targetUid,
    this.targetTitle = '',
  });

  final String targetType;
  final String? targetId;
  final int? targetUid;
  final String targetTitle;

  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  static const _categories = <String, String>{
    'spam': '垃圾信息 / 广告',
    'abuse': '辱骂 / 人身攻击',
    'nsfw': '色情低俗',
    'illegal': '违法违规',
    'infringement': '侵权 / 抄袭',
    'misinformation': '虚假信息',
    'other': '其他',
  };

  String _category = 'spam';
  final _descriptionCtrl = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _descriptionCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reason = _categories[_category]!;
    final desc = _descriptionCtrl.text.trim();
    if (desc.isEmpty) {
      zxToast(context, '请补充问题描述');
      return;
    }
    setState(() => _busy = true);
    try {
      await context.read<AuthStore>().api.reportUser({
        if (widget.targetUid != null) 'target_uid': widget.targetUid,
        'target_type': widget.targetType,
        if (widget.targetId != null) 'target_id': widget.targetId,
        'reason': reason,
        'description': desc,
        'category': _category,
      });
      if (mounted) {
        Navigator.of(context).pop();
        zxToast(context, '举报已提交，感谢你的反馈');
      }
    } on ApiException catch (e) {
      if (mounted) zxToast(context, '提交失败：${e.message}');
    } catch (_) {
      if (mounted) zxToast(context, '提交失败，请稍后重试');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final typeLabel = switch (widget.targetType) {
      'video' => '视频',
      'comment' => '评论',
      'dynamic' => '动态',
      'article' => '专栏',
      _ => '用户',
    };
    return AlertDialog(
      title: const Text('举报'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '举报类型：$typeLabel'
                '${widget.targetTitle.isEmpty ? '' : ' · ${widget.targetTitle}'}',
                style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final entry in _categories.entries)
                    ChoiceChip(
                      label: Text(entry.value),
                      selected: _category == entry.key,
                      onSelected: (_) => setState(() => _category = entry.key),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descriptionCtrl,
                maxLines: 4,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: '详细描述',
                  hintText: '请描述举报原因，帮助我们更快处理',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '恶意举报可能导致账号受到处罚，请如实填写。',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
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
              : const Text('提交举报'),
        ),
      ],
    );
  }
}
