import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:teacher_app/data/models/autism_archive.dart';
import 'package:teacher_app/data/models/rehab.dart';
import 'package:teacher_app/features/rehab/presentation/widgets/child_timeline.dart';
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

    /// 重新拉取档案详情：编辑儿童信息保存后、或手动点刷新时调用。
    void _reload() {
      ref.read(rehabArchiveDetailProvider(archiveId).notifier).reload();
      if (isAutism) {
        ref.read(autismArchiveDetailProvider(archiveId).notifier).reload();
      }
    }

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
          // 档案总览：/rehab/:id 详情页（含官方表单整档导出）。
          // 没有这个入口它就成了取不到的孤儿页，整档 PDF 导出也就没地方点了。
          IconButton(
            icon: const Icon(Icons.folder_open_outlined),
            tooltip: '档案总览与整档导出',
            onPressed: () => context.push('/rehab/$archiveId'),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: '编辑儿童信息',
            // 编辑页保存后 pop(true)，回到本页立刻重新拉取，姓名等信息即时更新。
            onPressed: () async {
              final Object? saved =
                  await context.push<Object?>('/children/$archiveId/edit');
              if (saved == true && context.mounted) _reload();
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
            onPressed: _reload,
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

          // 听障三步流程引导：先让老师看清「现在该做哪一步」，再进功能入口。
          if (!isAutism) ...<Widget>[
            _HearingFlowGuide(
              archiveId: archiveId,
              detail: rehabState.detail!,
            ),
            const SizedBox(height: 16),
          ],

          // 功能入口（按类型分支）— 已提到评估历史之上。
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

          // 即将上课 / 最新计划（挪到功能入口之下，符合「先做事再排程」的次序）。
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
                        // 点卡片直达该做的事：教学计划提醒 → 计划页；其余 → 持续评估页。
                        onOpen: () => context.push(
                          t.reminderType == 'TEACHING_PLAN'
                              ? '/rehab/$archiveId/plan'
                              : '/rehab/$archiveId/cont-eval-edit',
                        ),
                      ))
                  .toList(),
            ),
          const SizedBox(height: 16),

          // 评估 / 计划 / 文档 时间线（按时间倒序）
          AppSectionTitle('时间线'),
          if (rehabState.detail != null)
            ChildTimeline(
              archiveId: archiveId,
              isAutism: isAutism,
              rehab: rehabState.detail!,
              autism: isAutism ? autismState?.detail : null,
            ),
          const SizedBox(height: 24),
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
          title: p.aiGenerated ? 'AI 教学计划（7 项目标）' : '教学计划',
          subtitle: '${_periodText(p.planPeriodStart, p.planPeriodEnd)}'
              '${p.aiSourceLabel.isEmpty ? '' : ' · ${p.aiSourceLabel}'}',
          date: d,
          upcoming: d == null || d.isAfter(now.subtract(const Duration(days: 1))),
          // 点开直接进教学计划页（7 项目标 + 与 AI 对话修改），不再落到档案详情。
          route: '/rehab/${rehab.archive.id}/plan',
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
    // 听障主线已收敛为「首次评估 → 持续评估 → 教学计划 → 单课教案」四项，
    // 听能管理入口下线；残联标准模板保留（承载手写板汇总与全部模块下钻，避免孤儿页）。
    // 孤独症保持原样（残联标准模板 + OFFLINE / PEP-3 / VB）。
    final List<_HubEntry> raw = isAutism
        ? <_HubEntry>[
            const _HubEntry(
              icon: Icons.folder_special_outlined,
              title: '残联标准模板',
              subtitle: '月计划 / IEP / 评估等标准模块',
              route: '/children/{id}/template?autism={autism}',
              colorKey: 'teal',
            ),
            const _HubEntry(
              icon: Icons.offline_bolt_outlined,
              title: 'C-PEP3',
              subtitle: 'OFFLINE A/B 卷评估',
              route: '/rehab-autism/{id}/offline-home',
              colorKey: 'rose',
            ),
            const _HubEntry(
              icon: Icons.child_care_outlined,
              title: 'PEP-3',
              subtitle: '填各领域预估年龄 → 直接出报告',
              route: '/rehab-autism/{id}/pep3-home',
              colorKey: 'indigo',
            ),
            const _HubEntry(
              icon: Icons.record_voice_over_outlined,
              title: 'VB',
              subtitle: 'VB 教师 / 家长卷',
              route: '/rehab-autism/{id}/vb-home',
              colorKey: 'purple',
            ),
          ]
        : <_HubEntry>[
            const _HubEntry(
              icon: Icons.assignment_outlined,
              title: '首次评估',
              subtitle: '听障儿童评估表',
              route: '/rehab/{id}/first-eval-edit',
              colorKey: 'teal',
            ),
            const _HubEntry(
              icon: Icons.assessment_outlined,
              title: '持续评估',
              subtitle: '每 2 个月一次',
              route: '/rehab/{id}/cont-eval-edit',
              colorKey: 'amber',
            ),
            const _HubEntry(
              icon: Icons.edit_calendar_outlined,
              title: '教学计划',
              subtitle: '7 项目标 · AI 生成 + 对话修改',
              route: '/rehab/{id}/plan',
              colorKey: 'purple',
            ),
            const _HubEntry(
              icon: Icons.menu_book_outlined,
              title: '单课教案',
              subtitle: '5 领域 · 依据教学计划',
              route: '/rehab/{id}/lesson-plan',
              colorKey: 'blue',
            ),
            const _HubEntry(
              icon: Icons.folder_special_outlined,
              title: '残联标准模板',
              subtitle: '全部模块 + 手写板汇总',
              route: '/children/{id}/template?autism={autism}',
              colorKey: 'green',
            ),
          ];

    return raw
        .map((_HubEntry e) => _HubEntry(
              icon: e.icon,
              title: e.title,
              subtitle: e.subtitle,
              route: e.route
                  .replaceAll('{id}', id)
                  .replaceAll('{autism}', isAutism ? '1' : '0'),
              colorKey: e.colorKey,
            ))
        .toList();
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
  const _TaskCard({required this.task, required this.onDone, this.onOpen});
  final RehabTask task;
  final VoidCallback onDone;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final DateFormat fmt = DateFormat('yyyy-MM-dd');
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onOpen,
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

