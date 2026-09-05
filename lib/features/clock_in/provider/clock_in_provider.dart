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
    this.syncing = false,
    this.error,
    this.notice,
    this.currentLatitude,
    this.currentLongitude,
    this.lastDistance,
  });

  final Campus campus;
  final List<ClockRecord> records;
  final bool loading;

  /// 正在获取定位（「获取当前位置」按钮 / 进入页面自动定位）。
  final bool locating;

  /// 正在把某条记录补传到后台。
  final bool syncing;

  /// 阻断性失败（超出围栏、定位不可用等），红色区块展示。
  final String? error;

  /// 非阻断性提示（定位降级、后台同步失败但已本地留存等），橙色区块展示。
  final String? notice;

  final double? currentLatitude;
  final double? currentLongitude;
  final double? lastDistance;

  ClockInState copyWith({
    Campus? campus,
    List<ClockRecord>? records,
    bool? loading,
    bool? locating,
    bool? syncing,
    String? error,
    String? notice,
    double? currentLatitude,
    double? currentLongitude,
    double? lastDistance,
  }) =>
      ClockInState(
        campus: campus ?? this.campus,
        records: records ?? this.records,
        loading: loading ?? this.loading,
        locating: locating ?? this.locating,
        syncing: syncing ?? this.syncing,
        error: error,
        notice: notice,
        currentLatitude: currentLatitude ?? this.currentLatitude,
        currentLongitude: currentLongitude ?? this.currentLongitude,
        lastDistance: lastDistance ?? this.lastDistance,
      );
}

/// 签到逻辑：取定位（带超时/降级）→ 算距离 → 围栏判定 → 本地留存 → 后台同步。
///
/// 兜底原则：**任何情况下 loading / locating 都会归位**，不会出现
/// 「一直转圈」或「按钮永久置灰且无提示」；且**后台同步失败不会丢打卡记录**。
class ClockInNotifier extends StateNotifier<ClockInState> {
  ClockInNotifier(this._repository) : super(const ClockInState()) {
    _restorePending();
  }

  final ClockInRepository _repository;

  void setCampus(Campus campus) => state = state.copyWith(campus: campus);

  /// 启动时恢复上次未同步成功的记录，并尝试自动重发。
  Future<void> _restorePending() async {
    final List<ClockRecord> pending = await _repository.loadPending();
    if (pending.isEmpty || !mounted) return;
    final List<ClockRecord> merged = <ClockRecord>[...pending, ...state.records];
    state = state.copyWith(
      records: merged,
      notice: '有 ${pending.length} 条打卡记录尚未同步到后台，正在自动重试…',
    );
    for (final ClockRecord r in pending) {
      if (!mounted) return;
      await _sync(r);
    }
  }

  /// 获取当前定位，用于围栏可视化。
  Future<void> fetchLocation() async {
    if (state.locating) return;
    state = state.copyWith(locating: true, error: null, notice: null);
    try {
      final LocationFix fix = await _repository.acquireLocation();
      if (!mounted) return;
      state = state.copyWith(
        locating: false,
        currentLatitude: fix.latitude,
        currentLongitude: fix.longitude,
        notice: fix.degraded ? fix.degradedReason : null,
      );
    } on ClockInException catch (e) {
      if (!mounted) return;
      state = state.copyWith(locating: false, error: e.message);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(locating: false, error: '定位失败：$e');
    }
  }

  /// 执行签到（上班 / 下班）。
  Future<void> doClockIn(ClockType type) async {
    if (state.loading) return; // 防重复点击
    state = state.copyWith(loading: true, error: null, notice: null);
    try {
      final LocationFix fix = await _repository.acquireLocation();
      if (!mounted) return;

      final double distance = _repository.distanceTo(
        campus: state.campus,
        latitude: fix.latitude,
        longitude: fix.longitude,
      );

      if (!_repository.isWithinFence(distance)) {
        state = state.copyWith(
          loading: false,
          lastDistance: distance,
          currentLatitude: fix.latitude,
          currentLongitude: fix.longitude,
          error: '距打卡点 ${distance.toStringAsFixed(0)} 米，'
              '超出 ${AppConstants.clockInRadiusMeters.toInt()} 米围栏，本次打卡未生效。'
              '请到校区范围内重试；如确已到岗但无法定位，请改用「补卡申请」。',
        );
        return;
      }

      final ClockRecord record = ClockRecord(
        type: type,
        time: DateTime.now(),
        campusName: state.campus.name,
        latitude: fix.latitude,
        longitude: fix.longitude,
        distanceMeters: distance,
        withinFence: true,
        synced: false,
        degradedLocation: fix.degraded,
        id: DateTime.now().microsecondsSinceEpoch.toString(),
      );

      // 先本地留存：即使后面同步失败，这次打卡也不会丢失。
      state = state.copyWith(
        loading: false,
        records: <ClockRecord>[record, ...state.records],
        lastDistance: distance,
        currentLatitude: fix.latitude,
        currentLongitude: fix.longitude,
        notice: fix.degraded ? fix.degradedReason : null,
      );
      await _persistPending();
      if (!mounted) return;

      // 再尝试同步到后台。
      await _sync(record);
    } on ClockInException catch (e) {
      if (!mounted) return;
      state = state.copyWith(loading: false, error: e.message);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(loading: false, error: '打卡失败：$e');
    }
  }

  /// 手动重发某条未同步成功的记录（列表页「同步」按钮）。
  Future<void> retrySync(ClockRecord record) async {
    if (state.syncing || record.synced) return;
    await _sync(record);
  }

  /// 同步单条记录到后台；失败则保留为「待同步」，并给出明确提示。
  Future<void> _sync(ClockRecord record) async {
    state = state.copyWith(syncing: true);
    try {
      await _repository.saveRemote(record);
      if (!mounted) return;
      _replaceRecord(record.copyWith(synced: true));
      await _persistPending();
      if (!mounted) return;
      // 全部同步成功后清掉同步类提示。
      final bool allSynced = state.records.every((ClockRecord r) => r.synced);
      state = state.copyWith(
        syncing: false,
        notice: allSynced ? null : state.notice,
      );
    } on ClockInException catch (e) {
      if (!mounted) return;
      _replaceRecord(record.copyWith(synced: false));
      await _persistPending();
      if (!mounted) return;
      state = state.copyWith(
        syncing: false,
        notice: '打卡已记录在本地，但同步到后台失败：${e.message}。'
            '记录不会丢失，可点记录右侧的「同步」重试。',
      );
    } catch (e) {
      if (!mounted) return;
      _replaceRecord(record.copyWith(synced: false));
      await _persistPending();
      if (!mounted) return;
      state = state.copyWith(
        syncing: false,
        notice: '打卡已记录在本地，但同步到后台失败：$e。'
            '记录不会丢失，可点记录右侧的「同步」重试。',
      );
    }
  }

  void _replaceRecord(ClockRecord updated) {
    final List<ClockRecord> next = state.records
        .map((ClockRecord r) => r.id == updated.id ? updated : r)
        .toList();
    state = state.copyWith(records: next);
  }

  /// 把「未同步」的记录落盘，App 重启后仍可重发。
  Future<void> _persistPending() async {
    final List<ClockRecord> pending =
        state.records.where((ClockRecord r) => !r.synced).toList();
    await _repository.persistPending(pending);
  }
}
