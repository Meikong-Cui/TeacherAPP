import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teacher_app/data/models/autism_eval_item.dart';
import 'package:teacher_app/features/rehab/data/autism_questions.dart';
import 'package:teacher_app/features/rehab/presentation/widgets/autism_line_chart.dart';
import 'package:teacher_app/features/rehab/presentation/widgets/autism_pie_chart.dart';
import 'package:teacher_app/features/rehab/provider/autism_eval_provider.dart';

/// 评估图表：领域发展剖面图 + 情绪行为表现图（可点选涂黑）+ P 数折线图。
class AutismChartsScreen extends ConsumerStatefulWidget {
  const AutismChartsScreen({required this.archiveId, super.key});
  final String archiveId;

  @override
  ConsumerState<AutismChartsScreen> createState() => _AutismChartsScreenState();
}

const List<Color> _areaPalette = <Color>[
  Color(0xFF5B8FF9),
  Color(0xFF61DDAA),
  Color(0xFF65789B),
  Color(0xFFF6BD16),
  Color(0xFF7262FD),
  Color(0xFF78D3F8),
  Color(0xFF9661BC),
  Color(0xFFF6903D),
];
const List<Color> _emotionPalette = <Color>[
  Color(0xFFE8684A),
  Color(0xFFFF9D4D),
  Color(0xFFF6BD16),
  Color(0xFF5AD8A6),
  Color(0xFF5B8FF9),
  Color(0xFF9270CA),
];

