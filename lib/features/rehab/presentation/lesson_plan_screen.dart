import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:teacher_app/app/design_tokens.dart';
import 'package:teacher_app/data/models/rehab.dart';
import 'package:teacher_app/features/ai_lesson_plan/data/ai_lesson_plan_repository.dart';
import 'package:teacher_app/features/ai_lesson_plan/provider/ai_lesson_plan_provider.dart';
import 'package:teacher_app/features/rehab/provider/rehab_provider.dart';
import 'package:teacher_app/shared/ui.dart';

/// 听障档案 - 单课教案页（5 领域）。
///
/// 与「教学计划」是两个独立入口，因为两者是不同层级的东西：
///   教学计划（7 项目标）：按每期持续评估更新，覆盖接下来两个月的阶段目标；
///   单课教案（5 领域）：把阶段目标落到每一节课的听能发展 / 言语发展 / 语言发展 /
///   认知发展 / 沟通技能，含设备玩具等课堂材料。
///
/// 生成时会把当期教学计划一并带给后端（`planId`），保证「单课教案依据教学计划写」。
class LessonPlanSectionScreen extends ConsumerStatefulWidget {
  const LessonPlanSectionScreen({required this.archiveId, super.key});
  final String archiveId;

  @override
  ConsumerState<LessonPlanSectionScreen> createState() =>
      _LessonPlanSectionScreenState();
}

