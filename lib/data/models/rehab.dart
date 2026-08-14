import 'dart:convert';

/// 康复档案状态。
enum ArchiveStatus {
  draft(1, '草稿'),
  archived(2, '已归档');

  const ArchiveStatus(this.code, this.label);
  final int code;
  final String label;
  static ArchiveStatus fromCode(int? c) =>
      ArchiveStatus.values.firstWhere((e) => e.code == c,
          orElse: () => ArchiveStatus.draft);
}

/// 持续评估状态。
enum ContEvalStatus {
  pending(0, '待填写'),
  done(1, '已完成'),
  overdue(2, '逾期');

  const ContEvalStatus(this.code, this.label);
  final int code;
  final String label;
  static ContEvalStatus fromCode(int? c) =>
      ContEvalStatus.values.firstWhere((e) => e.code == c,
          orElse: () => ContEvalStatus.pending);
}

/// 公章审批状态。
enum SealStatus {
  pending(0, '待审批'),
  approved(1, '已通过'),
  rejected(2, '已驳回');

  const SealStatus(this.code, this.label);
  final int code;
  final String label;
  static SealStatus fromCode(int? c) =>
      SealStatus.values.firstWhere((e) => e.code == c,
          orElse: () => SealStatus.pending);
}

DateTime? _dt(dynamic v) =>
    v == null ? null : DateTime.tryParse(v.toString());

/// 安全地从嵌套 Map 中取值（跨库公开，供 UI 层调用）。
String jsonStr(Map<String, dynamic>? data, List<String> path) {
  if (data == null) return '';
  dynamic cur = data;
  for (final k in path) {
    if (cur is! Map<String, dynamic>) return '';
    cur = cur[k];
    if (cur == null) return '';
  }
  return cur.toString();
}

/// 安全地将值写入嵌套 Map（返回新 Map，不修改原 Map）。
Map<String, dynamic> jsonSet(
    Map<String, dynamic>? data, List<String> path, dynamic value) {
  data = data != null ? Map<String, dynamic>.from(data) : <String, dynamic>{};
  Map<String, dynamic> current = data;
  for (int i = 0; i < path.length - 1; i++) {
    final k = path[i];
    if (current[k] is! Map<String, dynamic>) {
      current[k] = <String, dynamic>{};
    }
    current = current[k] as Map<String, dynamic>;
  }
  current[path.last] = value;
  return data;
}

/// 解析可能为 String 或 Map 的 JSON 字段（供两个评估模型共用）。
Map<String, dynamic>? _parseJson(dynamic v) {
  if (v is Map<String, dynamic>) return Map<String, dynamic>.from(v);
  if (v is String && v.isNotEmpty) {
    try { return jsonDecode(v) as Map<String, dynamic>; } catch (_) { /* fall */ }
  }
  return null;
}

/// 康复档案元数据（每个儿童一份）。
class RehabArchive {
  const RehabArchive({
    required this.id,
    this.archiveNo = '',
    this.childName = '',
    this.photoUrl,
    this.status = ArchiveStatus.draft,
    this.campusName = '',
    this.remark,
    this.createTime,
    this.templateType = '',
  });

  final String id;
  final String archiveNo;
  final String childName;
  final String? photoUrl;
  final ArchiveStatus status;
  final String campusName;
  final String? remark;
  final DateTime? createTime;
  final String templateType;

  /// 是否为孤独症档案（决定详情页走孤独症模板）。
  bool get isAutism => templateType.toUpperCase() == 'AUTISM';

  /// 人类可读的特殊教育类型标签。
  String get typeLabel => isAutism ? '孤独症' : '听障';

  factory RehabArchive.fromJson(Map<String, dynamic> j) => RehabArchive(
        id: j['id']?.toString() ?? '',
        archiveNo: (j['archiveNo'] as String?) ?? '',
        childName: (j['childName'] as String?) ?? '',
        photoUrl: j['photoUrl'] as String?,
        status: ArchiveStatus.fromCode(j['status'] as int?),
        campusName: (j['campusName'] as String?) ?? '',
        remark: j['remark'] as String?,
        createTime: _dt(j['createTime']),
        templateType: (j['templateType'] as String?) ?? '',
      );

  /// 序列化（创建/更新档案用）。id 为空时不带上，由后端生成。
  Map<String, dynamic> toJson() => <String, dynamic>{
        if (id.isNotEmpty) 'id': id,
        'archiveNo': archiveNo,
        'childName': childName,
        'campusName': campusName,
        'status': status.code,
        'templateType': templateType,
        if (remark != null) 'remark': remark,
      };
}

// ════════════════════════════════════════════════════════════════
//  首次评估表（对应听障模板 1.1.1）
//  基础资料用独立标量字段；评估内容的六大领域/行为/自理/家长受训
//  用 Map<String,dynamic> JSON 存储（后端对应 TEXT 列）。
// ════════════════════════════════════════════════════════════════

/// 首次评估表。
class RehabFirstEval {
  RehabFirstEval({
    this.id,
    required this.archiveId,
    // ── 一、基本情况 ──
    this.name = '',
    this.gender = '',
    this.birthDate,
    this.ethnicity = '',
    this.hukouLocation = '',
    this.idNumber = '',
    this.enrollmentDate,
    this.className = '',
    // ── 二、听力状况 ──
    this.diagnosisConfirmDate,
    this.leftEarDb = '',
    this.rightEarDb = '',
    this.leftCompensationType = '',
    this.rightCompensationType = '',
    this.leftDeviceModel = '',
    this.rightDeviceModel = '',
    this.leftFittingDate,
    this.rightFittingDate,
    this.aidedThresholds,            // JSON: {left:{250,500,1k,2k,3k,4k}, right:{...}}
    this.hearingStimStrategy = '',
    // ── 三、沟通与康复史 ──
    this.commMode = '',
    this.problemFoundAge = '',
    this.rehabStartAge = '',
    this.pastRehabExp = '',
    // ── 四、家庭资料 ──
    this.familyData,                 // JSON: {father:{...}, mother:{...}}
    this.familyStatus = '',
    this.familyInputLangType = '',
    this.caregiverRelation = '',
    this.caregiverContact = '',
    this.homeAddress = '',
    this.familyAwareness = '',
    this.familyCooperation = '',
    // ── 五、评估内容（六大领域 + 行为 + 自理 + 家长受训）──
    this.domainHearingMgmt,          // JSON → 听能管理
    this.domainHearingAbility,       // JSON → 听觉能力
    this.domainLanguage,             // JSON → 语言能力
    this.domainSpeech,               // JSON → 言语能力
    this.domainCognition,            // JSON → 认知能力
    this.domainCommunication,        // JSON → 沟通能力
    this.behaviorNote,               // JSON → 行为表现
    this.selfCareNote,               // JSON → 自理能力
    this.parentTrainingNote,         // JSON → 家长受训经验及教育能力
    // ── 六、综合分析与康复建议 ──
    this.comprehensiveAdvice,        // JSON → {briefDesc, analysis, suggestion}
    // ── 七、评估信息 ──
    this.evaluatorName = '',
    this.evalDate,
    // ── 兼容旧字段 ──
    this.leftEarType = '',
    this.rightEarType = '',
    this.caregiver = '',
    this.familyLangEnv = '',
    this.diagnosisDate,
    this.firstDeviceDate,
    this.hearingTestData,
  });

  // ── 标量字段声明 ──
  final String? id;
  final String archiveId;
  final String name;
  final String gender;
  final DateTime? birthDate;
  final String ethnicity;
  final String hukouLocation;
  final String idNumber;
  final DateTime? enrollmentDate;
  final String className;
  final DateTime? diagnosisConfirmDate;
  final String leftEarDb;
  final String rightEarDb;
  final String leftCompensationType;
  final String rightCompensationType;
  final String leftDeviceModel;
  final String rightDeviceModel;
  final DateTime? leftFittingDate;
  final DateTime? rightFittingDate;
  final Map<String, dynamic>? aidedThresholds;
  final String hearingStimStrategy;
  final String commMode;
  final String problemFoundAge;
  final String rehabStartAge;
  final String pastRehabExp;
  final Map<String, dynamic>? familyData;
  final String familyStatus;
  final String familyInputLangType;
  final String caregiverRelation;
  final String caregiverContact;
  final String homeAddress;
  final String familyAwareness;
  final String familyCooperation;

