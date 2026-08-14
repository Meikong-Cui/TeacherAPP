import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:teacher_app/data/models/iep_plan.dart';
import 'package:teacher_app/features/rehab/provider/iep_provider.dart';
import 'package:teacher_app/features/rehab/provider/rehab_provider.dart';

/// 添加 IEP 项目页（独立页面）。
///
/// 从后端拉取模板库，按「年龄段 → 领域 → 子领域」组织；
/// 用户勾选目标，点「确认添加」后写回后端（重复添加只显示一个，由后端按 templateId 去重）。
class AddIepGoalScreen extends ConsumerStatefulWidget {
  const AddIepGoalScreen({required this.archiveId, super.key});
  final String archiveId;

  @override
  ConsumerState<AddIepGoalScreen> createState() => _AddIepGoalScreenState();
}

class _AddIepGoalScreenState extends ConsumerState<AddIepGoalScreen> {
  bool _loading = true;
  String? _error;
  List<String> _ageBands = kIepAgeBands;
  String _ageBand = '';
  List<IepTemplateGroup> _groups = const <IepTemplateGroup>[];
  String _domain = '';

  /// 本次新勾选的模板 id（已存在于计划的会被禁用，不计入）。
  final Set<int> _selected = <int>{};
  /// 已存在于后端计划的模板 id（禁用，避免重复添加）。
  final Set<int> _existing = <int>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(rehabRepositoryProvider);
      final List<String> bands = await repo.listIepAgeBands();
      final IepPlan plan = await repo.getIepPlan(widget.archiveId);
      _existing.clear();
      for (final g in plan.goals) {
        if (g.templateId != null) _existing.add(g.templateId!);
      }
      if (bands.isNotEmpty) _ageBand = bands.first;
      _ageBands = bands.isNotEmpty ? bands : kIepAgeBands;
      await _loadGrouped();
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) setState(() => _error = '加载失败：$e');
    }
  }

  Future<void> _loadGrouped() async {
    final repo = ref.read(rehabRepositoryProvider);
    _groups = await repo.listIepTemplatesGrouped(ageBand: _ageBand);
    if (_groups.isNotEmpty && _groups.first.domains.isNotEmpty) {
      _domain = _groups.first.domains.first.domain;
    } else {
      _domain = '';
    }
  }

  Future<void> _changeAgeBand(String ab) async {
    setState(() {
      _ageBand = ab;
      _loading = true;
    });
    await _loadGrouped();
    if (mounted) setState(() => _loading = false);
  }

  IepTemplateDomain? get _currentDomain {
    for (final g in _groups) {
      for (final d in g.domains) {
        if (d.domain == _domain) return d;
      }
    }
    return null;
  }

  List<int> get _newlySelected =>
      _selected.where((id) => !_existing.contains(id)).toList();

  Future<void> _confirm() async {
    final newly = _newlySelected;
    if (newly.isEmpty) {
      context.pop();
      return;
    }
    await ref
        .read(iepPlanProvider(widget.archiveId).notifier)
        .addTemplateIds(newly);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final int newCount = _newlySelected.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('添加 IEP 项目'),
        actions: <Widget>[
          TextButton.icon(
            onPressed: _loading ? null : _confirm,
            icon: const Icon(Icons.check),
            label: Text(newCount > 0 ? '确认添加 ($newCount)' : '确认添加'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error!,
                        style: TextStyle(color: colors.error)),
                  ),
                )
              : Column(
                  children: <Widget>[
                    // 年龄段选择
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: DropdownButtonFormField<String>(
                        initialValue: _ageBand,
                        decoration: const InputDecoration(
                          labelText: '年龄段',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        items: _ageBands
                            .map((ab) => DropdownMenuItem<String>(
                                  value: ab,
                                  child: Text(ab),
                                ))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) _changeAgeBand(v);
                        },
                      ),
                    ),
                    // 领域 Tab（按类型区分）
                    if (_groups.isNotEmpty &&
                        _groups.first.domains.isNotEmpty)
                      SizedBox(
                        height: 44,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _groups.first.domains.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, i) {
                            final d = _groups.first.domains[i];
                            final bool active = d.domain == _domain;
                            return ChoiceChip(
                              label: Text(d.domain),
                              selected: active,
                              onSelected: (_) =>
                                  setState(() => _domain = d.domain),
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 4),
                    // 子领域 → 模板条目
                    Expanded(
                      child: _currentDomain == null
                          ? const Center(child: Text('该年龄段暂无模板'))
                          : ListView(
                              padding: const EdgeInsets.all(16),
                              children: <Widget>[
                                for (final sub in _currentDomain!.subDomains)
                                  _SubSection(
                                    sub: sub,
                                    existing: _existing,
                                    selected: _selected,
                                    onToggle: (id) => setState(() {
                                      if (_existing.contains(id)) return;
                                      if (_selected.contains(id)) {
                                        _selected.remove(id);
                                      } else {
                                        _selected.add(id);
                                      }
                                    }),
                                  ),
                                const SizedBox(height: 16),
                              ],
                            ),
                    ),
                  ],
                ),
      bottomNavigationBar: _newlySelected.isEmpty
          ? null
          : SafeArea(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: colors.surface,
                  border:
                      Border(top: BorderSide(color: colors.outlineVariant)),
                ),
                child: Row(
                  children: <Widget>[
                    Text('已选 $_newlySelected 项',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const Spacer(),
                    TextButton(
                      onPressed: () =>
                          setState(() => _selected.removeAll(_selected.where(
                              (id) => !_existing.contains(id)))),
                      child: const Text('清空'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: _confirm,
                      icon: const Icon(Icons.check),
                      label: const Text('确认添加'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

/// 子领域分区：列出该子领域下的所有模板条目（可勾选）。
class _SubSection extends StatelessWidget {
  const _SubSection({
    required this.sub,
    required this.existing,
    required this.selected,
    required this.onToggle,
  });
  final IepTemplateSub sub;
  final Set<int> existing;
  final Set<int> selected;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(top: 12, left: 4, bottom: 6),
          child: Text(sub.subDomain,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w800, color: colors.primary)),
        ),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: sub.items.map((e) {
              final bool isExisting = existing.contains(e.id);
              final bool checked = selected.contains(e.id) || isExisting;
              final Color border =
                  checked ? const Color(0xFF2563EB) : Colors.transparent;
              return InkWell(
                onTap: isExisting ? null : () => onToggle(e.id),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(left: BorderSide(color: border, width: 3)),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(
                        checked ? Icons.check_box : Icons.check_box_outline_blank,
                        color: isExisting
                            ? colors.onSurfaceVariant
                            : (checked ? const Color(0xFF2563EB) : colors.onSurfaceVariant),
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(e.interventionGoal,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Text(e.stageGoal,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: colors.onSurfaceVariant)),
                            const SizedBox(height: 6),
                            if (isExisting)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: colors.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text('已添加',
                                    style: TextStyle(fontSize: 10)),
                              )
                            else
                              Text('未添加',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: colors.onSurfaceVariant)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
