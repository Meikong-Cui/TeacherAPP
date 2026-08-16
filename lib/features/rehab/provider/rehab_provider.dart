import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teacher_app/core/notification_service.dart';
import 'package:teacher_app/data/models/rehab.dart';
import 'package:teacher_app/data/providers.dart';
import 'package:teacher_app/features/rehab/data/rehab_repository.dart';

final Provider<RehabRepository> rehabRepositoryProvider =
    Provider<RehabRepository>((ref) => const RehabRepository());

/// 档案详情状态。
class RehabArchiveDetailState {
  const RehabArchiveDetailState({
    this.detail,
    this.loading = false,
    this.error,
    this.message,
  });

  final RehabArchiveDetail? detail;
  final bool loading;
  final String? error;
  final String? message;

  RehabArchiveDetailState copyWith({
    RehabArchiveDetail? detail,
    bool? loading,
    String? error,
    String? message,
  }) =>
      RehabArchiveDetailState(
        detail: detail ?? this.detail,
        loading: loading ?? this.loading,
        error: error,
        message: message,
      );
}

/// 档案详情逻辑：加载 + 提交首次评估/持续评估/计划 + AI 补全 + 上传照片 + 任务完成。
class RehabArchiveDetailNotifier
    extends StateNotifier<RehabArchiveDetailState> {
  RehabArchiveDetailNotifier(this._repo)
      : super(const RehabArchiveDetailState());

  final RehabRepository _repo;

  Future<void> load(String id) async {
    state = state.copyWith(loading: true, error: null);
    try {
      final RehabArchiveDetail detail = await _repo.getArchive(id);
      state = state.copyWith(detail: detail, loading: false);
      NotificationService.notifyRehabTasks(detail.tasks);
    } catch (e) {
      state = state.copyWith(loading: false, error: '加载失败：$e');
    }
  }

  Future<void> reload() async {
    if (state.detail != null) await load(state.detail!.archive.id);
  }

  /// 消费掉一次性错误提示（SnackBar 展示后调用）。
  void clearError() => state = state.copyWith(error: null);

  /// 消费掉一次性成功提示（SnackBar 展示后调用）。
  void clearMessage() => state = state.copyWith(message: null);

  Future<bool> submitFirstEval(RehabFirstEval eval) async {
    try {
      if (eval.id == null) {
        await _repo.createFirstEval(eval);
      } else {
        await _repo.updateFirstEval(eval);
      }
      // 首次评估提交后，自动创建2个月后的持续评估任务提醒
      try {
        final dueDate = DateTime.now().add(const Duration(days: 60));
        await _repo.createTask(
          archiveId: eval.archiveId,
          reminderType: 'CONT_EVAL',
          title: '${eval.name.isEmpty ? "儿童" : eval.name} · 持续评估（第2次）',
          dueDate: dueDate,
        );
      } catch (_) { /* 任务创建失败不阻塞主流程 */ }
      await reload();
      state = state.copyWith(message: '首次评估已保存，已创建2月后持续评估任务');
      return true;
    } catch (e) {
      state = state.copyWith(error: '保存失败：$e');
      return false;
    }
  }

  Future<bool> submitContEval(RehabContEval eval) async {
    try {
      // 有 id → 更新已有记录；无 id → 新建。
      // 修复前：无条件 create，导致每次「编辑」都插入一条新记录，
      // 而编辑页读到的仍是旧记录，表现为「改了没保存」。
      final bool isUpdate = eval.id != null && eval.id!.isNotEmpty;
      if (isUpdate) {
        await _repo.updateContEval(eval);
      } else {
        await _repo.createContEval(eval);
      }
      await reload();
      state = state.copyWith(message: isUpdate ? '持续评估已更新' : '持续评估已提交');
      return true;
    } catch (e) {
      state = state.copyWith(error: '提交失败：$e');
      return false;
    }
  }

  Future<bool> createPlan(RehabTeachingPlan plan) async {
    try {
      await _repo.createPlan(plan);
      await reload();
      state = state.copyWith(message: '教学计划已新建');
      return true;
    } catch (e) {
      state = state.copyWith(error: '新建失败：$e');
      return false;
    }
  }

  Future<bool> aiGeneratePlan(String planId) async {
    try {
      final Map<String, String> gen = await _repo.aiGeneratePlan(planId);
      if (state.detail != null) {
        final RehabTeachingPlan? existing = state.detail!.plans
            .where((p) => p.id == planId)
            .firstOrNull;
        if (existing != null) {
          await _repo.updatePlan(
            existing.copyWith(
              hearingGoal: gen['hearingGoal'] ?? '',
              speechGoal: gen['speechGoal'] ?? '',
              languageGoal: gen['languageGoal'] ?? '',
              cognitionGoal: gen['cognitionGoal'] ?? '',
              communicationGoal: gen['communicationGoal'] ?? '',
              familyGuidance: gen['familyGuidance'] ?? '',
              otherGoal: gen['otherGoal'] ?? '',
              aiGenerated: true,
            ),
          );
        }
      }
      await reload();
      state = state.copyWith(message: 'AI 已补全 7 领域目标');
      return true;
    } catch (e) {
      state = state.copyWith(error: 'AI 补全失败：$e');
      return false;
    }
  }

  Future<bool> updatePlan(RehabTeachingPlan plan) async {
    try {
      await _repo.updatePlan(plan);
      await reload();
      state = state.copyWith(message: '教学计划已更新');
      return true;
    } catch (e) {
      state = state.copyWith(error: '更新失败：$e');
      return false;
    }
  }

  Future<bool> deletePlan(String planId) async {
    try {
      await _repo.deletePlan(planId);
      await reload();
      state = state.copyWith(message: '教学计划已删除');
      return true;
    } catch (e) {
      state = state.copyWith(error: '删除失败：$e');
      return false;
    }
  }

  Future<bool> saveHearingRecord(RehabHearingRecord record) async {
    try {
      if (record.id.isEmpty) {
        await _repo.createHearingRecord(record);
      } else {
        await _repo.updateHearingRecord(record);
      }
      await reload();
      state = state.copyWith(message: '听能管理记录已保存');
      return true;
    } catch (e) {
      state = state.copyWith(error: '保存失败：$e');
      return false;
    }
  }

  Future<bool> deleteHearingRecord(String recordId) async {
    try {
      await _repo.deleteHearingRecord(recordId);
      await reload();
      state = state.copyWith(message: '听能管理记录已删除');
      return true;
    } catch (e) {
      state = state.copyWith(error: '删除失败：$e');
      return false;
    }
  }

  Future<bool> uploadPhoto({
    required String archiveId,
    required String filePath,
    required String mimeType,
    int fileSize = 0,
    String? relatedFormType,
    String? remark,
  }) async {
    try {
      await _repo.uploadPhoto(
        archiveId: archiveId,
        filePath: filePath,
        mimeType: mimeType,
        fileSize: fileSize,
        relatedFormType: relatedFormType,
        remark: remark,
      );
      await reload();
      state = state.copyWith(message: '照片已上传');
      return true;
    } catch (e) {
      state = state.copyWith(error: '上传失败：$e');
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

final StateNotifierProviderFamily<RehabArchiveDetailNotifier,
        RehabArchiveDetailState, String> rehabArchiveDetailProvider =
    StateNotifierProvider.family<RehabArchiveDetailNotifier,
        RehabArchiveDetailState, String>(
  (ref, id) => RehabArchiveDetailNotifier(ref.watch(rehabRepositoryProvider)),
);

/// 待办任务（首页/任务页使用）。
final pendingTasksProvider =
    FutureProvider.autoDispose<List<RehabTask>>((ref) {
  ref.watch(authChangedProvider);
  return ref.watch(rehabRepositoryProvider).pendingTasks();
});

/// 康复档案列表（首页"今日儿童"使用，从后端真实拉取）。
/// 依赖 [authChangedProvider]：登录成功 / 登出后自动重算，避免旧 token 的 403 被永久缓存。
final rehabArchivesProvider =
    FutureProvider.autoDispose<List<RehabArchive>>((ref) {
      ref.watch(authChangedProvider);
      final repo = ref.watch(rehabRepositoryProvider);
      return repo.listArchives(keyword: '', current: 1, size: 50);
    });
