/// 单个 IEP 目标。
class IepGoal {
  const IepGoal({
    required this.domain,
    required this.status,
    required this.title,
    required this.desc,
    required this.owner,
    required this.deadline,
    required this.progress,
    this.warning = false,
  });

  final String domain;
  final String status;
  final String title;
  final String desc;
  final String owner;
  final String deadline;
  final int progress;
  final bool warning;
}

/// 儿童 IEP 周期。
class Iep {
  const Iep({
    required this.title,
    required this.start,
    required this.end,
    required this.status,
    required this.completed,
    required this.total,
    required this.goals,
  });

  final String title;
  final String start;
  final String end;
  final String status;
  final int completed;
  final int total;
  final List<IepGoal> goals;
}

/// 儿童档案时间线条目。
class ChildTimelineItem {
  const ChildTimelineItem({
    required this.type,
    required this.title,
    required this.desc,
    required this.time,
    required this.actor,
  });

  final String type;
  final String title;
  final String desc;
  final String time;
  final String actor;
}

/// 儿童档案。
class Child {
  const Child({
    required this.id,
    required this.name,
    required this.gender,
    required this.birth,
    required this.ageText,
    required this.group,
    required this.status,
    required this.guardian,
    required this.phone,
    required this.primaryTeacher,
    required this.iepProgress,
    required this.weeklyTrain,
    required this.nextDate,
    this.iep,
    required this.timeline,
  });

  final String id;
  final String name;
  final String gender;
  final String birth;
  final String ageText;
  final String group;
  final String status;
  final String guardian;
  final String phone;
  final String primaryTeacher;
  final int iepProgress;
  final int weeklyTrain;
  final String nextDate;
  final Iep? iep;
  final List<ChildTimelineItem> timeline;
}

/// 儿童主档（后端 `rehab_child` 一行）。
///
/// 这是「家长信息 / 第二位家长 / 出生日期 / 身份证号 / 班级 / 区、县残联意见 /
/// 归属校区」的**唯一真相**，与康复档案（`rehab_archive`）是 1:1 但独立的两张表。
///
/// ⚠️ App「新增孩子」必须**先建主档、再建档案**（档案带上 childId）。
/// 若只建档案，后端在 `childId` 为空时会自动补建一个**只有姓名**的儿童 ——
/// 家长、出生日期、身份证、班级、残联意见会在用户毫无察觉的情况下全部丢失
/// （这正是 2026-10-16 之前「App 填了家长信息但 OA 看不到」的根因）。
class ChildProfile {
  const ChildProfile({
    this.id,
    required this.name,
    this.childType = 'HEARING',
    this.studentType = 'NEW',
    this.gender = '男',
    this.age,
    this.birthDate,
    this.idNumber = '',
    this.className = '',
    this.groupName,
    this.status = '在训',
    this.admissionDate,
    this.teacherId,
    this.teacherName,
    this.remark,
    this.guardianName = '',
    this.guardianRelation = '',
    this.familyPhone = '',
    this.homeAddress = '',
    this.guardian2Name = '',
    this.guardian2Relation = '',
    this.guardian2Phone = '',
    this.federationOpinion = '',
    this.campusId,
  });

  final int? id;
  final String name;

  /// HEARING 听障 / AUTISM 孤独症（后端白名单，其它值会被 400 拒绝）。
  final String childType;

  /// NEW 新生 / OLD 老生。唯一真相在主档，档案上的同名字段只是传输字段。
  final String studentType;
  final String gender;

  /// 周岁。App 录入页不采集，由后端按出生日期推算。
  final int? age;
  final DateTime? birthDate;
  final String idNumber;

  /// 所在班级（≠ groupName：groupName 是康复组别）。
  final String className;
  final String? groupName;
  final String status;
  final DateTime? admissionDate;
  final int? teacherId;
  final String? teacherName;
  final String? remark;

  // ── 家长信息（主家长 + 第二位家长，均为儿童主档级，与档案类型无关）──
  final String guardianName;
  final String guardianRelation;
  final String familyPhone;

  /// 家庭住址（家庭共用，第二位家长不重复录入）。
  final String homeAddress;
  final String guardian2Name;
  final String guardian2Relation;
  final String guardian2Phone;

