import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teacher_app/data/mock_data.dart';

// 数据源 Provider 层。当前由 MockData（演示数据）实现；
// 接入真实后端时，只需在 ProviderScope(overrides: [...]) 中替换这些 provider，
// 各页面无需改动。模型类型由 mock_data.dart 一并 re-export。
export 'package:teacher_app/data/mock_data.dart';

/// 当前登录用户。
final currentUserProvider = StateProvider<TeacherUser>((ref) => MockData.currentUser);

/// 儿童列表。
final childrenProvider = Provider<List<Child>>((ref) => MockData.children);

/// 单儿童（按 id）。
final childByIdProvider = Provider.family<Child?, String>((ref, id) {
  for (final Child c in MockData.children) {
    if (c.id == id) return c;
  }
  return null;
});

/// 评估任务列表。
final assessmentsProvider = Provider<List<Assessment>>((ref) => MockData.assessments);

/// 单条评估任务（按 id）。
final assessmentByIdProvider = Provider.family<Assessment?, String>((ref, id) {
  for (final Assessment a in ref.watch(assessmentsProvider)) {
    if (a.id == id) return a;
  }
  return null;
});

/// 站内消息列表。
final messagesProvider = Provider<List<AppMessage>>((ref) => MockData.messages);

/// 家庭指导详情。
final guidanceProvider = Provider<Guidance>((ref) => MockData.guidance);
