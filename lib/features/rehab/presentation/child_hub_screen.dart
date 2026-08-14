import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:teacher_app/data/models/autism_archive.dart';
import 'package:teacher_app/data/models/rehab.dart';
import 'package:teacher_app/features/rehab/provider/autism_provider.dart';
import 'package:teacher_app/features/rehab/provider/rehab_provider.dart';
import 'package:teacher_app/shared/ui.dart';

/// 儿童中枢页：所有儿童功能的统一入口。
/// 按 templateType 分支展示听障 / 孤独症各自的功能入口与计划。
class ChildHubScreen extends ConsumerWidget {
  const ChildHubScreen({required this.archiveId, super.key});
  final String archiveId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme colors = Theme.of(context).colorScheme;

    final RehabArchiveDetailState rehabState =
        ref.watch(rehabArchiveDetailProvider(archiveId));
    final bool isAutism = rehabState.detail?.archive.isAutism ?? false;
    final AutismArchiveDetailState? autismState =
        isAutism ? ref.watch(autismArchiveDetailProvider(archiveId)) : null;

    // 触发加载
    if (rehabState.detail == null && !rehabState.loading) {
      Future.microtask(() =>
          ref.read(rehabArchiveDetailProvider(archiveId).notifier).load(archiveId));
    }
    if (isAutism &&
        (autismState == null || (autismState.detail == null && !autismState.loading))) {
      Future.microtask(() =>
          ref.read(autismArchiveDetailProvider(archiveId).notifier).load(archiveId));
    }

