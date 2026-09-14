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

  /// 提交首次评估。
  ///
  /// 提醒与 AI 生成都由后端负责：后端在保存首评后会创建「1 个月后持续评估」待办，
  /// 并自动按首评生成第一版教学计划。前端不再自己建任务——那会导致网页端提交评估时
  /// 完全没有提醒（两端行为不一致）。
  Future<bool> submitFirstEval(RehabFirstEval eval) async {
    try {
      if (eval.id == null) {
        await _repo.createFirstEval(eval);
      } else {
        await _repo.updateFirstEval(eval);
      }
      await reload();
      state = state.copyWith(message: '首次评估已保存，已排入 1 个月后的持续评估提醒');
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

  /// 按最新评估生成教学计划（新生按首评、老生按最新一期已完成的持续评估）。
  ///
  /// 后端返回落库后的完整计划，直接 reload 即可——旧实现生成后又补一次 PUT，
  /// 多一次请求且容易出现「界面显示的还是旧内容」。
  Future<bool> aiGeneratePlan(String planId) async {
    try {
      await _repo.aiGeneratePlan(planId);
      await reload();
      state = state.copyWith(message: 'AI 已按最新评估生成 7 项目标');
      return true;
    } catch (e) {
      // 失败原因后端已写进计划的 aiError，reload 后页面能直接展示
      await reload();
      state = state.copyWith(error: 'AI 生成失败：$e');
      return false;
    }
  }

  /// 老师提意见 → 按意见重新生成（只重写涉及到的字段）。
  Future<bool> revisePlan(String planId, String instruction) async {
    try {
      await _repo.revisePlan(planId, instruction);
      await reload();
      state = state.copyWith(message: '已按你的意见重新生成');
      return true;
    } catch (e) {
      await reload();
      state = state.copyWith(error: '重新生成失败：$e');
      return false;
    }
  }

  /// 生成前的额度信息（本月已用 / 剩余 / 本次预估花费）。
  Future<Map<String, dynamic>> planQuota(String planId) =>
      _repo.planQuota(planId);

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