  // ── JSON 领域字段声明 ──
  final Map<String, dynamic>? domainHearingMgmt;     // 听能管理
  final Map<String, dynamic>? domainHearingAbility;  // 听觉能力
  final Map<String, dynamic>? domainLanguage;        // 语言能力
  final Map<String, dynamic>? domainSpeech;          // 言语能力
  final Map<String, dynamic>? domainCognition;       // 认知能力
  final Map<String, dynamic>? domainCommunication;   // 沟通能力
  final Map<String, dynamic>? behaviorNote;          // 行为表现
  final Map<String, dynamic>? selfCareNote;          // 自理能力
  final Map<String, dynamic>? parentTrainingNote;    // 家长受训
  final Map<String, dynamic>? comprehensiveAdvice;   // 综合分析 {desc,analysis,suggestion}

  final String evaluatorName;
  final DateTime? evalDate;

  // 兼容旧字段
  final String leftEarType;
  final String rightEarType;
  final String caregiver;
  final String familyLangEnv;
  final DateTime? diagnosisDate;
  final DateTime? firstDeviceDate;
  final Map<String, dynamic>? hearingTestData;

  // ── JSON 快捷访问方法 ──

  /// 从 familyData 取父亲/母亲字段。
  String father(String key) => jsonStr(familyData, ['father', key]);
  String mother(String key) => jsonStr(familyData, ['mother', key]);

  /// 从 aidedThresholds 取助听听阈。
  String threshold(String ear, String freq) => jsonStr(aidedThresholds, [ear, freq]);

  /// 从领域 JSON 取值（点号路径）。
  String d(String domainKey, String path) {
    final Map<String, dynamic>? domainMap = _domainMap(domainKey);
    return jsonStr(domainMap, path.split('.'));
  }

  Map<String, dynamic>? _domainMap(String key) {
    switch (key) {
      case 'hearingMgmt': return domainHearingMgmt;
      case 'hearingAbility': return domainHearingAbility;
      case 'language': return domainLanguage;
      case 'speech': return domainSpeech;
      case 'cognition': return domainCognition;
      case 'communication': return domainCommunication;
      case 'behavior': return behaviorNote;
      case 'selfCare': return selfCareNote;
      case 'parentTraining': return parentTrainingNote;
      case 'advice': return comprehensiveAdvice;
      default: return null;
    }
  }

  /// 综合分析三段式快捷访问。
  String get briefDesc => jsonStr(comprehensiveAdvice, ['briefDesc']) ;
  String get analysis => jsonStr(comprehensiveAdvice, ['analysis']);
  String get suggestion => jsonStr(comprehensiveAdvice, ['suggestion']);

  // ── 序列化 ──

  factory RehabFirstEval.fromJson(Map<String, dynamic> j) => RehabFirstEval(
        id: j['id']?.toString(),
        archiveId: j['archiveId']?.toString() ?? '',
        name: (j['name'] as String?) ?? '',
        gender: (j['gender'] as String?) ?? '',
        birthDate: _dt(j['birthDate']),
        ethnicity: (j['ethnicity'] as String?) ?? '',
        hukouLocation: (j['hukouLocation'] as String?) ?? '',
        idNumber: (j['idNumber'] as String?) ?? '',
        enrollmentDate: _dt(j['enrollmentDate']),
        className: (j['className'] as String?) ?? '',
        diagnosisConfirmDate: _dt(j['diagnosisConfirmDate']),
        leftEarDb: (j['leftEarDb'] as String?) ?? '',
        rightEarDb: (j['rightEarDb'] as String?) ?? '',
        leftCompensationType: (j['leftCompensationType'] as String?) ?? '',
        rightCompensationType: (j['rightCompensationType'] as String?) ?? '',
        leftDeviceModel: (j['leftDeviceModel'] as String?) ?? '',
        rightDeviceModel: (j['rightDeviceModel'] as String?) ?? '',
        leftFittingDate: _dt(j['leftFittingDate']),
        rightFittingDate: _dt(j['rightFittingDate']),
        aidedThresholds: _parseJson(j['aidedThresholds']),
        hearingStimStrategy: (j['hearingStimStrategy'] as String?) ?? '',
        commMode: (j['commMode'] as String?) ?? '',
        problemFoundAge: (j['problemFoundAge'] as String?) ?? '',
        rehabStartAge: (j['rehabStartAge'] as String?) ?? '',
        pastRehabExp: (j['pastRehabExp'] as String?) ?? '',
        familyData: _parseJson(j['familyData']),
        familyStatus: (j['familyStatus'] as String?) ?? '',
        familyInputLangType: (j['familyInputLangType'] as String?) ?? '',
        caregiverRelation: (j['caregiverRelation'] as String?) ?? '',
        caregiverContact: (j['caregiverContact'] as String?) ?? '',
        homeAddress: (j['homeAddress'] as String?) ?? '',
        familyAwareness: (j['familyAwareness'] as String?) ?? '',
        familyCooperation: (j['familyCooperation'] as String?) ?? '',
        // 领域 JSON 字段
        domainHearingMgmt: _parseJson(j['domainHearingMgmt']),
        domainHearingAbility: _parseJson(j['domainHearingAbility']),
        domainLanguage: _parseJson(j['domainLanguage']),
        domainSpeech: _parseJson(j['domainSpeech']),
        domainCognition: _parseJson(j['domainCognition']),
        domainCommunication: _parseJson(j['domainCommunication']),
        behaviorNote: _parseJson(j['behaviorNote']),
        selfCareNote: _parseJson(j['selfCareNote']),
        parentTrainingNote: _parseJson(j['parentTrainingNote']),
        comprehensiveAdvice: _parseJson(j['comprehensiveAdvice']),
        evaluatorName: (j['evaluatorName'] as String?) ?? '',
        evalDate: _dt(j['evalDate']),
        // 兼容旧字段
        hearingTestData: _parseJson(j['hearingTestData']),
        leftEarType: (j['leftEarType'] as String?) ?? '',
        rightEarType: (j['rightEarType'] as String?) ?? '',
        caregiver: (j['caregiver'] as String?) ?? '',
        familyLangEnv: (j['familyLangEnv'] as String?) ?? '',
        diagnosisDate: _dt(j['diagnosisDate']),
        firstDeviceDate: _dt(j['firstDeviceDate']),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'archiveId': archiveId,
        'name': name, 'gender': gender,
        if (birthDate != null) 'birthDate': birthDate!.toIso8601String().split('T').first,
        'ethnicity': ethnicity, 'hukouLocation': hukouLocation,
        'idNumber': idNumber,
        if (enrollmentDate != null) 'enrollmentDate': enrollmentDate!.toIso8601String().split('T').first,
        'className': className,
        if (diagnosisConfirmDate != null) 'diagnosisConfirmDate': diagnosisConfirmDate!.toIso8601String().split('T').first,
        'leftEarDb': leftEarDb, 'rightEarDb': rightEarDb,
        'leftCompensationType': leftCompensationType, 'rightCompensationType': rightCompensationType,
        'leftDeviceModel': leftDeviceModel, 'rightDeviceModel': rightDeviceModel,
        if (leftFittingDate != null) 'leftFittingDate': leftFittingDate!.toIso8601String().split('T').first,
        if (rightFittingDate != null) 'rightFittingDate': rightFittingDate!.toIso8601String().split('T').first,
        if (aidedThresholds != null) 'aidedThresholds': jsonEncode(aidedThresholds),
        'hearingStimStrategy': hearingStimStrategy,
        'commMode': commMode, 'problemFoundAge': problemFoundAge,
        'rehabStartAge': rehabStartAge, 'pastRehabExp': pastRehabExp,
        if (familyData != null) 'familyData': jsonEncode(familyData),
        'familyStatus': familyStatus, 'familyInputLangType': familyInputLangType,
        'caregiverRelation': caregiverRelation, 'caregiverContact': caregiverContact,
        'homeAddress': homeAddress,
        'familyAwareness': familyAwareness, 'familyCooperation': familyCooperation,
        // 领域 JSON
        if (domainHearingMgmt != null) 'domainHearingMgmt': jsonEncode(domainHearingMgmt),
        if (domainHearingAbility != null) 'domainHearingAbility': jsonEncode(domainHearingAbility),
        if (domainLanguage != null) 'domainLanguage': jsonEncode(domainLanguage),
        if (domainSpeech != null) 'domainSpeech': jsonEncode(domainSpeech),
        if (domainCognition != null) 'domainCognition': jsonEncode(domainCognition),
        if (domainCommunication != null) 'domainCommunication': jsonEncode(domainCommunication),
        if (behaviorNote != null) 'behaviorNote': jsonEncode(behaviorNote),
        if (selfCareNote != null) 'selfCareNote': jsonEncode(selfCareNote),
        if (parentTrainingNote != null) 'parentTrainingNote': jsonEncode(parentTrainingNote),
        if (comprehensiveAdvice != null) 'comprehensiveAdvice': jsonEncode(comprehensiveAdvice),
        'evaluatorName': evaluatorName,
        if (evalDate != null) 'evalDate': evalDate!.toIso8601String().split('T').first,
        // 兼容旧字段
        if (hearingTestData != null) 'hearingTestData': jsonEncode(hearingTestData),
        'leftEarType': leftCompensationType.isEmpty ? leftEarType : leftCompensationType,
        'rightEarType': rightCompensationType.isEmpty ? rightEarType : rightCompensationType,
        'caregiver': caregiverRelation.isEmpty ? caregiver : caregiverRelation,
        'familyLangEnv': familyInputLangType.isEmpty ? familyLangEnv : familyInputLangType,
        if (diagnosisDate != null && diagnosisConfirmDate == null)
          'diagnosisDate': diagnosisDate!.toIso8601String().split('T').first,
        if (firstDeviceDate != null) 'firstDeviceDate': firstDeviceDate!.toIso8601String().split('T').first,
      };

