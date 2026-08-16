import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:teacher_app/features/auth/login_screen.dart';
import 'package:teacher_app/features/ai_lesson_plan/data/ai_lesson_plan_repository.dart';
import 'package:teacher_app/features/ai_lesson_plan/presentation/ai_lesson_plan_screen.dart';
import 'package:teacher_app/features/children/children_list_screen.dart';
import 'package:teacher_app/features/clock_in/presentation/clock_in_screen.dart';
import 'package:teacher_app/features/home/home_screen.dart';
import 'package:teacher_app/features/profile/profile_screen.dart';
import 'package:teacher_app/features/reimbursement/presentation/reimbursement_list_screen.dart';
import 'package:teacher_app/features/reimbursement/presentation/reimbursement_new_screen.dart';
import 'package:teacher_app/features/reimbursement/presentation/reimbursement_detail_screen.dart';
import 'package:teacher_app/features/rehab/presentation/rehab_archive_list_screen.dart';
import 'package:teacher_app/features/rehab/presentation/rehab_archive_detail_screen.dart';
import 'package:teacher_app/features/rehab/presentation/autism_archive_detail_screen.dart';
import 'package:teacher_app/features/rehab/presentation/autism_edit_screen.dart';
import 'package:teacher_app/features/rehab/presentation/child_hub_screen.dart';
import 'package:teacher_app/features/rehab/presentation/add_child_screen.dart';
import 'package:teacher_app/features/office/office_screen.dart';
import 'package:teacher_app/features/rehab/presentation/autism_items_editor_screen.dart';
import 'package:teacher_app/features/rehab/presentation/autism_charts_screen.dart';
import 'package:teacher_app/features/rehab/presentation/autism_effect_screen.dart';
import 'package:teacher_app/features/rehab/presentation/autism_monthly_plan_ai_screen.dart';
import 'package:teacher_app/features/seal/presentation/seal_apply_screen.dart';
import 'package:teacher_app/features/seal/presentation/seal_list_screen.dart';
import 'package:teacher_app/features/rehab/presentation/iep_screen.dart';
import 'package:teacher_app/features/rehab/presentation/add_iep_goal_screen.dart';
import 'package:teacher_app/core/auth_store.dart';
import 'package:teacher_app/core/app_navigator.dart';
import 'package:teacher_app/shared/app_shell.dart';

