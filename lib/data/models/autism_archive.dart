import 'package:teacher_app/data/models/rehab.dart';

DateTime? _aDt(dynamic v) =>
    v == null ? null : DateTime.tryParse(v.toString());

String _aStr(dynamic v) => v == null ? '' : v.toString();

/// ════════════════════════════════════════════════════════════════
///  孤独症儿童入学登记 + 八大领域首次评估 + IEP
/// ════════════════════════════════════════════════════════════════
class AutismFirstEval {
  AutismFirstEval({
    this.id,
    required this.archiveId,
    this.name = '',
    this.gender = '',
    this.birthDate,
    this.clinicalDiagnosis = '',
    this.diagnosisDate,
    this.diagnosisHospital = '',
    this.enrollmentDate,
    this.className = '',
    this.idNumber = '',
    this.ethnicity = '',
    this.hukouLocation = '',
    this.homeAddress = '',
    this.familyPhone = '',
    this.guardianName = '',
    this.guardianRelation = '',
    this.disabilityCertNo = '',
    this.familyData = '',
    this.selfStatus = '',
    this.domainPerception = '',
    this.domainGrossMotor = '',
    this.domainFineMotor = '',
    this.domainLanguageComm = '',
    this.domainCognition = '',
    this.domainSocial = '',
    this.domainSelfCare = '',
    this.domainEmotionBehavior = '',
    this.evalCountJson = '',
    this.iepPlanner = '',
    this.iepStartDate,
    this.iepEndDate,
    this.iepDomainSensory = '',
    this.iepDomainGross = '',
    this.iepDomainFine = '',
    this.iepDomainLanguage = '',
    this.iepDomainCognition = '',
    this.iepDomainSocial = '',
    this.iepDomainSelfcare = '',
    this.iepDomainEmotion = '',
    this.evalDate,
    this.evaluatorName = '',
    this.physiologicalAge = '',
    this.developmentalAge = '',
  });

  final String? id;
  final String archiveId;
  final String name;
  final String gender;
  final DateTime? birthDate;
  final String clinicalDiagnosis;
  final DateTime? diagnosisDate;
  final String diagnosisHospital;
  final DateTime? enrollmentDate;
  final String className;
  final String idNumber;
  final String ethnicity;
  final String hukouLocation;
  final String homeAddress;
  final String familyPhone;
  final String guardianName;
  final String guardianRelation;
  final String disabilityCertNo;
  final String familyData;
  final String selfStatus;
  final String domainPerception;
  final String domainGrossMotor;
  final String domainFineMotor;
  final String domainLanguageComm;
  final String domainCognition;
  final String domainSocial;
  final String domainSelfCare;
  final String domainEmotionBehavior;
  final String evalCountJson;
  final String iepPlanner;
  final DateTime? iepStartDate;
  final DateTime? iepEndDate;
  final String iepDomainSensory;
  final String iepDomainGross;
  final String iepDomainFine;
  final String iepDomainLanguage;
  final String iepDomainCognition;
  final String iepDomainSocial;
  final String iepDomainSelfcare;
  final String iepDomainEmotion;
  final DateTime? evalDate;
  final String evaluatorName;
  final String physiologicalAge;
  final String developmentalAge;

