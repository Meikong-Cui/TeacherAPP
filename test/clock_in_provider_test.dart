import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:teacher_app/core/auth_store.dart';
import 'package:teacher_app/data/models/campus.dart';
import 'package:teacher_app/data/models/clock_record.dart';
import 'package:teacher_app/features/clock_in/data/clock_in_repository.dart';
import 'package:teacher_app/features/clock_in/domain/attendance.dart';
import 'package:teacher_app/features/clock_in/provider/clock_in_provider.dart';

/// 测试用的「后台下发」校区列表。
///
/// ⚠️ 这**不是 App 的内置数据** —— App 已不再内置任何校区（`Campus` 类里
/// 没有 `all` / `defaultCampus` 了）。这里只是本文件对「后台正常返回两个校区」
/// 这一情形的模拟，坐标取任意固定值即可。
const Campus _hulan = Campus(
    id: 1, name: '呼兰校区', latitude: 45.98555, longitude: 126.599363);
const Campus _daoli = Campus(
    id: 2, name: '道里校区', latitude: 45.732986, longitude: 126.587281);
const List<Campus> _remoteCampuses = <Campus>[_hulan, _daoli];

/// 打卡数据层桩件：不触碰真实 GPS / 网络 / 本地存储，只模拟成功与各类失败。
///
/// 只覆盖「会碰 I/O」的方法（定位、网络、SharedPreferences）；
/// [distanceTo] / [isWithinFence] 不覆盖，继续用真实实现 —— 它们与围栏
/// 判定结果直接相关，用桩替掉就等于把要验证的逻辑自己写一遍，测试会失去意义。
class FakeClockInRepository extends ClockInRepository {
  FakeClockInRepository({
    this.fix,
    this.locationError,
    this.syncError,
    List<Campus>? campuses,
    this.selectedCampusId,
    this.remoteUnavailable = false,
    this.cached,
    this.attendance,
  }) : campuses = campuses ?? _remoteCampuses;

  LocationFix? fix;
  String? locationError; // 非空 → 定位失败
  String? syncError; // 非空 → 后台同步失败

  /// `fetchAttendanceToday()` 的返回值。null = 后台没给（未登录 / 网络失败）。
  ///
  /// ⚠️ 必须在这里覆盖掉真实现：真实现会发真实 HTTP 请求，跑测试时既慢又
  /// 依赖环境。默认 null 正好对应「拿不到班次」这条分支，也就要显式给值才能测迟到。
  AttendanceToday? attendance;

  /// 后台返回的校区列表。默认为 [_remoteCampuses]（等价于「后台正常返回数据」）。
  ///
  /// ⚠️ 想模拟「后台拉不到」**不能用 `campuses: null`** —— 构造器里的 `??` 会把它
  /// 兜成默认列表，于是 `listCampuses()` 返回非 null，用例会在「以为在测离线
  /// 路径」的情况下悄悄走在线路径。这种假通过比直接失败更难发现，所以另开一个
  /// [remoteUnavailable] 开关，语义上不可能与默认值混淆。
  List<Campus>? campuses;

  /// true → `listCampuses()` 返回 null，走「后台拉不到」的降级分支。
  ///
  /// 非 final：有一条用例要模拟「网络恢复后再点重试」。
  bool remoteUnavailable;

  /// `loadCampusCache()` 的返回值。null 表示本地没有任何缓存。
  CampusCache? cached;

  /// 上次手动选择的校区 id；null 表示没存过。
  int? selectedCampusId;

  /// 记录被写入的缓存（断言「拿到后台数据后必须写缓存」）。
  final List<List<Campus>> savedCaches = <List<Campus>>[];

  int syncCalls = 0;
  final List<ClockRecord> submitted = <ClockRecord>[];
  final List<ClockRecord> persisted = <ClockRecord>[];
  final List<int> persistedCampusIds = <int>[];

  @override
  Future<LocationFix> acquireLocation() async {
    if (locationError != null) throw ClockInException(locationError!);
    return fix!;
  }

  @override
  Future<AttendanceToday?> fetchAttendanceToday() async => attendance;

