/// 校区。打卡地点按校区配置（经纬度为占位示例坐标，真实环境由后台下发）。
class Campus {
  const Campus({
    required this.id,
    required this.name,
    required this.isDefault,
    required this.latitude,
    required this.longitude,
  });

  final int id;
  final String name;
  final bool isDefault;
  final double latitude;
  final double longitude;

  /// 默认示范康复中心打卡点（示例坐标：北京·朝阳）。
  static const Campus defaultCampus = Campus(
    id: 1,
    name: '示范康复中心',
    isDefault: true,
    latitude: 39.9219,
    longitude: 116.4435,
  );

  static const List<Campus> all = <Campus>[
    defaultCampus,
    Campus(
      id: 2,
      name: '东城校区',
      isDefault: false,
      latitude: 39.9096,
      longitude: 116.4163,
    ),
    Campus(
      id: 3,
      name: '南城校区',
      isDefault: false,
      latitude: 39.8528,
      longitude: 116.4074,
    ),
  ];
}
