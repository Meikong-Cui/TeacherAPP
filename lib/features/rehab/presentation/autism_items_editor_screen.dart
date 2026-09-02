import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:teacher_app/data/models/autism_eval_item.dart';
import 'package:teacher_app/features/rehab/data/autism_questions.dart';
import 'package:teacher_app/features/rehab/provider/autism_eval_provider.dart';
import 'package:teacher_app/features/rehab/provider/rehab_provider.dart';
import 'package:teacher_app/shared/handwritten_uploader.dart';

/// 多量表评估录入：选择评估轮次 → 按量表题项逐题作答并保存。
///
/// - 残联标准(STANDARD)：题项来自本地 [autismQuestionAreas]（8 领域 + 情绪行为）。
/// - OFFLINE / VB：题项来自后端 [AutismEvalFormItem] 模板（树形：总项目 + 子项目）。
class AutismScaleEvalScreen extends ConsumerStatefulWidget {
  const AutismScaleEvalScreen({
    required this.archiveId,
    this.formCode = '',
    super.key,
  });
  final String archiveId;
  final String formCode;

  @override
  ConsumerState<AutismScaleEvalScreen> createState() =>
      _AutismScaleEvalScreenState();
}

/// 题项树节点（OFFLINE / VB 等树形模板）。
class _Node {
  _Node(this.item, this.children);
  final AutismEvalFormItem item;
  final List<_Node> children;
}

class _AutismScaleEvalScreenState extends ConsumerState<AutismScaleEvalScreen> {
  String _formCode = '';
  String? _roundId;
  final Map<String, String?> _draft = <String, String?>{};
  bool _saving = false;
  bool _creating = false;
  /// VB 一键答题循环下标：每点一次所有题切到自己那一档的「下一个选项」
  /// （按 options_json 顺序；越界时落到末项）。下一次点击前 +1。
  int _cycleIdx = 0;

  @override
  void initState() {
    super.initState();
    _formCode = widget.formCode;
    Future.microtask(_resolveForm);
  }

  Future<void> _resolveForm() async {
    String fc = widget.formCode;
    if (fc.isEmpty) {
      // 优先尝试从档案详情读取默认量表（保持兼容老数据 / OA 网页直接进入的场景）。
      try {
        final detail = await ref
            .read(rehabRepositoryProvider)
            .getArchive(widget.archiveId);
        fc = detail.archive.evalFormCode;
      } catch (_) {
        fc = '';
      }
    }
    if (!mounted) return;
    if (fc.isEmpty) {
      // 拿不到量表代码时不再硬塞 STANDARD——把选择权交回给用户。
      setState(() => _formCode = '__PICK__');
      return;
    }
    setState(() => _formCode = fc);
  }

  String _key(String areaKey, String itemCode) => '$areaKey|$itemCode';

  List<(String, String)> _choicesForStandard(String areaKey) =>
      autismRatingsFor(areaKey).map((r) => (r, r)).toList();

  List<(String, String)> _choicesForItem(AutismEvalFormItem it) {
    if (it.options.isNotEmpty) {
      return it.options.map((o) => (o.code, o.label)).toList();
    }
    // 兜底：无选项模板按 通过/未通过
    return const <(String, String)>[
      ('P', '通过'),
      ('F', '未通过'),
    ];
  }

  String? _selectedLabel(List<(String, String)> choices, String? code) {
    if (code == null) return null;
    for (final c in choices) {
      if (c.$1 == code) return c.$2;
    }
    return code;
  }

  Future<void> _loadRound(String roundId) async {
    setState(() => _roundId = roundId);
    final EvalRoundItemsNotifier notifier =
        ref.read(evalRoundItemsProvider(roundId).notifier);
    await notifier.load();
    if (!mounted) return;
    _draft.clear();
    for (final AutismEvalItem it in notifier.state.items) {
      _draft[_key(it.areaKey, it.itemCode)] = it.rating;
    }
    setState(() {});
  }

