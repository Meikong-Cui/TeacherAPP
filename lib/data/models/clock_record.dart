import 'package:flutter/material.dart';

/// 打卡类型：上班 / 下班。
enum ClockType {
  checkIn('上班', Icons.login),
  checkOut('下班', Icons.logout);

  const ClockType(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// 一条打卡记录（本地演示 + 预留后端保存接口）。
class ClockRecord {
  const ClockRecord({
    required this.type,
    required this.time,
    required this.campusName,
    required this.latitude,
    required this.longitude,
    required this.distanceMeters,
    required this.withinFence,
  });

  final ClockType type;
  final DateTime time;
  final String campusName;
  final double latitude;
  final double longitude;
  final double distanceMeters;
  final bool withinFence;

  String get distanceText =>
      distanceMeters < 1000
          ? '${distanceMeters.toStringAsFixed(0)} m'
          : '${(distanceMeters / 1000).toStringAsFixed(2)} km';

  Map<String, dynamic> toJson() => <String, dynamic>{
        'type': type.name,
        'time': time.toIso8601String(),
        'campusName': campusName,
        'latitude': latitude,
        'longitude': longitude,
        'distanceMeters': distanceMeters,
        'withinFence': withinFence,
      };
}
