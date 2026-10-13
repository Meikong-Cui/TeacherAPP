import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teacher_app/core/auth_store.dart';
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
    this.campus,
    this.campuses = const <Campus>[],
    this.loadingCampuses = false,
    this.campusLoadFailed = false,
    this.campusCacheAt,
    this.records = const <ClockRecord>[],
    this.loading = false,
    this.locating = false,
    this.syncing = false,
    this.error,
    this.notice,
    this.campusSourceNote,
    this.currentLatitude,
    this.currentLongitude,
    this.lastDistance,
  });

  /// 当前选中的打卡校区。
  ///
  /// **为 null 表示还没拿到任何校区数据**（首次进入、后台拉取失败、本地也没有缓存）。
  /// 此时页面不展示校区相关控件，而是给出「无法获取校区列表」与重试入口 ——
  /// 而不是拿一份内置的假校区顶上。见 [campusLoadFailed]。
  final Campus? campus;

  /// 可选校区列表。来自后台 `GET /api/system/campuses`；
  /// 后台不可用时是本地缓存（此时 [campusCacheAt] 非 null）。
  final List<Campus> campuses;

  /// 正在拉取后台校区列表（下拉框据此显示加载态，而不是空着不响应）。
  final bool loadingCampuses;

  /// 后台拉取失败**且**本地没有可用缓存 —— 页面需显示失败态与重试入口。
  final bool campusLoadFailed;

  /// [campuses] 是什么时候从后台拉到的。
  ///
  /// 非 null 表示**当前用的是缓存数据**（后台此刻不可达），UI 据此提示数据可能陈旧；
  /// null 表示就是本次刚从后台拉到的。
  final DateTime? campusCacheAt;

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

  /// 校区列表的来源与可用性说明（用的是缓存数据还是后台实时数据、哪些校区缺坐标）。
  ///
  /// 单独占一个字段而不复用 [notice]：notice 在每次打卡 / 同步的 copyWith 里都会被清掉，
  /// 而「当前用的是缓存数据」这件事必须在整页生命周期内持续可见，不能一闪而过。
  final String? campusSourceNote;

  final double? currentLatitude;
  final double? currentLongitude;
  final double? lastDistance;

  /// 当前校区是否可用于打卡（未选中校区、或校区未配置坐标时均为 false）。
  bool get campusClockable => campus?.hasGeo ?? false;

  /// 当前校区实际生效的围栏半径（米）；未选校区时返回全局默认值。
  double get fenceRadiusMeters =>
      campus?.effectiveRadius ?? AppConstants.clockInRadiusMeters;

  ClockInState copyWith({
    Campus? campus,
    List<Campus>? campuses,
    bool? loadingCampuses,
    bool? campusLoadFailed,
    DateTime? campusCacheAt,
    /// true → [campusCacheAt] 与 [campusSourceNote] **按传入值整体生效（含置空）**。
    bool resetCampusMeta = false,
    List<ClockRecord>? records,
    bool? loading,
    bool? locating,
    bool? syncing,
    String? error,
    String? notice,
    String? campusSourceNote,
    double? currentLatitude,
    double? currentLongitude,
    double? lastDistance,
  }) =>
      ClockInState(
        campus: campus ?? this.campus,
        campuses: campuses ?? this.campuses,
        loadingCampuses: loadingCampuses ?? this.loadingCampuses,
        campusLoadFailed: campusLoadFailed ?? this.campusLoadFailed,
        // 为什么需要 resetCampusMeta：`?? this.xxx` 无法把已有值改回 null，
        // 而从「缓存态」切到「后台实时态」时，陈旧标记**和**缓存说明必须一起清掉，
        // 否则界面上会一直挂着「数据来自缓存」的过期提示（实测踩过）。
        // 只有 _applyList 与加载失败分支传 true，其余调用保持原值不变。
        campusCacheAt: resetCampusMeta
            ? campusCacheAt
            : (campusCacheAt ?? this.campusCacheAt),
        records: records ?? this.records,
        loading: loading ?? this.loading,
        locating: locating ?? this.locating,
        syncing: syncing ?? this.syncing,
        error: error,
        notice: notice,
        campusSourceNote: resetCampusMeta
            ? campusSourceNote
            : (campusSourceNote ?? this.campusSourceNote),
        currentLatitude: currentLatitude ?? this.currentLatitude,
        currentLongitude: currentLongitude ?? this.currentLongitude,
        lastDistance: lastDistance ?? this.lastDistance,
      );
}