  Future<void> _createRound() async {
    setState(() => _creating = true);
    try {
      final String id = await ref
          .read(rehabRepositoryProvider)
          .createEvalRound(AutismEvalRound(
            archiveId: widget.archiveId,
            formCode: _formCode,
            evalDate: DateTime.now(),
            status: 1,
          ));
      if (!mounted) return;
      if (id.isEmpty) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('创建评估轮次失败')));
        return;
      }
      ref.invalidate(evalRoundsProvider('${widget.archiveId}|$_formCode'));
      await _loadRound(id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('创建失败：$e')));
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _save() async {
    if (_roundId == null || _roundId!.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请先创建或选择一次评估')));
      return;
    }
    setState(() => _saving = true);
    final List<AutismEvalItem> batch = <AutismEvalItem>[];

    if (_formCode == 'STANDARD') {
      for (final AutismQuestionArea area in autismQuestionAreas) {
        for (final AutismQuestion q in area.items) {
          final String? v = _draft[_key(area.key, q.code)];
          batch.add(AutismEvalItem(
            archiveId: widget.archiveId,
            formCode: _formCode,
            roundId: int.tryParse(_roundId!) ?? 0,
            areaKey: area.key,
            itemCode: q.code,
            itemName: q.name,
            itemScope: q.scope.isEmpty ? null : q.scope,
            refAge: q.refAge.isEmpty ? null : q.refAge,
            rating: v,
          ));
        }
      }
    } else {
      final List<AutismEvalFormItem>? items =
          ref.read(evalFormItemsProvider(_formCode)).value;
      if (items != null) {
        final List<_Node> tree = _buildTree(items);
        for (final _Node leaf in _leaves(tree)) {
          final String? v = _draft[_key(leaf.item.areaKey ?? 'other', leaf.item.itemCode)];
          batch.add(AutismEvalItem(
            archiveId: widget.archiveId,
            formCode: _formCode,
            roundId: int.tryParse(_roundId!) ?? 0,
            formItemId: leaf.item.id,
            areaKey: leaf.item.areaKey ?? 'other',
            itemCode: leaf.item.itemCode,
            itemName: leaf.item.itemName,
            itemType: 'item',
            itemScope: leaf.item.itemScope,
            ageMinMonths: leaf.item.ageMinMonths,
            ageMaxMonths: leaf.item.ageMaxMonths,
            rating: v,
            optionLabel: _selectedLabel(_choicesForItem(leaf.item), v),
          ));
        }
      }
    }

    final bool ok = await ref
        .read(evalRoundItemsProvider(_roundId!).notifier)
        .save(batch);

    // VB 表单：保存后自动计分（接口幂等：再次调用会重写 score_summary），
    // 并将流程推向「VB 评估结果」页（与线下模板的引导式流程统一）。
    // 该结果页自带 PopScope 回儿童详情，不再弹 dialog。
    if (ok && _formCode.startsWith('VB') && _roundId != null && _roundId!.isNotEmpty) {
      try {
        await ref.read(rehabRepositoryProvider).vbScore(_roundId!);
      } catch (_) {
        // 计分失败不阻断进入结果页：结果页再试一次。
      }
      if (!mounted) return;
      ref.invalidate(evalRoundsProvider('${widget.archiveId}|$_formCode'));
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已提交，正在出分…')));
      setState(() => _saving = false);
      context.pushReplacement(
        '/rehab-autism/${widget.archiveId}/vb-submit'
        '?round=$_roundId'
        '&form=$_formCode'
        '&label=${Uri.encodeQueryComponent(_formShortLabel())}',
      );
      return;
    }

    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? '已保存 ${batch.length} 题评分' : '保存失败，请重试'),
      ));
    }
  }

  // —— 树形模板工具 ——
  List<_Node> _buildTree(List<AutismEvalFormItem> items) {
    final Map<int, _Node> byId = <int, _Node>{};
    for (final AutismEvalFormItem it in items) {
      if (it.id != null) byId[it.id!] = _Node(it, <_Node>[]);
    }
    final List<_Node> roots = <_Node>[];
    for (final _Node node in byId.values) {
      final int? pid = node.item.parentId;
      if (pid != null && byId.containsKey(pid)) {
        byId[pid]!.children.add(node);
      } else {
        roots.add(node);
      }
    }
    return roots;
  }

  /// VB 题项为扁平结构（无 parentId），按 areaKey（维度）分组为折叠分组节点。
  List<_Node> _vbTree(List<AutismEvalFormItem> items) {
    final Map<String, List<AutismEvalFormItem>> byArea =
        <String, List<AutismEvalFormItem>>{};
    for (final AutismEvalFormItem it in items) {
      final String key = it.areaKey ?? '其他';
      byArea.putIfAbsent(key, () => <AutismEvalFormItem>[]).add(it);
    }
    final List<_Node> roots = <_Node>[];
    byArea.forEach((area, list) {
      final AutismEvalFormItem groupItem = AutismEvalFormItem(
        formCode: _formCode,
        itemCode: area,
        itemName: area,
        itemType: 'group',
      );
      roots.add(_Node(
        groupItem,
        list.map((it) => _Node(it, <_Node>[])).toList(),
      ));
    });
    return roots;
  }

  List<_Node> _leaves(List<_Node> nodes) {
    final List<_Node> out = <_Node>[];
    for (final _Node n in nodes) {
      if (n.children.isEmpty) {
        out.add(n);
      } else {
        out.addAll(_leaves(n.children));
      }
    }
    return out;
  }

  /// VB 一键选择（仿「线下模板」单按钮循环）：
  /// 每点一次把所有题切到自己那一档的「下一个选项」（按 options_json 顺序）；
  /// 越界时落到末项，并不回 0，避免多次点击后「选项错乱」。
  /// 不触发保存/出分（出分由右上角「提交」按钮触发）。
  void _cycleFill() {
    final List<AutismEvalFormItem>? items =
        ref.read(evalFormItemsProvider(_formCode)).value;
    if (items == null) return;
    final List<_Node> tree = _vbTree(items);
    final List<_Node> leaves = _leaves(tree);
    String? filledLabel;
    setState(() {
      for (final _Node node in leaves) {
        final String key = '${node.item.areaKey ?? 'other'}|${node.item.itemCode}';
        final List<(String, String)> choices = _choicesForItem(node.item);
        if (choices.isEmpty) continue;
        final int pos = _cycleIdx < choices.length
            ? _cycleIdx
            : choices.length - 1;
        _draft[key] = choices[pos].$1;
        filledLabel ??= choices[pos].$2;
      }
      _cycleIdx++;
    });
    if (filledLabel != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已一键全选「$filledLabel」，确认后点右上角「提交」出分'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// VB 一键答题按钮（单按钮循环，issue 1）。按钮 label 显示下一档要切到的选项 label。
  Widget _buildVbQuickFill(
      AsyncValue<List<AutismEvalFormItem>>? formItemsAsync) {
    return formItemsAsync?.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (items) {
            final List<_Node> leaves = _leaves(_vbTree(items));
            if (leaves.isEmpty) return const SizedBox.shrink();
            // 按钮 label 取首题下一档的 label；档位越界时显示末项。
            final List<(String, String)> firstChoices =
                _choicesForItem(leaves.first.item);
            if (firstChoices.isEmpty) return const SizedBox.shrink();
            final int pos = _cycleIdx < firstChoices.length
                ? _cycleIdx
                : firstChoices.length - 1;
            final String nextLabel = firstChoices[pos].$2;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.flash_on),
                  label: Text('一键全选「$nextLabel」'),
                  onPressed: _saving ? null : _cycleFill,
                ),
              ),
            );
          },
        ) ??
        const SizedBox.shrink();
  }

  String _formShortLabel() {
    switch (_formCode) {
      case 'VB_PARENT':
        return '家长卷';
      case 'VB_TEACHER':
        return '教师卷';
      case 'VB':
        return 'VB';
      default:
        return _formCode;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_formCode == '__PICK__') {
      return Scaffold(
        appBar: AppBar(title: const Text('选择评测量表')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(Icons.help_outline, size: 48, color: Colors.orange),
                const SizedBox(height: 12),
                const Text(
                  '该档案尚未绑定评测量表。\n请回到上一页选择量表后再开始作答。',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () =>
                      context.pushReplacement('/rehab-autism/${widget.archiveId}/scale-picker'),
                  child: const Text('去选择量表'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (_formCode.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_formCode == 'PEP3') {
      // PEP-3 不答 A/B 卷，没有题项可录入——引导到「填预估月龄」页。
      return Scaffold(
        appBar: AppBar(title: const Text('PEP-3 评估')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(Icons.child_care_outlined, size: 48, color: Colors.indigo),
                const SizedBox(height: 12),
                const Text(
                  'PEP-3 不需要录入题目。\n请直接填写各领域的预估年龄，提交后自动生成报告。',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => context.pushReplacement(
                      '/rehab-autism/${widget.archiveId}/pep3-home'),
                  child: const Text('去填写预估年龄'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final AsyncValue<List<AutismEvalRound>> roundsAsync =
        ref.watch(evalRoundsProvider('${widget.archiveId}|$_formCode'));
    final AsyncValue<List<AutismEvalFormItem>>? formItemsAsync =
        _formCode == 'STANDARD' ? null : ref.watch(evalFormItemsProvider(_formCode));
    final EvalRoundItemsState? roundState =
        _roundId != null ? ref.watch(evalRoundItemsProvider(_roundId!)) : null;

    final bool busy = _saving || _creating || (roundState?.loading ?? false);
    final bool isVb = _formCode.startsWith('VB');

    return Scaffold(
      appBar: AppBar(
        title: Text(_formLabel()),
        actions: <Widget>[
          if (isVb)
            IconButton(
              icon: const Icon(Icons.show_chart),
              tooltip: '查看评估趋势',
              onPressed: () => context.push(
                '/rehab-autism/${widget.archiveId}/vb-trend?form=$_formCode',
              ),
            ),
          if (busy)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(
                  width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            // 仿「线下模板」答题页：保存图标改为右上角文字「提交」按钮，
            // 更贴合引导式流程（点击后即出分或给出错误）。
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: TextButton(
                onPressed: _roundId == null || _roundId!.isEmpty ? null : _save,
                style: TextButton.styleFrom(
                  textStyle: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15),
                ),
                child: const Text('提交'),
              ),
            ),
        ],
      ),
      body: roundsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载评估轮次失败：$e')),
        data: (rounds) => ListView(
          padding: const EdgeInsets.all(12),
          children: <Widget>[
            if (_formCode == 'STANDARD')
              HandwrittenUploader(
                archiveId: widget.archiveId,
                section: 'STANDARD_FORM',
                title: '评测量表 · 手写板',
                compact: true,
              ),
            if (_formCode == 'STANDARD') const SizedBox(height: 12),
            _RoundSelector(
              rounds: rounds,
              selectedId: _roundId,
              creating: _creating,
              onCreate: _createRound,
              onSelect: _loadRound,
            ),
            if (isVb && _roundId != null && _roundId!.isNotEmpty)
              _buildVbQuickFill(formItemsAsync),
            const SizedBox(height: 12),
            if (_roundId == null || _roundId!.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('请创建一次评估，或选择已有评估轮次后开始作答。'),
                ),
              )
            else if (_formCode == 'STANDARD')
              ..._standardCards()
            else
              formItemsAsync == null
                  ? const Center(child: CircularProgressIndicator())
                  : formItemsAsync.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Center(child: Text('加载题项失败：$e')),
                      data: (items) => Column(
                        children: _formCards(
                          _formCode.startsWith('VB')
                              ? _vbTree(items)
                              : _buildTree(items),
                        ),
                      ),
                    ),
          ],
        ),
      ),
    );
  }

  String _formLabel() {
    switch (_formCode) {
      case 'OFFLINE':
        return 'C-PEP3 评估录入';
      case 'VB_PARENT':
        return 'VB 家长卷评估录入';
      case 'VB_TEACHER':
        return 'VB 教师卷评估录入';
      case 'VB':
        return 'VB 评估录入';
      case 'PEP3':
        return 'PEP-3 评估录入';
      case 'STANDARD':
      default:
        return '残联标准评估录入';
    }
  }

  List<Widget> _standardCards() {
    final List<Widget> cards = <Widget>[];
    for (final AutismQuestionArea area in autismQuestionAreas) {
      final int answered = area.items
          .where((q) => _draft[_key(area.key, q.code)] != null)
          .length;
      cards.add(Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: ExpansionTile(
          initiallyExpanded: cards.isEmpty,
          title: Text(area.label),
          subtitle: Text('已评 $answered / ${area.items.length}'),
          children: <Widget>[
            ...area.items.map((q) => _RatingRow(
                  name: q.name,
                  scope: q.scope,
                  refAge: q.refAge,
                  choices: _choicesForStandard(area.key),
                  value: _draft[_key(area.key, q.code)],
                  onChanged: (v) =>
                      setState(() => _draft[_key(area.key, q.code)] = v),
                )),
            const SizedBox(height: 8),
          ],
        ),
      ));
    }
    return cards;
  }

  List<Widget> _formCards(List<_Node> roots) {
    final List<Widget> out = <Widget>[];
    for (final _Node root in roots) {
      out.add(_GroupTile(node: root, draft: _draft, onChange: (k, v) => setState(() => _draft[k] = v)));
    }
    return out;
  }
}

/// 轮次选择器（已有轮次 chips + 新建）。
class _RoundSelector extends StatelessWidget {
  const _RoundSelector({
    required this.rounds,
    required this.selectedId,
    required this.creating,
    required this.onCreate,
    required this.onSelect,
  });
  final List<AutismEvalRound> rounds;
  final String? selectedId;
  final bool creating;
  final Future<void> Function() onCreate;
  final Future<void> Function(String) onSelect;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            const Text('评估轮次：', style: TextStyle(fontWeight: FontWeight.w700)),
            ...rounds.map((r) => ChoiceChip(
                  label: Text('第${r.evalSeq ?? '?'}次'
                      '${r.evalDate != null ? '（${r.evalDate!.month}/${r.evalDate!.day}）' : ''}'),
                  selected: r.id?.toString() == selectedId,
                  onSelected: (_) => onSelect(r.id.toString()),
                )),
            if (creating)
              const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
            else
              OutlinedButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add),
                label: const Text('新建评估'),
              ),
          ],
        ),
      ),
    );
  }
}