class _LessonPlanSectionScreenState
    extends ConsumerState<LessonPlanSectionScreen> {
  late Future<List<AiLessonPlanResult>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
    // 档案详情用于「当期教学计划 / 儿童信息」，没加载过就补一次。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final RehabArchiveDetailState st =
          ref.read(rehabArchiveDetailProvider(widget.archiveId));
      if (st.detail == null && !st.loading) {
        ref
            .read(rehabArchiveDetailProvider(widget.archiveId).notifier)
            .load(widget.archiveId);
      }
    });
  }

  Future<List<AiLessonPlanResult>> _load() async {
    final int? aid = int.tryParse(widget.archiveId);
    if (aid == null) return const <AiLessonPlanResult>[];
    return ref.read(aiLessonPlanRepositoryProvider).listByArchive(aid);
  }

  void _reload() => setState(() => _future = _load());

  /// 打开 AI 生成页：带入儿童信息与**当期教学计划**，生成结果会挂在该计划下。
  Future<void> _openGenerator() async {
    final RehabArchiveDetail? detail =
        ref.read(rehabArchiveDetailProvider(widget.archiveId)).detail;
    final RehabTeachingPlan? plan = detail?.latestPlan;
    await context.push<Object?>(
      '/ai-lesson-plan',
      extra: AiLessonPlanLaunchContext(
        archiveId: int.tryParse(widget.archiveId),
        childName: detail?.archive.childName ?? '',
        gender: detail?.firstEval?.gender ?? '',
        physiologicalAge: _physiologicalAge(detail),
        hearingAge: _hearingAge(detail),
        deviceWear: _deviceWear(detail),
        plan: plan,
      ),
    );
    if (mounted) _reload();
  }

  String _physiologicalAge(RehabArchiveDetail? d) {
    final RehabContEval? ce = d?.latestCompletedContEval;
    if (ce != null && ce.physiologicalAge.isNotEmpty) {
      return ce.physiologicalAge;
    }
    return _ageFromBirth(d?.firstEval?.birthDate);
  }

  String _hearingAge(RehabArchiveDetail? d) {
    final RehabContEval? ce = d?.latestCompletedContEval;
    if (ce != null && ce.hearingAge.isNotEmpty) return ce.hearingAge;
    return '';
  }

  String _deviceWear(RehabArchiveDetail? d) {
    final RehabFirstEval? fe = d?.firstEval;
    if (fe == null) return '双侧';
    final bool left = fe.leftCompensationType.isNotEmpty;
    final bool right = fe.rightCompensationType.isNotEmpty;
    if (left && right) return '双侧';
    if (left || right) return '单侧';
    return '双侧';
  }

  String _ageFromBirth(DateTime? birth) {
    if (birth == null) return '';
    final DateTime now = DateTime.now();
    int months = (now.year - birth.year) * 12 +
        now.month -
        birth.month -
        (now.day < birth.day ? 1 : 0);
    if (months < 0) months = 0;
    return '${months ~/ 12}岁${months % 12}个月';
  }

  @override
  Widget build(BuildContext context) {
    final RehabArchiveDetail? detail =
        ref.watch(rehabArchiveDetailProvider(widget.archiveId)).detail;
    final RehabTeachingPlan? plan = detail?.latestPlan;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '单课教案',
          style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.w700, color: AppPalette.ink),
        ),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
            onPressed: _reload,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _reload(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            _BasisCard(plan: plan, onGenerate: _openGenerator),
            const SizedBox(height: 16),
            const AppSectionTitle('历史教案'),
            FutureBuilder<List<AiLessonPlanResult>>(
              future: _future,
              builder: (BuildContext ctx,
                  AsyncSnapshot<List<AiLessonPlanResult>> snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snap.hasError) {
                  return SoftCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text('加载失败：${snap.error}',
                            style: const TextStyle(
                                fontSize: AppFontSize.small,
                                color: AppPalette.danger)),
                        const SizedBox(height: 8),
                        OutlinedButton(
                            onPressed: _reload, child: const Text('重试')),
                      ],
                    ),
                  );
                }
                final List<AiLessonPlanResult> list =
                    snap.data ?? const <AiLessonPlanResult>[];
                if (list.isEmpty) {
                  return SoftCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(children: const <Widget>[
                          Icon(Icons.menu_book_outlined,
                              color: AppPalette.inkMute),
                          SizedBox(width: 8),
                          Text('还没有单课教案',
                              style: TextStyle(
                                  fontSize: AppFontSize.title,
                                  fontWeight: FontWeight.bold)),
                        ]),
                        const SizedBox(height: 6),
                        const Text(
                          '点上面的「AI 生成新教案」，填本课主题与目标音位即可生成 5 领域内容；'
                          '生成结果会自动关联当期教学计划。',
                          style: TextStyle(
                              fontSize: AppFontSize.small,
                              color: AppPalette.inkMute),
                        ),
                      ],
                    ),
                  );
                }
                return Column(
                  children: <Widget>[
                    for (final AiLessonPlanResult r in list)
                      _LessonPlanTile(
                        result: r,
                        planLabel: _planLabel(detail?.plans, r.planId),
                        onTap: () => _showDetail(r),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  /// 这份教案服务于哪一期教学计划（按周期展示，比裸 id 可读）。
  String _planLabel(List<RehabTeachingPlan>? plans, int? planId) {
    if (planId == null) return '未关联教学计划';
    final DateFormat fmt = DateFormat('yyyy.MM.dd');
    if (plans != null) {
      for (final RehabTeachingPlan p in plans) {
        if (p.id == planId.toString()) {
          return '依据计划 ${fmt.format(p.planPeriodStart ?? DateTime.now())}'
              '~${fmt.format(p.planPeriodEnd ?? DateTime.now())}';
        }
      }
    }
    return '关联教学计划 #$planId';
  }

  /// 单条教案详情：5 领域内容（只读）+ 导出 1.1.4 PDF。
  void _showDetail(AiLessonPlanResult r) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext sheetCtx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        maxChildSize: 0.95,
        builder: (BuildContext ctx, ScrollController sc) => Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          r.lessonTheme.isEmpty ? '未命名教案' : r.lessonTheme,
                          style: const TextStyle(
                              fontSize: AppFontSize.subtitle,
                              fontWeight: FontWeight.bold,
                              color: AppPalette.ink),
                        ),
                        Text(
                          '${_statusLabel(r.status)}'
                          '${r.createTime == null ? '' : ' · ${DateFormat('yyyy-MM-dd HH:mm').format(r.createTime!)}'}',
                          style: const TextStyle(
                              fontSize: AppFontSize.caption,
                              color: AppPalette.inkMute),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _exportPdf(ctx, r),
                    icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                    label: const Text('导出 PDF'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: sc,
                padding: const EdgeInsets.all(16),
                children: <Widget>[
                  if (r.status == 0 || r.status == 3)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        r.status == 0
                            ? '这份教案未生成成功（当前环境未启用 AI 服务）。'
                            : '这份教案生成失败，请重新生成。',
                        style: const TextStyle(
                            fontSize: AppFontSize.small,
                            color: AppPalette.danger),
                      ),
                    ),
                  for (final (String key, String label)
                      in AiLessonPlanResult.orderedDomains)
                    _DomainBlock(
                      label: label,
                      content: r.domains[key]?.content ?? '',
                      materials: r.domains[key]?.materials ?? '',
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _statusLabel(int status) {
    switch (status) {
      case 1:
        return '生成中';
      case 2:
        return '已生成';
      case 3:
        return '生成失败';
      case 4:
        return '教师已定稿';
      default:
        return '未生成';
    }
  }

  Future<void> _exportPdf(BuildContext ctx, AiLessonPlanResult r) async {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('正在生成 PDF…')));
    try {
      final Uint8List bytes =
          await ref.read(aiLessonPlanRepositoryProvider).downloadPdf(r.id);
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'lesson-plan-${r.id}.pdf',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('导出失败：$e')));
    }
  }
}

