import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:teacher_app/features/rehab/presentation/offline_subitem_parser.dart';
import 'package:teacher_app/features/rehab/provider/rehab_provider.dart';

/// 当前线下模板评估报告（非归档轮次）的「康复目标 / 指导说明」小项挑选页。
///
/// 流程：从 OfflineArchiveHome 的「教师版 / 家长版评估报告」卡片进入。
/// 9 行项目本身全部保留（不可取消），老师逐项勾选康复目标 / 指导说明中
/// 带数字编号的小项（未勾选的小项不会出现在报告里），确认后跳转到评估报告。
class OfflineEvalGuidanceSelectScreen extends ConsumerStatefulWidget {
  const OfflineEvalGuidanceSelectScreen({
    required this.archiveId,
    required this.role,
    required this.title,
    super.key,
  });
  final String archiveId;
  final String role;
  final String title;

  @override
  ConsumerState<OfflineEvalGuidanceSelectScreen> createState() =>
      _OfflineEvalGuidanceSelectScreenState();
}

class _OfflineEvalGuidanceSelectScreenState
    extends ConsumerState<OfflineEvalGuidanceSelectScreen> {
  List<Map<String, dynamic>> _rows = const <Map<String, dynamic>>[];
  // project -> { 'rehabGoal': Set<int>, 'guidance': Set<int> }
  Map<String, Map<String, Set<int>>> _selected = const <String, Map<String, Set<int>>>{};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      // 教师版与家长版项目相同，挑选统一以教师版为准。
      final Map<String, dynamic> report = await ref
          .read(rehabRepositoryProvider)
          .getOfflineEvalReport(widget.archiveId, 'TEACHER');
      final List<dynamic> rawRows =
          report['rows'] is List ? report['rows'] as List : const <dynamic>[];
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
      final Map<String, Map<String, Set<int>>> sel =
          <String, Map<String, Set<int>>>{};
      for (final Map<String, dynamic> r in list) {
        final String p = r['project'].toString();
        sel[p] = <String, Set<int>>{
          'rehabGoal': Set<int>.from(parseItemIndices(r['rehabGoal'].toString())),
          'guidance': Set<int>.from(parseItemIndices(r['guidance'].toString())),
        };
      }
      _rows = list;
      _selected = sel;
      if (_rows.isEmpty) {
        _error = '暂无报告内容，请先完成 A/B 卷答题并保存评估结果。';
      }
    } catch (e) {
      _error = '加载失败：$e';
    }
    if (mounted) setState(() => _loading = false);
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

  void _confirm() {
    final String itemsParam = encodeSelectedItems(_buildPayload());
    context.pushReplacement(
      '/rehab/${widget.archiveId}/offline-eval-report'
      '?type=${Uri.encodeQueryComponent(widget.role)}'
      '&title=${Uri.encodeQueryComponent(widget.title)}'
      '&items=$itemsParam',
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('挑选康复目标 / 指导说明'),
        actions: <Widget>[
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
