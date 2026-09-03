import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:teacher_app/features/rehab/data/rehab_repository.dart';
import 'package:teacher_app/features/rehab/presentation/offline_subitem_parser.dart';
import 'package:teacher_app/features/rehab/provider/rehab_provider.dart';

/// 评估报告「康复目标 / 指导说明」小项挑选页（归档轮次）。
///
/// 流程位置：在 OfflineArchiveHome 点「保存为新一轮评估」归档成功后进入；
/// PEP-3 则在提交月龄归档后进入（[template] = 'PEP3'）。
/// 9 行项目本身全部保留（不可取消），老师逐项勾选康复目标 / 指导说明中
/// 带数字编号的小项，确认后保存选择并跳转轮次报告（后端按所选小项过滤）。
///
/// 教师版 / 家长版 各自独立挑选、各自独立存储：顶部「教师版 / 家长版」分段切换，
/// 切换时从对应**未过滤**报告（evalReportTRaw / evalReportPRaw）取小项、从对应
/// 已保存选择（selectedEvalItemsT / selectedEvalItemsP）回显，保存也写入对应字段。
class OfflineGuidanceSelectScreen extends ConsumerStatefulWidget {
  const OfflineGuidanceSelectScreen({
    required this.archiveId,
    required this.roundId,
    this.template = 'OFFLINE',
    this.role = 'TEACHER',
    this.returnToReport = false,
    super.key,
  });
  final String archiveId;
  final String roundId;
  /// 'OFFLINE'（线下模板 / C-PEP3）或 'PEP3'（PEP-3 年龄预估模板）。
  final String template;
  /// 进入时默认挑选的版本：TEACHER / PARENT。
  /// 从报告页「重新挑选」进入时带上当前版本，避免家长版报告页跳到教师版挑选。
  final String role;
  /// 为 true 表示是从轮次报告页「重新挑选」进来的：保存后 pop(true) 回报告页
  /// 让它自行刷新；为 false（引导流程）则 pushReplacement 到报告页。
  final bool returnToReport;

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

  /// 当前正在挑选的版本：教师版 TEACHER / 家长版 PARENT。
  late String _role;

  /// 轮次详情原始响应（含 evalReportT / evalReportP / selectedEvalItemsT / P）。
  Map<String, dynamic>? _round;

  @override
  void initState() {
    super.initState();
    _role = widget.role == 'PARENT' ? 'PARENT' : 'TEACHER';
    _load();
  }

  bool get _isPep3 => widget.template == 'PEP3';

  Future<void> _load() async {
    try {
      final RehabRepository repo = ref.read(rehabRepositoryProvider);
      final Map<String, dynamic>? round = _isPep3
          ? await repo.getPep3Round(widget.roundId)
          : await repo.getOfflineRound(widget.roundId);
      _round = round;
      if (round == null) {
        _error = '未找到该评估轮次，请返回重试。';
      } else {
        _deriveFromRound();
      }
    } catch (e) {
      _error = '加载失败：$e';
    }
    if (mounted) setState(() => _loading = false);
  }

  /// 根据当前 [_role] 从 [_round] 重新派生 9 行小项清单与已勾选状态。
  void _deriveFromRound() {
    final Map<String, dynamic>? round = _round;
    if (round == null) return;
    // 必须取未过滤原文（evalReportTRaw / PRaw）：evalReportT/P 已被上次的选择
    // 裁剪过，用它派生小项会导致上次没勾的选项永久消失、无法再勾回。
    // 兼容尚未升级的后端（不返回 Raw 键）：退回已过滤的 evalReportT/P。
    // 此时退化为旧行为（未勾选项不可再勾回，保存也只写教师版列），
    // 但页面不会空白报「尚未生成报告」——避免 APP 比后端先发版时整页不可用。
    final String rawKey = _role == 'TEACHER' ? 'evalReportTRaw' : 'evalReportPRaw';
    final String fallbackKey = _role == 'TEACHER' ? 'evalReportT' : 'evalReportP';
    final String selKey = _role == 'TEACHER' ? 'selectedEvalItemsT' : 'selectedEvalItemsP';
    final Map<String, dynamic>? report = round[rawKey] is Map
        ? round[rawKey] as Map<String, dynamic>
        : (round[fallbackKey] is Map
            ? round[fallbackKey] as Map<String, dynamic>
            : null);
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
    final Map<String, dynamic>? saved = round[selKey] is Map
        ? round[selKey] as Map<String, dynamic>
        // 老后端只有 selectedEvalItems 这个别名（等同教师版），没有 T/P 拆分键。
        : (_role == 'TEACHER' && round['selectedEvalItems'] is Map
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
    _error = list.isEmpty
        ? (_isPep3
            ? '该轮次尚未生成报告，请先填写各领域预估年龄。'
            : '该轮次尚未生成报告，请先完成 A/B 卷答题。')
        : null;
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
      final RehabRepository repo = ref.read(rehabRepositoryProvider);
      if (_isPep3) {
        await repo.savePep3RoundGuidance(widget.roundId, _buildPayload(),
            role: _role);
      } else {
        await repo.saveOfflineRoundGuidance(widget.roundId, _buildPayload(),
            role: _role);
      }
      if (!mounted) return;
      if (widget.returnToReport) {
        // 从报告页「重新挑选」进来的：pop 回那一页，由它自己重新拉取
        // （若用 pushReplacement 会新压一页报告，返回键退到下面那页时数据已过期）。
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('已保存挑选')));
        context.pop(true);
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已保存挑选，正在打开报告…')));
      // 跳转轮次报告页（后端已按所选小项过滤，并带对应版本角色）。
      context.pushReplacement(
        '/rehab/${widget.archiveId}/'
        '${_isPep3 ? 'pep3-round' : 'offline-round'}/${widget.roundId}?role=$_role',
      );
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
                    _buildRoleSwitch(colors),
                    const SizedBox(height: 4),
                    ..._rows.map((r) => _buildRowCard(context, r)),
                  ],
                ),
    );
  }

  /// 教师版 / 家长版 分段切换：切换即按对应版本重新派生小项与已选状态。
  Widget _buildRoleSwitch(ColorScheme colors) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: <Widget>[
            Icon(Icons.swap_horiz, color: colors.primary, size: 18),
            const SizedBox(width: 8),
            const Text('报告版本', style: TextStyle(fontSize: 13)),
            const Spacer(),
            SegmentedButton<String>(
              selected: <String>{_role},
              onSelectionChanged: (Set<String> s) {
                if (s.first == _role) return;
                setState(() {
                  _role = s.first;
                  _deriveFromRound();
                });
              },
              segments: const <ButtonSegment<String>>[
                ButtonSegment<String>(value: 'TEACHER', label: Text('教师版')),
                ButtonSegment<String>(value: 'PARENT', label: Text('家长版')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 单个领域卡片：可折叠（ExpansionTile），展开后显示康复目标 / 指导说明的小项勾选。
  Widget _buildRowCard(BuildContext context, Map<String, dynamic> r) {
    final String project = r['project'].toString();
    final String refAge = r['refAge'].toString();
    final List<String> goalItems = itemTexts(r['rehabGoal'].toString());
    final List<String> guideItems = itemTexts(r['guidance'].toString());
    return ExpansionTile(
      initiallyExpanded: true,
      tilePadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      title: Row(
        children: <Widget>[
          Expanded(
            child: Text(project,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 16)),
          ),
          if (refAge.isNotEmpty)
            Text('参考年龄：$refAge',
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
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
      ],
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
