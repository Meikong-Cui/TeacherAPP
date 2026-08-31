import 'package:teacher_app/core/api_client.dart';
import 'package:teacher_app/core/auth_store.dart';
import 'package:teacher_app/data/models/campus.dart';
import 'package:teacher_app/data/models/user.dart';

/// 鉴权数据层：调用后端 /api/auth/login，解析 JWT 声明并持久化登录态。
class AuthRepository {
  const AuthRepository();

  /// 登录并保存 token 与用户声明。
  /// 用户名/密码与 OA 后台一致（演示：teacher / 123456）。
  Future<void> login(String username, String password) async {
    final dynamic data = await apiClient.post(
      '/api/auth/login',
      <String, dynamic>{'username': username, 'password': password},
    );
    if (data is! Map<String, dynamic>) {
      throw const ApiException('登录响应异常');
    }
    final String? token = data['accessToken'] as String?;
    if (token == null || token.isEmpty) {
      throw const ApiException('未获取到登录凭证');
    }
    // 从 JWT 声明读取用户信息（name/uid/roles/campusId/tenantId）。
    final Map<String, dynamic> claims = AuthStore.decodeJwt(token);
    final String? name = claims['name'] as String?;
    final String? uid = claims['uid']?.toString();
    final String? campusId = claims['campusId']?.toString();
    final String? tenantId = claims['tenantId']?.toString();
    final List<String> roles = <String>[];
    if (claims['roles'] is List) {
      for (final dynamic r in claims['roles']) {
        roles.add(r.toString());
      }
    }
    await AuthStore.instance.save(
      token: token,
      userId: uid,
      userName: name,
      roles: roles,
      campusId: campusId,
      tenantId: tenantId,
    );
  }

  Future<void> logout() => AuthStore.instance.clear();

  /// 拉取当前登录用户的权威信息（GET /api/me），覆盖本地 demo 默认值（林嘉怡）。
  /// 返回映射后的 [TeacherUser]：name / role / center / avatar 来自后端，
  /// dept 后端暂无该字段，保留原有默认。
  Future<TeacherUser> fetchMe() async {
    final dynamic data = await apiClient.get('/api/me');
    if (data is! Map<String, dynamic>) {
      throw const ApiException('获取用户信息失败');
    }
    final String displayName =
        (data['name'] as String?)?.isNotEmpty == true ? data['name'] as String : '教师';

    final List<dynamic> rolesRaw =
        data['roles'] is List ? data['roles'] as List : const <dynamic>[];
    final List<String> roles = rolesRaw.map((e) => e.toString()).toList();
    final String role = _roleLabel(roles);

    String center = '—';
    final dynamic campusRaw = data['campusId'];
    final int? campusId = campusRaw is int
        ? campusRaw
        : (campusRaw is String ? int.tryParse(campusRaw) : null);
    if (campusId != null) {
      for (final Campus c in Campus.all) {
        if (c.id == campusId) {
          center = c.name;
          break;
        }
      }
    }

    final String avatar = displayName.isNotEmpty ? displayName[0] : '?';
    return TeacherUser.demo.copyWith(
      name: displayName,
      role: role,
      center: center,
      avatar: avatar,
    );
  }

  /// 将后端角色码映射为 App 内展示用中文角色名。
  static String _roleLabel(List<String> roles) {
    final List<String> upper = roles.map((r) => r.toUpperCase()).toList();
    if (upper.contains('TEACHER')) return '康复教师';
    if (upper.contains('ADMIN') || upper.contains('PRINCIPAL')) return '管理员';
    if (roles.isNotEmpty) return roles.first;
    return '康复教师';
  }
}
