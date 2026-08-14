/// 校区。打卡地点按校区配置（经纬度为真实坐标，真实环境可由后台下发覆盖）。
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

  /// 默认打卡点（呼兰校区）。
  static const Campus defaultCampus = Campus(
    id: 1,
    name: '呼兰校区',
    isDefault: true,
    latitude: 45.98555,
    longitude: 126.599363,
  );

  static const List<Campus> all = <Campus>[
    defaultCampus,
    Campus(
      id: 2,
      name: '道里小区',
      isDefault: false,
      latitude: 45.732986,
      longitude: 126.587281,
    ),
  ];
}
