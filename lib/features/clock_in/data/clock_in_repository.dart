import 'package:geolocator/geolocator.dart';
import 'package:teacher_app/core/api_client.dart';
import 'package:teacher_app/core/auth_store.dart';
import 'package:teacher_app/core/constants.dart';
import 'package:teacher_app/data/models/campus.dart';
import 'package:teacher_app/data/models/clock_record.dart';
import 'package:teacher_app/features/clock_in/domain/geo.dart';

/// 后台「工作提示-员工打卡」对应的 oa_record 分类（与 OA 网页 oaRecordConfig.ts 一致）。
const String _staffClockCategory = 'staff-clock';

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

  /// 获取当前定位（含权限申请）。真实设备 / 模拟器可用。
  Future<Position> getCurrentPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const ClockInException('请先开启设备的定位服务');
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
    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
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
