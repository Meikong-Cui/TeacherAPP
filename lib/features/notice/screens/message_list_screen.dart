import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:teacher_app/app/design_tokens.dart';
import 'package:teacher_app/features/notice/data/notice_repository.dart';

/// 消息通知列表：展示站内信（后端 /api/notices）的简略消息。
/// 点击进入详情（/messages/detail）查看完整内容并标记已读。
class MessageListScreen extends StatefulWidget {
  const MessageListScreen({super.key});

  @override
  State<MessageListScreen> createState() => _MessageListScreenState();
}

class _MessageListScreenState extends State<MessageListScreen> {
  final NoticeRepository _repo = NoticeRepository();
  List<Map<String, dynamic>> _items = <Map<String, dynamic>>[];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final List<Map<String, dynamic>> list = await _repo.fetchNotices();
      list.sort((a, b) => _ts(b).compareTo(_ts(a)));
      setState(() => _items = list);
    } catch (e) {
      setState(() => _error = '加载失败：$e');
    } finally {
      setState(() => _loading = false);
    }
  }

  DateTime _ts(Map<String, dynamic> n) {
    final dynamic t = n['createTime'];
    if (t is String) return DateTime.tryParse(t) ?? DateTime(2000);
    return DateTime(2000);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('消息通知')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!))
                : _items.isEmpty
                    ? const Center(child: Text('暂无消息'))
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (ctx, i) => _MessageTile(
                          notice: _items[i],
                          onTap: () async {
                            await context.push('/messages/detail', extra: _items[i]);
                            _load(); // 返回后刷新已读状态
                          },
                        ),
                      ),
      ),
    );
  }
}

class _MessageTile extends StatelessWidget {
  final Map<String, dynamic> notice;
  final VoidCallback onTap;
  const _MessageTile({required this.notice, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bool unread = (notice['read'] as int? ?? 0) == 0;
    final String title = notice['title'] as String? ?? '通知';
    final String content = notice['content'] as String? ?? '';
    final String type = notice['type'] as String? ?? 'notice';
    final String time = _format(notice['createTime']);
    return SoftCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          unread
              ? Container(
                  margin: const EdgeInsets.only(top: 6, right: 8),
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                  ),
                )
              : const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontWeight: unread ? FontWeight.bold : FontWeight.normal,
                          fontSize: AppFontSize.body,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _TypeTag(type),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  content,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: AppFontSize.small,
                    color: AppPalette.inkMute,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  time,
                  style: const TextStyle(fontSize: 12, color: AppPalette.inkMute),
                ),
              ],
            ),
          ),
        ],
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

class _TypeTag extends StatelessWidget {
  final String type;
  const _TypeTag(this.type);

  static const Map<String, String> _labels = <String, String>{
    'approval': '审批',
    'alert': '预警',
    'task': '任务',
    'notice': '通知',
    'reimbursement': '报销',
    'seal': '用章',
    'mailbox': '信箱',
  };
  static const Map<String, Color> _colors = <String, Color>{
    'approval': Colors.orange,
    'alert': Colors.red,
    'task': Colors.green,
    'notice': Colors.blue,
    'reimbursement': Colors.amber,
    'seal': Colors.teal,
  };

  @override
  Widget build(BuildContext context) {
    final Color color = _colors[type] ?? Colors.grey;
    final String label = _labels[type] ?? type;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(38),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, color: color)),
    );
  }
}
