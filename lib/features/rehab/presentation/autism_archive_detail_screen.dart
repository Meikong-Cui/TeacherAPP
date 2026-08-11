import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:teacher_app/data/models/autism_archive.dart';
import 'package:teacher_app/data/models/rehab.dart';
import 'package:teacher_app/features/rehab/provider/autism_provider.dart';
import 'package:teacher_app/shared/ui.dart';

String _fmt(DateTime? d) =>
    d == null ? '—' : DateFormat('yyyy-MM-dd').format(d);

/// 孤独症档案详情（按 7 类文档分区块展示，点击进入编辑）。
class AutismArchiveDetailScreen extends ConsumerStatefulWidget {
  const AutismArchiveDetailScreen({required this.archiveId, super.key});
  final String archiveId;

  @override
  ConsumerState<AutismArchiveDetailScreen> createState() =>
      _AutismArchiveDetailScreenState();
}

class _AutismArchiveDetailScreenState
    extends ConsumerState<AutismArchiveDetailScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref
        .read(autismArchiveDetailProvider(widget.archiveId).notifier)
        .load(widget.archiveId));
  }

  Future<void> _refresh() async =>
      ref.read(autismArchiveDetailProvider(widget.archiveId).notifier).reload();

  void _goEdit(String doc, {String? docId}) {
    final String q = docId != null ? '?docId=$docId' : '';
    context.push('/rehab-autism/${widget.archiveId}/edit/$doc$q');
  }

  @override
  Widget build(BuildContext context) {
    final AutismArchiveDetailState st =
        ref.watch(autismArchiveDetailProvider(widget.archiveId));
    final bool loading = st.loading && st.detail == null;

    // 一次性提示
    ref.listen<AutismArchiveDetailState>(
        autismArchiveDetailProvider(widget.archiveId), (prev, next) {
      if (next.message != null && next.message != prev?.message) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(next.message!)));
        ref
            .read(autismArchiveDetailProvider(widget.archiveId).notifier)
            .clearMessage();
      }
      if (next.error != null && next.error != prev?.error) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(next.error!)));
        ref
            .read(autismArchiveDetailProvider(widget.archiveId).notifier)
            .clearError();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(st.detail?.archive.childName ?? '孤独症档案'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
            tooltip: '刷新',
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : st.detail == null
              ? Center(child: Text(st.error ?? '加载失败'))
              : RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: <Widget>[
                      _OverviewCard(detail: st.detail!),
                      const SizedBox(height: 16),
                      _TaskSection(
                        tasks: st.detail!.tasks,
                        onComplete: (id) => ref
                            .read(autismArchiveDetailProvider(widget.archiveId)
                                .notifier)
                            .completeTask(id),
                      ),
                      const SizedBox(height: 16),
                      _FirstEvalSection(
                        firstEval: st.detail!.firstEval,
                        onEdit: () => _goEdit('first-eval',
                            docId: st.detail!.firstEval?.id),
                      ),
                      const SizedBox(height: 16),
                      _ListSection<AutismContEval>(
                        title: '持续评估',
                        items: st.detail!.contEvals,
                        emptyHint: '暂无持续评估',
                        onAdd: () => _goEdit('cont-eval'),
                        itemSubtitle: (e) =>
                            '第${e.evalSeq ?? "?"}次 · ${_fmt(e.evalDate)}',
                        itemTitle: (e) => '持续评估（${e.evaluatorName}）',
                        onEdit: (e) => _goEdit('cont-eval', docId: e.id),
                        onDelete: (e) => ref
                            .read(autismArchiveDetailProvider(widget.archiveId)
                                .notifier)
                            .deleteContEval(e.id!),
                      ),
                      const SizedBox(height: 16),
                      _ListSection<AutismSemesterPlan>(
                        title: '学期教学计划',
                        items: st.detail!.semesterPlans,
                        emptyHint: '暂无学期计划',
                        onAdd: () => _goEdit('semester-plan'),
                        itemSubtitle: (e) =>
                            '${_fmt(e.periodStart)} ~ ${_fmt(e.periodEnd)}',
                        itemTitle: (e) => '第${e.seqNo ?? "?"}学期 · ${e.planNo}',
                        onEdit: (e) => _goEdit('semester-plan', docId: e.id),
                        onDelete: (e) => ref
                            .read(autismArchiveDetailProvider(widget.archiveId)
                                .notifier)
                            .deleteSemesterPlan(e.id!),
                      ),
                      const SizedBox(height: 16),
                      _ListSection<AutismMonthlyPlan>(
                        title: '月教学计划',
                        items: st.detail!.monthlyPlans,
                        emptyHint: '暂无月计划',
                        onAdd: () => _goEdit('monthly-plan'),
                        itemSubtitle: (e) => e.theme,
                        itemTitle: (e) => e.monthLabel,
                        onEdit: (e) => _goEdit('monthly-plan', docId: e.id),
                        onDelete: (e) => ref
                            .read(autismArchiveDetailProvider(widget.archiveId)
                                .notifier)
                            .deleteMonthlyPlan(e.id!),
                      ),
                      const SizedBox(height: 16),
                      _ListSection<AutismLessonPlan>(
                        title: '月份教育教案',
                        items: st.detail!.lessonPlans,
                        emptyHint: '暂无教案',
                        onAdd: () => _goEdit('lesson-plan'),
                        itemSubtitle: (e) =>
                            '${e.halfMonth == 'FIRST' ? '上半月' : '下半月'} · ${e.lessonTitle}',
                        itemTitle: (e) => _fmt(e.planMonth),
                        onEdit: (e) => _goEdit('lesson-plan', docId: e.id),
                        onDelete: (e) => ref
                            .read(autismArchiveDetailProvider(widget.archiveId)
                                .notifier)
                            .deleteLessonPlan(e.id!),
                      ),
                      const SizedBox(height: 16),
                      _ListSection<AutismFamilyGuide>(
                        title: '家庭康复指导（每周）',
                        items: st.detail!.familyGuides,
                        emptyHint: '暂无家庭指导',
                        onAdd: () => _goEdit('family-guide'),
                        itemSubtitle: (e) => e.guideTarget,
                        itemTitle: (e) => e.weekLabel,
                        onEdit: (e) => _goEdit('family-guide', docId: e.id),
                        onDelete: (e) => ref
                            .read(autismArchiveDetailProvider(widget.archiveId)
                                .notifier)
                            .deleteFamilyGuide(e.id!),
                      ),
                      const SizedBox(height: 16),
                      _ListSection<AutismEffectRecord>(
                        title: '年度康复效果登记表',
                        items: st.detail!.effectRecords,
                        emptyHint: '暂无效果登记',
                        onAdd: () => _goEdit('effect-record'),
                        itemSubtitle: (e) => '有效率 ${e.effectiveRate}',
                        itemTitle: (e) => '${e.recordYear ?? "?"} 年度',
                        onEdit: (e) => _goEdit('effect-record', docId: e.id),
                        onDelete: (e) => ref
                            .read(autismArchiveDetailProvider(widget.archiveId)
                                .notifier)
                            .deleteEffectRecord(e.id!),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }
}

/// 概览卡片。
class _OverviewCard extends StatelessWidget {
  const _OverviewCard({required this.detail});
  final AutismArchiveDetail detail;

  @override
  Widget build(BuildContext context) {
    final RehabArchive a = detail.archive;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                StatusChip('孤独症', tone: const Color(0xFF7C5CF0)),
                const SizedBox(width: 8),
                StatusChip(a.status.label),
              ],
            ),
            const SizedBox(height: 8),
            InfoRow(label: '档案编号', value: a.archiveNo),
            InfoRow(label: '校区', value: a.campusName),
            if (detail.firstEval != null) ...<Widget>[
              InfoRow(label: '姓名', value: detail.firstEval!.name),
              InfoRow(label: '性别', value: detail.firstEval!.gender),
              InfoRow(label: '临床诊断', value: detail.firstEval!.clinicalDiagnosis),
              InfoRow(label: '入学日期', value: _fmt(detail.firstEval!.enrollmentDate)),
            ],
          ],
        ),
      ),
    );
  }
}