  factory AutismFirstEval.fromJson(Map<String, dynamic> j) => AutismFirstEval(
        id: j['id']?.toString(),
        archiveId: j['archiveId']?.toString() ?? '',
        name: _aStr(j['name']),
        gender: _aStr(j['gender']),
        birthDate: _aDt(j['birthDate']),
        clinicalDiagnosis: _aStr(j['clinicalDiagnosis']),
        diagnosisDate: _aDt(j['diagnosisDate']),
        diagnosisHospital: _aStr(j['diagnosisHospital']),
        enrollmentDate: _aDt(j['enrollmentDate']),
        className: _aStr(j['className']),
        idNumber: _aStr(j['idNumber']),
        ethnicity: _aStr(j['ethnicity']),
        hukouLocation: _aStr(j['hukouLocation']),
        homeAddress: _aStr(j['homeAddress']),
        familyPhone: _aStr(j['familyPhone']),
        guardianName: _aStr(j['guardianName']),
        guardianRelation: _aStr(j['guardianRelation']),
        disabilityCertNo: _aStr(j['disabilityCertNo']),
        familyData: _aStr(j['familyData']),
        selfStatus: _aStr(j['selfStatus']),
        domainPerception: _aStr(j['domainPerception']),
        domainGrossMotor: _aStr(j['domainGrossMotor']),
        domainFineMotor: _aStr(j['domainFineMotor']),
        domainLanguageComm: _aStr(j['domainLanguageComm']),
        domainCognition: _aStr(j['domainCognition']),
        domainSocial: _aStr(j['domainSocial']),
        domainSelfCare: _aStr(j['domainSelfCare']),
        domainEmotionBehavior: _aStr(j['domainEmotionBehavior']),
        evalCountJson: _aStr(j['evalCountJson']),
        iepPlanner: _aStr(j['iepPlanner']),
        iepStartDate: _aDt(j['iepStartDate']),
        iepEndDate: _aDt(j['iepEndDate']),
        iepDomainSensory: _aStr(j['iepDomainSensory']),
        iepDomainGross: _aStr(j['iepDomainGross']),
        iepDomainFine: _aStr(j['iepDomainFine']),
        iepDomainLanguage: _aStr(j['iepDomainLanguage']),
        iepDomainCognition: _aStr(j['iepDomainCognition']),
        iepDomainSocial: _aStr(j['iepDomainSocial']),
        iepDomainSelfcare: _aStr(j['iepDomainSelfcare']),
        iepDomainEmotion: _aStr(j['iepDomainEmotion']),
        evalDate: _aDt(j['evalDate']),
        evaluatorName: _aStr(j['evaluatorName']),
        physiologicalAge: _aStr(j['physiologicalAge']),
        developmentalAge: _aStr(j['developmentalAge']),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'archiveId': archiveId,
        'name': name,
        'gender': gender,
        if (birthDate != null)
          'birthDate': birthDate!.toIso8601String().split('T').first,
        'clinicalDiagnosis': clinicalDiagnosis,
        if (diagnosisDate != null)
          'diagnosisDate': diagnosisDate!.toIso8601String().split('T').first,
        'diagnosisHospital': diagnosisHospital,
        if (enrollmentDate != null)
          'enrollmentDate': enrollmentDate!.toIso8601String().split('T').first,
        'className': className,
        'idNumber': idNumber,
        'ethnicity': ethnicity,
        'hukouLocation': hukouLocation,
        'homeAddress': homeAddress,
        'familyPhone': familyPhone,
        'guardianName': guardianName,
        'guardianRelation': guardianRelation,
        'disabilityCertNo': disabilityCertNo,
        'familyData': familyData,
        'selfStatus': selfStatus,
        'domainPerception': domainPerception,
        'domainGrossMotor': domainGrossMotor,
        'domainFineMotor': domainFineMotor,
        'domainLanguageComm': domainLanguageComm,
        'domainCognition': domainCognition,
        'domainSocial': domainSocial,
        'domainSelfCare': domainSelfCare,
        'domainEmotionBehavior': domainEmotionBehavior,
        'evalCountJson': evalCountJson,
        'iepPlanner': iepPlanner,
        if (iepStartDate != null)
          'iepStartDate': iepStartDate!.toIso8601String().split('T').first,
        if (iepEndDate != null)
          'iepEndDate': iepEndDate!.toIso8601String().split('T').first,
        'iepDomainSensory': iepDomainSensory,
        'iepDomainGross': iepDomainGross,
        'iepDomainFine': iepDomainFine,
        'iepDomainLanguage': iepDomainLanguage,
        'iepDomainCognition': iepDomainCognition,
        'iepDomainSocial': iepDomainSocial,
        'iepDomainSelfcare': iepDomainSelfcare,
        'iepDomainEmotion': iepDomainEmotion,
        if (evalDate != null)
          'evalDate': evalDate!.toIso8601String().split('T').first,
        'evaluatorName': evaluatorName,
        'physiologicalAge': physiologicalAge,
        'developmentalAge': developmentalAge,
      };
}

/// ════════════════════════════════════════════════════════════════
///  孤独症儿童持续评估（与首次评估同结构，便于对比）
/// ════════════════════════════════════════════════════════════════
class AutismContEval {
  AutismContEval({
    this.id,
    required this.archiveId,
    this.evalSeq,
    this.evalDate,
    this.dueDate,
    this.status = 0,
    this.physiologicalAge = '',
    this.developmentalAge = '',
    this.domainPerception = '',
    this.domainGrossMotor = '',
    this.domainFineMotor = '',
    this.domainLanguageComm = '',
    this.domainCognition = '',
    this.domainSocial = '',
    this.domainSelfCare = '',
    this.domainEmotionBehavior = '',
    this.effectSummary = '',
    this.parentPerformance = '',
    this.teacherNotes = '',
    this.evaluatorName = '',
  });

  final String? id;
  final String archiveId;
  final int? evalSeq;
  final DateTime? evalDate;
  final DateTime? dueDate;
  final int status;
  final String physiologicalAge;
  final String developmentalAge;
  final String domainPerception;
  final String domainGrossMotor;
  final String domainFineMotor;
  final String domainLanguageComm;
  final String domainCognition;
  final String domainSocial;
  final String domainSelfCare;
  final String domainEmotionBehavior;
  final String effectSummary;
  final String parentPerformance;
  final String teacherNotes;
  final String evaluatorName;

