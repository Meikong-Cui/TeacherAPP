import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teacher_app/data/models/autism_eval_item.dart';
import 'package:teacher_app/features/rehab/presentation/widgets/autism_line_chart.dart';
import 'package:teacher_app/features/rehab/presentation/widgets/development_profile_chart.dart';
import 'package:teacher_app/features/rehab/presentation/widgets/emotion_ring_chart.dart';
import 'package:teacher_app/features/rehab/provider/rehab_provider.dart';
import 'package:teacher_app/features/rehab/services/chart_export.dart';
import 'package:teacher_app/shared/handwritten_uploader.dart';

/// 评估图表：发展情况剖面图（竖线，可点选）+ 情绪行为表现图（同心圆环，可涂黑）+ 折线图。
///
/// 数据来源改为「评估轮次（round）」+ 后端轮次统计（[EvalRoundStats]）：
///  - STANDARD：展示两张自绘可编辑图（8 领域剖面 + 情绪行为环）+ 各域 P 数折线图。
///  - OFFLINE / VB：展示各域均分汇总 + 各域均分折线图（按评估次数对比）。
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

  String _formCode = '';
  List<AutismEvalRound> _rounds = <AutismEvalRound>[];
  final Map<String, EvalRoundStats> _stats = <String, EvalRoundStats>{};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(rehabRepositoryProvider);
      String fc = 'STANDARD';
      try {
        final detail = await repo.getArchive(widget.archiveId);
        fc = detail.archive.evalFormCode;
      } catch (_) {
        fc = 'STANDARD';
      }
      if (!mounted) return;
      _formCode = fc;

      final rounds = await repo.listEvalRounds(widget.archiveId, _formCode);
      final Map<String, EvalRoundStats> stats = <String, EvalRoundStats>{};
      for (final r in rounds) {
        if (r.id == null) continue;
        try {
          stats[r.id.toString()] =
              await repo.getRoundStats(r.id.toString());
        } catch (_) {
          // 单轮统计失败忽略，不阻塞其他轮次。
        }
      }
      if (!mounted) return;
      setState(() {
        _rounds = rounds;
        _stats
          ..clear()
          ..addAll(stats);
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '加载失败：$e';
        });
      }
    }
  }

  /// 全部有统计的轮次（保持与 _rounds 同顺序）。
  List<AutismEvalRound> get _statRounds => _rounds
      .where((r) => r.id != null && _stats.containsKey(r.id.toString()))
      .toList();

  /// 折线图取第一个有统计轮次的领域集合作为基准。
  List<EvalAreaStat> get _baseAreas {
    for (final r in _statRounds) {
      final s = _stats[r.id.toString()]!;
      if (s.areas.isNotEmpty) return s.areas;
    }
    return const <EvalAreaStat>[];
  }

  num _metricForRound(AutismEvalRound r, String areaKey, bool isStandard) {
    final EvalRoundStats? s = r.id != null ? _stats[r.id.toString()] : null;
    if (s == null) return 0;
    if (isStandard) {
      return s.areas.fold<int>(0, (sum, a) => sum + a.passCount);
    }
    final area = s.areas.firstWhere(
      (x) => x.areaKey == areaKey,
      orElse: () => EvalAreaStat(
        areaKey: areaKey,
        areaLabel: areaKey,
        total: 0,
        passCount: 0,
        failCount: 0,
        sumScore: 0,
        avgScore: 0,
      ),
    );
    return area.avgScore;
  }

  int _totalPForRound(AutismEvalRound r) {
    final EvalRoundStats? s = r.id != null ? _stats[r.id.toString()] : null;
    if (s == null) return 0;
    return s.areas.fold<int>(0, (sum, a) => sum + a.passCount);
  }

  double _totalScoreForRound(AutismEvalRound r) {
    final EvalRoundStats? s = r.id != null ? _stats[r.id.toString()] : null;
    if (s == null) return 0;
    return s.areas.fold<double>(0, (sum, a) => sum + a.avgScore);
  }

  List<AutismLineSeries> _buildSeries() {
    final List<AutismEvalRound> rounds = _statRounds;
    if (rounds.isEmpty) return <AutismLineSeries>[];
    final bool isStandard = _formCode == 'STANDARD';
    final List<EvalAreaStat> areas = _baseAreas;
    final List<String> xLabels =
        rounds.map((r) => '第${r.evalSeq ?? '?'}次').toList();

    final List<AutismLineSeries> out = <AutismLineSeries>[];
    if (!_hiddenLines.contains('全部题目')) {
      out.add(AutismLineSeries(
        label: '全部题目',
        color: Colors.black,
        values: rounds
            .map((r) => isStandard ? _totalPForRound(r) : _totalScoreForRound(r))
            .toList(),
      ));
    }
    for (int i = 0; i < areas.length; i++) {
      final EvalAreaStat a = areas[i];
      if (_hiddenLines.contains(a.areaKey)) continue;
      out.add(AutismLineSeries(
        label: a.areaLabel,
        color: _linePalette[i % _linePalette.length],
        values: rounds
            .map((r) => _metricForRound(r, a.areaKey, isStandard))
            .toList(),
      ));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final bool isStandard = _formCode == 'STANDARD';
    final List<AutismLineSeries> series = _buildSeries();
    final bool empty = _statRounds.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('评估图表'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
            onPressed: _load,
          ),
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
                    title = '评估得分折线图';
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
            itemBuilder: (_) {
              final List<PopupMenuEntry<String>> items =
                  <PopupMenuEntry<String>>[];
              if (isStandard) {
                items.add(const PopupMenuItem<String>(
                    value: 'profile',
                    child: Text('导出 发展情况剖面图 (PDF)')));
                items.add(const PopupMenuItem<String>(
                    value: 'emotion',
                    child: Text('导出 情绪行为表现图 (PDF)')));
              }
              items.add(const PopupMenuItem<String>(
                  value: 'line', child: Text('导出 得分折线图 (PDF)')));
              return items;
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error!),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(12),
                  children: <Widget>[
                    HandwrittenUploader(
                      archiveId: widget.archiveId,
                      section: 'STANDARD_CHART',
                      title: '评估图表 · 手写板',
                      compact: true,
                    ),
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
                                '尚未创建评估轮次，请先到「评测录入」页创建评估并作答。',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.amber),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (isStandard) ...<Widget>[
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              const Text('发展情况剖面图（首次评估）',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
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
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
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
                    ] else ...<Widget>[
                      _AreaScoreSummary(
                        stats: _statRounds.isNotEmpty
                            ? _stats[_statRounds.last.id.toString()]
                            : null,
                      ),
                      const SizedBox(height: 12),
                    ],
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                                isStandard
                                    ? 'P 数折线图（按评估次数）'
                                    : '领域均分折线图（按评估次数）',
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            _LineLegend(
                              areas: _baseAreas,
                              hidden: _hiddenLines,
                              onToggle: (k) =>
                                  setState(() => _hiddenLines.contains(k)
                                      ? _hiddenLines.remove(k)
                                      : _hiddenLines.add(k)),
                            ),
                            const SizedBox(height: 8),
                            RepaintBoundary(
                              key: _lineKey,
                              child: Container(
                                color: Colors.white,
                                child: AutismLineChart(
                                  xLabels: _statRounds
                                      .map((r) => '第${r.evalSeq ?? '?'}次')
                                      .toList(),
                                  series: series,
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
}

/// OFFLINE / VB 等量表：展示最近一次评估各领域均分汇总。
class _AreaScoreSummary extends StatelessWidget {
  const _AreaScoreSummary({this.stats});
  final EvalRoundStats? stats;

  @override
  Widget build(BuildContext context) {
    if (stats == null || stats!.areas.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            '暂无领域得分数据。',
            style: TextStyle(
                fontSize: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('领域得分汇总（第${stats!.roundId}轮）',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...stats!.areas.map((a) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: <Widget>[
                      Expanded(child: Text(a.areaLabel)),
                      Text('${a.avgScore.toStringAsFixed(1)} 分 '
                          '（共 ${a.total} 项，得分合计 ${a.sumScore}）'),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

/// 折线图图例（可点击切换显隐）。
class _LineLegend extends StatelessWidget {
  const _LineLegend({
    required this.areas,
    required this.hidden,
    required this.onToggle,
  });
  final List<EvalAreaStat> areas;
  final Set<String> hidden;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    final List<_LegendItem> items = <_LegendItem>[
      const _LegendItem(key: '全部题目', label: '全部题目', color: Colors.black),
    ];
    for (int i = 0; i < areas.length; i++) {
      final EvalAreaStat a = areas[i];
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
