import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:teacher_app/features/rehab/presentation/offline_subitem_parser.dart';
import 'package:teacher_app/features/rehab/provider/rehab_provider.dart';

/// 线下模板报告「康复目标 / 指导说明」小项挑选页（归档轮次）。
///
/// 流程位置：在 OfflineArchiveHome 点「保存为新一轮评估」归档成功后进入。
/// 9 行项目本身全部保留（不可取消），老师逐项勾选康复目标 / 指导说明中
/// 带数字编号的小项，确认后保存选择并跳转轮次报告（后端按所选小项过滤）。
class OfflineGuidanceSelectScreen extends ConsumerStatefulWidget {
  const OfflineGuidanceSelectScreen({
    required this.archiveId,
    required this.roundId,
    super.key,
  });
  final String archiveId;
  final String roundId;

  @override
  ConsumerState<OfflineGuidanceSelectScreen> createState() =>
      _OfflineGuidanceSelectScreenState();
}

class _OfflineGuidanceSelectScreenState
    extends ConsumerState<OfflineGuidanceSelectScreen> {
  List<Map<String, dynamic>> _rows = const <Map<String, dynamic>>[];
  // project -> { 'rehabGoal': Set<int>, 'guidance': Set<int> }
  Map<String, Map<String, Set<int>>> _selected = const <String, Map<String, Set<int>>>{};
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final Map<String, dynamic>? round = await ref
          .read(rehabRepositoryProvider)
          .getOfflineRound(widget.roundId);
      final Map<String, dynamic>? report =
          round == null ? null : round['evalReportT'] as Map<String, dynamic>?;
      final List<dynamic> rawRows = report == null
          ? const <dynamic>[]
          : (report['rows'] is List ? report['rows'] as List : const <dynamic>[]);
      final List<Map<String, dynamic>> list = rawRows
          .whereType<Map<String, dynamic>>()
          .map((r) => <String, dynamic>{
                'project': r['project']?.toString() ?? '',
                'refAge': r['refAge']?.toString() ?? '',
                'rehabGoal': r['rehabGoal']?.toString() ?? '',
                'guidance': r['guidance']?.toString() ?? '',
              })
          .where((r) => r['project'].toString().isNotEmpty)
          .toList();

      // 回显已保存的小项选择；无保存记录则默认全选。
      final Map<String, Map<String, Set<int>>> sel =
          <String, Map<String, Set<int>>>{};
      final Map<String, dynamic>? saved = round == null
          ? null
          : (round['selectedEvalItems'] is Map
              ? round['selectedEvalItems'] as Map<String, dynamic>
              : null);
      for (final Map<String, dynamic> r in list) {
        final String p = r['project'].toString();
        if (saved != null && saved[p] is Map) {
          final Map<String, dynamic> sv = saved[p] as Map<String, dynamic>;
          sel[p] = <String, Set<int>>{
            'rehabGoal': Set<int>.from(_toIntList(sv['rehabGoal'])),
            'guidance': Set<int>.from(_toIntList(sv['guidance'])),
          };
        } else {
          sel[p] = <String, Set<int>>{
            'rehabGoal': Set<int>.from(parseItemIndices(r['rehabGoal'].toString())),
            'guidance': Set<int>.from(parseItemIndices(r['guidance'].toString())),
          };
        }
      }
      _rows = list;
      _selected = sel;
      if (list.isEmpty) {
        _error = '该轮次尚未生成报告，请先完成 A/B 卷答题。';
      }
    } catch (e) {
      _error = '加载失败：$e';
    }
    if (mounted) setState(() => _loading = false);
  }

  List<int> _toIntList(dynamic v) {
    if (v is! List) return <int>[];
    return v.whereType<num>().map((n) => n.toInt()).toList();
  }

  void _toggle(String project, String field, int index, bool? v) {
    setState(() {
      final Set<int> set = _selected[project]![field]!;
      if (v == true) {
        set.add(index);
      } else {
        set.remove(index);
      }
    });
  }

  Map<String, Map<String, List<int>>> _buildPayload() {
    final Map<String, Map<String, List<int>>> out =
        <String, Map<String, List<int>>>{};
    _selected.forEach((String p, Map<String, Set<int>> fields) {
      out[p] = <String, List<int>>{
        'rehabGoal': fields['rehabGoal']!.toList()..sort(),
        'guidance': fields['guidance']!.toList()..sort(),
      };
    });
    return out;
  }

  Future<void> _confirm() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await ref.read(rehabRepositoryProvider).saveOfflineRoundGuidance(
            widget.roundId,
            _buildPayload(),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已保存挑选，正在打开报告…')));
      // 跳转轮次报告页（后端已按所选小项过滤）。
      context.pushReplacement(
          '/rehab/${widget.archiveId}/offline-round/${widget.roundId}?role=TEACHER');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('保存失败：$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('挑选康复目标 / 指导说明'),
        actions: <Widget>[
          if (_saving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(
                  width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            TextButton.icon(
              icon: const Icon(Icons.check),
              label: const Text('确认并出报告'),
              onPressed: _rows.isEmpty ? null : _confirm,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error!,
                        style: const TextStyle(color: Colors.grey)),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: <Widget>[
                    Card(
                      color: colors.primaryContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: <Widget>[
                            Icon(Icons.help_outline,
                                color: colors.onPrimaryContainer),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '9 行项目均会保留。请逐项勾选康复目标 / 指导说明中带编号的小项，'
                                '未勾选的小项不会出现在报告里；全部勾选后点右上角「确认并出报告」。',
                                style: TextStyle(
                                    color: colors.onPrimaryContainer,
                                    fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ..._rows.map((r) => _buildRowCard(context, r)),
                  ],
                ),
    );
  }

  Widget _buildRowCard(BuildContext context, Map<String, dynamic> r) {
    final String project = r['project'].toString();
    final String refAge = r['refAge'].toString();
    final List<String> goalItems = itemTexts(r['rehabGoal'].toString());
    final List<String> guideItems = itemTexts(r['guidance'].toString());
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(project,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 16)),
                ),
                if (refAge.isNotEmpty)
                  Text('参考年龄：$refAge',
                      style:
                          const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 8),
            _buildField(
              context,
              '康复目标',
              goalItems,
              _selected[project]!['rehabGoal']!,
              (i, v) => _toggle(project, 'rehabGoal', i, v),
            ),
            const SizedBox(height: 8),
            _buildField(
              context,
              '指导说明',
              guideItems,
              _selected[project]!['guidance']!,
              (i, v) => _toggle(project, 'guidance', i, v),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(
    BuildContext context,
    String label,
    List<String> items,
    Set<int> selected,
    void Function(int, bool?) onToggle,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label,
            style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary)),
        const SizedBox(height: 4),
        if (items.isEmpty)
          const Padding(
            padding: EdgeInsets.only(left: 8, bottom: 4),
            child: Text('（无内容）',
                style: TextStyle(fontSize: 13, color: Colors.grey)),
          )
        else
          ...items.asMap().entries.map((MapEntry<int, String> e) {
            final int index = e.key;
            return CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
              value: selected.contains(index),
              onChanged: (v) => onToggle(index, v),
              title: Text(e.value, style: const TextStyle(fontSize: 13)),
            );
          }),
      ],
    );
  }
}
