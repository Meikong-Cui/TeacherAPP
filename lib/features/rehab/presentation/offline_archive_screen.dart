import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';
import 'package:teacher_app/data/models/autism_archive.dart';
import 'package:teacher_app/features/rehab/data/rehab_repository.dart';
import 'package:teacher_app/features/rehab/presentation/offline_subitem_parser.dart';
import 'package:teacher_app/features/rehab/provider/rehab_provider.dart';

/// 线下模板评估（OFFLINE）首页：引导式入口（issue 2）。
///
/// 只保留两件事，避免功能平铺让用户不知道点哪里：
/// 1. 顶部大卡片「新建评估」→ 答 A 卷 → 提交 → 答 B 卷 → 提交 → 评估结果页
///    （得分 + 报告入口；退出回到儿童详情页）。
/// 2. 下方「历史评估记录」：每次提交自动归档一轮，可回看答案 / 教师版 / 家长版 / 总览报告。
class OfflineArchiveHome extends ConsumerStatefulWidget {
  const OfflineArchiveHome({required this.archiveId, super.key});
  final String archiveId;

  @override
  ConsumerState<OfflineArchiveHome> createState() => _OfflineArchiveHomeState();
}

class _OfflineArchiveHomeState extends ConsumerState<OfflineArchiveHome> {
  List<Map<String, dynamic>> _rounds = <Map<String, dynamic>>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _rounds = await ref
          .read(rehabRepositoryProvider)
          .listOfflineRounds(widget.archiveId);
    } catch (_) {
      // 历史记录为空时后端返回空列表，忽略异常。
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('线下模板评估')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          // Issue 2：入口收紧为一个大「新建评估」按钮（与历史记录分开），
          // 后续按 A → B → 提交 → 评估结果 顺序引导用户完成一轮评估。
          _bigStartCard(context, colors),
          const SizedBox(height: 16),
          _sectionTitle(context, '历史评估记录'),
          _roundsSection(context),
        ],
      ),
    );
  }

  /// Issue 2 引入的大尺寸「新建评估」入口卡片：从 A 卷答题开始走完一轮。
  Widget _bigStartCard(BuildContext context, ColorScheme colors) {
    return Card(
      color: colors.primary,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(
            '/rehab/${widget.archiveId}/offline-answer?paper=A'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
          child: Row(
            children: <Widget>[
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.add_circle_outline,
                    color: Colors.white, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const <Widget>[
                    Text('新建评估',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 20)),
                    SizedBox(height: 6),
                    Text('答 A/B 卷 → 提交后自动出分并查看报告',
                        style: TextStyle(color: Colors.white70, fontSize: 13)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white),
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
          child: Text('暂无历史评估记录。点上方「新建评估」答 A/B 卷并提交，'
              '本次评估会自动出现在这里。',
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
  /// 一键答题循环下标：0→P/A，1→E/M，2→F/S，然后绕回 0。
  /// 不包含 N（N 表示无机会/不适用，须老师手动判定，不自动填写）。
  int _cycleIdx = 0;

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
      if (!mounted) return;
      // Issue 1+2：保存即「提交」，不再自动弹分数框；改为引导到下一步。
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已提交，正在出分…')));
      if (widget.paper == 'A') {
        // A卷 提交 → 紧接着答 B卷（同路由，仅 paper 改变）。
        context.pushReplacement(
            '/rehab/${widget.archiveId}/offline-answer?paper=B');
        return;
      }
      // B卷 提交 → 新一轮评估自动归档（这样历史记录里能看到本次评估），
      // 再进入「评估结果」页看得分与导出报告。回看历史轮次时不重复归档。
      int? roundId;
      if (widget.roundId == null) {
        try {
          roundId = await ref
              .read(rehabRepositoryProvider)
              .createOfflineRound(widget.archiveId);
        } catch (_) {
          // 归档失败不阻断出分：结果页按无轮次处理（只是历史记录不新增）。
        }
      }
      if (!mounted) return;
      final String qs = roundId == null ? '' : '?round=$roundId';
      context.pushReplacement('/rehab/${widget.archiveId}/offline-submit$qs');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('保存失败：$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// 一键答题循环档位：与每题选项顺序一一对应（0/1/2）。
  static const List<String> _cycleLabelsA = <String>['P / A', 'E / M', 'F / S'];
  static const List<String> _cycleLabelsB =
      <String>['独立完成', '协助完成', '不能完成'];

  /// 某题的可选 code 列表（过滤掉 N）。
  List<String> _cycleCodesOf(Map<String, dynamic> item) =>
      _options(item).map((o) => o.$1).where((c) => c != 'N').toList();

  /// 一键循环填写：仅填选项，不触发保存/出分（出分由右上角「提交」按钮触发）。
  ///
  /// 档位按**每题自己的选项顺序**取，跳过 N：
  /// - 第 1 次点击 → P / A / 独立完成
  /// - 第 2 次点击 → E / M / 协助完成
  /// - 第 3 次点击 → F / S / 不能完成
  ///
  /// A 卷里「感觉模式」题是 A/M/S/N，其余题是 P/E/F——若统一取首题选项会把
  /// P 填进只有 A/M/S/N 的题里，故逐题取自己那一档，保证 code 一定合法。
  void _cycleFill() {
    final List<String> labels =
        widget.paper == 'A' ? _cycleLabelsA : _cycleLabelsB;
    final int pos = _cycleIdx % labels.length;
    setState(() {
      for (final Map<String, dynamic> it in _visibleItems) {
        final int id = _toInt(it['id']) ?? 0;
        if (id == 0) continue;
        final List<String> codes = _cycleCodesOf(it);
        if (codes.isEmpty) continue;
        _draft[id] = codes[pos < codes.length ? pos : codes.length - 1];
      }
      _cycleIdx = (_cycleIdx + 1) % labels.length;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已一键全选「${labels[pos]}」，确认后点右上角「提交」出分'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// 一键答题按钮（单按钮循环切换档位，issue 1）。
  Widget _buildQuickFill() {
    final List<String> labels =
        widget.paper == 'A' ? _cycleLabelsA : _cycleLabelsB;
    final String next = labels[_cycleIdx % labels.length];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          icon: const Icon(Icons.flash_on),
          label: Text('一键全选 $next'),
          onPressed: _saving || _visibleItems.isEmpty ? null : _cycleFill,
        ),
      ),
    );
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
            // Issue 1：保存图标改为文字「提交」按钮，更符合引导式流程语境。
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: TextButton(
                onPressed: _save,
                style: TextButton.styleFrom(
                  textStyle: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15),
                ),
                child: const Text('提交'),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: <Widget>[
          _buildQuickFill(),
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
        // Issue 2：保存即回到儿童详情页（避免在结果页反复停留）。
        context.go('/children/${widget.archiveId}');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('保存失败：$e')));
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: '返回儿童详情',
          // Issue 2：结果页退出直接回到儿童详情，不再回退到线下模板首页。
          onPressed: () => context.go('/children/${widget.archiveId}'),
        ),
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
          // Issue 2：结果页加「导出报告」入口，引导式流程的最后一环。
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push(
                      '/rehab/${widget.archiveId}/offline-eval-guidance?type=TEACHER&title=${Uri.encodeQueryComponent('教师版评估报告')}'),
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('教师版报告'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push(
                      '/rehab/${widget.archiveId}/offline-eval-guidance?type=PARENT&title=${Uri.encodeQueryComponent('家长版评估报告')}'),
                  icon: const Icon(Icons.family_restroom_outlined),
                  label: const Text('家长版报告'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}


/// 提交后的「评估结果」页（引导式流程终点，issue 2）。
///
/// 入口：B 卷点右上角「提交」→ 自动归档为新一轮 → pushReplacement 到本页。
/// 页面只做三件事：看得分、挑小项后查看/导出报告、完成返回。
///
/// 返回键与底部「完成」按钮都直接回到儿童详情页 `/children/{id}`，
/// 不会退回 A/B 卷答题页（避免重复提交产生多余轮次）。
/// 本次评估已归档，回到线下模板首页即可在「历史评估记录」中看到。
class OfflineSubmitResultScreen extends ConsumerStatefulWidget {
  const OfflineSubmitResultScreen({
    required this.archiveId,
    this.roundId,
    super.key,
  });
  final String archiveId;

  /// 本次提交自动归档出的轮次 id；为 null 表示归档失败（不显示小项挑选入口）。
  final String? roundId;

  @override
  ConsumerState<OfflineSubmitResultScreen> createState() =>
      _OfflineSubmitResultScreenState();
}

class _OfflineSubmitResultScreenState
    extends ConsumerState<OfflineSubmitResultScreen> {
  Map<String, dynamic>? _aOverview;
  Map<String, dynamic>? _bResult;
  bool _loading = true;
  String? _error;

  /// 7 个领域类型固定顺序，与 OA 网页剖面图一致。
  static const List<String> _domains = <String>[
    '模仿',
    '知觉',
    '精细动作',
    '粗大动作',
    '手眼协调',
    '认知表现',
    '口语认知',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final RehabRepository repo = ref.read(rehabRepositoryProvider);
      _aOverview = await repo.getOfflineAOverview(widget.archiveId);
      _bResult = await repo.getOfflineBResult(widget.archiveId);
      _error = null;
    } catch (e) {
      _error = '出分失败：$e';
    }
    if (mounted) setState(() => _loading = false);
  }

  /// 退出本页 = 回到儿童详情页（不再退回答题页）。
  void _backToChild() => context.go('/children/${widget.archiveId}');

  String _str(dynamic v, [String fallback = '-']) =>
      (v == null || v.toString().isEmpty) ? fallback : v.toString();

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
          title: const Text('评估结果'),
          leading: BackButton(onPressed: _backToChild),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: <Widget>[
                  if (_error != null) _errorCard(colors) else ...<Widget>[
                    _aScoreCard(colors),
                    const SizedBox(height: 12),
                    _bScoreCard(colors),
                  ],
                  const SizedBox(height: 20),
                  _section('报告'),
                  if (widget.roundId != null)
                    _action(
                      context,
                      Icons.checklist,
                      '挑选康复目标 / 指导说明',
                      '勾选要纳入报告的小项，再导出教师版 / 家长版报告',
                      () => context.push(
                          '/rehab/${widget.archiveId}/offline-guidance/${widget.roundId}'),
                    ),
                  _action(
                    context,
                    Icons.school_outlined,
                    '教师版评估报告',
                    '按所选小项查看并导出 PDF',
                    () => context.push(
                      '/rehab/${widget.archiveId}/offline-eval-guidance'
                      '?type=TEACHER&title=${Uri.encodeQueryComponent('教师版评估报告')}',
                    ),
                  ),
                  _action(
                    context,
                    Icons.family_restroom_outlined,
                    '家长版评估报告',
                    '按所选小项查看并导出 PDF',
                    () => context.push(
                      '/rehab/${widget.archiveId}/offline-eval-guidance'
                      '?type=PARENT&title=${Uri.encodeQueryComponent('家长版评估报告')}',
                    ),
                  ),
                  _action(
                    context,
                    Icons.insights_outlined,
                    '发展总览报告',
                    'A 卷得分总览 + 发展功能剖面图，可导出 PDF',
                    () => context.push(
                      '/rehab/${widget.archiveId}/offline-overview'
                      '${widget.roundId == null ? '' : '?roundId=${widget.roundId}'}',
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

  Widget _errorCard(ColorScheme colors) => Card(
        color: colors.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(_error!, style: TextStyle(color: colors.onErrorContainer)),
        ),
      );

  Widget _aScoreCard(ColorScheme colors) {
    final List<dynamic> types = _aOverview?['types'] is List
        ? List<dynamic>.from(_aOverview!['types'] as List)
        : <dynamic>[];
    final Map<String, Map<String, dynamic>> byType =
        <String, Map<String, dynamic>>{};
    for (final dynamic t in types) {
      if (t is Map && t['itemType'] != null) {
        byType[t['itemType'].toString()] = Map<String, dynamic>.from(t);
      }
    }
    final String total = _str(_aOverview?['totalScore']);
    final String full = _str(_aOverview?['totalFullScore']);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.assignment_turned_in_outlined),
                const SizedBox(width: 8),
                const Text('A 卷得分',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const Spacer(),
                Text('总分 $total / $full',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, color: colors.primary)),
              ],
            ),
            const Divider(height: 20),
            ..._domains.map((String d) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: <Widget>[
                      Expanded(child: Text(d)),
                      Text(
                        '${_str(byType[d]?['score'], '0')} / ${_str(byType[d]?['fullScore'], '0')}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _bScoreCard(ColorScheme colors) {
    final String passed = _str(_bResult?['maxPassedGroup'], '未通过任何年龄段');
    final String bucket = _str(_bResult?['bucket'], '');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Row(
              children: <Widget>[
                Icon(Icons.accessible_forward_outlined),
                SizedBox(width: 8),
                Text('B 卷结果',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              ],
            ),
            const Divider(height: 20),
            Row(
              children: <Widget>[
                const Text('最大通过年龄段'),
                const Spacer(),
                Text(passed, style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
            if (bucket.isNotEmpty) ...<Widget>[
              const SizedBox(height: 6),
              Row(
                children: <Widget>[
                  const Text('适应行为分档'),
                  const Spacer(),
                  Text(bucket, style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _section(String t) => Padding(
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
      String subtitle, VoidCallback onTap) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
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
    this.selectedItems,
    super.key,
  });
  final String archiveId;
  final String type;
  final String title;

  /// 所选小项：project -> { 'rehabGoal': [idx...], 'guidance': [idx...] }。
  /// 为 null 时展示报告全量（所有小项）。
  final Map<String, Map<String, List<int>>>? selectedItems;

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

  Map<String, Map<String, List<int>>>? _selectedItems;

  @override
  void initState() {
    super.initState();
    _role = widget.type == 'PARENT' ? 'PARENT' : 'TEACHER';
    _selectedItems = widget.selectedItems;
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

  List<dynamic> get _filteredRows {
    final dynamic rows = _content?['rows'];
    if (rows is! List) return const <dynamic>[];
    return rows;
  }

  /// 按所选小项过滤某一字段（康复目标 / 指导说明）的文本。
  String _filterField(String project, String field, String text) {
    final Map<String, List<int>>? sel = _selectedItems?[project];
    if (sel == null) return text;
    final List<int>? indices = sel[field];
    if (indices == null) return text;
    return filterSubItems(text, Set<int>.from(indices));
  }

  Future<void> _exportPdf() async {
    setState(() => _exporting = true);
    try {
      final String? itemsParam = _selectedItems == null
          ? null
          : encodeSelectedItems(_selectedItems!);
      final Uint8List bytes = await ref
          .read(rehabRepositoryProvider)
          .getOfflineEvalReportPdf(widget.archiveId, _role, itemsParam: itemsParam);
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
    final List<dynamic> rowList = _filteredRows;
    if (rowList.isEmpty) {
      return const Center(child: Text('暂无报告内容（请先完成 B 卷答题）'));
    }
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
              final String rehabGoal =
                  _filterField(project, 'rehabGoal', row['rehabGoal']?.toString() ?? '');
              final String guidance =
                  _filterField(project, 'guidance', row['guidance']?.toString() ?? '');
              return TableRow(
                children: <Widget>[
                  _Td(project, bold: true),
                  _Td(row['refAge']?.toString() ?? ''),
                  _Td(rehabGoal),
                  _Td(guidance),
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
