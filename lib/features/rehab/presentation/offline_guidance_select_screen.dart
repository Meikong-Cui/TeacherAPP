import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:teacher_app/features/rehab/provider/rehab_provider.dart';

/// 线下模板报告「康复目标 / 指导说明」挑选页。
///
/// 流程位置：在 OfflineArchiveHome 点「保存为新一轮评估」归档成功后进入。
/// 页面把该轮 9 行报告的康复目标 + 指导说明逐行列为可勾选选项，
/// 老师勾选需要纳入报告（教师版 / 家长版均按行过滤）的行，确认后保存选择并跳转轮次报告。
///
/// 默认全选（保持原有报告不变）；老师取消勾选即把对应行从报告中剔除。
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
  final Set<String> _selected = <String>{};
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
      final List<dynamic> rawRows =
          report == null ? const <dynamic>[] : (report['rows'] is List ? report['rows'] as List : const <dynamic>[]);
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
      _rows = list;
      // 已有选择则按后端回显，否则默认全选。
      final List<dynamic>? saved = round == null
          ? null
          : (round['selectedEvalRows'] is List
              ? round['selectedEvalRows'] as List
              : null);
      if (saved != null && saved.isNotEmpty) {
        _selected.addAll(saved.map((e) => e.toString()));
      } else {
        _selected.addAll(list.map((r) => r['project'].toString()));
      }
      if (list.isEmpty) _error = '该轮次尚未生成报告，请先完成 A/B 卷答题。';
    } catch (e) {
      _error = '加载失败：$e';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _confirm() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await ref.read(rehabRepositoryProvider).saveOfflineRoundGuidance(
            widget.roundId,
            _selected.toList(),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已保存挑选项，正在打开报告…')));
      // 跳转轮次报告页（后端已按选择过滤行）。
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
              label: const Text('确认'),
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
                                '勾选需要纳入报告的行；未勾选的康复目标 / 指导说明不会出现在报告里。'
                                '教师版与家长版报告均按所选行过滤。',
                                style: TextStyle(
                                    color: colors.onPrimaryContainer, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: <Widget>[
                        TextButton(
                          onPressed: () => setState(() =>
                              _selected.addAll(_rows.map((r) => r['project'].toString()))),
                          child: const Text('全选'),
                        ),
                        TextButton(
                          onPressed: () => setState(() => _selected.clear()),
                          child: const Text('清空'),
                        ),
                        const Spacer(),
                        Text('已选 ${_selected.length} / ${_rows.length} 行',
                            style: const TextStyle(color: Colors.grey)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ..._rows.map((r) {
                      final String project = r['project'].toString();
                      final bool checked = _selected.contains(project);
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: CheckboxListTile(
                          value: checked,
                          onChanged: (v) => setState(() {
                            if (v == true) {
                              _selected.add(project);
                            } else {
                              _selected.remove(project);
                            }
                          }),
                          title: Text(project,
                              style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              if (r['refAge'].toString().isNotEmpty)
                                Text('参考年龄：${r['refAge']}',
                                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
                              const SizedBox(height: 4),
                              Text('康复目标：${r['rehabGoal']}',
                                  style: const TextStyle(fontSize: 13)),
                              const SizedBox(height: 2),
                              Text('指导说明：${r['guidance']}',
                                  style: const TextStyle(fontSize: 13)),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
    );
  }
}
