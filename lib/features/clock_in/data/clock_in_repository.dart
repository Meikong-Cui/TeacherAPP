import 'dart:async';
import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teacher_app/core/api_client.dart';
import 'package:teacher_app/core/auth_store.dart';
import 'package:teacher_app/core/constants.dart';
import 'package:teacher_app/data/models/campus.dart';
import 'package:teacher_app/data/models/clock_record.dart';
import 'package:teacher_app/features/clock_in/domain/geo.dart';

/// 后台「工作提示-员工打卡」对应的 oa_record 分类（与 OA 网页 oaRecordConfig.ts 一致）。
const String _staffClockCategory = 'staff-clock';

/// 实时定位的最长等待时间。超时后降级为「上次已知位置」，
/// 避免 GPS 无信号时 Future 一直不返回（表现为打卡按钮永久转圈/置灰）。
const Duration kLocationTimeout = Duration(seconds: 15);

/// 本地待同步队列的持久化 key。
const String _pendingKey = 'clock_in_pending_records';

/// 签到数据层：定位、围栏距离计算、后端保存（预留）。
class ClockInRepository {
  const ClockInRepository();

  /// 默认打卡地点（真实环境由后台按校区下发）。
  Campus get defaultCampus => Campus.defaultCampus;

  /// 计算到指定校区的球面距离（米）。
  double distanceTo({
    required Campus campus,
    required double latitude,
    required double longitude,
  }) =>
      haversineDistance(
        lat1: campus.latitude,
        lon1: campus.longitude,
        lat2: latitude,
        lon2: longitude,
      );

  /// 是否在允许围栏内（≤ 1000 米）。
  bool isWithinFence(double distanceMeters) =>
      distanceMeters <= AppConstants.clockInRadiusMeters;

  /// 获取当前定位（含权限申请、超时与降级兜底）。
  ///
  /// 保证：**要么返回 [LocationFix]，要么抛 [ClockInException]，
  /// 不会无限挂起**。修复前直接调 `Geolocator.getCurrentPosition()` 且不带
  /// `timeLimit`，GPS 拿不到信号时 Future 永不完成，打卡页会一直转圈、
  /// 两个按钮永久置灰且无任何提示。
  Future<LocationFix> acquireLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const ClockInException(
          '定位服务未开启，无法打卡。请在系统设置中打开定位后重试。');
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw const ClockInException('定位权限被拒绝，无法签到');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw const ClockInException('定位权限已被永久拒绝，请在系统设置中开启');
    }

    try {
      final Position p = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: kLocationTimeout,
      );
      return LocationFix(position: p, degraded: false);
    } on TimeoutException {
      return _fallbackToLastKnown(
          '定位超时（${kLocationTimeout.inSeconds} 秒未取得位置），已改用最近一次已知位置打卡');
    } catch (e) {
      return _fallbackToLastKnown('定位失败，已改用最近一次已知位置打卡（$e）');
    }
  }

  /// 降级取「上次已知位置」。拿不到就抛出明确异常，由上层给出可操作提示。
  Future<LocationFix> _fallbackToLastKnown(String degradedReason) async {
    try {
      final Position? last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        return LocationFix(
          position: last,
          degraded: true,
          degradedReason: degradedReason,
        );
      }
    } catch (_) {
      // 忽略：落到下面的异常分支
    }
    throw const ClockInException(
        '定位失败且无可用位置信息。请到开阔地带、开启 Wi‑Fi/移动网络辅助定位后重试，'
        '或改用「补卡申请」。');
  }

  // ── 本地待同步队列（网络失败时兜底，避免打卡记录丢失）──

  /// 读取上次未成功同步的打卡记录。
  Future<List<ClockRecord>> loadPending() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? raw = prefs.getString(_pendingKey);
      if (raw == null || raw.isEmpty) return const <ClockRecord>[];
      final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map<String, dynamic>>()
          .map(ClockRecord.fromJson)
          .whereType<ClockRecord>()
          .toList();
    } catch (_) {
      // 解析失败不能让整个打卡页挂掉，按空队列处理。
      return const <ClockRecord>[];
    }
  }

  /// 持久化尚未同步成功的记录（App 被杀掉后下次启动仍可重发）。
  Future<void> persistPending(List<ClockRecord> records) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      if (records.isEmpty) {
        await prefs.remove(_pendingKey);
        return;
      }
      await prefs.setString(
        _pendingKey,
        jsonEncode(records.map((ClockRecord r) => r.toJson()).toList()),
      );
    } catch (_) {
      // 持久化失败不阻塞打卡主流程
    }
  }

  /// 签到记录保存至后台「工作提示-员工打卡」页（oa_record, category=staff-clock）。
  ///
  /// 该分类由 OA 网页 oaRecordConfig.ts 的 `staff-clock` 配置驱动，列表展示
  /// [姓名 / 日期 / 上班时间 / 下班时间 / 状态]；本方法构造完全一致的 content，
  /// 使 APP 打完卡后，后台该页面能立即新增一条记录。
  Future<void> saveRemote(ClockRecord record) async {
    final String employee = AuthStore.instance.userName ?? '教师';

    final Map<String, Object> content = <String, Object>{
      'employee': employee,
      'clockDate': _dateOf(record.time),
      'statusLabel': _statusLabelOf(record),
    };
    if (record.type == ClockType.checkIn) {
      content['onTime'] = _timeOf(record.time);
    } else {
      content['offTime'] = _timeOf(record.time);
    }

    final Map<String, dynamic> payload = <String, dynamic>{
      'category': _staffClockCategory,
      'recordTitle': employee,
      'content': content,
      'status': 2, // 已完成（与 staff-clock 默认状态一致）
      'creatorName': employee,
    };

    try {
      await apiClient.post('/api/oa/record', payload);
    } on ApiException catch (e) {
      // 透传后端业务错误，便于签到页给出明确提示。
      throw ClockInException('打卡记录同步失败：${e.message}');
    } catch (e) {
      throw ClockInException('打卡记录同步失败：$e');
    }
  }
}

/// yyyy-MM-dd
String _dateOf(DateTime t) =>
    '${t.year}-${_pad(t.month)}-${_pad(t.day)}';

/// HH:mm
String _timeOf(DateTime t) => '${_pad(t.hour)}:${_pad(t.minute)}';

String _pad(int n) => n.toString().padLeft(2, '0');

/// 上班晚于 09:00 记为「迟到」，下班早于 18:00 记为「早退」，其余「正常」。
String _statusLabelOf(ClockRecord record) {
  if (record.type == ClockType.checkIn) {
    return record.time.hour >= 9 ? '迟到' : '正常';
  }
  return record.time.hour < 18 ? '早退' : '正常';
}

/// 签到相关异常（携带中文提示）。
class ClockInException implements Exception {
  const ClockInException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// 一次定位结果。
///
/// [degraded] 为 true 表示高精度定位超时/失败，使用的是「上次已知位置」，
/// 位置可能偏旧 —— 该标记会随打卡记录一起留痕，便于人工核对。
class LocationFix {
  const LocationFix({
    required this.position,
    this.degraded = false,
    this.degradedReason,
  });

  final Position position;
  final bool degraded;
  final String? degradedReason;

  double get latitude => position.latitude;
  double get longitude => position.longitude;
}
