/// 1:1 private conversation screen: a reversed message list (newest at the
/// bottom) plus a sticky input bar for sending new messages.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../stores/app_stores.dart';
import '../widgets/common.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.peerUsername,
    this.peerGravatar,
    required this.peerUid,
  });

  final String conversationId;
  final String peerUsername;
  final String? peerGravatar;
  final int peerUid;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<DirectMessage> _messages = [];
  final _inputCtrl = TextEditingController();
  bool _loading = true;
  bool _sending = false;
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
    _inputCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final api = context.read<AuthStore>().api;
    try {
      final messages = await api.listMessages(widget.conversationId);
      try {
        await api.markConversationRead(widget.conversationId);
      } catch (_) {
        // Best effort - the unread badge refreshes when the list reloads.
      }
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(messages);
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
        _error = '消息加载失败，请稍后重试';
        _loading = false;
      });
    }
  }

  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    final api = context.read<AuthStore>().api;
    try {
      final message = await api.sendMessage(
        conversationId: widget.conversationId,
        content: text,
      );
      if (!mounted) return;
      setState(() {
        _messages.add(message);
        _inputCtrl.clear();
      });
    } on ApiException catch (e) {
      if (mounted) zxToast(context, e.message);
    } catch (_) {
      if (mounted) zxToast(context, '发送失败，请稍后重试');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            ZxAvatar(url: widget.peerGravatar, name: widget.peerUsername, size: 32),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.peerUsername.isEmpty ? '私信' : widget.peerUsername,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ZxError(message: _error!, onRetry: _load)
              : _messages.isEmpty
                  ? const ZxEmpty(
                      icon: Icons.chat_bubble_outline,
                      message: '暂无消息，发送第一条私信吧',
                    )
                  : ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.fromLTRB(14, 16, 14, 8),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        // Reversed list: index 0 renders at the bottom, so
                        // feed it the newest message first.
                        final m = _messages[_messages.length - 1 - index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _bubble(context, m),
                        );
                      },
                    ),
      bottomNavigationBar: _buildInputBar(context),
    );
  }

  Widget _buildInputBar(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _inputCtrl,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: const InputDecoration(
                  hintText: '输入消息...',
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              tooltip: '发送',
              onPressed: _sending ? null : _send,
              icon: const Icon(Icons.send_rounded),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bubble(BuildContext context, DirectMessage m) {
    final scheme = Theme.of(context).colorScheme;
    final auth = context.read<AuthStore>();
    final own = auth.user != null && m.senderUid == auth.user!.uid;
    final maxWidth = MediaQuery.sizeOf(context).width * .72;

    return Align(
      alignment: own ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment:
            own ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '${m.senderUsername} · ${formatRelative(m.createdAt)}',
              style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 3),
          Container(
            constraints: BoxConstraints(maxWidth: maxWidth),
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
            decoration: BoxDecoration(
              color: own ? scheme.primary : scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(14),
                topRight: const Radius.circular(14),
                bottomLeft: Radius.circular(own ? 14 : 4),
                bottomRight: Radius.circular(own ? 4 : 14),
              ),
            ),
            child: Text(
              m.content,
              style: TextStyle(
                fontSize: 14.5,
                height: 1.4,
                color: own ? scheme.onPrimary : scheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
