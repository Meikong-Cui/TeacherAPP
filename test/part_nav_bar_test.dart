import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teacher_app/features/rehab/presentation/widgets/part_nav_bar.dart';

/// 长表单底部翻页条（首次评估 1.1.1 / 持续评估 1.1.2 共用）。
///
/// 背景（2026-09-15 用户反馈）：
///   · 持续评估的翻页入口原来只挂在「基本资料」和「总结」两页上，
///     中间 7 个目录页**一个都没有** → 老师填完第 1 页直接卡死；
///   · 首次评估的翻页条是每部分 ListView 的**第一个子项**（内容顶部），
///     一页几十个字段，滑到底必须滚回顶部才能翻页。
///
/// 现在统一成底部固定条，这里锁定它的行为与布局约束。
void main() {
  Future<void> pump(
    WidgetTester tester, {
    required int index,
    required int count,
    VoidCallback? onPrev,
    VoidCallback? onNext,
    String? nextLabel,
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PartNavBar(
          index: index,
          count: count,
          onPrev: onPrev,
          onNext: onNext,
          nextLabel: nextLabel,
        ),
      ),
    ));
  }

  testWidgets('中间部分：两侧按钮都在，页码正确，点击各触发一次', (WidgetTester tester) async {
    int prevHits = 0;
    int nextHits = 0;
    await pump(tester, index: 1, count: 9,
        onPrev: () => prevHits++, onNext: () => nextHits++);

    expect(find.text('2 / 9'), findsOneWidget);
    expect(find.text('上一部分'), findsOneWidget);
    expect(find.text('下一部分 →'), findsOneWidget);

    await tester.tap(find.text('上一部分'));
    await tester.tap(find.text('下一部分 →'));
    expect(prevHits, 1);
    expect(nextHits, 1);
  });

  testWidgets('第一部分：不渲染「上一部分」（不是渲染成灰按钮）', (WidgetTester tester) async {
    await pump(tester, index: 0, count: 9, onNext: () {});

    expect(find.text('上一部分'), findsNothing);
    expect(find.text('下一部分 →'), findsOneWidget);
    expect(find.text('1 / 9'), findsOneWidget);
  });

  testWidgets('最后一部分：不渲染「下一部分」', (WidgetTester tester) async {
    await pump(tester, index: 8, count: 9, onPrev: () {});

    expect(find.text('上一部分'), findsOneWidget);
    expect(find.textContaining('下一部分'), findsNothing);
    expect(find.text('9 / 9'), findsOneWidget);
  });

  testWidgets('窄屏 + 超长页名不溢出（纸表页名可能很长）', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pump(tester, index: 2, count: 9,
        onPrev: () {}, onNext: () {},
        nextLabel: '下一部分：接听电话 / 主动聆听 / 评估标准 / 词汇 / 问句 →');

    // RenderFlex overflow 会以异常形式抛出，这里断言没有被抛。
    expect(tester.takeException(), isNull);
  });

  testWidgets('自定义文案生效（首次评估用「下一部分：评估内容 →」）', (WidgetTester tester) async {
    await pump(tester, index: 0, count: 3,
        onNext: () {}, nextLabel: '下一部分：评估内容 →');

    expect(find.text('下一部分：评估内容 →'), findsOneWidget);
    expect(find.text('1 / 3'), findsOneWidget);
  });
}
