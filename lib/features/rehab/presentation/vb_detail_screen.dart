import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:teacher_app/features/rehab/data/rehab_repository.dart';
import 'package:teacher_app/features/rehab/provider/rehab_provider.dart';
import 'package:teacher_app/data/models/autism_eval_item.dart';

/// VB（Vanderbilt）评测详情页：展示某一卷（家长卷/教师卷）最新一次评估的
/// 各维度得分表 + 儿童情况说明，并提供「导出报告」（PDF，含得分表与柱状图）。
///
/// 流程：教师在点开某卷「评测详情」时，自动取该卷最新一轮作答 → 调用后端计分
/// （vb/score，幂等）→ 展示得分与说明；点「导出报告」下载带鉴权的 PDF。
class VbDetailScreen extends ConsumerStatefulWidget {
  const VbDetailScreen({
    required this.archiveId,
    this.formCode = 'VB_PARENT',
    this.formLabel = '家长卷',
    this.roundId,
    super.key,
  });
  final String archiveId;
  final String formCode;
  final String formLabel;
  final String? roundId;

  @override
  ConsumerState<VbDetailScreen> createState() => _VbDetailScreenState();
}

class _VbDetailScreenState extends ConsumerState<VbDetailScreen> {
  bool _exporting = false;
  Map<String, dynamic>? _data;

  Future<Map<String, dynamic>> _load() async {
    final RehabRepository repo = ref.read(rehabRepositoryProvider);
    final List<AutismEvalRound> rounds =
        await repo.listEvalRounds(widget.archiveId, widget.formCode);
    if (rounds.isEmpty) {
      return <String, dynamic>{'rounds': const <AutismEvalRound>[], 'score': null};
    }
    // 未指定轮次则取最新一次；指定了则按 roundId 精确定位（历史查看）
    final AutismEvalRound target = widget.roundId != null && widget.roundId!.isNotEmpty
        ? (rounds.where((r) => r.id?.toString() == widget.roundId).firstOrNull ?? rounds.last)
        : rounds.last;
    final String rid = target.id?.toString() ?? '';
    final Map<String, dynamic> score = await repo.vbScore(rid);
    return <String, dynamic>{
      'rounds': rounds,
      'round': target,
      'roundId': rid,
      'score': score,
    };
  }

