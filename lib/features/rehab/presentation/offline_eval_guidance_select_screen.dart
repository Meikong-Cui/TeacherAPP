import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:teacher_app/features/rehab/presentation/offline_subitem_parser.dart';
import 'package:teacher_app/features/rehab/provider/rehab_provider.dart';
import 'package:teacher_app/data/models/autism_archive.dart';

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
  Map<String, Map<String, Set<int>>> _selected =
      const <String, Map<String, Set<int>>>{};
  bool _loading = true;
  String? _error;

  // 顶部儿童信息栏数据（获取失败不影响选择流程）。
  String _childName = '';
  String _childGender = '';
  String _childAge = '';
  String _childStatus = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// 由出生日期算出「X 岁 Y 个月」文案。
  String _ageLabel(DateTime? b) {
    if (b == null) return '';
    final DateTime now = DateTime.now();
    int months = (now.year - b.year) * 12 + now.month - b.month;
    if (now.day < b.day) months--;
    if (months < 0) return '';
    final int y = months ~/ 12;
    final int m = months % 12;
    if (y <= 0) return '$m 个月';
    return '$y 岁${m > 0 ? ' $m 个月' : ''}';
  }

  Future<void> _load() async {
    try {
      final repo = ref.read(rehabRepositoryProvider);
      final Map<String, dynamic> report =
          await repo.getOfflineEvalReport(widget.archiveId, 'TEACHER');

      // 儿童信息（非关键，失败不影响选择）。
      try {
        final AutismArchiveDetail detail =
            await repo.getAutismArchive(widget.archiveId);
        _childName = detail.archive.childName;
        _childStatus = detail.archive.status.label;
        final fe = detail.firstEval;
        if (fe != null) {
          _childGender = fe.gender;
          _childAge = _ageLabel(fe.birthDate);
        }
      } catch (_) {
        // 忽略儿童信息获取异常。
      }

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
          'rehabGoal':
              Set<int>.from(parseItemIndices(r['rehabGoal'].toString())),
          'guidance':
              Set<int>.from(parseItemIndices(r['guidance'].toString())),
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

  /// 全选 / 取消全选某一分组的全部小项。
  void _toggleAll(String project, String field, List<String> items) {
    setState(() {
      final Set<int> set = _selected[project]![field]!;
      if (set.length == items.length) {
        set.clear();
      } else {
        set
          ..clear()
          ..addAll(List<int>.generate(items.length, (i) => i));
      }
    });
  }

  /// 当前已勾选的小项总数（康复目标 + 指导说明，跨全部 9 行）。
  int get _selectedCount {
    int n = 0;
    for (final Map<String, Set<int>> fields in _selected.values) {
      n += fields['rehabGoal']!.length + fields['guidance']!.length;
    }
    return n;
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
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(
              child: Text('已选 $_selectedCount 项',
                  style: const TextStyle(fontSize: 13)),
            ),
          ),
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
                    _buildChildInfoBar(context),
                    const SizedBox(height: 12),
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

  /// 顶部儿童信息栏：姓名 · 性别 · 月龄，右侧显示档案状态标签。
  Widget _buildChildInfoBar(BuildContext context) {
    final List<String> parts = <String>[
      if (_childName.isNotEmpty) _childName,
      if (_childGender.isNotEmpty) _childGender,
      if (_childAge.isNotEmpty) _childAge,
    ];
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: <Widget>[
            const Icon(Icons.child_care, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: parts.isEmpty
                  ? const Text('儿童信息', style: TextStyle(color: Colors.grey))
                  : Text(
                      parts.join('  ·  '),
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14),
                    ),
            ),
            if (_childStatus.isNotEmpty)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: colors.secondaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(_childStatus,
                    style: TextStyle(
                        fontSize: 12, color: colors.onSecondaryContainer)),
              ),
          ],
        ),
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
              project,
              '康复目标',
              'rehabGoal',
              goalItems,
              _selected[project]!['rehabGoal']!,
              (i, v) => _toggle(project, 'rehabGoal', i, v),
            ),
            const SizedBox(height: 8),
            _buildField(
              context,
              project,
              '指导说明',
              'guidance',
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
    String project,
    String label,
    String field,
    List<String> items,
    Set<int> selected,
    void Function(int, bool?) onToggle,
  ) {
    // 全选复选框三态：全选=true，无选中=false，部分选中=null（中间态）。
    bool? allChecked;
    if (items.isEmpty) {
      allChecked = false;
    } else if (selected.length == items.length) {
      allChecked = true;
    } else if (selected.isEmpty) {
      allChecked = false;
    } else {
      allChecked = null;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: <Widget>[
              Text(label,
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary)),
              const Spacer(),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Checkbox(
                    value: allChecked,
                    tristate: true,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    onChanged: items.isEmpty
                        ? null
                        : (_) => _toggleAll(project, field, items),
                  ),
                  const Text('全选', style: TextStyle(fontSize: 13)),
                  const SizedBox(width: 4),
                ],
              ),
            ],
          ),
        ),
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
