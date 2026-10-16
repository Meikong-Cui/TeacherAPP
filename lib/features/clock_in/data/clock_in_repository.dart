import 'dart:async';
import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teacher_app/core/api_client.dart';
import 'package:teacher_app/data/models/campus.dart';
import 'package:teacher_app/data/models/clock_record.dart';
import 'package:teacher_app/features/clock_in/domain/attendance.dart';
import 'package:teacher_app/features/clock_in/domain/geo.dart';

/// 实时定位的最长等待时间。超时后降级为「上次已知位置」，
/// 避免 GPS 无信号时 Future 一直不返回（表现为打卡按钮永久转圈/置灰）。
const Duration kLocationTimeout = Duration(seconds: 15);

/// 本地待同步队列的持久化 key。
const String _pendingKey = 'clock_in_pending_records';

/// 上次手动选择的打卡校区 id 的持久化 key。
const String _selectedCampusKey = 'clock_in_selected_campus_id';

/// 校区列表本地缓存的持久化 key。
///
/// 带版本后缀：缓存结构将来若变更，换掉 key 即可让旧格式自然失效，
/// 不必写迁移代码（读到不认识的格式会被 [ClockInRepository.loadCampusCache] 判为无效）。
const String _campusCacheKey = 'clock_in_campus_cache_v1';

/// 一份从后台成功拉取过的校区列表缓存。
///
/// 存在的意义：让 App **不需要内置任何校区坐标**也能在离线时打卡 ——
/// 用的仍然是后台真实下发过的数据，只是可能陈旧；陈旧度由 [cachedAt] 明确告知用户。
class CampusCache {
  const CampusCache({required this.campuses, required this.cachedAt});

  final List<Campus> campuses;

  /// 这份数据是什么时候从后台拉到的。
  final DateTime cachedAt;
}

/// 签到数据层：定位、围栏距离计算、后端保存（预留）。
class ClockInRepository {
  const ClockInRepository();

  /// 拉取后台校区列表（含打卡坐标与围栏半径，由 OA 网页「学校管理」维护）。
  ///
  /// 返回 null 表示**没拿到后台数据**（网络失败 / 权限不足 / 后端未就绪），
  /// 由调用方回退到**本地缓存** [loadCampusCache] —— 注意不是回退到内置数据，
  /// 本 App 已不再内置任何校区。
  ///
  /// 成功时顺带把结果写入缓存（写失败不影响本次打卡），供离线时使用。
  Future<List<Campus>?> listCampuses() async {
    try {
      final dynamic data = await apiClient.get(
        '/api/system/campuses',
        params: <String, dynamic>{'current': 1, 'size': 200},
      );
      final dynamic records = (data is Map) ? data['records'] : data;
      if (records is! List) return null;
      final List<Campus> list = records
          .whereType<Map>()
          .map((Map e) => Campus.fromJson(Map<String, dynamic>.from(e)))
          .where((Campus c) => c.id > 0 && c.name.isNotEmpty)
          .toList();
      if (list.isEmpty) return null;
      // 不 await：缓存写盘失败只影响「下次离线时的兜底」，不能影响本次打卡。
      unawaited(saveCampusCache(list));
      return list;
    } catch (_) {
      // 静默降级为「没拿到」，由上层决定用缓存还是给出失败态。
      return null;
    }
  }