  factory AutismContEval.fromJson(Map<String, dynamic> j) => AutismContEval(
        id: j['id']?.toString(),
        archiveId: j['archiveId']?.toString() ?? '',
        evalSeq: (j['evalSeq'] as int?) ?? (int.tryParse(j['evalSeq']?.toString() ?? '')),
        evalDate: _aDt(j['evalDate']),
        dueDate: _aDt(j['dueDate']),
        status: (j['status'] as int?) ?? 0,
        physiologicalAge: _aStr(j['physiologicalAge']),
        developmentalAge: _aStr(j['developmentalAge']),
        domainPerception: _aStr(j['domainPerception']),
        domainGrossMotor: _aStr(j['domainGrossMotor']),
        domainFineMotor: _aStr(j['domainFineMotor']),
        domainLanguageComm: _aStr(j['domainLanguageComm']),
        domainCognition: _aStr(j['domainCognition']),
        domainSocial: _aStr(j['domainSocial']),
        domainSelfCare: _aStr(j['domainSelfCare']),
        domainEmotionBehavior: _aStr(j['domainEmotionBehavior']),
        effectSummary: _aStr(j['effectSummary']),
        parentPerformance: _aStr(j['parentPerformance']),
        teacherNotes: _aStr(j['teacherNotes']),
        evaluatorName: _aStr(j['evaluatorName']),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'archiveId': archiveId,
        if (evalSeq != null) 'evalSeq': evalSeq,
        if (evalDate != null)
          'evalDate': evalDate!.toIso8601String().split('T').first,
        if (dueDate != null)
          'dueDate': dueDate!.toIso8601String().split('T').first,
        'status': status,
        'physiologicalAge': physiologicalAge,
        'developmentalAge': developmentalAge,
        'domainPerception': domainPerception,
        'domainGrossMotor': domainGrossMotor,
        'domainFineMotor': domainFineMotor,
        'domainLanguageComm': domainLanguageComm,
        'domainCognition': domainCognition,
        'domainSocial': domainSocial,
        'domainSelfCare': domainSelfCare,
        'domainEmotionBehavior': domainEmotionBehavior,
        'effectSummary': effectSummary,
        'parentPerformance': parentPerformance,
        'teacherNotes': teacherNotes,
        'evaluatorName': evaluatorName,
      };
}

/// ════════════════════════════════════════════════════════════════
///  孤独症康复教育学期教学计划（每 6 个月一版）
/// ════════════════════════════════════════════════════════════════
class AutismSemesterPlan {
  AutismSemesterPlan({
    this.id,
    required this.archiveId,
    this.planNo = '',
    this.seqNo,
    this.periodStart,
    this.periodEnd,
    this.childName = '',
    this.className = '',
    this.goalSensory = '',
    this.teacherSensory = '',
    this.goalFine = '',
    this.teacherFine = '',
    this.goalGroup = '',
    this.teacherGroup = '',
    this.goalCognition = '',
    this.teacherCognition = '',
    this.goalLife = '',
    this.teacherLife = '',
    this.goalMusic = '',
    this.teacherMusic = '',
    this.unitThemes = '',
    this.status = 0,
  });

  final String? id;
  final String archiveId;
  final String planNo;
  final int? seqNo;
  final DateTime? periodStart;
  final DateTime? periodEnd;
  final String childName;
  final String className;
  final String goalSensory;
  final String teacherSensory;
  final String goalFine;
  final String teacherFine;
  final String goalGroup;
  final String teacherGroup;
  final String goalCognition;
  final String teacherCognition;
  final String goalLife;
  final String teacherLife;
  final String goalMusic;
  final String teacherMusic;
  final String unitThemes;
  final int status;

