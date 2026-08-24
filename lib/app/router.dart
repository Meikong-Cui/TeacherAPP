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
import 'package:teacher_app/features/rehab/presentation/eval_history_screen.dart';
import 'package:teacher_app/features/rehab/presentation/add_child_screen.dart';
import 'package:teacher_app/features/office/office_screen.dart';
import 'package:teacher_app/features/rehab/presentation/autism_items_editor_screen.dart';
import 'package:teacher_app/features/rehab/presentation/offline_archive_screen.dart';
import 'package:teacher_app/features/rehab/presentation/offline_round_report_screen.dart';
import 'package:teacher_app/features/rehab/presentation/offline_overview_report_screen.dart';
import 'package:teacher_app/features/rehab/presentation/vb_archive_screen.dart';
import 'package:teacher_app/features/rehab/presentation/scale_picker_screen.dart';
import 'package:teacher_app/features/rehab/presentation/autism_charts_screen.dart';
import 'package:teacher_app/features/rehab/presentation/autism_effect_screen.dart';
import 'package:teacher_app/features/rehab/presentation/autism_monthly_plan_ai_screen.dart';
import 'package:teacher_app/features/seal/presentation/seal_apply_screen.dart';
import 'package:teacher_app/features/seal/presentation/seal_list_screen.dart';
import 'package:teacher_app/features/supplement/supplement_apply_screen.dart';
import 'package:teacher_app/features/supplement/supplement_list_screen.dart';
import 'package:teacher_app/features/games/games_hub_screen.dart';
import 'package:teacher_app/features/games/find_animals_game.dart';
import 'package:teacher_app/features/games/volume_jump_game.dart';
import 'package:teacher_app/features/games/jigsaw_puzzle_game.dart';
import 'package:teacher_app/features/games/sequence_sort_game.dart';
import 'package:teacher_app/features/games/expression_wheel_game.dart';
import 'package:teacher_app/features/games/schulte_grid_game.dart';
import 'package:teacher_app/features/games/match_pairs_game.dart';
import 'package:teacher_app/features/games/sequence_memory_game.dart';
import 'package:teacher_app/features/rehab/presentation/hearing_section_screen.dart';
import 'package:teacher_app/features/rehab/presentation/plan_tasks_screens.dart';
import 'package:teacher_app/features/rehab/presentation/iep_screen.dart';
import 'package:teacher_app/features/rehab/presentation/add_iep_goal_screen.dart';
import 'package:teacher_app/features/office/leave_list_screen.dart';
import 'package:teacher_app/features/office/leave_apply_screen.dart';
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
      path: '/rehab/:id/offline-answer',
      builder: (BuildContext context, GoRouterState state) => OfflineAnswerScreen(
        archiveId: state.pathParameters['id'] ?? '',
        paper: state.uri.queryParameters['paper'] ?? 'A',
        roundId: state.uri.queryParameters['roundId'],
      ),
    ),
    GoRoute(
      // 评估历史里点某轮 round 进入答题页：roundId 在路径段，paper 在 query（默认 A）。
      path: '/rehab/:id/offline-answer/:roundId',
      builder: (BuildContext context, GoRouterState state) => OfflineAnswerScreen(
        archiveId: state.pathParameters['id'] ?? '',
        roundId: state.pathParameters['roundId'] ?? '',
        paper: state.uri.queryParameters['paper'] ?? 'A',
      ),
    ),
    GoRoute(
      path: '/rehab/:id/offline-result',
      builder: (BuildContext context, GoRouterState state) => OfflineResultScreen(
        archiveId: state.pathParameters['id'] ?? '',
      ),
    ),
    GoRoute(
      path: '/rehab/:id/offline-eval-report',
      builder: (BuildContext context, GoRouterState state) => OfflineEvalReportScreen(
        archiveId: state.pathParameters['id'] ?? '',
        type: state.uri.queryParameters['type'] ?? 'TEACHER',
        title: state.uri.queryParameters['title'] ?? '评估报告',
      ),
    ),
    GoRoute(
      path: '/rehab/:id/offline-overview',
      builder: (BuildContext context, GoRouterState state) => OfflineOverviewReportScreen(
        archiveId: state.pathParameters['id'] ?? '',
        roundId: state.uri.queryParameters['roundId'],
      ),
    ),
    GoRoute(
      path: '/rehab-autism/:id/vb-trend',
      builder: (BuildContext context, GoRouterState state) => VbTrendScreen(
        archiveId: state.pathParameters['id'] ?? '',
        formCode: state.uri.queryParameters['form'] ?? 'VB_PARENT',
      ),
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
          AutismScaleEvalScreen(
        archiveId: state.pathParameters['id'] ?? '',
        formCode: state.uri.queryParameters['form'] ?? '',
      ),
    ),
    // OFFLINE / VB 专属首页：从「选择评测量表」页进入，替代原听障详情里的历史分支。
    GoRoute(
      path: '/rehab-autism/:id/offline-home',
      builder: (BuildContext context, GoRouterState state) =>
          OfflineArchiveHome(archiveId: state.pathParameters['id'] ?? ''),
    ),
    // 线下模板：单个评估轮次报告（不可变快照，教师版/家长版可切换 + 导出 PDF）
    GoRoute(
      path: '/rehab/:id/offline-round/:roundId',
      builder: (BuildContext context, GoRouterState state) =>
          OfflineRoundReportScreen(
        archiveId: state.pathParameters['id'] ?? '',
        roundId: state.pathParameters['roundId'] ?? '',
        role: state.uri.queryParameters['role'] ?? 'TEACHER',
      ),
    ),
    GoRoute(
      path: '/rehab-autism/:id/vb-home',
      builder: (BuildContext context, GoRouterState state) =>
          VbArchiveHome(archiveId: state.pathParameters['id'] ?? ''),
    ),
    GoRoute(
      path: '/rehab-autism/:id/scale-picker',
      builder: (BuildContext context, GoRouterState state) =>
          ScalePickerScreen(
        archiveId: state.pathParameters['id'] ?? '',
      ),
    ),
    GoRoute(
      // 评估历史独立页（孤独症档案专用，从功能入口「评估历史」卡片进入）。
      path: '/rehab-autism/:id/eval-history',
      builder: (BuildContext context, GoRouterState state) =>
          EvalHistoryScreen(archiveId: state.pathParameters['id'] ?? ''),
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
    // 听障档案 - 听能管理独立页（替代原「总览页」Tab）
    GoRoute(
      path: '/rehab/:id/hearing',
      builder: (BuildContext context, GoRouterState state) =>
          HearingSectionScreen(archiveId: state.pathParameters['id'] ?? ''),
    ),
    // 听障档案 - 教学计划独立页
    GoRoute(
      path: '/rehab/:id/plan',
      builder: (BuildContext context, GoRouterState state) =>
          PlanSectionScreen(archiveId: state.pathParameters['id'] ?? ''),
    ),
    // 听障档案 - 评估待办独立页
    GoRoute(
      path: '/rehab/:id/tasks',
      builder: (BuildContext context, GoRouterState state) =>
          TasksSectionScreen(archiveId: state.pathParameters['id'] ?? ''),
    ),
    // ── OA 请假（教师端 ↔ OA 网页共通）──
    GoRoute(
      path: '/office/leave',
      builder: (BuildContext context, GoRouterState state) =>
          const LeaveListScreen(),
    ),
    GoRoute(
      path: '/office/leave/new',
      builder: (BuildContext context, GoRouterState state) =>
          const LeaveApplyScreen(),
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
    // ── OA 补卡（教师端 ↔ OA 网页共通）──
    GoRoute(
      path: '/supplement',
      builder: (BuildContext context, GoRouterState state) =>
          const SupplementListScreen(),
    ),
    GoRoute(
      path: '/supplement/new',
      builder: (BuildContext context, GoRouterState state) =>
          const SupplementApplyScreen(),
    ),
    GoRoute(
      path: '/games',
      builder: (BuildContext context, GoRouterState state) =>
          const GamesHubScreen(),
    ),
    GoRoute(
      path: '/games/find',
      builder: (BuildContext context, GoRouterState state) =>
          const FindAnimalsGame(),
    ),
    GoRoute(
      path: '/games/jump',
      builder: (BuildContext context, GoRouterState state) =>
          const VolumeJumpGame(),
    ),
    GoRoute(
      path: '/games/puzzle',
      builder: (BuildContext context, GoRouterState state) =>
          const JigsawPuzzleGame(),
    ),
    GoRoute(
      path: '/games/sequence',
      builder: (BuildContext context, GoRouterState state) =>
          const SequenceSortGame(),
    ),
    GoRoute(
      path: '/games/wheel',
      builder: (BuildContext context, GoRouterState state) =>
          const ExpressionWheelGame(),
    ),
    GoRoute(
      path: '/games/schulte',
      builder: (BuildContext context, GoRouterState state) =>
          const SchulteGridGame(),
    ),
    GoRoute(
      path: '/games/pairs',
      builder: (BuildContext context, GoRouterState state) =>
          const MatchPairsGame(),
    ),
    GoRoute(
      path: '/games/seqmem',
      builder: (BuildContext context, GoRouterState state) =>
          const SequenceMemoryGame(),
    ),
  ],
);