  Future<void> _export() async {
    final String? rid = _data?['roundId']?.toString();
    if (rid == null || rid.isEmpty) return;
    final dynamic round = _data?['round'];
    final int seq = round is AutismEvalRound ? (round.evalSeq ?? 0) : 0;
    setState(() => _exporting = true);
    try {
      final Uint8List bytes =
          await ref.read(rehabRepositoryProvider).getVbReportPdf(rid);
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'VB报告_${widget.formLabel}_第$seq次.pdf',
      );
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
    return Scaffold(
      appBar: AppBar(
        title: Text('VB 评测详情 · ${widget.formLabel}'),
        actions: <Widget>[
          if (_exporting)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(
                  width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              tooltip: '导出报告',
              onPressed: _data?['roundId'] != null ? _export : null,
            ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _load(),
        builder: (BuildContext context,
            AsyncSnapshot<Map<String, dynamic>> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('加载失败：${snapshot.error}',
                    style: const TextStyle(color: Colors.grey)),
              ),
            );
          }
          _data = snapshot.data;
          final List<dynamic> sections =
              _data?['score']?['sections'] is List ? _data!['score']['sections'] as List : const <dynamic>[];
          final String explanation =
              _data?['score']?['explanation']?.toString() ?? '';
          final dynamic round = _data?['round'];
          final int seq = round is AutismEvalRound ? (round.evalSeq ?? 0) : 0;

          if (_data == null ||
              (_data!['rounds'] is List && (_data!['rounds'] as List).isEmpty)) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('该卷尚无评估记录，请先「作答」并完成一次评估。',
                    style: TextStyle(color: Colors.grey)),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('第 $seq 次评估 · ${widget.formLabel}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15)),
                      const SizedBox(height: 4),
                      Text('得分随作答编辑自动重算；下表为各维度量化结果。',
                          style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (sections.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('该轮次暂无可计分的作答，请先完成答题。',
                      style: TextStyle(color: Colors.grey)),
                )
              else
                _ScoreTable(sections: sections),
              if (explanation.isNotEmpty) ...<Widget>[
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text('儿童情况说明',
                            style: TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 14)),
                        const SizedBox(height: 8),
                        Text(explanation,
                            style: const TextStyle(fontSize: 13, height: 1.5)),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('导出报告（PDF：得分表 + 柱状图）'),
                  onPressed: _exporting ? null : _export,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ScoreTable extends StatelessWidget {
  const _ScoreTable({required this.sections});
  final List<dynamic> sections;

  @override
  Widget build(BuildContext context) {
    return Table(
      border: TableBorder.all(color: Colors.grey.shade400),
      columnWidths: const <int, TableColumnWidth>{
        0: FlexColumnWidth(1.6),
        1: FlexColumnWidth(0.9),
        2: FlexColumnWidth(0.8),
        3: FlexColumnWidth(1.0),
        4: FlexColumnWidth(0.8),
        5: FlexColumnWidth(0.9),
        6: FlexColumnWidth(0.9),
        7: FlexColumnWidth(1.1),
      },
      children: <TableRow>[
        TableRow(
          decoration: BoxDecoration(color: Colors.grey.shade200),
          children: const <Widget>[
            _Th('维度'),
            _Th('类型'),
            _Th('题数'),
            _Th('得分'),
            _Th('均分'),
            _Th('≥2题数'),
            _Th('阈值'),
            _Th('结果'),
          ],
        ),
        ...sections.map((r) {
          final Map<String, dynamic> m =
              r is Map<String, dynamic> ? r : <String, dynamic>{};
          final String scoreType = m['scoreType']?.toString() ?? 'SYMPTOM';
          final int ge2 = _toInt(m['countGe2']);
          final int itemCount = _toInt(m['itemCount']);
          final int sum = _toInt(m['sumScore']);
          final int max = _toInt(m['maxScore']);
          final dynamic threshold = m['threshold'];
          final bool positive = m['positive'] == 1;
          final String resultText = threshold == null
              ? '不适用'
              : (positive ? '筛查阳性' : '阴性');
          return TableRow(
            children: <Widget>[
              _Td(m['section']?.toString() ?? '', bold: true),
              _Td(scoreType == 'PERFORMANCE' ? '表现' : '症状'),
              _Td('$itemCount'),
              _Td('$sum/$max'),
              _Td(_fmtAvg(m['avgScore'])),
              _Td('$ge2'),
              _Td(threshold == null ? '-' : '$threshold'),
              _Td(resultText,
                  color: threshold == null
                      ? Colors.grey
                      : (positive ? Colors.red : Colors.green.shade700),
                  bold: true),
            ],
          );
        }),
      ],
    );
  }
}

class _Th extends StatelessWidget {
  const _Th(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(6),
        child: Text(text,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            textAlign: TextAlign.center),
      );
}

class _Td extends StatelessWidget {
  const _Td(this.text, {this.bold = false, this.color});
  final String text;
  final bool bold;
  final Color? color;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(6),
        child: Text(text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: bold ? FontWeight.w700 : null,
              color: color,
            ),
            textAlign: TextAlign.center),
      );
}

int _toInt(dynamic v) => v is int ? v : (int.tryParse(v?.toString() ?? '') ?? 0);

String _fmtAvg(dynamic v) {
  if (v is num) return v.toStringAsFixed(2);
  final double? d = double.tryParse(v?.toString() ?? '');
  return d == null ? '0.00' : d.toStringAsFixed(2);
}