/// 顶部「生成依据」卡：展示当期教学计划，并提供 AI 生成入口。
class _BasisCard extends StatelessWidget {
  const _BasisCard({required this.plan, required this.onGenerate});
  final RehabTeachingPlan? plan;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    final DateFormat fmt = DateFormat('yyyy.MM.dd');
    final bool hasPlan = plan != null;
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(children: const <Widget>[
            Icon(Icons.link, color: AppPalette.brandDark),
            SizedBox(width: 8),
            Text('生成依据：教学计划',
                style: TextStyle(
                    fontSize: AppFontSize.title,
                    fontWeight: FontWeight.bold,
                    color: AppPalette.ink)),
          ]),
          const SizedBox(height: 6),
          Text(
            hasPlan
                ? '${fmt.format(plan!.planPeriodStart ?? DateTime.now())}'
                    ' ~ ${fmt.format(plan!.planPeriodEnd ?? DateTime.now())}'
                    ' · ${plan!.aiSourceLabel} · 已填 '
                    '${plan!.goalEntries.where((e) => e.$2.trim().isNotEmpty).length}/7 项'
                : '该儿童还没有教学计划：单课教案需要以教学计划为蓝本，'
                    '请先到「教学计划」页生成 7 项目标。',
            style: TextStyle(
                fontSize: AppFontSize.small,
                color: hasPlan ? AppPalette.inkMute : AppPalette.warning),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onGenerate,
              icon: const Icon(Icons.auto_awesome),
              label: const Text('AI 生成新教案'),
            ),
          ),
        ],
      ),
    );
  }
}

/// 单条教案列表项。
class _LessonPlanTile extends StatelessWidget {
  const _LessonPlanTile({
    required this.result,
    required this.planLabel,
    required this.onTap,
  });

  final AiLessonPlanResult result;
  final String planLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final DateFormat fmt = DateFormat('yyyy.MM.dd HH:mm');
    final String title =
        result.lessonTheme.isEmpty ? '未命名教案' : result.lessonTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SoftCard(
        onTap: onTap,
        child: Row(
          children: <Widget>[
            const Icon(Icons.menu_book_outlined, color: AppPalette.brandDark),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(title,
                            style: const TextStyle(
                                fontSize: AppFontSize.body,
                                fontWeight: FontWeight.w600,
                                color: AppPalette.ink)),
                      ),
                      if (result.status == 4)
                        const Text('已定稿',
                            style: TextStyle(
                                fontSize: AppFontSize.caption,
                                color: AppPalette.success,
                                fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${result.targetPhonemes.isEmpty ? '未设音位' : result.targetPhonemes}'
                    ' · ${result.planId == null ? '未关联计划' : '已关联计划'}',
                    style: const TextStyle(
                        fontSize: AppFontSize.caption,
                        color: AppPalette.inkMute),
                  ),
                  Text(
                    '${planLabel}${result.createTime == null ? '' : ' · ${fmt.format(result.createTime!)}'}',
                    style: const TextStyle(
                        fontSize: AppFontSize.caption,
                        color: AppPalette.inkMute),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
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

/// 单个领域（内容 + 设备材料）。
class _DomainBlock extends StatelessWidget {
  const _DomainBlock({
    required this.label,
    required this.content,
    required this.materials,
  });

  final String label;
  final String content;
  final String materials;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(children: <Widget>[
            const Icon(Icons.label_outline, size: 18, color: AppPalette.brandDark),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(
                    fontSize: AppFontSize.body,
                    fontWeight: FontWeight.bold,
                    color: AppPalette.ink)),
          ]),
          const SizedBox(height: 6),
          Text(
            content.trim().isEmpty ? '—' : content,
            style: const TextStyle(
                fontSize: AppFontSize.small,
                color: AppPalette.ink,
                height: 1.5),
          ),
          if (materials.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Text('设备/玩具/图书：$materials',
                style: const TextStyle(
                    fontSize: AppFontSize.caption,
                    color: AppPalette.inkMute)),
          ],
        ],
      ),
    );
  }
}
