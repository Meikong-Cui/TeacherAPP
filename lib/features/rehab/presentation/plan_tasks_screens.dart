import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:teacher_app/app/design_tokens.dart';
import 'package:teacher_app/shared/ui.dart';
import 'package:teacher_app/data/models/rehab.dart';
import 'package:teacher_app/features/rehab/provider/rehab_provider.dart';

/// 听障档案 - 教学计划独立页。
class PlanSectionScreen extends ConsumerWidget {
  const PlanSectionScreen({required this.archiveId, super.key});
  final String archiveId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final RehabArchiveDetailState st =
        ref.watch(rehabArchiveDetailProvider(archiveId));
    final List<RehabTeachingPlan> plans = st.detail?.plans ?? <RehabTeachingPlan>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('教学计划',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppPalette.ink)),
        // 任何时刻都能手动新建教学计划，不依赖 AI 何时生成。
        actions: <Widget>[
          TextButton.icon(
            onPressed: () => _createPlan(context, ref),
            icon: const Icon(Icons.add, size: 18, color: AppPalette.brandDark),
            label: const Text('新建教学计划',
                style: TextStyle(
                    color: AppPalette.brandDark,
                    fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: st.loading && st.detail == null
          ? const Center(child: CircularProgressIndicator())
          : plans.isEmpty
              ? Center(
                  child: SoftCard(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Icon(Icons.menu_book_outlined,
                            size: 56, color: AppPalette.inkMute),
                        const SizedBox(height: 12),
                        const Text('暂无教学计划',
                            style: TextStyle(
                                fontSize: AppFontSize.title,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        const Text(
                            '可在档案详情首次评估后使用 AI 自动生成，也可手动新建',
                            style: TextStyle(
                                fontSize: AppFontSize.small,
                                color: AppPalette.inkMute)),
                        const SizedBox(height: 16),
                        // 空态主 CTA：即使无首次评估也能立刻开始。
                        FilledButton.icon(
                          onPressed: () => _createPlan(context, ref),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('新建教学计划'),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: plans.length,
                  itemBuilder: (BuildContext ctx, int i) {
                    final RehabTeachingPlan p = plans[i];
                    final DateFormat fmt = DateFormat('yyyy.MM.dd');
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      // 纯查看卡片：各领域目标已完整展示，不再跳转
                      // （原先点击会 push 回档案详情页，造成循环嵌套导航）。
                      child: SoftCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(children: <Widget>[
                              Icon(
                                p.aiGenerated
                                    ? Icons.auto_awesome_outlined
                                    : Icons.edit_calendar_outlined,
                                color: AppPalette.brandDark,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  p.aiGenerated ? 'AI 教学计划' : '教学计划',
                                  style: const TextStyle(
                                    fontSize: AppFontSize.title,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ]),
                            const SizedBox(height: 6),
                            Text(
                              '${fmt.format(p.planPeriodStart ?? DateTime.now())} ~ ${fmt.format(p.planPeriodEnd ?? DateTime.now())}',
                              style: const TextStyle(
                                  fontSize: AppFontSize.small,
                                  color: AppPalette.inkMute),
                            ),
                            if (p.hearingGoal.isNotEmpty)
                              _goalLine('听觉', p.hearingGoal),
                            if (p.speechGoal.isNotEmpty)
                              _goalLine('言语', p.speechGoal),
                            if (p.languageGoal.isNotEmpty)
                              _goalLine('语言', p.languageGoal),
                            if (p.cognitionGoal.isNotEmpty)
                              _goalLine('认知', p.cognitionGoal),
                            if (p.communicationGoal.isNotEmpty)
                              _goalLine('沟通', p.communicationGoal),
                            if (p.familyGuidance.isNotEmpty)
                              _goalLine('家庭指导', p.familyGuidance),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  /// 手动新建教学计划：与 `rehab_archive_detail_screen._createPlan` 同语义，
  /// 默认起止时间=今天 ~ 今天+60 天，可立刻在弹窗或档案页里继续编辑。
  Future<void> _createPlan(BuildContext context, WidgetRef ref) async {
    final DateTime now = DateTime.now();
    final RehabTeachingPlan plan = RehabTeachingPlan(
      archiveId: archiveId,
      planPeriodStart: now,
      planPeriodEnd: now.add(const Duration(days: 60)),
      teacherName: '教师',
    );
    try {
      final bool ok = await ref
          .read(rehabArchiveDetailProvider(archiveId).notifier)
          .createPlan(plan);
      if (!context.mounted) return;
      // 本页没监听 state.message，所以主动弹一下；同时清掉 message 避免
      // 用户跳回档案详情页时再被 ref.listen 重复弹出。
      ref
          .read(rehabArchiveDetailProvider(archiveId).notifier)
          .clearMessage();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? '教学计划已新建' : '新建失败，请稍后再试'),
      ));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('新建失败：$e')));
    }
  }

  Widget _goalLine(String label, String value) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: RichText(
          text: TextSpan(
            style: const TextStyle(
              fontSize: AppFontSize.small,
              color: AppPalette.ink,
              height: 1.5,
            ),
            children: <InlineSpan>[
              TextSpan(
                text: '$label ',
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppPalette.brandDark),
              ),
              TextSpan(text: value),
            ],
          ),
        ),
      );
}

/// 听障档案 - 评估待办独立页。
class TasksSectionScreen extends ConsumerWidget {
  const TasksSectionScreen({required this.archiveId, super.key});
  final String archiveId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final RehabArchiveDetailState st =
        ref.watch(rehabArchiveDetailProvider(archiveId));
    final List<RehabTask> tasks = st.detail?.tasks ?? <RehabTask>[];
    final DateFormat fmt = DateFormat('yyyy.MM.dd');
    final List<RehabTask> pending =
        tasks.where((RehabTask t) => !t.completed).toList();
    final List<RehabTask> done =
        tasks.where((RehabTask t) => t.completed).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('评估待办',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppPalette.ink)),
      ),
      body: RefreshIndicator(
        onRefresh: () async =>
            ref.read(rehabArchiveDetailProvider(archiveId).notifier).reload(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            AppSectionTitle('待办（${pending.length}）'),
            if (pending.isEmpty)
              const SoftCard(
                  child: Text('暂无待办',
                      style: TextStyle(color: AppPalette.inkMute))),
            ...pending.map((RehabTask t) {
              final bool overdue = t.dueDate.isBefore(DateTime.now());
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SoftCard(
                  child: Row(children: <Widget>[
                    Icon(
                      t.reminderType == 'TEACHING_PLAN'
                          ? Icons.edit_calendar_outlined
                          : Icons.assessment_outlined,
                      color:
                          overdue ? AppPalette.danger : AppPalette.warning,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(t.title,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600)),
                          Text('${t.typeLabel} · 截止 ${fmt.format(t.dueDate)}',
                              style: TextStyle(
                                  fontSize: AppFontSize.small,
                                  color: overdue
                                      ? AppPalette.danger
                                      : AppPalette.inkMute)),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        await ref
                            .read(rehabArchiveDetailProvider(archiveId)
                                .notifier)
                            .completeTask(t.id);
                      },
                      child: const Text('完成'),
                    ),
                  ]),
                ),
              );
            }),
            const SizedBox(height: 8),
            AppSectionTitle('已完成（${done.length}）'),
            ...done.map((RehabTask t) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SoftCard(
                    child: Row(children: <Widget>[
                      const Icon(Icons.check_circle,
                          color: AppPalette.success),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(t.title,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w500)),
                            Text(
                              '${t.typeLabel} · 完成 ${t.completedAt == null ? '—' : fmt.format(t.completedAt!)}',
                              style: const TextStyle(
                                  fontSize: AppFontSize.small,
                                  color: AppPalette.inkMute),
                            ),
                          ],
                        ),
                      ),
                    ]),
                  ),
                )),
          ],
        ),
      ),
    );
  }
}
