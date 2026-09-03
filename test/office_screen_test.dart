import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teacher_app/core/auth_store.dart';
import 'package:teacher_app/features/office/office_screen.dart';

/// 办公页入口的角色可见性（2026-09-03 审批功能）。
///
/// 需求：办公页新增「审批」入口，仅 财务/园长/管理员 可见；
/// 教师等其他角色完全看不到。此处用 widget 测试锁定该行为，
/// 避免以后改办公页时不小心把角色过滤弄丢。
void main() {
  // AuthStore 是单例，测试间要还原，避免污染其它用例。
  tearDown(() {
    AuthStore.instance.roles = const <String>[];
  });

  Future<void> pumpOffice(WidgetTester tester) async {
    // 头部的 ThemeToggleButton 是 Riverpod ConsumerWidget，必须包 ProviderScope。
    // 不用 pumpAndSettle()：页内可能有无限循环动画，会永久挂起（见 app_boot_test 的注释）。
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: OfficeScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('教师：看不到「审批」入口，普通入口不受影响', (tester) async {
    AuthStore.instance.roles = const <String>['TEACHER'];
    await pumpOffice(tester);
    expect(find.text('审批'), findsNothing);
    // 教师日常要用的入口必须都在。
    expect(find.text('请假申请'), findsOneWidget);
    expect(find.text('补卡申请'), findsOneWidget);
    expect(find.text('财务报销'), findsOneWidget);
    expect(find.text('员工信箱'), findsOneWidget);
  });

  testWidgets('财务：可见「审批」入口', (tester) async {
    AuthStore.instance.roles = const <String>['FINANCE'];
    await pumpOffice(tester);
    expect(find.text('审批'), findsOneWidget);
  });

  testWidgets('园长：可见「审批」入口', (tester) async {
    AuthStore.instance.roles = const <String>['PRINCIPAL'];
    await pumpOffice(tester);
    expect(find.text('审批'), findsOneWidget);
  });

  testWidgets('管理员：可见「审批」入口', (tester) async {
    AuthStore.instance.roles = const <String>['ADMIN'];
    await pumpOffice(tester);
    expect(find.text('审批'), findsOneWidget);
  });

  testWidgets('多角色（教师+园长）：取并集，可见「审批」', (tester) async {
    AuthStore.instance.roles = const <String>['TEACHER', 'PRINCIPAL'];
    await pumpOffice(tester);
    expect(find.text('审批'), findsOneWidget);
  });

  testWidgets('未登录（无角色）：看不到「审批」入口', (tester) async {
    AuthStore.instance.roles = const <String>[];
    await pumpOffice(tester);
    expect(find.text('审批'), findsNothing);
  });
}
