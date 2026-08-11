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
    this.error,
    this.simulate = false,
    this.simLatitude,
    this.simLongitude,
    this.lastDistance,
  });

  final Campus campus;
  final List<ClockRecord> records;
  final bool loading;
  final String? error;
  final bool simulate;
  final double? simLatitude;
  final double? simLongitude;
  final double? lastDistance;

  ClockInState copyWith({
    Campus? campus,
    List<ClockRecord>? records,
    bool? loading,
    String? error,
    bool? simulate,
    double? simLatitude,
    double? simLongitude,
    double? lastDistance,
  }) =>
      ClockInState(
        campus: campus ?? this.campus,
        records: records ?? this.records,
        loading: loading ?? this.loading,
        error: error,
        simulate: simulate ?? this.simulate,
        simLatitude: simLatitude ?? this.simLatitude,
        simLongitude: simLongitude ?? this.simLongitude,
        lastDistance: lastDistance ?? this.lastDistance,
      );
}

/// 签到逻辑：取定位 → 算距离 → 围栏判定 → 保存。
class ClockInNotifier extends StateNotifier<ClockInState> {
  ClockInNotifier(this._repository) : super(const ClockInState());

  final ClockInRepository _repository;

  void setCampus(Campus campus) => state = state.copyWith(campus: campus);

  void toggleSimulate(bool value) => state = state.copyWith(simulate: value);

  void setSimCoords({double? latitude, double? longitude}) => state = state.copyWith(
        simLatitude: latitude,
        simLongitude: longitude,
      );

  /// 执行签到（上班 / 下班）。
  Future<void> doClockIn(ClockType type) async {
    state = state.copyWith(loading: true, error: null);
    try {
      double latitude;
      double longitude;

      if (state.simulate &&
          state.simLatitude != null &&
          state.simLongitude != null) {
        // 演示用：使用模拟坐标，免去真实定位依赖。
        latitude = state.simLatitude!;
        longitude = state.simLongitude!;
      } else {
        final position = await _repository.getCurrentPosition();
        latitude = position.latitude;
        longitude = position.longitude;
      }

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
        records: <ClockRecord>[record, ...state.records],
      );
    } on ClockInException catch (e) {
      state = state.copyWith(loading: false, error: e.message);
    } catch (e) {
      state = state.copyWith(loading: false, error: '定位失败：$e');
    }
  }
}
