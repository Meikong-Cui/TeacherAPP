import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:teacher_app/app/design_tokens.dart';
import 'package:teacher_app/core/notification_service.dart';
import 'package:teacher_app/data/models/rehab.dart';
import 'package:teacher_app/data/providers.dart';
import 'package:teacher_app/features/rehab/provider/rehab_provider.dart';
import 'package:teacher_app/shared/ui.dart';

/// 主页：工作台仪表盘。儿童列表固定 3 张 + 查看全部，
/// 4 张快捷入口卡（听障录入 / 孤独症录入 / 教学游戏 / 课表），
/// 移除了「新增孩子」入口（迁至「儿童」页面 FAB）。
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Timer? _noticeTimer;

  @override
  void initState() {
    super.initState();
    // 启动后立即拉取一次通知/预警，并周期性轮询
    NotificationService.pollNotices();
    _noticeTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      NotificationService.pollNotices();
    });
  }

  @override
  void dispose() {
    _noticeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final TeacherUser user = ref.watch(currentUserProvider);
    final AsyncValue<List<RehabArchive>> archivesAsync =
        ref.watch(rehabArchivesProvider);
    final AsyncValue<List<RehabTask>> tasksAsync =
        ref.watch(pendingTasksProvider);

    final List<RehabTask> allTasks = tasksAsync.valueOrNull ?? <RehabTask>[];
    final List<RehabTask> plans = allTasks
        .where((t) => t.reminderType == 'TEACHING_PLAN')
        .toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    final List<RehabTask> todos = allTasks
        .where((t) => t.reminderType != 'TEACHING_PLAN')
        .toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(rehabArchivesProvider);
            ref.invalidate(pendingTasksProvider);
          },
          child: CustomScrollView(
            slivers: <Widget>[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                sliver: SliverToBoxAdapter(child: _GreetingHeader(user: user)),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: archivesAsync.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (Object e, _) => SoftCard(
                      child: Text(
                          '档案加载失败：$e\n（后端可能未启动，可下拉重试）'),
                    ),
                    data: (archives) {
                      if (archives.isEmpty) {
                        return const _EmptyChildHint();
                      }
                      // 主页固定只展示前 3 张，多了引导到「儿童」Tab。
                      final List<RehabArchive> top =
                          archives.take(3).toList();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          AppSectionTitle('我的儿童',
                              action: TextButton(
                                onPressed: () =>
                                    _switchTab(context, 1),
                                child: const Text('查看全部'),
                              )),
                          ...top.map(
                              (RehabArchive a) => _HomeChildCard(archive: a)),
                        ],
                      );
                    },
                  ),
                ),
              ),
              // 待办
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      AppSectionTitle('待办（${todos.length + plans.length}）'),
                      if (todos.isEmpty && plans.isEmpty)
                        SoftCard(
                          child: Row(children: <Widget>[
                            const Icon(Icons.celebration_outlined,
                                color: AppPalette.brand),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text('暂无待办，辛苦了',
                                  style: TextStyle(
                                      color: AppPalette.inkMute,
                                      fontSize: AppFontSize.body)),
                            ),
                          ]),
                        )
                      else
                        Column(
                          children: <Widget>[
                            ...todos.take(3).map((RehabTask t) =>
                                _TodoTile(task: t, onDone: () async {
                                  await ref
                                      .read(rehabRepositoryProvider)
                                      .completeTask(t.id);
                                  ref.invalidate(pendingTasksProvider);
                                  ref.invalidate(rehabArchivesProvider);
                                })),
                            ...plans.take(1).map((RehabTask t) =>
                                _PlanTile(task: t)),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              // 快捷入口
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      AppSectionTitle('快捷入口'),
                      const _ShortcutGrid(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 切换到指定的 Tab 索引。借助 GlobalKey 找到 StatefulShellRoute 的壳。
  void _switchTab(BuildContext context, int index) {
    // 用通用套路：从壳出发切换 Tab。
    // goRouter 已经把 rootNavigatorKey 与 shellNavigatorKey 分离。
    final GoRouter router = GoRouter.of(context);
    router.go(_shellBranchPath(index));
  }

  String _shellBranchPath(int index) {
    const List<String> branches = <String>['/', '/children', '/office', '/profile'];
    if (index < 0 || index >= branches.length) return '/';
    return branches[index];
  }
}

// ───────────── 头部问候（渐变） ─────────────

class _GreetingHeader extends StatelessWidget {
  const _GreetingHeader({required this.user});
  final TeacherUser user;

  @override
  Widget build(BuildContext context) {
    final String hourGreeting = _greetingOfHour(DateTime.now().hour);
    return GradientCard(
      gradient: AppGradients.greeting,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      radius: AppRadius.lg,
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('$hourGreeting，${user.name}',
                    style: const TextStyle(
                      fontSize: AppFontSize.headline,
                      fontWeight: AppFontWeight.extrabold,
                      color: AppPalette.ink,
                      letterSpacing: 0.4,
                    )),
                const SizedBox(height: 6),
                Text('${user.role} · ${user.center}',
                    style: const TextStyle(
                      fontSize: AppFontSize.small,
                      color: AppPalette.inkMute,
                    )),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppGradients.teal,
            ),
            alignment: Alignment.center,
            child: Text(user.avatar,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: AppFontSize.subtitle,
                    fontWeight: AppFontWeight.bold)),
          ),
        ],
      ),
    );
  }

  static String _greetingOfHour(int hour) {
    if (hour < 6) return '夜深了';
    if (hour < 9) return '早上好';
    if (hour < 12) return '上午好';
    if (hour < 14) return '中午好';
    if (hour < 18) return '下午好';
    return '晚上好';
  }
}