  RehabFirstEval copyWith({
    String? id,
    String? name, String? gender, DateTime? birthDate,
    String? ethnicity, String? hukouLocation, String? idNumber,
    DateTime? enrollmentDate, String? className,
    DateTime? diagnosisConfirmDate,
    String? leftEarDb, String? rightEarDb,
    String? leftCompensationType, String? rightCompensationType,
    String? leftDeviceModel, String? rightDeviceModel,
    DateTime? leftFittingDate, DateTime? rightFittingDate,
    Map<String, dynamic>? aidedThresholds,
    String? hearingStimStrategy,
    String? commMode, String? problemFoundAge,
    String? rehabStartAge, String? pastRehabExp,
    Map<String, dynamic>? familyData,
    String? familyStatus, String? familyInputLangType,
    String? caregiverRelation, String? caregiverContact,
    String? homeAddress,
    String? familyAwareness, String? familyCooperation,
    Map<String, dynamic>? domainHearingMgmt,
    Map<String, dynamic>? domainHearingAbility,
    Map<String, dynamic>? domainLanguage,
    Map<String, dynamic>? domainSpeech,
    Map<String, dynamic>? domainCognition,
    Map<String, dynamic>? domainCommunication,
    Map<String, dynamic>? behaviorNote,
    Map<String, dynamic>? selfCareNote,
    Map<String, dynamic>? parentTrainingNote,
    Map<String, dynamic>? comprehensiveAdvice,
    String? evaluatorName, DateTime? evalDate,
    // 兼容
    String? leftEarType, String? rightEarType,
    String? caregiver, String? familyLangEnv,
    DateTime? diagnosisDate, DateTime? firstDeviceDate,
    Map<String, dynamic>? hearingTestData,
  }) =>
      RehabFirstEval(
        id: id ?? this.id,
        archiveId: archiveId,
        name: name ?? this.name,
        gender: gender ?? this.gender,
        birthDate: birthDate ?? this.birthDate,
        ethnicity: ethnicity ?? this.ethnicity,
        hukouLocation: hukouLocation ?? this.hukouLocation,
        idNumber: idNumber ?? this.idNumber,
        enrollmentDate: enrollmentDate ?? this.enrollmentDate,
        className: className ?? this.className,
        diagnosisConfirmDate: diagnosisConfirmDate ?? this.diagnosisConfirmDate,
        leftEarDb: leftEarDb ?? this.leftEarDb,
        rightEarDb: rightEarDb ?? this.rightEarDb,
        leftCompensationType: leftCompensationType ?? this.leftCompensationType,
        rightCompensationType: rightCompensationType ?? this.rightCompensationType,
        leftDeviceModel: leftDeviceModel ?? this.leftDeviceModel,
        rightDeviceModel: rightDeviceModel ?? this.rightDeviceModel,
        leftFittingDate: leftFittingDate ?? this.leftFittingDate,
        rightFittingDate: rightFittingDate ?? this.rightFittingDate,
        aidedThresholds: aidedThresholds ?? this.aidedThresholds,
        hearingStimStrategy: hearingStimStrategy ?? this.hearingStimStrategy,
        commMode: commMode ?? this.commMode,
        problemFoundAge: problemFoundAge ?? this.problemFoundAge,
        rehabStartAge: rehabStartAge ?? this.rehabStartAge,
        pastRehabExp: pastRehabExp ?? this.pastRehabExp,
        familyData: familyData ?? this.familyData,
        familyStatus: familyStatus ?? this.familyStatus,
        familyInputLangType: familyInputLangType ?? this.familyInputLangType,
        caregiverRelation: caregiverRelation ?? this.caregiverRelation,
        caregiverContact: caregiverContact ?? this.caregiverContact,
        homeAddress: homeAddress ?? this.homeAddress,
        familyAwareness: familyAwareness ?? this.familyAwareness,
        familyCooperation: familyCooperation ?? this.familyCooperation,
        domainHearingMgmt: domainHearingMgmt ?? this.domainHearingMgmt,
        domainHearingAbility: domainHearingAbility ?? this.domainHearingAbility,
        domainLanguage: domainLanguage ?? this.domainLanguage,
        domainSpeech: domainSpeech ?? this.domainSpeech,
        domainCognition: domainCognition ?? this.domainCognition,
        domainCommunication: domainCommunication ?? this.domainCommunication,
        behaviorNote: behaviorNote ?? this.behaviorNote,
        selfCareNote: selfCareNote ?? this.selfCareNote,
        parentTrainingNote: parentTrainingNote ?? this.parentTrainingNote,
        comprehensiveAdvice: comprehensiveAdvice ?? this.comprehensiveAdvice,
        evaluatorName: evaluatorName ?? this.evaluatorName,
        evalDate: evalDate ?? this.evalDate,
        leftEarType: leftEarType ?? this.leftEarType,
        rightEarType: rightEarType ?? this.rightEarType,
        caregiver: caregiver ?? this.caregiver,
        familyLangEnv: familyLangEnv ?? this.familyLangEnv,
        diagnosisDate: diagnosisDate ?? this.diagnosisDate,
        firstDeviceDate: firstDeviceDate ?? this.firstDeviceDate,
        hearingTestData: hearingTestData ?? this.hearingTestData,
      );
}

// ════════════════════════════════════════════════════════════════
//  持续评估表（对应听障模板 1.1.2）
//  所有评估细项均用 Map<String,dynamic> JSON 存储。
// ════════════════════════════════════════════════════════════════

