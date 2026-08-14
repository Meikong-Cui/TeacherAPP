import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:teacher_app/data/models/iep_plan.dart';
import 'package:teacher_app/features/rehab/data/rehab_repository.dart';
import 'package:teacher_app/features/rehab/provider/rehab_provider.dart';

/// IEP 计划状态（数据源为后端 oa-rehab /iep 接口）。
class IepPlanState {
  IepPlanState({
    required this.archiveId,
    this.plan,
    this.childName = '',
    this.ageBands = const <String>[],
    this.loading = false,
    this.saving = false,
    this.exporting = false,
    this.error,
    this.message,
  });

  final String archiveId;
  final IepPlan? plan;
  final String childName;
  final List<String> ageBands;
  final bool loading;
  final bool saving;
  final bool exporting;
  final String? error;
  final String? message;

  List<IepPlanGoal> get goals => plan?.goals ?? const <IepPlanGoal>[];
  bool get hasGoals => goals.isNotEmpty;
  Map<String, int> get phaseCounts =>
      plan?.phaseCounts ?? const <String, int>{};

  IepPlanState copyWith({
    IepPlan? plan,
    String? childName,
    List<String>? ageBands,
    bool? loading,
    bool? saving,
    bool? exporting,
    String? error,
    String? message,
  }) =>
      IepPlanState(
        archiveId: archiveId,
        plan: plan ?? this.plan,
        childName: childName ?? this.childName,
        ageBands: ageBands ?? this.ageBands,
        loading: loading ?? this.loading,
        saving: saving ?? this.saving,
        exporting: exporting ?? this.exporting,
        error: error,
        message: message,
      );
}

class IepPlanNotifier extends StateNotifier<IepPlanState> {
  IepPlanNotifier(this._ref, this._archiveId)
      : super(IepPlanState(archiveId: _archiveId)) {
    _load();
  }

  final Ref _ref;
  final String _archiveId;

  RehabRepository get _repo => _ref.read(rehabRepositoryProvider);

  Future<void> _load() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final List<String> ageBands = await _repo.listIepAgeBands();
      final IepPlan plan = await _repo.getIepPlan(_archiveId);
      String name = plan.childName;
      if (name.isEmpty) {
        try {
          final detail = await _repo.getAutismArchive(_archiveId);
          name = detail.archive.childName;
        } catch (_) {
          // 档案名缺失不影响 IEP 本身
        }
      }
      state = state.copyWith(
        loading: false,
        plan: plan,
        childName: name,
        ageBands: ageBands,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: '加载失败：$e');
    }
  }

  Future<void> reload() => _load();

  Future<void> _apply(IepPlan plan, {String? msg}) async {
    state = state.copyWith(
      plan: plan,
      childName: plan.childName.isNotEmpty ? plan.childName : state.childName,
      message: msg,
    );
  }

  /// 追加模板（去重由后端按 templateId 保证，重复添加只显示一个）。
  Future<void> addTemplateIds(List<int> ids) async {
    if (ids.isEmpty) return;
    state = state.copyWith(saving: true, error: null);
    try {
      final IepPlan plan = await _repo.saveIepPlan(IepPlanSaveRequest(
        archiveId: _archiveId,
        appendTemplateIds: ids,
      ));
      await _apply(plan, msg: '已添加 ${ids.length} 个 IEP 项目');
      state = state.copyWith(saving: false);
    } catch (e) {
      state = state.copyWith(saving: false, error: '添加失败：$e');
    }
  }

  /// 删除单个目标。
  Future<void> removeGoal(int goalId) async {
    state = state.copyWith(saving: true, error: null);
    try {
      await _repo.removeIepGoal(goalId);
      final IepPlan plan = await _repo.getIepPlan(_archiveId);
      await _apply(plan, msg: '已删除目标');
      state = state.copyWith(saving: false);
    } catch (e) {
      state = state.copyWith(saving: false, error: '删除失败：$e');
    }
  }

  /// 更新目标阶段（即时落库 + 本地重算统计）。
  Future<void> setGoalPhase(int goalId, IepPhase phase) async {
    try {
      await _repo.updateIepGoalPhase(goalId, phase.code);
      final List<IepPlanGoal> next =
          state.goals.map((g) => g.id == goalId ? g.copyWith(phase: phase) : g).toList();
      final Map<String, int> counts = _recalc(next);
      state = state.copyWith(
        plan: state.plan?.copyWith(goals: next, phaseCounts: counts),
      );
    } catch (e) {
      state = state.copyWith(error: '阶段更新失败：$e');
    }
  }

  Map<String, int> _recalc(List<IepPlanGoal> goals) {
    final Map<String, int> c = <String, int>{
      'NOT_STARTED': 0,
      'IN_PROGRESS': 0,
      'PASSED': 0,
      'STOPPED': 0,
    };
    for (final g in goals) {
      c[g.phase.code] = (c[g.phase.code] ?? 0) + 1;
    }
    return c;
  }

  /// AI 推荐（按年龄段 + 薄弱领域；薄弱领域为空时后端默认每领域各 1 条）。
  Future<void> aiRecommend({
    String? ageBand,
    required List<String> weakDomains,
  }) async {
    state = state.copyWith(saving: true, error: null);
    try {
      final IepPlan plan = await _repo.aiRecommendIep(
        archiveId: _archiveId,
        ageBand: ageBand,
        weakDomains: weakDomains,
      );
      await _apply(plan, msg: 'AI 已生成推荐目标');
      state = state.copyWith(saving: false);
    } catch (e) {
      state = state.copyWith(saving: false, error: 'AI 推荐失败：$e');
    }
  }

  /// 保存元信息（制定人员、年龄段、起止日期）。
  Future<void> saveMeta({
    String? childName,
    String? ageBand,
    String? planner,
    String? startDate,
    String? endDate,
  }) async {
    state = state.copyWith(saving: true, error: null);
    try {
      final IepPlan plan = await _repo.saveIepPlan(IepPlanSaveRequest(
        archiveId: _archiveId,
        childName: childName ?? state.childName,
        ageBand: ageBand ?? state.plan?.ageBand,
        planner: planner ?? state.plan?.planner,
        startDate: startDate ?? state.plan?.startDate,
        endDate: endDate ?? state.plan?.endDate,
      ));
      await _apply(plan, msg: '已保存');
      state = state.copyWith(saving: false);
    } catch (e) {
      state = state.copyWith(saving: false, error: '保存失败：$e');
    }
  }

  /// 导出 PDF（分享/保存）。
  Future<void> exportPdf() async {
    state = state.copyWith(exporting: true, error: null);
    try {
      final Uint8List bytes = await _repo.exportIepPdf(_archiveId);
      final String name =
          state.childName.isNotEmpty ? state.childName : 'archive-$_archiveId';
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'IEP-$name-$_archiveId.pdf',
      );
      state = state.copyWith(exporting: false, message: 'PDF 已导出');
    } catch (e) {
      state = state.copyWith(exporting: false, error: '导出失败：$e');
    }
  }

  void clearMessage() => state = state.copyWith(message: null);
  void clearError() => state = state.copyWith(error: null);
}

final StateNotifierProviderFamily<IepPlanNotifier, IepPlanState, String>
    iepPlanProvider =
    StateNotifierProvider.family<IepPlanNotifier, IepPlanState, String>(
  (ref, archiveId) => IepPlanNotifier(ref, archiveId),
);
