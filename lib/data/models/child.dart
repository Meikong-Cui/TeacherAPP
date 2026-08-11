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