/// 持续评估表。
class RehabContEval {
  RehabContEval({
    this.id,
    required this.archiveId,
    this.evalSeq,
    this.evalDate,
    this.dueDate,
    this.status = ContEvalStatus.pending,
    // ── 基础资料扩展 ──
    this.physiologicalAge = '',       // 生理年龄 "X岁X个月"
    this.hearingAge = '',             // 听觉年龄 "X岁X个月"
    this.evalTime1,                   // 第一次评估时间
    this.evalTime2,                   // 第二次评估时间
    this.evalTime3,                   // 第三次评估时间
    // ── 听能（JSON）──
    this.hearingData,                 // JSON: 声源辨识/林氏六音/词组字词
    this.auditoryMemoryData,          // JSON: 听觉记忆5级详细项
    this.auditoryDescData,            // JSON: 听觉描述(闭合/开放)
    this.recordingData,               // JSON: 录音带内容
    this.noisyEnvData,                // JSON: 吵杂环境倾听
    this.groupListenData,             // JSON: 团体对话倾听
    this.phoneSkillData,              // JSON: 接听电话技巧7级
    this.activeListenData,            // JSON: 主动聆听技巧8级
    this.hearingEvalScore,            // JSON: {avgRecogRate, evalDate}
    this.capLevelData,                // JSON: CAP级别+日期
    // ── 语言（JSON）──
    this.languageVocabData,           // JSON: 初/中/高级词汇
    this.languageQuestionData,        // JSON: 问句(年龄段)
    this.languageEvalScore,           // JSON: {avgLangAge, evalDate}
    this.sirLevelData,               // JSON: SIR级别+日期
    // ── 言语（JSON）──
    this.speechQualityData,           // JSON: 音质/辨识度
    this.speechSupraSegmentalData,    // JSON: 超语段
    this.speechToneData,              // JSON: 四声
    this.speechVowelData,             // JSON: 韵母系统
    this.speechConsonantData,         // JSON: 声母24个
    // ── 认知（JSON）──
    this.cognitionClassifyData,       // JSON: 分类及配对
    this.cognitionColorData,          // JSON: 颜色
    this.cognitionNumberData,         // JSON: 数字概念
    this.cognitionShapeData,          // JSON: 形状
    this.cognitionTouchData,          // JSON: 触觉感知
    this.cognitionCompareData,        // JSON: 比较与对照
    // ── 沟通（JSON）──
    this.commSequenceData,           // JSON: 顺序概念
    this.commBehaviorData,           // JSON: 沟通行为
    this.commStrategyData,           // JSON: 沟通策略(高级12项)
    // ── 家长表现（JSON）──
    this.parentPerformanceData,      // JSON: 4项评分+进步+其它
    // ── 简化字段（向后兼容旧 UI 引用）──
    this.soundSourceRecognition = '',
    this.lingSixSound = '',
    this.auditoryMemory = '',
    this.auditoryDescription = '',
    this.auditoryComprehension = '',
    this.languageDetail = '',
    this.speechDetail = '',
    this.cognitionDetail = '',
    this.communicationDetail = '',
    this.parentPerformance = '',
    this.teacherNotes = '',
    this.evaluatorName = '',
  });

  final String? id;
  final String archiveId;
  final int? evalSeq;
  final DateTime? evalDate;
  final DateTime? dueDate;
  final ContEvalStatus status;

  // 基础资料扩展
  final String physiologicalAge;
  final String hearingAge;
  final DateTime? evalTime1;
  final DateTime? evalTime2;
  final DateTime? evalTime3;

  // 听能 JSON
  final Map<String, dynamic>? hearingData;
  final Map<String, dynamic>? auditoryMemoryData;
  final Map<String, dynamic>? auditoryDescData;
  final Map<String, dynamic>? recordingData;
  final Map<String, dynamic>? noisyEnvData;
  final Map<String, dynamic>? groupListenData;
  final Map<String, dynamic>? phoneSkillData;
  final Map<String, dynamic>? activeListenData;
  final Map<String, dynamic>? hearingEvalScore;
  final Map<String, dynamic>? capLevelData;

  // 语言 JSON
  final Map<String, dynamic>? languageVocabData;
  final Map<String, dynamic>? languageQuestionData;
  final Map<String, dynamic>? languageEvalScore;
  final Map<String, dynamic>? sirLevelData;

  // 言语 JSON
  final Map<String, dynamic>? speechQualityData;
  final Map<String, dynamic>? speechSupraSegmentalData;
  final Map<String, dynamic>? speechToneData;
  final Map<String, dynamic>? speechVowelData;
  final Map<String, dynamic>? speechConsonantData;

  // 认知 JSON
  final Map<String, dynamic>? cognitionClassifyData;
  final Map<String, dynamic>? cognitionColorData;
  final Map<String, dynamic>? cognitionNumberData;
  final Map<String, dynamic>? cognitionShapeData;
  final Map<String, dynamic>? cognitionTouchData;
  final Map<String, dynamic>? cognitionCompareData;

  // 沟通 JSON
  final Map<String, dynamic>? commSequenceData;
  final Map<String, dynamic>? commBehaviorData;
  final Map<String, dynamic>? commStrategyData;

  // 家长表现 JSON
  final Map<String, dynamic>? parentPerformanceData;

  // 向后兼容的简化字段
  final String soundSourceRecognition;
  final String lingSixSound;
  final String auditoryMemory;
  final String auditoryDescription;
  final String auditoryComprehension;
  final String languageDetail;
  final String speechDetail;
  final String cognitionDetail;
  final String communicationDetail;
  final String parentPerformance;
  final String teacherNotes;
  final String evaluatorName;

  /// 从 JSON 领域取快捷值。
  String cd(String domainKey, String path) {
    final Map<String, dynamic>? m = _contDomainMap(domainKey);
    return jsonStr(m, path.split('.'));
  }

  Map<String, dynamic>? _contDomainMap(String key) {
    switch (key) {
      case 'hearing': return hearingData;
      case 'auditoryMemory': return auditoryMemoryData;
      case 'auditoryDesc': return auditoryDescData;
      case 'recording': return recordingData;
      case 'noisyEnv': return noisyEnvData;
      case 'groupListen': return groupListenData;
      case 'phoneSkill': return phoneSkillData;
      case 'activeListen': return activeListenData;
      case 'hearingEval': return hearingEvalScore;
      case 'capLevel': return capLevelData;
      case 'langVocab': return languageVocabData;
      case 'langQuestion': return languageQuestionData;
      case 'langEval': return languageEvalScore;
      case 'sirLevel': return sirLevelData;
      case 'speechQuality': return speechQualityData;
      case 'speechSupra': return speechSupraSegmentalData;
      case 'speechTone': return speechToneData;
      case 'speechVowel': return speechVowelData;
      case 'speechConsonant': return speechConsonantData;
      case 'cogClassify': return cognitionClassifyData;
      case 'cogColor': return cognitionColorData;
      case 'cogNumber': return cognitionNumberData;
      case 'cogShape': return cognitionShapeData;
      case 'cogTouch': return cognitionTouchData;
      case 'cogCompare': return cognitionCompareData;
      case 'commSequence': return commSequenceData;
      case 'commBehavior': return commBehaviorData;
      case 'commStrategy': return commStrategyData;
      case 'parentPerf': return parentPerformanceData;
      default: return null;
    }
  }

