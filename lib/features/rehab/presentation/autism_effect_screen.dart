import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teacher_app/data/models/autism_eval_item.dart';
import 'package:teacher_app/features/rehab/data/autism_questions.dart';
import 'package:teacher_app/features/rehab/provider/rehab_provider.dart';
import 'package:teacher_app/shared/handwritten_uploader.dart';

/// 训练效果评估表（文档三）。
///
/// 数据来源改为「评估轮次（round）」下逐题评分：[AutismEvalItem]。
///  - STANDARD：复用本地 8 领域题项（[autismQuestionAreas]），按相邻两次评估
///    对比得到 显效 / 有效 / 无效。
///  - OFFLINE / VB：无 P/E/F/X 模型，展示各轮次逐题评分清单。
/// 纯展示界面，不可编辑。
class AutismEffectScreen extends ConsumerStatefulWidget {
  const AutismEffectScreen({required this.archiveId, super.key});
  final String archiveId;

  @override
  ConsumerState<AutismEffectScreen> createState() => _AutismEffectScreenState();
}

class _AutismEffectScreenState extends ConsumerState<AutismEffectScreen> {
  String _formCode = '';
  List<AutismEvalRound> _rounds = <AutismEvalRound>[];
  final Map<String, List<AutismEvalItem>> _itemsByRound =
      <String, List<AutismEvalItem>>{};
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
      final Map<String, List<AutismEvalItem>> itemsByRound =
          <String, List<AutismEvalItem>>{};
      for (final r in rounds) {
        if (r.id == null) continue;
        try {
          itemsByRound[r.id.toString()] =
              await repo.listRoundItems(r.id.toString());
        } catch (_) {
          itemsByRound[r.id.toString()] = const <AutismEvalItem>[];
        }
      }
      if (!mounted) return;
      setState(() {
        _rounds = rounds;
        _itemsByRound
          ..clear()
          ..addAll(itemsByRound);
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

  /// roundId -> 评估序号（缺省用下标+1）。
  Map<String, int> get _roundSeq {
    final Map<String, int> m = <String, int>{};
    for (int i = 0; i < _rounds.length; i++) {
      final r = _rounds[i];
      if (r.id != null) m[r.id.toString()] = r.evalSeq ?? (i + 1);
    }
    return m;
  }

  /// "$areaKey|$itemCode" -> { evalSeq: 评级 }
  Map<String, Map<int, String>> get _values {
    final Map<String, Map<int, String>> v = <String, Map<int, String>>{};
    final Map<String, int> seq = _roundSeq;
    for (final r in _rounds) {
      if (r.id == null) continue;
      final int s = seq[r.id.toString()]!;
      for (final it in _itemsByRound[r.id.toString()] ?? <AutismEvalItem>[]) {
        if (it.rating == null || it.rating!.isEmpty) continue;
        v.putIfAbsent('${it.areaKey}|${it.itemCode}',
            () => <int, String>{})[s] = it.rating!;
      }
    }
    return v;
  }

  List<int> get _seqs {
    final Set<int> seqSet = <int>{};
    for (final m in _values.values) {
      seqSet.addAll(m.keys);
    }
    final List<int> seqs = seqSet.toList()..sort();
    return seqs;
  }

  String? _effectOf(String? before, String? after, bool isEmotion) {
    if (before == null || after == null) return null;
    if (isEmotion) {
      if ((before == 'M' || before == 'S') && after == 'A') return '显效';
      if (before == 'S' && after == 'M') return '有效';
      return '无效';
    } else {
      if ((before == 'E' || before == 'F') && after == 'P') return '显效';
      if (before == 'F' && after == 'E') return '有效';
      return '无效';
    }
  }

  bool _isPass(String? v, bool isEmotion) {
    if (v == null) return false;
    return isEmotion ? (v == 'A' || v == 'M') : v == 'P';
  }

  int _pCountAt(AutismQuestionArea area, int seq) {
    final bool emo = autismIsEmotionArea(area.key);
    int c = 0;
    for (final AutismQuestion q in area.items) {
      final String? v = _values['${area.key}|${q.code}']?[seq];
      if (_isPass(v, emo)) c++;
    }
    return c;
  }

  String _overall(int firstP, int lastP) {
    final int delta = lastP - firstP;
    if (delta >= 10) return '显效';
    if (delta >= 5) return '有效';
    return '无效';
  }

  Widget _buildArea(AutismQuestionArea area, List<int> seqs) {
    final List<int> pBySeq = seqs.map((s) => _pCountAt(area, s)).toList();
    final int firstP = pBySeq.isNotEmpty ? pBySeq.first : 0;
    final int lastP = pBySeq.isNotEmpty ? pBySeq.last : 0;
    final String overall = seqs.length >= 2 ? _overall(firstP, lastP) : '—';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        initiallyExpanded: area.key == autismQuestionAreas.first.key,
        title: Text(area.label,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(_seqSummary(seqs, pBySeq, overall)),
        children: <Widget>[
          _EffectTable(
            area: area,
            seqs: seqs,
            values: _values,
            effectOf: _effectOf,
          ),
        ],
      ),
    );
  }

  String _seqSummary(List<int> seqs, List<int> pBySeq, String overall) {
    if (seqs.isEmpty) return '尚未录入评估数据';
    final List<String> parts = <String>[];
    for (int i = 0; i < seqs.length; i++) {
      parts.add('第${seqs[i]}次 P=${pBySeq[i]}');
    }
    return '${parts.join('，')}　总体评价：$overall';
  }

  /// OFFLINE / VB 等量表：逐轮次展示题项评分清单。
  List<Widget> _buildGeneric() {
    final List<Widget> out = <Widget>[];
    final Map<String, int> seq = _roundSeq;
    for (final r in _rounds) {
      if (r.id == null) continue;
      final int s = seq[r.id.toString()]!;
      final items = _itemsByRound[r.id.toString()] ?? <AutismEvalItem>[];
      out.add(Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: ExpansionTile(
          initiallyExpanded: out.isEmpty,
          title: Text('第$s次评估'),
          subtitle: Text('${items.length} 题'),
          children: items.isEmpty
              ? const <Widget>[
                  Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('本次评估暂无评分。'),
                  )
                ]
              : items
                  .map((it) => ListTile(
                        dense: true,
                        title: Text(it.itemName,
                            style: const TextStyle(fontSize: 13)),
                        trailing: Text(
                          it.optionLabel?.isNotEmpty == true
                              ? it.optionLabel!
                              : (it.rating ?? '—'),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ))
                  .toList(),
        ),
      ));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('训练效果评估表（文档三）')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('训练效果评估表（文档三）')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(_error!),
          ),
        ),
      );
    }

    final bool isStandard = _formCode == 'STANDARD';
    final List<int> seqs = _seqs;

    return Scaffold(
      appBar: AppBar(
        title: const Text('训练效果评估表（文档三）'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
            onPressed: _load,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: <Widget>[
          HandwrittenUploader(
            archiveId: widget.archiveId,
            section: 'STANDARD_EFFECT',
            title: '训练效果评估表 · 手写板',
            compact: true,
          ),
          const SizedBox(height: 8),
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding:
                const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade100),
            ),
            child: Text(
              isStandard
                  ? '效果判定：训练前「中间项(E)」训练后「通过(P)」为显效；'
                      '训练前「未通过(F)」训练后「中间项(E)」为有效；无变化为无效。'
                      '（情绪域：M/S→A 为显效，S→M 为有效）'
                  : '当前量表（$_formCode）逐次评估的题项评分清单。',
              style: const TextStyle(fontSize: 12, color: Colors.blue),
            ),
          ),
          if (isStandard)
            ...autismQuestionAreas.map((a) => _buildArea(a, seqs)).toList()
          else
            ..._buildGeneric(),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

/// 单个领域的训练效果明细表。
class _EffectTable extends StatelessWidget {
  const _EffectTable({
    required this.area,
    required this.seqs,
    required this.values,
    required this.effectOf,
  });
  final AutismQuestionArea area;
  final List<int> seqs;
  final Map<String, Map<int, String>> values;
  final String? Function(String? before, String? after, bool isEmotion) effectOf;

  static const double _codeW = 44;
  static const double _trainW = 40;
  static const double _effW = 48;

  @override
  Widget build(BuildContext context) {
    final bool emo = autismIsEmotionArea(area.key);
    final bool has3 = seqs.contains(3);

    Widget headerCell(String t, double w, {bool center = true}) => SizedBox(
          width: w,
          child: center
              ? Center(
                  child: Text(t,
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w700)))
              : Text(t,
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w700)),
        );

    final List<Widget> header = <Widget>[
      headerCell('代号', _codeW),
      const Expanded(child: Text('项目', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
    ];
    for (final s in seqs) {
      header.add(headerCell('第$s次', _trainW));
    }
    header.add(headerCell('效果①', _effW));
    if (has3) header.add(headerCell('效果②', _effW));

    final List<Widget> rows = <Widget>[];
    for (final AutismQuestion q in area.items) {
      final Map<int, String>? vm = values['${area.key}|${q.code}'];
      final String? v1 = vm?[1];
      final String? v2 = vm?[2];
      final String? v3 = vm?[3];

      final List<Widget> cells = <Widget>[
        SizedBox(
            width: _codeW,
            child: Text(q.code,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Text(q.name,
                style: const TextStyle(fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ),
        ),
      ];
      for (final s in seqs) {
        final String? v = vm?[s];
        cells.add(SizedBox(
          width: _trainW,
          child: Center(
            child: v != null && v.isNotEmpty
                ? const Icon(Icons.check, size: 16, color: Colors.green)
                : const Text('', style: TextStyle(fontSize: 12)),
          ),
        ));
      }
      cells.add(_effCell(effectOf(v1, v2, emo)));
      if (has3) cells.add(_effCell(effectOf(v2, v3, emo)));

      rows.add(Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade200),
          ),
        ),
        child: Row(children: cells),
      ));
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(children: header),
          const SizedBox(height: 4),
          ...rows,
        ],
      ),
    );
  }

  Widget _effCell(String? eff) {
    Color c;
    switch (eff) {
      case '显效':
        c = Colors.green;
        break;
      case '有效':
        c = Colors.orange;
        break;
      case '无效':
        c = Colors.grey;
        break;
      default:
        c = Colors.grey.shade400;
    }
    return SizedBox(
      width: _effW,
      child: Center(
        child: Text(eff ?? '—',
            style: TextStyle(fontSize: 12, color: c, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
