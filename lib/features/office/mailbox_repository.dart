import 'package:teacher_app/core/api_client.dart';
import 'package:teacher_app/core/constants.dart';

/// 员工信箱消息（收件箱 / 发件箱共用模型）。
///
/// 后端：oa-workflow 模块 `/api/mailbox/*`，一对多收件人（群发），
/// 保留 30 天（查询侧已按创建时间过滤，过期由定时任务清理）。
class MailboxMessage {
  const MailboxMessage({
    required this.id,
    this.senderId,
    this.senderName = '',
    this.content = '',
    this.images = const <String>[],
    this.createTime,
    this.readFlag = 0,
    this.recipients = const <MailboxRecipient>[],
  });

  final int id;
  final int? senderId;
  final String senderName;
  final String content;
  final List<String> images;
  final DateTime? createTime;
  /// 收件箱视角：0 未读 1 已读
  final int readFlag;
  /// 发件箱视角：每位收件人及其已读状态（群发时多条）
  final List<MailboxRecipient> recipients;

  bool get unread => readFlag != 1;

  /// 列表摘要：有文字取文字，纯图片给图片提示。
  String get summary {
    final String t = content.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (t.isEmpty) return '［图片 ${images.length} 张］';
    return t;
  }

  /// 图片完整访问地址（后端存相对路径 /api/attachment/file/...）。
  String imageUrl(String path) =>
      path.startsWith('http') ? path : '${AppConstants.apiBaseUrl}$path';

  factory MailboxMessage.fromJson(Map<String, dynamic> j) {
    final dynamic imgs = j['images'];
    final List<String> images = <String>[];
    if (imgs is List) {
      for (final dynamic e in imgs) {
        if (e != null && e.toString().isNotEmpty) images.add(e.toString());
      }
    }
    final dynamic recs = j['recipients'];
    final List<MailboxRecipient> recipients = <MailboxRecipient>[];
    if (recs is List) {
      for (final dynamic e in recs) {
        if (e is Map<String, dynamic>) recipients.add(MailboxRecipient.fromJson(e));
      }
    }
    return MailboxMessage(
      id: (j['id'] as num?)?.toInt() ?? 0,
      senderId: (j['senderId'] as num?)?.toInt(),
      senderName: (j['senderName'] as String?) ?? '',
      content: (j['content'] as String?) ?? '',
      images: images,
      createTime: DateTime.tryParse((j['createTime'] as String?) ?? ''),
      readFlag: (j['readFlag'] as num?)?.toInt() ?? 0,
      recipients: recipients,
    );
  }
}

/// 发件箱中的收件人明细。
class MailboxRecipient {
  const MailboxRecipient({
    required this.recipientId,
    required this.name,
    this.readFlag = 0,
  });

  final int recipientId;
  final String name;
  final int readFlag;

  factory MailboxRecipient.fromJson(Map<String, dynamic> j) => MailboxRecipient(
        recipientId: (j['recipientId'] as num?)?.toInt() ?? 0,
        name: (j['recipientName'] as String?) ?? '',
        readFlag: (j['readFlag'] as num?)?.toInt() ?? 0,
      );
}

/// 可选收件人（员工名册）。
class MailboxUser {
  const MailboxUser({required this.id, required this.name, this.role = ''});

  final int id;
  final String name;
  final String role;

  factory MailboxUser.fromJson(Map<String, dynamic> j) => MailboxUser(
        id: (j['id'] as num?)?.toInt() ?? 0,
        name: (j['name'] as String?) ?? (j['username'] as String?) ?? '',
        role: (j['role'] as String?) ?? '',
      );
}

/// 员工信箱数据通道。
class MailboxRepository {
  MailboxRepository({ApiClient? client}) : _client = client ?? apiClient;
  final ApiClient _client;

  /// 收件箱（近 30 天发给我的）。
  Future<List<MailboxMessage>> inbox() async {
    final dynamic data = await _client.get('/api/mailbox/inbox');
    return _toList(data);
  }

  /// 发件箱（近 30 天我发出的）。
  Future<List<MailboxMessage>> outbox() async {
    final dynamic data = await _client.get('/api/mailbox/outbox');
    return _toList(data);
  }

  /// 未读条数。
  Future<int> unreadCount() async {
    final dynamic data = await _client.get('/api/mailbox/unread-count');
    return (data is num) ? data.toInt() : 0;
  }

  /// 信箱是否启用（受后台「员工信箱」流程模板状态控制）。
  Future<bool> enabled() async {
    try {
      final dynamic data = await _client.get('/api/mailbox/enabled');
      if (data is bool) return data;
      return data?.toString() == 'true';
    } catch (_) {
      return true; // 接口异常时不阻断使用
    }
  }

  /// 标记已读。
  Future<void> markRead(int id) async {
    await _client.post('/api/mailbox/$id/read', <String, dynamic>{});
  }

  /// 发送（recipientIds 多选即群发）。返回消息主键。
  Future<int> send({
    required List<int> recipientIds,
    String content = '',
    List<String> images = const <String>[],
  }) async {
    final dynamic data = await _client.post('/api/mailbox/send', <String, dynamic>{
      'content': content,
      'images': images,
      'recipientIds': recipientIds,
    });
    if (data is num) return data.toInt();
    if (data is Map<String, dynamic> && data['id'] is num) {
      return (data['id'] as num).toInt();
    }
    return 0;
  }

  /// 员工名册（用于选择收件人；后端 /api/system/users/search）。
  Future<List<MailboxUser>> listUsers({String? keyword}) async {
    final Map<String, dynamic> params = <String, dynamic>{'size': 200};
    if (keyword != null && keyword.isNotEmpty) params['keyword'] = keyword;
    final dynamic raw = await _client.get('/api/system/users/search', params: params);
    final List<dynamic> list = (raw is List) ? raw : <dynamic>[];
    return list
        .whereType<Map<String, dynamic>>()
        .map(MailboxUser.fromJson)
        .where((MailboxUser u) => u.id > 0 && u.name.isNotEmpty)
        .toList();
  }

  /// 上传图片，返回后端相对地址。
  Future<String> uploadImage(String filePath) => _client.uploadImage(filePath);

  List<MailboxMessage> _toList(dynamic data) {
    final List<dynamic> raw = (data is List) ? data : <dynamic>[];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(MailboxMessage.fromJson)
        .toList();
  }
}