  factory RehabContEval.fromJson(Map<String, dynamic> j) => RehabContEval(
        id: j['id']?.toString(),
        archiveId: j['archiveId']?.toString() ?? '',
        evalSeq: j['evalSeq'] as int?,
        evalDate: _dt(j['evalDate']),
        dueDate: _dt(j['dueDate']),
        status: ContEvalStatus.fromCode(j['status'] as int?),
        physiologicalAge: (j['physiologicalAge'] as String?) ?? '',
        hearingAge: (j['hearingAge'] as String?) ?? '',
        evalTime1: _dt(j['evalTime1']),
        evalTime2: _dt(j['evalTime2']),
        evalTime3: _dt(j['evalTime3']),
        hearingData: _parseJson(j['hearingData']),
        auditoryMemoryData: _parseJson(j['auditoryMemoryData']),
        auditoryDescData: _parseJson(j['auditoryDescData']),
        recordingData: _parseJson(j['recordingData']),
        noisyEnvData: _parseJson(j['noisyEnvData']),
        groupListenData: _parseJson(j['groupListenData']),
        phoneSkillData: _parseJson(j['phoneSkillData']),
        activeListenData: _parseJson(j['activeListenData']),
        hearingEvalScore: _parseJson(j['hearingEvalScore']),
        capLevelData: _parseJson(j['capLevelData']),
        languageVocabData: _parseJson(j['languageVocabData']),
        languageQuestionData: _parseJson(j['languageQuestionData']),
        languageEvalScore: _parseJson(j['languageEvalScore']),
        sirLevelData: _parseJson(j['sirLevelData']),
        speechQualityData: _parseJson(j['speechQualityData']),
        speechSupraSegmentalData: _parseJson(j['speechSupraSegmentalData']),
        speechToneData: _parseJson(j['speechToneData']),
        speechVowelData: _parseJson(j['speechVowelData']),
        speechConsonantData: _parseJson(j['speechConsonantData']),
        cognitionClassifyData: _parseJson(j['cognitionClassifyData']),
        cognitionColorData: _parseJson(j['cognitionColorData']),
        cognitionNumberData: _parseJson(j['cognitionNumberData']),
        cognitionShapeData: _parseJson(j['cognitionShapeData']),
        cognitionTouchData: _parseJson(j['cognitionTouchData']),
        cognitionCompareData: _parseJson(j['cognitionCompareData']),
        commSequenceData: _parseJson(j['commSequenceData']),
        commBehaviorData: _parseJson(j['commBehaviorData']),
        commStrategyData: _parseJson(j['commStrategyData']),
        parentPerformanceData: _parseJson(j['parentPerformanceData']),
        // 兼容旧字段
        soundSourceRecognition: (j['soundSourceRecognition'] as String?) ?? '',
        lingSixSound: (j['lingSixSound'] as String?) ?? '',
        auditoryMemory: (j['auditoryMemory'] as String?) ?? '',
        auditoryDescription: (j['auditoryDescription'] as String?) ?? '',
        auditoryComprehension: (j['auditoryComprehension'] as String?) ?? '',
        languageDetail: (j['languageDetail'] as String?) ?? '',
        speechDetail: (j['speechDetail'] as String?) ?? '',
        cognitionDetail: (j['cognitionDetail'] as String?) ?? '',
        communicationDetail: (j['communicationDetail'] as String?) ?? '',
        parentPerformance: (j['parentPerformance'] as String?) ?? '',
        teacherNotes: (j['teacherNotes'] as String?) ?? '',
        evaluatorName: (j['evaluatorName'] as String?) ?? '',
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'archiveId': archiveId,
        if (evalDate != null) 'evalDate': evalDate!.toIso8601String().split('T').first,
        'physiologicalAge': physiologicalAge,
        'hearingAge': hearingAge,
        if (evalTime1 != null) 'evalTime1': evalTime1!.toIso8601String().split('T').first,
        if (evalTime2 != null) 'evalTime2': evalTime2!.toIso8601String().split('T').first,
        if (evalTime3 != null) 'evalTime3': evalTime3!.toIso8601String().split('T').first,
        if (hearingData != null) 'hearingData': jsonEncode(hearingData),
        if (auditoryMemoryData != null) 'auditoryMemoryData': jsonEncode(auditoryMemoryData),
        if (auditoryDescData != null) 'auditoryDescData': jsonEncode(auditoryDescData),
        if (recordingData != null) 'recordingData': jsonEncode(recordingData),
        if (noisyEnvData != null) 'noisyEnvData': jsonEncode(noisyEnvData),
        if (groupListenData != null) 'groupListenData': jsonEncode(groupListenData),
        if (phoneSkillData != null) 'phoneSkillData': jsonEncode(phoneSkillData),
        if (activeListenData != null) 'activeListenData': jsonEncode(activeListenData),
        if (hearingEvalScore != null) 'hearingEvalScore': jsonEncode(hearingEvalScore),
        if (capLevelData != null) 'capLevelData': jsonEncode(capLevelData),
        if (languageVocabData != null) 'languageVocabData': jsonEncode(languageVocabData),
        if (languageQuestionData != null) 'languageQuestionData': jsonEncode(languageQuestionData),
        if (languageEvalScore != null) 'languageEvalScore': jsonEncode(languageEvalScore),
        if (sirLevelData != null) 'sirLevelData': jsonEncode(sirLevelData),
        if (speechQualityData != null) 'speechQualityData': jsonEncode(speechQualityData),
        if (speechSupraSegmentalData != null) 'speechSupraSegmentalData': jsonEncode(speechSupraSegmentalData),
        if (speechToneData != null) 'speechToneData': jsonEncode(speechToneData),
        if (speechVowelData != null) 'speechVowelData': jsonEncode(speechVowelData),
        if (speechConsonantData != null) 'speechConsonantData': jsonEncode(speechConsonantData),
        if (cognitionClassifyData != null) 'cognitionClassifyData': jsonEncode(cognitionClassifyData),
        if (cognitionColorData != null) 'cognitionColorData': jsonEncode(cognitionColorData),
        if (cognitionNumberData != null) 'cognitionNumberData': jsonEncode(cognitionNumberData),
        if (cognitionShapeData != null) 'cognitionShapeData': jsonEncode(cognitionShapeData),
        if (cognitionTouchData != null) 'cognitionTouchData': jsonEncode(cognitionTouchData),
        if (cognitionCompareData != null) 'cognitionCompareData': jsonEncode(cognitionCompareData),
        if (commSequenceData != null) 'commSequenceData': jsonEncode(commSequenceData),
        if (commBehaviorData != null) 'commBehaviorData': jsonEncode(commBehaviorData),
        if (commStrategyData != null) 'commStrategyData': jsonEncode(commStrategyData),
        if (parentPerformanceData != null) 'parentPerformanceData': jsonEncode(parentPerformanceData),
        // 兼容旧字段名（后端可能仍期望这些键）
        'soundSourceRecognition': soundSourceRecognition,
        'lingSixSound': lingSixSound,
        'auditoryMemory': auditoryMemory,
        'auditoryDescription': auditoryDescription,
        'auditoryComprehension': auditoryComprehension,
        'languageDetail': languageDetail,
        'speechDetail': speechDetail,
        'cognitionDetail': cognitionDetail,
        'communicationDetail': communicationDetail,
        'parentPerformance': parentPerformance,
        'teacherNotes': teacherNotes,
        'evaluatorName': evaluatorName,
      };

