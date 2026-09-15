import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teacher_app/app/design_tokens.dart';
import 'package:teacher_app/core/auth_store.dart';
import 'package:teacher_app/core/constants.dart';
import 'package:teacher_app/features/auth/login_screen.dart';

/// 登录页（毛玻璃重写版）行为锁定。
///
/// 背景：2026-09-15 把登录页整体重做成「全屏渐变光斑背景 + 居中毛玻璃卡片」，
/// 并做了两处需求变更（品牌更名「哈哈龙」、去掉演示账号提示行）。
/// 这个文件把「能看见的行为」和「被批准的视觉参数」都钉住，
/// 防止以后改别的地方顺手改坏登录页 —— 它是 App 唯一入口，坏了等于全盘不可用。
void main() {
  // AuthStore 是单例，测试之间要还原，避免污染其它用例。
  tearDown(() {
    AuthStore.instance.token = null;
    AuthStore.instance.userName = null;
    AuthStore.instance.roles = const <String>[];
  });

  /// 用手机尺寸（400×800）渲染，比默认的 800×600 更接近真机，
  /// 能顺带兜住横向溢出这类只在窄屏出现的问题。
  Future<void> pumpLogin(WidgetTester tester, {bool dark = true}) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          // LoginScreen 按 Theme.brightness 选深浅两套玻璃皮肤，两套都要跑到。
          theme: ThemeData(brightness: dark ? Brightness.dark : Brightness.light),
          home: const LoginScreen(),
        ),
      ),
    );
    // 不要用 pumpAndSettle()：页内若出现 CircularProgressIndicator 会永久挂起
    // （见 app_boot_test.dart 的注释）。推有限帧足够完成首帧构建。
    await tester.pump(const Duration(milliseconds: 100));
  }

  /// 树里是否存在指定填充色的 DecoratedBox（用来确认玻璃底色/描边真的生效）。
  bool hasDecoration(
    WidgetTester tester, {
    Color? color,
    Color? borderColor,
  }) {
    return tester.widgetList<DecoratedBox>(find.byType(DecoratedBox)).any((d) {
      final Decoration deco = d.decoration;
      if (deco is! BoxDecoration) return false;
      if (color != null && deco.color != color) return false;
      if (borderColor != null && deco.border?.top.color != borderColor) {
        return false;
      }
      return true;
    });
  }

  group('品牌与文案', () {
    testWidgets('品牌区显示「哈哈龙康复 / HA HA LONG」', (tester) async {
      await pumpLogin(tester);
      expect(find.text(AppConstants.brandName), findsOneWidget);
      expect(find.text(AppConstants.brandLatin), findsOneWidget);
      expect(find.text('哈哈龙康复'), findsOneWidget);
      expect(find.text('HA HA LONG'), findsOneWidget);
    });

    testWidgets('不再出现「演示账号」提示行', (tester) async {
      await pumpLogin(tester);
      expect(find.textContaining('演示账号'), findsNothing);
    });

    testWidgets('标题与表单元素齐全', (tester) async {
      await pumpLogin(tester);
      expect(find.text('教师端登录'), findsOneWidget);
      expect(find.text('康复管理系统 · 教师工作台'), findsOneWidget);
      expect(find.text('工号 / 手机号'), findsOneWidget);
      expect(find.text('密码'), findsOneWidget);
      expect(find.text('忘记密码？'), findsOneWidget);
      expect(find.text('登录'), findsOneWidget);
      // 账号 + 密码两个输入框。
      expect(find.byType(TextField), findsNWidgets(2));
    });

    testWidgets('旧品牌名「语亦丰」已彻底清除', (tester) async {
      await pumpLogin(tester);
      expect(find.textContaining('语亦丰'), findsNothing);
      expect(find.textContaining('Yu Yi Feng'), findsNothing);
    });
  });

  group('被批准的视觉参数', () {
    testWidgets('标题走「轻盈细线」：字重 w300 + 字距 3 + 细黑体候选链', (tester) async {
      await pumpLogin(tester);
      final Text title = tester.widget<Text>(find.text('教师端登录'));
      expect(title.style?.fontWeight, AppFontWeight.light);
      expect(title.style?.fontWeight, FontWeight.w300);
      expect(title.style?.letterSpacing, 3);
      expect(title.style?.fontFamilyFallback, AppFontFamily.thinSansCjk);
      // 候选链尾部必须有通用兜底，保证任何平台都能渲染出字。
      expect(AppFontFamily.thinSansCjk.last, 'sans-serif');
    });

    testWidgets('毛玻璃结构存在：ClipRRect(28) 包住 BackdropFilter', (tester) async {
      await pumpLogin(tester);
      expect(find.byType(BackdropFilter), findsOneWidget);

      final Finder clip = find.ancestor(
        of: find.byType(BackdropFilter),
        matching: find.byType(ClipRRect),
      );
      expect(clip, findsWidgets);
      expect(
        tester.widget<ClipRRect>(clip.first).borderRadius,
        BorderRadius.circular(28),
      );
    });

    testWidgets('深色玻璃：底色 white 0.115 / 描边 white 0.26', (tester) async {
      await pumpLogin(tester, dark: true);
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
        const Color(0xFF04211F),
      );
      expect(hasDecoration(tester, color: const Color(0x1DFFFFFF)), isTrue);
      expect(
        hasDecoration(tester, borderColor: const Color(0x42FFFFFF)),
        isTrue,
      );
    });

    testWidgets('浅色玻璃：底色 white 0.520 / 描边 white 0.85', (tester) async {
      await pumpLogin(tester, dark: false);
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
        const Color(0xFFEAFBF7),
      );
      expect(hasDecoration(tester, color: const Color(0x85FFFFFF)), isTrue);
      expect(
        hasDecoration(tester, borderColor: const Color(0xD9FFFFFF)),
        isTrue,
      );
    });

    testWidgets('玻璃阴影画在 ClipRRect 外层（放进被裁剪子树会被剪掉）', (tester) async {
      await pumpLogin(tester);
      final Finder clip = find
          .ancestor(
            of: find.byType(BackdropFilter),
            matching: find.byType(ClipRRect),
          )
          .first;
      final Finder outerContainer = find.ancestor(
        of: clip,
        matching: find.byType(Container),
      );
      expect(outerContainer, findsWidgets);

      final Container outer = tester.widget<Container>(outerContainer.first);
      final BoxDecoration? deco = outer.decoration as BoxDecoration?;
      expect(deco?.boxShadow, isNotNull);
      expect(deco!.boxShadow!.first.blurRadius, 60);
      expect(deco.boxShadow!.first.offset, const Offset(0, 24));
    });
  });

  group('交互', () {
    testWidgets('密码默认隐藏，点眼睛图标可切换显示', (tester) async {
      await pumpLogin(tester);

      expect(
        tester.widget<TextField>(find.byType(TextField).at(1)).obscureText,
        isTrue,
      );
      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);

      await tester.tap(find.byIcon(Icons.visibility_off_outlined));
      await tester.pump();

      expect(
        tester.widget<TextField>(find.byType(TextField).at(1)).obscureText,
        isFalse,
      );
      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
      expect(find.byIcon(Icons.visibility_off_outlined), findsNothing);
    });

    testWidgets('账号为空时拦截提交并提示', (tester) async {
      await pumpLogin(tester);
      await tester.enterText(find.byType(TextField).at(0), '');
      await tester.tap(find.text('登录'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('请输入账号'), findsOneWidget);
      // 校验不通过就不该进 loading 态。
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('密码为空时拦截提交并提示', (tester) async {
      await pumpLogin(tester);
      await tester.enterText(find.byType(TextField).at(1), '');
      await tester.tap(find.text('登录'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('请输入密码'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('主题切换按钮可用，且用的是登录页传的紧凑参数（18 / dense）', (tester) async {
      await pumpLogin(tester);

      // 尺寸由 IconButton.iconSize 下发（Icon 自身 size 为 null），
      // dense 则体现在 padding 归零 + 命中区压到 38×38 —— 都是登录页传进去的。
      Finder toggle(IconData icon) => find.ancestor(
            of: find.byIcon(icon),
            matching: find.byType(IconButton),
          );
      final IconButton btn =
          tester.widget<IconButton>(toggle(Icons.brightness_auto_outlined));
      expect(btn.iconSize, 18);
      expect(btn.padding, EdgeInsets.zero);
      expect(btn.constraints, const BoxConstraints.tightFor(width: 38, height: 38));

      // 点一下按 system → light → dark 循环推进。
      await tester.tap(find.byIcon(Icons.brightness_auto_outlined));
      await tester.pump();
      expect(find.byIcon(Icons.light_mode_outlined), findsOneWidget);

      await tester.tap(find.byIcon(Icons.light_mode_outlined));
      await tester.pump();
      expect(find.byIcon(Icons.dark_mode_outlined), findsOneWidget);
    });

    testWidgets('「忘记密码？」给出明确出口（SnackBar），不是点不动的死链', (tester) async {
      await pumpLogin(tester);
      await tester.tap(find.text('忘记密码？'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('请联系园区管理员重置密码'), findsOneWidget);
      // 让 4 秒自动消失的定时器跑完，避免测试结束时留下 pending timer。
      await tester.pumpAndSettle();
    });
  });

  group('登录失败兜底', () {
    testWidgets('后端不可达时显示错误提示并恢复按钮，不无限转圈', (tester) async {
      await pumpLogin(tester);

      // 测试环境下 HTTP 一律被 flutter_test 拦成 400，因此这里必然走失败分支，
      // 正好用来验「失败有反馈、loading 会复位」这条防御式体验。
      await tester.tap(find.text('登录'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 500));

      // 错误条出现（用图标判断，不依赖后端具体错误文案）。
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
      // loading 已复位：转圈消失、按钮文字回来了，用户能再点一次。
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('登录'), findsOneWidget);
      expect(AuthStore.instance.isLoggedIn, isFalse);
    });
  });
}
