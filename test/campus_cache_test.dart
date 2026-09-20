import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teacher_app/data/models/campus.dart';
import 'package:teacher_app/features/clock_in/data/clock_in_repository.dart';

/// 校区列表本地缓存的契约测试。
///
/// 这份缓存是**离线能打卡的唯一数据来源** —— App 已不再内置任何校区坐标
/// （见 `Campus` 顶部说明），所以缓存一旦写坏或读不回，断网的老师就直接
/// 打不了卡，而且现象上只会看到「未能获取校区列表」，很难联想到缓存。
///
/// ⚠️ 这里用**真实的 [ClockInRepository]**（不覆盖这两个方法）：
/// `clock_in_provider_test.dart` 里的桩件把 `listCampuses` / `loadCampusCache`
/// 都替掉了，那条路径上的缓存行为在那里测不到，只能在这里测。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const ClockInRepository repo = ClockInRepository();
  const String cacheKey = 'clock_in_campus_cache_v1';

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test('写缓存后能原样读回：坐标、半径、名称都不丢', () async {
    final DateTime before = DateTime.now();
    await repo.saveCampusCache(const <Campus>[
      Campus(
        id: 1,
        name: '甲校区',
        latitude: 45.98555,
        longitude: 126.599363,
        radiusMeters: 1500,
      ),
      Campus(id: 2, name: '乙校区'),
    ]);

    final CampusCache? back = await repo.loadCampusCache();

    expect(back, isNotNull, reason: '刚写进去就读不回来，离线兜底直接失效');
    expect(back!.campuses, hasLength(2));
    final Campus first = back.campuses.first;
    expect(first.id, 1);
    expect(first.name, '甲校区');
    expect(first.latitude, closeTo(45.98555, 1e-9));
    expect(first.longitude, closeTo(126.599363, 1e-9));
    expect(first.radiusMeters, 1500);
    expect(first.hasGeo, isTrue);
    // 未配坐标的校区不能在往返中「长出」坐标
    expect(back.campuses[1].hasGeo, isFalse);
    expect(back.campuses[1].latitude, isNull);
    // 时间戳要落在写入前后之间（不该是 1970 或未来）
    expect(back.cachedAt.isBefore(before.subtract(const Duration(minutes: 1))),
        isFalse,
        reason: '时间戳解析失败会让「数据来自 X 时」的提示显示错误的陈旧度');
  });

  test('没有缓存 → 返回 null（不是空列表）', () async {
    expect(await repo.loadCampusCache(), isNull);
  });

  test('缓存损坏 → 返回 null，不抛异常', () async {
    // 坏了就当没有：上层会转成「明确失败 + 重试」，而不是让打卡页崩掉。
    for (final String bad in <String>['{不是 JSON', '[]', '{"list":"x"}', 'null']) {
      SharedPreferences.setMockInitialValues(<String, Object>{cacheKey: bad});
      expect(await repo.loadCampusCache(), isNull, reason: 'bad=$bad');
    }
  });

  test('缓存里的列表为空 → 视为没有缓存', () async {
    // 「空列表」与「没有缓存」语义不同，若不区分，上层会把失败原因说错。
    SharedPreferences.setMockInitialValues(<String, Object>{
      cacheKey: '{"at":"2026-09-18T10:30:00","list":[]}',
    });
    expect(await repo.loadCampusCache(), isNull);
  });

  test('时间戳缺失 → 仍返回数据（宁可用「现在」也不丢真实数据）', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      cacheKey: '{"list":[{"id":7,"name":"丙校区","latitude":45.0,"longitude":126.0}]}',
    });
    final CampusCache? back = await repo.loadCampusCache();
    expect(back, isNotNull,
        reason: '缺个时间戳就丢掉整份数据，会让断网老师直接打不了卡');
    expect(back!.campuses.single.id, 7);
  });
}
