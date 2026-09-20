import 'dart:math';

/// 地理计算：Haversine 球面距离（米）。
double haversineDistance({
  required double lat1,
  required double lon1,
  required double lat2,
  required double lon2,
}) {
  const double earthRadius = 6371000.0; // 米
  final double dLat = _toRadians(lat2 - lat1);
  final double dLon = _toRadians(lon2 - lon1);
  final double a = _square(sin(dLat / 2)) +
      cos(_toRadians(lat1)) *
          cos(_toRadians(lat2)) *
          _square(sin(dLon / 2));
  final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return earthRadius * c;
}

double _toRadians(double deg) => deg * pi / 180;

double _square(double v) => v * v;

// ══════════════════════════════════════════════════════════════════════
// 坐标系：WGS-84 → GCJ-02
//
// 为什么只有单向、而且只给地图用：
//   · 打卡点坐标（后台 sys_campus.latitude/longitude）与 GPS 都是 WGS-84，
//     **围栏判定全程不做任何坐标转换** —— 输入与配置同系，算出来的就是真实米数，
//     不受转换实现正确与否影响。
//   · 高德底图用的是 GCJ-02（火星坐标），把 WGS-84 的点直接画上去会偏 300~600 米。
//     所以转换只发生在地图组件里，只影响「点画在哪」。
// 这样分工的收益：绘图偏了是**看得见的错位**，用户当场能发现并反馈；
// 而围栏中心偏了是**静默**的（人在楼里却被拒打卡），几乎不可能被发现。宁可错在明处。
//
// 算法是公开的 GCJ-02 偏移式（无解析反函数）。此处只用正向，反向换算由
// 仓库 tools/gcj02_to_wgs84.py 提供给管理员录坐标时使用。
// ══════════════════════════════════════════════════════════════════════

const double _gcjA = 6378245.0;
const double _gcjEe = 0.00669342162296594323;

/// 是否在中国境外 —— GCJ-02 的偏移只在国内生效，境外必须原样返回。
bool isOutOfChina(double lat, double lng) =>
    !(lng > 72.004 && lng < 137.8347 && lat > 0.8293 && lat < 55.8271);

double _transformLat(double x, double y) {
  double ret = -100.0 +
      2.0 * x +
      3.0 * y +
      0.2 * y * y +
      0.1 * x * y +
      0.2 * sqrt(x.abs());
  ret += (20.0 * sin(6.0 * x * pi) + 20.0 * sin(2.0 * x * pi)) * 2.0 / 3.0;
  ret += (20.0 * sin(y * pi) + 40.0 * sin(y / 3.0 * pi)) * 2.0 / 3.0;
  ret += (160.0 * sin(y / 12.0 * pi) + 320.0 * sin(y * pi / 30.0)) * 2.0 / 3.0;
  return ret;
}

double _transformLng(double x, double y) {
  double ret =
      300.0 + x + 2.0 * y + 0.1 * x * x + 0.1 * x * y + 0.1 * sqrt(x.abs());
  ret += (20.0 * sin(6.0 * x * pi) + 20.0 * sin(2.0 * x * pi)) * 2.0 / 3.0;
  ret += (20.0 * sin(x * pi) + 40.0 * sin(x / 3.0 * pi)) * 2.0 / 3.0;
  ret += (150.0 * sin(x / 12.0 * pi) + 300.0 * sin(x / 30.0 * pi)) * 2.0 / 3.0;
  return ret;
}

/// WGS-84 → GCJ-02。**仅用于在高德底图上定位**，不要拿结果参与围栏判定。
({double lat, double lng}) wgs84ToGcj02(double lat, double lng) {
  if (isOutOfChina(lat, lng)) return (lat: lat, lng: lng);
  double dLat = _transformLat(lng - 105.0, lat - 35.0);
  double dLng = _transformLng(lng - 105.0, lat - 35.0);
  final double radLat = lat / 180.0 * pi;
  double magic = sin(radLat);
  magic = 1 - _gcjEe * magic * magic;
  final double sqrtMagic = sqrt(magic);
  dLat = (dLat * 180.0) / ((_gcjA * (1 - _gcjEe)) / (magic * sqrtMagic) * pi);
  dLng = (dLng * 180.0) / (_gcjA / sqrtMagic * cos(radLat) * pi);
  return (lat: lat + dLat, lng: lng + dLng);
}
