import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:teacher_app/core/app_navigator.dart';
import 'package:teacher_app/data/models/rehab.dart';
import 'package:teacher_app/features/notice/data/notice_repository.dart';

/// 本地系统通知服务。
/// - 康复档案待办到期提醒（原有功能）
/// - 后端通知 / 预警 / 公告推送：能处理的跳转对应页面，处理不了的提示"请前往网页处理"
class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'rehab_reminder';
  static const String _channelName = '康复档案提醒';
  static const String _noticeChannelId = 'oa_notice';
  static const String _noticeChannelName = 'OA 通知';

  static bool _initialized = false;
  static final Set<String> _notifiedTaskIds = <String>{};
  static final Set<int> _notifiedNoticeIds = <int>{};
  static NoticeRepository? _noticeRepo;

  static void setNoticeRepository(NoticeRepository repo) => _noticeRepo = repo;

  static Future<void> init() async {
    const AndroidInitializationSettings android =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    final DarwinInitializationSettings ios = DarwinInitializationSettings(
      onDidReceiveLocalNotification: (id, title, body, payload) {
        _handleTap(payload);
      },
    );
    final InitializationSettings settings = InitializationSettings(
      android: android,
      iOS: ios,
    );
    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (NotificationResponse resp) {
        _handleTap(resp.payload);
      },
    );

    final AndroidFlutterLocalNotificationsPlugin? androidImpl =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl != null) {
      await androidImpl.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: '康复档案待办到期提醒',
          importance: Importance.high,
        ),
      );
      await androidImpl.createNotificationChannel(
        const AndroidNotificationChannel(
          _noticeChannelId,
          _noticeChannelName,
          description: 'OA 通知、预警与公告',
          importance: Importance.high,
        ),
      );
      try {
        await androidImpl.requestNotificationsPermission();
      } catch (_) {
        /* 低版本无此方法，忽略 */
      }
    }
    _initialized = true;
  }

  /// 显式弹出一条康复提醒。
  static Future<void> showRehabReminder(String title, String body) async {
    if (!_initialized) await init();
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: '康复档案待办到期提醒',
      importance: Importance.high,
      priority: Priority.high,
    );
    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );
    await _plugin.show(title.hashCode, title, body, details);
  }

  /// 遍历待办任务，对 7 天内到期或逾期且未提醒过的弹出系统通知。
  static Future<void> notifyRehabTasks(List<RehabTask> tasks) async {
    if (!_initialized) await init();
    final DateTime now = DateTime.now();
    for (final RehabTask t in tasks) {
      if (t.completed) continue;
      if (_notifiedTaskIds.contains(t.id)) continue;
      final int days = t.dueDate.difference(now).inDays;
      if (days <= 7) {
        final String when = days < 0
            ? '已逾期'
            : (days == 0 ? '今天到期' : '$days 天后到期');
        await showRehabReminder(
          t.title,
          '$when · 截止 ${DateFormat('yyyy-MM-dd').format(t.dueDate)}',
        );
        _notifiedTaskIds.add(t.id);
      }
    }
  }

  /// 测试/演示用：清空已提醒记录，便于重复演示。
  static void resetNotified() {
    _notifiedTaskIds.clear();
    _notifiedNoticeIds.clear();
  }

  /// 轮询后端未读通知并推送本地通知。
  /// 建议在首页 [HomeScreen] 启动后周期性调用（如进入首页、每 60 秒）。
  static Future<void> pollNotices() async {
    if (!_initialized) await init();
    if (_noticeRepo == null) return;
    try {
      final List<Map<String, dynamic>> list =
          await _noticeRepo!.fetchNotices(view: 'unread');
      for (final n in list) {
        final int id = (n['id'] as int?) ?? 0;
        if (id == 0 || _notifiedNoticeIds.contains(id)) continue;
        final String type = (n['type'] as String?) ?? 'notice';
        final String title = (n['title'] as String?) ?? 'OA 通知';
        final String content = (n['content'] as String?) ?? '';
        final String payload = '$id|$type|$title';
        await _showNotice(title, content, payload);
        _notifiedNoticeIds.add(id);
      }
    } catch (_) {
      // 网络异常时静默，避免打扰
    }
  }

  static Future<void> _showNotice(String title, String body, String payload) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      _noticeChannelId,
      _noticeChannelName,
      channelDescription: 'OA 通知、预警与公告',
      importance: Importance.high,
      priority: Priority.high,
    );
    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );
    await _plugin.show(payload.hashCode, title, body, details);
  }

  /// 通过全局 navigatorKey 跳转（避免导入 app/router.dart 造成循环依赖）。
  static void _navigateTo(String path) {
    final BuildContext? ctx = appNavigatorKey.currentContext;
    if (ctx != null) GoRouter.of(ctx).go(path);
  }

  static void _handleTap(String? payload) {
    if (payload == null || payload.isEmpty) return;
    final parts = payload.split('|');
    if (parts.length < 3) return;
    final String type = parts[1];
    final int id = int.tryParse(parts[0]) ?? 0;

    // 能处理的类型直接跳转，处理不了的弹窗提醒到网页处理
    switch (type) {
      case 'reimbursement':
        _navigateTo('/reimbursement/list');
        break;
      case 'seal':
        _navigateTo('/seal/list');
        break;
      case 'task':
      case 'notice':
        _navigateTo('/office');
        break;
      case 'alert':
      case 'warning':
      default:
        _showWebOnlyDialog();
        break;
    }
    // 标记已读（忽略错误）
    if (id > 0) {
      _noticeRepo?.markRead(id).catchError((_) {});
    }
  }

  static void _showWebOnlyDialog() {
    final BuildContext? ctx = appNavigatorKey.currentContext;
    if (ctx == null) return;
    showDialog(
      context: ctx,
      builder: (context) => AlertDialog(
        title: const Text('请在网页端处理'),
        content: const Text('该事项目前仅在 OA 网页端支持处理，请前往网页完成。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }
}