  @override
  Future<ClockSubmitResult> submitClock(ClockRecord record) async {
    syncCalls++;
    submitted.add(record);
    if (syncError != null) throw ClockInException(syncError!);
    // 忠实模拟后台的合并口径：上班取最早、下班取最晚，状态由后台算。
    final String hhmm = '${record.time.hour.toString().padLeft(2, '0')}:'
        '${record.time.minute.toString().padLeft(2, '0')}';
    final String start = attendance?.start ?? '09:00';
    return ClockSubmitResult(
      type: record.type,
      time: record.time,
      id: 100 + syncCalls,
      onTime: record.type == ClockType.checkIn
          ? hhmm
          : attendance?.onTime,
      offTime: record.type == ClockType.checkOut ? hhmm : attendance?.offTime,
      onTimeSec: '$hhmm:00',
      offTimeSec: record.type == ClockType.checkOut ? '$hhmm:00' : null,
      statusLabel: hhmm.compareTo(start) > 0 ? '迟到' : '正常',
      late: record.type == ClockType.checkIn && hhmm.compareTo(start) > 0,
      synced: true,
    );
  }

  @override
  Future<List<ClockRecord>> loadPending() async => const <ClockRecord>[];

  @override
  Future<void> persistPending(List<ClockRecord> records) async {
    persisted
      ..clear()
      ..addAll(records);
  }

  @override
  Future<List<Campus>?> listCampuses() async {
    if (remoteUnavailable) return null;
    // 忠实模拟真实现：拉取成功后写缓存（真实现里是 `unawaited(saveCampusCache(list))`）。
    // 桩件若省掉这一步，「离线时拿得到兜底数据」的用例就会在一个**失真的前提**下
    // 通过 —— 而那份缓存恰恰是离线能打卡的唯一来源。
    await saveCampusCache(campuses!);
    return campuses;
  }

  @override
  Future<CampusCache?> loadCampusCache() async => cached;

  @override
  Future<void> saveCampusCache(List<Campus> campuses) async {
    savedCaches.add(campuses);
  }

  @override
  Future<int?> loadSelectedCampusId() async => selectedCampusId;

  @override
  Future<void> persistSelectedCampusId(int id) async {
    selectedCampusId = id;
    persistedCampusIds.add(id);
  }
}

Position _pos(double lat, double lon) => Position(
      latitude: lat,
      longitude: lon,
      timestamp: DateTime(2026, 9, 5, 9, 0),
      accuracy: 5,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );

LocationFix _fixAt(double lat, double lon) =>
    LocationFix(position: _pos(lat, lon));

/// 测试用打卡点坐标（与 [_hulan] 一致），恒有值。
const double _lat = 45.98555;
const double _lon = 126.599363;

/// 让 notifier 构造时发起的 unawaited 任务（拉校区列表）跑完，再断言。
///
/// ⚠️ 必须先 `read(...notifier)` 把实例建出来：`ProviderContainer` 是**懒加载**的，
/// 光建容器不会构造 notifier，构造里的 `unawaited(loadCampuses())` 自然也不会启动。
/// 早先版本漏了这一步 —— 「等一个事件循环」等了个寂寞，断言读到的是尚未加载的
/// 初始状态；有两个用例因此**假通过**（初始值恰好等于期望值）。这不是小事：
/// 假通过会让人以为「默认选中」逻辑已经验证过了。
///
/// 现在改成轮询到 `loadingCampuses` 归位为止，超上限直接 fail —— 宁可测试红，
/// 也不要一个恒真的断言。
Future<void> _settle(ProviderContainer c) async {
  c.read(clockInProvider.notifier);
  for (int i = 0; i < 20; i++) {
    if (!c.read(clockInProvider).loadingCampuses) return;
    await Future<void>.delayed(Duration.zero);
  }
  fail('校区列表在 20 个事件循环内仍未加载完成；'
      'notifier 构造里的 unawaited(loadCampuses()) 可能卡住了');
}