// ───────────── 列表卡片 ─────────────

class _HomeChildCard extends StatelessWidget {
  const _HomeChildCard({required this.archive});
  final RehabArchive archive;

  @override
  Widget build(BuildContext context) {
    final bool isAutism = archive.isAutism;
    final Color tone = isAutism ? AppPalette.purple : AppPalette.success;
    final Gradient gradient =
        isAutism ? AppGradients.purple : AppGradients.tealLight;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: SoftCard(
        onTap: () => context.push('/children/${archive.id}'),
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: <Widget>[
            CircleAvatar(
              radius: 22,
              backgroundColor: tone.withOpacity(0.16),
              child: Text(
                archive.childName.isNotEmpty ? archive.childName[0] : '?',
                style: TextStyle(
                  color: tone,
                  fontWeight: AppFontWeight.bold,
                  fontSize: AppFontSize.title,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    archive.childName,
                    style: const TextStyle(
                      fontSize: AppFontSize.title,
                      fontWeight: AppFontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${archive.archiveNo} · ${archive.campusName}',
                    style: const TextStyle(
                      fontSize: AppFontSize.small,
                      color: AppPalette.inkMute,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    gradient: gradient,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(archive.typeLabel,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: AppFontSize.caption,
                          fontWeight: AppFontWeight.bold)),
                ),
                const SizedBox(height: 6),
                if (archive.status.label.isNotEmpty)
                  AppChip(archive.status.label, dense: true, tone: tone),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyChildHint extends StatelessWidget {
  const _EmptyChildHint();

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      child: Row(children: <Widget>[
        const AccentSquare(
            icon: Icons.diversity_1_outlined,
            gradient: AppGradients.tealLight),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const <Widget>[
              Text('还没有孩子档案',
                  style: TextStyle(
                      fontSize: AppFontSize.title,
                      fontWeight: AppFontWeight.bold)),
              SizedBox(height: 4),
              Text('前往「儿童」页面 → 点击右下角 + 按钮开始录入',
                  style: TextStyle(
                      fontSize: AppFontSize.small,
                      color: AppPalette.inkMute)),
            ],
          ),
        ),
      ]),
    );
  }
}

class _TodoTile extends StatelessWidget {
  const _TodoTile({required this.task, required this.onDone});
  final RehabTask task;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final DateFormat fmt = DateFormat('MM-dd');
    final bool overdue = task.dueDate.isBefore(DateTime.now());
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: SoftCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: <Widget>[
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: overdue
                  ? AppPalette.danger.withOpacity(0.16)
                  : AppPalette.warning.withOpacity(0.16),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            alignment: Alignment.center,
            child: Icon(Icons.assessment_outlined,
                color: overdue ? AppPalette.danger : AppPalette.warning,
                size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(task.title,
                    style: const TextStyle(
                        fontSize: AppFontSize.body,
                        fontWeight: AppFontWeight.semibold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text('${task.typeLabel} · 截止 ${fmt.format(task.dueDate)}',
                    style: TextStyle(
                      fontSize: AppFontSize.small,
                      color: overdue
                          ? AppPalette.danger
                          : AppPalette.inkMute,
                    )),
              ],
            ),
          ),
          TextButton(
            onPressed: onDone,
            style: TextButton.styleFrom(foregroundColor: AppPalette.brand),
            child: const Text('完成'),
          ),
        ]),
      ),
    );
  }
}

