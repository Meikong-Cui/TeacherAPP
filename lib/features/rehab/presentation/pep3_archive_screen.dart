import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:teacher_app/features/rehab/data/rehab_repository.dart';
import 'package:teacher_app/features/rehab/provider/rehab_provider.dart';

/// PEP-3 模板：完全复刻线下模板（C-PEP3）的 9 行评估报告，但去掉 A/B 卷答题阶段。
///
/// 流程：新建评估 → 直接填 9 个领域的预估年龄（月）→ 提交 → 评估结果页
///      （档位解析 + 教师版/家长版报告，可挑选小项并导出 PDF）。
/// 报告内容与线下模板同构（项目 / 参考年龄 / 康复目标 / 指导说明），
/// 只是得分来源从「逐题计分」换成「教师填的月龄反查分档」。

/// 9 个报告项目固定顺序（与后端 Pep3TemplateService.PROJECTS 一致）。
const List<String> kPep3Projects = <String>[
  '模仿',
  '知觉',
  '精细动作',
  '粗大动作',
  '手眼协调',
  '认知表现',
  '口语认知',
  '适应行为',
  '个人自理',
];

/// 前 7 项为发展领域，后 2 项（适应行为 / 个人自理）为综合项。
const List<String> kPep3Domains = <String>[
  '模仿',
  '知觉',
  '精细动作',
  '粗大动作',
  '手眼协调',
  '认知表现',
  '口语认知',
];

/// 单个年龄档（与后端 Pep3TemplateService.Band 对应）。
class _Band {
  const _Band(this.min, this.max, this.label);
  final int min;
  final int max;
  final String label;
}

/// 按年龄定位档位：优先精确命中，否则取区间距离最近的档（并列取更高的档）。
/// 逻辑与后端 Pep3TemplateService.matchBand 保持一致，保证前后端档位提示一致。
_Band? _matchBand(List<_Band> bands, int months) {
  if (bands.isEmpty) return null;
  final List<_Band> sorted = List<_Band>.of(bands)
    ..sort((_Band a, _Band b) => b.min.compareTo(a.min));
  _Band? best;
  int bestDist = 1 << 30;
  for (final _Band b in sorted) {
    if (months >= b.min && months <= b.max) return b;
    final int dist = months < b.min ? b.min - months : months - b.max;
    if (dist < bestDist) {
      bestDist = dist;
      best = b;
    }
  }
  return best;
}

// =====================================================================
// PEP-3 首页：新建评估 + 历史评估记录
// =====================================================================

class Pep3ArchiveHome extends ConsumerStatefulWidget {
  const Pep3ArchiveHome({required this.archiveId, super.key});
  final String archiveId;

  @override
  ConsumerState<Pep3ArchiveHome> createState() => _Pep3ArchiveHomeState();
}

