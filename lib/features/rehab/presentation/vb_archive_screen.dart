import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:teacher_app/data/models/autism_eval_item.dart';
import 'package:teacher_app/features/rehab/data/rehab_repository.dart';
import 'package:teacher_app/features/rehab/presentation/widgets/autism_line_chart.dart';
import 'package:teacher_app/features/rehab/provider/autism_eval_provider.dart';
import 'package:teacher_app/features/rehab/provider/rehab_provider.dart';

/// VB（Vanderbilt）首页：家长卷 / 教师卷 两套。
/// 顶部「新建评估 / 查看历史评估」分段：新建用于作答，历史列出所有轮次并可回看得分与报告。
const List<(String, String)> _vbForms = <(String, String)>[
  ('VB_PARENT', '家长卷'),
  ('VB_TEACHER', '教师卷'),
];

class VbArchiveHome extends ConsumerStatefulWidget {
  const VbArchiveHome({required this.archiveId, super.key});
  final String archiveId;

  @override
  ConsumerState<VbArchiveHome> createState() => _VbArchiveHomeState();
}

class _VbArchiveHomeState extends ConsumerState<VbArchiveHome> {
  bool _history = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('VB（Vanderbilt 评估）')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          SegmentedButton<bool>(
            segments: const <ButtonSegment<bool>>[
              ButtonSegment(value: false, label: Text('新建评估')),
              ButtonSegment(value: true, label: Text('查看历史评估')),
            ],
            selected: <bool>{_history},
            onSelectionChanged: (s) => setState(() => _history = s.first),
          ),
          const SizedBox(height: 12),
          if (!_history)
            for (final (String code, String label) in _vbForms)
              Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(label,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.edit),
                              label: const Text('作答'),
                              onPressed: () => context.push(
                                '/rehab-autism/${widget.archiveId}/items?form=$code',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.show_chart),
                              label: const Text('查看趋势'),
                              onPressed: () => context.push(
                                '/rehab-autism/${widget.archiveId}/vb-trend?form=$code',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.assessment),
                          label: const Text('评测详情'),
                          onPressed: () => context.push(
                            '/rehab-autism/${widget.archiveId}/vb-detail?form=$code&label=${Uri.encodeQueryComponent(label)}',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
          else
            VbHistoryList(archiveId: widget.archiveId),
        ],
      ),
    );
  }
}

/// VB 历史评估列表：按卷列出所有轮次，点击任一轮次进入「评测详情」（得分表 + 报告）。
class VbHistoryList extends ConsumerStatefulWidget {
  const VbHistoryList({required this.archiveId, super.key});
  final String archiveId;

  @override
  ConsumerState<VbHistoryList> createState() => _VbHistoryListState();
}

class _VbHistoryListState extends ConsumerState<VbHistoryList> {
  bool _loading = true;
  String? _error;
  final Map<String, List<AutismEvalRound>> _byForm =
      <String, List<AutismEvalRound>>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final RehabRepository repo = ref.read(rehabRepositoryProvider);
      final Map<String, List<AutismEvalRound>> map =
          <String, List<AutismEvalRound>>{};
      for (final (String code, String label) in _vbForms) {
        map[code] = await repo.listEvalRounds(widget.archiveId, code);
      }
      if (!mounted) return;
      _byForm
        ..clear()
        ..addAll(map);
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('加载失败：$_error', style: const TextStyle(color: Colors.grey)),
        ),
      );
    }
    final bool any = _byForm.values.any((l) => l.isNotEmpty);
    if (!any) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text('尚无评估记录，请先在「新建评估」中作答。',
            style: TextStyle(color: Colors.grey)),
      );
    }
    final List<Widget> cards = <Widget>[];
    for (final (String code, String label) in _vbForms) {
      final List<AutismEvalRound> rounds = _byForm[code] ?? const <AutismEvalRound>[];
      if (rounds.isEmpty) continue;
      cards.add(Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(label,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              ...rounds.map((AutismEvalRound r) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('第${r.evalSeq ?? '?'}次'
                        '${r.evalDate != null ? '（${r.evalDate}）' : ''}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(
                      '/rehab-autism/${widget.archiveId}/vb-detail'
                      '?form=$code&label=${Uri.encodeQueryComponent(label)}'
                      '&round=${r.id}',
                    ),
                  )),
            ],
          ),
        ),
      ));
    }
    return Column(children: cards);
  }
}

