import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teacher_app/shared/attachment_gallery.dart';

/// 附件画廊：请款单**没有金额字段**，金额只存在于「购买凭证 / 支付记录」图片里，
/// 所以「有没有附件、有几张、没附件时说不说得清」是审批能否成立的前提。
/// 这里用测试把这三件事锁住，避免以后改 UI 时把凭证区改没了。
void main() {
  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
    // 不用 pumpAndSettle()：页内有进度动画会永久挂起，推有限帧即可。
    await tester.pump(const Duration(milliseconds: 100));
  }

  test('looksLikeImage：只按扩展名判定，且大小写/查询串不影响结果', () {
    expect(AttachmentGallery.looksLikeImage('/uploads/a.jpg'), isTrue);
    expect(AttachmentGallery.looksLikeImage('/uploads/a.JPEG'), isTrue);
    expect(AttachmentGallery.looksLikeImage('https://x/y/z.PNG?w=200'), isTrue);
    expect(AttachmentGallery.looksLikeImage('/uploads/contract.pdf'), isFalse);
    // 无扩展名的后端路径不该被误判成图片
    expect(AttachmentGallery.looksLikeImage('/uploads/receipt'), isFalse);
  });

  testWidgets('没有附件：给出明确文案，而不是留白', (WidgetTester tester) async {
    await pump(
      tester,
      const AttachmentGallery(
        urls: <String>[],
        label: '购买凭证 / 支付记录',
        emptyText: '本单没有上传凭证（异常，建议驳回并让申请人补充）',
      ),
    );
    expect(find.text('本单没有上传凭证（异常，建议驳回并让申请人补充）'),
        findsOneWidget);
  });

  testWidgets('有附件：标题给出张数，逐张渲染缩略图与序号角标', (WidgetTester tester) async {
    // 刻意用非图片扩展名：图片分支会走 Image.network，
    // flutter_test 里必然加载失败，徒增噪声；数量/序号逻辑与扩展名无关。
    await pump(
      tester,
      const AttachmentGallery(
        urls: <String>['/uploads/a.pdf', '/uploads/b.pdf', '/uploads/c.pdf'],
        label: '购买凭证',
      ),
    );
    expect(find.textContaining('购买凭证（共 3 张）'), findsOneWidget);
    expect(find.byIcon(Icons.insert_drive_file_outlined), findsNWidgets(3));
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('单张附件也带「共 1 张」与序号，不会退化成纯文字', (WidgetTester tester) async {
    await pump(
      tester,
      const AttachmentGallery(urls: <String>['/uploads/only.pdf'], label: '合同材料'),
    );
    expect(find.textContaining('合同材料（共 1 张）'), findsOneWidget);
    expect(find.byIcon(Icons.insert_drive_file_outlined), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
  });
}