class _Pep3ArchiveHomeState extends ConsumerState<Pep3ArchiveHome> {
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
          .listPep3Rounds(widget.archiveId);
    } catch (_) {
      // 无历史记录时后端返回空列表，忽略异常。
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('PEP-3 评估')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          _bigStartCard(context, colors),
          const SizedBox(height: 16),
          _sectionTitle(context, '历史评估记录'),
          _roundsSection(context),
        ],
      ),
    );
  }

  Widget _bigStartCard(BuildContext context, ColorScheme colors) {
    return Card(
      color: colors.primary,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context
            .push('/rehab-autism/${widget.archiveId}/pep3-new')
            .then((_) => _load()),
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
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('新建评估',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 20)),
                    SizedBox(height: 6),
                    Text('填 9 个领域的预估年龄 → 提交后直接出报告',
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
          child: Text(
            '暂无历史评估记录。点上方「新建评估」填写各领域预估年龄并提交，'
            '本次评估会自动出现在这里。',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }
    return Column(
      children: _rounds.map((Map<String, dynamic> r) => _roundCard(context, r)).toList(),
    );
  }

  Widget _roundCard(BuildContext context, Map<String, dynamic> r) {
    final int seq = r['evalSeq'] is int ? r['evalSeq'] as int : 0;
    final String date = r['evalDate']?.toString() ?? '';
    final String roundId = r['id']?.toString() ?? '';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
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
                  Text(
                    date.substring(0, date.length >= 10 ? 10 : date.length),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => context.push(
                        '/rehab/${widget.archiveId}/pep3-round/$roundId?role=TEACHER'),
                    icon: const Icon(Icons.visibility_outlined, size: 18),
                    label: const Text('教师版'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => context.push(
                        '/rehab/${widget.archiveId}/pep3-round/$roundId?role=PARENT'),
                    icon: const Icon(Icons.visibility_outlined, size: 18),
                    label: const Text('家长版'),
                  ),
                ),
                IconButton(
                  tooltip: '重新填写月龄',
                  onPressed: () => context
                      .push('/rehab-autism/${widget.archiveId}/pep3-new?round=$roundId')
                      .then((_) => _load()),
                  icon: Icon(Icons.edit_outlined,
                      color: Theme.of(context).colorScheme.primary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// PEP-3 年龄填写页
// =====================================================================

class Pep3AgeInputScreen extends ConsumerStatefulWidget {
  const Pep3AgeInputScreen({
    required this.archiveId,
    this.roundId,
    super.key,
  });
  final String archiveId;
  /// 非空表示编辑既有轮次（重填月龄并重出报告）。
  final String? roundId;

  @override
  ConsumerState<Pep3AgeInputScreen> createState() => _Pep3AgeInputScreenState();
}

class _Pep3AgeInputScreenState extends ConsumerState<Pep3AgeInputScreen> {
  final Map<String, TextEditingController> _ctrl =
      <String, TextEditingController>{};
  Map<String, List<_Band>> _bands = <String, List<_Band>>{};
  bool _loading = true;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.roundId != null && widget.roundId!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    for (final String p in kPep3Projects) {
      _ctrl[p] = TextEditingController();
    }
    _load();
  }

  @override
  void dispose() {
    for (final TextEditingController c in _ctrl.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final RehabRepository repo = ref.read(rehabRepositoryProvider);
      final Map<String, dynamic> bandsRes = await repo.getPep3AgeBands();
      final Map<String, dynamic> rawBands = bandsRes['bands'] is Map
          ? bandsRes['bands'] as Map<String, dynamic>
          : <String, dynamic>{};
      final Map<String, List<_Band>> bands = <String, List<_Band>>{};
      rawBands.forEach((String key, dynamic value) {
        if (value is! List) return;
        bands[key] = value
            .whereType<Map<String, dynamic>>()
            .map((Map<String, dynamic> b) => _Band(
                  b['min'] is int ? b['min'] as int : 0,
                  b['max'] is int ? b['max'] as int : 0,
                  b['label']?.toString() ?? '',
                ))
            .toList();
      });
      // 编辑既有轮次：回填上次填写的月龄。
      if (_isEdit) {
        final Map<String, dynamic>? round =
            await repo.getPep3Round(widget.roundId!);
        final Map<String, dynamic> ages = round?['ages'] is Map
            ? round!['ages'] as Map<String, dynamic>
            : <String, dynamic>{};
        ages.forEach((String k, dynamic v) {
          if (_ctrl.containsKey(k) && v != null) {
            _ctrl[k]!.text = v.toString();
          }
        });
      }
      _bands = bands;
      _error = null;
    } catch (e) {
      _error = '加载失败：$e';
    }
    if (mounted) setState(() => _loading = false);
  }

  /// 当前填的月龄（非法/空的不计入）。
  Map<String, int> get _ages {
    final Map<String, int> out = <String, int>{};
    _ctrl.forEach((String p, TextEditingController c) {
      final int? v = int.tryParse(c.text.trim());
      if (v != null) out[p] = v;
    });
    return out;
  }

  Future<void> _submit() async {
    final Map<String, int> ages = _ages;
    if (ages.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请至少填写一个领域的预估年龄')));
      return;
    }
    setState(() => _saving = true);
    try {
      final RehabRepository repo = ref.read(rehabRepositoryProvider);
      final String roundId;
      if (_isEdit) {
        await repo.updatePep3Round(widget.roundId!, ages);
        roundId = widget.roundId!;
      } else {
        roundId = (await repo.createPep3Round(widget.archiveId, ages)).toString();
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已提交，正在出报告…')));
      context.pushReplacement(
          '/rehab/${widget.archiveId}/pep3-submit?round=$roundId');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('提交失败：$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? '修改 PEP-3 评估' : 'PEP-3 新建评估'),
        actions: <Widget>[
          if (_saving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            TextButton(
              onPressed: _submit,
              child: const Text('提交'),
            ),
        ],
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
                      padding: const EdgeInsets.all(14),
                      child: Text(_error!,
                          style: TextStyle(color: colors.onErrorContainer)),
                    ),
                  ),
                Card(
                  color: colors.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: <Widget>[
                        Icon(Icons.help_outline, color: colors.onPrimaryContainer),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '直接填写各领域的预估年龄（单位：月），提交后按年龄归入对应档位，'
                            '生成与线下模板一致的 9 行评估报告。落空年龄会自动归入最近档位。',
                            style: TextStyle(
                                color: colors.onPrimaryContainer, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _sectionTitle(context, '发展领域'),
                ...kPep3Domains.map(_ageRow),
                _sectionTitle(context, '综合'),
                ...kPep3Projects
                    .where((String p) => !kPep3Domains.contains(p))
                    .map(_ageRow),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.check),
                    label: const Text('提交并出报告'),
                    onPressed: _saving ? null : _submit,
                  ),
                ),
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

  Widget _ageRow(String project) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final List<_Band> bands = _bands[project] ?? const <_Band>[];
    final TextEditingController c = _ctrl[project]!;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(project,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 16)),
                ),
                SizedBox(
                  width: 96,
                  child: TextField(
                    controller: c,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(
                      isDense: true,
                      hintText: '月龄',
                      suffixText: '月',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            _bandHint(project),
            if (bands.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: bands.map((_Band b) {
                  final int? cur = int.tryParse(c.text.trim());
                  final bool on = cur != null && cur >= b.min && cur <= b.max;
                  return ActionChip(
                    label: Text(b.label, style: const TextStyle(fontSize: 12)),
                    backgroundColor:
                        on ? colors.primaryContainer : null,
                    onPressed: () => setState(() => c.text = '${b.min}'),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 档位提示：显示当前月龄命中的档位；未命中则提示将归入的最近档位。
  Widget _bandHint(String project) {
    final List<_Band> bands = _bands[project] ?? const <_Band>[];
    final String text = _ctrl[project]!.text.trim();
    if (text.isEmpty) {
      return const SizedBox.shrink();
    }
    final int? months = int.tryParse(text);
    final ColorScheme colors = Theme.of(context).colorScheme;
    if (months == null) {
      return const Text('请输入 0-80 的整数月龄',
          style: TextStyle(fontSize: 12, color: Colors.red));
    }
    final _Band? band = _matchBand(bands, months);
    if (band == null) {
      return const Text('该领域暂无可用档位',
          style: TextStyle(fontSize: 12, color: Colors.grey));
    }
    final bool exact = months >= band.min && months <= band.max;
    return Text(
      exact ? '归入档位：${band.label}' : '档位无精确匹配，将归入最近档位：${band.label}',
      style: TextStyle(
        fontSize: 12,
        color: exact ? colors.primary : Colors.orange.shade700,
      ),
    );
  }
}

// =====================================================================
// PEP-3 提交结果页
// =====================================================================

class Pep3SubmitResultScreen extends ConsumerStatefulWidget {
  const Pep3SubmitResultScreen({
    required this.archiveId,
    required this.roundId,
    super.key,
  });
  final String archiveId;
  final String roundId;

  @override
  ConsumerState<Pep3SubmitResultScreen> createState() =>
      _Pep3SubmitResultScreenState();
}

class _Pep3SubmitResultScreenState
    extends ConsumerState<Pep3SubmitResultScreen> {
  Map<String, dynamic>? _round;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _round = await ref
          .read(rehabRepositoryProvider)
          .getPep3Round(widget.roundId);
      _error = null;
    } catch (e) {
      _error = '出报告失败：$e';
    }
    if (mounted) setState(() => _loading = false);
  }

  /// 退出本页 = 回到儿童详情页（不再退回填写页，避免重复提交产生多余轮次）。
  void _backToChild() => context.go('/children/${widget.archiveId}');

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
                  if (_error != null)
                    Card(
                      color: colors.errorContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(_error!,
                            style: TextStyle(color: colors.onErrorContainer)),
                      ),
                    )
                  else
                    _bandCard(colors),
                  const SizedBox(height: 20),
                  _sectionTitle(context, '报告'),
                  _action(
                    context,
                    Icons.checklist,
                    '挑选康复目标 / 指导说明',
                    '勾选要纳入报告的小项，再导出教师版 / 家长版报告',
                    () => context.push(
                        '/rehab/${widget.archiveId}/pep3-guidance/${widget.roundId}'),
                  ),
                  _action(
                    context,
                    Icons.school_outlined,
                    '教师版评估报告',
                    '按所选小项查看并导出 PDF',
                    () => context.push(
                        '/rehab/${widget.archiveId}/pep3-round/${widget.roundId}?role=TEACHER'),
                  ),
                  _action(
                    context,
                    Icons.family_restroom_outlined,
                    '家长版评估报告',
                    '按所选小项查看并导出 PDF',
                    () => context.push(
                        '/rehab/${widget.archiveId}/pep3-round/${widget.roundId}?role=PARENT'),
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

  /// 年龄 → 档位 解析结果表。
  Widget _bandCard(ColorScheme colors) {
    final Map<String, dynamic> ages = _round?['ages'] is Map
        ? _round!['ages'] as Map<String, dynamic>
        : <String, dynamic>{};
    final List<Map<String, dynamic>> resolved =
        (_round?['result'] is List ? _round!['result'] as List : const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .toList();
    final Map<String, Map<String, dynamic>> byProject =
        <String, Map<String, dynamic>>{};
    for (final Map<String, dynamic> r in resolved) {
      final String p = r['project']?.toString() ?? '';
      if (p.isNotEmpty) byProject[p] = r;
    }
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
                const Text('年龄 → 档位',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const Spacer(),
                Text('第 ${_round?['evalSeq'] ?? '?'} 次',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, color: colors.primary)),
              ],
            ),
            const Divider(height: 20),
            ...kPep3Projects.map((String p) {
              final String age = ages[p]?.toString() ?? '';
              final String band = byProject[p]?['band']?.toString() ?? '';
              final bool matched = byProject[p]?['matched'] == true;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: <Widget>[
                    Expanded(child: Text(p)),
                    Text(age.isEmpty ? '未填写' : '$age 月',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 130,
                      child: Text(
                        matched ? band : '—',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 12,
                          color: matched
                              ? colors.primary
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _action(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