class _AutismChartsScreenState extends ConsumerState<AutismChartsScreen> {
  final Set<int> _areaBlackout = <int>{};
  final Set<int> _emotionBlackout = <int>{};
  final Set<String> _hiddenLines = <String>{};

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref
          .read(autismEvalStatsProvider('${widget.archiveId}|FIRST').notifier)
          .load(),
    );
  }

  /// 数据为空时构造一份「全 0」统计，使图表（剖面图 + 折线图）仍能正常渲染，
  /// 方便在没有录入数据的情况下预览图表版式。
  AutismEvalStats _emptyStats() {
    final List<EvalAreaProfile> p8 = autismQuestionAreas
        .map((a) => EvalAreaProfile(
              areaKey: a.key,
              areaLabel: a.label,
              total: a.items.length,
              pCount: 0,
              pRatio: 0,
            ))
        .toList();
    final Map<String, int> dimCount = <String, int>{};
    for (final AutismQuestionArea a in autismQuestionAreas) {
      if (!autismIsEmotionArea(a.key)) continue;
      for (final AutismQuestion q in a.items) {
        final String d = q.sub ?? '情绪与行为';
        dimCount[d] = (dimCount[d] ?? 0) + 1;
      }
    }
    final List<EvalEmotionProfile> pe = autismEmotionDims
        .map((d) => EvalEmotionProfile(
              dimKey: d,
              dimLabel: d,
              total: dimCount[d] ?? 0,
              pCount: 0,
              pRatio: 0,
            ))
        .toList();
    final List<EvalAreaSeries> as = autismQuestionAreas
        .map((a) => EvalAreaSeries(
              areaKey: a.key,
              areaLabel: a.label,
              points: <EvalAreaPoint>[
                EvalAreaPoint(seq: 1, pCount: 0),
                EvalAreaPoint(seq: 2, pCount: 0),
                EvalAreaPoint(seq: 3, pCount: 0),
              ],
            ))
        .toList();
    return AutismEvalStats(
      items: const <EvalItemSeries>[],
      series: const <EvalItemSeries>[],
      areaSeries: as,
      profile8: p8,
      profileEmotion: pe,
      evalSeqs: const <int>[1, 2, 3],
      maxPSum: 0,
    );
  }

  List<AutismPieSlice> _areaSlices(AutismEvalStats stats) {
    final Map<String, int> paletteIdx = <String, int>{};
    for (int i = 0; i < autismAreaKeys.length; i++) {
      paletteIdx[autismAreaKeys[i]] = i;
    }
    return stats.profile8.map((p) {
      final int idx = paletteIdx[p.areaKey] ?? 0;
      return AutismPieSlice(
        label: p.areaLabel,
        pCount: p.pCount,
        total: p.total,
        color: _areaPalette[idx % _areaPalette.length],
      );
    }).toList();
  }

  List<AutismPieSlice> _emotionSlices(AutismEvalStats stats) {
    return stats.profileEmotion.map((p) {
      final int idx =
          autismEmotionDims.indexOf(p.dimKey).clamp(0, _emotionPalette.length - 1);
      return AutismPieSlice(
        label: p.dimLabel,
        pCount: p.pCount,
        total: p.total,
        color: _emotionPalette[idx],
      );
    }).toList();
  }

  int _areaTotalP(AutismEvalStats stats) =>
      stats.profile8.fold(0, (s, e) => s + e.pCount);

  @override
  Widget build(BuildContext context) {
    final AutismEvalStatsState st =
        ref.watch(autismEvalStatsProvider('${widget.archiveId}|FIRST'));
    final AutismEvalStats? raw = st.stats;
    final bool empty = raw == null || raw.evalSeqs.isEmpty;
    // 数据为空时渲染空白图表（而非仅显示文字），以便预览版式。
    final AutismEvalStats stats = empty ? _emptyStats() : raw;

    ref.listen<AutismEvalStatsState>(
        autismEvalStatsProvider('${widget.archiveId}|FIRST'), (_, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(next.error!)));
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('评估图表')),
      body: st.loading && raw == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(12),
              children: <Widget>[
                if (empty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: const Row(
                      children: <Widget>[
                        Icon(Icons.info_outline, size: 16, color: Colors.amber),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '暂无评估数据，以下为空白图表占位。'
                            '请先在「评估题目录入」中填写题目后保存。',
                            style: TextStyle(fontSize: 12, color: Colors.amber),
                          ),
                        ),
                      ],
                    ),
                  ),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: <Widget>[
                        const Text('领域发展剖面图（首次评估）',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        AutismPieChart(
                          slices: _areaSlices(stats),
                          blackout: _areaBlackout,
                          onTapSlice: (i) => setState(() => _areaBlackout.contains(i)
                              ? _areaBlackout.remove(i)
                              : _areaBlackout.add(i)),
                          centerText: 'P ${_areaTotalP(stats)}',
                        ),
                        const SizedBox(height: 6),
                        const Text('点击扇区可标记为「重点缺陷域」（涂黑）',
                            style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: <Widget>[
                        const Text('情绪与行为表现图',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        AutismPieChart(
                          slices: _emotionSlices(stats),
                          blackout: _emotionBlackout,
                          onTapSlice: (i) => setState(() => _emotionBlackout.contains(i)
                              ? _emotionBlackout.remove(i)
                              : _emotionBlackout.add(i)),
                          centerText:
                              'P ${stats.profileEmotion.fold(0, (s, e) => s + e.pCount)}',
                          size: 240,
                        ),
                        const SizedBox(height: 6),
                        const Text('点击扇区可标记为「重点缺陷域」（涂黑）',
                            style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text('P 数折线图（按评估次数）',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        _LineLegend(
                          stats: stats,
                          hidden: _hiddenLines,
                          onToggle: (k) => setState(() => _hiddenLines.contains(k)
                              ? _hiddenLines.remove(k)
                              : _hiddenLines.add(k)),
                        ),
                        const SizedBox(height: 8),
                        AutismLineChart(
                          xLabels: stats.evalSeqs
                              .map((s) => '第${s}次')
                              .toList(),
                          series: _buildSeries(stats),
                          height: 280,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  List<AutismLineSeries> _buildSeries(AutismEvalStats stats) {
    final List<AutismLineSeries> out = <AutismLineSeries>[];
    // 全部题目总 P 数
    if (!_hiddenLines.contains('全部题目')) {
      out.add(AutismLineSeries(
        label: '全部题目',
        color: const Color(0xFF7C5CF0),
        values: stats.totalPSeries().cast<num>(),
      ));
    }
    final Map<String, int> paletteIdx = <String, int>{};
    for (int i = 0; i < autismAreaKeys.length; i++) {
      paletteIdx[autismAreaKeys[i]] = i;
    }
    for (final EvalAreaSeries a in stats.areaSeries) {
      if (_hiddenLines.contains(a.areaKey)) continue;
      final List<num> vals = <num>[
        for (final int seq in stats.evalSeqs)
          a.points.where((x) => x.seq == seq).isEmpty
              ? 0
              : a.points.firstWhere((x) => x.seq == seq).pCount,
      ];
      out.add(AutismLineSeries(
        label: a.areaLabel,
        color: _areaPalette[(paletteIdx[a.areaKey] ?? 0) % _areaPalette.length],
        values: vals,
      ));
    }
    return out;
  }
}

/// 折线图图例（可点击切换显隐）。
class _LineLegend extends StatelessWidget {
  const _LineLegend({
    required this.stats,
    required this.hidden,
    required this.onToggle,
  });
  final AutismEvalStats stats;
  final Set<String> hidden;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    final List<_LegendItem> items = <_LegendItem>[
      const _LegendItem(key: '全部题目', label: '全部题目', color: Color(0xFF7C5CF0)),
    ];
    for (final EvalAreaSeries a in stats.areaSeries) {
      final int idx =
          autismAreaKeys.indexOf(a.areaKey).clamp(0, _areaPalette.length - 1);
      items.add(_LegendItem(
          key: a.areaKey, label: a.areaLabel, color: _areaPalette[idx]));
    }
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: items
          .map((it) => FilterChip(
                label: Text(it.label, style: const TextStyle(fontSize: 12)),
                selected: !hidden.contains(it.key),
                selectedColor: it.color.withAlpha(60),
                onSelected: (_) => onToggle(it.key),
              ))
          .toList(),
    );
  }
}

class _LegendItem {
  const _LegendItem({
    required this.key,
    required this.label,
    required this.color,
  });
  final String key;
  final String label;
  final Color color;
}
