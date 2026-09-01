import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:teacher_app/data/models/autism_eval_item.dart';
import 'package:teacher_app/features/rehab/provider/autism_eval_provider.dart';
import 'package:teacher_app/features/rehab/provider/rehab_provider.dart';

/// 评估历史独立页（孤独症档案专用）。
/// 从儿童中枢页「评估历史」卡片进入，展示 VB 教师卷 / VB 家长卷 / 线下模板 OFFLINE 三类记录。
/// - VB 行：查看 → 编辑器；趋势 → 多维折线（后端无单轮 PDF，故只接趋势能力）。
/// - OFFLINE：按「评估轮次」逐次展示（每次归档为一份不可变记录），可查看/导出 PDF。
class EvalHistoryScreen extends ConsumerWidget {
  const EvalHistoryScreen({required this.archiveId, super.key});
  final String archiveId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('评估历史')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          _EvalHistoryBody(archiveId: archiveId),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

/// 评估历史内容（三类记录的卡片集合）。
class _EvalHistoryBody extends StatelessWidget {
  const _EvalHistoryBody({required this.archiveId});
  final String archiveId;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _VbHistoryBlock(
            archiveId: archiveId,
            formCode: 'VB_PARENT',
            label: 'VB 家长卷'),
        const SizedBox(height: 12),
        _VbHistoryBlock(
            archiveId: archiveId,
            formCode: 'VB_TEACHER',
            label: 'VB 教师卷'),
        const SizedBox(height: 12),
        _OfflineRoundsBlock(archiveId: archiveId),
      ],
    );
  }
}

/// VB 教师/家长卷 历次评估列表。
class _VbHistoryBlock extends ConsumerWidget {
  const _VbHistoryBlock({
    required this.archiveId,
    required this.formCode,
    required this.label,
  });
  final String archiveId;
  final String formCode;
  final String label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<AutismEvalRound>> rounds =
        ref.watch(evalRoundsProvider('$archiveId|$formCode'));
    final TextTheme text = Theme.of(context).textTheme;
    final ColorScheme colors = Theme.of(context).colorScheme;
    final DateFormat fmt = DateFormat('yyyy-MM-dd');

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(label,
                      style: text.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                ),
                TextButton.icon(
                  onPressed: () => context.push(
                      '/rehab-autism/$archiveId/vb-trend?form=$formCode'),
                  icon: const Icon(Icons.show_chart, size: 18),
                  label: const Text('趋势'),
                ),
              ],
            ),
            rounds.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(minHeight: 2),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('加载失败：$e',
                    style: text.bodySmall?.copyWith(color: colors.error)),
              ),
              data: (list) {
                final List<AutismEvalRound> sorted = list.toList()
                  ..sort((a, b) {
                    final DateTime? ad = a.evalDate;
                    final DateTime? bd = b.evalDate;
                    if (ad == null && bd == null) return 0;
                    if (ad == null) return 1;
                    if (bd == null) return -1;
                    return bd.compareTo(ad);
                  });
                if (sorted.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text('尚无评估记录',
                        style: text.bodySmall
                            ?.copyWith(color: colors.onSurfaceVariant)),
                  );
                }
                return Column(
                  children: sorted
                      .take(5)
                      .map((r) => _VbRoundRow(
                            round: r,
                            fmt: fmt,
                            archiveId: archiveId,
                            formCode: formCode,
                          ))
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// VB 单轮（一次评估）。
class _VbRoundRow extends StatelessWidget {
  const _VbRoundRow({
    required this.round,
    required this.fmt,
    required this.archiveId,
    required this.formCode,
  });
  final AutismEvalRound round;
  final DateFormat fmt;
  final String archiveId;
  final String formCode;

  @override
  Widget build(BuildContext context) {
    final String seq = round.evalSeq != null ? '第${round.evalSeq}次' : '评估';
    final String? date = round.evalDate == null ? null : fmt.format(round.evalDate!);
    final String? evaluator = round.evaluatorName;
    final String subtitleParts = <String>[
      if (date != null) date,
      if (evaluator != null && evaluator.isNotEmpty) evaluator,
    ].join(' · ');
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: const Icon(Icons.history),
      title: Text(seq),
      subtitle: Text(
        subtitleParts.isEmpty ? '点击查看评估详情' : subtitleParts,
      ),
      trailing: TextButton.icon(
        onPressed: () => context.push(
            '/rehab-autism/$archiveId/vb-trend?form=$formCode'),
        icon: const Icon(Icons.show_chart, size: 18),
        label: const Text('趋势'),
      ),
      onTap: () => context.push('/rehab-autism/$archiveId/vb-home'),
    );
  }
}

/// 线下模板评估轮次列表（每次「保存为新一轮评估」归档为一份不可变记录）。
/// 每行可查看教师版/家长版报告，或导出对应 PDF。
class _OfflineRoundsBlock extends ConsumerStatefulWidget {
  const _OfflineRoundsBlock({required this.archiveId, super.key});
  final String archiveId;

  @override
  ConsumerState<_OfflineRoundsBlock> createState() => _OfflineRoundsBlockState();
}

class _OfflineRoundsBlockState extends ConsumerState<_OfflineRoundsBlock> {
  List<Map<String, dynamic>> _rounds = const <Map<String, dynamic>>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _rounds = await ref
          .read(rehabRepositoryProvider)
          .listOfflineRounds(widget.archiveId);
    } catch (_) {
      // 忽略异常，展示空态。
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('C-PEP3（多次记录）',
                style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(minHeight: 2),
              )
            else if (_rounds.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  '尚无归档记录，到「C-PEP3」页点「保存为新一轮评估」生成。',
                  style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant),
                ),
              )
            else
              Column(
                children: _rounds.map((r) {
                  final String rid = r['id']?.toString() ?? '';
                  final int seq = r['evalSeq'] is int ? r['evalSeq'] as int : 0;
                  final String date = r['evalDate']?.toString() ?? '';
                  final bool hasP = r['hasReportP'] == true;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.history),
                    title: Text('第 $seq 次'),
                    subtitle: Text(date.length >= 10 ? date.substring(0, 10) : '点击查看'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        TextButton(
                          onPressed: () => context.push(
                              '/rehab/${widget.archiveId}/offline-round/$rid?role=TEACHER'),
                          child: const Text('教师版'),
                        ),
                        TextButton(
                          onPressed: hasP
                              ? () => context.push(
                                  '/rehab/${widget.archiveId}/offline-round/$rid?role=PARENT')
                              : null,
                          child: const Text('家长版'),
                        ),
                        IconButton(
                          tooltip: '查看第三份报告（发展总览）',
                          iconSize: 20,
                          onPressed: () => context.push(
                              '/rehab/${widget.archiveId}/offline-overview?roundId=$rid'),
                          icon: const Icon(Icons.insights, color: Colors.deepPurple),
                        ),
                      ],
                    ),
                    onTap: () => context.push(
                        '/rehab/${widget.archiveId}/offline-answer/$rid?paper=A'),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }
}
