import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// 登录态存储：token 与 JWT 中的用户声明（uid/name/roles/campusId/tenantId）。
///
/// 启动时调用 [load] 从 SharedPreferences 恢复；登录成功调用 [save]；
/// 登出调用 [clear]。ApiClient 在每个请求前读取 [token] 自动附带 Bearer。
class AuthStore {
  AuthStore._();

  static final AuthStore instance = AuthStore._();

  static const String _tokenKey = 'teacher_app_token';
  static const String _userIdKey = 'teacher_app_user_id';
  static const String _nameKey = 'teacher_app_user_name';
  static const String _rolesKey = 'teacher_app_user_roles';
  static const String _campusKey = 'teacher_app_campus_id';
  static const String _tenantKey = 'teacher_app_tenant_id';

  String? token;
  String? userId;
  String? userName;
  List<String> roles = const <String>[];
  String? campusId;
  String? tenantId;

  /// 从本地存储恢复登录态（App 启动时调用，须 await）。
  Future<void> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    token = prefs.getString(_tokenKey);
    userId = prefs.getString(_userIdKey);
    userName = prefs.getString(_nameKey);
    campusId = prefs.getString(_campusKey);
    tenantId = prefs.getString(_tenantKey);
    final String? r = prefs.getString(_rolesKey);
    roles = (r == null || r.isEmpty)
        ? const <String>[]
        : r.split(',').where((String e) => e.isNotEmpty).toList();
  }

  Future<void> save({
    required String token,
    String? userId,
    String? userName,
    List<String> roles = const <String>[],
    String? campusId,
    String? tenantId,
  }) async {
    this.token = token;
    this.userId = userId;
    this.userName = userName;
    this.roles = roles;
    this.campusId = campusId;
    this.tenantId = tenantId;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    if (userId != null) await prefs.setString(_userIdKey, userId);
    if (userName != null) await prefs.setString(_nameKey, userName);
    await prefs.setString(_rolesKey, roles.join(','));
    if (campusId != null) await prefs.setString(_campusKey, campusId);
    if (tenantId != null) await prefs.setString(_tenantKey, tenantId);
  }

  Future<void> clear() async {
    token = null;
    userId = null;
    userName = null;
    roles = const <String>[];
    campusId = null;
    tenantId = null;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_nameKey);
    await prefs.remove(_rolesKey);
    await prefs.remove(_campusKey);
    await prefs.remove(_tenantKey);
  }

  bool get isLoggedIn => token != null && token!.isNotEmpty;

  /// 角色判断（用于公章审批等权限入口）。
  bool hasRole(String role) =>
      roles.any((String r) => r.toUpperCase() == role.toUpperCase());

  /// 解析 JWT payload（不含签名校验，仅读取声明）。
  static Map<String, dynamic> decodeJwt(String token) {
    final List<String> parts = token.split('.');
    if (parts.length != 3) return <String, dynamic>{};
    String payload = parts[1];
    // base64url 补 padding
    while (payload.length % 4 != 0) {
      payload += '=';
    }
    try {
      final String decoded =
          utf8.decode(base64Url.decode(payload));
      final dynamic json = jsonDecode(decoded);
      if (json is Map<String, dynamic>) return json;
    } catch (_) {
      // 忽略解析失败
    }
    return <String, dynamic>{};
  }
}