/// 任务区块（待办提醒）。
class _TaskSection extends StatelessWidget {
  const _TaskSection({required this.tasks, required this.onComplete});
  final List<RehabTask> tasks;
  final ValueChanged<String> onComplete;

  @override
  Widget build(BuildContext context) {
    final List<RehabTask> open =
        tasks.where((t) => !t.completed).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            AppSectionTitle('待办提醒（${open.length}）',
                action: open.isEmpty
                    ? null
                    : StatusChip('${open.length} 项', tone: const Color(0xFFE2683B))),
            if (tasks.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('暂无提醒'),
              )
            else
              ...tasks.map((t) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      t.completed ? Icons.check_circle : Icons.schedule,
                      color: t.completed ? Colors.green : const Color(0xFFE2683B),
                    ),
                    title: Text(t.title),
                    subtitle: Text(
                        '${t.reminderType} · 截止 ${_fmt(t.dueDate)}'),
                    trailing: t.completed
                        ? null
                        : TextButton(
                            onPressed: () => onComplete(t.id),
                            child: const Text('完成'),
                          ),
                  )),
          ],
        ),
      ),
    );
  }
}

/// 入学评估区块（单条）。
class _FirstEvalSection extends StatelessWidget {
  const _FirstEvalSection({required this.firstEval, required this.onEdit});
  final AutismFirstEval? firstEval;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            AppSectionTitle('入学评估 + IEP',
                action: TextButton(
                  onPressed: onEdit,
                  child: Text(firstEval == null ? '填写' : '编辑'),
                )),
            if (firstEval == null)
              const Text('尚未填写入学评估')
            else ...<Widget>[
              InfoRow(label: '姓名', value: firstEval!.name),
              InfoRow(label: '临床诊断', value: firstEval!.clinicalDiagnosis),
              InfoRow(label: '评估日期', value: _fmt(firstEval!.evalDate)),
              InfoRow(label: '评估人', value: firstEval!.evaluatorName),
            ],
          ],
        ),
      ),
    );
  }
}

/// 通用列表区块（持续评估 / 学期计划 / 月计划 / 教案 / 家庭指导 / 效果登记）。
class _ListSection<T> extends StatelessWidget {
  const _ListSection({
    required this.title,
    required this.items,
    required this.emptyHint,
    required this.onAdd,
    required this.itemTitle,
    required this.itemSubtitle,
    required this.onEdit,
    required this.onDelete,
    this.itemTitleOf,
  });

  final String title;
  final List<T> items;
  final String emptyHint;
  final VoidCallback onAdd;
  final String Function(T) itemTitle;
  final String Function(T)? itemTitleOf;
  final String Function(T) itemSubtitle;
  final ValueChanged<T> onEdit;
  final ValueChanged<T> onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            AppSectionTitle(title,
                action: TextButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('新增'),
                )),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(emptyHint),
              )
            else
              ...items.map((e) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(itemTitle(e)),
                    subtitle: Text(itemSubtitle(e).isEmpty
                        ? '点击编辑'
                        : itemSubtitle(e)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        IconButton(
                          icon: const Icon(Icons.edit, size: 20),
                          onPressed: () => onEdit(e),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20),
                          onPressed: () => onDelete(e),
                        ),
                      ],
                    ),
                    onTap: () => onEdit(e),
                  )),
          ],
        ),
      ),
    );
  }
}
