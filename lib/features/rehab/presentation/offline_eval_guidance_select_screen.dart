import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:teacher_app/features/rehab/provider/rehab_provider.dart';

/// 当前线下模板评估报告（非归档轮次）的「康复目标 / 指导说明」挑选页。
///
/// 流程：从 OfflineArchiveHome 的「教师版 / 家长版评估报告」卡片进入，
/// 老师勾选需要纳入报告的 9 行项目后，确认跳转到评估报告页（按所选行过滤展示）。
/// 当前报告为可编辑草稿，挑选结果本次会话生效；如需持久化过滤，请使用「保存为新一轮评估」。
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
  final Set<String> _selected = <String>{};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      // 教师版与家长版目前项目相同，挑选统一以教师版为准。
      final Map<String, dynamic> report = await ref
          .read(rehabRepositoryProvider)
          .getOfflineEvalReport(widget.archiveId, 'TEACHER');
      final List<dynamic> rawRows =
          report['rows'] is List ? report['rows'] as List : const <dynamic>[];
      _rows = rawRows
          .whereType<Map<String, dynamic>>()
          .map((r) => <String, dynamic>{
                'project': r['project']?.toString() ?? '',
                'refAge': r['refAge']?.toString() ?? '',
                'rehabGoal': r['rehabGoal']?.toString() ?? '',
                'guidance': r['guidance']?.toString() ?? '',
              })
          .where((r) => r['project'].toString().isNotEmpty)
          .toList();
      _selected.addAll(_rows.map((r) => r['project'].toString()));
      if (_rows.isEmpty) _error = '暂无报告内容，请先完成 A/B 卷答题并保存评估结果。';
    } catch (e) {
      _error = '加载失败：$e';
    }
    if (mounted) setState(() => _loading = false);
  }

  void _confirm() {
    if (_selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请至少选择一行')));
      return;
    }
    final String selectedParam = _selected
        .map(Uri.encodeQueryComponent)
        .join(',');
    context.pushReplacement(
      '/rehab/${widget.archiveId}/offline-eval-report'
      '?type=${Uri.encodeQueryComponent(widget.role)}'
      '&title=${Uri.encodeQueryComponent(widget.title)}'
      '&rows=$selectedParam',
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
                                '请勾选需要纳入「${widget.title}」的康复目标 / 指导说明项目；'
                                '未勾选的内容不会出现在报告展示中。',
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
                    Row(
                      children: <Widget>[
                        TextButton(
                          onPressed: () => setState(() => _selected.addAll(
                              _rows.map((r) => r['project'].toString()))),
                          child: const Text('全选'),
                        ),
                        TextButton(
                          onPressed: () => setState(() => _selected.clear()),
                          child: const Text('清空'),
                        ),
                        const Spacer(),
                        Text('已选 ${_selected.length} / ${_rows.length} 项',
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
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              if (r['refAge'].toString().isNotEmpty)
                                Text('参考年龄：${r['refAge']}',
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.grey)),
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