  factory AutismSemesterPlan.fromJson(Map<String, dynamic> j) => AutismSemesterPlan(
        id: j['id']?.toString(),
        archiveId: j['archiveId']?.toString() ?? '',
        planNo: _aStr(j['planNo']),
        seqNo: (j['seqNo'] as int?) ?? (int.tryParse(j['seqNo']?.toString() ?? '')),
        periodStart: _aDt(j['periodStart']),
        periodEnd: _aDt(j['periodEnd']),
        childName: _aStr(j['childName']),
        className: _aStr(j['className']),
        goalSensory: _aStr(j['goalSensory']),
        teacherSensory: _aStr(j['teacherSensory']),
        goalFine: _aStr(j['goalFine']),
        teacherFine: _aStr(j['teacherFine']),
        goalGroup: _aStr(j['goalGroup']),
        teacherGroup: _aStr(j['teacherGroup']),
        goalCognition: _aStr(j['goalCognition']),
        teacherCognition: _aStr(j['teacherCognition']),
        goalLife: _aStr(j['goalLife']),
        teacherLife: _aStr(j['teacherLife']),
        goalMusic: _aStr(j['goalMusic']),
        teacherMusic: _aStr(j['teacherMusic']),
        unitThemes: _aStr(j['unitThemes']),
        status: (j['status'] as int?) ?? 0,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'archiveId': archiveId,
        'planNo': planNo,
        if (seqNo != null) 'seqNo': seqNo,
        if (periodStart != null)
          'periodStart': periodStart!.toIso8601String().split('T').first,
        if (periodEnd != null)
          'periodEnd': periodEnd!.toIso8601String().split('T').first,
        'childName': childName,
        'className': className,
        'goalSensory': goalSensory,
        'teacherSensory': teacherSensory,
        'goalFine': goalFine,
        'teacherFine': teacherFine,
        'goalGroup': goalGroup,
        'teacherGroup': teacherGroup,
        'goalCognition': goalCognition,
        'teacherCognition': teacherCognition,
        'goalLife': goalLife,
        'teacherLife': teacherLife,
        'goalMusic': goalMusic,
        'teacherMusic': teacherMusic,
        'unitThemes': unitThemes,
        'status': status,
      };
}

/// ════════════════════════════════════════════════════════════════
///  孤独症康复教育月教学计划（每月一版，六领域 × 第 1-4 周）
/// ════════════════════════════════════════════════════════════════
class AutismMonthlyPlan {
  AutismMonthlyPlan({
    this.id,
    required this.archiveId,
    this.planMonth,
    this.monthLabel = '',
    this.theme = '',
    this.childName = '',
    this.className = '',
    this.sensoryGoal = '',
    this.sensoryWeek1 = '',
    this.sensoryWeek2 = '',
    this.sensoryWeek3 = '',
    this.sensoryWeek4 = '',
    this.teacherSensory = '',
    this.fineGoal = '',
    this.fineWeek1 = '',
    this.fineWeek2 = '',
    this.fineWeek3 = '',
    this.fineWeek4 = '',
    this.teacherFine = '',
    this.groupGoal = '',
    this.groupWeek1 = '',
    this.groupWeek2 = '',
    this.groupWeek3 = '',
    this.groupWeek4 = '',
    this.teacherGroup = '',
    this.cognitionGoal = '',
    this.cognitionWeek1 = '',
    this.cognitionWeek2 = '',
    this.cognitionWeek3 = '',
    this.cognitionWeek4 = '',
    this.teacherCognition = '',
    this.lifeGoal = '',
    this.lifeWeek1 = '',
    this.lifeWeek2 = '',
    this.lifeWeek3 = '',
    this.lifeWeek4 = '',
    this.teacherLife = '',
    this.musicGoal = '',
    this.musicWeek1 = '',
    this.musicWeek2 = '',
    this.musicWeek3 = '',
    this.musicWeek4 = '',
    this.teacherMusic = '',
    this.parentSignature = '',
    this.status = 0,
  });

  final String? id;
  final String archiveId;
  final DateTime? planMonth;
  final String monthLabel;
  final String theme;
  final String childName;
  final String className;
  final String sensoryGoal;
  final String sensoryWeek1;
  final String sensoryWeek2;
  final String sensoryWeek3;
  final String sensoryWeek4;
  final String teacherSensory;
  final String fineGoal;
  final String fineWeek1;
  final String fineWeek2;
  final String fineWeek3;
  final String fineWeek4;
  final String teacherFine;
  final String groupGoal;
  final String groupWeek1;
  final String groupWeek2;
  final String groupWeek3;
  final String groupWeek4;
  final String teacherGroup;
  final String cognitionGoal;
  final String cognitionWeek1;
  final String cognitionWeek2;
  final String cognitionWeek3;
  final String cognitionWeek4;
  final String teacherCognition;
  final String lifeGoal;
  final String lifeWeek1;
  final String lifeWeek2;
  final String lifeWeek3;
  final String lifeWeek4;
  final String teacherLife;
  final String musicGoal;
  final String musicWeek1;
  final String musicWeek2;
  final String musicWeek3;
  final String musicWeek4;
  final String teacherMusic;
  final String parentSignature;
  final int status;

