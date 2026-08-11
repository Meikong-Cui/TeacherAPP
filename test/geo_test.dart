import 'package:flutter_test/flutter_test.dart';
import 'package:teacher_app/features/clock_in/domain/geo.dart';

void main() {
  group('haversineDistance', () {
    test('同一点距离为 0', () {
      final d = haversineDistance(
        lat1: 23.1291, lon1: 113.2644,
        lat2: 23.1291, lon2: 113.2644,
      );
      expect(d, closeTo(0, 0.001));
    });

    test('纬度相差 1 度约 111.19 公里', () {
      final d = haversineDistance(
        lat1: 0, lon1: 0,
        lat2: 1, lon2: 0,
      );
      expect(d, closeTo(111194.9, 50));
    });

    test('赤道上经度相差 1 度约 111.19 公里', () {
      final d = haversineDistance(
        lat1: 0, lon1: 0,
        lat2: 0, lon2: 1,
      );
      expect(d, closeTo(111194.9, 50));
    });

    test('高纬度经度距离收缩（北纬 60 度约为赤道一半）', () {
      final d = haversineDistance(
        lat1: 60, lon1: 0,
        lat2: 60, lon2: 1,
      );
      expect(d, closeTo(55597.5, 100));
    });

    test('距离对称：A→B 等于 B→A', () {
      const a = [23.1291, 113.2644];
      const b = [23.1350, 113.2700];
      final ab = haversineDistance(lat1: a[0], lon1: a[1], lat2: b[0], lon2: b[1]);
      final ba = haversineDistance(lat1: b[0], lon1: b[1], lat2: a[0], lon2: a[1]);
      expect(ab, closeTo(ba, 0.0001));
    });

    test('跨 180 度经线不应算成绕地球一圈', () {
      final d = haversineDistance(
        lat1: 0, lon1: 179.5,
        lat2: 0, lon2: -179.5,
      );
      // 实际只差 1 度 ≈ 111km，若实现有误会算成 ~39900km
      expect(d, closeTo(111194.9, 100));
    });

    test('负纬度（南半球）正常计算', () {
      final d = haversineDistance(
        lat1: -33.8688, lon1: 151.2093,
        lat2: -33.8700, lon2: 151.2093,
      );
      expect(d, closeTo(133, 10));
    });

    group('1000 米围栏判定边界', () {
      const campusLat = 23.1291;
      const campusLon = 113.2644;
      const fence = 1000.0;

      test('围栏内：约 100 米处应通过', () {
        final d = haversineDistance(
          lat1: campusLat, lon1: campusLon,
          lat2: campusLat + 0.0009, lon2: campusLon,
        );
        expect(d, lessThan(fence));
      });

      test('围栏外：约 2 公里处应拒绝', () {
        final d = haversineDistance(
          lat1: campusLat, lon1: campusLon,
          lat2: campusLat + 0.018, lon2: campusLon,
        );
        expect(d, greaterThan(fence));
      });

      test('临界点附近可稳定判定（0.0089 度 ≈ 990m）', () {
        final d = haversineDistance(
          lat1: campusLat, lon1: campusLon,
          lat2: campusLat + 0.0089, lon2: campusLon,
        );
        expect(d, closeTo(989, 15));
        expect(d < fence, isTrue);
      });
    });
  });
}
