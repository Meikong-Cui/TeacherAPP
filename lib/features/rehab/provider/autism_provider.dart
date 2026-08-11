import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teacher_app/core/notification_service.dart';
import 'package:teacher_app/data/models/autism_archive.dart';
import 'package:teacher_app/features/rehab/data/rehab_repository.dart';
import 'package:teacher_app/features/rehab/provider/rehab_provider.dart';

/// 孤独症档案详情状态。
class AutismArchiveDetailState {
  const AutismArchiveDetailState({
    this.detail,
    this.loading = false,
    this.error,
    this.message,
  });

  final AutismArchiveDetail? detail;
  final bool loading;
  final String? error;
  final String? message;

  AutismArchiveDetailState copyWith({
    AutismArchiveDetail? detail,
    bool? loading,
    String? error,
    String? message,
  }) =>
      AutismArchiveDetailState(
        detail: detail ?? this.detail,
        loading: loading ?? this.loading,
        error: error,
        message: message,
      );
}

/// 孤独症档案详情逻辑：加载 + 提交各类文档 + 任务完成。
class AutismArchiveDetailNotifier
    extends StateNotifier<AutismArchiveDetailState> {
  AutismArchiveDetailNotifier(this._repo)
      : super(const AutismArchiveDetailState());

  final RehabRepository _repo;

  Future<void> load(String id) async {
    state = state.copyWith(loading: true, error: null);
    try {
      final AutismArchiveDetail detail = await _repo.getAutismArchive(id);
      state = state.copyWith(detail: detail, loading: false);
      NotificationService.notifyRehabTasks(detail.tasks);
    } catch (e) {
      state = state.copyWith(loading: false, error: '加载失败：$e');
    }
  }

  Future<void> reload() async {
    if (state.detail != null) await load(state.detail!.archive.id);
  }

  void clearError() => state = state.copyWith(error: null);
  void clearMessage() => state = state.copyWith(message: null);

  Future<bool> submitFirstEval(AutismFirstEval eval) async {
    try {
      await _repo.saveAutismFirstEval(eval);
      await reload();
      state = state.copyWith(message: '入学评估 + IEP 已保存');
      return true;
    } catch (e) {
      state = state.copyWith(error: '保存失败：$e');
      return false;
    }
  }

  Future<bool> submitContEval(AutismContEval eval) async {
    try {
      await _repo.saveAutismContEval(eval);
      await reload();
      state = state.copyWith(message: '持续评估已保存');
      return true;
    } catch (e) {
      state = state.copyWith(error: '保存失败：$e');
      return false;
    }
  }

  Future<bool> deleteContEval(String id) async {
    try {
      await _repo.deleteAutismContEval(id);
      await reload();
      state = state.copyWith(message: '持续评估已删除');
      return true;
    } catch (e) {
      state = state.copyWith(error: '删除失败：$e');
      return false;
    }
  }

  Future<bool> submitSemesterPlan(AutismSemesterPlan plan) async {
    try {
      await _repo.saveAutismSemesterPlan(plan);
      await reload();
      state = state.copyWith(message: '学期计划已保存');
      return true;
    } catch (e) {
      state = state.copyWith(error: '保存失败：$e');
      return false;
    }
  }

  Future<bool> deleteSemesterPlan(String id) async {
    try {
      await _repo.deleteAutismSemesterPlan(id);
      await reload();
      state = state.copyWith(message: '学期计划已删除');
      return true;
    } catch (e) {
      state = state.copyWith(error: '删除失败：$e');
      return false;
    }
  }

  Future<bool> submitMonthlyPlan(AutismMonthlyPlan plan) async {
    try {
      await _repo.saveAutismMonthlyPlan(plan);
      await reload();
      state = state.copyWith(message: '月计划已保存');
      return true;
    } catch (e) {
      state = state.copyWith(error: '保存失败：$e');
      return false;
    }
  }

  Future<bool> deleteMonthlyPlan(String id) async {
    try {
      await _repo.deleteAutismMonthlyPlan(id);
      await reload();
      state = state.copyWith(message: '月计划已删除');
      return true;
    } catch (e) {
      state = state.copyWith(error: '删除失败：$e');
      return false;
    }
  }

  Future<bool> submitLessonPlan(AutismLessonPlan plan) async {
    try {
      await _repo.saveAutismLessonPlan(plan);
      await reload();
      state = state.copyWith(message: '教育教案已保存');
      return true;
    } catch (e) {
      state = state.copyWith(error: '保存失败：$e');
      return false;
    }
  }

  Future<bool> deleteLessonPlan(String id) async {
    try {
      await _repo.deleteAutismLessonPlan(id);
      await reload();
      state = state.copyWith(message: '教育教案已删除');
      return true;
    } catch (e) {
      state = state.copyWith(error: '删除失败：$e');
      return false;
    }
  }

  Future<bool> submitFamilyGuide(AutismFamilyGuide guide) async {
    try {
      await _repo.saveAutismFamilyGuide(guide);
      await reload();
      state = state.copyWith(message: '家庭康复指导已保存');
      return true;
    } catch (e) {
      state = state.copyWith(error: '保存失败：$e');
      return false;
    }
  }

  Future<bool> deleteFamilyGuide(String id) async {
    try {
      await _repo.deleteAutismFamilyGuide(id);
      await reload();
      state = state.copyWith(message: '家庭康复指导已删除');
      return true;
    } catch (e) {
      state = state.copyWith(error: '删除失败：$e');
      return false;
    }
  }

  Future<bool> submitEffectRecord(AutismEffectRecord record) async {
    try {
      await _repo.saveAutismEffectRecord(record);
      await reload();
      state = state.copyWith(message: '年度康复效果登记表已保存');
      return true;
    } catch (e) {
      state = state.copyWith(error: '保存失败：$e');
      return false;
    }
  }

  Future<bool> deleteEffectRecord(String id) async {
    try {
      await _repo.deleteAutismEffectRecord(id);
      await reload();
      state = state.copyWith(message: '效果登记表已删除');
      return true;
    } catch (e) {
      state = state.copyWith(error: '删除失败：$e');
      return false;
    }
  }

  Future<bool> completeTask(String taskId) async {
    try {
      await _repo.completeTask(taskId);
      await reload();
      state = state.copyWith(message: '任务已标记完成');
      return true;
    } catch (e) {
      state = state.copyWith(error: '操作失败：$e');
      return false;
    }
  }
}

final StateNotifierProviderFamily<AutismArchiveDetailNotifier,
        AutismArchiveDetailState, String> autismArchiveDetailProvider =
    StateNotifierProvider.family<AutismArchiveDetailNotifier,
        AutismArchiveDetailState, String>(
  (ref, id) => AutismArchiveDetailNotifier(ref.watch(rehabRepositoryProvider)),
);
