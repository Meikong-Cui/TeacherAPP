import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:teacher_app/app/design_tokens.dart';
import 'package:teacher_app/core/theme_mode_notifier.dart';
import 'package:teacher_app/features/auth/data/auth_repository.dart';
import 'package:teacher_app/data/providers.dart';
import 'package:teacher_app/shared/ui.dart';

/// 我的（仅保留个人信息 / 主题 / 关于，办公功能已迁出到「办公」页）。
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TeacherUser user = ref.watch(currentUserProvider);
    final ThemeMode mode = ref.watch(themeModeProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: <Widget>[
            // 个人信息卡（渐变）
            GradientCard(
              gradient: AppGradients.greeting,
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
              radius: AppRadius.lg,
              child: Row(
                children: <Widget>[
                  Container(
                    width: 56,
                    height: 56,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppGradients.teal,
                    ),
                    alignment: Alignment.center,
                    child: Text(user.avatar,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: AppFontSize.headline,
                          fontWeight: FontWeight.bold,
                        )),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(user.name,
                            style: const TextStyle(
                              fontSize: AppFontSize.headline,
                              fontWeight: FontWeight.w800,
                              color: AppPalette.ink,
                            )),
                        const SizedBox(height: 4),
                        Text('${user.role} · ${user.dept}',
                            style: const TextStyle(
                              fontSize: AppFontSize.small,
                              color: AppPalette.inkMute,
                            )),
                        Text(user.center,
                            style: const TextStyle(
                              fontSize: AppFontSize.small,
                              color: AppPalette.inkMute,
                            )),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 主题
            const AppSectionTitle('主题'),
            SoftCard(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 4),
              child: SegmentedButton<ThemeMode>(
                segments: const <ButtonSegment<ThemeMode>>[
                  ButtonSegment<ThemeMode>(
                      value: ThemeMode.light,
                      label: Text('亮色'),
                      icon: Icon(Icons.light_mode_outlined)),
                  ButtonSegment<ThemeMode>(
                      value: ThemeMode.dark,
                      label: Text('深色'),
                      icon: Icon(Icons.dark_mode_outlined)),
                  ButtonSegment<ThemeMode>(
                      value: ThemeMode.system,
                      label: Text('跟随系统'),
                      icon: Icon(Icons.brightness_auto_outlined)),
                ],
                selected: <ThemeMode>{mode},
                onSelectionChanged: (Set<ThemeMode> v) =>
                    ref.read(themeModeProvider.notifier).set(v.first),
              ),
            ),

            const SizedBox(height: 8),

            // 关于
            const AppSectionTitle('关于'),
            SoftCard(
              onTap: () => showAboutDialog(
                context: context,
                applicationName: '语亦丰康复教师端',
                applicationVersion: '1.0.0',
                children: const <Widget>[
                  Text('儿童康复教育系统 · 教师端 App（Flutter）'),
                ],
              ),
              child: Row(children: const <Widget>[
                AccentSquare(
                  icon: Icons.info_outline,
                  gradient: AppGradients.teal,
                  size: 36,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text('关于',
                      style: TextStyle(
                          fontSize: AppFontSize.body,
                          fontWeight: FontWeight.w600)),
                ),
                Icon(Icons.chevron_right, color: AppPalette.inkMute),
              ]),
            ),

            const SizedBox(height: 24),

            // 退出登录
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  await const AuthRepository().logout();
                  ref.read(authChangedProvider.notifier).state++;
                  if (context.mounted) {
                    Navigator.of(context).popUntil((_) => false);
                    context.go('/login');
                  }
                },
                icon: const Icon(Icons.logout, size: 18),
                label: const Text('退出登录'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppPalette.danger,
                  side: const BorderSide(color: AppPalette.danger),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
