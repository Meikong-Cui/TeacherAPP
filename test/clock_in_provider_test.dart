import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:teacher_app/data/models/campus.dart';
import 'package:teacher_app/data/models/clock_record.dart';
import 'package:teacher_app/features/clock_in/data/clock_in_repository.dart';
import 'package:teacher_app/features/clock_in/provider/clock_in_provider.dart';

/// 打卡数据层桩件：不触碰真实 GPS / 网络 / 本地存储，只模拟成功与各类失败。
class FakeClockInRepository extends ClockInRepository {
  FakeClockInRepository({this.fix, this.locationError, this.syncError});

  LocationFix? fix;
  String? locationError; // 非空 → 定位失败
  String? syncError; // 非空 → 后台同步失败

  int syncCalls = 0;
  final List<ClockRecord> persisted = <ClockRecord>[];

  @override
  Future<LocationFix> acquireLocation() async {
    if (locationError != null) throw ClockInException(locationError!);
    return fix!;
  }

  @override
  Future<void> saveRemote(ClockRecord record) async {
    syncCalls++;
    if (syncError != null) throw ClockInException(syncError!);
  }

  @override
  Future<List<ClockRecord>> loadPending() async => const <ClockRecord>[];

  @override
  Future<void> persistPending(List<ClockRecord> records) async {
    persisted
      ..clear()
      ..addAll(records);
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

ProviderContainer _container(FakeClockInRepository repo) {
  final ProviderContainer container = ProviderContainer(
    overrides: <Override>[clockInRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  const Campus campus = Campus.defaultCampus;

  test('围栏内打卡成功：记录已同步，loading 归位', () async {
    final FakeClockInRepository repo =
        FakeClockInRepository(fix: _fixAt(campus.latitude, campus.longitude));
    final ProviderContainer c = _container(repo);

    await c.read(clockInProvider.notifier).doClockIn(ClockType.checkIn);
    final ClockInState s = c.read(clockInProvider);

    expect(s.loading, isFalse, reason: 'loading 必须归位，不能一直转圈');
    expect(s.error, isNull);
    expect(s.records, hasLength(1));
    expect(s.records.single.synced, isTrue);
    expect(repo.syncCalls, 1);
  });

  test('超出围栏：给出明确原因，不产生记录，loading 归位', () async {
    // 纬度 +0.05° ≈ 5.5 km，远超 1000 米围栏
    final FakeClockInRepository repo =
        FakeClockInRepository(fix: _fixAt(campus.latitude + 0.05, campus.longitude));
    final ProviderContainer c = _container(repo);

    await c.read(clockInProvider.notifier).doClockIn(ClockType.checkIn);
    final ClockInState s = c.read(clockInProvider);

    expect(s.loading, isFalse);
    expect(s.records, isEmpty, reason: '越界不应产生打卡记录');
    expect(s.error, isNotNull);
    expect(s.error, contains('超出'));
    expect(s.error, contains('米'));
    expect(repo.syncCalls, 0);
  });

  test('网络同步失败：打卡记录本地留存（不丢），标记待同步并给出提示', () async {
    final FakeClockInRepository repo = FakeClockInRepository(
      fix: _fixAt(campus.latitude, campus.longitude),
      syncError: '网络不可用',
    );
    final ProviderContainer c = _container(repo);

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
      fix: _fixAt(campus.latitude, campus.longitude),
      syncError: '网络不可用',
    );
    final ProviderContainer c = _container(repo);

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