/// 签到逻辑：拉校区列表 → 取定位（带超时/降级）→ 算距离 → 围栏判定 →
/// 本地留存 → 后台同步。
///
/// 兜底原则：**任何情况下 loading / locating / loadingCampuses 都会归位**，
/// 不会出现「一直转圈」或「按钮永久置灰且无提示」；且**后台同步失败不会丢打卡记录**。
class ClockInNotifier extends StateNotifier<ClockInState> {
  ClockInNotifier(this._repository) : super(const ClockInState()) {
    unawaited(_restorePending());
    unawaited(loadCampuses());
  }

  final ClockInRepository _repository;

  /// 切换打卡校区，并记住这次选择（下次进入本页直接用它）。
  void setCampus(Campus campus) {
    state = state.copyWith(campus: campus);
    // 落盘失败只影响「下次的默认值」，不能影响本次打卡，所以不 await、不抛错。
    unawaited(_repository.persistSelectedCampusId(campus.id));
  }

  /// 拉取校区列表并解析默认选中项。
  ///
  /// 数据来源三级，**任何一级都不会给出 App 内置的假数据**：
  ///   ① 后台 `GET /api/system/campuses`（实时）
  ///   ② 本地缓存 —— 上次从后台成功拉取的**真实数据**，界面标注拉取时间
  ///   ③ 明确失败态 + 重试入口（[ClockInState.campusLoadFailed]）
  ///
  /// 第 ② 级为什么不是「内置一份坐标」：内置坐标是固定值，管理员在后台改过位置后，
  /// 离线状态会拿旧坐标判围栏，老师被拒打卡却看不出原因（详见 `Campus` 顶部说明）。
  ///
  /// 默认选中优先级：**上次手动选择 > 本人所属校区 > 第一个已配坐标的 > 第一个**。
  Future<void> loadCampuses() async {
    if (state.loadingCampuses) return;
    state = state.copyWith(loadingCampuses: true, campusLoadFailed: false);

    final List<Campus>? remote = await _repository.listCampuses();
    if (!mounted) return;
    if (remote != null) {
      await _applyList(remote, cachedAt: null);
      return;
    }

    final CampusCache? cache = await _repository.loadCampusCache();
    if (!mounted) return;
    if (cache != null && cache.campuses.isNotEmpty) {
      await _applyList(cache.campuses, cachedAt: cache.cachedAt);
      return;
    }

    // 连缓存都没有（首次安装就断网，或缓存已被系统清理）：明确失败，不留假数据。
    state = state.copyWith(
      loadingCampuses: false,
      campusLoadFailed: true,
      campuses: const <Campus>[],
      campusSourceNote: null,
      resetCampusMeta: true,
    );
  }

  /// 用一份确定的校区列表刷新状态，并解析选中项。
  ///
  /// [cachedAt] 为 null 表示这是刚从后台拉到的实时数据；
  /// 非 null 表示用的是缓存，会把该时间带到 UI 上提示数据陈旧度。
  Future<void> _applyList(List<Campus> list, {required DateTime? cachedAt}) async {
    final int? savedId = await _repository.loadSelectedCampusId();
    if (!mounted) return;
    final int? myCampusId = int.tryParse(AuthStore.instance.campusId ?? '');

    final Campus? pick = _findById(list, savedId) ??
        _findById(list, myCampusId) ??
        _firstWhereOrNull(list, (Campus c) => c.hasGeo) ??
        (list.isEmpty ? null : list.first);

    state = state.copyWith(
      loadingCampuses: false,
      campusLoadFailed: false,
      campuses: list,
      campus: pick,
      campusCacheAt: cachedAt,
      resetCampusMeta: true,
      campusSourceNote: _sourceNote(cachedAt, list),
    );
  }

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

