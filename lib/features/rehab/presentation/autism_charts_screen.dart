import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teacher_app/data/models/autism_eval_item.dart';
import 'package:teacher_app/features/rehab/data/autism_questions.dart';
import 'package:teacher_app/features/rehab/presentation/widgets/autism_line_chart.dart';
import 'package:teacher_app/features/rehab/presentation/widgets/development_profile_chart.dart';
import 'package:teacher_app/features/rehab/presentation/widgets/emotion_ring_chart.dart';
import 'package:teacher_app/features/rehab/provider/autism_eval_provider.dart';
import 'package:teacher_app/features/rehab/services/chart_export.dart';

/// 评估图表：发展情况剖面图（竖线，可点选）+ 情绪行为表现图（同心圆环，可涂黑）+ P 数折线图。
class AutismChartsScreen extends ConsumerStatefulWidget {
  const AutismChartsScreen({required this.archiveId, super.key});
  final String archiveId;

  @override
  ConsumerState<AutismChartsScreen> createState() => _AutismChartsScreenState();
}

/// 折线图临床灰阶配色（与另两张黑白图风格统一）。
const List<Color> _linePalette = <Color>[
  Color(0xFF333333),
  Color(0xFF555555),
  Color(0xFF6E6E6E),
  Color(0xFF888888),
  Color(0xFF9E9E9E),
  Color(0xFFB4B4B4),
  Color(0xFF4A4A4A),
  Color(0xFF7A7A7A),
];

class _AutismChartsScreenState extends ConsumerState<AutismChartsScreen> {
  final Set<String> _hiddenLines = <String>{};

  /// 用于导出图表的 RepaintBoundary 键。
  final GlobalKey _profileKey = GlobalKey();
  final GlobalKey _emotionKey = GlobalKey();
  final GlobalKey _lineKey = GlobalKey();
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref
          .read(autismEvalStatsProvider('${widget.archiveId}|FIRST').notifier)
          .load(),
    );
  }

  /// 数据为空时构造一份「全 0」统计，使折线图仍能正常渲染。
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

  @override
  Widget build(BuildContext context) {
    final AutismEvalStatsState st =
        ref.watch(autismEvalStatsProvider('${widget.archiveId}|FIRST'));
    final AutismEvalStats? raw = st.stats;
    final bool empty = raw == null || raw.evalSeqs.isEmpty;
    final AutismEvalStats stats = empty ? _emptyStats() : raw;

    ref.listen<AutismEvalStatsState>(
        autismEvalStatsProvider('${widget.archiveId}|FIRST'), (_, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(next.error!)));
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('评估图表'),
        actions: <Widget>[
          PopupMenuButton<String>(
            icon: const Icon(Icons.ios_share),
            tooltip: '导出图表',
            onSelected: (String chart) async {
              if (_exporting) return;
              setState(() => _exporting = true);
              try {
                final GlobalKey key;
                final String title;
                switch (chart) {
                  case 'profile':
                    key = _profileKey;
                    title = '孤独症儿童发展情况剖面图';
                    break;
                  case 'emotion':
                    key = _emotionKey;
                    title = '孤独症儿童情绪行为表现图';
                    break;
                  case 'line':
                    key = _lineKey;
                    title = 'P数折线图';
                    break;
                  default:
                    return;
                }
                await exportBoundaryToPdf(
                  key,
                  filename: '$title.pdf',
                  title: title,
                );
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('导出失败: $e')),
                  );
                }
              } finally {
                if (mounted) setState(() => _exporting = false);
              }
            },
            itemBuilder: (_) => const <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                  value: 'profile', child: Text('导出 发展情况剖面图 (PDF)')),
              PopupMenuItem<String>(
                  value: 'emotion', child: Text('导出 情绪行为表现图 (PDF)')),
              PopupMenuItem<String>(
                  value: 'line', child: Text('导出 P数折线图 (PDF)')),
            ],
          ),
        ],
      ),
      body: st.loading && raw == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(12),
              children: <Widget>[
                if (empty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(
                        vertical: 8, horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: const Row(
                      children: <Widget>[
                        Icon(Icons.info_outline,
                            size: 16, color: Colors.amber),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '暂无评估数据，折线图为空白占位；'
                            '上方两张图可直接在屏幕上点选填写。',
                            style:
                                TextStyle(fontSize: 12, color: Colors.amber),
                          ),
                        ),
                      ],
                    ),
                  ),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text('发展情况剖面图（首次评估）',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        RepaintBoundary(
                          key: _profileKey,
                          child: Container(
                            color: Colors.white,
                            child: const DevelopmentProfileChart(
                              editable: true,
                            ),
                          ),
                        ),
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
                        const Text('情绪行为表现图',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        RepaintBoundary(
                          key: _emotionKey,
                          child: Container(
                            color: Colors.white,
                            child: const EmotionRingChart(
                              editable: true,
                            ),
                          ),
                        ),
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
                        RepaintBoundary(
                          key: _lineKey,
                          child: Container(
                            color: Colors.white,
                            child: AutismLineChart(
                              xLabels: stats.evalSeqs
                                  .map((s) => '第$s次')
                                  .toList(),
                              series: _buildSeries(stats),
                              height: 280,
                            ),
                          ),
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
    // 全部题目总 P 数（黑色主线）
    if (!_hiddenLines.contains('全部题目')) {
      out.add(AutismLineSeries(
        label: '全部题目',
        color: Colors.black,
        values: stats.totalPSeries().cast<num>(),
      ));
    }
    for (int i = 0; i < stats.areaSeries.length; i++) {
      final EvalAreaSeries a = stats.areaSeries[i];
      if (_hiddenLines.contains(a.areaKey)) continue;
      final List<num> vals = <num>[
        for (final int seq in stats.evalSeqs)
          a.points.where((x) => x.seq == seq).isEmpty
              ? 0
              : a.points.firstWhere((x) => x.seq == seq).pCount,
      ];
      out.add(AutismLineSeries(
        label: a.areaLabel,
        color: _linePalette[i % _linePalette.length],
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
      const _LegendItem(key: '全部题目', label: '全部题目', color: Colors.black),
    ];
    for (int i = 0; i < stats.areaSeries.length; i++) {
      final EvalAreaSeries a = stats.areaSeries[i];
      items.add(_LegendItem(
        key: a.areaKey,
        label: a.areaLabel,
        color: _linePalette[i % _linePalette.length],
      ));
    }
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: items
          .map((it) => FilterChip(
                label: Text(it.label, style: const TextStyle(fontSize: 12)),
                selected: !hidden.contains(it.key),
                selectedColor: it.color.withAlpha(40),
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