/// VB 多次评估趋势页：按维度绘制得分折线，直观看到分数变化。
class VbTrendScreen extends ConsumerStatefulWidget {
  const VbTrendScreen(
      {required this.archiveId, this.formCode = 'VB_PARENT', super.key});
  final String archiveId;
  final String formCode;

  @override
  ConsumerState<VbTrendScreen> createState() => _VbTrendScreenState();
}

class _VbTrendScreenState extends ConsumerState<VbTrendScreen> {
  late String _formCode;

  @override
  void initState() {
    super.initState();
    _formCode = widget.formCode;
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<Map<String, dynamic>> trend =
        ref.watch(vbTrendProvider('${widget.archiveId}|$_formCode'));

    return Scaffold(
      appBar: AppBar(
        title: const Text('VB 评估趋势'),
        actions: <Widget>[
          SegmentedButton<String>(
            segments: const <ButtonSegment<String>>[
              ButtonSegment(value: 'VB_PARENT', label: Text('家长卷')),
              ButtonSegment(value: 'VB_TEACHER', label: Text('教师卷')),
            ],
            selected: <String>{_formCode},
            onSelectionChanged: (s) => setState(() => _formCode = s.first),
          ),
        ],
      ),
      body: trend.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载趋势失败：$e')),
        data: (data) {
          final List<dynamic> rounds =
              data['rounds'] is List ? data['rounds'] as List : const <dynamic>[];
          final List<dynamic> sections = data['sections'] is List
              ? data['sections'] as List
              : const <dynamic>[];
          if (rounds.isEmpty) {
            return const Center(child: Text('暂无评估记录'));
          }
          final List<String> xLabels = rounds.map((r) {
            final String seq =
                r is Map ? (r['evalSeq']?.toString() ?? '?') : '?';
            return '第$seq次';
          }).toList();

          final List<Widget> cards = <Widget>[];
          if (sections.isEmpty) {
            cards.add(const Padding(
              padding: EdgeInsets.all(24),
              child: Text('该表单暂无维度得分，请先完成至少一次评估。'),
            ));
          }
          int ci = 0;
          for (final dynamic s in sections) {
            if (s is! Map<String, dynamic>) continue;
            final String name = s['sectionName']?.toString() ??
                s['sectionKey']?.toString() ??
                '';
            final String scoreType = s['scoreType']?.toString() ?? '';
            final List<dynamic> points =
                s['points'] is List ? s['points'] as List : const <dynamic>[];
            final bool positive = points.whereType<Map<String, dynamic>>().isNotEmpty &&
                points.whereType<Map<String, dynamic>>().last['positive'] == 1;
            final List<num> values = rounds.map((r) {
              final dynamic rid = r is Map ? r['roundId'] : null;
              final Map<String, dynamic> hit = points
                  .whereType<Map<String, dynamic>>()
                  .firstWhere((p) => p['roundId'] == rid,
                      orElse: () => const <String, dynamic>{});
              final dynamic v = hit['sumScore'];
              return v is num ? v : 0;
            }).toList();
            final Color color = _palette(ci++);
            cards.add(Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700)),
                        ),
                        if (scoreType == 'SYMPTOM')
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: positive
                                  ? Colors.red.shade50
                                  : Colors.green.shade50,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              positive ? '筛查阳性' : '未达阳性',
                              style: TextStyle(
                                fontSize: 12,
                                color: positive
                                    ? Colors.red
                                    : Colors.green.shade700,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    AutismLineChart(
                      xLabels: xLabels,
                      series: <AutismLineSeries>[
                        AutismLineSeries(label: name, color: color, values: values),
                      ],
                    ),
                    if (rounds.length < 2)
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text(
                          '提示：至少完成两次评估才能看到分数变化趋势。',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ),
                  ],
                ),
              ),
            ));
          }
          return ListView(padding: const EdgeInsets.all(12), children: cards);
        },
      ),
    );
  }

  Color _palette(int i) {
    const List<Color> colors = <Color>[
      Colors.blue,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
      Colors.brown,
      Colors.cyan,
    ];
    return colors[i % colors.length];
  }
}
