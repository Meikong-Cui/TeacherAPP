import 'dart:typed_data';
import 'package:teacher_app/core/api_client.dart';
import 'package:teacher_app/core/constants.dart';
import 'package:teacher_app/data/models/autism_archive.dart';
import 'package:teacher_app/data/models/autism_eval_item.dart';
import 'package:teacher_app/data/models/iep_plan.dart';
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

  /// 新建康复档案（用于「新增孩子」：先录入共用信息，再按类型创建模板）。
  /// 返回后端生成的档案 id。
  Future<String> createArchive(RehabArchive archive) async {
    final dynamic data =
        await apiClient.post('${AppConstants.rehabPath}/archives', archive.toJson());
    if (data is Map && data['id'] != null) return data['id'].toString();
    if (data != null) return data.toString();
    return '';
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

  /// 无 LLM 生成孤独症月教学计划：参考数据库最新 5 份，组合相似内容。
  /// 历史不足 5 份时 [AutismMonthlyPlanGenerateResult.success] 为 false，
  /// [AutismMonthlyPlanGenerateResult.message] 含「数据不足」。
  Future<AutismMonthlyPlanGenerateResult> aiGenerateAutismMonthlyPlan(
      String archiveId) async {
    final dynamic data = await apiClient.post(
      '$_autismPath/monthly-plan/ai-generate?archiveId=$archiveId',
    );
    if (data is! Map<String, dynamic>) {
      throw const ApiException('月计划生成响应异常');
    }
    return AutismMonthlyPlanGenerateResult.fromJson(data);
  }

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

  // ════════════════════════════════════════════════════════════════
  //  评估题目逐题录入（autism_eval_item）
  // ════════════════════════════════════════════════════════════════

  /// 批量保存逐题评分（空值由后端按删除处理）。
  Future<int> saveEvalItems(List<AutismEvalItem> items) async {
    final dynamic data = await apiClient.post(
      '$_autismPath/items/batch',
      items.map((e) => e.toJson()).toList(),
    );
    if (data is int) return data;
    return int.tryParse(data?.toString() ?? '0') ?? 0;
  }

  /// 拉取某档案下某 source 的全部逐题评分。
  Future<List<AutismEvalItem>> listEvalItems(String archiveId, String source) async {
    final dynamic data =
        await apiClient.get('$_autismPath/items/list/$archiveId?source=$source');
    if (data is! List) return const <AutismEvalItem>[];
    return data
        .whereType<Map<String, dynamic>>()
        .map((e) => AutismEvalItem.fromJson(e))
        .toList();
  }

  /// 拉取评估统计（剖面图 + 折线序列）。
  Future<AutismEvalStats> getEvalStats(String archiveId, String source) async {
    final dynamic data =
        await apiClient.get('$_autismPath/items/stats/$archiveId?source=$source');
    if (data is! Map<String, dynamic>) {
      throw const ApiException('评估统计响应异常');
    }
    return AutismEvalStats.fromJson(data);
  }

  // ════════════════════════════════════════════════════════════════
  //  IEP 个别化教育计划（后端 oa-rehab /iep 接口）
  // ════════════════════════════════════════════════════════════════

  String get _iepPath => '${AppConstants.rehabPath}/iep';

  /// 年龄段字典。
  Future<List<String>> listIepAgeBands() async {
    final dynamic data = await apiClient.get('$_iepPath/templates/age-bands');
    if (data is! List) return const <String>[];
    return data.whereType<String>().toList();
  }

  /// 模板：平铺列表（可按年龄/领域/子领域/关键词过滤）。
  Future<List<IepTemplate>> listIepTemplatesFlat({
    String? ageBand,
    String? domain,
    String? subDomain,
    String? keyword,
  }) async {
    final List<String> q = <String>[];
    if (ageBand != null) q.add('ageBand=${Uri.encodeQueryComponent(ageBand)}');
    if (domain != null) q.add('domain=${Uri.encodeQueryComponent(domain)}');
    if (subDomain != null) {
      q.add('subDomain=${Uri.encodeQueryComponent(subDomain)}');
    }
    if (keyword != null) q.add('keyword=${Uri.encodeQueryComponent(keyword)}');
    final String path =
        '$_iepPath/templates${q.isEmpty ? '' : '?${q.join('&')}'}';
    final dynamic data = await apiClient.get(path);
    if (data is! List) return const <IepTemplate>[];
    return data
        .whereType<Map<String, dynamic>>()
        .map((e) => IepTemplate.fromJson(e))
        .toList();
  }

  /// 模板：分组结构（年龄段→领域→子领域→条目）。
  Future<List<IepTemplateGroup>> listIepTemplatesGrouped({
    String? ageBand,
    String? domain,
    String? subDomain,
    String? keyword,
  }) async {
    final List<String> q = <String>[];
    if (ageBand != null) q.add('ageBand=${Uri.encodeQueryComponent(ageBand)}');
    if (domain != null) q.add('domain=${Uri.encodeQueryComponent(domain)}');
    if (subDomain != null) {
      q.add('subDomain=${Uri.encodeQueryComponent(subDomain)}');
    }
    if (keyword != null) q.add('keyword=${Uri.encodeQueryComponent(keyword)}');
    final String path =
        '$_iepPath/templates/grouped${q.isEmpty ? '' : '?${q.join('&')}'}';
    final dynamic data = await apiClient.get(path);
    if (data is! List) return const <IepTemplateGroup>[];
    return data
        .whereType<Map<String, dynamic>>()
        .map((e) => IepTemplateGroup.fromJson(e))
        .toList();
  }

  /// 取档案当前 IEP 计划（含目标列表 + 阶段统计）。
  Future<IepPlan> getIepPlan(String archiveId) async {
    final dynamic data = await apiClient.get('$_iepPath/plans/$archiveId');
    if (data is! Map<String, dynamic>) {
      throw const ApiException('IEP 计划响应异常');
    }
    return IepPlan.fromJson(data);
  }

  /// 保存 / 更新计划（追加模板 + 删除目标）。去重由后端按 templateId 保证。
  Future<IepPlan> saveIepPlan(IepPlanSaveRequest req) async {
    final dynamic data = await apiClient.post('$_iepPath/plans', req.toJson());
    if (data is! Map<String, dynamic>) {
      throw const ApiException('IEP 保存响应异常');
    }
    return IepPlan.fromJson(data);
  }

  /// 删除单个目标。
  Future<void> removeIepGoal(int goalId) async {
    await apiClient.delete('$_iepPath/plans/goals/$goalId');
  }

  /// 更新单个目标阶段。
  Future<IepPlanGoal> updateIepGoalPhase(int goalId, String phase) async {
    final dynamic data = await apiClient.put(
        '$_iepPath/plans/goals/$goalId/phase?phase=${Uri.encodeQueryComponent(phase)}');
    if (data is! Map<String, dynamic>) {
      throw const ApiException('阶段更新响应异常');
    }
    return IepPlanGoal.fromJson(data);
  }

  /// AI 推荐（按年龄段 + 薄弱领域）。
  Future<IepPlan> aiRecommendIep({
    required String archiveId,
    String? ageBand,
    required List<String> weakDomains,
  }) async {
    final dynamic data = await apiClient.post('$_iepPath/plans/ai-recommend',
        <String, dynamic>{
          'archiveId': archiveId,
          if (ageBand != null) 'ageBand': ageBand,
          'weakDomains': weakDomains,
        });
    if (data is! Map<String, dynamic>) {
      throw const ApiException('AI 推荐响应异常');
    }
    return IepPlan.fromJson(data);
  }

  /// 导出 PDF（返回字节流）。
  Future<Uint8List> exportIepPdf(String archiveId) async {
    return apiClient.getBytes('$_iepPath/plans/$archiveId/export/pdf');
  }
}