  factory AutismMonthlyPlan.fromJson(Map<String, dynamic> j) => AutismMonthlyPlan(
        id: j['id']?.toString(),
        archiveId: j['archiveId']?.toString() ?? '',
        planMonth: _aDt(j['planMonth']),
        monthLabel: _aStr(j['monthLabel']),
        theme: _aStr(j['theme']),
        childName: _aStr(j['childName']),
        className: _aStr(j['className']),
        sensoryGoal: _aStr(j['sensoryGoal']),
        sensoryWeek1: _aStr(j['sensoryWeek1']),
        sensoryWeek2: _aStr(j['sensoryWeek2']),
        sensoryWeek3: _aStr(j['sensoryWeek3']),
        sensoryWeek4: _aStr(j['sensoryWeek4']),
        teacherSensory: _aStr(j['teacherSensory']),
        fineGoal: _aStr(j['fineGoal']),
        fineWeek1: _aStr(j['fineWeek1']),
        fineWeek2: _aStr(j['fineWeek2']),
        fineWeek3: _aStr(j['fineWeek3']),
        fineWeek4: _aStr(j['fineWeek4']),
        teacherFine: _aStr(j['teacherFine']),
        groupGoal: _aStr(j['groupGoal']),
        groupWeek1: _aStr(j['groupWeek1']),
        groupWeek2: _aStr(j['groupWeek2']),
        groupWeek3: _aStr(j['groupWeek3']),
        groupWeek4: _aStr(j['groupWeek4']),
        teacherGroup: _aStr(j['teacherGroup']),
        cognitionGoal: _aStr(j['cognitionGoal']),
        cognitionWeek1: _aStr(j['cognitionWeek1']),
        cognitionWeek2: _aStr(j['cognitionWeek2']),
        cognitionWeek3: _aStr(j['cognitionWeek3']),
        cognitionWeek4: _aStr(j['cognitionWeek4']),
        teacherCognition: _aStr(j['teacherCognition']),
        lifeGoal: _aStr(j['lifeGoal']),
        lifeWeek1: _aStr(j['lifeWeek1']),
        lifeWeek2: _aStr(j['lifeWeek2']),
        lifeWeek3: _aStr(j['lifeWeek3']),
        lifeWeek4: _aStr(j['lifeWeek4']),
        teacherLife: _aStr(j['teacherLife']),
        musicGoal: _aStr(j['musicGoal']),
        musicWeek1: _aStr(j['musicWeek1']),
        musicWeek2: _aStr(j['musicWeek2']),
        musicWeek3: _aStr(j['musicWeek3']),
        musicWeek4: _aStr(j['musicWeek4']),
        teacherMusic: _aStr(j['teacherMusic']),
        parentSignature: _aStr(j['parentSignature']),
        status: (j['status'] as int?) ?? 0,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'archiveId': archiveId,
        if (planMonth != null)
          'planMonth': planMonth!.toIso8601String().split('T').first,
        'monthLabel': monthLabel,
        'theme': theme,
        'childName': childName,
        'className': className,
        'sensoryGoal': sensoryGoal,
        'sensoryWeek1': sensoryWeek1,
        'sensoryWeek2': sensoryWeek2,
        'sensoryWeek3': sensoryWeek3,
        'sensoryWeek4': sensoryWeek4,
        'teacherSensory': teacherSensory,
        'fineGoal': fineGoal,
        'fineWeek1': fineWeek1,
        'fineWeek2': fineWeek2,
        'fineWeek3': fineWeek3,
        'fineWeek4': fineWeek4,
        'teacherFine': teacherFine,
        'groupGoal': groupGoal,
        'groupWeek1': groupWeek1,
        'groupWeek2': groupWeek2,
        'groupWeek3': groupWeek3,
        'groupWeek4': groupWeek4,
        'teacherGroup': teacherGroup,
        'cognitionGoal': cognitionGoal,
        'cognitionWeek1': cognitionWeek1,
        'cognitionWeek2': cognitionWeek2,
        'cognitionWeek3': cognitionWeek3,
        'cognitionWeek4': cognitionWeek4,
        'teacherCognition': teacherCognition,
        'lifeGoal': lifeGoal,
        'lifeWeek1': lifeWeek1,
        'lifeWeek2': lifeWeek2,
        'lifeWeek3': lifeWeek3,
        'lifeWeek4': lifeWeek4,
        'teacherLife': teacherLife,
        'musicGoal': musicGoal,
        'musicWeek1': musicWeek1,
        'musicWeek2': musicWeek2,
        'musicWeek3': musicWeek3,
        'musicWeek4': musicWeek4,
        'teacherMusic': teacherMusic,
        'parentSignature': parentSignature,
        'status': status,
      };
}

