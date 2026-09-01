import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';
import 'package:teacher_app/data/models/autism_eval_item.dart';
import 'package:teacher_app/features/rehab/data/rehab_repository.dart';
import 'package:teacher_app/features/rehab/presentation/vb_detail_screen.dart';
import 'package:teacher_app/features/rehab/presentation/widgets/autism_line_chart.dart';
import 'package:teacher_app/features/rehab/provider/autism_eval_provider.dart';
import 'package:teacher_app/features/rehab/provider/rehab_provider.dart';

/// VB（Vanderbilt）首页：家长卷 / 教师卷 两套。
///
/// 仿「线下模板」首页的引导式布局（与 OfflineArchiveHome 风格一致）：
/// - 顶部两个并列大卡：「新建评估 - 家长卷」/「新建评估 - 教师卷」
///   点击直接进入对应卷的答题页；提交后落到「VB 评估结果」页。
/// - 下方「历史评估记录」：按卷列出所有轮次，点击进入评测详情。
/// - AppBar 右上角保留「查看趋势」入口（按 form 选择卷）。
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
  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('VB（Vanderbilt 评估）'),
        actions: <Widget>[
          IconButton(
            tooltip: '查看评估趋势',
            icon: const Icon(Icons.show_chart),
            onPressed: () => context.push(
                '/rehab-autism/${widget.archiveId}/vb-trend?form=VB_PARENT'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          _bigStartCards(context, colors),
          const SizedBox(height: 16),
          _sectionTitle(context, '历史评估记录'),
          VbHistoryList(archiveId: widget.archiveId),
        ],
      ),
    );
  }

  /// 顶部两个并列大卡：点击进入对应卷的答题页。
  Widget _bigStartCards(BuildContext context, ColorScheme colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final (String code, String label) in _vbForms) ...<Widget>[
          _startCard(context, colors, code, label),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _startCard(
      BuildContext context, ColorScheme colors, String code, String label) {
    final bool isTeacher = code == 'VB_TEACHER';
    return Card(
      color: isTeacher ? colors.secondaryContainer : colors.primary,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(
            '/rehab-autism/${widget.archiveId}/items?form=$code'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          child: Row(
            children: <Widget>[
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isTeacher ? Icons.school_outlined : Icons.family_restroom,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('新建评估 · $label',
                        style: TextStyle(
                          color: isTeacher ? colors.onSecondaryContainer : Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        )),
                    const SizedBox(height: 4),
                    Text(
                      isTeacher
                          ? '答 VB 教师卷 → 提交后自动出分并查看报告'
                          : '答 VB 家长卷 → 提交后自动出分并查看报告',
                      style: TextStyle(
                        color: isTeacher
                            ? colors.onSecondaryContainer.withValues(alpha: 0.85)
                            : Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  color: isTeacher ? colors.onSecondaryContainer : Colors.white),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String t) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
        child: Text(
          t,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      );
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
      for (final (String code, String _) in _vbForms) {
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
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: LinearProgressIndicator(minHeight: 2),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text('加载失败：$_error',
            style: const TextStyle(color: Colors.grey)),
      );
    }
    final bool any = _byForm.values.any((l) => l.isNotEmpty);
    if (!any) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            '暂无历史评估记录。点上方「新建评估」答卷并提交后，本次评估会自动出现在这里。',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }
    final List<Widget> cards = <Widget>[];
    for (final (String code, String label) in _vbForms) {
      final List<AutismEvalRound> rounds = _byForm[code] ?? const <AutismEvalRound>[];
      if (rounds.isEmpty) continue;
      cards.add(Card(
        margin: const EdgeInsets.only(bottom: 12),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Icon(Icons.history, size: 18),
                  const SizedBox(width: 8),
                  Text(label,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                ],
              ),
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

/// VB 提交后的「评估结果」页（仿线下模板引导式流程）。
///
/// 入口：VB 答题页（AutismScaleEvalScreen）右上角「提交」成功
/// → 后端计分（vb/score）→ pushReplacement 到本页。
/// 页面只做四件事：看得分表 + 儿童情况说明、导出报告、查看完整详情、返回儿童详情。
///
/// 返回键与底部「完成」按钮都直接回到儿童详情页 `/children/{id}`，
/// 不会退回答题页（避免重复提交）。
/// 本次评估已归档，回到 VB 首页即可在「历史评估记录」中看到。
class VbSubmitResultScreen extends ConsumerStatefulWidget {
  const VbSubmitResultScreen({
    required this.archiveId,
    required this.roundId,
    this.formCode = 'VB_PARENT',
    this.formLabel = '家长卷',
    super.key,
  });
  final String archiveId;
  final String roundId;
  final String formCode;
  final String formLabel;

  @override
  ConsumerState<VbSubmitResultScreen> createState() =>
      _VbSubmitResultScreenState();
}

class _VbSubmitResultScreenState extends ConsumerState<VbSubmitResultScreen> {
  Map<String, dynamic>? _score;
  bool _loading = true;
  bool _exporting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final Map<String, dynamic> data =
          await ref.read(rehabRepositoryProvider).vbScore(widget.roundId);
      if (!mounted) return;
      setState(() {
        _score = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '出分失败：$e';
        _loading = false;
      });
    }
  }

  /// 退出本页 = 回到儿童详情页（不再退回答题页）。
  void _backToChild() => context.go('/children/${widget.archiveId}');

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      final Uint8List bytes = await ref
          .read(rehabRepositoryProvider)
          .getVbReportPdf(widget.roundId);
      final int seq = _score?['evalSeq'] is int
          ? _score!['evalSeq'] as int
          : int.tryParse(_score?['evalSeq']?.toString() ?? '') ?? 0;
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'VB报告_${widget.formLabel}_第$seq次.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('导出失败：$e')));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) _backToChild();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('VB 评估结果'),
          leading: BackButton(onPressed: _backToChild),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: <Widget>[
                  if (_error != null)
                    Card(
                      color: colors.errorContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(_error!,
                            style: TextStyle(color: colors.onErrorContainer)),
                      ),
                    )
                  else if (_score != null) ...<Widget>[
                    _summaryCard(colors),
                    const SizedBox(height: 12),
                    VbScoreTable(
                        sections: (_score!['sections'] is List
                            ? List<dynamic>.from(_score!['sections'] as List)
                            : <dynamic>[])),
                    const SizedBox(height: 12),
                    if ((_score!['explanation']?.toString() ?? '').isNotEmpty)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              const Text('儿童情况说明',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14)),
                              const SizedBox(height: 8),
                              Text(_score!['explanation'].toString(),
                                  style: const TextStyle(
                                      fontSize: 13, height: 1.5)),
                            ],
                          ),
                        ),
                      ),
                  ],
                  const SizedBox(height: 20),
                  _sectionTitle(context, '报告'),
                  _action(
                    context,
                    Icons.picture_as_pdf_outlined,
                    '导出报告（PDF：得分表 + 柱状图）',
                    '下载带鉴权的 VB 评估 PDF',
                    _export,
                    busy: _exporting,
                  ),
                  _action(
                    context,
                    Icons.assessment_outlined,
                    '查看完整详情',
                    '展开所有维度得分表与儿童情况说明',
                    () => context.push(
                      '/rehab-autism/${widget.archiveId}/vb-detail'
                      '?form=${widget.formCode}'
                      '&label=${Uri.encodeQueryComponent(widget.formLabel)}'
                      '&round=${widget.roundId}',
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.check),
                      label: const Text('完成，返回儿童页'),
                      onPressed: _backToChild,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _summaryCard(ColorScheme colors) {
    final int seq = _score?['evalSeq'] is int
        ? _score!['evalSeq'] as int
        : int.tryParse(_score?['evalSeq']?.toString() ?? '') ?? 0;
    return Card(
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
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String t) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
        child: Text(
          t,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      );

  Widget _action(BuildContext context, IconData icon, String title,
      String subtitle, VoidCallback onTap,
      {bool busy = false}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: busy
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: busy ? null : const Icon(Icons.chevron_right),
        onTap: busy ? null : onTap,
      ),
    );
  }
}
