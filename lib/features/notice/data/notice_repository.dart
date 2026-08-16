import 'package:teacher_app/core/api_client.dart';

class NoticeRepository {
  final ApiClient _client;
  NoticeRepository({ApiClient? client}) : _client = client ?? apiClient;

  /// 拉取通知列表；view=unread 仅未读。
  Future<List<Map<String, dynamic>>> fetchNotices({String? view}) async {
    final dynamic data = await _client.get('/api/notices${view != null ? '?view=$view' : ''}');
    if (data is List) {
      return data.cast<Map<String, dynamic>>();
    }
    return <Map<String, dynamic>>[];
  }

  /// 标记通知已读。
  Future<void> markRead(int id) async {
    await _client.post('/api/notices/$id/read');
  }
}
