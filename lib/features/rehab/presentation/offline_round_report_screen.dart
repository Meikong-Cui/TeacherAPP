import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:teacher_app/features/rehab/provider/rehab_provider.dart';

/// 单个线下模板评估轮次的报告查看页（不可变快照）。
/// 支持教师版/家长版切换，导出该轮次 PDF。
class OfflineRoundReportScreen extends ConsumerStatefulWidget {
  const OfflineRoundReportScreen({
    required this.archiveId,
    required this.roundId,
    required this.role,
    super.key,
  });
  final String archiveId;
  final String roundId;
  final String role;

  @override
  ConsumerState<OfflineRoundReportScreen> createState() =>
      _OfflineRoundReportScreenState();
}

class _OfflineRoundReportScreenState
    extends ConsumerState<OfflineRoundReportScreen> {
  late String _role;
  Map<String, dynamic>? _round;
  bool _loading = true;
  bool _exporting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _role = widget.role == 'PARENT' ? 'PARENT' : 'TEACHER';
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _round =
          await ref.read(rehabRepositoryProvider).getOfflineRound(widget.roundId);
      _error = null;
    } catch (e) {
      _error = '加载失败：$e';
    }
    if (mounted) setState(() => _loading = false);
  }

  Map<String, dynamic>? get _report {
    if (_round == null) return null;
    final Map<String, dynamic>? r = _role == 'TEACHER'
        ? _round!['evalReportT'] as Map<String, dynamic>?
        : _round!['evalReportP'] as Map<String, dynamic>?;
    return r;
  }

  Future<void> _exportPdf() async {
    setState(() => _exporting = true);
    try {
      final Uint8List bytes = await ref
          .read(rehabRepositoryProvider)
          .getOfflineRoundReportPdf(widget.roundId, _role);
      final String name =
          '${_role == 'TEACHER' ? '教师版' : '家长版'}评估报告_第${widget.roundId}次.pdf';
      await Printing.sharePdf(bytes: bytes, filename: name);
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
    final int seq = _round?['evalSeq'] is int ? _round!['evalSeq'] as int : 0;
    final String roleLabel = _role == 'TEACHER' ? '教师版' : '家长版';
    return Scaffold(
      appBar: AppBar(
        title: Text('第 $seq 次 · $roleLabel评估报告'),
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
              tooltip: '导出 PDF',
              onPressed: _exportPdf,
            ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SegmentedButton<String>(
              segments: const <ButtonSegment<String>>[
                ButtonSegment<String>(value: 'TEACHER', label: Text('教师版')),
                ButtonSegment<String>(value: 'PARENT', label: Text('家长版')),
              ],
              selected: <String>{_role},
              onSelectionChanged: (Set<String> sel) {
                if (sel.first != _role) setState(() => _role = sel.first);
              },
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(_error!,
                              style: const TextStyle(color: Colors.grey)),
                        ),
                      )
                    : _buildReport(),
          ),
        ],
      ),
    );
  }

  Widget _buildReport() {
    final Map<String, dynamic>? report = _report;
    final dynamic rows = report?['rows'];
    if (rows is! List || rows.isEmpty) {
      return const Center(child: Text('该轮次暂无报告内容'));
    }
    final List<dynamic> rowList = rows;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(report?['title']?.toString() ?? '评估报告',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              textAlign: TextAlign.center),
        ),
        Table(
          border: TableBorder.all(color: Colors.grey.shade400),
          columnWidths: const <int, TableColumnWidth>{
            0: FlexColumnWidth(1.4),
            1: FlexColumnWidth(1.2),
            2: FlexColumnWidth(2.6),
            3: FlexColumnWidth(2.6),
          },
          children: <TableRow>[
            TableRow(
              decoration: BoxDecoration(color: Colors.grey.shade200),
              children: const <Widget>[
                _Th('项目'),
                _Th('参考年龄'),
                _Th('康复目标'),
                _Th('指导说明'),
              ],
            ),
            ...rowList.map((r) {
              final Map<String, dynamic> row =
                  r is Map<String, dynamic> ? r : <String, dynamic>{};
              final String project = row['project']?.toString() ?? '';
              final bool isSelf = project == '个人自理';
              return TableRow(
                children: <Widget>[
                  _Td(project, bold: true),
                  _Td(row['refAge']?.toString() ?? ''),
                  _Td(row['rehabGoal']?.toString() ?? ''),
                  _Td(row['guidance']?.toString() ?? ''),
                ],
                decoration: isSelf
                    ? BoxDecoration(color: Colors.blue.shade50)
                    : null,
              );
            }),
          ],
        ),
      ],
    );
  }
}

class _Th extends StatelessWidget {
  const _Th(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(8),
        child: Text(text,
            style: const TextStyle(fontWeight: FontWeight.w700),
            textAlign: TextAlign.center),
      );
}

class _Td extends StatelessWidget {
  const _Td(this.text, {this.bold = false});
  final String text;
  final bool bold;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(8),
        child: Text(text,
            style: bold ? const TextStyle(fontWeight: FontWeight.w700) : null),
      );
}
