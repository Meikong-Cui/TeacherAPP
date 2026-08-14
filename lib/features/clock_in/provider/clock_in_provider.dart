import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teacher_app/core/constants.dart';
import 'package:teacher_app/data/models/campus.dart';
import 'package:teacher_app/data/models/clock_record.dart';
import 'package:teacher_app/features/clock_in/data/clock_in_repository.dart';

final Provider<ClockInRepository> clockInRepositoryProvider =
    Provider<ClockInRepository>((ref) => const ClockInRepository());

final StateNotifierProvider<ClockInNotifier, ClockInState> clockInProvider =
    StateNotifierProvider<ClockInNotifier, ClockInState>(
  (ref) => ClockInNotifier(ref.watch(clockInRepositoryProvider)),
);

/// 签到页状态。
class ClockInState {
  const ClockInState({
    this.campus = Campus.defaultCampus,
    this.records = const <ClockRecord>[],
    this.loading = false,
    this.locating = false,
    this.error,
    this.currentLatitude,
    this.currentLongitude,
    this.lastDistance,
  });

  final Campus campus;
  final List<ClockRecord> records;
  final bool loading;
  final bool locating;
  final String? error;
  final double? currentLatitude;
  final double? currentLongitude;
  final double? lastDistance;

  ClockInState copyWith({
    Campus? campus,
    List<ClockRecord>? records,
    bool? loading,
    bool? locating,
    String? error,
    double? currentLatitude,
    double? currentLongitude,
    double? lastDistance,
  }) =>
      ClockInState(
        campus: campus ?? this.campus,
        records: records ?? this.records,
        loading: loading ?? this.loading,
        locating: locating ?? this.locating,
        error: error,
        currentLatitude: currentLatitude ?? this.currentLatitude,
        currentLongitude: currentLongitude ?? this.currentLongitude,
        lastDistance: lastDistance ?? this.lastDistance,
      );
}

/// 签到逻辑：取真实 GPS 定位 → 算距离 → 围栏判定 → 保存。
class ClockInNotifier extends StateNotifier<ClockInState> {
  ClockInNotifier(this._repository) : super(const ClockInState());

  final ClockInRepository _repository;

  void setCampus(Campus campus) => state = state.copyWith(campus: campus);

  /// 获取当前真实 GPS 定位，用于围栏可视化。
  Future<void> fetchLocation() async {
    state = state.copyWith(locating: true, error: null);
    try {
      final position = await _repository.getCurrentPosition();
      state = state.copyWith(
        locating: false,
        currentLatitude: position.latitude,
        currentLongitude: position.longitude,
      );
    } on ClockInException catch (e) {
      state = state.copyWith(locating: false, error: e.message);
    } catch (e) {
      state = state.copyWith(locating: false, error: '定位失败：$e');
    }
  }

  /// 执行签到（上班 / 下班）。始终使用真实 GPS 定位。
  Future<void> doClockIn(ClockType type) async {
    state = state.copyWith(loading: true, error: null);
    try {
      final position = await _repository.getCurrentPosition();
      final double latitude = position.latitude;
      final double longitude = position.longitude;

      final double distance = _repository.distanceTo(
        campus: state.campus,
        latitude: latitude,
        longitude: longitude,
      );

      if (!_repository.isWithinFence(distance)) {
        state = state.copyWith(
          loading: false,
          lastDistance: distance,
          error: '距打卡点 ${distance.toStringAsFixed(0)} 米，'
              '超出 ${AppConstants.clockInRadiusMeters.toInt()} 米围栏，无法签到',
        );
        return;
      }

      final ClockRecord record = ClockRecord(
        type: type,
        time: DateTime.now(),
        campusName: state.campus.name,
        latitude: latitude,
        longitude: longitude,
        distanceMeters: distance,
        withinFence: true,
      );

      await _repository.saveRemote(record);

      state = state.copyWith(
        loading: false,
        lastDistance: distance,
        currentLatitude: latitude,
        currentLongitude: longitude,
        records: <ClockRecord>[record, ...state.records],
      );
    } on ClockInException catch (e) {
      state = state.copyWith(loading: false, error: e.message);
    } catch (e) {
      state = state.copyWith(loading: false, error: '定位失败：$e');
    }
  }
}
