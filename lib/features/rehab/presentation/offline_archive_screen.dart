import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';
import 'package:teacher_app/data/models/autism_archive.dart';
import 'package:teacher_app/features/rehab/data/rehab_repository.dart';
import 'package:teacher_app/features/rehab/provider/rehab_provider.dart';

/// 线下模板评估（OFFLINE）首页：6 个卡片入口。
///
/// - 填写 A 卷答案 / 填写 B 卷答案：线下纸质题本评估后录入题号对应选项（无题干）。
/// - A/B 卷评估结果（可编辑）：汇总 7 领域得分与适应年龄当量，保存后自动生成 3 份报告。
/// - 评估报告 / 教师康复指导 / 家长康复指导：查看自动生成的报告。
class OfflineArchiveHome extends ConsumerStatefulWidget {
  const OfflineArchiveHome({required this.archiveId, super.key});
  final String archiveId;

  @override
  ConsumerState<OfflineArchiveHome> createState() => _OfflineArchiveHomeState();
}

class _OfflineArchiveHomeState extends ConsumerState<OfflineArchiveHome> {
  List<Map<String, dynamic>> _reports = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _rounds = <Map<String, dynamic>>[];
  bool _loading = true;
  bool _archiving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final RehabRepository repo = ref.read(rehabRepositoryProvider);
      _reports = await repo.listOfflineReports(widget.archiveId);
      _rounds = await repo.listOfflineRounds(widget.archiveId);
    } catch (_) {
      // 报告未生成时后端返回空列表，忽略异常。
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _archive() async {
    if (_archiving) return;
    setState(() => _archiving = true);
    try {
      final int roundId = await ref
          .read(rehabRepositoryProvider)
          .createOfflineRound(widget.archiveId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已保存为第 $roundId 次评估记录')));
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('归档失败：$e')));
    } finally {
      if (mounted) setState(() => _archiving = false);
    }
  }

  bool _hasReport(String type) {
    // 新 9 行评估报告类型：TEACHER→EVAL_REPORT_T，PARENT→EVAL_REPORT_P
    final String rt = type == 'TEACHER' ? 'EVAL_REPORT_T' : 'EVAL_REPORT_P';
    return _reports.any((r) => r['reportType'] == rt);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('线下模板评估')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: ListTile(
              leading: _archiving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(Icons.archive_outlined,
                      color: Theme.of(context).colorScheme.onPrimaryContainer),
              title: Text('保存为新一轮评估',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onPrimaryContainer)),
              subtitle: Text('将当前 A/B 卷答案与报告归档为一份不可变记录',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimaryContainer)),
              trailing: const Icon(Icons.chevron_right,
                  color: Colors.white70),
              onTap: _archiving ? null : _archive,
            ),
          ),
          const SizedBox(height: 8),
          _sectionTitle(context, '答题'),
          _card(
            context,
            Icons.edit_document,
            '填写 A 卷答案',
            '线下纸质题本评估后录入 A 卷题号对应选项',
            () => context.push(
                '/rehab/${widget.archiveId}/offline-answer?paper=A'),
          ),
          _card(
            context,
            Icons.edit_document,
            '填写 B 卷答案',
            '线下纸质题本评估后录入 B 卷题号对应选项',
            () => context.push(
                '/rehab/${widget.archiveId}/offline-answer?paper=B'),
          ),
          _sectionTitle(context, '评估结果与报告'),
          _card(
            context,
            Icons.analytics,
            'A/B 卷评估结果（可编辑）',
            '汇总 7 领域得分与适应年龄当量，保存后自动生成报告',
            () => context.push('/rehab/${widget.archiveId}/offline-result'),
          ),
          _reportCard(context, '教师版评估报告', 'TEACHER', Icons.school),
          _reportCard(context, '家长版评估报告', 'PARENT', Icons.family_restroom),
          _card(
            context,
            Icons.insights,
            '发展总览报告',
            'A 卷得分总览计数 + 发展功能剖面图',
            () => context.push(
                '/rehab/${widget.archiveId}/offline-overview'),
          ),
          _sectionTitle(context, '历史评估记录'),
          _roundsSection(context),
        ],
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

  Widget _card(BuildContext context, IconData icon, String title, String subtitle,
      VoidCallback onTap) {
    final Color primary = Theme.of(context).colorScheme.primary;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, color: primary),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  Widget _reportCard(
      BuildContext context, String title, String type, IconData icon) {
    final Color primary = Theme.of(context).colorScheme.primary;
    final bool generated = _hasReport(type);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, color: primary),
        title: Text(title),
        subtitle: Text(generated ? '已生成' : '完成 B 卷答题后自动生成'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (generated)
              const Icon(Icons.check_circle, color: Colors.green, size: 18),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: () => context.push(
            '/rehab/${widget.archiveId}/offline-eval-report?type=$type&title=${Uri.encodeQueryComponent(title)}'),
      ),
    );
  }

  Widget _roundsSection(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: LinearProgressIndicator(minHeight: 2),
      );
    }
    if (_rounds.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text('暂无历史评估记录，完成评估后点上方「保存为新一轮评估」归档。',
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ),
      );
    }
    return Column(
      children: _rounds.map((r) => _roundCard(context, r)).toList(),
    );
  }

  Widget _roundCard(BuildContext context, Map<String, dynamic> r) {
    final int seq = r['evalSeq'] is int ? r['evalSeq'] as int : 0;
    final String date = r['evalDate']?.toString() ?? '';
    final bool hasP = r['hasReportP'] == true;
    final String roundId = r['id']?.toString() ?? '';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(
            '/rehab/${widget.archiveId}/offline-answer/$roundId?paper=A'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Icon(Icons.history, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('第 $seq 次评估',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                  if (date.isNotEmpty)
                    Text(date.substring(0, date.length >= 10 ? 10 : date.length),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => context.push(
                          '/rehab/${widget.archiveId}/offline-round/$roundId?role=TEACHER'),
                      icon: const Icon(Icons.visibility_outlined, size: 18),
                      label: const Text('教师版'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: hasP
                          ? () => context.push(
                              '/rehab/${widget.archiveId}/offline-round/$roundId?role=PARENT')
                          : null,
                      icon: const Icon(Icons.visibility_outlined, size: 18),
                      label: const Text('家长版'),
                    ),
                  ),
                  IconButton(
                    tooltip: '查看第三份报告（发展总览）',
                    onPressed: () => context.push(
                        '/rehab/${widget.archiveId}/offline-overview?roundId=$roundId'),
                    icon: const Icon(Icons.insights, color: Colors.deepPurple),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A/B 卷答题页：仅展示题号与可选项（0/1/2/3），不展示题干。
/// roundId 非空时从 autism_offline_round 的答案 JSON 加载；
/// 保存后会双写主表 + round JSON，让主页「第三份报告」与该 round 自身的报告都即时刷新。
class OfflineAnswerScreen extends ConsumerStatefulWidget {
  const OfflineAnswerScreen({
    required this.archiveId,
    required this.paper,
    this.roundId,
    super.key,
  });
  final String archiveId;
  final String paper;
  final String? roundId;

  @override
  ConsumerState<OfflineAnswerScreen> createState() => _OfflineAnswerScreenState();
}

class _OfflineAnswerScreenState extends ConsumerState<OfflineAnswerScreen> {
  List<Map<String, dynamic>> _items = <Map<String, dynamic>>[];
  final Map<int, String> _draft = <int, String>{};
  bool _loading = true;
  bool _saving = false;
  /// 儿童生理月龄（月），用于 B卷 按年龄隐藏题项；null 表示未知（不隐藏）。
  int? _ageMonths;
  bool _filteredByAge = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// 由出生日期推算生理月龄（向下取整）。
  static int? _calcAgeMonths(DateTime? birth) {
    if (birth == null) return null;
    final DateTime now = DateTime.now();
    int months = (now.year - birth.year) * 12 + (now.month - birth.month);
    if (now.day < birth.day) months -= 1;
    return months;
  }

  Future<void> _load() async {
    try {
      final RehabRepository repo = ref.read(rehabRepositoryProvider);
      _items = await repo.listOfflineItems(widget.paper);
      // B卷：读取儿童出生日期，年龄 > 4 岁（48 月）时隐藏 0~24 月组（题37-47）。
      if (widget.paper == 'B') {
        try {
          final AutismArchiveDetail detail =
              await repo.getAutismArchive(widget.archiveId);
          _ageMonths = _calcAgeMonths(detail.firstEval?.birthDate);
          _filteredByAge = _ageMonths != null && _ageMonths! > 48;
        } catch (_) {
          // 取不到出生日期时不隐藏，展示全部题项。
        }
      }
      final List<Map<String, dynamic>> answers =
          await repo.listOfflineAnswers(widget.archiveId, widget.paper, roundId: widget.roundId);
      for (final Map<String, dynamic> a in answers) {
        final int? itemId = _toInt(a['itemId']);
        final String? v = a['value']?.toString();
        if (itemId != null && v != null) _draft[itemId] = v;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('加载失败：$e')));
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  /// B卷 且儿童年龄 > 4 岁时，隐藏 0~24 月组（题号 37-47）。
  List<Map<String, dynamic>> get _visibleItems {
    if (widget.paper != 'B' || !_filteredByAge) return _items;
    return _items.where((it) {
      final int code = int.tryParse(it['itemCode']?.toString() ?? '') ?? 0;
      return code < 37;
    }).toList();
  }

  List<(String, String)> _options(Map<String, dynamic> item) {
    final dynamic raw = item['optionsJson'];
    if (raw is String && raw.isNotEmpty) {
      try {
        final List<dynamic> list = jsonDecode(raw);
        return list
            .whereType<Map<String, dynamic>>()
            .map((o) =>
                (o['code']?.toString() ?? '', o['label']?.toString() ?? ''))
            .toList();
      } catch (_) {
        // 解析失败时回落到默认 0-3。
      }
    }
    return const <(String, String)>[
      ('0', '0分'),
      ('1', '1分'),
      ('2', '2分'),
      ('3', '3分')
    ];
  }

  Future<void> _save() async {
    if (_draft.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请先作答')));
      return;
    }
    setState(() => _saving = true);
    final List<Map<String, dynamic>> items = _draft.entries
        .map((e) => <String, dynamic>{'itemId': e.key, 'value': e.value})
        .toList();
    // B卷 且年龄 > 4 岁：0~24 月组（题37-47）前端不展示，保存时以「独立完成」补齐，
    // 使后端判定为完成（该组不参与最大通过段选取，不影响结果）。
    if (widget.paper == 'B' && _filteredByAge) {
      for (final Map<String, dynamic> it in _items) {
        final int code = int.tryParse(it['itemCode']?.toString() ?? '') ?? 0;
        final int id = _toInt(it['id']) ?? 0;
        if (code >= 37 && code <= 47 && !_draft.containsKey(id)) {
          items.add(<String, dynamic>{'itemId': id, 'value': 'INDEP'});
        }
      }
    }
    try {
      await ref
          .read(rehabRepositoryProvider)
          .saveOfflineAnswers(widget.archiveId, widget.paper, items, roundId: widget.roundId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已保存')));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('保存失败：$e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text('${widget.paper} 卷答题')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final bool busy = _saving;
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.paper} 卷答题'),
        actions: <Widget>[
          if (busy)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(
                  width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            IconButton(icon: const Icon(Icons.save), onPressed: _save),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: <Widget>[
          if (_filteredByAge)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Text(
                '儿童年龄大于 4 岁，已自动隐藏 0~24 月组（题 37-47）。',
                style: TextStyle(color: Colors.orange.shade800, fontSize: 13),
              ),
            ),
          ..._visibleItems.map((item) {
            final int id = _toInt(item['id']) ?? 0;
            final String name = item['itemName']?.toString() ?? item['itemCode']?.toString() ?? '题$id';
            final List<(String, String)> opts = _options(item);
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: opts
                          .map((o) => ChoiceChip(
                                label: Text(o.$2),
                                selected: _draft[id] == o.$1,
                                onSelected: (_) =>
                                    setState(() => _draft[id] = o.$1),
                              ))
                          .toList(),
                    ),
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

/// A/B 卷评估结果（可编辑）：7 领域得分 + 适应年龄当量。
class OfflineResultScreen extends ConsumerStatefulWidget {
  const OfflineResultScreen({required this.archiveId, super.key});
  final String archiveId;

  @override
  ConsumerState<OfflineResultScreen> createState() => _OfflineResultScreenState();
}

class _OfflineResultScreenState extends ConsumerState<OfflineResultScreen> {
  List<Map<String, dynamic>> _rows = <Map<String, dynamic>>[];
  final Map<String, TextEditingController> _scoreCtl =
      <String, TextEditingController>{};
  final Map<String, TextEditingController> _ageCtl =
      <String, TextEditingController>{};
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _scoreCtl.values) c.dispose();
    for (final c in _ageCtl.values) c.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      _rows =
          await ref.read(rehabRepositoryProvider).getOfflineResult(widget.archiveId);
      for (final Map<String, dynamic> r in _rows) {
        final String dk = r['domainKey']?.toString() ?? '';
        final dynamic score = r['score'];
        final String age = r['ageEquivalent']?.toString() ?? '';
        _scoreCtl[dk] = TextEditingController(
            text: score == null ? '' : score.toString());
        _ageCtl[dk] = TextEditingController(text: age);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('加载失败：$e')));
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final List<Map<String, dynamic>> results = _rows.map((r) {
      final String dk = r['domainKey']?.toString() ?? '';
      final String scoreText = _scoreCtl[dk]?.text.trim() ?? '';
      final String age = _ageCtl[dk]?.text.trim() ?? '';
      return <String, dynamic>{
        'domainKey': dk,
        'score': scoreText.isEmpty ? null : int.tryParse(scoreText),
        'ageEquivalent': age,
      };
    }).toList();
    try {
      await ref
          .read(rehabRepositoryProvider)
          .saveOfflineResult(widget.archiveId, results);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('已保存，报告已生成/更新')));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('保存失败：$e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('A/B 卷评估结果')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('A/B 卷评估结果'),
        actions: <Widget>[
          if (_saving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(
                  width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            IconButton(icon: const Icon(Icons.save), onPressed: _save),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: <Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: const <Widget>[
                  Expanded(flex: 3, child: Text('领域', style: TextStyle(fontWeight: FontWeight.w700))),
                  Expanded(flex: 2, child: Text('得分', style: TextStyle(fontWeight: FontWeight.w700))),
                  Expanded(flex: 3, child: Text('适应年龄当量', style: TextStyle(fontWeight: FontWeight.w700))),
                ],
              ),
            ),
          ),
          ..._rows.map((r) {
            final String dk = r['domainKey']?.toString() ?? '';
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: <Widget>[
                    Expanded(flex: 3, child: Text(dk)),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _scoreCtl[dk],
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          hintText: '0-?',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _ageCtl[dk],
                        decoration: const InputDecoration(
                          hintText: '如 2;6',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}


/// 9 行评估报告查看页（教师版 / 家长版）。
///
/// 报告含 9 行（模仿/知觉/精细动作/粗大动作/手眼协调/认知表现/口语认知/适应行为/个人自理），
/// 四列：项目 / 参考年龄 / 康复目标 / 指导说明。个人自理行由 B卷结果填充，
/// 其余 8 行暂为「待A卷评语」占位（A卷评语后续注入）。
/// 教师版与家长版文案不同，可切换查看并分别导出 PDF。
class OfflineEvalReportScreen extends ConsumerStatefulWidget {
  const OfflineEvalReportScreen({
    required this.archiveId,
    required this.type,
    required this.title,
    super.key,
  });
  final String archiveId;
  final String type;
  final String title;

  @override
  ConsumerState<OfflineEvalReportScreen> createState() =>
      _OfflineEvalReportScreenState();
}

class _OfflineEvalReportScreenState extends ConsumerState<OfflineEvalReportScreen> {
  String _role = 'TEACHER';
  Map<String, dynamic>? _content;
  bool _loading = true;
  bool _exporting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _role = widget.type == 'PARENT' ? 'PARENT' : 'TEACHER';
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final Map<String, dynamic> report = await ref
          .read(rehabRepositoryProvider)
          .getOfflineEvalReport(widget.archiveId, _role);
      _content = report;
      _error = null;
    } catch (e) {
      _error = '加载失败：$e';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _exportPdf() async {
    setState(() => _exporting = true);
    try {
      final Uint8List bytes = await ref
          .read(rehabRepositoryProvider)
          .getOfflineEvalReportPdf(widget.archiveId, _role);
      final String name =
          '${_role == 'TEACHER' ? '教师版' : '家长版'}评估报告_${widget.archiveId}.pdf';
      await Printing.sharePdf(bytes: bytes, filename: name);
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
    final String roleLabel = _role == 'TEACHER' ? '教师版' : '家长版';
    return Scaffold(
      appBar: AppBar(
        title: Text('$roleLabel评估报告'),
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
                if (sel.first != _role) {
                  setState(() => _role = sel.first);
                  _load();
                }
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
    final dynamic rows = _content?['rows'];
    if (rows is! List || rows.isEmpty) {
      return const Center(child: Text('暂无报告内容（请先完成 B 卷答题）'));
    }
    final List<dynamic> rowList = rows;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(_content?['title']?.toString() ?? '评估报告',
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

int? _toInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  return int.tryParse(v.toString());
}