/// ════════════════════════════════════════════════════════════════
///  孤独症月份教育教案（每月两份：上半月 FIRST / 下半月 SECOND）
/// ════════════════════════════════════════════════════════════════
class AutismLessonPlan {
  AutismLessonPlan({
    this.id,
    required this.archiveId,
    this.planMonth,
    this.halfMonth = 'FIRST',
    this.courseDomain = '',
    this.unitTheme = '',
    this.lessonTitle = '',
    this.teacher = '',
    this.classGroup = '',
    this.teachingDateStart,
    this.teachingDateEnd,
    this.teachingForm = '',
    this.obstacleTypeDegree = '',
    this.cognitiveLevel = '',
    this.currentAbility = '',
    this.knowledgeGoal = '',
    this.abilityGoal = '',
    this.emotionGoal = '',
    this.keyPoints = '',
    this.difficultPoints = '',
    this.preparation = '',
    this.introduction = '',
    this.process = '',
    this.summary = '',
    this.extension = '',
    this.learningAttitude = '',
    this.learningEffect = '',
    this.existingProblems = '',
    this.teachingSuggestion = '',
    this.parentSignature = '',
    this.status = 0,
  });

  final String? id;
  final String archiveId;
  final DateTime? planMonth;
  final String halfMonth;
  final String courseDomain;
  final String unitTheme;
  final String lessonTitle;
  final String teacher;
  final String classGroup;
  final DateTime? teachingDateStart;
  final DateTime? teachingDateEnd;
  final String teachingForm;
  final String obstacleTypeDegree;
  final String cognitiveLevel;
  final String currentAbility;
  final String knowledgeGoal;
  final String abilityGoal;
  final String emotionGoal;
  final String keyPoints;
  final String difficultPoints;
  final String preparation;
  final String introduction;
  final String process;
  final String summary;
  final String extension;
  final String learningAttitude;
  final String learningEffect;
  final String existingProblems;
  final String teachingSuggestion;
  final String parentSignature;
  final int status;

  factory AutismLessonPlan.fromJson(Map<String, dynamic> j) => AutismLessonPlan(
        id: j['id']?.toString(),
        archiveId: j['archiveId']?.toString() ?? '',
        planMonth: _aDt(j['planMonth']),
        halfMonth: _aStr(j['halfMonth']),
        courseDomain: _aStr(j['courseDomain']),
        unitTheme: _aStr(j['unitTheme']),
        lessonTitle: _aStr(j['lessonTitle']),
        teacher: _aStr(j['teacher']),
        classGroup: _aStr(j['classGroup']),
        teachingDateStart: _aDt(j['teachingDateStart']),
        teachingDateEnd: _aDt(j['teachingDateEnd']),
        teachingForm: _aStr(j['teachingForm']),
        obstacleTypeDegree: _aStr(j['obstacleTypeDegree']),
        cognitiveLevel: _aStr(j['cognitiveLevel']),
        currentAbility: _aStr(j['currentAbility']),
        knowledgeGoal: _aStr(j['knowledgeGoal']),
        abilityGoal: _aStr(j['abilityGoal']),
        emotionGoal: _aStr(j['emotionGoal']),
        keyPoints: _aStr(j['keyPoints']),
        difficultPoints: _aStr(j['difficultPoints']),
        preparation: _aStr(j['preparation']),
        introduction: _aStr(j['introduction']),
        process: _aStr(j['process']),
        summary: _aStr(j['summary']),
        extension: _aStr(j['extension']),
        learningAttitude: _aStr(j['learningAttitude']),
        learningEffect: _aStr(j['learningEffect']),
        existingProblems: _aStr(j['existingProblems']),
        teachingSuggestion: _aStr(j['teachingSuggestion']),
        parentSignature: _aStr(j['parentSignature']),
        status: (j['status'] as int?) ?? 0,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'archiveId': archiveId,
        if (planMonth != null)
          'planMonth': planMonth!.toIso8601String().split('T').first,
        'halfMonth': halfMonth,
        'courseDomain': courseDomain,
        'unitTheme': unitTheme,
        'lessonTitle': lessonTitle,
        'teacher': teacher,
        'classGroup': classGroup,
        if (teachingDateStart != null)
          'teachingDateStart': teachingDateStart!.toIso8601String().split('T').first,
        if (teachingDateEnd != null)
          'teachingDateEnd': teachingDateEnd!.toIso8601String().split('T').first,
        'teachingForm': teachingForm,
        'obstacleTypeDegree': obstacleTypeDegree,
        'cognitiveLevel': cognitiveLevel,
        'currentAbility': currentAbility,
        'knowledgeGoal': knowledgeGoal,
        'abilityGoal': abilityGoal,
        'emotionGoal': emotionGoal,
        'keyPoints': keyPoints,
        'difficultPoints': difficultPoints,
        'preparation': preparation,
        'introduction': introduction,
        'process': process,
        'summary': summary,
        'extension': extension,
        'learningAttitude': learningAttitude,
        'learningEffect': learningEffect,
        'existingProblems': existingProblems,
        'teachingSuggestion': teachingSuggestion,
        'parentSignature': parentSignature,
        'status': status,
      };
}

