import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:teacher_app/data/models/rehab.dart';

/// 本地系统通知服务（决策 #3：康复档案提醒同时推送手机系统通知）。
///
/// 应用启动时调用 [init]；档案待办加载后调用 [notifyRehabTasks]，
/// 对 7 天内到期或已逾期的待办弹出系统通知（每条仅提醒一次，避免刷屏）。
class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'rehab_reminder';
  static const String _channelName = '康复档案提醒';

  static bool _initialized = false;
  static final Set<String> _notified = <String>{};

  static Future<void> init() async {
    const AndroidInitializationSettings android =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings ios = DarwinInitializationSettings();
    const InitializationSettings settings =
        InitializationSettings(android: android, iOS: ios);
    await _plugin.initialize(settings);

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
      // Android 13+ 需显式申请通知权限。
      try {
        await androidImpl.requestNotificationsPermission();
      } catch (_) {
        /* 低版本无此方法，忽略 */
      }
    }
    _initialized = true;
  }

  /// 显式弹出一条康复提醒（供手动触发 / 演示）。
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
      if (_notified.contains(t.id)) continue;
      final int days = t.dueDate.difference(now).inDays;
      if (days <= 7) {
        final String when = days < 0
            ? '已逾期'
            : (days == 0 ? '今天到期' : '$days 天后到期');
        await showRehabReminder(
          t.title,
          '$when · 截止 ${DateFormat('yyyy-MM-dd').format(t.dueDate)}',
        );
        _notified.add(t.id);
      }
    }
  }

  /// 测试/演示用：清空已提醒记录，便于重复演示。
  static void resetNotified() => _notified.clear();
}
