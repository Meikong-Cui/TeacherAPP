import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:teacher_app/app/design_tokens.dart';
import 'package:teacher_app/data/models/rehab.dart';
import 'package:teacher_app/features/rehab/provider/rehab_provider.dart';
import 'package:teacher_app/shared/ui.dart';

/// 老师提意见时的快捷短语，降低「不知道该说什么」的门槛。
const List<String> kQuickReviseInstructions = <String>[
  '目标难度偏高，请下调一档',
  '目标太笼统，请拆成可观察的具体行为',
  '增加家庭指导的可操作步骤',
  '把语言目标按词汇 / 句长分层',
  '补充发音清晰度（音位）要求',
  '结合最新评估结果，减少已掌握的目标',
];

/// 听障档案 - 教学计划页（7 项目标）。
///
/// 分层约定（与后端 TeachingPlanAiService 一致）：
///   教学计划 = 按「每次持续评估」更新的两个月阶段目标，固定 7 项；
///   单课教案 = 依据教学计划写的每节课详细目标（见 LessonPlanSectionScreen）。
///
/// 因此本页只负责「AI 按最新评估生成 7 项目标」+「看/改这 7 项」+「与 AI 对话修改」，
/// 不再承担每节课的展开——那是单课教案页的事。
class PlanSectionScreen extends ConsumerWidget {
  const PlanSectionScreen({required this.archiveId, super.key});
  final String archiveId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final RehabArchiveDetailState st =
        ref.watch(rehabArchiveDetailProvider(archiveId));
    final RehabArchiveDetail? detail = st.detail;
    final List<RehabTeachingPlan> plans =
        detail?.plans ?? const <RehabTeachingPlan>[];
    final RehabTeachingPlan? current = detail?.latestPlan;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '教学计划',
          style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.w700, color: AppPalette.ink),
        ),
        actions: <Widget>[
          TextButton.icon(
            onPressed: () => _createPlan(context, ref),
            icon: const Icon(Icons.add, size: 18, color: AppPalette.brandDark),
            label: const Text(
              '手动新建',
              style: TextStyle(
                  color: AppPalette.brandDark, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: (st.loading && detail == null)
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async => ref
                  .read(rehabArchiveDetailProvider(archiveId).notifier)
                  .reload(),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: <Widget>[
                  _AiActionCard(
                    archiveId: archiveId,
                    detail: detail,
                    current: current,
                  ),
                  const SizedBox(height: 16),
                  const AppSectionTitle('当前计划（7 项目标）'),
                  if (current == null)
                    _EmptyPlanCard(onCreate: () => _createPlan(context, ref))
                  else
                    _PlanDetailCard(
                      plan: current,
                      onEdit: () => _showPlanEditDialog(context, ref, current),
                      onRevise: () => _showReviseSheet(context, ref, current),
                    ),
                  if (current != null && current.revisions.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 16),
                    const AppSectionTitle('AI 修改记录'),
                    _RevisionList(entries: current.revisions),
                  ],
                  if (current != null && plans.length > 1) ...<Widget>[
                    const SizedBox(height: 16),
                    AppSectionTitle('历史计划（${plans.length - 1}）'),
                    for (final RehabTeachingPlan p in plans)
                      if (p.id != current.id)
                        _HistoryPlanTile(
                          plan: p,
                          onTap: () => _showPlanEditDialog(context, ref, p),
                        ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  /// 手动新建教学计划：周期默认今天 ~ 两个月后（与「每 2 个月一次」的节奏一致）。
  Future<void> _createPlan(BuildContext context, WidgetRef ref) async {
    final DateTime now = DateTime.now();
    final RehabTeachingPlan plan = RehabTeachingPlan(
      archiveId: archiveId,
      planPeriodStart: now,
      planPeriodEnd: DateTime(now.year, now.month + 2, now.day),
      teacherName: '教师',
    );
    final RehabArchiveDetailNotifier notifier =
        ref.read(rehabArchiveDetailProvider(archiveId).notifier);
    final bool ok = await notifier.createPlan(plan);
    // 本页自行提示，清掉状态里的 message，避免退回档案详情页时被重复弹出。
    notifier.clearMessage();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? '教学计划已新建，可点「AI 按最新评估生成」' : '新建失败，请稍后再试'),
    ));
  }

  /// 编辑 7 项目标（老师手工微调）。
  void _showPlanEditDialog(
      BuildContext context, WidgetRef ref, RehabTeachingPlan plan) {
    final TextEditingController hearCtrl =
        TextEditingController(text: plan.hearingGoal);
    final TextEditingController speechCtrl =
        TextEditingController(text: plan.speechGoal);
    final TextEditingController langCtrl =
        TextEditingController(text: plan.languageGoal);
    final TextEditingController cognCtrl =
        TextEditingController(text: plan.cognitionGoal);
    final TextEditingController commCtrl =
        TextEditingController(text: plan.communicationGoal);
    final TextEditingController familyCtrl =
        TextEditingController(text: plan.familyGuidance);
    final TextEditingController otherCtrl =
        TextEditingController(text: plan.otherGoal);
    DateTime? start = plan.planPeriodStart;
    DateTime? end = plan.planPeriodEnd;

    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => StatefulBuilder(
        builder: (BuildContext ctx2, StateSetter setDlg) => AlertDialog(
          title: const Text('教学计划详情'),
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (plan.aiSourceLabel.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text('来源：${plan.aiSourceLabel}',
                          style: const TextStyle(
                              fontSize: AppFontSize.small,
                              color: AppPalette.inkMute)),
                    ),
                  _planDateRow(context, '开始日期', start,
                      (DateTime? v) => setDlg(() => start = v)),
                  const SizedBox(height: 8),
                  _planDateRow(context, '结束日期', end,
                      (DateTime? v) => setDlg(() => end = v)),
                  const SizedBox(height: 12),
                  _planField('听能目标', hearCtrl),
                  _planField('言语目标', speechCtrl),
                  _planField('语言目标', langCtrl),
                  _planField('认知目标', cognCtrl),
                  _planField('沟通目标', commCtrl),
                  _planField('家庭指导', familyCtrl),
                  _planField('其它目标与注意事项', otherCtrl),
                ],
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('取消')),
            FilledButton.tonal(
              onPressed: () async {
                final RehabTeachingPlan updated = plan.copyWith(
                  planPeriodStart: start,
                  planPeriodEnd: end,
                  hearingGoal: hearCtrl.text.trim(),
                  speechGoal: speechCtrl.text.trim(),
                  languageGoal: langCtrl.text.trim(),
                  cognitionGoal: cognCtrl.text.trim(),
                  communicationGoal: commCtrl.text.trim(),
                  familyGuidance: familyCtrl.text.trim(),
                  otherGoal: otherCtrl.text.trim(),
                );
                final RehabArchiveDetailNotifier notifier = ref
                    .read(rehabArchiveDetailProvider(archiveId).notifier);
                final bool ok = await notifier.updatePlan(updated);
                notifier.clearMessage();
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(ok ? '教学计划已保存' : '保存失败，请重试'),
                  ));
                }
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _planDateRow(BuildContext context, String label, DateTime? value,
      ValueChanged<DateTime?> onChanged) {
    return InkWell(
      onTap: () async {
        final DateTime? picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2040),
        );
        if (picked != null) onChanged(picked);
      },
      child: Row(children: <Widget>[
        SizedBox(
            width: 72,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 14, color: AppPalette.inkMute))),
        Expanded(
            child: Text(
          value == null ? '请选择' : DateFormat('yyyy-MM-dd').format(value),
          style: TextStyle(
              fontSize: 14,
              color: value == null ? AppPalette.inkMute : AppPalette.ink),
        )),
        const Icon(Icons.calendar_today, size: 18, color: AppPalette.inkMute),
      ]),
    );
  }

  Widget _planField(String label, TextEditingController ctrl) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          controller: ctrl,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          ),
          minLines: 2,
          maxLines: 4,
          style: const TextStyle(fontSize: 14),
        ),
      );

  /// 「与 AI 对话修改」：老师提意见 → 后端只重写涉及到的目标，其余原样保留。
  Future<void> _showReviseSheet(
      BuildContext context, WidgetRef ref, RehabTeachingPlan plan) async {
    final TextEditingController ctrl = TextEditingController();
    // 计划的 id 在 DTO 里可空（尚未落库），提到外面统一判断，避免在闭包里反复解包。
    final String planId = plan.id ?? '';
    bool busy = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext sheetCtx) => StatefulBuilder(
        builder: (BuildContext ctx, StateSetter setSheet) {
          final double keyboard = MediaQuery.of(ctx).viewInsets.bottom;
          return Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 16 + keyboard),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(children: const <Widget>[
                    Icon(Icons.forum_outlined, color: AppPalette.brandDark),
                    SizedBox(width: 8),
                    Text('与 AI 对话修改',
                        style: TextStyle(
                            fontSize: AppFontSize.subtitle,
                            fontWeight: FontWeight.bold)),
                  ]),
                  const SizedBox(height: 6),
                  const Text(
                    '说出哪里不满意即可。AI 只重写你提到的目标，其余目标保持原样。',
                    style: TextStyle(
                        fontSize: AppFontSize.small, color: AppPalette.inkMute),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      for (final String s in kQuickReviseInstructions)
                        ActionChip(
                          label: Text(s,
                              style:
                                  const TextStyle(fontSize: AppFontSize.small)),
                          onPressed: () => setSheet(() => ctrl.text = s),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: ctrl,
                    minLines: 3,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      labelText: '你的意见',
                      hintText: '例如：听能目标太难了，请下调到单音节识别',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                  ),
                  if (plan.aiFailed && (plan.aiError?.isNotEmpty ?? false)) ...<Widget>[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppPalette.danger.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '上次生成失败：${plan.aiError}',
                        style: const TextStyle(
                            fontSize: AppFontSize.small, color: AppPalette.danger),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: busy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.auto_awesome),
                      label: Text(busy ? '正在按你的意见重新生成…' : '提交意见，重新生成'),
                      onPressed: busy
                          ? null
                          : () async {
                              if (planId.isEmpty) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  const SnackBar(content: Text('该计划尚未保存，无法修改')),
                                );
                                return;
                              }
                              final String text = ctrl.text.trim();
                              if (text.isEmpty) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  const SnackBar(content: Text('请先写下你的意见')),
                                );
                                return;
                              }
                              setSheet(() => busy = true);
                              final RehabArchiveDetailNotifier notifier = ref
                                  .read(rehabArchiveDetailProvider(archiveId)
                                      .notifier);
                              final bool ok =
                                  await notifier.revisePlan(planId, text);
                              final String? err = ref
                                  .read(rehabArchiveDetailProvider(archiveId))
                                  .error;
                              notifier.clearMessage();
                              notifier.clearError();
                              if (!ctx.mounted) return;
                              setSheet(() => busy = false);
                              if (ok) {
                                Navigator.of(ctx).pop();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text('已按你的意见重新生成')),
                                  );
                                }
                              } else {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(
                                    content: Text(err?.replaceFirst('重新生成失败：', '') ??
                                        '重新生成失败，请稍后再试'),
                                  ),
                                );
                              }
                            },
                    ),
                  ),
                  if (plan.revisions.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 18),
                    const Text('修改记录',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    for (final PlanRevisionEntry r in plan.revisions.reversed)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text('第${r.round}轮',
                                style: const TextStyle(
                                    fontSize: AppFontSize.small,
                                    fontWeight: FontWeight.bold,
                                    color: AppPalette.brandDark)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(r.instruction,
                                  style: const TextStyle(
                                      fontSize: AppFontSize.small)),
                            ),
                            const SizedBox(width: 8),
                            Text(r.timeLabel,
                                style: const TextStyle(
                                    fontSize: AppFontSize.caption,
                                    color: AppPalette.inkMute)),
                          ],
                        ),
                      ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
    ctrl.dispose();
  }
}