class _PlanTile extends StatelessWidget {
  const _PlanTile({required this.task});
  final RehabTask task;

  @override
  Widget build(BuildContext context) {
    final DateFormat fmt = DateFormat('MM-dd');
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: SoftCard(
        onTap: () => context.push('/children/${task.archiveId}'),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: <Widget>[
          const AccentSquare(
              icon: Icons.event_available_outlined,
              gradient: AppGradients.teal,
              size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(task.title,
                    style: const TextStyle(
                        fontSize: AppFontSize.body,
                        fontWeight: AppFontWeight.semibold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text('教学计划 · ${fmt.format(task.dueDate)}',
                    style: const TextStyle(
                        fontSize: AppFontSize.small,
                        color: AppPalette.inkMute)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppPalette.inkMute),
        ]),
      ),
    );
  }
}

// ───────────── 快捷入口 ─────────────

class _ShortcutGrid extends StatelessWidget {
  const _ShortcutGrid();

  @override
  Widget build(BuildContext context) {
    final List<_Shortcut> entries = <_Shortcut>[
      const _Shortcut(
        icon: Icons.hearing_outlined,
        title: '听障儿童录入',
        subtitle: '首次评估 / 听能记录',
        gradient: AppGradients.rose,
        route: '/add-child?type=HEARING',
      ),
      const _Shortcut(
        icon: Icons.psychology_outlined,
        title: '孤独症儿童录入',
        subtitle: '评测 / IEP / 月计划',
        gradient: AppGradients.purple,
        route: '/add-child?type=AUTISM',
      ),
      const _Shortcut(
        icon: Icons.sports_esports_outlined,
        title: '教学游戏',
        subtitle: '听觉 · 发音 · 认知',
        gradient: AppGradients.sky,
        route: '/games',
      ),
      const _Shortcut(
        icon: Icons.calendar_today_outlined,
        title: '课表',
        subtitle: '今日课程安排',
        gradient: AppGradients.amber,
        route: '/timetable',
      ),
    ];
    return GridView.builder(
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.7,
      ),
      itemCount: entries.length,
      itemBuilder: (BuildContext ctx, int i) {
        final _Shortcut e = entries[i];
        return _ShortcutCard(entry: e);
      },
    );
  }
}

class _Shortcut {
  const _Shortcut({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.route,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final Gradient gradient;
  final String route;
}

class _ShortcutCard extends StatelessWidget {
  const _ShortcutCard({required this.entry});
  final _Shortcut entry;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      onTap: () {
        // 课表入口暂未实现：route /timetable 未注册；为了不阻塞 UI 使用体验
        // 这里给个 SnackBar 反馈，其余三种入口是已存在的路由。
        if (entry.route == '/timetable') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('课表功能即将上线，敬请期待')),
          );
          return;
        }
        context.push(entry.route);
      },
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          AccentSquare(icon: entry.icon, gradient: entry.gradient),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(entry.title,
                  style: const TextStyle(
                    fontSize: AppFontSize.body,
                    fontWeight: AppFontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(entry.subtitle,
                  style: const TextStyle(
                    fontSize: AppFontSize.small,
                    color: AppPalette.inkMute,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ],
      ),
    );
  }
}

// ───────────── 私有工具：分级时间格式化 ─────────────
