import 'package:flutter/material.dart';

/// 打卡类型：上班 / 下班。
enum ClockType {
  checkIn('上班', Icons.login),
  checkOut('下班', Icons.logout);

  const ClockType(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// 一条打卡记录（本地留存 + 后台同步）。
class ClockRecord {
  const ClockRecord({
    required this.type,
    required this.time,
    required this.campusName,
    required this.latitude,
    required this.longitude,
    required this.distanceMeters,
    required this.withinFence,
    this.synced = false,
    this.degradedLocation = false,
    this.id,
  });

  final ClockType type;
  final DateTime time;
  final String campusName;
  final double latitude;
  final double longitude;
  final double distanceMeters;
  final bool withinFence;

  /// 是否已成功同步到后台。false 表示「已打卡但待同步」，会本地留存并可重试。
  final bool synced;

  /// 定位降级：高精度定位失败/超时，改用「上次已知位置」完成打卡。
  /// 仅作提示与留痕，仍照常参与围栏判定。
  final bool degradedLocation;

  /// 本地唯一 id（用于待同步队列重试定位该条记录）。
  final String? id;

  ClockRecord copyWith({
    ClockType? type,
    DateTime? time,
    String? campusName,
    double? latitude,
    double? longitude,
    double? distanceMeters,
    bool? withinFence,
    bool? synced,
    bool? degradedLocation,
    String? id,
  }) =>
      ClockRecord(
        type: type ?? this.type,
        time: time ?? this.time,
        campusName: campusName ?? this.campusName,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        distanceMeters: distanceMeters ?? this.distanceMeters,
        withinFence: withinFence ?? this.withinFence,
        synced: synced ?? this.synced,
        degradedLocation: degradedLocation ?? this.degradedLocation,
        id: id ?? this.id,
      );

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
        'synced': synced,
        'degradedLocation': degradedLocation,
        if (id != null) 'id': id,
      };

  /// 从本地待同步队列反序列化。解析失败返回 null，避免一条坏数据卡死整个队列。
  static ClockRecord? fromJson(Map<String, dynamic> json) {
    final DateTime? time = DateTime.tryParse(json['time']?.toString() ?? '');
    if (time == null) return null;
    final ClockType type = ClockType.values.firstWhere(
      (e) => e.name == json['type'],
      orElse: () => ClockType.checkIn,
    );
    double? d(String k) =>
        json[k] is num ? (json[k] as num).toDouble() : double.tryParse(json[k]?.toString() ?? '');
    return ClockRecord(
      type: type,
      time: time,
      campusName: json['campusName']?.toString() ?? '',
      latitude: d('latitude') ?? 0,
      longitude: d('longitude') ?? 0,
      distanceMeters: d('distanceMeters') ?? 0,
      withinFence: json['withinFence'] == true,
      synced: json['synced'] == true,
      degradedLocation: json['degradedLocation'] == true,
      id: json['id']?.toString(),
    );
  }
}
