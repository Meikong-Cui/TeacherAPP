// 持续评估表日期栏：锁定「存量日期文本如何收敛成 YYYY-MM-DD」的规则。
//
// 这条规则在网页端也有一份（oa-admin-web/src/components/rehab/ContEvalCatalogForm.tsx
// 的 `canonicalDate`），两边必须逐字一致 —— 否则同一份数据在网页能规范化、
// 在 App 却被判非法，老师会以为其中一端坏了。改动本文件时请同步改那边。
//
// 用例覆盖：标准值原样返回、斜杠写法补齐零、带时间后缀取日期部分、
// 不认的写法返回 null、以及 2026-02-31 这类会被 DateTime 自动进位的假日期要被挡掉。
import 'package:flutter_test/flutter_test.dart';
import 'package:teacher_app/features/rehab/presentation/widgets/cont_eval_catalog_form.dart';

void main() {
  group('canonicalContEvalDate', () {
    test('标准 YYYY-MM-DD 原样返回', () {
      expect(canonicalContEvalDate('2026-03-02'), '2026-03-02');
      expect(canonicalContEvalDate('2026-12-31'), '2026-12-31');
    });

    test('斜杠写法补齐零（老师手打过 2026/3/2）', () {
      expect(canonicalContEvalDate('2026/3/2'), '2026-03-02');
      expect(canonicalContEvalDate('2026/03/02'), '2026-03-02');
      expect(canonicalContEvalDate('2026-3-2'), '2026-03-02');
    });

    test('带时间后缀时只取日期部分', () {
      expect(canonicalContEvalDate('2026-03-02 00:00:00'), '2026-03-02');
      expect(canonicalContEvalDate('2026-03-02T10:30:00'), '2026-03-02');
    });

    test('首尾空格不算错', () {
      expect(canonicalContEvalDate('  2026-03-02  '), '2026-03-02');
    });

    test('空值返回 null（不是错误，只是没填）', () {
      expect(canonicalContEvalDate(null), isNull);
      expect(canonicalContEvalDate(''), isNull);
      expect(canonicalContEvalDate('   '), isNull);
    });

    test('认不出来的写法返回 null（由 UI 提示老师重选，不静默丢数据）', () {
      expect(canonicalContEvalDate('待定'), isNull);
      expect(canonicalContEvalDate('2026年3月2日'), isNull);
      expect(canonicalContEvalDate('03/02/2026'), isNull);
      expect(canonicalContEvalDate('2026-3'), isNull);
      expect(canonicalContEvalDate('abc2026-03-02'), isNull);
    });

    test('月份/日越界返回 null', () {
      expect(canonicalContEvalDate('2026-00-10'), isNull);
      expect(canonicalContEvalDate('2026-13-10'), isNull);
      expect(canonicalContEvalDate('2026-03-00'), isNull);
      expect(canonicalContEvalDate('2026-03-32'), isNull);
    });

    test('2 月 31 日这类被自动进位的假日期要挡掉', () {
      // DateTime(2026, 2, 31) 会变成 3 月 3 日；回读校验必须发现不一致
      expect(canonicalContEvalDate('2026-02-31'), isNull);
      expect(canonicalContEvalDate('2026-04-31'), isNull);
    });

    test('闰年 2 月 29 日是合法日期', () {
      expect(canonicalContEvalDate('2024-02-29'), '2024-02-29');
      // 2026 不是闰年
      expect(canonicalContEvalDate('2026-02-29'), isNull);
    });
  });
}
