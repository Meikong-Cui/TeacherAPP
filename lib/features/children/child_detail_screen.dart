import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:teacher_app/data/models/rehab.dart';
import 'package:teacher_app/features/rehab/provider/rehab_provider.dart';
import 'package:teacher_app/shared/ui.dart';

/// 儿童详情：基于真实康复档案数据，提供功能入口。
/// 从首页"我的儿童"点击进入，archiveId 即为康复档案 ID。
class ChildDetailScreen extends ConsumerWidget {
  const ChildDetailScreen({super.key, required this.id});
  final String id; // 实际为 archiveId

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final RehabArchiveDetailState state =
        ref.watch(rehabArchiveDetailProvider(id));
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme colors = Theme.of(context).colorScheme;

    // 触发加载（如果还没加载过）
    if (state.detail == null && !state.loading) {
      Future.microtask(() =>
          ref.read(rehabArchiveDetailProvider(id).notifier).load(id));
    }

    if (state.loading && state.detail == null) {
      return Scaffold(
        appBar: AppBar(title: Text('加载中...')),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (state.error != null && state.detail == null) {
      return Scaffold(
        appBar: AppBar(title: Text('加载失败')),
        body: Center(child: Text('档案加载失败：${state.error}')),
      );
    }
    if (state.detail == null) {
      return Scaffold(
        appBar: AppBar(title: Text('未找到')),
        body: Center(child: Text('未找到该档案')),
      );
    }

    final RehabArchiveDetail detail = state.detail!;
        final RehabArchive a = detail.archive;
        final List<RehabTask> tasks = detail.tasks
            .where((t) => !t.completed)
            .toList()
          ..sort((x, y) => x.dueDate.compareTo(y.dueDate));
        final List<RehabTeachingPlan> plans = detail.plans;
        final List<RehabContEval> contEvals = detail.contEvals;

        return Scaffold(
          appBar: AppBar(title: Text(a.childName)),
          body: ListView(
            padding: EdgeInsets.all(16),
            children: <Widget>[
              // ── 头部卡片：儿童名 + 档案信息 ──
              Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Row(
                    children: <Widget>[
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: colors.primaryContainer,
                        foregroundColor: colors.onPrimaryContainer,
                        child: Text(
                          a.childName.isNotEmpty ? a.childName[0] : '?',
                          style: textTheme.headlineSmall,
                        ),
                      ),
                      SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(a.childName,
                                style: textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w800)),
                            SizedBox(height: 4),
                            Text('${a.archiveNo} · ${a.campusName}',
                                style: textTheme.bodyMedium),
                            SizedBox(height: 6),
                            StatusChip(a.status.label),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 8),

              // ── 醒目的「新增教学计划」按钮 ──
              FilledButton.icon(
                onPressed: () => _createPlan(context, ref, id),
                icon: Icon(Icons.add_circle_outline),
                label: Text('新增教学计划（高频操作）'),
                style: FilledButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  textStyle: textTheme.titleMedium,
                ),
              ),
              SizedBox(height: 8),
              Text('听障的教学计划每节课都要更新，是高频场景',
                  style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12)),

              AppSectionTitle('功能入口'),
              // 评估任务 → 跳转到康复档案详情页（不再自动创建教学计划）
              _EntryTile(
                icon: Icons.edit_calendar_outlined,
                title: '评估任务',
                subtitle: tasks.isNotEmpty
                    ? '最近待办：${tasks.first.title}'
                    : '查看评估任务与记录',
                onTap: () => context.push('/rehab/$id'),
              ),
              // IEP目标 → 展示持续评估/首次评估任务
              _EntryTile(
                icon: Icons.flag_outlined,
                title: 'IEP 目标',
                subtitle: contEvals.isNotEmpty
                    ? '${contEvals.length} 条持续评估记录'
                    : detail.firstEval != null
                        ? '已填写首次评估'
                        : '尚未填写首次评估',
                onTap: () => _showEvalTasks(context, detail),
              ),
              // 训练记录 → 历史教学计划列表
              _EntryTile(
                icon: Icons.fitness_center_outlined,
                title: '训练记录',
                subtitle: plans.isNotEmpty
                    ? '${plans.length} 份教学计划'
                    : '暂无教学计划',
                onTap: () => _showTrainingRecords(context, plans),
              ),
              AppSectionTitle('动态时间线'),
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      if (detail.firstEval != null) ...[
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.assignment, color: colors.primary),
                          title: Text('首次评估已填写'),
                          subtitle: Text('评估人：${detail.firstEval!.evaluatorName}'),
                        ),
                      ],
                      if (contEvals.isNotEmpty)
                        ...contEvals.map((c) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(Icons.assessment, color: colors.primary),
                              title: Text('第 ${c.evalSeq ?? 0} 次持续评估'),
                              subtitle: Text(c.status.label),
                            )),
                      if (plans.isNotEmpty)
                        ...plans.map((p) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(Icons.edit_calendar, color: colors.primary),
                              title: Text(p.aiGenerated ? 'AI 生成计划' : '教学计划'),
                              subtitle: Text(p.hearingGoal.isEmpty
                                  ? '（未填目标）'
                                  : p.hearingGoal),
                            )),
                      if (detail.firstEval == null &&
                          contEvals.isEmpty &&
                          plans.isEmpty)
                        Text('暂无动态', style: TextStyle(color: Colors.black54)),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16),
            ],
          ),
        );
  }

  /// 新增教学计划：跳转到康复详情的"教学计划"Tab 并提示创建。
  void _createPlan(BuildContext context, WidgetRef ref, String archiveId) {
    context.push('/rehab/$archiveId');
    // 延迟跳转到教学计划 Tab（等页面加载完）
    Future.delayed(Duration(milliseconds: 500), () {
      // 通过 provider 触发新建
      ref.read(rehabArchiveDetailProvider(archiveId).notifier).createPlan(
        RehabTeachingPlan(
          archiveId: archiveId,
          planPeriodStart: DateTime.now(),
          planPeriodEnd: DateTime.now().add(Duration(days: 60)),
        ),
      );
    });
  }

  /// IEP 目标：展示当前两月持续评估任务（无则展示首次评估）。
  void _showEvalTasks(BuildContext context, RehabArchiveDetail detail) {
    final List<RehabContEval> contEvals = detail.contEvals;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        expand: false,
        builder: (_, scrollCtrl) => Column(
          children: <Widget>[
            Padding(
              padding: EdgeInsets.all(16),
              child: Text('IEP 目标 / 评估任务',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            ),
            Divider(height: 1),
            Expanded(
              child: contEvals.isNotEmpty
                  ? ListView.builder(
                      controller: scrollCtrl,
                      itemCount: contEvals.length,
                      itemBuilder: (_, i) {
                        final RehabContEval c = contEvals[i];
                        return ListTile(
                          leading: Icon(Icons.assessment_outlined,
                              color: Theme.of(ctx).colorScheme.primary),
                          title: Text('第 ${c.evalSeq ?? 0} 次持续评估'),
                          subtitle: Text(c.evalDate == null
                              ? '状态：${c.status.label}'
                              : '${DateFormat('yyyy-MM-dd').format(c.evalDate!)} · ${c.status.label}'),
                          trailing: StatusChip(c.status.label),
                        );
                      },
                    )
                  : detail.firstEval != null
                      ? ListView(
                          controller: scrollCtrl,
                          padding: EdgeInsets.all(16),
                          children: <Widget>[
                            Text('首次评估已填写（尚无持续评估记录）',
                                style: TextStyle(color: Colors.black54)),
                            SizedBox(height: 12),
                            ...<String>[
                              '听能管理：${detail.firstEval!.domainHearingMgmt}',
                              '听觉能力：${detail.firstEval!.domainHearingAbility}',
                              '语言能力：${detail.firstEval!.domainLanguage}',
                              '言语能力：${detail.firstEval!.domainSpeech}',
                              '认知能力：${detail.firstEval!.domainCognition}',
                              '沟通能力：${detail.firstEval!.domainCommunication}',
                            ].map((s) => Padding(
                                  padding: EdgeInsets.symmetric(vertical: 3),
                                  child: Text(s),
                                )),
                          ],
                        )
                      : ListView(
                          controller: scrollCtrl,
                          padding: EdgeInsets.all(16),
                          children: <Widget>[
                            Icon(Icons.info_outline, color: Colors.orange, size: 40),
                            SizedBox(height: 12),
                            Text('尚未填写任何评估',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 15)),
                            SizedBox(height: 8),
                            Text('请先在"康复档案"中填写首次评估',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.black54)),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  /// 训练记录：展示历史教学计划列表。
  void _showTrainingRecords(BuildContext context, List<RehabTeachingPlan> plans) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        expand: false,
        builder: (_, scrollCtrl) => Column(
          children: <Widget>[
            Padding(
              padding: EdgeInsets.all(16),
              child: Text('训练记录 / 教学计划历史',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            ),
            Divider(height: 1),
            Expanded(
              child: plans.isNotEmpty
                  ? ListView.builder(
                      controller: scrollCtrl,
                      itemCount: plans.length,
                      itemBuilder: (_, i) {
                        final RehabTeachingPlan p = plans[i];
                        return ListTile(
                          leading: Icon(
                            p.aiGenerated ? Icons.auto_awesome : Icons.edit_calendar,
                            color: Theme.of(ctx).colorScheme.primary,
                          ),
                          title: Text(p.aiGenerated ? 'AI 生成' : '手动创建'),
                          subtitle: Text(_planPeriodText(p)),
                          isThreeLine: true,
                        );
                      },
                    )
                  : ListView(
                      controller: scrollCtrl,
                      padding: EdgeInsets.all(16),
                      children: <Widget>[
                        Icon(Icons.history, color: Colors.grey, size: 40),
                        SizedBox(height: 12),
                        Text('暂无教学计划记录',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 15)),
                        SizedBox(height: 8),
                        Text('点击上方"新增教学计划"开始填写',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.black54)),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _planPeriodText(RehabTeachingPlan p) {
    final String start = p.planPeriodStart == null
        ? ''
        : DateFormat('yyyy-MM-dd').format(p.planPeriodStart!);
    final String end = p.planPeriodEnd == null
        ? ''
        : DateFormat('yyyy-MM-dd').format(p.planPeriodEnd!);
    if (start.isEmpty && end.isEmpty) return '周期未设置';
    return '$start ~ $end · 听能:${p.hearingGoal}';
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 12)),
        trailing: Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