/// 顶部 AI 操作卡：依据来源 + 生成按钮 + 额度提示。
class _AiActionCard extends ConsumerStatefulWidget {
  const _AiActionCard({
    required this.archiveId,
    required this.detail,
    required this.current,
  });

  final String archiveId;
  final RehabArchiveDetail? detail;
  final RehabTeachingPlan? current;

  @override
  ConsumerState<_AiActionCard> createState() => _AiActionCardState();
}

class _AiActionCardState extends ConsumerState<_AiActionCard> {
  Map<String, dynamic>? _quota;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadQuota();
  }

  @override
  void didUpdateWidget(covariant _AiActionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.current?.id != widget.current?.id) _loadQuota();
  }

  Future<void> _loadQuota() async {
    final String? id = widget.current?.id;
    if (id == null || id.isEmpty) return;
    try {
      final Map<String, dynamic> q =
          await ref.read(rehabRepositoryProvider).planQuota(id);
      if (mounted) setState(() => _quota = q);
    } catch (_) {
      // 额度查询失败不阻塞主流程（例如后端未启用 AI 时接口会报错）。
    }
  }

  /// 依据来源：优先最新一期已完成的持续评估，其次首次评估。
  String get _sourceHint {
    final RehabArchiveDetail? d = widget.detail;
    if (d == null) return '正在读取评估记录…';
    final RehabContEval? ce = d.latestCompletedContEval;
    if (ce != null) {
      final String seq = ce.evalSeq == null ? '' : ' 第${ce.evalSeq}期';
      return '依据：持续评估$seq · 之后每 2 个月更新一次';
    }
    if (d.hasFirstEval) return '依据：首次评估 · 之后每 2 个月按持续评估更新';
    return '尚无已完成评估：请先完成首次评估或持续评估，AI 才有依据';
  }

  Future<void> _generate() async {
    setState(() => _busy = true);
    final RehabArchiveDetailNotifier notifier =
        ref.read(rehabArchiveDetailProvider(widget.archiveId).notifier);
    try {
      String planId = widget.current?.id ?? '';
      // 没有计划记录时先建一版：AI 生成是挂在某份计划上的（POST /teaching-plan/{id}/generate）。
      if (planId.isEmpty) {
        final DateTime now = DateTime.now();
        final bool created = await notifier.createPlan(RehabTeachingPlan(
          archiveId: widget.archiveId,
          planPeriodStart: now,
          planPeriodEnd: DateTime(now.year, now.month + 2, now.day),
          teacherName: '教师',
        ));
        notifier.clearMessage();
        if (!created) {
          _toast('新建计划失败，无法生成');
          return;
        }
        await notifier.reload();
        planId = ref
                .read(rehabArchiveDetailProvider(widget.archiveId))
                .detail
                ?.latestPlan
                ?.id ??
            '';
      }
      if (planId.isEmpty) {
        _toast('新建计划失败，无法生成');
        return;
      }

      final bool ok = await notifier.aiGeneratePlan(planId);
      final String? err =
          ref.read(rehabArchiveDetailProvider(widget.archiveId)).error;
      notifier.clearMessage();
      notifier.clearError();
      if (!mounted) return;
      if (ok) {
        _toast('AI 已按最新评估生成 7 项目标');
      } else if (err != null && err.contains('额度')) {
        await showDialog<void>(
          context: context,
          builder: (BuildContext ctx) => AlertDialog(
            title: const Text('AI 额度不足'),
            content: Text(err.replaceFirst('AI 生成失败：', '')),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('我知道了'),
              ),
            ],
          ),
        );
      } else {
        _toast(err?.replaceFirst('AI 生成失败：', '') ?? 'AI 生成失败，请稍后再试');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
      _loadQuota();
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _money(dynamic v) =>
      v == null ? '—' : '¥${(v as num).toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    final RehabTeachingPlan? plan = widget.current;
    final bool running = _busy || (plan?.aiRunning ?? false);
    final Map<String, dynamic>? q = _quota;
    final bool aiEnabled = q == null || (q['enabled'] as bool? ?? true);

    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.auto_awesome_outlined,
                  color: AppPalette.brandDark),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  plan == null ? 'AI 生成教学计划' : 'AI 按最新评估重新生成',
                  style: const TextStyle(
                      fontSize: AppFontSize.title,
                      fontWeight: FontWeight.bold,
                      color: AppPalette.ink),
                ),
              ),
              if (plan?.aiFailed ?? false)
                const Icon(Icons.error_outline,
                    size: 18, color: AppPalette.danger),
            ],
          ),
          const SizedBox(height: 6),
          Text(_sourceHint,
              style: const TextStyle(
                  fontSize: AppFontSize.small, color: AppPalette.inkMute)),
          if (plan?.aiSourceLabel != null && plan!.aiSourceLabel.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Text('当前这版：${plan.aiSourceLabel}',
                style: const TextStyle(
                    fontSize: AppFontSize.small, color: AppPalette.inkMute)),
          ],
          if (plan?.aiFailed ?? false) ...<Widget>[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppPalette.danger.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                plan!.aiError?.isNotEmpty == true
                    ? '上次生成失败：${plan.aiError}'
                    : '上次生成失败，可重试',
                style: const TextStyle(
                    fontSize: AppFontSize.small, color: AppPalette.danger),
              ),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: running
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome),
              label: Text(running
                  ? '正在生成 7 项目标…'
                  : (plan == null ? 'AI 按最新评估生成' : '重新生成 7 项目标')),
              onPressed: running ? null : _generate,
            ),
          ),
          if (!aiEnabled) ...<Widget>[
            const SizedBox(height: 8),
            const Text(
              '当前环境未配置 AI 服务，生成不可用；可先手动新建并填写目标。',
              style: TextStyle(fontSize: AppFontSize.small, color: AppPalette.warning),
            ),
          ] else if (q != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              (q['unlimited'] as bool? ?? false)
                  ? '本月 AI 额度：不限（${q['month'] ?? ''}）'
                  : '本月已用 ${_money(q['usedYuan'])} · 剩余 ${_money(q['remainingYuan'])}'
                      ' · 本次预估 ${_money(q['estimateYuan'])}',
              style: const TextStyle(
                  fontSize: AppFontSize.caption, color: AppPalette.inkMute),
            ),
          ],
        ],
      ),
    );
  }
}

