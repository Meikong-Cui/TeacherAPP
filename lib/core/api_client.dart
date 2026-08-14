import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:teacher_app/core/auth_store.dart';
import 'package:teacher_app/core/constants.dart';

/// 统一后端异常（携带中文提示与可选 HTTP 状态码）。
class ApiException implements Exception {
  const ApiException(this.message, [this.statusCode]);
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

/// 统一 HTTP 客户端：自动附带 JWT、统一解包后端 `{code,data,msg}` 结构。
///
/// 后端响应约定：`{ "code": 0, "msg": "success", "data": <任意> }`。
/// code != 0 视为业务失败并抛出 [ApiException]。
class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Map<String, String> _headers({bool json = true}) {
    final Map<String, String> h = <String, String>{};
    if (json) h['Content-Type'] = 'application/json; charset=utf-8';
    final String? token = AuthStore.instance.token;
    if (token != null && token.isNotEmpty) {
      h['Authorization'] = 'Bearer $token';
    }
    return h;
  }

  /// 解析后端响应：成功返回 data，失败抛 [ApiException]。
  dynamic _unwrap(http.Response resp) {
    final String body = resp.body;
    dynamic decoded;
    try {
      decoded = body.isEmpty ? <String, dynamic>{} : jsonDecode(body);
    } catch (_) {
      throw ApiException('响应解析失败', resp.statusCode);
    }
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      if (decoded is Map<String, dynamic> && decoded.containsKey('code')) {
        final int code = (decoded['code'] as int?) ?? -1;
        if (code != 0) {
          throw ApiException(
            (decoded['msg'] as String?) ?? '请求失败',
            resp.statusCode,
          );
        }
        return decoded['data'];
      }
      return decoded;
    }
    String msg = '请求失败（${resp.statusCode}）';
    if (decoded is Map<String, dynamic>) {
      msg = (decoded['msg'] as String?) ?? msg;
    }
    throw ApiException(msg, resp.statusCode);
  }

  Future<dynamic> get(String path) async {
    final Uri uri = Uri.parse('${AppConstants.apiBaseUrl}$path');
    final http.Response resp = await _client.get(uri, headers: _headers());
    return _unwrap(resp);
  }

  Future<dynamic> post(String path, [Object? body]) async {
    final Uri uri = Uri.parse('${AppConstants.apiBaseUrl}$path');
    final http.Response resp = await _client.post(
      uri,
      headers: _headers(),
      body: body == null ? null : jsonEncode(body),
    );
    return _unwrap(resp);
  }

  Future<dynamic> put(String path, [Object? body]) async {
    final Uri uri = Uri.parse('${AppConstants.apiBaseUrl}$path');
    final http.Response resp = await _client.put(
      uri,
      headers: _headers(),
      body: body == null ? null : jsonEncode(body),
    );
    return _unwrap(resp);
  }

  Future<dynamic> delete(String path) async {
    final Uri uri = Uri.parse('${AppConstants.apiBaseUrl}$path');
    final http.Response resp = await _client.delete(uri, headers: _headers());
    return _unwrap(resp);
  }

  /// 直接拉取二进制响应（用于 PDF 导出等不返回 JSON 的接口）。
  /// 成功返回字节；非 2xx 抛出异常（尽量解析后端 `{msg}` 错误）。
  Future<Uint8List> getBytes(String path) async {
    final Uri uri = Uri.parse('${AppConstants.apiBaseUrl}$path');
    final http.Response resp =
        await _client.get(uri, headers: _headers(json: false));
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return resp.bodyBytes;
    }
    String msg = '下载失败（${resp.statusCode}）';
    try {
      final dynamic decoded = jsonDecode(resp.body);
      if (decoded is Map<String, dynamic>) {
        msg = (decoded['msg'] as String?) ?? msg;
      }
    } catch (_) {
      // 非 JSON，保留默认信息
    }
    throw ApiException(msg, resp.statusCode);
  }
}

/// 全局单例客户端。
final ApiClient apiClient = ApiClient();