    // 没有任何校区数据时不能继续：没有打卡点就没有围栏，任何结论都是编的。
    final Campus? target = state.campus;
    if (target == null) {
      // 区分「还在加载」和「已经失败」：两者都没校区，但用户能做的事完全不同
      // （前者等一下就行，后者要去检查网络）。UI 上按钮此时是禁用的，
      // 这里主要覆盖程序化调用与极端时序。
      state = state.copyWith(
        error: state.loadingCampuses
            ? '正在获取校区列表，请稍候再试。若长时间没有响应，请检查网络后'
                '点上方「重试」重新加载。'
            : '尚未获取到校区列表，无法判定打卡范围，本次打卡未生效。'
                '请检查网络后点上方「重试」重新加载；'
                '如确已到岗，可改用「补卡申请」。',
      );
      return;
    }

    // 校区未配坐标时不进定位：算不出距离，任何结论都是编的。
    // 这里**不置灰按钮**，而是在按下后给出确切原因与出路。
    if (!target.hasGeo) {
      state = state.copyWith(
        error: '「${target.name}」尚未配置打卡坐标，无法判定是否在岗，本次打卡未生效。'
            '请联系管理员在 OA 网页「学校管理」中录入该校区坐标；'
            '如确已到岗，可先改用「补卡申请」。',
      );
      return;
    }

    state = state.copyWith(loading: true, error: null, notice: null);
    try {
      final LocationFix fix = await _repository.acquireLocation();
      if (!mounted) return;

      final double? distance = _repository.distanceTo(
        campus: target,
        latitude: fix.latitude,
        longitude: fix.longitude,
      );
      if (distance == null) {
        // target.hasGeo 已在上面拦过，走到这里只可能是校区坐标在定位期间被清空。
        state = state.copyWith(
          loading: false,
          error: '「${target.name}」的打卡坐标不可用，本次打卡未生效。',
        );
        return;
      }

      if (!_repository.isWithinFence(target, distance)) {
        state = state.copyWith(
          loading: false,
          lastDistance: distance,
          currentLatitude: fix.latitude,
          currentLongitude: fix.longitude,
          error: '距「${target.name}」打卡点 ${distance.toStringAsFixed(0)} 米，'
              '超出 ${target.effectiveRadius.toInt()} 米围栏，本次打卡未生效。'
              '请到校区范围内重试；如确已到岗但无法定位，请改用「补卡申请」。',
        );
        return;
      }

      final ClockRecord record = ClockRecord(
        type: type,
        time: DateTime.now(),
        campusName: target.name,
        campusId: target.id,
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

  /// 校区列表的来源与可用性说明；一切正常时返回 null（不打扰用户）。
  String? _sourceNote(DateTime? cachedAt, List<Campus> list) {
    final List<String> parts = <String>[];
    if (cachedAt != null) {
      parts.add('当前无法连接后台，校区列表来自 ${_formatTime(cachedAt)} 拉取的缓存，'
          '可能不是最新。恢复网络后重新进入本页即可刷新。');
    }
    final List<String> noGeo = list
        .where((Campus c) => !c.hasGeo)
        .map((Campus c) => c.name)
        .toList();
    if (noGeo.isNotEmpty) {
      parts.add('以下校区尚未配置打卡坐标，无法打卡：${noGeo.join('、')}。'
          '请管理员在 OA 网页「学校管理」中录入坐标与围栏半径。');
    }
    return parts.isEmpty ? null : parts.join('\n');
  }

  static String _formatTime(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)} '
        '${two(t.hour)}:${two(t.minute)}';
  }

  static Campus? _findById(List<Campus> list, int? id) {
    if (id == null) return null;
    for (final Campus c in list) {
      if (c.id == id) return c;
    }
    return null;
  }

  static Campus? _firstWhereOrNull(
      List<Campus> list, bool Function(Campus) test) {
    for (final Campus c in list) {
      if (test(c)) return c;
    }
    return null;
  }
}