/// 应用路由表。
/// 底部 Tab（首页/儿童/消息/我的）走 StatefulShellRoute；
/// 详情、签到、AI 教案为独立全屏页。
final GoRouter appRouter = GoRouter(
  navigatorKey: appNavigatorKey,
  initialLocation: '/login',
  redirect: (BuildContext context, GoRouterState state) {
    final bool loggedIn = AuthStore.instance.isLoggedIn;
    final bool goingToLogin = state.matchedLocation == '/login';
    if (!loggedIn && !goingToLogin) return '/login';
    if (loggedIn && goingToLogin) return '/';
    return null;
  },
  routes: <RouteBase>[
    GoRoute(
      path: '/login',
      builder: (BuildContext context, GoRouterState state) =>
          const LoginScreen(),
    ),
    StatefulShellRoute.indexedStack(
      builder: (
        BuildContext context,
        GoRouterState state,
        StatefulNavigationShell navigationShell,
      ) =>
          AppShell(navigationShell: navigationShell),
      branches: <StatefulShellBranch>[
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: '/',
              builder: (BuildContext context, GoRouterState state) =>
                  const HomeScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: '/children',
              builder: (BuildContext context, GoRouterState state) =>
                  const ChildrenListScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: '/office',
              builder: (BuildContext context, GoRouterState state) =>
                  const OfficeScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: '/profile',
              builder: (BuildContext context, GoRouterState state) =>
                  const ProfileScreen(),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/children/:id',
      builder: (BuildContext context, GoRouterState state) =>
          ChildHubScreen(archiveId: state.pathParameters['id'] ?? ''),
    ),
    GoRoute(
      path: '/add-child',
      builder: (BuildContext context, GoRouterState state) =>
          const AddChildScreen(),
    ),
    GoRoute(
      path: '/clock-in',
      builder: (BuildContext context, GoRouterState state) =>
          const ClockInScreen(),
    ),
    GoRoute(
      path: '/ai-lesson-plan',
      builder: (BuildContext context, GoRouterState state) =>
          AiLessonPlanScreen(
        launchContext: state.extra is AiLessonPlanLaunchContext
            ? state.extra as AiLessonPlanLaunchContext
            : null,
      ),
    ),
    GoRoute(
      path: '/reimbursement/list',
      builder: (BuildContext context, GoRouterState state) =>
          const ReimbursementListScreen(),
    ),
    GoRoute(
      path: '/reimbursement/new',
      builder: (BuildContext context, GoRouterState state) =>
          const ReimbursementNewScreen(),
    ),
    GoRoute(
      path: '/reimbursement/:id',
      builder: (BuildContext context, GoRouterState state) =>
          ReimbursementDetailScreen(id: state.pathParameters['id'] ?? ''),
    ),
    GoRoute(
      path: '/rehab',
      builder: (BuildContext context, GoRouterState state) =>
          const RehabArchiveListScreen(),
    ),
    GoRoute(
      path: '/rehab/:id',
      builder: (BuildContext context, GoRouterState state) =>
          RehabArchiveDetailScreen(archiveId: state.pathParameters['id'] ?? ''),
    ),
    GoRoute(
      path: '/rehab-autism/:id',
      builder: (BuildContext context, GoRouterState state) =>
          AutismArchiveDetailScreen(archiveId: state.pathParameters['id'] ?? ''),
    ),
    GoRoute(
      path: '/rehab-autism/:id/edit/:doc',
      builder: (BuildContext context, GoRouterState state) =>
          AutismEditScreen(
        archiveId: state.pathParameters['id'] ?? '',
        doc: state.pathParameters['doc'] ?? '',
        docId: state.uri.queryParameters['docId'],
      ),
    ),
    GoRoute(
      path: '/rehab-autism/:id/items',
      builder: (BuildContext context, GoRouterState state) =>
          AutismItemsEditorScreen(
        archiveId: state.pathParameters['id'] ?? '',
        sourceId: int.tryParse(state.uri.queryParameters['sourceId'] ?? '0') ?? 0,
      ),
    ),
    GoRoute(
      path: '/rehab-autism/:id/charts',
      builder: (BuildContext context, GoRouterState state) =>
          AutismChartsScreen(archiveId: state.pathParameters['id'] ?? ''),
    ),
    GoRoute(
      path: '/rehab-autism/:id/effect',
      builder: (BuildContext context, GoRouterState state) =>
          AutismEffectScreen(archiveId: state.pathParameters['id'] ?? ''),
    ),
    GoRoute(
      path: '/rehab-autism/:id/monthly-plan-ai',
      builder: (BuildContext context, GoRouterState state) =>
          AutismMonthlyPlanAiScreen(
        archiveId: state.pathParameters['id'] ?? '',
      ),
    ),
    GoRoute(
      // IEP 干预计划（与月计划分开、独立创建）。
      path: '/rehab-autism/:id/iep',
      builder: (BuildContext context, GoRouterState state) =>
          IepScreen(archiveId: state.pathParameters['id'] ?? ''),
    ),
    GoRoute(
      // 添加 IEP 项目（独立页，从后端模板库按年龄/领域勾选）。
      path: '/rehab-autism/:id/iep/add',
      builder: (BuildContext context, GoRouterState state) =>
          AddIepGoalScreen(archiveId: state.pathParameters['id'] ?? ''),
    ),
    GoRoute(
      path: '/rehab/:id/first-eval-edit',
      builder: (BuildContext context, GoRouterState state) =>
          FirstEvalEditScreen(archiveId: state.pathParameters['id'] ?? ''),
    ),
    GoRoute(
      path: '/rehab/:id/cont-eval-edit',
      builder: (BuildContext context, GoRouterState state) => ContEvalEditScreen(
        archiveId: state.pathParameters['id'] ?? '',
        // 带 evalId 时进入编辑已有记录模式，缺省为新建。
        evalId: state.uri.queryParameters['evalId'],
      ),
    ),
    GoRoute(
      path: '/seal/apply',
      builder: (BuildContext context, GoRouterState state) =>
          const SealApplyScreen(),
    ),
    GoRoute(
      path: '/seal',
      builder: (BuildContext context, GoRouterState state) =>
          const SealListScreen(),
    ),
  ],
);
