/// 消息提醒。
class AppMessage {
  const AppMessage({
    required this.type,
    required this.title,
    required this.desc,
    required this.time,
    required this.icon,
  });

  final String type;
  final String title;
  final String desc;
  final String time;
  final String icon;
}
