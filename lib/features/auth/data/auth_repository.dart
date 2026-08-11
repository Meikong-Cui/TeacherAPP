import 'package:teacher_app/core/api_client.dart';
import 'package:teacher_app/core/auth_store.dart';

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
}
