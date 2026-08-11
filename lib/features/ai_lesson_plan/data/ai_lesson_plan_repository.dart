import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:teacher_app/core/api_client.dart';
import 'package:teacher_app/core/auth_store.dart';
import 'package:teacher_app/core/constants.dart';
import 'package:teacher_app/data/models/rehab.dart';

/// AI 教案生成数据层。
///
/// 真实调用后端 `oa-ai` 模块：
///   POST /api/ai/lesson-plan         —— 生成 5 大领域教案（DeepSeek）
///   GET  /api/ai/lesson-plan/{id}/pdf —— 导出 1.1.4 听障儿童日常教学记录 PDF
/// 角色门禁 `TEACHER,PRINCIPAL`；JWT 由 [apiClient] 自动附带。
class AiLessonPlanRepository {
  const AiLessonPlanRepository();

  /// 生成教案：传入儿童上下文，返回结构化 5 领域结果。
  Future<AiLessonPlanResult> generate(AiLessonPlanRequest req) async {
    final dynamic data = await apiClient.post(
      AppConstants.aiLessonPlanPath,
      req.toJson(),
    );
    return AiLessonPlanResult.fromJson(data as Map<String, dynamic>);
  }

  /// 下载已生成教案的 PDF 字节（1.1.4 格式，含中文）。
  Future<Uint8List> downloadPdf(int id) async {
    final Uri uri =
        Uri.parse('${AppConstants.apiBaseUrl}${AppConstants.aiLessonPlanPath}/$id/pdf');
    final http.Response resp = await http.get(uri, headers: <String, String>{
      'Authorization': 'Bearer ${AuthStore.instance.token ?? ''}',
    });
    if (resp.statusCode != 200) {
      throw ApiException('PDF 下载失败（${resp.statusCode}）', resp.statusCode);
    }
    return resp.bodyBytes;
  }

  /// 保存教师最终定稿：服务端会与 AI 生成内容做 DIFF 并记录（学习教师风格）。
  Future<AiLessonPlanResult> saveFinal(
      int id, Map<String, dynamic> finalDomains) async {
    final dynamic data = await apiClient.put(
      '${AppConstants.aiLessonPlanPath}/$id',
      <String, dynamic>{'finalResult': finalDomains},
    );
    return AiLessonPlanResult.fromJson(data as Map<String, dynamic>);
  }
}

/// 生成请求：听障儿童个别化教学记录所需的上下文字段。
class AiLessonPlanRequest {
  const AiLessonPlanRequest({
    this.archiveId,
    this.childId,
    this.iepGoalId,
    required this.childName,
    required this.gender,
    required this.physiologicalAge,
    required this.hearingAge,
    required this.deviceWear,
    required this.targetPhonemes,
    required this.lessonTheme,
    this.extra,
  });

  final int? archiveId;
  final int? childId;
  final int? iepGoalId;
  final String childName;
  final String gender;
  final String physiologicalAge;
  final String hearingAge;
  final String deviceWear;
  final String targetPhonemes;
  final String lessonTheme;
  final String? extra;

  Map<String, dynamic> toJson() => <String, dynamic>{
        if (archiveId != null) 'archiveId': archiveId,
        if (childId != null) 'childId': childId,
        if (iepGoalId != null) 'iepGoalId': iepGoalId,
        'childName': childName,
        'gender': gender,
        'physiologicalAge': physiologicalAge,
        'hearingAge': hearingAge,
        'deviceWear': deviceWear,
        'targetPhonemes': targetPhonemes,
        'lessonTheme': lessonTheme,
        if (extra != null && extra!.isNotEmpty) 'extra': extra,
      };
}

/// 单领域内容（内容 + 设备/玩具/图书/备注）。
class DomainContent {
  const DomainContent({required this.content, required this.materials});

  final String content;
  final String materials;

  factory DomainContent.fromJson(Map<String, dynamic> json) => DomainContent(
        content: (json['content'] as String?) ?? '',
        materials: (json['materials'] as String?) ?? '',
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'content': content,
        'materials': materials,
      };
}

/// 教案生成结果。
///
/// [domains] 仅含听能发展→沟通技能 5 个领域；符号（√/＋/✗/⊥）由教师在课堂记录，
/// 不在此生成。
class AiLessonPlanResult {
  const AiLessonPlanResult({
    required this.id,
    this.status = 0,
    required this.childName,
    required this.gender,
    required this.physiologicalAge,
    required this.hearingAge,
    required this.deviceWear,
    required this.targetPhonemes,
    required this.lessonTheme,
    required this.domains,
  });

  final int id;
  final int status;
  final String childName;
  final String gender;
  final String physiologicalAge;
  final String hearingAge;
  final String deviceWear;
  final String targetPhonemes;
  final String lessonTheme;
  final Map<String, DomainContent> domains;

  /// 5 个领域的固定顺序与中文标题。
  static const List<(String, String)> orderedDomains = <(String, String)>[
    ('auditoryDevelopment', '听能发展'),
    ('speechDevelopment', '言语发展'),
    ('languageDevelopment', '语言发展'),
    ('cognitiveDevelopment', '认知发展'),
    ('communicationSkills', '沟通技能'),
  ];

  /// 将当前 5 领域内容序列化为后端 PUT 所需的 finalResult 结构。
  Map<String, dynamic> get domainsJson {
    final Map<String, dynamic> out = <String, dynamic>{};
    for (final (String key, _) in orderedDomains) {
      out[key] = domains[key]?.toJson() ?? <String, dynamic>{
        'content': '',
        'materials': '',
      };
    }
    return out;
  }

  factory AiLessonPlanResult.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> sr =
        (json['structuredResult'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final Map<String, DomainContent> domains = <String, DomainContent>{};
    for (final (String key, _) in orderedDomains) {
      final dynamic v = sr[key];
      if (v is Map<String, dynamic>) {
        domains[key] = DomainContent.fromJson(v);
      }
    }
    return AiLessonPlanResult(
      id: (json['id'] as int?) ?? 0,
      status: (json['status'] as int?) ?? 0,
      childName: (json['childName'] as String?) ?? '',
      gender: (json['gender'] as String?) ?? '',
      physiologicalAge: (json['physiologicalAge'] as String?) ?? '',
      hearingAge: (json['hearingAge'] as String?) ?? '',
      deviceWear: (json['deviceWear'] as String?) ?? '',
      targetPhonemes: (json['targetPhonemes'] as String?) ?? '',
      lessonTheme: (json['lessonTheme'] as String?) ?? '',
      domains: domains,
    );
  }
}

/// 从学生档案「AI 补全」按钮跳转时的上下文（携带儿童信息与目标教学计划）。
class AiLessonPlanLaunchContext {
  const AiLessonPlanLaunchContext({
    this.archiveId,
    this.childId,
    this.childName = '',
    this.gender = '',
    this.physiologicalAge = '',
    this.hearingAge = '',
    this.deviceWear = '',
    this.plan,
  });

  final int? archiveId;
  final int? childId;
  final String childName;
  final String gender;
  final String physiologicalAge;
  final String hearingAge;
  final String deviceWear;
  final RehabTeachingPlan? plan;
}
