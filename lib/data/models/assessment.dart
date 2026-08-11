/// 评估题目选项。
class AssessmentQuestion {
  const AssessmentQuestion({
    required this.id,
    required this.title,
    required this.options,
    this.selected,
  });

  final int id;
  final String title;
  final List<String> options;
  final String? selected;
}

/// 评估任务。
class Assessment {
  const Assessment({
    required this.id,
    required this.name,
    required this.status,
    required this.child,
    required this.date,
    required this.version,
    required this.progress,
    required this.total,
    required this.autoSave,
    required this.chapter,
    required this.questions,
  });

  final String id;
  final String name;
  final String status;
  final String child;
  final String date;
  final String version;
  final int progress;
  final int total;
  final String? autoSave;
  final String chapter;
  final List<AssessmentQuestion> questions;
}
