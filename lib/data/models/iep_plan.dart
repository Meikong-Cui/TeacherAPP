// IEP 数据模型（对接后端 oa-rehab /iep 接口）。
// 旧版的「按 8 大领域本地 JSON 字段存储」已废弃，改为后端专用 iep_plan / iep_plan_goal 表。

/// IEP 目标阶段（4 档）。
enum IepPhase {
  passed('PASSED', '已通过'),
  inProgress('IN_PROGRESS', '干预中'),
  stopped('STOPPED', '已停止'),
  notStarted('NOT_STARTED', '未开始');

  const IepPhase(this.code, this.label);
  final String code;
  final String label;

  static IepPhase fromCode(String? c) => IepPhase.values.firstWhere(
        (p) => p.code == c,
        orElse: () => IepPhase.notStarted,
      );
}

/// 年龄段常量（与后端 iep_template.age_band 对齐）。
const List<String> kIepAgeBands = <String>[
  '1-2岁',
  '2-3岁',
  '3-4岁',
  '4-5岁',
  '5岁以上',
];

/// IEP 模板领域（用于 AI 推荐时选择薄弱领域）。
const List<String> kIepDomains = <String>[
  '感知觉',
  '动作发展',
  '认知',
  '沟通',
  '社交情绪',
  '生活自理',
  '游戏',
  '发音',
  '行为管理',
];

/// 单条 IEP 模板（来自后端 iep_template 表）。
class IepTemplate {
  const IepTemplate({
    required this.id,
    required this.ageBand,
    required this.domain,
    required this.subDomain,
    required this.interventionGoal,
    required this.stageGoal,
    this.sortOrder = 0,
  });

  final int id;
  final String ageBand;
  final String domain;
  final String subDomain;
  final String interventionGoal;
  final String stageGoal;
  final int sortOrder;

  factory IepTemplate.fromJson(Map<String, dynamic> j) => IepTemplate(
        id: (j['id'] as int?) ?? 0,
        ageBand: (j['ageBand'] as String?) ?? '',
        domain: (j['domain'] as String?) ?? '',
        subDomain: (j['subDomain'] as String?) ?? '',
        interventionGoal: (j['interventionGoal'] as String?) ?? '',
        stageGoal: (j['stageGoal'] as String?) ?? '',
        sortOrder: (j['sortOrder'] as int?) ?? 0,
      );
}

/// 分组结构：子领域 → 模板条目。
class IepTemplateSub {
  const IepTemplateSub({required this.subDomain, required this.items});
  final String subDomain;
  final List<IepTemplate> items;

  factory IepTemplateSub.fromJson(Map<String, dynamic> j) => IepTemplateSub(
        subDomain: (j['subDomain'] as String?) ?? '',
        items: (j['items'] as List?)
                ?.whereType<Map<String, dynamic>>()
                .map((e) => IepTemplate.fromJson(e))
                .toList() ??
            const <IepTemplate>[],
      );
}

/// 分组结构：领域 → 子领域。
class IepTemplateDomain {
  const IepTemplateDomain(
      {required this.domain, required this.subDomains});
  final String domain;
  final List<IepTemplateSub> subDomains;

  factory IepTemplateDomain.fromJson(Map<String, dynamic> j) =>
      IepTemplateDomain(
        domain: (j['domain'] as String?) ?? '',
        subDomains: (j['subDomains'] as List?)
                ?.whereType<Map<String, dynamic>>()
                .map((e) => IepTemplateSub.fromJson(e))
                .toList() ??
            const <IepTemplateSub>[],
      );
}

/// 分组结构：年龄段 → 领域（对应后端 IepTemplateGroupVO）。
class IepTemplateGroup {
  const IepTemplateGroup({required this.ageBand, required this.domains});
  final String ageBand;
  final List<IepTemplateDomain> domains;

  factory IepTemplateGroup.fromJson(Map<String, dynamic> j) =>
      IepTemplateGroup(
        ageBand: (j['ageBand'] as String?) ?? '',
        domains: (j['domains'] as List?)
                ?.whereType<Map<String, dynamic>>()
                .map((e) => IepTemplateDomain.fromJson(e))
                .toList() ??
            const <IepTemplateDomain>[],
      );
}

/// 单条 IEP 计划目标（来自后端 iep_plan_goal 表）。
class IepPlanGoal {
  const IepPlanGoal({
    required this.id,
    this.planId,
    this.templateId,
    required this.ageBand,
    required this.domain,
    required this.subDomain,
    required this.interventionGoal,
    required this.stageGoal,
    this.phase = IepPhase.notStarted,
    this.aiSuggested = false,
    this.sortOrder = 0,
  });

  final int id;
  final int? planId;
  final int? templateId;
  final String ageBand;
  final String domain;
  final String subDomain;
  final String interventionGoal;
  final String stageGoal;
  final IepPhase phase;
  final bool aiSuggested;
  final int sortOrder;

