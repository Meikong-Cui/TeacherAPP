import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teacher_app/app/router.dart';
import 'package:teacher_app/app/theme.dart';
import 'package:teacher_app/core/auth_store.dart';
import 'package:teacher_app/core/notification_service.dart';
import 'package:teacher_app/core/theme_mode_notifier.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AuthStore.instance.load();
  await NotificationService.init();
  runApp(const ProviderScope(child: TeacherApp()));
}

class TeacherApp extends ConsumerWidget {
  const TeacherApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeMode themeMode = ref.watch(themeModeProvider);
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
