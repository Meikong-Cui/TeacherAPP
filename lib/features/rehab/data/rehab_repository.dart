import 'package:teacher_app/core/api_client.dart';
import 'package:teacher_app/core/constants.dart';
import 'package:teacher_app/data/models/autism_archive.dart';
import 'package:teacher_app/data/models/rehab.dart';

/// 康复档案数据层（真实对接后端 oa-rehab 模块）。
class RehabRepository {
  const RehabRepository();

  /// 档案列表（分页）。[keyword] 支持按儿童姓名/档案编号搜索。
  Future<List<RehabArchive>> listArchives({
    String? keyword,
    int current = 1,
    int size = 50,
  }) async {
    final StringBuffer sb =
        StringBuffer('${AppConstants.rehabPath}/archives?current=$current&size=$size');
    if (keyword != null && keyword.isNotEmpty) {
      sb.write('&keyword=${Uri.encodeQueryComponent(keyword)}');
    }
    final dynamic data = await apiClient.get(sb.toString());
    if (data is Map && data['records'] is List) {
      return (data['records'] as List)
          .whereType<Map<String, dynamic>>()
          .map((e) => RehabArchive.fromJson(e))
          .toList();
    }
    if (data is List) {
      return data
          .whereType<Map<String, dynamic>>()
          .map((e) => RehabArchive.fromJson(e))
          .toList();
    }
    return const <RehabArchive>[];
  }

  /// 档案详情（含首次评估/持续评估/计划/照片/任务）。
  Future<RehabArchiveDetail> getArchive(String id) async {
    final dynamic data =
        await apiClient.get('${AppConstants.rehabPath}/archives/$id');
    if (data is! Map<String, dynamic>) {
      throw const ApiException('档案详情响应异常');
    }
    return RehabArchiveDetail.fromJson(data);
  }

  /// 提交首次评估（返回后端 id）。
  Future<String> createFirstEval(RehabFirstEval eval) async {
    final dynamic data =
        await apiClient.post('${AppConstants.rehabPath}/first-eval', eval.toJson());
    return data?.toString() ?? '';
  }

  /// 更新首次评估。
  Future<void> updateFirstEval(RehabFirstEval eval) async {
    await apiClient.put(
        '${AppConstants.rehabPath}/first-eval/${eval.id}', eval.toJson());
  }

  /// 提交持续评估（返回后端 id）。
  Future<String> createContEval(RehabContEval eval) async {
    final dynamic data =
        await apiClient.post('${AppConstants.rehabPath}/cont-eval', eval.toJson());
    return data?.toString() ?? '';
  }

  /// 更新持续评估（对应后端 PUT /cont-eval/{id}）。
  Future<void> updateContEval(RehabContEval eval) async {
    await apiClient.put(
        '${AppConstants.rehabPath}/cont-eval/${eval.id}', eval.toJson());
  }

  /// 新建教学计划（返回后端 id）。
  Future<String> createPlan(RehabTeachingPlan plan) async {
    final dynamic data =
        await apiClient.post('${AppConstants.rehabPath}/plan', plan.toJson());
    return data?.toString() ?? '';
  }

  /// 更新教学计划。
  Future<void> updatePlan(RehabTeachingPlan plan) async {
    await apiClient.put(
        '${AppConstants.rehabPath}/plan/${plan.id}', plan.toJson());
  }

  /// AI 补全教学计划（返回 7 领域目标文本）。
  Future<Map<String, String>> aiGeneratePlan(String planId) async {
    final dynamic data = await apiClient
        .post('${AppConstants.rehabPath}/plan/$planId/ai-generate');
    final Map<String, String> out = <String, String>{};
    if (data is Map) {
      data.forEach((k, v) => out[k.toString()] = v?.toString() ?? '');
    }
    return out;
  }

  /// 删除教学计划。
  Future<void> deletePlan(String planId) async {
    await apiClient.delete('${AppConstants.rehabPath}/plan/$planId');
  }

  /// 新建听能管理记录。
  Future<String> createHearingRecord(RehabHearingRecord record) async {
    final dynamic data = await apiClient
        .post('${AppConstants.rehabPath}/hearing-records', record.toJson());
    return data?.toString() ?? '';
  }

  /// 更新听能管理记录。
  Future<void> updateHearingRecord(RehabHearingRecord record) async {
    await apiClient.put(
        '${AppConstants.rehabPath}/hearing-records/${record.id}', record.toJson());
  }

  /// 删除听能管理记录。
  Future<void> deleteHearingRecord(String recordId) async {
    await apiClient
        .delete('${AppConstants.rehabPath}/hearing-records/$recordId');
  }

  /// 上传手写照片（base64 dataURL 直接作为 filePath 传给后端）。
  Future<String> uploadPhoto({
    required String archiveId,
    required String filePath,
    required String mimeType,
    int fileSize = 0,
    String? relatedFormType,
    String? remark,
  }) async {
    final dynamic data = await apiClient.post('${AppConstants.rehabPath}/photos', <
        String, dynamic>{
      'archiveId': archiveId,
      if (relatedFormType != null) 'relatedFormType': relatedFormType,
      'filePath': filePath,
      'fileSize': fileSize,
      'mimeType': mimeType,
      if (remark != null) 'remark': remark,
    });
    return data?.toString() ?? '';
  }

