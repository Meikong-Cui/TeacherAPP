import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:teacher_app/main.dart';

void main() {
  testWidgets('App boots and renders a MaterialApp', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: TeacherApp()),
    );

    // 注意：不要用 pumpAndSettle()。
    // 启动页/登录页存在 CircularProgressIndicator 等无限循环动画，
    // pumpAndSettle 会一直等待"动画静止"而永久挂起（测试卡死）。
    // 这里只推进有限帧，足以让首帧构建完成。
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
