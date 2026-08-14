import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:teacher_app/data/models/iep_plan.dart';
import 'package:teacher_app/features/rehab/provider/iep_provider.dart';

/// 个别化教育计划 (IEP) 屏幕：与「月教学计划」独立。
///
/// - 空态：居中展示「AI 生成」「添加项目」两个按钮。
/// - 非空态：顶部元信息卡（可编辑 + 保存）、阶段统计、按领域分组的表格、
///   仅保留「添加项目」按钮（不再显示 AI 生成）、以及导出 PDF / 保存。
class IepScreen extends ConsumerStatefulWidget {
  const IepScreen({required this.archiveId, super.key});
  final String archiveId;

  @override
  ConsumerState<IepScreen> createState() => _IepScreenState();
}

class _IepScreenState extends ConsumerState<IepScreen> {
  final TextEditingController _plannerCtl = TextEditingController();
  String _ageBand = '';
  DateTime? _start;
  DateTime? _end;
  bool _metaInit = false;

  @override
  void dispose() {
    _plannerCtl.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final IepPlanState st = ref.watch(iepPlanProvider(widget.archiveId));
    if (!_metaInit && st.plan != null) {
      _metaInit = true;
      _plannerCtl.text = st.plan!.planner;
      _ageBand = st.plan!.ageBand.isNotEmpty
          ? st.plan!.ageBand
          : (st.ageBands.isNotEmpty ? st.ageBands.first : '');
      _start = _parse(st.plan!.startDate);
      _end = _parse(st.plan!.endDate);
    }
  }

  DateTime? _parse(String? s) {
    if (s == null || s.isEmpty) return null;
    try {
      return DateFormat('yyyy-MM-dd').parse(s);
    } catch (_) {
      return null;
    }
  }

  String _fmt(DateTime? d) =>
      d == null ? '' : DateFormat('yyyy-MM-dd').format(d);