/// 单个可作答题行（通用：支持任意选项列表）。
class _RatingRow extends StatelessWidget {
  const _RatingRow({
    required this.name,
    this.scope,
    this.refAge,
    required this.choices,
    required this.value,
    required this.onChanged,
  });
  final String name;
  final String? scope;
  final String? refAge;
  final List<(String, String)> choices;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (scope != null && scope!.isNotEmpty)
                  Text(scope!,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                Text(name),
                if (refAge != null && refAge!.isNotEmpty)
                  Text('参考年龄：${refAge!}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Wrap(
            spacing: 4,
            children: choices
                .map((c) => ChoiceChip(
                      label: Text(c.$2),
                      selected: value == c.$1,
                      onSelected: (_) => onChanged(value == c.$1 ? null : c.$1),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

/// 题项分组（树形）：有子项则折叠展开，叶子为可作答行。
class _GroupTile extends StatelessWidget {
  const _GroupTile({
    required this.node,
    required this.draft,
    required this.onChange,
  });
  final _Node node;
  final Map<String, String?> draft;
  final void Function(String key, String?) onChange;

  @override
  Widget build(BuildContext context) {
    if (node.children.isNotEmpty) {
      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: ExpansionTile(
          initiallyExpanded: true,
          title: Text(node.item.itemName),
          subtitle: node.item.remark != null && node.item.remark!.isNotEmpty
              ? Text(node.item.remark!,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600))
              : null,
          children: <Widget>[
            ...node.children
                .map((c) => _GroupTile(node: c, draft: draft, onChange: onChange)),
          ],
        ),
      );
    }
    final String key = '${node.item.areaKey ?? 'other'}|${node.item.itemCode}';
    final List<(String, String)> choices = node.item.options.isNotEmpty
        ? node.item.options.map((o) => (o.code, o.label)).toList()
        : const <(String, String)>[
            ('P', '通过'),
            ('F', '未通过'),
          ];
    return _RatingRow(
      name: node.item.itemName,
      scope: node.item.itemScope,
      refAge: node.item.ageMinMonths != null
          ? '${node.item.ageMinMonths}~${node.item.ageMaxMonths ?? ''} 月'
          : null,
      choices: choices,
      value: draft[key],
      onChanged: (v) => onChange(key, v),
    );
  }
}
