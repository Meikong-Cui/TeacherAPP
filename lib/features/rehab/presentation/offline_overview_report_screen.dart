import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:teacher_app/features/rehab/presentation/widgets/offline_profile_chart.dart';
import 'package:teacher_app/features/rehab/provider/rehab_provider.dart';

/// 第三份报告：发展总览报告。
/// 固定两项：① A 卷得分总览计数（A 类 A/M/S/N、P 类 P/E/F）；② 发展功能剖面图。
/// 与 OA 网页「报告② A 卷得分总览 + 剖面图」对齐，支持导出 PDF。
/// roundId 非空时按 round 答案 JSON 算（评估历史点 round 进入时）。
class OfflineOverviewReportScreen extends ConsumerStatefulWidget {
  const OfflineOverviewReportScreen({
    required this.archiveId,
    this.roundId,
    super.key,
  });
  final String archiveId;
  final String? roundId;

  @override
  ConsumerState<OfflineOverviewReportScreen> createState() =>
      _OfflineOverviewReportScreenState();
}

class _OfflineOverviewReportScreenState
    extends ConsumerState<OfflineOverviewReportScreen> {
  Map<String, dynamic>? _overview;
  bool _loading = true;
  bool _exporting = false;

  static const List<String> _order = <String>[
    '模仿', '知觉', '精细动作', '粗大动作', '手眼协调', '认知表现', '口语认知',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _overview = await ref
          .read(rehabRepositoryProvider)
          .getOfflineAOverview(widget.archiveId, roundId: widget.roundId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('加载失败：$e')));
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  /// 由 A 卷得分总览构建 8 列剖面图数据（7 领域 + 发展评分），与网页 profileScores 一致。
  List<OfflineProfileScore?> _buildScores() {
    final List<dynamic> types = _overview?['types'] is List
        ? List<dynamic>.from(_overview!['types'])
        : <dynamic>[];
    final Map<String, dynamic> byType = <String, dynamic>{};
    for (final dynamic t in types) {
      if (t is Map && t['itemType'] != null) byType[t['itemType'].toString()] = t;
    }
    final List<OfflineProfileScore?> seven = _order.map((String d) {
      final dynamic t = byType[d];
      if (t == null) return null;
      final double score =
          (t['score'] is num ? (t['score'] as num).toDouble() : 0);
      final double full =
          (t['fullScore'] is num ? (t['fullScore'] as num).toDouble() : 0);
      return OfflineProfileScore(score: score, fullScore: full);
    }).toList();
    final double totalScore =
        _overview?['totalScore'] is num ? (_overview!['totalScore'] as num).toDouble() : 0;
    final double totalFull = _overview?['totalFullScore'] is num
        ? (_overview!['totalFullScore'] as num).toDouble()
        : 0;
    final double devScore = totalFull > 0 ? (totalScore / totalFull * 85) : 0;
    return <OfflineProfileScore?>[...seven, OfflineProfileScore(score: devScore, fullScore: 85)];
  }

  Future<void> _export() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final Uint8List bytes = await ref
          .read(rehabRepositoryProvider)
          .getOfflineOverviewReportPdf(widget.archiveId, roundId: widget.roundId);
      final String tag = widget.roundId == null
          ? widget.archiveId
          : 'round${widget.roundId}_${widget.archiveId}';
      await Printing.sharePdf(bytes: bytes, filename: '发展总览报告_$tag.pdf');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('导出失败：$e')));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('发展总览报告')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final List<dynamic> types = _overview?['types'] is List
        ? List<dynamic>.from(_overview!['types'])
        : <dynamic>[];
    final List<dynamic> aTypes = types
        .where((t) => t is Map && t['optionType'] == 'A')
        .toList();
    final List<dynamic> pTypes = types
        .where((t) => t is Map && t['optionType'] == 'P')
        .toList();
    final String total = _overview?['totalScore']?.toString() ?? '-';
    final String totalFull = _overview?['totalFullScore']?.toString() ?? '-';

    return Scaffold(
      appBar: AppBar(
        title: const Text('发展总览报告'),
        actions: <Widget>[
          _exporting
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: SizedBox(
                      width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                )
              : IconButton(
                  icon: const Icon(Icons.picture_as_pdf),
                  tooltip: '导出 PDF',
                  onPressed: _export,
                ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: <Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: _Stat('A 卷总分', '$total / $totalFull'),
                  ),
                  Expanded(
                    child: _Stat('类型数', '${types.length}'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _CountCard(
            title: '一、选项计数（A/M/S/N 分档）',
            columns: const <String>['类型', '题数', 'A', 'M', 'S', 'N'],
            rows: aTypes,
            countKeys: const <String>['A', 'M', 'S', 'N'],
          ),
          const SizedBox(height: 12),
          _CountCard(
            title: '二、选项计数（P/E/F 分档）',
            columns: const <String>['类型', '题数', 'P', 'E', 'F'],
            rows: pTypes,
            countKeys: const <String>['P', 'E', 'F'],
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text('三、发展功能剖面图',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 8),
                  OfflineProfileChart(
                    scores: _buildScores(),
                    footer: 'A 卷总分 $total / $totalFull',
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

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        ],
      );
}

class _CountCard extends StatelessWidget {
  const _CountCard({
    required this.title,
    required this.columns,
    required this.rows,
    required this.countKeys,
  });
  final String title;
  final List<String> columns;
  final List<dynamic> rows;
  final List<String> countKeys;

  int _count(Map<String, dynamic> c, String k) {
    final dynamic v = c[k];
    return v is num ? v.toInt() : 0;
  }

  @override
  Widget build(BuildContext context) {
    final List<TableRow> tableRows = <TableRow>[
      TableRow(
        decoration: const BoxDecoration(color: Color(0xffeeeeee)),
        children: columns
            .map((c) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                  child: Text(c,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ))
            .toList(),
      ),
    ];
    for (final dynamic r in rows) {
      if (r is! Map) continue;
      final Map<String, dynamic> counts = r['counts'] is Map
          ? Map<String, dynamic>.from(r['counts'])
          : <String, dynamic>{};
      final List<Widget> cells = <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
          child: Text(r['itemType']?.toString() ?? '',
              style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
        _cell(r['total']?.toString() ?? '0'),
      ];
      for (final String k in countKeys) {
        cells.add(_cell(_count(counts, k).toString()));
      }
      tableRows.add(TableRow(children: cells));
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 8),
            Table(
              border: TableBorder.all(color: Colors.grey),
              children: tableRows,
            ),
          ],
        ),
      ),
    );
  }

  Widget _cell(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
        child: Text(text, textAlign: TextAlign.center),
      );
}