/// ════════════════════════════════════════════════════════════════
///  孤独症个别化家庭康复指导计划与反馈（每周一份）
/// ════════════════════════════════════════════════════════════════
class AutismFamilyGuide {
  AutismFamilyGuide({
    this.id,
    required this.archiveId,
    this.weekStart,
    this.weekEnd,
    this.weekLabel = '',
    this.childName = '',
    this.courseName = '',
    this.teacher = '',
    this.guideTarget = '',
    this.homework = '',
    this.completionStatus = '',
    this.parentFeedback = '',
    this.teacherComment = '',
    this.parentSignature = '',
    this.status = 0,
  });

  final String? id;
  final String archiveId;
  final DateTime? weekStart;
  final DateTime? weekEnd;
  final String weekLabel;
  final String childName;
  final String courseName;
  final String teacher;
  final String guideTarget;
  final String homework;
  final String completionStatus;
  final String parentFeedback;
  final String teacherComment;
  final String parentSignature;
  final int status;

  factory AutismFamilyGuide.fromJson(Map<String, dynamic> j) => AutismFamilyGuide(
        id: j['id']?.toString(),
        archiveId: j['archiveId']?.toString() ?? '',
        weekStart: _aDt(j['weekStart']),
        weekEnd: _aDt(j['weekEnd']),
        weekLabel: _aStr(j['weekLabel']),
        childName: _aStr(j['childName']),
        courseName: _aStr(j['courseName']),
        teacher: _aStr(j['teacher']),
        guideTarget: _aStr(j['guideTarget']),
        homework: _aStr(j['homework']),
        completionStatus: _aStr(j['completionStatus']),
        parentFeedback: _aStr(j['parentFeedback']),
        teacherComment: _aStr(j['teacherComment']),
        parentSignature: _aStr(j['parentSignature']),
        status: (j['status'] as int?) ?? 0,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'archiveId': archiveId,
        if (weekStart != null)
          'weekStart': weekStart!.toIso8601String().split('T').first,
        if (weekEnd != null) 'weekEnd': weekEnd!.toIso8601String().split('T').first,
        'weekLabel': weekLabel,
        'childName': childName,
        'courseName': courseName,
        'teacher': teacher,
        'guideTarget': guideTarget,
        'homework': homework,
        'completionStatus': completionStatus,
        'parentFeedback': parentFeedback,
        'teacherComment': teacherComment,
        'parentSignature': parentSignature,
        'status': status,
      };
}

/// ════════════════════════════════════════════════════════════════
///  孤独症儿童康复服务康复效果登记表（年度）
/// ════════════════════════════════════════════════════════════════
class AutismEffectRecord {
  AutismEffectRecord({
    this.id,
    required this.archiveId,
    this.recordYear,
    this.orgName = '',
    this.childName = '',
    this.gender = '',
    this.birthDate,
    this.fillPerson = '',
    this.reviewer = '',
    this.fillDate,
    this.trainingStart,
    this.trainingEnd,
    this.effectStats = '',
    this.effectiveRate = '',
    this.parentTrainingCount,
    this.satisfaction = '',
    this.trainingOutcome = '',
    this.guardianSignature = '',
    this.status = 0,
  });

  final String? id;
  final String archiveId;
  final int? recordYear;
  final String orgName;
  final String childName;
  final String gender;
  final DateTime? birthDate;
  final String fillPerson;
  final String reviewer;
  final DateTime? fillDate;
  final DateTime? trainingStart;
  final DateTime? trainingEnd;
  final String effectStats;
  final String effectiveRate;
  final int? parentTrainingCount;
  final String satisfaction;
  final String trainingOutcome;
  final String guardianSignature;
  final int status;

  factory AutismEffectRecord.fromJson(Map<String, dynamic> j) => AutismEffectRecord(
        id: j['id']?.toString(),
        archiveId: j['archiveId']?.toString() ?? '',
        recordYear: (j['recordYear'] as int?) ??
            (int.tryParse(j['recordYear']?.toString() ?? '')),
        orgName: _aStr(j['orgName']),
        childName: _aStr(j['childName']),
        gender: _aStr(j['gender']),
        birthDate: _aDt(j['birthDate']),
        fillPerson: _aStr(j['fillPerson']),
        reviewer: _aStr(j['reviewer']),
        fillDate: _aDt(j['fillDate']),
        trainingStart: _aDt(j['trainingStart']),
        trainingEnd: _aDt(j['trainingEnd']),
        effectStats: _aStr(j['effectStats']),
        effectiveRate: _aStr(j['effectiveRate']),
        parentTrainingCount: (j['parentTrainingCount'] as int?) ??
            (int.tryParse(j['parentTrainingCount']?.toString() ?? '')),
        satisfaction: _aStr(j['satisfaction']),
        trainingOutcome: _aStr(j['trainingOutcome']),
        guardianSignature: _aStr(j['guardianSignature']),
        status: (j['status'] as int?) ?? 0,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'archiveId': archiveId,
        if (recordYear != null) 'recordYear': recordYear,
        'orgName': orgName,
        'childName': childName,
        'gender': gender,
        if (birthDate != null)
          'birthDate': birthDate!.toIso8601String().split('T').first,
        'fillPerson': fillPerson,
        'reviewer': reviewer,
        if (fillDate != null)
          'fillDate': fillDate!.toIso8601String().split('T').first,
        if (trainingStart != null)
          'trainingStart': trainingStart!.toIso8601String().split('T').first,
        if (trainingEnd != null)
          'trainingEnd': trainingEnd!.toIso8601String().split('T').first,
        'effectStats': effectStats,
        'effectiveRate': effectiveRate,
        if (parentTrainingCount != null)
          'parentTrainingCount': parentTrainingCount,
        'satisfaction': satisfaction,
        'trainingOutcome': trainingOutcome,
        'guardianSignature': guardianSignature,
        'status': status,
      };
}