ProviderContainer _container(FakeClockInRepository repo, {String? myCampusId}) {
  // 每个用例都显式重置「本人所属校区」，避免用例之间互相污染。
  AuthStore.instance.campusId = myCampusId;
  final ProviderContainer container = ProviderContainer(
    overrides: <Override>[clockInRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('围栏内打卡成功：记录已同步，loading 归位', () async {
    final FakeClockInRepository repo =
        FakeClockInRepository(fix: _fixAt(_lat, _lon));
    final ProviderContainer c = _container(repo);
    // 校区列表是异步拉的，必须先等它归位：初始状态里没有校区（App 不再内置），
    // 不等的话 doClockIn 会先被「没有打卡点」拦下，测到的就不是围栏逻辑了。
    await _settle(c);

    await c.read(clockInProvider.notifier).doClockIn(ClockType.checkIn);
    final ClockInState s = c.read(clockInProvider);

    expect(s.loading, isFalse, reason: 'loading 必须归位，不能一直转圈');
    expect(s.error, isNull);
    expect(s.records, hasLength(1));
    expect(s.records.single.synced, isTrue);
    expect(repo.syncCalls, 1);
  });

  test('超出围栏：给出明确原因，不产生记录，loading 归位', () async {
    // 纬度 +0.05° ≈ 5.5 km，远超 1000 米默认围栏
    final FakeClockInRepository repo =
        FakeClockInRepository(fix: _fixAt(_lat + 0.05, _lon));
    final ProviderContainer c = _container(repo);

    await _settle(c);

    await c.read(clockInProvider.notifier).doClockIn(ClockType.checkIn);
    final ClockInState s = c.read(clockInProvider);

    expect(s.loading, isFalse);
    expect(s.records, isEmpty, reason: '越界不应产生打卡记录');
    expect(s.error, isNotNull);
    expect(s.error, contains('超出'));
    expect(s.error, contains('米'));
    expect(s.error, contains('呼兰校区'), reason: '要说明是哪个校区的围栏');
    expect(repo.syncCalls, 0);
  });

  test('校区自定义半径生效：默认 1000 米会被拒，配到 8000 米后放行', () async {
    const Campus wide = Campus(
      id: 1,
      name: '呼兰校区',
      latitude: _lat,
      longitude: _lon,
      radiusMeters: 8000,
    );
    // 约 5.5 km：超出默认 1000 米，但在 8000 米围栏内
    final FakeClockInRepository repo = FakeClockInRepository(
      fix: _fixAt(_lat + 0.05, _lon),
      campuses: const <Campus>[wide],
    );
    final ProviderContainer c = _container(repo);
    await _settle(c);

    final ClockInNotifier notifier = c.read(clockInProvider.notifier);
    await notifier.doClockIn(ClockType.checkIn);
    final ClockInState s = c.read(clockInProvider);

    expect(s.campus, isNotNull);
    expect(s.campus!.effectiveRadius, 8000);
    expect(s.records, hasLength(1), reason: '半径放大后应放行');
    expect(s.error, isNull);
  });

  test('网络同步失败：打卡记录本地留存（不丢），标记待同步并给出提示', () async {
    final FakeClockInRepository repo = FakeClockInRepository(
      fix: _fixAt(_lat, _lon),
      syncError: '网络不可用',
    );
    final ProviderContainer c = _container(repo);

    await _settle(c);

    await c.read(clockInProvider.notifier).doClockIn(ClockType.checkIn);
    final ClockInState s = c.read(clockInProvider);

    expect(s.loading, isFalse, reason: '同步失败也不能卡在转圈');
    expect(s.error, isNull, reason: '同步失败不是阻断性错误');
    expect(s.records, hasLength(1), reason: '同步失败不能丢打卡记录');
    expect(s.records.single.synced, isFalse);
    expect(s.notice, isNotNull);
    expect(s.notice, contains('同步'));
    expect(repo.persisted, hasLength(1), reason: '待同步记录须落盘，重启后可重发');
  });

  test('定位失败：给出可操作提示，不产生记录，loading 归位', () async {
    final FakeClockInRepository repo =
        FakeClockInRepository(locationError: '定位服务未开启');
    final ProviderContainer c = _container(repo);

    await _settle(c);
    await c.read(clockInProvider.notifier).doClockIn(ClockType.checkIn);
    await c.read(clockInProvider.notifier).fetchLocation();
    final ClockInState s = c.read(clockInProvider);

    expect(s.loading, isFalse);
    expect(s.locating, isFalse, reason: 'locating 必须归位，按钮不能永久置灰');
    expect(s.records, isEmpty);
    expect(s.error, contains('定位服务未开启'));
  });

  test('同步失败后可重试成功', () async {
    final FakeClockInRepository repo = FakeClockInRepository(
      fix: _fixAt(_lat, _lon),
      syncError: '网络不可用',
    );
    final ProviderContainer c = _container(repo);

    await _settle(c);

    final ClockInNotifier notifier = c.read(clockInProvider.notifier);
    await notifier.doClockIn(ClockType.checkOut);
    expect(c.read(clockInProvider).records.single.synced, isFalse);

    // 网络恢复后重试
    repo.syncError = null;
    await notifier.retrySync(c.read(clockInProvider).records.single);
    final ClockInState s = c.read(clockInProvider);

    expect(s.records.single.synced, isTrue);
    expect(repo.syncCalls, 2);
    expect(repo.persisted, isEmpty, reason: '同步成功后待同步队列应清空');
    expect(s.syncing, isFalse);
  });

  // ── 校区数据来源：后台 → 本地缓存 → 明确失败（三级，且不含任何内置数据）──

  test('后台拉不到、但本地有缓存：用缓存数据，并带出拉取时间', () async {
    final DateTime cachedAt = DateTime(2026, 9, 18, 10, 30);
    final FakeClockInRepository repo = FakeClockInRepository(
      remoteUnavailable: true,
      cached: CampusCache(campuses: _remoteCampuses, cachedAt: cachedAt),
    );
    final ProviderContainer c = _container(repo);
    await _settle(c);

    final ClockInState s = c.read(clockInProvider);

    expect(s.loadingCampuses, isFalse, reason: 'loadingCampuses 必须归位');
    expect(s.campusLoadFailed, isFalse, reason: '有缓存可用就不算加载失败');
    expect(s.campuses.map((Campus x) => x.id), <int>[1, 2]);
    expect(s.campusCacheAt, cachedAt,
        reason: '必须带出缓存时间，UI 才能提示「数据可能不是最新」');
    expect(s.campusSourceNote, isNotNull);
    expect(s.campusSourceNote, contains('缓存'));
    expect(s.campusSourceNote, contains('2026-09-18 10:30'));
    expect(s.error, isNull, reason: '有缓存可用不是阻断性错误，不能挡住打卡');
  });

  test('后台拉不到、本地也无缓存：明确失败态，不给任何校区', () async {
    final FakeClockInRepository repo =
        FakeClockInRepository(remoteUnavailable: true);
    final ProviderContainer c = _container(repo);
    await _settle(c);

    final ClockInState s = c.read(clockInProvider);

    expect(s.loadingCampuses, isFalse);
    expect(s.campusLoadFailed, isTrue);
    expect(s.campuses, isEmpty, reason: '不能拿内置的假校区顶上（已删除内置数据）');
    expect(s.campus, isNull, reason: '没有校区就没有默认选中项');
    expect(s.campusSourceNote, isNull,
        reason: '失败原因由 campusLoadFailed 承载，不重复堆提示');
  });

  test('没有校区数据时打卡被拦下并说明原因（不静默置灰）', () async {
    final FakeClockInRepository repo = FakeClockInRepository(
      fix: _fixAt(_lat, _lon),
      remoteUnavailable: true,
    );
    final ProviderContainer c = _container(repo);
    await _settle(c);

    await c.read(clockInProvider.notifier).doClockIn(ClockType.checkIn);
    final ClockInState s = c.read(clockInProvider);

    expect(s.loading, isFalse, reason: '拦截路径也必须归位');
    expect(s.records, isEmpty);
    expect(s.error, isNotNull);
    expect(s.error, contains('尚未获取到校区列表'));
    expect(s.error, contains('补卡'), reason: '要给出可操作出口，不能只说失败');
    expect(repo.syncCalls, 0, reason: '没有打卡点不得产生后台记录');
  });

  test('拿到后台数据后写入缓存（离线兜底的唯一来源）', () async {
    final FakeClockInRepository repo = FakeClockInRepository();
    final ProviderContainer c = _container(repo);
    await _settle(c);
    await Future<void>.delayed(Duration.zero); // 写缓存是 unawaited 的

    expect(repo.savedCaches, hasLength(1));
    expect(repo.savedCaches.single.map((Campus x) => x.id), <int>[1, 2]);
  });

  test('从缓存态刷新到后台实时态：陈旧标记必须被清掉', () async {
    final FakeClockInRepository repo = FakeClockInRepository(
      remoteUnavailable: true,
      cached: CampusCache(
        campuses: _remoteCampuses,
        cachedAt: DateTime(2026, 9, 18, 10, 30),
      ),
    );
    final ProviderContainer c = _container(repo);
    await _settle(c);
    expect(c.read(clockInProvider).campusCacheAt, isNotNull,
        reason: '前置条件：此刻应当处于缓存态');

    // 网络恢复，点重试
    repo.remoteUnavailable = false;
    await c.read(clockInProvider.notifier).loadCampuses();
    final ClockInState s = c.read(clockInProvider);

    expect(s.campusCacheAt, isNull,
        reason: '已刷新到实时数据，不能再显示「数据来自缓存」');
    expect(s.campusSourceNote, isNull, reason: '数据新鲜且都有坐标，无需提示');
    expect(s.campuses.map((Campus x) => x.id), <int>[1, 2]);
  });

  test('后台列表完整且有坐标：不显示多余提示', () async {
    final FakeClockInRepository repo = FakeClockInRepository();
    final ProviderContainer c = _container(repo);
    await _settle(c);

    final ClockInState s = c.read(clockInProvider);

    expect(s.campusSourceNote, isNull, reason: '一切正常时不该打扰用户');
    expect(s.campusClockable, isTrue);
    expect(s.campus?.id, 1,
        reason: '没有本人校区、也没有历史选择时，落在第一个已配坐标的校区');
  });

  test('未配坐标的校区：提示点名 + 打卡被拦下，不进定位也不上后台', () async {
    final FakeClockInRepository repo = FakeClockInRepository(
      fix: _fixAt(_lat, _lon),
      campuses: const <Campus>[
        Campus(id: 9, name: '待建校区'),
      ],
    );
    final ProviderContainer c = _container(repo);
    await _settle(c);

    final ClockInState before = c.read(clockInProvider);
    expect(before.campus?.id, 9, reason: '默认项应落在唯一可选校区上');
    expect(before.campusClockable, isFalse);
    expect(before.campusSourceNote, contains('待建校区'));

    await c.read(clockInProvider.notifier).doClockIn(ClockType.checkIn);
    final ClockInState s = c.read(clockInProvider);

    expect(s.loading, isFalse, reason: '拦截路径也必须归位');
    expect(s.records, isEmpty);
    expect(s.error, contains('未配置打卡坐标'));
    expect(s.error, contains('待建校区'));
    expect(repo.syncCalls, 0, reason: '未配坐标不得产生后台记录');
  });

  test('默认选中：本人所属校区优先', () async {
    final FakeClockInRepository repo = FakeClockInRepository();
    final ProviderContainer c = _container(repo, myCampusId: '2');
    await _settle(c);

    expect(c.read(clockInProvider).campus?.id, 2,
        reason: '道里校区的老师进页面默认就该是道里');
  });

  test('默认选中：上次手动选择优先于本人所属校区', () async {
    // 本人属呼兰（id=1），上次手动改成了道里（id=2）。
    // 期望落在 2 —— 只看 id 的话这两个来源会撞在一起，区分不开。
    final FakeClockInRepository repo =
        FakeClockInRepository(selectedCampusId: 2);
    final ProviderContainer c = _container(repo, myCampusId: '1');
    await _settle(c);

    expect(c.read(clockInProvider).campus?.id, 2, reason: '改过的选择要被记住');
  });

  test('切换校区：状态即刻生效并落盘（下次进入本页沿用）', () async {
    final FakeClockInRepository repo = FakeClockInRepository();
    final ProviderContainer c = _container(repo);
    await _settle(c);

    final ClockInNotifier notifier = c.read(clockInProvider.notifier);
    notifier.setCampus(_daoli);
    await Future<void>.delayed(Duration.zero); // 落盘是 unawaited 的，等它跑完

    expect(c.read(clockInProvider).campus?.id, 2);
    expect(repo.persistedCampusIds, <int>[2], reason: '选择须落到本地，否则下次白改');
    expect(repo.selectedCampusId, 2);
  });

  test('桩件自检：两个开关各自真的生效，不会被默认值抹平', () async {
    // 用桩件最容易栽的坑是「桩件的默认值把边界抹平了」—— 本文件里已经栽过两次：
    //  ① 容器懒加载，没 read 就等，等到的是初始状态（两个用例假通过）；
    //  ② campuses: null 被构造器的 ?? 兜成默认列表，离线用例悄悄走了在线路径。
    // 所以把桩件自己的契约也钉一条用例：它坏了，这里先红，而不是等到上层逻辑
    // 被一个「看起来在测 A 其实在测 B」的断言放过。
    expect(
      await FakeClockInRepository(remoteUnavailable: true).listCampuses(),
      isNull,
      reason: 'remoteUnavailable 必须真的返回 null',
    );
    expect(await FakeClockInRepository().listCampuses(), _remoteCampuses,
        reason: '默认必须返回「后台正常返回的那份列表」');

    // 缓存开关同样不能与「后台可用」混为一谈
    final DateTime at = DateTime(2026, 9, 18, 10, 30);
    final FakeClockInRepository withCache = FakeClockInRepository(
      remoteUnavailable: true,
      cached: CampusCache(campuses: _remoteCampuses, cachedAt: at),
    );
    expect((await withCache.loadCampusCache())?.cachedAt, at);
    expect(await FakeClockInRepository().loadCampusCache(), isNull,
        reason: '默认没有缓存 —— 别让「无缓存」的用例悄悄跑在有缓存的分支上');
  });

  // ── 2026-10-16 改版：单按钮流转 / 迟到判定 / 下班卡可反复更新 ──

  test('按钮流转：没打上班卡只给上班卡，打过之后只给下班卡', () async {
    final FakeClockInRepository repo = FakeClockInRepository(
      fix: _fixAt(_lat, _lon),
      attendance: const AttendanceToday(
          date: '2026-10-16', start: '09:00', end: '18:00'),
    );
    final ProviderContainer c = _container(repo);
    await _settle(c);

    expect(c.read(clockInProvider).nextClockType, ClockType.checkIn,
        reason: '还没打上班卡，只应显示上班打卡');
    expect(c.read(clockInProvider).hasCheckedIn, isFalse);

    await c.read(clockInProvider.notifier).doClockIn(ClockType.checkIn);
    final ClockInState s = c.read(clockInProvider);

    expect(s.hasCheckedIn, isTrue, reason: '本地已留存上班记录，按钮该翻到下班卡');
    expect(s.nextClockType, ClockType.checkOut);
  });

  test('后台侧已打过上班卡：进页面直接是下班卡状态（换手机也不回退）', () async {
    final FakeClockInRepository repo = FakeClockInRepository(
      fix: _fixAt(_lat, _lon),
      attendance: const AttendanceToday(
        date: '2026-10-16',
        start: '09:00',
        end: '18:00',
        onTime: '08:55',
        statusLabel: '正常',
      ),
    );
    final ProviderContainer c = _container(repo);
    await _settle(c);

    final ClockInState s = c.read(clockInProvider);
    expect(s.hasCheckedIn, isTrue, reason: '按钮流转要认后台记录，不能只看本地');
    expect(s.hasCheckedOut, isFalse);
    expect(s.nextClockType, ClockType.checkOut);
  });

  test('迟到判定以后台生效班次为准；拿不到班次时不判迟到', () async {
    // start=00:00 → 任何时刻都算迟到（用时间边界做确定性断言，不依赖跑测的钟点）
    final ProviderContainer c1 = _container(FakeClockInRepository(
      fix: _fixAt(_lat, _lon),
      attendance: const AttendanceToday(
          date: '2026-10-16', start: '00:00', end: '23:59'),
    ));
    await _settle(c1);
    expect(c1.read(clockInProvider).attendance, isNotNull, reason: '前置：班次已拿到');
    expect(c1.read(clockInProvider).lateNow, isTrue);

    // start=23:59 → 正常时段内不算迟到
    final ProviderContainer c2 = _container(FakeClockInRepository(
      fix: _fixAt(_lat, _lon),
      attendance: const AttendanceToday(
          date: '2026-10-16', start: '23:59', end: '23:59'),
    ));
    await _settle(c2);
    expect(c2.read(clockInProvider).lateNow, isFalse);

    // 后台班次拿不到：不判迟到 —— 宁可少打扰一次，也不能凭本机时间误报
    final ProviderContainer c3 =
        _container(FakeClockInRepository(fix: _fixAt(_lat, _lon)));
    await _settle(c3);
    expect(c3.read(clockInProvider).attendance, isNull);
    expect(c3.read(clockInProvider).lateNow, isFalse);
  });

  test('下班卡可反复重打：每次都上送，由后台取最晚一次', () async {
    final FakeClockInRepository repo = FakeClockInRepository(
      fix: _fixAt(_lat, _lon),
      attendance: const AttendanceToday(
          date: '2026-10-16', start: '09:00', end: '18:00', onTime: '08:55'),
    );
    final ProviderContainer c = _container(repo);
    await _settle(c);

    final ClockInNotifier notifier = c.read(clockInProvider.notifier);
    await notifier.doClockIn(ClockType.checkOut);
    expect(c.read(clockInProvider).hasCheckedOut, isTrue);

    // 打得早、又补打一次：按钮不该锁死，第二次照样要发出去
    await notifier.doClockIn(ClockType.checkOut);
    final ClockInState s = c.read(clockInProvider);

    expect(repo.submitted, hasLength(2), reason: '两次下班打卡都要上送，后台按最晚合并');
    expect(
      repo.submitted.every((ClockRecord r) => r.type == ClockType.checkOut),
      isTrue,
    );
    expect(s.nextClockType, ClockType.checkOut,
        reason: '下班卡可随时重打，按钮不消失');
  });

  test('打卡成功返回结果（供鼓励卡片展示）；离线时返回未同步结果而不是 null', () async {
    final FakeClockInRepository online = FakeClockInRepository(
      fix: _fixAt(_lat, _lon),
      attendance: const AttendanceToday(
          date: '2026-10-16', start: '09:00', end: '18:00'),
    );
    final ProviderContainer c1 = _container(online);
    await _settle(c1);
    final ClockSubmitResult? r1 = await c1
        .read(clockInProvider.notifier)
        .doClockIn(ClockType.checkIn);

    expect(r1, isNotNull, reason: '成功打卡必须回结果，卡片才知道记了几点');
    expect(r1!.synced, isTrue);
    expect(r1.id, isNotNull);
    expect(c1.read(clockInProvider).lastResult, isNotNull);

    // 离线：本地已留存，卡片照弹（标注待同步），不能因为同步失败就不给反馈
    final FakeClockInRepository offline = FakeClockInRepository(
      fix: _fixAt(_lat, _lon),
      syncError: '网络不可用',
    );
    final ProviderContainer c2 = _container(offline);
    await _settle(c2);
    final ClockSubmitResult? r2 = await c2
        .read(clockInProvider.notifier)
        .doClockIn(ClockType.checkIn);

    expect(r2, isNotNull);
    expect(r2!.synced, isFalse);
    expect(c2.read(clockInProvider).records, hasLength(1),
        reason: '同步失败也不能丢记录');
  });

  test('被拦下的打卡返回 null（失败原因走页面红色区块，不弹鼓励卡片）', () async {
    // 越界：不该有任何「成功」表示
    final FakeClockInRepository repo =
        FakeClockInRepository(fix: _fixAt(_lat + 0.05, _lon));
    final ProviderContainer c = _container(repo);
    await _settle(c);

    final ClockSubmitResult? r =
        await c.read(clockInProvider.notifier).doClockIn(ClockType.checkIn);

    expect(r, isNull);
    expect(c.read(clockInProvider).error, contains('超出'));
  });

  test('待同步记录序列化往返一致（用于本地兜底队列）', () {
    final ClockRecord r = ClockRecord(
      type: ClockType.checkIn,
      time: DateTime(2026, 9, 5, 8, 57),
      campusName: '呼兰校区',
      latitude: 45.98555,
      longitude: 126.599363,
      distanceMeters: 12.5,
      withinFence: true,
      synced: false,
      degradedLocation: true,
      id: '123456',
    );

    final ClockRecord? back = ClockRecord.fromJson(r.toJson());

    expect(back, isNotNull);
    expect(back!.id, '123456');
    expect(back.type, ClockType.checkIn);
    expect(back.synced, isFalse);
    expect(back.degradedLocation, isTrue);
    expect(back.distanceMeters, closeTo(12.5, 0.001));
  });
}
