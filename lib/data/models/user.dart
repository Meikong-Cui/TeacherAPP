/// 当前登录的康复教师。
class TeacherUser {
  const TeacherUser({
    required this.name,
    required this.role,
    required this.dept,
    required this.center,
    required this.avatar,
  });

  final String name;
  final String role;
  final String dept;
  final String center;
  final String avatar;

  static const TeacherUser demo = TeacherUser(
    name: '林嘉怡',
    role: '康复教师',
    dept: '感知认知组',
    center: '呼兰校区',
    avatar: '林',
  );

  TeacherUser copyWith({
    String? name,
    String? role,
    String? dept,
    String? center,
    String? avatar,
  }) =>
      TeacherUser(
        name: name ?? this.name,
        role: role ?? this.role,
        dept: dept ?? this.dept,
        center: center ?? this.center,
        avatar: avatar ?? this.avatar,
      );
}
