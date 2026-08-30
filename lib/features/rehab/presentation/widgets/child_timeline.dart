import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:teacher_app/app/design_tokens.dart';
import 'package:teacher_app/data/models/autism_archive.dart';
import 'package:teacher_app/data/models/autism_eval_item.dart';
import 'package:teacher_app/data/models/rehab.dart';
import 'package:teacher_app/features/rehab/provider/autism_eval_provider.dart';
import 'package:teacher_app/features/rehab/provider/rehab_provider.dart';

/// 儿童档案时间线：聚合所有评估 / 计划 / 文档事件，按时间倒序展示。
///
/// 数据来源：
/// - 听障：[RehabArchiveDetail] 的 firstEval / contEvals / hearingRecords / plans
/// - 孤独症：[AutismArchiveDetail] 的 firstEval / contEvals / monthlyPlans /
///   lessonPlans / effectRecords
/// - 孤独症额外汇聚「线下模板评估轮次」与「VB 评估轮次」的日期，
///   保证新添加的评测也会出现在时间线上。
class ChildTimeline extends ConsumerStatefulWidget {
  const ChildTimeline({
    super.key,
    required this.archiveId,
    required this.isAutism,
    required this.rehab,
    required this.autism,
  });

  final String archiveId;
  final bool isAutism;
  final RehabArchiveDetail rehab;
  final AutismArchiveDetail? autism;

  @override
  ConsumerState<ChildTimeline> createState() => _ChildTimelineState();
}