/// ════════════════════════════════════════════════════════════════
///  孤独症档案详情聚合（入学评估 + 7 类文档 + 任务 + 照片）
/// ════════════════════════════════════════════════════════════════
class AutismArchiveDetail {
  const AutismArchiveDetail({
    required this.archive,
    this.tasks = const <RehabTask>[],
    this.photos = const <RehabPhoto>[],
    this.firstEval,
    this.contEvals = const <AutismContEval>[],
    this.semesterPlans = const <AutismSemesterPlan>[],
    this.monthlyPlans = const <AutismMonthlyPlan>[],
    this.lessonPlans = const <AutismLessonPlan>[],
    this.familyGuides = const <AutismFamilyGuide>[],
    this.effectRecords = const <AutismEffectRecord>[],
  });

  final RehabArchive archive;
  final List<RehabTask> tasks;
  final List<RehabPhoto> photos;
  final AutismFirstEval? firstEval;
  final List<AutismContEval> contEvals;
  final List<AutismSemesterPlan> semesterPlans;
  final List<AutismMonthlyPlan> monthlyPlans;
  final List<AutismLessonPlan> lessonPlans;
  final List<AutismFamilyGuide> familyGuides;
  final List<AutismEffectRecord> effectRecords;

  factory AutismArchiveDetail.fromJson(Map<String, dynamic> j) {
    final dynamic arch = j['archive'];
    final List<dynamic> tk = (j['tasks'] as List?) ?? <dynamic>[];
    final List<dynamic> ph = (j['photos'] as List?) ?? <dynamic>[];
    final dynamic fe = j['autismFirstEval'];
    final List<dynamic> ce = (j['autismContEvals'] as List?) ?? <dynamic>[];
    final List<dynamic> sp = (j['autismSemesterPlans'] as List?) ?? <dynamic>[];
    final List<dynamic> mp = (j['autismMonthlyPlans'] as List?) ?? <dynamic>[];
    final List<dynamic> lp = (j['autismLessonPlans'] as List?) ?? <dynamic>[];
    final List<dynamic> fg = (j['autismFamilyGuides'] as List?) ?? <dynamic>[];
    final List<dynamic> er = (j['autismEffectRecords'] as List?) ?? <dynamic>[];
    return AutismArchiveDetail(
      archive: arch is Map<String, dynamic>
          ? RehabArchive.fromJson(arch)
          : RehabArchive(id: j['id']?.toString() ?? ''),
      tasks: tk
          .whereType<Map<String, dynamic>>()
          .map((e) => RehabTask.fromJson(e))
          .toList(),
      photos: ph
          .whereType<Map<String, dynamic>>()
          .map((e) => RehabPhoto.fromJson(e))
          .toList(),
      firstEval:
          fe is Map<String, dynamic> ? AutismFirstEval.fromJson(fe) : null,
      contEvals: ce
          .whereType<Map<String, dynamic>>()
          .map((e) => AutismContEval.fromJson(e))
          .toList(),
      semesterPlans: sp
          .whereType<Map<String, dynamic>>()
          .map((e) => AutismSemesterPlan.fromJson(e))
          .toList(),
      monthlyPlans: mp
          .whereType<Map<String, dynamic>>()
          .map((e) => AutismMonthlyPlan.fromJson(e))
          .toList(),
      lessonPlans: lp
          .whereType<Map<String, dynamic>>()
          .map((e) => AutismLessonPlan.fromJson(e))
          .toList(),
      familyGuides: fg
          .whereType<Map<String, dynamic>>()
          .map((e) => AutismFamilyGuide.fromJson(e))
          .toList(),
      effectRecords: er
          .whereType<Map<String, dynamic>>()
          .map((e) => AutismEffectRecord.fromJson(e))
          .toList(),
    );
  }
}
