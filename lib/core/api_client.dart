import 'dart:async';
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

/// HTTP 超时配置。生产环境 LAN/校园网常因网关把 8080 出站拦截、DNS 解析慢、
/// 或对端挂起导致请求无响应——只要等不到 TCP 完成或服务器字节，UI 就会无限转圈。
/// 给所有方法套一层 `.timeout()`，并在超时时统一抛出 [ApiException]，
/// 让登录/列表/导出页真正显示"网络异常，请重试"，而不是死锁按钮。
class ApiTimeouts {
  const ApiTimeouts._();
  /// 建立 TCP 连接的最长允许时间。
  static const Duration connect = Duration(seconds: 6);
  /// 从连接成功开始等服务器回包的最长允许时间（含响应头与响应体）。
  static const Duration read = Duration(seconds: 10);
  /// 整个请求的最长允许时间（兜底，避免极端情况两项叠加超出预期）。
  static const Duration overall = Duration(seconds: 20);
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

  Future<dynamic> get(String path, {Map<String, dynamic>? params}) async {
    // 注意：Uri.replace(queryParameters: {}) 会**清空**原 path 里的 query（Dart Uri 行为）。
    // 原来无脑调 .replace 会把 `get('/api/x?a=1&b=2')` 这种手动拼好的 query 全部干没。
    // 修复：仅当显式传了 params 时才用 replace 覆盖；否则保留 path 自带 query。
    Uri uri = Uri.parse('${AppConstants.apiBaseUrl}$path');
    if (params != null) {
      uri = uri.replace(queryParameters: _stringifyParams(params));
    }
    final http.Response resp = await _run(() => _client.get(uri, headers: _headers()));
    return _unwrap(resp);
  }

  Future<dynamic> post(String path, [Object? body]) async {
    final Uri uri = Uri.parse('${AppConstants.apiBaseUrl}$path');
    final http.Response resp = await _run(() => _client.post(
          uri,
          headers: _headers(),
          body: body == null ? null : jsonEncode(body),
        ));
    return _unwrap(resp);
  }

  Future<dynamic> put(String path, [Object? body]) async {
    final Uri uri = Uri.parse('${AppConstants.apiBaseUrl}$path');
    final http.Response resp = await _run(() => _client.put(
          uri,
          headers: _headers(),
          body: body == null ? null : jsonEncode(body),
        ));
    return _unwrap(resp);
  }

  Future<dynamic> delete(String path) async {
    final Uri uri = Uri.parse('${AppConstants.apiBaseUrl}$path');
    final http.Response resp = await _run(() => _client.delete(uri, headers: _headers()));
    return _unwrap(resp);
  }

  /// 直接拉取二进制响应（用于 PDF 导出等不返回 JSON 的接口）。
  /// 成功返回字节；非 2xx 抛出异常（尽量解析后端 `{msg}` 错误）。
  Future<Uint8List> getBytes(String path) async {
    final Uri uri = Uri.parse('${AppConstants.apiBaseUrl}$path');
    final http.Response resp = await _run(
        () => _client.get(uri, headers: _headers(json: false)));
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

/// 把 [Map] 过滤掉 null 后全部 toString，供 queryParameters 序列化使用。
Map<String, String> _stringifyParams(Map<String, dynamic>? src) {
  if (src == null || src.isEmpty) return const <String, String>{};
  final Map<String, String> out = <String, String>{};
  src.forEach((String k, dynamic v) {
    if (v == null) return;
    out[k] = v.toString();
  });
  return out;
}

/// 全局单例客户端。
final ApiClient apiClient = ApiClient();

/// 统一给底层 [http.Client] 调用加 [ApiTimeouts.overall] 超时。
/// 任何 [TimeoutException] / [SocketException] / [http.ClientException] 都映射为
/// 带中文提示的 [ApiException]，让上层 UI 能正常显示"网络异常，请重试"，
/// 不再出现"按钮一直转圈但屏幕无反馈"的死锁体验。
Future<http.Response> _run(Future<http.Response> Function() send) async {
  try {
    return await send().timeout(ApiTimeouts.overall);
  } on TimeoutException {
    throw const ApiException('请求超时，请检查网络或后端');
  } on http.ClientException catch (e) {
    throw ApiException('网络异常：${e.message}');
  } on Exception catch (e) {
    throw ApiException('网络异常：$e');
  }
}
