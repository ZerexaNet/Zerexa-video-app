/// Formatting helpers shared across the app.
library;

import 'package:intl/intl.dart';

/// 1234 -> "1234", 12345 -> "1.2万", 123456789 -> "1.2亿"
String formatCount(num? v) {
  final n = v ?? 0;
  if (n < 10000) return '$n';
  if (n < 100000000) {
    final w = n / 10000;
    return '${w >= 100 ? w.toStringAsFixed(0) : w.toStringAsFixed(1)}万';
  }
  final y = n / 100000000;
  return '${y >= 100 ? y.toStringAsFixed(0) : y.toStringAsFixed(1)}亿';
}

String formatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:$m:$s' : '$m:$s';
}

String formatRelative(DateTime? time) {
  if (time == null) return '';
  final diff = DateTime.now().difference(time);
  if (diff.inSeconds < 60) return '刚刚';
  if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
  if (diff.inHours < 24) return '${diff.inHours}小时前';
  if (diff.inDays < 30) return '${diff.inDays}天前';
  if (diff.inDays < 365) return DateFormat('M月d日').format(time);
  return DateFormat('yyyy年M月d日').format(time);
}

String formatDate(DateTime? time) =>
    time == null ? '' : DateFormat('yyyy-MM-dd HH:mm').format(time);

/// Rough byte size formatting: 1536 -> "1.5 KB"
String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }
  return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
}