  RehabContEval copyWith({
    String? id,
    int? evalSeq,
    DateTime? evalDate,
    DateTime? dueDate,
    ContEvalStatus? status,
    String? physiologicalAge,
    String? hearingAge,
    DateTime? evalTime1,
    DateTime? evalTime2,
    DateTime? evalTime3,
    Map<String, dynamic>? hearingData,
    Map<String, dynamic>? auditoryMemoryData,
    Map<String, dynamic>? auditoryDescData,
    Map<String, dynamic>? recordingData,
    Map<String, dynamic>? noisyEnvData,
    Map<String, dynamic>? groupListenData,
    Map<String, dynamic>? phoneSkillData,
    Map<String, dynamic>? activeListenData,
    Map<String, dynamic>? hearingEvalScore,
    Map<String, dynamic>? capLevelData,
    Map<String, dynamic>? languageVocabData,
    Map<String, dynamic>? languageQuestionData,
    Map<String, dynamic>? languageEvalScore,
    Map<String, dynamic>? sirLevelData,
    Map<String, dynamic>? speechQualityData,
    Map<String, dynamic>? speechSupraSegmentalData,
    Map<String, dynamic>? speechToneData,
    Map<String, dynamic>? speechVowelData,
    Map<String, dynamic>? speechConsonantData,
    Map<String, dynamic>? cognitionClassifyData,
    Map<String, dynamic>? cognitionColorData,
    Map<String, dynamic>? cognitionNumberData,
    Map<String, dynamic>? cognitionShapeData,
    Map<String, dynamic>? cognitionTouchData,
    Map<String, dynamic>? cognitionCompareData,
    Map<String, dynamic>? commSequenceData,
    Map<String, dynamic>? commBehaviorData,
    Map<String, dynamic>? commStrategyData,
    Map<String, dynamic>? parentPerformanceData,
    // 兼容
    String? soundSourceRecognition,
    String? lingSixSound,
    String? auditoryMemory,
    String? auditoryDescription,
    String? auditoryComprehension,
    String? languageDetail,
    String? speechDetail,
    String? cognitionDetail,
    String? communicationDetail,
    String? parentPerformance,
    String? teacherNotes,
    String? evaluatorName,
  }) =>
      RehabContEval(
        id: id ?? this.id,
        archiveId: archiveId,
        evalSeq: evalSeq ?? this.evalSeq,
        evalDate: evalDate ?? this.evalDate,
        dueDate: dueDate ?? this.dueDate,
        status: status ?? this.status,
        physiologicalAge: physiologicalAge ?? this.physiologicalAge,
        hearingAge: hearingAge ?? this.hearingAge,
        evalTime1: evalTime1 ?? this.evalTime1,
        evalTime2: evalTime2 ?? this.evalTime2,
        evalTime3: evalTime3 ?? this.evalTime3,
        hearingData: hearingData ?? this.hearingData,
        auditoryMemoryData: auditoryMemoryData ?? this.auditoryMemoryData,
        auditoryDescData: auditoryDescData ?? this.auditoryDescData,
        recordingData: recordingData ?? this.recordingData,
        noisyEnvData: noisyEnvData ?? this.noisyEnvData,
        groupListenData: groupListenData ?? this.groupListenData,
        phoneSkillData: phoneSkillData ?? this.phoneSkillData,
        activeListenData: activeListenData ?? this.activeListenData,
        hearingEvalScore: hearingEvalScore ?? this.hearingEvalScore,
        capLevelData: capLevelData ?? this.capLevelData,
        languageVocabData: languageVocabData ?? this.languageVocabData,
        languageQuestionData: languageQuestionData ?? this.languageQuestionData,
        languageEvalScore: languageEvalScore ?? this.languageEvalScore,
        sirLevelData: sirLevelData ?? this.sirLevelData,
        speechQualityData: speechQualityData ?? this.speechQualityData,
        speechSupraSegmentalData: speechSupraSegmentalData ?? this.speechSupraSegmentalData,
        speechToneData: speechToneData ?? this.speechToneData,
        speechVowelData: speechVowelData ?? this.speechVowelData,
        speechConsonantData: speechConsonantData ?? this.speechConsonantData,
        cognitionClassifyData: cognitionClassifyData ?? this.cognitionClassifyData,
        cognitionColorData: cognitionColorData ?? this.cognitionColorData,
        cognitionNumberData: cognitionNumberData ?? this.cognitionNumberData,
        cognitionShapeData: cognitionShapeData ?? this.cognitionShapeData,
        cognitionTouchData: cognitionTouchData ?? this.cognitionTouchData,
        cognitionCompareData: cognitionCompareData ?? this.cognitionCompareData,
        commSequenceData: commSequenceData ?? this.commSequenceData,
        commBehaviorData: commBehaviorData ?? this.commBehaviorData,
        commStrategyData: commStrategyData ?? this.commStrategyData,
        parentPerformanceData: parentPerformanceData ?? this.parentPerformanceData,
        soundSourceRecognition: soundSourceRecognition ?? this.soundSourceRecognition,
        lingSixSound: lingSixSound ?? this.lingSixSound,
        auditoryMemory: auditoryMemory ?? this.auditoryMemory,
        auditoryDescription: auditoryDescription ?? this.auditoryDescription,
        auditoryComprehension: auditoryComprehension ?? this.auditoryComprehension,
        languageDetail: languageDetail ?? this.languageDetail,
        speechDetail: speechDetail ?? this.speechDetail,
        cognitionDetail: cognitionDetail ?? this.cognitionDetail,
        communicationDetail: communicationDetail ?? this.communicationDetail,
        parentPerformance: parentPerformance ?? this.parentPerformance,
        teacherNotes: teacherNotes ?? this.teacherNotes,
        evaluatorName: evaluatorName ?? this.evaluatorName,
      );
}

/// 教学计划。
class RehabTeachingPlan {
  RehabTeachingPlan({
    this.id,
    required this.archiveId,
    this.planPeriodStart,
    this.planPeriodEnd,
    this.aiGenerated = false,
    this.hearingGoal = '',
    this.speechGoal = '',
    this.languageGoal = '',
    this.cognitionGoal = '',
    this.communicationGoal = '',
    this.familyGuidance = '',
    this.otherGoal = '',
    this.teacherName = '',
    this.status = 0,
  });

  final String? id;
  final String archiveId;
  final DateTime? planPeriodStart;
  final DateTime? planPeriodEnd;
  final bool aiGenerated;
  final String hearingGoal;
  final String speechGoal;
  final String languageGoal;
  final String cognitionGoal;
  final String communicationGoal;
  final String familyGuidance;
  final String otherGoal;
  final String teacherName;
  final int status;

  factory RehabTeachingPlan.fromJson(Map<String, dynamic> j) => RehabTeachingPlan(
        id: j['id']?.toString(),
        archiveId: j['archiveId']?.toString() ?? '',
        planPeriodStart: _dt(j['planPeriodStart']),
        planPeriodEnd: _dt(j['planPeriodEnd']),
        aiGenerated: j['aiGenerated'] as bool? ?? false,
        hearingGoal: (j['hearingGoal'] as String?) ?? '',
        speechGoal: (j['speechGoal'] as String?) ?? '',
        languageGoal: (j['languageGoal'] as String?) ?? '',
        cognitionGoal: (j['cognitionGoal'] as String?) ?? '',
        communicationGoal: (j['communicationGoal'] as String?) ?? '',
        familyGuidance: (j['familyGuidance'] as String?) ?? '',
        otherGoal: (j['otherGoal'] as String?) ?? '',
        teacherName: (j['teacherName'] as String?) ?? '',
        status: j['status'] as int? ?? 0,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'archiveId': archiveId,
        if (planPeriodStart != null)
          'planPeriodStart': planPeriodStart!.toIso8601String().split('T').first,
        if (planPeriodEnd != null)
          'planPeriodEnd': planPeriodEnd!.toIso8601String().split('T').first,
        'hearingGoal': hearingGoal,
        'speechGoal': speechGoal,
        'languageGoal': languageGoal,
        'cognitionGoal': cognitionGoal,
        'communicationGoal': communicationGoal,
        'familyGuidance': familyGuidance,
        'otherGoal': otherGoal,
      };

  RehabTeachingPlan copyWith({
    DateTime? planPeriodStart,
    DateTime? planPeriodEnd,
    bool? aiGenerated,
    String? hearingGoal,
    String? speechGoal,
    String? languageGoal,
    String? cognitionGoal,
    String? communicationGoal,
    String? familyGuidance,
    String? otherGoal,
    String? teacherName,
  }) =>
      RehabTeachingPlan(
        id: id,
        archiveId: archiveId,
        planPeriodStart: planPeriodStart ?? this.planPeriodStart,
        planPeriodEnd: planPeriodEnd ?? this.planPeriodEnd,
        aiGenerated: aiGenerated ?? this.aiGenerated,
        hearingGoal: hearingGoal ?? this.hearingGoal,
        speechGoal: speechGoal ?? this.speechGoal,
        languageGoal: languageGoal ?? this.languageGoal,
        cognitionGoal: cognitionGoal ?? this.cognitionGoal,
        communicationGoal: communicationGoal ?? this.communicationGoal,
        familyGuidance: familyGuidance ?? this.familyGuidance,
        otherGoal: otherGoal ?? this.otherGoal,
        teacherName: teacherName ?? this.teacherName,
        status: status,
      );
}

/// 手写照片附件。
class RehabPhoto {
  const RehabPhoto({
    required this.id,
    required this.archiveId,
    this.relatedFormType,
    this.filePath = '',
    this.remark,
    this.uploadTime,
  });

  final String id;
  final String archiveId;
  final String? relatedFormType;
  final String filePath;
  final String? remark;
  final DateTime? uploadTime;

  factory RehabPhoto.fromJson(Map<String, dynamic> j) => RehabPhoto(
        id: j['id']?.toString() ?? '',
        archiveId: j['archiveId']?.toString() ?? '',
        relatedFormType: j['relatedFormType'] as String?,
        filePath: (j['filePath'] as String?) ?? '',
        remark: j['remark'] as String?,
        uploadTime: _dt(j['uploadTime']),
      );
}

