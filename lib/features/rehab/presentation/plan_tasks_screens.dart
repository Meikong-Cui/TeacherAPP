import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
      ),
      body: st.loading && st.detail == null
          ? const Center(child: CircularProgressIndicator())
          : plans.isEmpty
              ? Center(
                  child: SoftCard(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const <Widget>[
                        Icon(Icons.menu_book_outlined,
                            size: 56, color: AppPalette.inkMute),
                        SizedBox(height: 12),
                        Text('暂无教学计划',
                            style: TextStyle(
                                fontSize: AppFontSize.title,
                                fontWeight: FontWeight.bold)),
                        SizedBox(height: 4),
                        Text('可在档案详情首次评估后使用 AI 自动生成',
                            style: TextStyle(
                                fontSize: AppFontSize.small,
                                color: AppPalette.inkMute)),
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
                      child: SoftCard(
                        onTap: () => context.push(
                            '/rehab/$archiveId'),
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