  /// 区、县残联意见（选填，自由文本）。
  final String federationOpinion;

  /// 归属校区。教师建档时由后端落成教师自己的校区。
  final int? campusId;

  /// 是否填了第二位家长（决定家长卡片是否展开）。
  bool get hasSecondGuardian =>
      guardian2Name.trim().isNotEmpty ||
      guardian2Relation.trim().isNotEmpty ||
      guardian2Phone.trim().isNotEmpty;

  /// 第二位家长摘要，用于折叠态副标题；没填返回空串。
  String get secondGuardianSummary {
    final List<String> parts = <String>[
      if (guardian2Name.trim().isNotEmpty) guardian2Name.trim(),
      if (guardian2Relation.trim().isNotEmpty) guardian2Relation.trim(),
      if (guardian2Phone.trim().isNotEmpty) guardian2Phone.trim(),
    ];
    return parts.join(' · ');
  }

  static DateTime? _date(dynamic v) =>
      v == null ? null : DateTime.tryParse(v.toString());

  static String _fmt(DateTime? d) =>
      d == null ? '' : d.toIso8601String().split('T').first;

  factory ChildProfile.fromJson(Map<String, dynamic> j) => ChildProfile(
        id: (j['id'] as num?)?.toInt(),
        name: (j['name'] as String?) ?? '',
        childType: (j['childType'] as String?) ?? 'HEARING',
        studentType: (j['studentType'] as String?) ?? 'NEW',
        gender: (j['gender'] as String?) ?? '男',
        age: (j['age'] as num?)?.toInt(),
        birthDate: _date(j['birthDate']),
        idNumber: (j['idNumber'] as String?) ?? '',
        className: (j['className'] as String?) ?? '',
        groupName: j['groupName'] as String?,
        status: (j['status'] as String?) ?? '在训',
        admissionDate: _date(j['admissionDate']),
        teacherId: (j['teacherId'] as num?)?.toInt(),
        teacherName: j['teacherName'] as String?,
        remark: j['remark'] as String?,
        guardianName: (j['guardianName'] as String?) ?? '',
        guardianRelation: (j['guardianRelation'] as String?) ?? '',
        familyPhone: (j['familyPhone'] as String?) ?? '',
        homeAddress: (j['homeAddress'] as String?) ?? '',
        guardian2Name: (j['guardian2Name'] as String?) ?? '',
        guardian2Relation: (j['guardian2Relation'] as String?) ?? '',
        guardian2Phone: (j['guardian2Phone'] as String?) ?? '',
        federationOpinion: (j['federationOpinion'] as String?) ?? '',
        campusId: (j['campusId'] as num?)?.toInt(),
      );

  /// 提交给后端的 payload。
  ///
  /// 空串一律转成 null：后端的 update 是**全量覆盖**语义（逐字段 set），
  /// 传 `""` 会把列写成空串而不是 NULL，读回时「有没有填过」就无法区分了。
  /// 这一点必须与 OA 网页的 `ChildFormModal.toPayload()` 保持一致。
  Map<String, dynamic> toPayload() {
    String? s(String v) => v.trim().isEmpty ? null : v.trim();
    return <String, dynamic>{
      'name': name.trim(),
      'childType': childType,
      'studentType': studentType,
      'gender': gender,
      'birthDate': _fmt(birthDate),
      'idNumber': s(idNumber),
      'className': s(className),
      if (groupName != null) 'groupName': s(groupName!),
      'status': status,
      if (admissionDate == null) 'admissionDate': null,
      if (admissionDate != null) 'admissionDate': _fmt(admissionDate),
      if (teacherName != null) 'teacherName': s(teacherName!),
      'guardianName': s(guardianName),
      'guardianRelation': s(guardianRelation),
      'familyPhone': s(familyPhone),
      'homeAddress': s(homeAddress),
      'guardian2Name': s(guardian2Name),
      'guardian2Relation': s(guardian2Relation),
      'guardian2Phone': s(guardian2Phone),
      'federationOpinion': s(federationOpinion),
      'campusId': campusId,
      if (remark != null) 'remark': s(remark!),
    };
  }
}