/// 任务提醒（持续评估 / 教学计划到期）。
class RehabTask {
  const RehabTask({
    required this.id,
    required this.archiveId,
    required this.reminderType,
    required this.title,
    required this.dueDate,
    this.completed = false,
    this.completedAt,
    this.archiveChildName,
  });

  final String id;
  final String archiveId;
  final String reminderType;
  final String title;
  final DateTime dueDate;
  final bool completed;
  final DateTime? completedAt;
  final String? archiveChildName;

  factory RehabTask.fromJson(Map<String, dynamic> j) => RehabTask(
        id: j['id']?.toString() ?? '',
        archiveId: j['archiveId']?.toString() ?? '',
        reminderType: (j['reminderType'] as String?) ?? '',
        title: (j['title'] as String?) ?? '',
        dueDate: _dt(j['dueDate']) ?? DateTime.now(),
        completed: j['completed'] as bool? ?? false,
        completedAt: _dt(j['completedAt']),
      );

  String get typeLabel =>
      reminderType == 'TEACHING_PLAN' ? '教学计划提醒' : '持续评估提醒';
}

/// 听力图单点：频率(Hz) + 分贝值(dB)。
class AudiogramPoint {
  const AudiogramPoint({required this.freq, required this.db});
  final int freq;
  final int db;

