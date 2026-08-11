import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:teacher_app/core/theme_mode_notifier.dart';
import 'package:teacher_app/features/auth/data/auth_repository.dart';
import 'package:teacher_app/data/providers.dart';
import 'package:teacher_app/shared/ui.dart';

/// 我的。
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TeacherUser user = ref.watch(currentUserProvider);
    final ThemeMode mode = ref.watch(themeModeProvider);
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的'),
        actions: const <Widget>[ThemeToggleButton()],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: <Widget>[
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: colors.primaryContainer,
                    foregroundColor: colors.onPrimaryContainer,
                    child: Text(user.avatar,
                        style: textTheme.titleLarge),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(user.name,
                            style: textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text('${user.role} · ${user.dept}'),
                        Text(user.center,
                            style: textTheme.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const AppSectionTitle('主题'),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
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
          ),
          const AppSectionTitle('功能'),
          _EntryTile(
            icon: Icons.location_on_outlined,
            title: '上下班签到',
            subtitle: '指定地点 1000 米内可打卡',
            onTap: () => context.push('/clock-in'),
          ),
          _EntryTile(
            icon: Icons.receipt_long_outlined,
            title: '财务报销',
            subtitle: '申请并提交至 OA 后台等待审批',
            onTap: () => context.push('/reimbursement/list'),
          ),
          _EntryTile(
            icon: Icons.folder_open_outlined,
            title: '康复档案',
            subtitle: '填写评估与教学计划、上传手写照片',
            onTap: () => context.push('/rehab'),
          ),
          _EntryTile(
            icon: Icons.gpp_good_outlined,
            title: '用章申请',
            subtitle: '提交用章申请并查看审批进度',
            onTap: () => context.push('/seal/apply'),
          ),
          const SizedBox(height: 8),
          _EntryTile(
            icon: Icons.info_outline,
            title: '关于',
            onTap: () => showAboutDialog(
              context: context,
              applicationName: '语亦丰康复教师端',
              applicationVersion: '1.0.0',
              children: const <Widget>[
                Text('儿童康复教育系统 · 教师端 App（Flutter）'),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () async {
                await const AuthRepository().logout();
                if (context.mounted) context.go('/login');
              },
              child: const Text('退出登录'),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title),
        subtitle: subtitle != null ? Text(subtitle!) : null,
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
