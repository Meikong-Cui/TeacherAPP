import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teacher_app/data/models/autism_eval_item.dart';
import 'package:teacher_app/features/rehab/data/autism_questions.dart';
import 'package:teacher_app/features/rehab/provider/autism_eval_provider.dart';
import 'package:teacher_app/features/rehab/provider/rehab_provider.dart';

/// 评估题目逐题录入：每个空可选 P/E/F/X（情绪域 A/M/S），支持三次评估。
class AutismItemsEditorScreen extends ConsumerStatefulWidget {
  const AutismItemsEditorScreen({
    required this.archiveId,
    this.source = 'FIRST',
    this.sourceId = 0,
    super.key,
  });
  final String archiveId;
  final String source;
  final int sourceId;

  @override
  ConsumerState<AutismItemsEditorScreen> createState() =>
      _AutismItemsEditorScreenState();
}

class _AutismItemsEditorScreenState extends ConsumerState<AutismItemsEditorScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Map<String, String?> _draft = <String, String?>{};
  bool _seeded = false;
  bool _saving = false;

  static const List<String> _rounds = <String>['第一次', '第二次', '第三次'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
    Future.microtask(
      () => ref
          .read(autismEvalItemsProvider('${widget.archiveId}|${widget.source}').notifier)
          .load(),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _key(String areaKey, String code, int seq) => '$areaKey|$code|$seq';

  void _seed(List<AutismEvalItem> items) {
    if (_seeded || items.isEmpty) return;
    for (final AutismEvalItem it in items) {
      _draft[_key(it.areaKey, it.itemCode, it.evalSeq)] = it.value;
    }
    _seeded = true;
  }

  bool _isPass(String? v, String areaKey) {
    if (v == null) return false;
    return autismIsEmotionArea(areaKey) ? v == 'A' : v == 'P';
  }

  int _areaPassCount(AutismQuestionArea area, int seq) {
    int c = 0;
    for (final q in area.items) {
      if (_isPass(_draft[_key(area.key, q.code, seq)], area.key)) c++;
    }
    return c;
  }

  void _setAll(int seq) {
    for (final area in autismQuestionAreas) {
      final String v = autismIsEmotionArea(area.key) ? 'A' : 'P';
      for (final q in area.items) {
        _draft[_key(area.key, q.code, seq)] = v;
      }
    }
    setState(() {});
  }

  void _clearAll(int seq) {
    for (final area in autismQuestionAreas) {
      for (final q in area.items) {
        _draft[_key(area.key, q.code, seq)] = null;
      }
    }
    setState(() {});
  }

  Future<void> _save(int seq) async {
    setState(() => _saving = true);
    final List<AutismEvalItem> batch = <AutismEvalItem>[];
    for (final area in autismQuestionAreas) {
      for (final q in area.items) {
        final String? v = _draft[_key(area.key, q.code, seq)];
        batch.add(AutismEvalItem(
          archiveId: widget.archiveId,
          source: widget.source,
          sourceId: widget.sourceId,
          evalSeq: seq,
          areaKey: area.key,
          itemCode: q.code,
          itemName: q.name,
          itemScope: q.scope,
          refAge: q.refAge.isEmpty ? null : q.refAge,
          value: v,
        ));
      }
    }
    final bool ok = await ref
        .read(autismEvalItemsProvider('${widget.archiveId}|${widget.source}').notifier)
        .save(batch);
    if (mounted) {
      setState(() => _saving = false);
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('第${seq}次评估已保存（${batch.length} 题）'),
        ));
        // 首次评测（seq=1）保存后，自动创建后续教学设计待办提醒。
        if (seq == 1) {
          try {
            await ref.read(rehabRepositoryProvider).createTask(
                  archiveId: widget.archiveId,
                  reminderType: 'TEACHING_PLAN',
                  title: '孤独症首次评测已完成 · 待生成 IEP / 月教学计划',
                  dueDate: DateTime.now().add(const Duration(days: 30)),
                );
          } catch (_) {
            // 任务创建失败不阻塞主流程
          }
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('保存失败，请重试'),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AutismEvalItemsState st =
        ref.watch(autismEvalItemsProvider('${widget.archiveId}|${widget.source}'));
    _seed(st.items);
    final int seq = _tabController.index + 1;

    ref.listen<AutismEvalItemsState>(
        autismEvalItemsProvider('${widget.archiveId}|${widget.source}'), (_, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(next.error!)));
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('评估题目录入'),
        bottom: TabBar(
          controller: _tabController,
          tabs: _rounds.map((r) => Tab(text: r)).toList(),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => _setAll(seq),
            child: const Text('全选通过'),
          ),
          TextButton(
            onPressed: () => _clearAll(seq),
            child: const Text('清空'),
          ),
          if (_saving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.save),
              tooltip: '保存当前评估',
              onPressed: () => _save(seq),
            ),
        ],
      ),
      body: st.loading && st.items.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: autismQuestionAreas.length,
              itemBuilder: (ctx, i) {
                final AutismQuestionArea area = autismQuestionAreas[i];
                final int pass = _areaPassCount(area, seq);
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ExpansionTile(
                    initiallyExpanded: i == 0,
                    title: Text(area.label),
                    subtitle: Text('P 数 $pass / ${area.items.length}'),
                    children: <Widget>[
                      ...area.items.map((q) => _QuestionRow(
                            areaKey: area.key,
                            q: q,
                            value: _draft[_key(area.key, q.code, seq)],
                            onChanged: (v) =>
                                setState(() => _draft[_key(area.key, q.code, seq)] = v),
                          )),
                      const SizedBox(height: 8),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class _QuestionRow extends StatelessWidget {
  const _QuestionRow({
    required this.areaKey,
    required this.q,
    required this.value,
    required this.onChanged,
  });
  final String areaKey;
  final AutismQuestion q;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final List<String> ratings = autismRatingsFor(areaKey);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 34,
            child: Text(q.code, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (q.scope.isNotEmpty)
                  Text(q.scope,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                Text(q.name),
                if (q.refAge.isNotEmpty)
                  Text('参考年龄：${q.refAge}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Wrap(
            spacing: 4,
            children: ratings
                .map((r) => ChoiceChip(
                      label: Text(r),
                      selected: value == r,
                      onSelected: (_) => onChanged(value == r ? null : r),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}
