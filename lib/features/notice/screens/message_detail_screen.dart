import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:teacher_app/app/design_tokens.dart';
import 'package:teacher_app/features/notice/data/notice_repository.dart';

/// 消息详情：展示完整内容，进入即标记已读。
/// 通过 GoRouter 的 extra 接收 notice Map。
class MessageDetailScreen extends StatefulWidget {
  final Map<String, dynamic> notice;
  const MessageDetailScreen({super.key, required this.notice});

  @override
  State<MessageDetailScreen> createState() => _MessageDetailScreenState();
}

class _MessageDetailScreenState extends State<MessageDetailScreen> {
  @override
  void initState() {
    super.initState();
    final int id = (widget.notice['id'] as int?) ?? 0;
    if (id > 0 && (widget.notice['read'] as int? ?? 0) == 0) {
      NoticeRepository().markRead(id).catchError((_) {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final String title = widget.notice['title'] as String? ?? '通知';
    final String content = widget.notice['content'] as String? ?? '';
    final String time = _format(widget.notice['createTime']);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              content,
              style: const TextStyle(fontSize: AppFontSize.body, height: 1.6),
            ),
            const SizedBox(height: 16),
            if (time.isNotEmpty)
              Text('时间：$time',
                  style: const TextStyle(color: AppPalette.inkMute, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  String _format(dynamic t) {
    if (t is String) {
      final DateTime? dt = DateTime.tryParse(t);
      if (dt != null) return DateFormat('yyyy-MM-dd HH:mm').format(dt);
    }
    return '';
  }
}
