import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teacher_app/app/router.dart';
import 'package:teacher_app/app/theme.dart';
import 'package:teacher_app/core/auth_store.dart';
import 'package:teacher_app/core/notification_service.dart';
import 'package:teacher_app/core/theme_mode_notifier.dart';
import 'package:teacher_app/features/auth/data/auth_repository.dart';
import 'package:teacher_app/features/notice/data/notice_repository.dart';
import 'package:teacher_app/data/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AuthStore.instance.load();
  await NotificationService.init();
  NotificationService.setNoticeRepository(NoticeRepository());
  runApp(const ProviderScope(child: TeacherApp()));
}

class TeacherApp extends ConsumerWidget {
  const TeacherApp({super.key});

  /// 仅启动时拉取一次真实用户信息（/api/me），覆盖本地 demo 默认（林嘉怡），
  /// 避免「已登录状态下重启 App」后 currentUserProvider 回落到硬编码默认值。
  static bool _meRefreshed = false;
  void _refreshCurrentUserOnce(WidgetRef ref) {
    if (_meRefreshed) return;
    _meRefreshed = true;
    if (!AuthStore.instance.isLoggedIn) return;
    () async {
      try {
        final TeacherUser me = await const AuthRepository().fetchMe();
        ref.read(currentUserProvider.notifier).state =
            ref.read(currentUserProvider).copyWith(
                  name: me.name,
                  role: me.role,
                  center: me.center,
                  avatar: me.avatar,
                );
      } catch (_) {
        // 拉取失败保持 demo 默认，不影响使用。
      }
    }();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeMode themeMode = ref.watch(themeModeProvider);
    _refreshCurrentUserOnce(ref);
    return MaterialApp.router(
      title: '康复教师端',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: appRouter,
    );
  }
}
