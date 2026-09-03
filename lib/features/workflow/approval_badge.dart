import 'dart:async';

import 'package:flutter_app_badger/flutter_app_badger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teacher_app/features/workflow/workflow_repository.dart';

/// 审批待办 + 未读通知 的合计角标数。
///
/// 数据来自后端聚合接口 `GET /api/approval/summary`
/// （todoTotal + noticeUnread，一次请求拿全，避免多接口轮询）。
///
/// 轮询放在本 provider 而不是首页：首页的 Timer 离开首页就停了，
/// 底部导航的红点必须**全局**常驻刷新。provider 被 AppShell watch 后常驻，
/// 每 60 秒自动刷新；审批页 / 通知页操作完也可调 [refresh] 立即更新。
///
/// 数值变化时同步写**桌面 App 图标角标**（iOS applicationIconBadgeNumber /
/// Android 厂商 ShortcutBadger）。失败静默忽略——桌面角标是增强项，
/// 不能因为个别 ROM 不支持而影响应用内红点。
class ApprovalBadgeNotifier extends StateNotifier<int> {
  ApprovalBadgeNotifier() : super(0) {
    refresh();
    _timer = Timer.periodic(const Duration(seconds: 60), (_) => refresh());
  }

  final WorkflowRepository _repo = WorkflowRepository();
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> refresh() async {
    try {
      final Map<String, dynamic> s = await _repo.fetchSummary();
      final int todo = (s['todoTotal'] as num?)?.toInt() ?? 0;
      final int unread = (s['noticeUnread'] as num?)?.toInt() ?? 0;
      final int total = todo + unread;
      if (total != state) {
        state = total;
        unawaited(_syncDesktopBadge(total));
      }
    } catch (_) {
      // 网络异常时保留上次数值，不把错误抛给 UI。
    }
  }

  /// 同步桌面图标角标：>0 显示数字，=0 清除。
  Future<void> _syncDesktopBadge(int count) async {
    try {
      final bool supported = await FlutterAppBadger.isAppBadgeSupported();
      if (!supported) return;
      if (count > 0) {
        await FlutterAppBadger.updateBadgeCount(count);
      } else {
        await FlutterAppBadger.removeBadge();
      }
    } catch (_) {
      // 个别 ROM / 模拟器不支持时静默忽略。
    }
  }
}

final StateNotifierProvider<ApprovalBadgeNotifier, int> approvalBadgeProvider =
    StateNotifierProvider<ApprovalBadgeNotifier, int>(
        (ref) => ApprovalBadgeNotifier());
