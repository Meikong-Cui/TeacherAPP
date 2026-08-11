/// 首页待办统计与条目。
class TodoItem {
  const TodoItem({
    required this.type,
    required this.title,
    required this.count,
    required this.desc,
    required this.icon,
  });

  final String type;
  final String title;
  final int count;
  final String desc;
  final String icon;
}

class Todos {
  const Todos({required this.total, required this.items});

  final int total;
  final List<TodoItem> items;
}
