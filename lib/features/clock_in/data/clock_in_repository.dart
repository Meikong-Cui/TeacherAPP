import 'package:geolocator/geolocator.dart';
import 'package:teacher_app/core/constants.dart';
import 'package:teacher_app/data/models/campus.dart';
import 'package:teacher_app/data/models/clock_record.dart';
import 'package:teacher_app/features/clock_in/domain/geo.dart';

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

  /// 预留：签到记录保存至后端考勤接口。
  /// 当前未接后端，仅作占位；接入时替换为带 JWT 的 POST 请求。
  Future<void> saveRemote(ClockRecord record) async {
    // TODO(backend): 接入 Spring Boot 考勤接口
    // final resp = await http.post(
    //   Uri.parse('${AppConstants.apiBaseUrl}${AppConstants.attendanceClockInPath}'),
    //   headers: {'Authorization': 'Bearer <token>'},
    //   body: jsonEncode(record.toJson()),
    // );
    // if (resp.statusCode != 200) throw ClockInException('保存失败');
    return;
  }
}

/// 签到相关异常（携带中文提示）。
class ClockInException implements Exception {
  const ClockInException(this.message);
  final String message;
  @override
  String toString() => message;
}