class _ChildTimelineState extends ConsumerState<ChildTimeline> {
  List<Map<String, dynamic>> _offlineRounds = const <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    if (widget.isAutism) _loadOfflineRounds();
  }

  Future<void> _loadOfflineRounds() async {
    try {
      _offlineRounds =
          await ref.read(rehabRepositoryProvider).listOfflineRounds(widget.archiveId);
    } catch (_) {
      // 忽略异常，时间线其余部分仍可展示。
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final DateFormat fmt = DateFormat('yyyy.MM.dd');
    final List<_TimelineEvent> events = <_TimelineEvent>[];

    // 入园建档
    final DateTime? created = widget.rehab.archive.createTime;
    if (created != null) {
      events.add(_TimelineEvent(
        date: created,
        title: '档案建档',
        subtitle:
            '${widget.rehab.archive.campusName} · ${widget.rehab.archive.archiveNo}',
        icon: Icons.folder_open_outlined,
        tone: AppPalette.info,
      ));
    }

    if (!widget.isAutism) {
      // 听障
      if (widget.rehab.firstEval != null) {
        events.add(_TimelineEvent(
          date: widget.rehab.firstEval!.evalDate ?? created,
          title: '首次评估完成',
          subtitle: widget.rehab.firstEval!.evaluatorName.isEmpty
              ? '首次评估'
              : '评估人：${widget.rehab.firstEval!.evaluatorName}',
          icon: Icons.assignment_outlined,
          tone: AppPalette.success,
        ));
      }
      for (final RehabContEval c in widget.rehab.contEvals) {
        events.add(_TimelineEvent(
          date: c.evalDate,
          title: '持续评估（第${c.evalSeq ?? "?"}次）',
          subtitle: c.evaluatorName.isEmpty ? '持续评估' : '评估人：${c.evaluatorName}',
          icon: Icons.assessment_outlined,
          tone: AppPalette.warning,
        ));
      }
      for (final RehabHearingRecord h in widget.rehab.hearingRecords) {
        events.add(_TimelineEvent(
          date: h.evalDate ?? h.fillDate,
          title: '听能管理记录',
          subtitle: h.evaluatorName == null || h.evaluatorName!.isEmpty
              ? '听力测试'
              : '听力师：${h.evaluatorName}',
          icon: Icons.hearing_outlined,
          tone: AppPalette.purple,
        ));
      }
      for (final RehabTeachingPlan p in widget.rehab.plans) {
        events.add(_TimelineEvent(
          date: p.planPeriodStart ?? p.planPeriodEnd,
          title: p.aiGenerated ? 'AI 生成教学计划' : '教学计划',
          subtitle: p.teacherName.isEmpty ? '教学计划' : '教师：${p.teacherName}',
          icon: Icons.edit_calendar_outlined,
          tone: AppPalette.brandDark,
        ));
      }
    } else if (widget.autism != null) {
      final AutismArchiveDetail autism = widget.autism!;
      if (autism.firstEval != null) {
        events.add(_TimelineEvent(
          date: autism.firstEval!.evalDate ?? created,
          title: '入学评估完成',
          subtitle: autism.firstEval!.evaluatorName.isEmpty
              ? '入学评估'
              : '评估人：${autism.firstEval!.evaluatorName}',
          icon: Icons.assignment_outlined,
          tone: AppPalette.success,
        ));
      }
      for (final AutismContEval c in autism.contEvals) {
        events.add(_TimelineEvent(
          date: c.evalDate,
          title: '持续评估（第${c.evalSeq ?? "?"}次）',
          subtitle: c.evaluatorName.isEmpty ? '持续评估' : '评估人：${c.evaluatorName}',
          icon: Icons.assessment_outlined,
          tone: AppPalette.warning,
        ));
      }
      for (final AutismMonthlyPlan p in autism.monthlyPlans) {
        events.add(_TimelineEvent(
          date: p.planMonth,
          title: '月教学计划：${p.monthLabel}',
          subtitle: p.theme.isEmpty ? '月计划' : p.theme,
          icon: Icons.calendar_view_month_outlined,
          tone: AppPalette.brand,
        ));
      }
      for (final AutismLessonPlan l in autism.lessonPlans) {
        events.add(_TimelineEvent(
          date: l.teachingDateStart ?? l.planMonth,
          title: '教育教案：${l.lessonTitle.isEmpty ? '未命名' : l.lessonTitle}',
          subtitle: l.unitTheme.isEmpty ? '教育教案' : l.unitTheme,
          icon: Icons.menu_book_outlined,
          tone: AppPalette.purple,
        ));
      }
      for (final AutismEffectRecord e in autism.effectRecords) {
        events.add(_TimelineEvent(
          date: e.fillDate,
          title: '年度效果登记（${e.recordYear ?? "?"}）',
          subtitle: '有效率：${e.effectiveRate}',
          icon: Icons.insights_outlined,
          tone: AppPalette.warning,
        ));
      }
      // 线下模板评估轮次（新添加的评测也在时间线展示）
      for (final Map<String, dynamic> r in _offlineRounds) {
        final String dateStr = r['evalDate']?.toString() ?? '';
        final DateTime? d = DateTime.tryParse(dateStr);
        final int seq = r['evalSeq'] is int ? r['evalSeq'] as int : 0;
        events.add(_TimelineEvent(
          date: d,
          title: '线下模板评估（第${seq == 0 ? '?' : seq}次）',
          subtitle: 'OFFLINE A/B 卷',
          icon: Icons.offline_bolt_outlined,
          tone: AppPalette.rose,
        ));
      }
      // VB 评估轮次（教师卷 / 家长卷合并去重）
      final List<dynamic> vbRounds = _collectVbRounds();
      for (final dynamic rr in vbRounds) {
        if (rr is! Map) continue;
        final int seq = rr['evalSeq'] is int ? rr['evalSeq'] as int : 0;
        final DateTime? d = rr['evalDate'] is DateTime ? rr['evalDate'] as DateTime : null;
        events.add(_TimelineEvent(
          date: d,
          title: 'VB 评估（第${seq == 0 ? '?' : seq}次）',
          subtitle: 'VB 教师 / 家长卷',
          icon: Icons.record_voice_over_outlined,
          tone: AppPalette.purple,
        ));
      }
    }

    events.removeWhere((_TimelineEvent e) => e.date == null);
    events.sort((_TimelineEvent a, _TimelineEvent b) => b.date!.compareTo(a.date!));

    if (events.isEmpty) {
      return SoftCard(
        child: Row(children: const <Widget>[
          Icon(Icons.timeline, size: 18, color: AppPalette.inkMute),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              '暂无评估记录，完成首次评估后将自动在此汇总。',
              style: TextStyle(fontSize: AppFontSize.small, color: AppPalette.inkMute),
            ),
          ),
        ]),
      );
    }

    return SoftCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Column(
        children: <Widget>[
          for (int i = 0; i < events.length; i++)
            _TimelineRow(
              event: events[i],
              isFirst: i == 0,
              isLast: i == events.length - 1,
              fmt: fmt,
            ),
        ],
      ),
    );
  }

  /// 合并 VB 教师卷 / 家长卷轮次，按 evalSeq 去重，返回 [{evalSeq, evalDate}]。
  List<Map<String, dynamic>> _collectVbRounds() {
    final List<Map<String, dynamic>> merged = <Map<String, dynamic>>[];
    final Set<int> seen = <int>{};
    for (final String form in const <String>['VB_TEACHER', 'VB_PARENT']) {
      final AsyncValue<List<AutismEvalRound>> av =
          ref.watch(evalRoundsProvider('${widget.archiveId}|$form'));
      final List<AutismEvalRound>? list = av.value;
      if (list == null) continue;
      for (final AutismEvalRound r in list) {
        final int seq = r.evalSeq ?? 0;
        if (seq != 0 && seen.contains(seq)) continue;
        if (seq != 0) seen.add(seq);
        merged.add(<String, dynamic>{'evalSeq': seq, 'evalDate': r.evalDate});
      }
    }
    return merged;
  }
}

class _TimelineEvent {
  _TimelineEvent({
    required this.date,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.tone,
  });
  final DateTime? date;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color tone;
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.event,
    required this.isFirst,
    required this.isLast,
    required this.fmt,
  });
  final _TimelineEvent event;
  final bool isFirst;
  final bool isLast;
  final DateFormat fmt;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 84,
            child: Column(
              children: <Widget>[
                Text(
                  event.date == null ? '' : fmt.format(event.date!),
                  style: const TextStyle(
                      fontSize: AppFontSize.small,
                      color: AppPalette.inkMute,
                      fontWeight: AppFontWeight.semibold),
                ),
                const SizedBox(height: 4),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: event.tone,
                    shape: BoxShape.circle,
                    boxShadow: AppShadow.sm,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      color: const Color(0xFFE6EFEE),
                    ),
                  )
                else
                  const SizedBox(height: 8),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: event.tone.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: Icon(event.icon, size: 14, color: event.tone),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(event.title,
                            style: const TextStyle(
                                fontSize: AppFontSize.body,
                                fontWeight: AppFontWeight.semibold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (event.subtitle.isNotEmpty)
                    Text(
                      event.subtitle,
                      style: const TextStyle(
                          fontSize: AppFontSize.small, color: AppPalette.inkMute),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