  @override
  Widget build(BuildContext context) {
    final IepPlanState st = ref.watch(iepPlanProvider(widget.archiveId));

    ref.listen<IepPlanState>(iepPlanProvider(widget.archiveId), (prev, next) {
      if (next.message != null && next.message != prev?.message) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(next.message!)));
        ref.read(iepPlanProvider(widget.archiveId).notifier).clearMessage();
      }
      if (next.error != null && next.error != prev?.error) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(next.error!)));
        ref.read(iepPlanProvider(widget.archiveId).notifier).clearError();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text('${st.childName.isEmpty ? '儿童' : st.childName} · IEP'),
        actions: <Widget>[
          if (st.hasGoals) ...<Widget>[
            if (st.exporting)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Center(
                  child:
                      SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                ),
              )
            else
              IconButton(
                icon: const Icon(Icons.picture_as_pdf_outlined),
                tooltip: '导出 PDF',
                onPressed: () =>
                    ref.read(iepPlanProvider(widget.archiveId).notifier).exportPdf(),
              ),
            if (st.saving)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Center(
                  child:
                      SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                ),
              )
            else
              IconButton(
                icon: const Icon(Icons.save_outlined),
                tooltip: '保存',
                onPressed: _saveMeta,
              ),
          ],
        ],
      ),
      body: _buildBody(context, st),
    );
  }

  Widget _buildBody(BuildContext context, IepPlanState st) {
    if (st.loading && st.plan == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!st.hasGoals) {
      return _EmptyState(archiveId: widget.archiveId);
    }
    return _buildContent(context, st);
  }

  Widget _buildContent(BuildContext context, IepPlanState st) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final List<IepPlanGoal> goals = st.goals;
    final int passed = st.phaseCounts['PASSED'] ?? 0;
    final int inProgress = st.phaseCounts['IN_PROGRESS'] ?? 0;
    final int stopped = st.phaseCounts['STOPPED'] ?? 0;
    final int notStarted = st.phaseCounts['NOT_STARTED'] ?? 0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        // 元信息卡（可编辑）
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('计划信息',
                    style: textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                Row(children: <Widget>[
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _ageBand.isNotEmpty ? _ageBand : null,
                      decoration: const InputDecoration(
                        labelText: '年龄段',
                        isDense: true,
                      ),
                      items: (st.ageBands.isNotEmpty ? st.ageBands : kIepAgeBands)
                          .map((ab) => DropdownMenuItem<String>(
                                value: ab,
                                child: Text(ab),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _ageBand = v ?? _ageBand),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _plannerCtl,
                      decoration: const InputDecoration(
                        labelText: '制定人员',
                        isDense: true,
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                Row(children: <Widget>[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickDate(context, true),
                      icon: const Icon(Icons.event_outlined, size: 18),
                      label: Text(_start == null ? '开始日期' : _fmt(_start)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickDate(context, false),
                      icon: const Icon(Icons.event_outlined, size: 18),
                      label: Text(_end == null ? '结束日期' : _fmt(_end)),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        // 阶段统计
        Card(
          color: colors.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('阶段目标：共 ${goals.length} 个',
                    style: textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: <Widget>[
                    _PhaseChip(label: '已通过', count: passed, color: Colors.green),
                    _PhaseChip(label: '干预中', count: inProgress, color: Colors.blue),
                    _PhaseChip(label: '已停止', count: stopped, color: Colors.grey),
                    _PhaseChip(label: '未开始', count: notStarted, color: Colors.orange),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        // 添加项目（非空态只显示此按钮）
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () =>
                context.push('/rehab-autism/${widget.archiveId}/iep/add'),
            icon: const Icon(Icons.add),
            label: const Text('添加项目'),
          ),
        ),
        const SizedBox(height: 12),
        ..._buildTableSection(context, colors, goals),
        const SizedBox(height: 24),
      ],
    );
  }

  List<Widget> _buildTableSection(
      BuildContext context, ColorScheme colors, List<IepPlanGoal> all) {
    final List<Widget> widgets = <Widget>[];
    final Map<String, List<IepPlanGoal>> byDomain =
        <String, List<IepPlanGoal>>{};
    for (final IepPlanGoal g in all) {
      byDomain.putIfAbsent(g.domain, () => <IepPlanGoal>[]).add(g);
    }
    byDomain.forEach((String domain, List<IepPlanGoal> list) {
      widgets.add(Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 6, left: 4),
        child: Text(domain,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w800)),
      ));
      final List<TableRow> rows = <TableRow>[
        TableRow(
          decoration: BoxDecoration(color: colors.surfaceContainerHighest),
          children: const <Widget>[
            Padding(padding: EdgeInsets.all(8), child: Text('子领域', style: TextStyle(fontWeight: FontWeight.w700))),
            Padding(padding: EdgeInsets.all(8), child: Text('干预目标', style: TextStyle(fontWeight: FontWeight.w700))),
            Padding(padding: EdgeInsets.all(8), child: Text('阶段目标', style: TextStyle(fontWeight: FontWeight.w700))),
            Padding(padding: EdgeInsets.all(8), child: Text('状态', style: TextStyle(fontWeight: FontWeight.w700))),
          ],
        ),
      ];
      for (final IepPlanGoal g in list) {
        rows.add(TableRow(children: <Widget>[
          Padding(padding: const EdgeInsets.all(8), child: Text(g.subDomain)),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(children: <Widget>[
              Expanded(child: Text(g.interventionGoal)),
              if (g.aiSuggested) ...<Widget>[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('AI建议',
                      style: TextStyle(
                          color: Color(0xFF1D4ED8),
                          fontSize: 10,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ]),
          ),
          Padding(padding: const EdgeInsets.all(8), child: Text(g.stageGoal)),
          Padding(
            padding: const EdgeInsets.all(6),
            child: Row(children: <Widget>[
              Expanded(
                child: _PhaseDropdown(
                  phase: g.phase,
                  onChanged: (p) => ref
                      .read(iepPlanProvider(widget.archiveId).notifier)
                      .setGoalPhase(g.id, p),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18),
                tooltip: '删除',
                onPressed: () => ref
                    .read(iepPlanProvider(widget.archiveId).notifier)
                    .removeGoal(g.id),
              ),
            ]),
          ),
        ]));
      }
      widgets.add(Card(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 720),
            child: Table(
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              columnWidths: const <int, TableColumnWidth>{
                0: FixedColumnWidth(90),
                1: FlexColumnWidth(2),
                2: FlexColumnWidth(2),
                3: FixedColumnWidth(140),
              },
              children: rows,
            ),
          ),
        ),
      ));
    });
    return widgets;
  }

  Future<void> _pickDate(BuildContext context, bool isStart) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStart ? (_start ?? DateTime.now()) : (_end ?? DateTime.now()),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _start = picked;
        } else {
          _end = picked;
        }
      });
    }
  }

  void _saveMeta() {
    ref.read(iepPlanProvider(widget.archiveId).notifier).saveMeta(
          planner: _plannerCtl.text.trim(),
          ageBand: _ageBand,
          startDate: _fmt(_start),
          endDate: _fmt(_end),
        );
  }
}

