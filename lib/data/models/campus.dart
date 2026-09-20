import 'package:teacher_app/core/constants.dart';

/// 校区。
///
/// **数据只有唯一来源：后台 `sys_campus`** —— 由管理员在 OA 网页「学校管理」中
/// 维护，经 `GET /api/system/campuses` 下发。
///
/// 本类**不内置任何校区与坐标**。2026-09-20 之前这里写死了「呼兰 / 道里」两个
/// 校区（含真实经纬度），且后台某校区未配坐标时会按 id 把内置坐标顶上去
/// （旧的 `mergeBuiltinGeo`）。那套兜底已删除，理由：
///
/// 内置坐标是**某个时间点抄下来的固定值**，而管理员随时可能在后台改校区位置。
/// 一旦后台改了、App 又因网络抖动走了内置值，围栏就会拿**旧坐标**判距离 ——
/// 老师被拒打卡，界面上却照常显示「距打卡点 800 米」，看不出任何异常。
/// 「配置已更新、判定却在用旧值」这种故障无法从现象反推，所以宁可离线时用
/// **上次从后台拉取的真实数据**（UI 上标注数据时间），也绝不内置坐标。
///
/// 离线兜底见 [ClockInRepository.loadCampusCache] / `saveCampusCache`。
///
/// **坐标系必须是 WGS-84**：围栏判定全程不做坐标转换，输入（App 里 geolocator
/// 取到的 GPS）与配置同系，算出来的才是真实米数。高德底图的 GCJ-02 偏移只在
/// 绘图层处理（见 `features/clock_in/domain/geo.dart`）。
class Campus {
  const Campus({
    required this.id,
    required this.name,
    this.latitude,
    this.longitude,
    this.radiusMeters,
  });

  final int id;
  final String name;

  /// 打卡点纬度（WGS-84）。null = 该校区尚未配置坐标。
  final double? latitude;

  /// 打卡点经度（WGS-84）。null = 该校区尚未配置坐标。
  final double? longitude;

  /// 打卡围栏半径（米）。null = 用全局默认 [AppConstants.clockInRadiusMeters]。
  final double? radiusMeters;

  /// 该校区是否可以参与围栏判定与地图绘制。
  ///
  /// 不只看「非 null」，还要过一遍取值范围 —— 后台即使有脏数据（历史遗留、接口直调、
  /// 或把 0 当成「没填」），也不能让它变成一个**看起来正常的围栏**：
  /// 坐标 (0,0) 落在几内亚湾，距离约 1.1 万公里，老师会被判「超出围栏」，
  /// 而错误信息里没有任何东西指向「坐标其实没填」。
  ///
  /// 后端已在录入口拦新数据（见 `CampusController.validateGeo`），这里是防旧数据的第二道。
  bool get hasGeo {
    final double? lat = latitude;
    final double? lon = longitude;
    if (lat == null || lon == null) return false;
    if (lat < -90 || lat > 90 || lon < -180 || lon > 180) return false;
    // (0,0) 是几内亚湾里一个真实存在的点，但在本产品语境下必然是「没填」。
    if (lat.abs() < 1e-4 && lon.abs() < 1e-4) return false;
    return true;
  }

  /// 本校区实际生效的围栏半径（米）：优先用后台配置，否则回退全局默认。
  ///
  /// 半径 ≤ 0 一律视为「没配」，而不是「零米围栏」。因为 0 **不是 null**，
  /// `??` 兜不住它 —— 一旦落库成 0，全园老师都会被判「超出围栏 0 米」而打不了卡，
  /// 提示却写着「距打卡点 N 米」，完全没有指向性。这是本轮实测确认过的静默故障形态。
  double get effectiveRadius {
    final double? r = radiusMeters;
    if (r == null || r <= 0) return AppConstants.clockInRadiusMeters;
    return r;
  }

  /// 解析 `GET /api/system/campuses` 的一条记录。
  ///
  /// 经纬度/半径都是可空的：后台列允许为 NULL，表示「未配置」，
  /// 不能把 null 当 0 用（0,0 是几内亚湾里一个真实点，会静默算出一个巨大的距离）。
  factory Campus.fromJson(Map<String, dynamic> json) => Campus(
        id: (json['id'] as num?)?.toInt() ?? 0,
        name: (json['name'] ?? '').toString(),
        latitude: _toDouble(json['latitude']),
        longitude: _toDouble(json['longitude']),
        radiusMeters: _toDouble(json['clockRadius']),
      );

  /// 序列化，用于本地缓存（见 `ClockInRepository.saveCampusCache`）。
  ///
  /// key 刻意与后台字段名一致（`clockRadius`），使「缓存写盘 → 读回」与
  /// 「后台响应 → 解析」走**完全相同**的一条字段映射路径，
  /// 避免两套字段名导致缓存静默丢字段。
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        'clockRadius': radiusMeters,
      };

  static double? _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  /// 按 id 判等：校区可能来自后台列表的两次不同拉取，靠 id 才能让
  /// `DropdownButtonFormField` 在列表刷新后仍然认得出当前选中项。
  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Campus && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Campus($id, $name, geo=$hasGeo, r=$radiusMeters)';
}
