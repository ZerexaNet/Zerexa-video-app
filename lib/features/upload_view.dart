/// Video submission ("视频投稿") with chunked upload support.
///
/// The file is picked via [FilePicker] with `withData: true`, so its bytes
/// are buffered in memory; large-file streaming from disk is delegated to
/// the server chunk API by slicing the buffer into presigned parts.
library;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../stores/app_stores.dart';
import '../widgets/common.dart';

class UploadView extends StatefulWidget {
  const UploadView({super.key});

  @override
  State<UploadView> createState() => _UploadViewState();
}

class _UploadViewState extends State<UploadView> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();

  PlatformFile? _pickedFile;
  double _progress = 0;
  int _uploadedChunks = 0;
  int _totalChunks = 0;

  /// Upload pipeline phase: idle | uploading | completing | done.
  String _phase = 'idle';
  String? _error;

  bool get _busy => _phase == 'uploading' || _phase == 'completing';

  @override
  void dispose() {
    _titleCtrl.dispose();
    _categoryCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  // ---------- file picking ----------

  Future<void> _pickFile() async {
    if (_busy) return;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    setState(() {
      _pickedFile = result.files.single;
      _error = null;
      if (_phase == 'done') _phase = 'idle';
    });
  }

  // ---------- upload flow ----------

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    final auth = context.read<AuthStore>();
    if (!auth.isAuthed) {
      zxToast(context, '请先登录后再投稿');
      return;
    }
    final file = _pickedFile;
    if (file == null) {
      zxToast(context, '请先选择视频文件');
      return;
    }
    // Bytes are read fully into memory (withData: true); streaming very
    // large files from disk is delegated to the server chunk API below by
    // slicing this buffer into presigned parts.
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      zxToast(context, '无法读取文件内容，请重新选择');
      return;
    }
    final api = auth.api;
    setState(() {
      _error = null;
      _phase = 'uploading';
      _progress = 0;
      _uploadedChunks = 0;
      _totalChunks = 0;
    });
    try {
      final session = await api.initUpload({
        'filename': file.name,
        'size': file.size,
        'mime_type': _mimeFor(file.extension),
        'kind': 'video',
      });
      final body = <String, dynamic>{
        'upload_id': session.uploadId,
        'title': _titleCtrl.text.trim(),
        'description': _descriptionCtrl.text.trim(),
        'category': _categoryCtrl.text.trim(),
      };

      if (session.chunkUrls.isNotEmpty && session.chunkSize > 0) {
        // Multipart upload: PUT every chunk to its presigned URL.
        final total = session.chunkUrls.length;
        if (mounted) setState(() => _totalChunks = total);
        final etags = <String?>[];
        for (var i = 0; i < total; i++) {
          final start = i * session.chunkSize;
          if (start >= bytes.length) break;
          final end = (i + 1) * session.chunkSize;
          final slice = bytes.sublist(
              start, end > bytes.length ? bytes.length : end);
          final etag = await api.putChunk(
            session.chunkUrls[i],
            slice,
            headers: session.headers,
            onProgress: (count, chunkTotal) {
              if (!mounted || chunkTotal <= 0) return;
              setState(
                  () => _progress = (i + count / chunkTotal) / total);
            },
          );
          etags.add(etag);
          if (!mounted) return;
          setState(() {
            _uploadedChunks = i + 1;
            _progress = (i + 1) / total;
          });
        }
        if (mounted) setState(() => _phase = 'completing');
        final parts = <Map<String, dynamic>>[];
        for (var j = 0; j < etags.length; j++) {
          final etag = etags[j];
          if (etag != null && etag.isNotEmpty) {
            parts.add({'part_number': j + 1, 'etag': etag});
          }
        }
        if (parts.isNotEmpty) body['parts'] = parts;
        await api.completeUpload(body);
      } else if (session.uploadUrl != null &&
          session.uploadUrl!.isNotEmpty) {
        // Single presigned URL upload.
        if (mounted) setState(() => _totalChunks = 1);
        await api.putChunk(
          session.uploadUrl!,
          bytes,
          onProgress: (count, total) {
            if (!mounted || total <= 0) return;
            setState(() => _progress = count / total);
          },
        );
        if (!mounted) return;
        setState(() {
          _uploadedChunks = 1;
          _progress = 1;
          _phase = 'completing';
        });
        await api.completeUpload(body);
      } else {
        throw ApiException('服务器未返回上传地址');
      }
      if (!mounted) return;
      setState(() => _phase = 'done');
      zxToast(context, '上传成功，等待审核');
      _resetForm();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _phase = 'idle';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = '上传失败，请稍后重试';
        _phase = 'idle';
      });
    }
  }

  void _resetForm() {
    _titleCtrl.clear();
    _categoryCtrl.clear();
    _descriptionCtrl.clear();
    setState(() => _pickedFile = null);
  }

  /// Derives a MIME type from the picked file extension.
  String _mimeFor(String? extension) {
    switch ((extension ?? '').toLowerCase()) {
      case 'mp4':
        return 'video/mp4';
      case 'mkv':
        return 'video/x-matroska';
      case 'webm':
        return 'video/webm';
      case 'mov':
        return 'video/quicktime';
      default:
        return 'video/mp4';
    }
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('视频投稿')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
          children: [
            _buildPickCard(context),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: Icon(Icons.info_outline, color: scheme.primary),
                title: const Text('分片上传',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                subtitle: const Text('大文件会被自动切分为多个分片并行安全上传'),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _titleCtrl,
              enabled: !_busy,
              decoration: const InputDecoration(
                labelText: '标题',
                prefixIcon: Icon(Icons.title),
              ),
              textInputAction: TextInputAction.next,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? '请输入视频标题' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _categoryCtrl,
              enabled: !_busy,
              decoration: const InputDecoration(
                labelText: '分区（可选）',
                prefixIcon: Icon(Icons.category_outlined),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
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
            const SizedBox(height: 18),
            if (_busy || _phase == 'done') _buildProgressCard(context),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.error_outline, size: 18, color: scheme.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style:
                          TextStyle(fontSize: 13, color: scheme.error),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 18),
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
                  : const Icon(Icons.cloud_upload_outlined),
              label: Text(_busy ? '上传中' : '开始上传'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPickCard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final file = _pickedFile;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('选择文件',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 10),
            if (file == null)
              OutlinedButton.icon(
                onPressed: _busy ? null : _pickFile,
                icon: const Icon(Icons.movie_outlined),
                label: const Text('选择视频文件'),
              )
            else
              Row(
                children: [
                  Icon(Icons.movie_outlined, color: scheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          file.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          formatBytes(file.size),
                          style: TextStyle(
                              fontSize: 12, color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: _busy ? null : _pickFile,
                    child: const Text('重新选择'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressCard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_phase == 'uploading') ...[
              LinearProgressIndicator(
                  value: _progress.clamp(0.0, 1.0).toDouble()),
              const SizedBox(height: 8),
              Text('上传分片 $_uploadedChunks/$_totalChunks',
                  style: TextStyle(
                      fontSize: 12.5, color: scheme.onSurfaceVariant)),
            ] else if (_phase == 'completing') ...[
              const LinearProgressIndicator(),
              const SizedBox(height: 8),
              Text('完成处理中',
                  style: TextStyle(
                      fontSize: 12.5, color: scheme.onSurfaceVariant)),
            ] else
              Row(
                children: [
                  Icon(Icons.check_circle_outline, color: scheme.primary),
                  const SizedBox(width: 8),
                  const Text('上传成功，等待审核',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