  /// 档案照片列表。
  Future<List<RehabPhoto>> listPhotos(String archiveId) async {
    final dynamic data = await apiClient
        .get('${AppConstants.rehabPath}/photos/archive/$archiveId');
    if (data is! List) return const <RehabPhoto>[];
    return data
        .whereType<Map<String, dynamic>>()
        .map((e) => RehabPhoto.fromJson(e))
        .toList();
  }

  /// 我（及相关儿童）的待办任务。
  Future<List<RehabTask>> pendingTasks() async {
    final dynamic data =
        await apiClient.get('${AppConstants.rehabPath}/tasks/pending');
    if (data is! List) return const <RehabTask>[];
    return data
        .whereType<Map<String, dynamic>>()
        .map((e) => RehabTask.fromJson(e))
        .toList();
  }

  /// 标记任务完成。
  Future<void> completeTask(String taskId) async {
    await apiClient
        .post('${AppConstants.rehabPath}/tasks/$taskId/complete');
  }

  /// 创建任务提醒（持续评估/教学计划到期）。
  Future<String> createTask({
    required String archiveId,
    required String reminderType,
    required String title,
    required DateTime dueDate,
  }) async {
    final dynamic data = await apiClient.post('${AppConstants.rehabPath}/tasks', <String, dynamic>{
      'archiveId': archiveId,
      'reminderType': reminderType,
      'title': title,
      'dueDate': dueDate.toIso8601String().split('T').first,
    });
    return data?.toString() ?? '';
  }

  // ════════════════════════════════════════════════════════════════
  //  孤独症档案（后端 oa-rehab /autism 接口）
  // ════════════════════════════════════════════════════════════════

  String get _autismPath => '${AppConstants.rehabPath}/autism';

  /// 孤独症档案详情（入学评估 + 7 类文档 + 任务）。
  Future<AutismArchiveDetail> getAutismArchive(String id) async {
    final dynamic data =
        await apiClient.get('${AppConstants.rehabPath}/archives/$id');
    if (data is! Map<String, dynamic>) {
      throw const ApiException('孤独症档案详情响应异常');
    }
    return AutismArchiveDetail.fromJson(data);
  }

  /// 保存孤独症入学评估 + IEP（有 id 走更新，无 id 走新建）。
  Future<void> saveAutismFirstEval(AutismFirstEval eval) async {
    if (eval.id == null || eval.id!.isEmpty) {
      await apiClient.post('$_autismPath/first-eval', eval.toJson());
    } else {
      await apiClient.put('$_autismPath/first-eval/${eval.id}', eval.toJson());
    }
  }

  Future<void> saveAutismContEval(AutismContEval eval) async {
    if (eval.id == null || eval.id!.isEmpty) {
      await apiClient.post('$_autismPath/cont-eval', eval.toJson());
    } else {
      await apiClient.put('$_autismPath/cont-eval/${eval.id}', eval.toJson());
    }
  }

  Future<void> deleteAutismContEval(String id) async =>
      apiClient.delete('$_autismPath/cont-eval/$id');

  Future<void> saveAutismSemesterPlan(AutismSemesterPlan plan) async {
    if (plan.id == null || plan.id!.isEmpty) {
      await apiClient.post('$_autismPath/semester-plan', plan.toJson());
    } else {
      await apiClient.put('$_autismPath/semester-plan/${plan.id}', plan.toJson());
    }
  }

  Future<void> deleteAutismSemesterPlan(String id) async =>
      apiClient.delete('$_autismPath/semester-plan/$id');

  Future<void> saveAutismMonthlyPlan(AutismMonthlyPlan plan) async {
    if (plan.id == null || plan.id!.isEmpty) {
      await apiClient.post('$_autismPath/monthly-plan', plan.toJson());
    } else {
      await apiClient.put('$_autismPath/monthly-plan/${plan.id}', plan.toJson());
    }
  }

  Future<void> deleteAutismMonthlyPlan(String id) async =>
      apiClient.delete('$_autismPath/monthly-plan/$id');

  Future<void> saveAutismLessonPlan(AutismLessonPlan plan) async {
    if (plan.id == null || plan.id!.isEmpty) {
      await apiClient.post('$_autismPath/lesson-plan', plan.toJson());
    } else {
      await apiClient.put('$_autismPath/lesson-plan/${plan.id}', plan.toJson());
    }
  }

  Future<void> deleteAutismLessonPlan(String id) async =>
      apiClient.delete('$_autismPath/lesson-plan/$id');

  Future<void> saveAutismFamilyGuide(AutismFamilyGuide guide) async {
    if (guide.id == null || guide.id!.isEmpty) {
      await apiClient.post('$_autismPath/family-guide', guide.toJson());
    } else {
      await apiClient.put('$_autismPath/family-guide/${guide.id}', guide.toJson());
    }
  }

  Future<void> deleteAutismFamilyGuide(String id) async =>
      apiClient.delete('$_autismPath/family-guide/$id');

  Future<void> saveAutismEffectRecord(AutismEffectRecord record) async {
    if (record.id == null || record.id!.isEmpty) {
      await apiClient.post('$_autismPath/effect-record', record.toJson());
    } else {
      await apiClient.put('$_autismPath/effect-record/${record.id}', record.toJson());
    }
  }

  Future<void> deleteAutismEffectRecord(String id) async =>
      apiClient.delete('$_autismPath/effect-record/$id');
}