  IepPlanGoal copyWith({IepPhase? phase}) => IepPlanGoal(
        id: id,
        planId: planId,
        templateId: templateId,
        ageBand: ageBand,
        domain: domain,
        subDomain: subDomain,
        interventionGoal: interventionGoal,
        stageGoal: stageGoal,
        phase: phase ?? this.phase,
        aiSuggested: aiSuggested,
        sortOrder: sortOrder,
      );

  factory IepPlanGoal.fromJson(Map<String, dynamic> j) => IepPlanGoal(
        id: (j['id'] as int?) ?? 0,
        planId: (j['planId'] as int?) ?? (j['plan_id'] as int?),
        templateId: (j['templateId'] as int?) ?? (j['template_id'] as int?),
        ageBand: (j['ageBand'] as String?) ?? '',
        domain: (j['domain'] as String?) ?? '',
        subDomain: (j['subDomain'] as String?) ?? '',
        interventionGoal: (j['interventionGoal'] as String?) ?? '',
        stageGoal: (j['stageGoal'] as String?) ?? '',
        phase: IepPhase.fromCode(j['phase'] as String?),
        aiSuggested: (j['aiSuggested'] as bool?) ?? false,
        sortOrder: (j['sortOrder'] as int?) ?? 0,
      );
}

/// IEP 计划（对应后端 IepPlanVO）。
class IepPlan {
  const IepPlan({
    this.id,
    required this.archiveId,
    this.childName = '',
    this.ageBand = '',
    this.planner = '',
    this.startDate,
    this.endDate,
    this.status = 'DRAFT',
    this.phaseCounts = const <String, int>{},
    this.goals = const <IepPlanGoal>[],
  });

  final int? id;
  final String archiveId;
  final String childName;
  final String ageBand;
  final String planner;
  final String? startDate;
  final String? endDate;
  final String status;
  final Map<String, int> phaseCounts;
  final List<IepPlanGoal> goals;

  bool get isEmpty => goals.isEmpty;

  factory IepPlan.fromJson(Map<String, dynamic> j) {
    final dynamic pc = j['phaseCounts'];
    final Map<String, int> counts = <String, int>{};
    if (pc is Map) {
      pc.forEach((k, v) => counts[k.toString()] = (v as int?) ?? 0);
    }
    return IepPlan(
      id: (j['id'] as int?) ?? (j['planId'] as int?),
      archiveId: (j['archiveId']?.toString()) ?? '',
      childName: (j['childName'] as String?) ?? '',
      ageBand: (j['ageBand'] as String?) ?? '',
      planner: (j['planner'] as String?) ?? '',
      startDate: (j['startDate'] as String?),
      endDate: (j['endDate'] as String?),
      status: (j['status'] as String?) ?? 'DRAFT',
      phaseCounts: counts,
      goals: (j['goals'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .map((e) => IepPlanGoal.fromJson(e))
              .toList() ??
          const <IepPlanGoal>[],
    );
  }

  IepPlan copyWith({
    int? id,
    String? archiveId,
    String? childName,
    String? ageBand,
    String? planner,
    String? startDate,
    String? endDate,
    String? status,
    Map<String, int>? phaseCounts,
    List<IepPlanGoal>? goals,
  }) =>
      IepPlan(
        id: id ?? this.id,
        archiveId: archiveId ?? this.archiveId,
        childName: childName ?? this.childName,
        ageBand: ageBand ?? this.ageBand,
        planner: planner ?? this.planner,
        startDate: startDate ?? this.startDate,
        endDate: endDate ?? this.endDate,
        status: status ?? this.status,
        phaseCounts: phaseCounts ?? this.phaseCounts,
        goals: goals ?? this.goals,
      );
}

/// 保存/更新 IEP 计划请求（对应后端 IepPlanSaveRequest）。
class IepPlanSaveRequest {
  IepPlanSaveRequest({
    required this.archiveId,
    this.childName,
    this.ageBand,
    this.planner,
    this.startDate,
    this.endDate,
    this.appendTemplateIds = const <int>[],
    this.removedGoalIds = const <int>[],
  });

  final String archiveId;
  final String? childName;
  final String? ageBand;
  final String? planner;
  final String? startDate;
  final String? endDate;
  final List<int> appendTemplateIds;
  final List<int> removedGoalIds;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'archiveId': archiveId,
        if (childName != null) 'childName': childName,
        if (ageBand != null) 'ageBand': ageBand,
        if (planner != null) 'planner': planner,
        if (startDate != null) 'startDate': startDate,
        if (endDate != null) 'endDate': endDate,
        'appendTemplateIds': appendTemplateIds,
        'removedGoalIds': removedGoalIds,
      };
}
