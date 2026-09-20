import 'package:flutter_test/flutter_test.dart';
import 'package:teacher_app/core/constants.dart';
import 'package:teacher_app/data/models/campus.dart';
import 'package:teacher_app/features/clock_in/domain/geo.dart';

/// 校区打卡配置（坐标 / 半径）与坐标系的契约测试。
///
/// 这些用例守的都是**静默故障**：配置脏了不会报错，只会让老师打不了卡、
/// 或者让地图上的点整体偏移几百米 —— 两种都极难从现象反推到原因，所以钉在测试里。
void main() {
  group('Campus.hasGeo —— 脏坐标必须被当成「没配」', () {
    test('未填坐标 → 不可打卡', () {
      const Campus c = Campus(id: 7, name: '新校区');
      expect(c.hasGeo, isFalse);
      expect(c.effectiveRadius, AppConstants.clockInRadiusMeters);
    });

    test('(0,0) 是几内亚湾的真实点，但本产品语境下必然是漏填', () {
      const Campus c = Campus(id: 7, name: '新校区', latitude: 0, longitude: 0);
      expect(c.hasGeo, isFalse,
          reason: '判成有坐标会算出约 1.1 万公里，提示「超出围栏」却毫无指向性');
    });

    test('越界坐标 → 不可打卡', () {
      expect(const Campus(id: 1, name: 'x', latitude: 91, longitude: 126).hasGeo,
          isFalse);
      expect(const Campus(id: 1, name: 'x', latitude: 45, longitude: 181).hasGeo,
          isFalse);
      expect(const Campus(id: 1, name: 'x', latitude: -90.5, longitude: 0.5).hasGeo,
          isFalse);
    });

    test('只填了一半 → 不可打卡', () {
      expect(const Campus(id: 1, name: 'x', latitude: 45.9).hasGeo, isFalse);
      expect(const Campus(id: 1, name: 'x', longitude: 126.5).hasGeo, isFalse);
    });

    test('正常坐标 → 可打卡', () {
      const Campus c =
          Campus(id: 1, name: '呼兰校区', latitude: 45.98555, longitude: 126.599363);
      expect(c.hasGeo, isTrue);
    });
  });

  group('Campus.effectiveRadius —— 0 不是 null，?? 兜不住它', () {
    test('未配置 → 用全局默认', () {
      expect(const Campus(id: 1, name: 'x').effectiveRadius,
          AppConstants.clockInRadiusMeters);
    });

    test('配了就用配置值', () {
      const Campus c = Campus(
          id: 1, name: 'x', latitude: 45.9, longitude: 126.5, radiusMeters: 8000);
      expect(c.effectiveRadius, 8000);
    });

    test('配成 0 / 负数 → 回退默认，而不是「零米围栏」', () {
      const Campus zero = Campus(
          id: 1, name: 'x', latitude: 45.9, longitude: 126.5, radiusMeters: 0);
      const Campus neg = Campus(
          id: 1, name: 'x', latitude: 45.9, longitude: 126.5, radiusMeters: -5);
      expect(zero.effectiveRadius, AppConstants.clockInRadiusMeters,
          reason: '0 米围栏会让全园老师被判「超出围栏 0 米」而全打不了卡');
      expect(neg.effectiveRadius, AppConstants.clockInRadiusMeters);
    });
  });

  group('Campus.fromJson —— 与后台的字段契约', () {
    test('clockRadius 映射到 radiusMeters，null 不能变成 0', () {
      final Campus a = Campus.fromJson(<String, dynamic>{
        'id': 3,
        'name': '测试校区',
        'latitude': 45.1,
        'longitude': 126.2,
        'clockRadius': 1200,
      });
      expect(a.id, 3);
      expect(a.radiusMeters, 1200);
      expect(a.hasGeo, isTrue);

      final Campus b =
          Campus.fromJson(<String, dynamic>{'id': 4, 'name': '缺省校区'});
      expect(b.latitude, isNull);
      expect(b.radiusMeters, isNull,
          reason: 'null 若被转成 0，会静默算出一个巨大的距离');
      expect(b.hasGeo, isFalse);
    });

    test('字符串形式的数字也能解析（后端序列化差异）', () {
      final Campus c = Campus.fromJson(<String, dynamic>{
        'id': 5,
        'name': 'x',
        'latitude': '45.1',
        'longitude': '126.2',
      });
      expect(c.hasGeo, isTrue);
    });

    test('按 id 判等：列表刷新后下拉框仍认得出当前选中项', () {
      final Campus a = Campus.fromJson(<String, dynamic>{'id': 3, 'name': '旧名'});
      final Campus b = Campus.fromJson(<String, dynamic>{
        'id': 3,
        'name': '新名',
        'latitude': 45.1,
        'longitude': 126.2,
      });
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('后台没给坐标就是没给 —— 不会按 id 从任何内置表里补', () {
      // 曾经的 `mergeBuiltinGeo()` 会在后台缺坐标时，按 id 把 App 内置的
      // 呼兰/道里坐标顶上去。那套兜底已删除，因为它是固定值：管理员在后台
      // 改过校区位置后，离线状态会拿旧坐标判围栏，老师被拒打卡却看不出原因。
      //
      // 这条用例用**曾经内置过的 id=1** 验证：后台不给坐标，它就是没坐标。
      // 万一将来有人重新引入「按 id 顶坐标」，这里会立刻变红。
      final Campus c =
          Campus.fromJson(<String, dynamic>{'id': 1, 'name': '呼兰校区'});
      expect(c.hasGeo, isFalse,
          reason: 'id=1 的内置坐标已删除，不得再被任何兜底逻辑顶上');
      expect(c.latitude, isNull);
      expect(c.longitude, isNull);
    });
  });

  group('Campus.toJson / fromJson —— 本地缓存往返', () {
    test('往返后字段不丢（缓存与后台解析走同一条字段映射）', () {
      const Campus src = Campus(
        id: 3,
        name: '测试校区',
        latitude: 45.1,
        longitude: 126.2,
        radiusMeters: 1200,
      );
      final Campus back = Campus.fromJson(src.toJson());
      expect(back.id, 3);
      expect(back.name, '测试校区');
      expect(back.latitude, closeTo(45.1, 1e-9));
      expect(back.longitude, closeTo(126.2, 1e-9));
      expect(back.radiusMeters, 1200);
      expect(back.hasGeo, isTrue);
    });

    test('未配坐标的校区往返后仍是「未配」，不会凭空长出坐标', () {
      const Campus src = Campus(id: 4, name: '未配坐标校区');
      final Campus back = Campus.fromJson(src.toJson());
      expect(back.latitude, isNull);
      expect(back.longitude, isNull);
      expect(back.radiusMeters, isNull);
      expect(back.hasGeo, isFalse,
          reason: 'null 在缓存往返中被写成 0 的话，离线时就会静默算出巨大距离');
    });
  });

  group('wgs84ToGcj02 —— 只给地图用，但必须真的偏移', () {
    double shiftMeters(double lat, double lng) {
      final ({double lat, double lng}) g = wgs84ToGcj02(lat, lng);
      return haversineDistance(lat1: lat, lon1: lng, lat2: g.lat, lon2: g.lng);
    }

    test('国内点必须偏移几百米（写成恒等变换会被这条立刻抓住）', () {
      // 本地区实测偏移 503~604 米
      for (final List<double> p in <List<double>>[
        <double>[45.98555, 126.599363],
        <double>[45.732986, 126.587281],
      ]) {
        final double d = shiftMeters(p[0], p[1]);
        expect(d, greaterThan(200), reason: '偏移过小，多半退化成恒等变换');
        expect(d, lessThan(900), reason: '偏移过大，多半算错或重复套用');
      }
    });

    test('境外点原样返回（偏移只在国内生效）', () {
      expect(isOutOfChina(35.68, 139.76), isTrue);
      final ({double lat, double lng}) g = wgs84ToGcj02(35.68, 139.76);
      expect(g.lat, 35.68);
      expect(g.lng, 139.76);
    });

    test('是一次小平移，不是把坐标挪到别处', () {
      final ({double lat, double lng}) g = wgs84ToGcj02(45.98555, 126.599363);
      expect((g.lat - 45.98555).abs(), lessThan(0.02));
      expect((g.lng - 126.599363).abs(), lessThan(0.02));
    });
  });
}
