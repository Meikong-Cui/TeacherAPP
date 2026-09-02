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
  Future<List<RehabPhoto>> listPhotos(String archiveId, {String? formType}) async {
    final StringBuffer sb = StringBuffer(
        '${AppConstants.rehabPath}/photos/archive/$archiveId');
    if (formType != null && formType.isNotEmpty) {
      sb.write('?formType=${Uri.encodeQueryComponent(formType)}');
    }
    final dynamic data = await apiClient.get(sb.toString());
    if (data is! List) return const <RehabPhoto>[];
    return data
        .whereType<Map<String, dynamic>>()
        .map((e) => RehabPhoto.fromJson(e))
        .toList();
  }

  /// 把已经上传到 /api/attachment 的图片 URL 落地为 rehab_photo 一条记录。
  /// [archiveId] [relatedFormType] [filePath] 必填；其他字段可空。
  Future<int> savePhotoRecord({
    required String archiveId,
    required String relatedFormType,
    required String filePath,
    int? fileSize,
    String? mimeType,
    String? remark,
  }) async {
    final dynamic data = await apiClient.post(
      '${AppConstants.rehabPath}/photos',
      <String, dynamic>{
        'archiveId': archiveId,
        'relatedFormType': relatedFormType,
        'filePath': filePath,
        if (fileSize != null) 'fileSize': fileSize,
        if (mimeType != null) 'mimeType': mimeType,
        if (remark != null) 'remark': remark,
      },
    );
    if (data is int) return data;
    return int.tryParse(data?.toString() ?? '0') ?? 0;
  }

  /// 删除一条手写照片。
  Future<void> removePhoto(String photoId) async {
    await apiClient.delete('${AppConstants.rehabPath}/photos/$photoId');
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

  /// 获取全部可用评测量表（残联标准 / OFFLINE / VB …）。
  Future<List<AutismEvalForm>> listEvalForms() async {
    final dynamic data = await apiClient.get('$_autismPath/forms');
    if (data is! List) return const <AutismEvalForm>[];
    return data
        .whereType<Map<String, dynamic>>()
        .map((e) => AutismEvalForm.fromJson(e))
        .toList();
  }

  /// 获取某量表的题项定义（树形：group 总项目 / item 作答项）。
  Future<List<AutismEvalFormItem>> listEvalFormItems(String formCode) async {
    final dynamic data = await apiClient.get('$_autismPath/forms/$formCode/items');
    if (data is! List) return const <AutismEvalFormItem>[];
    return data
        .whereType<Map<String, dynamic>>()
        .map((e) => AutismEvalFormItem.fromJson(e))
        .toList();
  }

  /// 新建一次评估轮次，返回轮次 id（evalSeq 由后端自动递增）。
  Future<String> createEvalRound(AutismEvalRound round) async {
    final dynamic data = await apiClient.post('$_autismPath/rounds', round.toJson());
    return data?.toString() ?? '';
  }

  /// 列出某档案在某量表下的所有评估轮次（按 evalSeq 倒序）。
  Future<List<AutismEvalRound>> listEvalRounds(String archiveId,
      [String? formCode]) async {
    final StringBuffer sb = StringBuffer('$_autismPath/rounds?archiveId=$archiveId');
    if (formCode != null && formCode.isNotEmpty) {
      sb.write('&formCode=${Uri.encodeQueryComponent(formCode)}');
    }
    final dynamic data = await apiClient.get(sb.toString());
    if (data is! List) return const <AutismEvalRound>[];
    return data
        .whereType<Map<String, dynamic>>()
        .map((e) => AutismEvalRound.fromJson(e))
        .toList();
  }

  /// 获取单个轮次详情。
  Future<AutismEvalRound> getEvalRound(String roundId) async {
    final dynamic data = await apiClient.get('$_autismPath/rounds/$roundId');
    if (data is! Map<String, dynamic>) {
      throw const ApiException('评估轮次响应异常');
    }
    return AutismEvalRound.fromJson(data);
  }

  /// 更新轮次元信息（评估日期 / 测评人 / 生心龄等）。
  Future<void> updateEvalRound(AutismEvalRound round) async {
    if (round.id == null) return;
    await apiClient.put('$_autismPath/rounds/${round.id}', round.toJson());
  }

  /// 拉取某轮次的逐题作答。
  Future<List<AutismEvalItem>> listRoundItems(String roundId) async {
    final dynamic data = await apiClient.get('$_autismPath/rounds/$roundId/items');
    if (data is! List) return const <AutismEvalItem>[];
    return data
        .whereType<Map<String, dynamic>>()
        .map((e) => AutismEvalItem.fromJson(e))
        .toList();
  }

  /// 批量保存某轮次逐题作答（空值由后端按删除处理）。
  Future<int> saveRoundItems(String roundId, List<AutismEvalItem> items) async {
    final dynamic data = await apiClient.post(
      '$_autismPath/rounds/$roundId/items/batch',
      items.map((e) => e.toJson()).toList(),
    );
    if (data is int) return data;
    return int.tryParse(data?.toString() ?? '0') ?? 0;
  }

  /// 拉取某轮次统计（按领域聚合）。
  Future<EvalRoundStats> getRoundStats(String roundId) async {
    final dynamic data = await apiClient.get('$_autismPath/rounds/$roundId/stats');
    if (data is! Map<String, dynamic>) {
      throw const ApiException('评估统计响应异常');
    }
    return EvalRoundStats.fromJson(data);
  }

  // ════════════════════════════════════════════════════════════════
  //  线下模板评估（OFFLINE）：A/B 卷答题 + 7 领域得分 + 3 报告
  // ══════════════════════════════════════════════════════════════

  /// A/B 卷题项模板（无题干，仅题号+选项+归属领域）。
  Future<List<Map<String, dynamic>>> listOfflineItems(String paper) async {
    final dynamic data =
        await apiClient.get('$_autismPath/offline/items?paper=${Uri.encodeQueryComponent(paper)}');
    if (data is! List) return const <Map<String, dynamic>>[];
    return data.whereType<Map<String, dynamic>>().toList();
  }

  /// 某档案某卷的已答记录。
  /// `roundId` 非空时按 round 答案 JSON 取（评估历史中点 round 进答题时使用）。
  Future<List<Map<String, dynamic>>> listOfflineAnswers(
      String archiveId, String paper, {String? roundId}) async {
    final String qs = roundId != null && roundId.isNotEmpty
        ? '&roundId=${Uri.encodeQueryComponent(roundId)}'
        : '';
    final dynamic data = await apiClient.get(
        '$_autismPath/offline/answers?archiveId=$archiveId&paper=${Uri.encodeQueryComponent(paper)}$qs');
    if (data is! List) return const <Map<String, dynamic>>[];
    return data.whereType<Map<String, dynamic>>().toList();
  }

  /// 保存某卷答题（items: [{itemId, value}]）。返回保存条数。
  /// `roundId` 非空时双写主表与 round 的答案 JSON（让主页「第三份报告」与该 round 的报告都即时刷新）。
  Future<int> saveOfflineAnswers(String archiveId, String paper,
      List<Map<String, dynamic>> items, {String? roundId}) async {
    final Map<String, dynamic> body = <String, dynamic>{
      'archiveId': archiveId,
      'paper': paper,
      'items': items,
    };
    if (roundId != null && roundId.isNotEmpty) body['roundId'] = roundId;
    final dynamic data = await apiClient.post('$_autismPath/offline/answers', body);
    if (data is int) return data;
    return int.tryParse(data?.toString() ?? '0') ?? 0;
  }

  /// 7 领域得分 + 适应年龄当量（缺则补空行，score=null）。
  Future<List<Map<String, dynamic>>> getOfflineResult(String archiveId) async {
    final dynamic data =
        await apiClient.get('$_autismPath/offline/result?archiveId=$archiveId');
    if (data is! List) return const <Map<String, dynamic>>[];
    return data.whereType<Map<String, dynamic>>().toList();
  }

  /// 保存 7 领域得分（results: [{domainKey, score, ageEquivalent}]）。
  /// A、B 两卷均完成时后端自动生成 3 份报告。
  Future<List<Map<String, dynamic>>> saveOfflineResult(
      String archiveId, List<Map<String, dynamic>> results) async {
    final dynamic data = await apiClient.post('$_autismPath/offline/result', <String, dynamic>{
      'archiveId': archiveId,
      'results': results,
    });
    if (data is! List) return const <Map<String, dynamic>>[];
    return data.whereType<Map<String, dynamic>>().toList();
  }

  /// 单份报告（type: EVAL / TEACHER / PARENT），返回 content_json 原始 Map。
  Future<Map<String, dynamic>?> getOfflineReport(String archiveId, String type) async {
    final dynamic data = await apiClient
        .get('$_autismPath/offline/report?archiveId=$archiveId&type=${Uri.encodeQueryComponent(type)}');
    if (data is! Map<String, dynamic>) return null;
    return data;
  }

  /// 报告列表（用于详情页显示生成状态）。
  Future<List<Map<String, dynamic>>> listOfflineReports(String archiveId) async {
    final dynamic data =
        await apiClient.get('$_autismPath/offline/report/list?archiveId=$archiveId');
    if (data is! List) return const <Map<String, dynamic>>[];
    return data.whereType<Map<String, dynamic>>().toList();
  }

  /// B卷评分结果：按年龄段统计通过情况，返回最大通过段与对应评语（教师/家长）。
  /// 后端 GET /autism/offline/b-result?archiveId=
  Future<Map<String, dynamic>> getOfflineBResult(String archiveId) async {
    final dynamic data = await apiClient
        .get('$_autismPath/offline/b-result?archiveId=$archiveId');
    if (data is! Map<String, dynamic>) {
      throw const ApiException('B卷评分响应异常');
    }
    return data;
  }

  /// A卷得分总览：7 领域类型得分/满分 + 总分，用于发展功能剖面图。
  /// 后端 GET /autism/offline/a-overview?archiveId= (&roundId= 可选)
  Future<Map<String, dynamic>> getOfflineAOverview(String archiveId,
      {String? roundId}) async {
    final String qs = roundId != null && roundId.isNotEmpty
        ? '&roundId=${Uri.encodeQueryComponent(roundId)}'
        : '';
    final dynamic data = await apiClient
        .get('$_autismPath/offline/a-overview?archiveId=$archiveId$qs');
    if (data is! Map<String, dynamic>) {
      throw const ApiException('A卷得分总览响应异常');
    }
    return data;
  }

  /// 9 行评估报告（教师版 TEACHER / 家长版 PARENT）：个人自理来自 B卷，其余 8 行占位待 A卷评语。
  /// 后端 GET /autism/offline/eval-report?archiveId=&type=
  Future<Map<String, dynamic>> getOfflineEvalReport(
      String archiveId, String type) async {
    final dynamic data = await apiClient.get(
      '$_autismPath/offline/eval-report'
      '?archiveId=${Uri.encodeQueryComponent(archiveId)}'
      '&type=${Uri.encodeQueryComponent(type)}',
    );
    if (data is! Map<String, dynamic>) {
      throw const ApiException('9 行评估报告响应异常');
    }
    return data;
  }

  /// 9 行评估报告 PDF（返回字节流，教师版/家长版）。
  /// [itemsParam] 为 URL 编码后的小项选择 JSON；为 null 时按全量导出。
  /// 后端 GET /autism/offline/eval-report/pdf?archiveId=&type=&items=
  Future<Uint8List> getOfflineEvalReportPdf(
      String archiveId, String type, {String? itemsParam}) async {
    final StringBuffer qs = StringBuffer(
      '?archiveId=${Uri.encodeQueryComponent(archiveId)}'
      '&type=${Uri.encodeQueryComponent(type)}',
    );
    if (itemsParam != null && itemsParam.isNotEmpty) {
      qs.write('&items=$itemsParam');
    }
    return apiClient.getBytes('$_autismPath/offline/eval-report/pdf$qs');
  }

  /// 归档当前线下模板草稿为新一轮评估，返回轮次 id（int）。
  /// 后端 POST /autism/offline/rounds
  Future<int> createOfflineRound(String archiveId, {String? evaluatorName}) async {
    final Map<String, dynamic> body = <String, dynamic>{'archiveId': archiveId};
    if (evaluatorName != null) body['evaluatorName'] = evaluatorName;
    final dynamic data = await apiClient.post('$_autismPath/offline/rounds', body);
    if (data is int) return data;
    return int.tryParse(data?.toString() ?? '0') ?? 0;
  }

  /// 列出某档案的全部线下模板评估轮次（倒序）。
  /// 后端 GET /autism/offline/rounds?archiveId=
  Future<List<Map<String, dynamic>>> listOfflineRounds(String archiveId) async {
    final dynamic data = await apiClient
        .get('$_autismPath/offline/rounds?archiveId=${Uri.encodeQueryComponent(archiveId)}');
    if (data is! List) return const <Map<String, dynamic>>[];
    return data.whereType<Map<String, dynamic>>().toList();
  }

  /// 单个轮次详情（含 A/B 答题、7 领域结果、教师/家长版报告快照）。
  /// 后端 GET /autism/offline/rounds/{id}
  Future<Map<String, dynamic>?> getOfflineRound(String roundId) async {
    final dynamic data = await apiClient
        .get('$_autismPath/offline/rounds/${Uri.encodeQueryComponent(roundId)}');
    if (data is! Map<String, dynamic>) return null;
    return data;
  }

  /// 保存某轮评估报告「康复目标 / 指导说明」的小项勾选结果。
  /// [items] 结构：project -> { 'rehabGoal': [序号...], 'guidance': [序号...] }。
  /// 后端 POST /autism/offline/rounds/{id}/guidance
  Future<void> saveOfflineRoundGuidance(
      String roundId, Map<String, Map<String, List<int>>> items) async {
    await apiClient.post(
      '$_autismPath/offline/rounds/${Uri.encodeQueryComponent(roundId)}/guidance',
      <String, dynamic>{'items': items},
    );
  }

  /// 单个轮次报告 PDF（教师版/家长版），返回字节流。
  /// 后端 GET /autism/offline/rounds/{id}/report/pdf?role=
  Future<Uint8List> getOfflineRoundReportPdf(String roundId, String role) async {
    return apiClient.getBytes(
      '$_autismPath/offline/rounds/${Uri.encodeQueryComponent(roundId)}/report/pdf'
      '?role=${Uri.encodeQueryComponent(role)}',
    );
  }

  /// 第三份报告（发展总览）PDF：A 卷得分总览计数 + 发展功能剖面图，返回字节流。
  /// `roundId` 非空时按 round 答案 JSON 出 PDF。
  /// 后端 GET /autism/offline/overview/report/pdf?archiveId= (&roundId= 可选)
  Future<Uint8List> getOfflineOverviewReportPdf(String archiveId, {String? roundId}) async {
    final String qs = roundId != null && roundId.isNotEmpty
        ? '&roundId=${Uri.encodeQueryComponent(roundId)}'
        : '';
    return apiClient.getBytes(
      '$_autismPath/offline/overview/report/pdf'
      '?archiveId=${Uri.encodeQueryComponent(archiveId)}$qs',
    );
  }

  // ========== PEP-3 模板（跳过答题，直接填各领域预估年龄）==========

  /// PEP-3 的 9 个项目及其可选年龄档（月）。
  /// 后端 GET /autism/pep3/age-bands
  Future<Map<String, dynamic>> getPep3AgeBands() async {
    final dynamic data = await apiClient.get('$_autismPath/pep3/age-bands');
    if (data is! Map<String, dynamic>) return const <String, dynamic>{};
    return data;
  }

  /// 预览：按当前月龄算报告，不落库。role 为 TEACHER / PARENT。
  /// 后端 POST /autism/pep3/preview
  Future<Map<String, dynamic>> previewPep3Report(
    Map<String, int> ages, {
    String role = 'TEACHER',
    String? archiveId,
  }) async {
    final dynamic data = await apiClient.post(
      '$_autismPath/pep3/preview',
      <String, dynamic>{
        'ages': ages,
        'role': role,
        if (archiveId != null) 'archiveId': archiveId,
      },
    );
    if (data is! Map<String, dynamic>) {
      throw const ApiException('PEP-3 预览响应异常');
    }
    return data;
  }

  /// 新建一轮 PEP-3 评估，返回轮次 id。
  /// 后端 POST /autism/pep3/rounds
  Future<int> createPep3Round(
    String archiveId,
    Map<String, int> ages, {
    String? evaluatorName,
  }) async {
    final dynamic data = await apiClient.post(
      '$_autismPath/pep3/rounds',
      <String, dynamic>{
        'archiveId': archiveId,
        'ages': ages,
        if (evaluatorName != null) 'evaluatorName': evaluatorName,
      },
    );
    if (data is int) return data;
    return int.tryParse(data?.toString() ?? '0') ?? 0;
  }

  /// 列出某档案的全部 PEP-3 评估轮次（倒序）。
  /// 后端 GET /autism/pep3/rounds?archiveId=
  Future<List<Map<String, dynamic>>> listPep3Rounds(String archiveId) async {
    final dynamic data = await apiClient
        .get('$_autismPath/pep3/rounds?archiveId=${Uri.encodeQueryComponent(archiveId)}');
    if (data is! List) return const <Map<String, dynamic>>[];
    return data.whereType<Map<String, dynamic>>().toList();
  }

  /// 单个 PEP-3 轮次详情（月龄 + 档位解析 + 教师/家长版报告）。
  /// 后端 GET /autism/pep3/rounds/{id}
  Future<Map<String, dynamic>?> getPep3Round(String roundId) async {
    final dynamic data = await apiClient
        .get('$_autismPath/pep3/rounds/${Uri.encodeQueryComponent(roundId)}');
    if (data is! Map<String, dynamic>) return null;
    return data;
  }

  /// 编辑某轮 PEP-3 评估：重填月龄并重出报告，返回最新详情。
  /// 后端 PUT /autism/pep3/rounds/{id}
  Future<Map<String, dynamic>?> updatePep3Round(
    String roundId,
    Map<String, int> ages, {
    String? evaluatorName,
  }) async {
    final dynamic data = await apiClient.put(
      '$_autismPath/pep3/rounds/${Uri.encodeQueryComponent(roundId)}',
      <String, dynamic>{
        'ages': ages,
        if (evaluatorName != null) 'evaluatorName': evaluatorName,
      },
    );
    if (data is! Map<String, dynamic>) return null;
    return data;
  }

  /// 保存某轮 PEP-3 报告「康复目标 / 指导说明」的小项勾选结果。
  /// 后端 POST /autism/pep3/rounds/{id}/guidance
  Future<void> savePep3RoundGuidance(
      String roundId, Map<String, Map<String, List<int>>> items) async {
    await apiClient.post(
      '$_autismPath/pep3/rounds/${Uri.encodeQueryComponent(roundId)}/guidance',
      <String, dynamic>{'items': items},
    );
  }

  /// 单轮 PEP-3 报告 PDF（教师版/家长版），返回字节流。
  /// 后端 GET /autism/pep3/rounds/{id}/report/pdf?role=
  Future<Uint8List> getPep3RoundReportPdf(String roundId, String role) async {
    return apiClient.getBytes(
      '$_autismPath/pep3/rounds/${Uri.encodeQueryComponent(roundId)}/report/pdf'
      '?role=${Uri.encodeQueryComponent(role)}',
    );
  }

  /// VB 计分：对某评估轮次计分并保存各维度得分，返回维度得分与儿童情况说明。
  /// 后端 POST /autism/vb/score?roundId=
  Future<Map<String, dynamic>> vbScore(String roundId) async {
    final dynamic data = await apiClient
        .post('$_autismPath/vb/score?roundId=${Uri.encodeQueryComponent(roundId)}');
    if (data is! Map<String, dynamic>) {
      throw const ApiException('VB 计分响应异常');
    }
    return data;
  }

  /// VB 多次评估趋势：同一儿童同一表单每次评估的维度得分折线序列。
  /// 后端 GET /autism/vb/trend?archiveId=&formCode=
  Future<Map<String, dynamic>> vbTrend(String archiveId, String formCode) async {
    final dynamic data = await apiClient.get(
      '$_autismPath/vb/trend'
      '?archiveId=${Uri.encodeQueryComponent(archiveId)}'
      '&formCode=${Uri.encodeQueryComponent(formCode)}',
    );
    if (data is! Map<String, dynamic>) {
      throw const ApiException('VB 趋势响应异常');
    }
    return data;
  }

  /// VB 评估报告（维度得分表 + 柱状图）PDF/DOCX，返回字节流（带鉴权）。
  /// 后端 GET /autism/vb/report?roundId=&format=
  Future<Uint8List> getVbReportPdf(String roundId, {String format = 'pdf'}) async {
    return apiClient.getBytes(
      '$_autismPath/vb/report'
      '?roundId=${Uri.encodeQueryComponent(roundId)}'
      '&format=${Uri.encodeQueryComponent(format)}',
    );
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

  // ══════════════════════════════════════════════════════════════════
  //  听障档案导出（后端生成：扫描件模板逐页叠字 → PDF）
  //
  //  与 OA 网页用的是同一批接口，导出的就是那套官方表单（1.1.1 首次评估 /
  //  1.2.1 听能诊断记录等），不是 App 本地另拼的版式。
  //  端点见 RehabController：GET /api/rehab/hearing/export/...
  // ══════════════════════════════════════════════════════════════════

  /// 整档（首次 + 持续 + 听能 + 计划）合订本。
  Future<Uint8List> exportHearingArchivePdf(String archiveId) =>
      apiClient.getBytes(
          '${AppConstants.rehabPath}/hearing/export/$archiveId?format=pdf');

  /// 单项：首次评估。
  Future<Uint8List> exportHearingFirstEvalPdf(String firstEvalId) =>
      apiClient.getBytes(
          '${AppConstants.rehabPath}/hearing/export/first-eval/$firstEvalId?format=pdf');

  /// 单项：持续评估。
  Future<Uint8List> exportHearingContEvalPdf(String contEvalId) =>
      apiClient.getBytes(
          '${AppConstants.rehabPath}/hearing/export/cont-eval/$contEvalId?format=pdf');

  /// 单项：听能管理记录。
  Future<Uint8List> exportHearingRecordPdf(String recordId) =>
      apiClient.getBytes(
          '${AppConstants.rehabPath}/hearing/export/hearing-record/$recordId?format=pdf');

  /// 单项：教学计划。
  Future<Uint8List> exportHearingPlanPdf(String planId) =>
      apiClient.getBytes(
          '${AppConstants.rehabPath}/hearing/export/plan/$planId?format=pdf');
}