  /// 读取上次成功拉取的校区列表缓存。
  ///
  /// 没有缓存 / 格式不认 / 解析失败一律返回 null（由上层转为明确的失败态 + 重试入口）。
  /// 这里**不返回空列表**：空列表会被上层当成「后台说没有校区」，与「没有缓存」
  /// 是不同的语义，混在一起会让失败提示说不清原因。
  Future<CampusCache?> loadCampusCache() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? raw = prefs.getString(_campusCacheKey);
      if (raw == null || raw.isEmpty) return null;
      final dynamic decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final dynamic listRaw = decoded['list'];
      if (listRaw is! List) return null;
      final List<Campus> list = listRaw
          .whereType<Map>()
          .map((Map e) => Campus.fromJson(Map<String, dynamic>.from(e)))
          .where((Campus c) => c.id > 0 && c.name.isNotEmpty)
          .toList();
      if (list.isEmpty) return null;
      // 时间戳解析不出来时用「现在」而不是 null：宁可让提示显示的陈旧度偏乐观，
      // 也不能因为缺个时间戳就把整份真实数据丢掉、让用户断网时无法打卡。
      final DateTime cachedAt =
          DateTime.tryParse((decoded['at'] ?? '').toString()) ?? DateTime.now();
      return CampusCache(campuses: list, cachedAt: cachedAt);
    } catch (_) {
      return null;
    }
  }

  /// 把刚拉到的校区列表写入本地缓存（含拉取时间）。
  ///
  /// 列表与时间戳存在**同一个 JSON** 里而不是两个 key：两个 key 会出现
  /// 「列表已更新、时间戳没更新」的中间状态，让陈旧度提示说谎。
  Future<void> saveCampusCache(List<Campus> campuses) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _campusCacheKey,
        jsonEncode(<String, dynamic>{
          'at': DateTime.now().toIso8601String(),
          'list': campuses.map((Campus c) => c.toJson()).toList(),
        }),
      );
    } catch (_) {
      // 忽略：缓存写失败不影响本次打卡主流程。
    }
  }

  /// 计算到指定校区的球面距离（米）。
  ///
  /// 校区未配置坐标时返回 null —— 调用方必须显式处理。**不要退化成 0**：
  /// 0 会被当成「就站在打卡点上」而放行，比报错危险得多。
  ///
  /// 入参与校区坐标同为 WGS-84，此处**不做任何坐标转换**
  /// （坐标系的取舍见 `domain/geo.dart` 顶部的说明）。
  double? distanceTo({
    required Campus campus,
    required double latitude,
    required double longitude,
  }) {
    final double? lat = campus.latitude;
    final double? lon = campus.longitude;
    if (lat == null || lon == null) return null;
    return haversineDistance(
      lat1: lat,
      lon1: lon,
      lat2: latitude,
      lon2: longitude,
    );
  }

  /// 是否在该校区允许的围栏内（半径取校区配置，未配置时回退全局默认）。
  bool isWithinFence(Campus campus, double distanceMeters) =>
      distanceMeters <= campus.effectiveRadius;

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

  // ── 打卡校区的记忆（下次进入页面时恢复上次选择）──

  /// 读取上次手动选择的校区 id。没存过或读失败都返回 null。
  Future<int?> loadSelectedCampusId() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_selectedCampusKey);
    } catch (_) {
      return null;
    }
  }

  /// 记住本次选择的校区 id。失败只影响「下次进入的默认值」，不阻塞打卡主流程。
  Future<void> persistSelectedCampusId(int id) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_selectedCampusKey, id);
    } catch (_) {
      // 忽略
    }
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

  /// 拉取「今日考勤」视图：本人生效班次 + 当天已打卡时间 + 服务器时间。
  ///
  /// 打卡页靠它决定「现在该打上班卡还是下班卡」「这一下算不算迟到」，
  /// 而不是在客户端写死 9:00 / 18:00（校区改时间后会集体误判）。
  ///
  /// 返回 null 表示没拿到（未登录 / 网络失败 / 后端未升级到该接口）。
  /// **拿不到不是阻断性失败**：调用方退回「只用本地记录判断按钮」，照样能打卡。
  Future<AttendanceToday?> fetchAttendanceToday() async {
    try {
      final dynamic data = await apiClient.get('/api/oa/record/attendance-today');
      if (data is! Map) return null;
      final AttendanceToday a =
          AttendanceToday.fromJson(Map<String, dynamic>.from(data));
      // 后台若还没配过考勤时间会回空串，落到模型默认值（09:00 / 18:00）。
      return a;
    } catch (_) {
      return null;
    }
  }

  /// 提交一次打卡到后台（oa_record, category=staff-clock）。
  ///
  /// 与旧的 `POST /api/oa/record` 的区别：那条每次调用都**新增**一条记录，
  /// 而下班卡允许反复刷新（走得晚、忘了打再补打），会让后台「员工打卡」列表
  /// 同一天堆出多行。现在改走 `/clock`，由服务端按「员工 + 日期」合并：
  /// 上班取最早、下班取最晚，一天恒定一行。
  ///
  /// 时间传客户端的打卡时刻（'HH:mm:ss'）：离线留存后补传时「打卡那一刻」已经
  /// 过去，只能以客户端记录为准；非法则由服务端按当时时间兜底。
  Future<ClockSubmitResult> submitClock(ClockRecord record) async {
    final Map<String, dynamic> payload = <String, dynamic>{
      'type': record.type == ClockType.checkIn ? 'IN' : 'OUT',
      'time': _secondOf(record.time),
      if (record.campusId != null) 'campusId': record.campusId!,
      'lat': record.latitude,
      'lng': record.longitude,
    };

    try {
      final dynamic data = await apiClient.post('/api/oa/record/clock', payload);
      if (data is! Map) {
        throw const ClockInException('打卡记录同步失败：后台返回格式异常');
      }
      return ClockSubmitResult.fromJson(
          record.type, Map<String, dynamic>.from(data));
    } on ApiException catch (e) {
      // 透传后端业务错误，便于签到页给出明确提示。
      throw ClockInException('打卡记录同步失败：${e.message}');
    } on ClockInException {
      rethrow;
    } catch (e) {
      throw ClockInException('打卡记录同步失败：$e');
    }
  }
}

/// HH:mm:ss —— 打卡时刻上送到秒（后台 onTime/offTime 仍是 HH:mm，秒值单独留痕）。
String _secondOf(DateTime t) =>
    '${_pad(t.hour)}:${_pad(t.minute)}:${_pad(t.second)}';

String _pad(int n) => n.toString().padLeft(2, '0');

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