  factory AudiogramPoint.fromJson(Map<String, dynamic> j) => AudiogramPoint(
        freq: (j['freq'] as num?)?.toInt() ?? 0,
        db: (j['db'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{'freq': freq, 'db': db};

  AudiogramPoint copyWith({int? freq, int? db}) =>
      AudiogramPoint(freq: freq ?? this.freq, db: db ?? this.db);
}

/// 听能管理记录（含听力图 / 诊断记录）。
class RehabHearingRecord {
  const RehabHearingRecord({
    required this.id,
    required this.archiveId,
    this.recordNo,
    this.name,
    this.gender,
    this.birthDate,
    this.diagnosisDate,
    this.leftFirstDeviceDate,
    this.rightFirstDeviceDate,
    this.leftCompensationType = const <String>[],
    this.rightCompensationType = const <String>[],
    this.leftDeviceModel,
    this.rightDeviceModel,
    this.leftProgram,
    this.rightProgram,
    this.leftVolume,
    this.rightVolume,
    this.hearingTestMethod = const <String>[],
    this.hearingSymbols,
    this.unit = 'dB HL',
    this.leftAudiogram = const <AudiogramPoint>[],
    this.rightAudiogram = const <AudiogramPoint>[],
    this.leftAverageHearing,
    this.rightAverageHearing,
    this.leftAidEffect,
    this.rightAidEffect,
    this.evalDate,
    this.evaluatorName,
    this.inspectionItems,
    this.diagnosis,
    this.audiologistComment,
    this.fillDate,
    this.audiologistSignature,
    this.teacherId,
    this.teacherName,
    this.status = 0,
  });

  final String id;
  final String archiveId;
  final String? recordNo;
  final String? name;
  final String? gender;
  final DateTime? birthDate;
  final DateTime? diagnosisDate;
  final DateTime? leftFirstDeviceDate;
  final DateTime? rightFirstDeviceDate;
  final List<String> leftCompensationType;
  final List<String> rightCompensationType;
  final String? leftDeviceModel;
  final String? rightDeviceModel;
  final String? leftProgram;
  final String? rightProgram;
  final String? leftVolume;
  final String? rightVolume;
  final List<String> hearingTestMethod;
  final String? hearingSymbols;
  final String unit;
  final List<AudiogramPoint> leftAudiogram;
  final List<AudiogramPoint> rightAudiogram;
  final String? leftAverageHearing;
  final String? rightAverageHearing;
  final String? leftAidEffect;
  final String? rightAidEffect;
  final DateTime? evalDate;
  final String? evaluatorName;
  final String? inspectionItems;
  final String? diagnosis;
  final String? audiologistComment;
  final DateTime? fillDate;
  final String? audiologistSignature;
  final String? teacherId;
  final String? teacherName;
  final int status;

  factory RehabHearingRecord.fromJson(Map<String, dynamic> j) {
    List<AudiogramPoint> parsePoints(dynamic raw) {
      if (raw is! List) return const <AudiogramPoint>[];
      return raw
          .whereType<Map<String, dynamic>>()
          .map((e) => AudiogramPoint.fromJson(e))
          .toList();
    }

    List<String> parseStrList(dynamic raw) {
      if (raw is List) return raw.whereType<String>().toList();
      if (raw is String && raw.isNotEmpty) {
        try {
          final decoded = jsonDecode(raw) as List;
          return decoded.whereType<String>().toList();
        } catch (_) {
          return <String>[];
        }
      }
      return const <String>[];
    }

    return RehabHearingRecord(
      id: j['id']?.toString() ?? '',
      archiveId: j['archiveId']?.toString() ?? '',
      recordNo: j['recordNo'] as String?,
      name: j['name'] as String?,
      gender: j['gender'] as String?,
      birthDate: _dt(j['birthDate']),
      diagnosisDate: _dt(j['diagnosisDate']),
      leftFirstDeviceDate: _dt(j['leftFirstDeviceDate']),
      rightFirstDeviceDate: _dt(j['rightFirstDeviceDate']),
      leftCompensationType: parseStrList(j['leftCompensationType']),
      rightCompensationType: parseStrList(j['rightCompensationType']),
      leftDeviceModel: j['leftDeviceModel'] as String?,
      rightDeviceModel: j['rightDeviceModel'] as String?,
      leftProgram: j['leftProgram'] as String?,
      rightProgram: j['rightProgram'] as String?,
      leftVolume: j['leftVolume'] as String?,
      rightVolume: j['rightVolume'] as String?,
      hearingTestMethod: parseStrList(j['hearingTestMethod']),
      hearingSymbols: j['hearingSymbols'] as String?,
      unit: (j['unit'] as String?) ?? 'dB HL',
      leftAudiogram: parsePoints(j['leftAudiogram']),
      rightAudiogram: parsePoints(j['rightAudiogram']),
      leftAverageHearing: j['leftAverageHearing'] as String?,
      rightAverageHearing: j['rightAverageHearing'] as String?,
      leftAidEffect: j['leftAidEffect'] as String?,
      rightAidEffect: j['rightAidEffect'] as String?,
      evalDate: _dt(j['evalDate']),
      evaluatorName: j['evaluatorName'] as String?,
      inspectionItems: j['inspectionItems'] as String?,
      diagnosis: j['diagnosis'] as String?,
      audiologistComment: j['audiologistComment'] as String?,
      fillDate: _dt(j['fillDate']),
      audiologistSignature: j['audiologistSignature'] as String?,
      teacherId: j['teacherId']?.toString(),
      teacherName: j['teacherName'] as String?,
      status: j['status'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    String fmt(DateTime? d) =>
        d == null ? '' : d.toIso8601String().split('T').first;

    return <String, dynamic>{
      'archiveId': archiveId,
      if (recordNo != null && recordNo!.isNotEmpty) 'recordNo': recordNo,
      if (name != null && name!.isNotEmpty) 'name': name,
      if (gender != null && gender!.isNotEmpty) 'gender': gender,
      if (birthDate != null) 'birthDate': fmt(birthDate),
      if (diagnosisDate != null) 'diagnosisDate': fmt(diagnosisDate),
      if (leftFirstDeviceDate != null)
        'leftFirstDeviceDate': fmt(leftFirstDeviceDate),
      if (rightFirstDeviceDate != null)
        'rightFirstDeviceDate': fmt(rightFirstDeviceDate),
      if (leftCompensationType.isNotEmpty)
        'leftCompensationType': leftCompensationType,
      if (rightCompensationType.isNotEmpty)
        'rightCompensationType': rightCompensationType,
      if (leftDeviceModel != null && leftDeviceModel!.isNotEmpty)
        'leftDeviceModel': leftDeviceModel,
      if (rightDeviceModel != null && rightDeviceModel!.isNotEmpty)
        'rightDeviceModel': rightDeviceModel,
      if (leftProgram != null && leftProgram!.isNotEmpty)
        'leftProgram': leftProgram,
      if (rightProgram != null && rightProgram!.isNotEmpty)
        'rightProgram': rightProgram,
      if (leftVolume != null && leftVolume!.isNotEmpty) 'leftVolume': leftVolume,
      if (rightVolume != null && rightVolume!.isNotEmpty)
        'rightVolume': rightVolume,
      if (hearingTestMethod.isNotEmpty) 'hearingTestMethod': hearingTestMethod,
      if (hearingSymbols != null && hearingSymbols!.isNotEmpty)
        'hearingSymbols': hearingSymbols,
      'unit': unit,
      'leftAudiogram': leftAudiogram.map((p) => p.toJson()).toList(),
      'rightAudiogram': rightAudiogram.map((p) => p.toJson()).toList(),
      if (leftAverageHearing != null && leftAverageHearing!.isNotEmpty)
        'leftAverageHearing': leftAverageHearing,
      if (rightAverageHearing != null && rightAverageHearing!.isNotEmpty)
        'rightAverageHearing': rightAverageHearing,
      if (leftAidEffect != null && leftAidEffect!.isNotEmpty)
        'leftAidEffect': leftAidEffect,
      if (rightAidEffect != null && rightAidEffect!.isNotEmpty)
        'rightAidEffect': rightAidEffect,
      if (evalDate != null) 'evalDate': fmt(evalDate),
      if (evaluatorName != null && evaluatorName!.isNotEmpty)
        'evaluatorName': evaluatorName,
      if (inspectionItems != null && inspectionItems!.isNotEmpty)
        'inspectionItems': inspectionItems,
      if (diagnosis != null && diagnosis!.isNotEmpty) 'diagnosis': diagnosis,
      if (audiologistComment != null && audiologistComment!.isNotEmpty)
        'audiologistComment': audiologistComment,
      if (fillDate != null) 'fillDate': fmt(fillDate),
      if (audiologistSignature != null && audiologistSignature!.isNotEmpty)
        'audiologistSignature': audiologistSignature,
      'status': status,
    };
  }

  RehabHearingRecord copyWith({
    String? id,
    String? archiveId,
    String? recordNo,
    String? name,
    String? gender,
    DateTime? birthDate,
    DateTime? diagnosisDate,
    DateTime? leftFirstDeviceDate,
    DateTime? rightFirstDeviceDate,
    List<String>? leftCompensationType,
    List<String>? rightCompensationType,
    String? leftDeviceModel,
    String? rightDeviceModel,
    String? leftProgram,
    String? rightProgram,
    String? leftVolume,
    String? rightVolume,
    List<String>? hearingTestMethod,
    String? hearingSymbols,
    String? unit,
    List<AudiogramPoint>? leftAudiogram,
    List<AudiogramPoint>? rightAudiogram,
    String? leftAverageHearing,
    String? rightAverageHearing,
    String? leftAidEffect,
    String? rightAidEffect,
    DateTime? evalDate,
    String? evaluatorName,
    String? inspectionItems,
    String? diagnosis,
    String? audiologistComment,
    DateTime? fillDate,
    String? audiologistSignature,
    String? teacherId,
    String? teacherName,
    int? status,
  }) =>
      RehabHearingRecord(
        id: id ?? this.id,
        archiveId: archiveId ?? this.archiveId,
        recordNo: recordNo ?? this.recordNo,
        name: name ?? this.name,
        gender: gender ?? this.gender,
        birthDate: birthDate ?? this.birthDate,
        diagnosisDate: diagnosisDate ?? this.diagnosisDate,
        leftFirstDeviceDate: leftFirstDeviceDate ?? this.leftFirstDeviceDate,
        rightFirstDeviceDate: rightFirstDeviceDate ?? this.rightFirstDeviceDate,
        leftCompensationType:
            leftCompensationType ?? this.leftCompensationType,
        rightCompensationType:
            rightCompensationType ?? this.rightCompensationType,
        leftDeviceModel: leftDeviceModel ?? this.leftDeviceModel,
        rightDeviceModel: rightDeviceModel ?? this.rightDeviceModel,
        leftProgram: leftProgram ?? this.leftProgram,
        rightProgram: rightProgram ?? this.rightProgram,
        leftVolume: leftVolume ?? this.leftVolume,
        rightVolume: rightVolume ?? this.rightVolume,
        hearingTestMethod: hearingTestMethod ?? this.hearingTestMethod,
        hearingSymbols: hearingSymbols ?? this.hearingSymbols,
        unit: unit ?? this.unit,
        leftAudiogram: leftAudiogram ?? this.leftAudiogram,
        rightAudiogram: rightAudiogram ?? this.rightAudiogram,
        leftAverageHearing: leftAverageHearing ?? this.leftAverageHearing,
        rightAverageHearing: rightAverageHearing ?? this.rightAverageHearing,
        leftAidEffect: leftAidEffect ?? this.leftAidEffect,
        rightAidEffect: rightAidEffect ?? this.rightAidEffect,
        evalDate: evalDate ?? this.evalDate,
        evaluatorName: evaluatorName ?? this.evaluatorName,
        inspectionItems: inspectionItems ?? this.inspectionItems,
        diagnosis: diagnosis ?? this.diagnosis,
        audiologistComment: audiologistComment ?? this.audiologistComment,
        fillDate: fillDate ?? this.fillDate,
        audiologistSignature:
            audiologistSignature ?? this.audiologistSignature,
        teacherId: teacherId ?? this.teacherId,
        teacherName: teacherName ?? this.teacherName,
        status: status ?? this.status,
      );
}

/// 档案详情聚合（首次评估/持续评估/计划/照片/任务/听能记录）。
class RehabArchiveDetail {
  const RehabArchiveDetail({
    required this.archive,
    this.firstEval,
    this.contEvals = const <RehabContEval>[],
    this.plans = const <RehabTeachingPlan>[],
    this.hearingRecords = const <RehabHearingRecord>[],
    this.photos = const <RehabPhoto>[],
    this.tasks = const <RehabTask>[],
  });

  final RehabArchive archive;
  final RehabFirstEval? firstEval;
  final List<RehabContEval> contEvals;
  final List<RehabTeachingPlan> plans;
  final List<RehabHearingRecord> hearingRecords;
  final List<RehabPhoto> photos;
  final List<RehabTask> tasks;

  factory RehabArchiveDetail.fromJson(Map<String, dynamic> j) {
    final dynamic fe = j['firstEval'];
    final List<dynamic> ce = (j['contEvals'] as List?) ?? <dynamic>[];
    final List<dynamic> pl = (j['plans'] as List?) ?? <dynamic>[];
    final List<dynamic> hr = (j['hearingRecords'] as List?) ?? <dynamic>[];
    final List<dynamic> ph = (j['photos'] as List?) ?? <dynamic>[];
    final List<dynamic> tk = (j['tasks'] as List?) ?? <dynamic>[];
    return RehabArchiveDetail(
      archive: RehabArchive.fromJson(j['archive'] as Map<String, dynamic>),
      firstEval: fe is Map<String, dynamic>
          ? RehabFirstEval.fromJson(fe)
          : null,
      contEvals: ce
          .whereType<Map<String, dynamic>>()
          .map((e) => RehabContEval.fromJson(e))
          .toList(),
      plans: pl
          .whereType<Map<String, dynamic>>()
          .map((e) => RehabTeachingPlan.fromJson(e))
          .toList(),
      hearingRecords: hr
          .whereType<Map<String, dynamic>>()
          .map((e) => RehabHearingRecord.fromJson(e))
          .toList(),
      photos: ph
          .whereType<Map<String, dynamic>>()
          .map((e) => RehabPhoto.fromJson(e))
          .toList(),
      tasks: tk
          .whereType<Map<String, dynamic>>()
          .map((e) => RehabTask.fromJson(e))
          .toList(),
    );
  }
}