/// 空态：两个大按钮。
class _EmptyState extends ConsumerWidget {
  const _EmptyState({required this.archiveId});
  final String archiveId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final bool busy =
        ref.watch(iepPlanProvider(archiveId)).saving;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(Icons.auto_awesome_outlined,
                    size: 56, color: colors.primary),
                const SizedBox(height: 16),
                Text('还没有 IEP 项目',
                    style: textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(
                  '先让 AI 按儿童评测薄弱项智能生成，或手动从模板库中添加 IEP 干预目标。',
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium
                      ?.copyWith(color: colors.onSurfaceVariant),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: busy
                        ? null
                        : () => _showAiDialog(context, ref),
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('AI 生成'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        context.push('/rehab-autism/$archiveId/iep/add'),
                    icon: const Icon(Icons.add),
                    label: const Text('添加项目'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showAiDialog(BuildContext context, WidgetRef ref) async {
    final IepPlanState st = ref.read(iepPlanProvider(archiveId));
    String ab = st.plan?.ageBand.isNotEmpty == true
        ? st.plan!.ageBand
        : (st.ageBands.isNotEmpty ? st.ageBands.first : kIepAgeBands.first);
    final Set<String> weak = <String>{};

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('AI 生成 IEP'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                DropdownButtonFormField<String>(
                  initialValue: ab,
                  decoration: const InputDecoration(labelText: '年龄段', isDense: true),
                  items: (st.ageBands.isNotEmpty ? st.ageBands : kIepAgeBands)
                      .map((d) => DropdownMenuItem<String>(value: d, child: Text(d)))
                      .toList(),
                  onChanged: (v) => setSt(() => ab = v ?? ab),
                ),
                const SizedBox(height: 12),
                const Text('薄弱领域（可多选；留空则每领域默认推荐）',
                    style: TextStyle(fontSize: 13)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: kIepDomains
                      .map((d) => FilterChip(
                            label: Text(d),
                            selected: weak.contains(d),
                            onSelected: (sel) =>
                                setSt(() => sel ? weak.add(d) : weak.remove(d)),
                          ))
                      .toList(),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                ref
                    .read(iepPlanProvider(archiveId).notifier)
                    .aiRecommend(ageBand: ab, weakDomains: weak.toList());
              },
              child: const Text('生成'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhaseChip extends StatelessWidget {
  const _PhaseChip(
      {required this.label, required this.count, required this.color});
  final String label;
  final int count;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text('$label · $count',
          style: TextStyle(color: color, fontWeight: FontWeight.w700)),
    );
  }
}

class _PhaseDropdown extends StatelessWidget {
  const _PhaseDropdown({required this.phase, required this.onChanged});
  final IepPhase phase;
  final ValueChanged<IepPhase> onChanged;
  @override
  Widget build(BuildContext context) {
    return DropdownButton<IepPhase>(
      value: phase,
      isExpanded: true,
      underline: const SizedBox(),
      items: IepPhase.values
          .map((p) => DropdownMenuItem<IepPhase>(
                value: p,
                child: Text(p.label),
              ))
          .toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}