/// 听障业务流程的一步（用于 [_HearingFlowGuide]）。
class _FlowStep {
  const _FlowStep({
    required this.index,
    required this.title,
    required this.desc,
    required this.done,
    required this.route,
  });

  final int index;
  final String title;
  final String desc;
  final bool done;
  final String route;
}

/// 听障三步流程引导卡：① 首次评估 → ② 持续评估 → ③ 教学计划。
///
/// 目的：老师打开儿童档案时立刻知道「现在该做哪一步」，而不是在功能入口里猜。
/// 每步可点直达对应页面；第一个未完成的步骤高亮为「当前该做」。
/// 老生允许跳过首次评估，不会因为首评为空就把第①步标成红色待办。
class _HearingFlowGuide extends StatelessWidget {
  const _HearingFlowGuide({required this.archiveId, required this.detail});
  final String archiveId;
  final RehabArchiveDetail detail;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme colors = Theme.of(context).colorScheme;
    final DateFormat fmt = DateFormat('yyyy-MM-dd');

    final bool hasFirst = detail.hasFirstEval;
    final bool oldStudent = !detail.archive.isNewStudent;
    final int contDone = detail.completedContEvalCount;
    final RehabTask? openTask = detail.openContEvalTask;
    final RehabTeachingPlan? plan = detail.latestPlan;

    final List<_FlowStep> steps = <_FlowStep>[
      _FlowStep(
        index: 1,
        title: '首次评估',
        desc: hasFirst
            ? '已完成，可随时修改'
            : (oldStudent ? '老生可跳过，直接填持续评估' : '先完成，AI 之后才有生成依据'),
        done: hasFirst,
        route: '/rehab/$archiveId/first-eval-edit',
      ),
      _FlowStep(
        index: 2,
        title: '持续评估',
        desc: contDone == 0 && openTask == null
            ? '每 2 个月填一次'
            : '${contDone > 0 ? '已完成 $contDone 期' : '待填写'}'
                '${openTask == null ? '' : ' · 下次 ${fmt.format(openTask.dueDate)}'}',
        done: contDone > 0 && openTask == null,
        route: '/rehab/$archiveId/cont-eval-edit',
      ),
      _FlowStep(
        index: 3,
        title: '教学计划',
        desc: plan == null
            ? '按最新评估 AI 生成 7 项目标'
            : '${plan.aiGenerated ? 'AI 已生成' : '已创建'} · ${plan.aiSourceLabel}',
        done: plan != null && plan.hasAnyGoal,
        route: '/rehab/$archiveId/plan',
      ),
    ];
    // 第一个未完成的步骤即「当前该做」；三步都完成时高亮最后一步（教学计划）。
    final int found = steps.indexWhere((_FlowStep s) => !s.done);
    final int currentIndex = found < 0 ? steps.length - 1 : found;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.route_outlined, color: colors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('听障康复流程',
                      style: textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w800)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    oldStudent ? '老生' : '新生',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: colors.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (int i = 0; i < steps.length; i++)
              _FlowStepRow(step: steps[i], current: i == currentIndex),
          ],
        ),
      ),
    );
  }
}

class _FlowStepRow extends StatelessWidget {
  const _FlowStepRow({required this.step, required this.current});
  final _FlowStep step;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    const Color doneColor = Color(0xFF0EA5A4);
    final Color circleColor =
        step.done ? doneColor : (current ? colors.primary : colors.outline);
    return InkWell(
      onTap: () => context.push(step.route),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: current ? colors.primary : colors.outlineVariant,
            width: current ? 1.6 : 1,
          ),
          color: current
              ? colors.primaryContainer.withValues(alpha: 0.45)
              : null,
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: circleColor,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: step.done
                  ? const Icon(Icons.check, size: 15, color: Colors.white)
                  : Text(
                      '${step.index}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700),
                    ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Text(step.title,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14)),
                      if (current) ...<Widget>[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: colors.primary,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            '当前该做',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 1),
                  Text(
                    step.desc,
                    style: TextStyle(
                        fontSize: 12, color: colors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 18),
          ],
        ),
      ),
    );
  }
}