/// 空态：还没有任何教学计划。
class _EmptyPlanCard extends StatelessWidget {
  const _EmptyPlanCard({required this.onCreate});
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(children: const <Widget>[
            Icon(Icons.menu_book_outlined, color: AppPalette.inkMute),
            SizedBox(width: 8),
            Text('暂无教学计划',
                style: TextStyle(
                    fontSize: AppFontSize.title, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 6),
          const Text(
            '点上面的「AI 按最新评估生成」会自动新建一版并按评估生成 7 项目标；'
            '也可以先手动新建再填写。',
            style: TextStyle(fontSize: AppFontSize.small, color: AppPalette.inkMute),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('手动新建教学计划'),
          ),
        ],
      ),
    );
  }
}

/// 当前计划详情卡：7 项目标 + 编辑 / 与 AI 对话修改。
class _PlanDetailCard extends StatelessWidget {
  const _PlanDetailCard({
    required this.plan,
    required this.onEdit,
    required this.onRevise,
  });

  final RehabTeachingPlan plan;
  final VoidCallback onEdit;
  final VoidCallback onRevise;

  @override
  Widget build(BuildContext context) {
    final DateFormat fmt = DateFormat('yyyy.MM.dd');
    final List<(String, String)> goals = plan.goalEntries;
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.edit_calendar_outlined,
                  color: AppPalette.brandDark),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  plan.aiGenerated ? 'AI 教学计划' : '教学计划',
                  style: const TextStyle(
                      fontSize: AppFontSize.title,
                      fontWeight: FontWeight.bold,
                      color: AppPalette.ink),
                ),
              ),
              Text(
                '${fmt.format(plan.planPeriodStart ?? DateTime.now())}'
                ' ~ ${fmt.format(plan.planPeriodEnd ?? DateTime.now())}',
                style: const TextStyle(
                    fontSize: AppFontSize.caption, color: AppPalette.inkMute),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            plan.aiSourceLabel,
            style: const TextStyle(
                fontSize: AppFontSize.small, color: AppPalette.inkMute),
          ),
          const SizedBox(height: 8),
          for (final (String label, String value) in goals)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(
                      fontSize: AppFontSize.small,
                      color: AppPalette.ink,
                      height: 1.5),
                  children: <InlineSpan>[
                    TextSpan(
                      text: '$label ',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppPalette.brandDark),
                    ),
                    TextSpan(
                      text: value.trim().isEmpty ? '待补充' : value,
                      style: value.trim().isEmpty
                          ? const TextStyle(color: AppPalette.inkMute)
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('编辑'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onRevise,
                  icon: const Icon(Icons.forum_outlined, size: 18),
                  label: const Text('与 AI 对话修改'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// AI 修改轮次记录。
class _RevisionList extends StatelessWidget {
  const _RevisionList({required this.entries});
  final List<PlanRevisionEntry> entries;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (final PlanRevisionEntry r in entries.reversed)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppPalette.brandSoft.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text('第${r.round}轮',
                        style: const TextStyle(
                            fontSize: AppFontSize.caption,
                            fontWeight: FontWeight.bold,
                            color: AppPalette.brandDark)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(r.instruction,
                        style: const TextStyle(fontSize: AppFontSize.small)),
                  ),
                  const SizedBox(width: 8),
                  Text(r.timeLabel,
                      style: const TextStyle(
                          fontSize: AppFontSize.caption,
                          color: AppPalette.inkMute)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// 历史计划条目（点开可编辑/查看）。
class _HistoryPlanTile extends StatelessWidget {
  const _HistoryPlanTile({required this.plan, required this.onTap});
  final RehabTeachingPlan plan;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final DateFormat fmt = DateFormat('yyyy.MM.dd');
    final int filled =
        plan.goalEntries.where((e) => e.$2.trim().isNotEmpty).length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SoftCard(
        onTap: onTap,
        child: Row(
          children: <Widget>[
            const Icon(Icons.history, color: AppPalette.inkMute),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '${fmt.format(plan.planPeriodStart ?? DateTime.now())}'
                    ' ~ ${fmt.format(plan.planPeriodEnd ?? DateTime.now())}',
                    style: const TextStyle(
                        fontSize: AppFontSize.small,
                        fontWeight: FontWeight.w600,
                        color: AppPalette.ink),
                  ),
                  Text('${plan.aiSourceLabel} · 已填 $filled/7 项',
                      style: const TextStyle(
                          fontSize: AppFontSize.caption,
                          color: AppPalette.inkMute)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppPalette.inkMute),
          ],
        ),
      ),
    );
  }
}

/// 听障档案 - 评估待办独立页。
class TasksSectionScreen extends ConsumerWidget {
  const TasksSectionScreen({required this.archiveId, super.key});
  final String archiveId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final RehabArchiveDetailState st =
        ref.watch(rehabArchiveDetailProvider(archiveId));
    final List<RehabTask> tasks = st.detail?.tasks ?? <RehabTask>[];
    final DateFormat fmt = DateFormat('yyyy.MM.dd');
    final List<RehabTask> pending =
        tasks.where((RehabTask t) => !t.completed).toList();
    final List<RehabTask> done =
        tasks.where((RehabTask t) => t.completed).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('评估待办',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppPalette.ink)),
      ),
      body: RefreshIndicator(
        onRefresh: () async =>
            ref.read(rehabArchiveDetailProvider(archiveId).notifier).reload(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            AppSectionTitle('待办（${pending.length}）'),
            if (pending.isEmpty)
              const SoftCard(
                  child: Text('暂无待办',
                      style: TextStyle(color: AppPalette.inkMute))),
            ...pending.map((RehabTask t) {
              final bool overdue = t.dueDate.isBefore(DateTime.now());
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SoftCard(
                  child: Row(children: <Widget>[
                    Icon(
                      t.reminderType == 'TEACHING_PLAN'
                          ? Icons.edit_calendar_outlined
                          : Icons.assessment_outlined,
                      color: overdue ? AppPalette.danger : AppPalette.warning,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(t.title,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600)),
                          Text('${t.typeLabel} · 截止 ${fmt.format(t.dueDate)}',
                              style: TextStyle(
                                  fontSize: AppFontSize.small,
                                  color: overdue
                                      ? AppPalette.danger
                                      : AppPalette.inkMute)),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        await ref
                            .read(rehabArchiveDetailProvider(archiveId)
                                .notifier)
                            .completeTask(t.id);
                      },
                      child: const Text('完成'),
                    ),
                  ]),
                ),
              );
            }),
            const SizedBox(height: 8),
            AppSectionTitle('已完成（${done.length}）'),
            ...done.map((RehabTask t) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SoftCard(
                    child: Row(children: <Widget>[
                      const Icon(Icons.check_circle,
                          color: AppPalette.success),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(t.title,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w500)),
                            Text(
                              '${t.typeLabel} · 完成 ${t.completedAt == null ? '—' : fmt.format(t.completedAt!)}',
                              style: const TextStyle(
                                  fontSize: AppFontSize.small,
                                  color: AppPalette.inkMute),
                            ),
                          ],
                        ),
                      ),
                    ]),
                  ),
                )),
          ],
        ),
      ),
    );
  }
}
