/// 康复指导（下发到家庭的在家练习方案）。
class Guidance {
  const Guidance({
    required this.title,
    required this.relation,
    required this.target,
    required this.steps,
    required this.notice,
  });

  final String title;
  final String relation;
  final String target;
  final List<String> steps;
  final String notice;
}
