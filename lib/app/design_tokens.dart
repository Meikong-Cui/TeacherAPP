import 'package:flutter/material.dart';

/// ════════════════════════════════════════════════════════════════
///  设计 Token（统一视觉语言常量）
///  修改本文件即可全局生效；详见 doc/UI_STYLE_GUIDE.md。
/// ════════════════════════════════════════════════════════════════
///
/// 设计原则：
/// 1. 圆角统一三档：12（卡片/按钮）/ 16（大卡片）/ 999（药丸标签）。
/// 2. 阴影统一两档：sm（列表卡片）/ md（浮起按钮/抽屉）。
/// 3. 强调色（Teal #14B8A6）= 信任、成长；辅色按业务语义复用。
/// 4. 字号梯度 6 档，禁止页面内随意新增字号。
/// 5. 间距梯度 4 档（4/8/12/16/24），全部使用 token。

class AppRadius {
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double pill = 999;
}

class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
}

class AppFontSize {
  static const double caption = 11;
  static const double small = 12;
  static const double body = 14;
  static const double title = 16;
  static const double subtitle = 18;
  static const double headline = 22;
  static const double display = 28;
}

class AppFontWeight {
  static const FontWeight normal = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semibold = FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;
  static const FontWeight extrabold = FontWeight.w800;
}

class AppShadow {
  static const List<BoxShadow> sm = <BoxShadow>[
    BoxShadow(
      color: Color(0x0A0F1F1B),
      blurRadius: 6,
      offset: Offset(0, 2),
    ),
  ];
  static const List<BoxShadow> md = <BoxShadow>[
    BoxShadow(
      color: Color(0x140F1F1B),
      blurRadius: 14,
      offset: Offset(0, 6),
    ),
  ];
  static const List<BoxShadow> lg = <BoxShadow>[
    BoxShadow(
      color: Color(0x1F0F1F1B),
      blurRadius: 22,
      offset: Offset(0, 10),
    ),
  ];
}

/// 业务辅色（与 design guide 颜色章节保持一致）。
/// 注意：这些颜色不参与 ColorScheme，仅用于卡片背景 / 渐变端点 / 图标强调。
class AppPalette {
  // 主品牌色
  static const Color brand = Color(0xFF14B8A6); // Teal
  static const Color brandDark = Color(0xFF0D9488);
  static const Color brandSoft = Color(0xFF5EEAD4);

  // 中性色
  static const Color ink = Color(0xFF102A27); // 正文
  static const Color inkMute = Color(0xFF5B6F6C); // 次级文字
  static const Color line = Color(0xFFCFE0DD); // 描边/分割线
  static const Color canvas = Color(0xFFF7FAFA); // 页面背景

  // 功能色
  static const Color success = Color(0xFF0EA5A4); // 进行中/通过
  static const Color warning = Color(0xFFE08A1E); // 截止/待
  static const Color danger = Color(0xFFE2683B); // 预警/驳回
  static const Color info = Color(0xFF2F7FF0);
  static const Color gold = Color(0xFFC99A00);
  static const Color purple = Color(0xFF7C5CF0);
  static const Color rose = Color(0xFFE2683B);
  static const Color sky = Color(0xFF2F7FF0);
  static const Color amber = Color(0xFFC99A00);
}

/// 业务渐变（卡片/Logo 区常用）。
class AppGradients {
  static const LinearGradient teal = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFF5EEAD4), Color(0xFF14B8A6)],
  );

  static const LinearGradient tealLight = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFFA7F3D0), Color(0xFF5EEAD4)],
  );

  static const LinearGradient sky = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFFBFE3FF), Color(0xFF7BB7FF)],
  );

  static const LinearGradient amber = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFFFFE08A), Color(0xFFFFB347)],
  );

  static const LinearGradient rose = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFFFFD3C4), Color(0xFFF89977)],
  );

  static const LinearGradient purple = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFFE6DBFF), Color(0xFFB8A1FF)],
  );

  static const LinearGradient greeting = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFFCFFAFE), Color(0xFFCCFBF1)],
  );
}

/// 通用渐变背景容器（圆角 + 阴影 + 渐变）。
class GradientCard extends StatelessWidget {
  const GradientCard({
    super.key,
    required this.child,
    required this.gradient,
    this.radius = AppRadius.md,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.shadow = AppShadow.sm,
  });
  final Widget child;
  final Gradient gradient;
  final double radius;
  final EdgeInsetsGeometry padding;
  final List<BoxShadow> shadow;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: shadow,
      ),
      child: child,
    );
  }
}

/// 通用圆角白卡（与 ColorScheme 匹配、阴影 sm）。
class SoftCard extends StatelessWidget {
  const SoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.radius = AppRadius.md,
    this.color,
    this.onTap,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final Color bg = color ?? colors.surface;
    final Widget body = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: AppShadow.sm,
      ),
      child: child,
    );
    if (onTap == null) return body;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: body,
      ),
    );
  }
}

/// 渐变短卡片（用于列表中的「快捷入口」图标方块）。
class AccentSquare extends StatelessWidget {
  const AccentSquare({
    super.key,
    required this.icon,
    required this.gradient,
    this.size = 44,
    this.radius = AppRadius.sm,
  });
  final IconData icon;
  final Gradient gradient;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: AppShadow.sm,
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: Colors.white, size: size * 0.5),
    );
  }
}

/// 状态药丸（带可选副色调），统一圆角与字号。
class AppChip extends StatelessWidget {
  const AppChip(this.label, {super.key, this.icon, this.tone, this.dense = false});
  final String label;
  final IconData? icon;
  final Color? tone;
  final bool dense;

  Color _autoTone() {
    if (label.contains('通过') ||
        label.contains('进行中') ||
        label.contains('在训') ||
        label.contains('已办结')) {
      return AppPalette.success;
    }
    if (label.contains('截止') ||
        label.contains('预警') ||
        label.contains('驳回') ||
        label.contains('待补') ||
        label.contains('请假')) {
      return AppPalette.danger;
    }
    if (label.contains('待') || label.contains('暂停') || label.contains('未')) {
      return AppPalette.warning;
    }
    return AppPalette.inkMute;
  }

  @override
  Widget build(BuildContext context) {
    final Color color = tone ?? _autoTone();
    final EdgeInsetsGeometry pad = dense
        ? const EdgeInsets.symmetric(horizontal: 8, vertical: 2)
        : const EdgeInsets.symmetric(horizontal: 10, vertical: 4);
    return Container(
      padding: pad,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: dense ? 10 : 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: dense ? AppFontSize.caption : AppFontSize.small,
              fontWeight: AppFontWeight.semibold,
              color: color,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// 阴影 ColorFilter 工具：构造带阴影的卡片装饰。
BoxDecoration softDecoration(BuildContext context,
    {double radius = AppRadius.md, Color? color}) {
  final ColorScheme colors = Theme.of(context).colorScheme;
  return BoxDecoration(
    color: color ?? colors.surface,
    borderRadius: BorderRadius.circular(radius),
    boxShadow: AppShadow.sm,
  );
}