    if (rehabState.loading && rehabState.detail == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('加载中…')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (rehabState.detail == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('未找到')),
        body: Center(child: Text(rehabState.error ?? '未找到该档案')),
      );
    }

    final RehabArchive archive = rehabState.detail!.archive;
    final Color accent = isAutism ? iconColor('rose') : iconColor('green');
    final List<RehabTask> tasks = rehabState.detail!.tasks
        .where((t) => !t.completed)
        .toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    final List<_PlanItem> plans = _buildPlanItems(isAutism, rehabState.detail!,
        isAutism ? autismState?.detail : null);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: '返回',
          // 兜底返回：能 pop 就 pop，否则回到主页。
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              context.go('/');
            }
          },
        ),
        title: Text(archive.childName.isEmpty ? '儿童档案' : archive.childName),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
            onPressed: () {
              ref.read(rehabArchiveDetailProvider(archiveId).notifier).reload();
              if (isAutism) {
                ref.read(autismArchiveDetailProvider(archiveId).notifier).reload();
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          // 头部信息卡片
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: <Widget>[
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: accent.withOpacity(0.16),
                    child: Text(
                      archive.childName.isNotEmpty ? archive.childName[0] : '?',
                      style: textTheme.headlineSmall?.copyWith(color: accent),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(archive.childName,
                                  style: textTheme.titleLarge
                                      ?.copyWith(fontWeight: FontWeight.w800)),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: accent.withOpacity(0.14),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(archive.typeLabel,
                                  style: TextStyle(
                                      color: accent,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text('${archive.archiveNo} · ${archive.campusName}',
                            style: textTheme.bodyMedium
                                ?.copyWith(color: colors.onSurfaceVariant)),
                        const SizedBox(height: 6),
                        StatusChip(archive.status.label),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 即将上课 / 最新计划（置顶区）
          AppSectionTitle('即将上课 / 最新计划'),
          if (plans.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text('暂无教学计划，完成评估后由 AI 生成并自动提醒。',
                    style: textTheme.bodyMedium
                        ?.copyWith(color: colors.onSurfaceVariant)),
              ),
            )
          else
            Column(
              children: plans
                  .take(4)
                  .map((p) => _PlanCard(item: p))
                  .toList(),
            ),
          const SizedBox(height: 16),

          // 功能入口（按类型分支）
          AppSectionTitle('功能入口'),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            // 6 张卡片（3 行 × 2 列）时保持卡片方正；4 张时仍合适。
            childAspectRatio: 1.25,
            children: _entries(isAutism, archiveId)
                .map((e) => _HubEntryCard(entry: e))
                .toList(),
          ),
          const SizedBox(height: 16),

          // 待办任务
          AppSectionTitle('待办任务'),
          if (tasks.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text('暂无待办任务，辛苦了！',
                    style: textTheme.bodyMedium
                        ?.copyWith(color: colors.onSurfaceVariant)),
              ),
            )
          else
            Column(
              children: tasks
                  .take(5)
                  .map((t) => _TaskCard(
                        task: t,
                        onDone: () => ref
                            .read(rehabArchiveDetailProvider(archiveId).notifier)
                            .completeTask(t.id),
                      ))
                  .toList(),
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  List<_PlanItem> _buildPlanItems(bool isAutism, RehabArchiveDetail rehab,
      AutismArchiveDetail? autism) {
    final List<_PlanItem> items = <_PlanItem>[];
    final DateTime now = DateTime.now();
    if (!isAutism) {
      for (final p in rehab.plans) {
        final DateTime? d = p.planPeriodStart;
        items.add(_PlanItem(
          title: p.aiGenerated ? 'AI 生成 · 教学计划' : '教学计划',
          subtitle: _periodText(p.planPeriodStart, p.planPeriodEnd),
          date: d,
          upcoming: d == null || d.isAfter(now.subtract(const Duration(days: 1))),
          route: '/rehab/${rehab.archive.id}',
        ));
      }
    } else if (autism != null) {
      for (final lp in autism.lessonPlans) {
        final DateTime? d = lp.teachingDateStart;
        items.add(_PlanItem(
          title: '教育教案：${lp.lessonTitle.isEmpty ? '未命名' : lp.lessonTitle}',
          subtitle: lp.halfMonth == 'SECOND' ? '下半月' : '上半月',
          date: d,
          upcoming: d == null || d.isAfter(now.subtract(const Duration(days: 1))),
          route: '/rehab-autism/$archiveId',
        ));
      }
      for (final mp in autism.monthlyPlans) {
        final DateTime? d = mp.planMonth;
        items.add(_PlanItem(
          title: '月教学计划：${mp.monthLabel.isEmpty ? '未命名' : mp.monthLabel}',
          subtitle: mp.theme.isEmpty ? '未设置主题' : mp.theme,
          date: d,
          upcoming: d == null || d.isAfter(now.subtract(const Duration(days: 1))),
          route: '/rehab-autism/${rehab.archive.id}/monthly-plan-ai',
        ));
      }
    }
    items.sort((a, b) {
      if (a.upcoming != b.upcoming) return a.upcoming ? -1 : 1;
      if (a.date == null) return 1;
      if (b.date == null) return -1;
      return a.date!.compareTo(b.date!);
    });
    return items;
  }

  String _periodText(DateTime? start, DateTime? end) {
    final DateFormat fmt = DateFormat('yyyy-MM-dd');
    if (start == null && end == null) return '周期未设置';
    final String s = start == null ? '' : fmt.format(start);
    final String e = end == null ? '' : fmt.format(end);
    return '$s ~ $e';
  }

  List<_HubEntry> _entries(bool isAutism, String id) {
    if (isAutism) {
      return <_HubEntry>[
        // 档案总览（独立卡片）—— 点入总览页
        const _HubEntry(
          icon: Icons.dashboard_outlined,
          title: '档案总览',
          subtitle: '查看完整档案',
          route: '/rehab-autism/{id}',
          colorKey: 'teal',
        ),
        // 首次评测录入 —— 直接跳录入页，而非总览
        const _HubEntry(
          icon: Icons.assignment_outlined,
          title: '首次评测录入',
          subtitle: '文档一 493 题',
          route: '/rehab-autism/{id}/items',
          colorKey: 'rose',
        ),
        // IEP 干预计划（独立卡片）
        const _HubEntry(
          icon: Icons.auto_awesome_outlined,
          title: 'IEP 干预计划',
          subtitle: 'AI 推荐目标',
          route: '/rehab-autism/{id}/iep',
          colorKey: 'purple',
        ),
        // 月教学计划（独立卡片）
        const _HubEntry(
          icon: Icons.calendar_month_outlined,
          title: '月教学计划',
          subtitle: '六领域 × 4 周',
          route: '/rehab-autism/{id}/monthly-plan-ai',
          colorKey: 'amber',
        ),
        const _HubEntry(
          icon: Icons.insights_outlined,
          title: '训练效果评估表',
          subtitle: '年度效果',
          route: '/rehab-autism/{id}/effect',
          colorKey: 'blue',
        ),
        const _HubEntry(
          icon: Icons.pie_chart,
          title: '评估图表',
          subtitle: '饼图 / 折线图',
          route: '/rehab-autism/{id}/charts',
          colorKey: 'green',
        ),
      ].map((e) => _HubEntry(
            icon: e.icon,
            title: e.title,
            subtitle: e.subtitle,
            route: e.route.replaceAll('{id}', id),
            colorKey: e.colorKey,
          )).toList();
    }
    return <_HubEntry>[
      // 听障 6 个入口：总览独立 + 首测/续评直达录入
      const _HubEntry(
        icon: Icons.dashboard_outlined,
        title: '档案总览',
        subtitle: '查看完整档案',
        route: '/rehab/{id}',
        colorKey: 'teal',
      ),
      const _HubEntry(
        icon: Icons.assignment_outlined,
        title: '首次评估录入',
        subtitle: '听障评估表',
        route: '/rehab/{id}/first-eval-edit',
        colorKey: 'green',
      ),
      const _HubEntry(
        icon: Icons.assessment_outlined,
        title: '持续评估',
        subtitle: '待填写任务',
        route: '/rehab/{id}/cont-eval-edit',
        colorKey: 'amber',
      ),
      const _HubEntry(
        icon: Icons.hearing_outlined,
        title: '听能管理记录',
        subtitle: '听力图/诊断',
        route: '/rehab/{id}',
        colorKey: 'blue',
      ),
      const _HubEntry(
        icon: Icons.edit_calendar_outlined,
        title: '每节课教学计划',
        subtitle: 'AI 生成',
        route: '/rehab/{id}',
        colorKey: 'purple',
      ),
      const _HubEntry(
        icon: Icons.event_note_outlined,
        title: '评估待办',
        subtitle: '查看提醒',
        route: '/rehab/{id}',
        colorKey: 'rose',
      ),
    ].map((e) => _HubEntry(
          icon: e.icon,
          title: e.title,
          subtitle: e.subtitle,
          route: e.route.replaceAll('{id}', id),
          colorKey: e.colorKey,
        )).toList();
  }
}

class _PlanItem {
  _PlanItem({
    required this.title,
    required this.subtitle,
    required this.date,
    required this.upcoming,
    required this.route,
  });
  final String title;
  final String subtitle;
  final DateTime? date;
  final bool upcoming;
  final String route;
}

class _HubEntry {
  const _HubEntry({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
    required this.colorKey,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final String route;
  final String colorKey;
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.item});
  final _PlanItem item;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme colors = Theme.of(context).colorScheme;
    final DateFormat fmt = DateFormat('yyyy-MM-dd');
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => context.push(item.route),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.event_available_outlined,
                    color: colors.onPrimaryContainer),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(item.title,
                              style: textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700)),
                        ),
                        if (item.upcoming)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0EA5A4).withOpacity(0.14),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text('即将上课',
                                style: TextStyle(
                                    color: Color(0xFF0E8C84),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(item.subtitle,
                        style: textTheme.bodySmall
                            ?.copyWith(color: colors.onSurfaceVariant)),
                    if (item.date != null)
                      Text('时间：${fmt.format(item.date!)}',
                          style: textTheme.bodySmall
                              ?.copyWith(color: colors.onSurfaceVariant)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _HubEntryCard extends StatelessWidget {
  const _HubEntryCard({required this.entry});
  final _HubEntry entry;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme colors = Theme.of(context).colorScheme;
    final Color accent = iconColor(entry.colorKey);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(entry.route),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(entry.icon, color: accent, size: 22),
              ),
              const SizedBox(height: 10),
              Text(
                entry.title,
                style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Expanded(
                child: Text(
                  entry.subtitle,
                  style: textTheme.bodySmall
                      ?.copyWith(color: colors.onSurfaceVariant),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.task, required this.onDone});
  final RehabTask task;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final DateFormat fmt = DateFormat('yyyy-MM-dd');
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: colors.primaryContainer,
          foregroundColor: colors.onPrimaryContainer,
          child: Icon(
            task.reminderType == 'TEACHING_PLAN'
                ? Icons.edit_calendar_outlined
                : Icons.assessment_outlined,
            size: 20,
          ),
        ),
        title: Text(task.title),
        subtitle: Text('${task.typeLabel} · 截止 ${fmt.format(task.dueDate)}'),
        trailing: TextButton(
          onPressed: onDone,
          child: const Text('完成'),
        ),
      ),
    );
  }
}
