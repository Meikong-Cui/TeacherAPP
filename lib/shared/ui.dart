import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teacher_app/core/theme_mode_notifier.dart';

/// 区块标题。
class AppSectionTitle extends StatelessWidget {
  const AppSectionTitle(this.text, {super.key, this.action});

  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
      child: Row(
        children: <Widget>[
          Text(
            text,
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          if (action != null) action!,
        ],
      ),
    );
  }
}

/// 状态/标签彩色药丸。
class StatusChip extends StatelessWidget {
  const StatusChip(this.label, {super.key, this.tone});

  final String label;
  final Color? tone;

  static Color _autoTone(String label) {
    if (label.contains('通过') || label.contains('进行中') || label.contains('在训')) {
      return const Color(0xFF0EA5A4);
    }
    if (label.contains('截止') || label.contains('预警') || label.contains('驳回')) {
      return const Color(0xFFE2683B);
    }
    if (label.contains('待') || label.contains('暂停') || label.contains('未')) {
      return const Color(0xFF9A6A00);
    }
    return const Color(0xFF5B6F6C);
  }

  @override
  Widget build(BuildContext context) {
    final Color color = tone ?? _autoTone(label);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

/// 信息行。
class InfoRow extends StatelessWidget {
  const InfoRow({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 84,
            child: Text(
              label,
              style: textTheme.bodyMedium
                  ?.copyWith(color: textTheme.bodySmall?.color),
            ),
          ),
          Expanded(
            child: Text(value, style: textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

/// 圆形进度环。
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.value,
    required this.size,
    this.strokeWidth = 8,
    this.center,
  });

  final double value; // 0..1
  final double size;
  final double strokeWidth;
  final Widget? center;

  @override
  Widget build(BuildContext context) {
    final Color primary = Theme.of(context).colorScheme.primary;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: value.clamp(0, 1),
              strokeWidth: strokeWidth,
              backgroundColor:
                  Theme.of(context).colorScheme.surfaceContainerHighest,
              color: primary,
            ),
          ),
          if (center != null) center!,
        ],
      ),
    );
  }
}

/// 图标色映射（演示原型约定）。
Color iconColor(String key) {
  switch (key) {
    case 'green':
      return const Color(0xFF0EA5A4);
    case 'blue':
      return const Color(0xFF2F7FF0);
    case 'orange':
      return const Color(0xFFE08A1E);
    case 'rose':
      return const Color(0xFFE2683B);
    case 'amber':
      return const Color(0xFFC99A00);
    case 'purple':
      return const Color(0xFF7C5CF0);
    default:
      return const Color(0xFF5B6F6C);
  }
}

/// 主题切换按钮（亮/暗/跟随系统 循环）。
class ThemeToggleButton extends ConsumerWidget {
  const ThemeToggleButton({super.key});

  IconData _icon(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return Icons.light_mode_outlined;
      case ThemeMode.dark:
        return Icons.dark_mode_outlined;
      case ThemeMode.system:
        return Icons.brightness_auto_outlined;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeMode mode = ref.watch(themeModeProvider);
    return IconButton(
      icon: Icon(_icon(mode)),
      tooltip: '主题：${mode.name}',
      onPressed: () => ref.read(themeModeProvider.notifier).cycle(),
    );
  }
}
