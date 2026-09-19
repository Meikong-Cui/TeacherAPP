import 'package:flutter/material.dart';
import 'package:teacher_app/core/auth_store.dart';
import 'package:teacher_app/core/constants.dart';

/// 带鉴权的网络图片。
///
/// **为什么必须用它**：附件上传接口返回的是**相对路径**
/// （`/api/attachment/file/202609/xxx.png`），而后端对一切请求都要求 JWT
/// （`anyRequest().authenticated()`）。`Image.network` 不会自动附带 token，
/// 于是：
///   - 相对路径在移动端根本无法解析成主机地址；
///   - 即便拼成绝对地址，不带 `Authorization` 也一律回 401。
/// 表现就是缩略图位置永远是一个裂图图标，点开大图也加载不出来。
///
/// 这里把「拼绝对地址 + 附带 token」收成唯一实现，避免各页面各写一份、
/// 然后陆续漏掉 header。每个新加网络图片的地方都应当走它。
///
/// 注：`Image.network` 的 `headers` 在 Flutter Web 上会被忽略。本 App 只发
/// Android / iOS，无影响；若将来要出 Web 版，需改为先取字节再 `Image.memory`。
class AuthedImage extends StatelessWidget {
  const AuthedImage({
    super.key,
    required this.path,
    this.fit,
    this.width,
    this.height,
    this.errorBuilder,
    this.loadingBuilder,
  });

  /// 附件地址：可为相对路径（`/api/attachment/...`）或绝对地址（`http(s)://...`）。
  final String path;
  final BoxFit? fit;
  final double? width;
  final double? height;
  final ImageErrorWidgetBuilder? errorBuilder;
  final ImageLoadingBuilder? loadingBuilder;

  /// 相对路径补全为绝对地址；已是绝对地址的原样返回。
  static String fullUrl(String path) =>
      path.startsWith('http') ? path : '${AppConstants.apiBaseUrl}$path';

  /// 附件图片所需的鉴权头。未登录时返回空表（由后端回 401，交给上层提示）。
  static Map<String, String> authHeaders() {
    final String? token = AuthStore.instance.token;
    if (token == null || token.isEmpty) return const <String, String>{};
    return <String, String>{'Authorization': 'Bearer $token'};
  }

  @override
  Widget build(BuildContext context) {
    return Image.network(
      fullUrl(path),
      headers: authHeaders(),
      fit: fit,
      width: width,
      height: height,
      errorBuilder: errorBuilder,
      loadingBuilder: loadingBuilder,
    );
  }
}
