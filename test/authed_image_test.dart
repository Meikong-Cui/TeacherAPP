import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teacher_app/core/auth_store.dart';
import 'package:teacher_app/shared/authed_image.dart';

/// 附件图片的加载防线。
///
/// 背景：后端附件接口（`/api/attachment/file/**`）被 `anyRequest().authenticated()`
/// 兜住，**必须带 JWT**；而 `Image.network` 默认不带任何 header。于是只要有人
/// 把上传接口返回的相对路径直接丢给裸 `Image.network`，症状就是：
///   - 相对路径在手机上根本拼不出主机地址；
///   - 即使拼成绝对地址也回 401，缩略图永远是裂图图标。
///
/// 这个缺陷在 Web 端一次性漏了 **17 处**（只修了报障的那 1 处，其余 16 处
/// 用户点到才会发现）。这里把两件事钉死：
///   ① `AuthedImage` 真的把 token 带上了（不是「看起来会带」）；
///   ② `lib/` 下不存在第二份裸网络图片写法（源码扫描，防回归）。
void main() {
  tearDown(() {
    // AuthStore 是单例，不还原会污染其它用例。
    AuthStore.instance.token = null;
  });

  group('AuthedImage.fullUrl', () {
    test('相对路径补成绝对地址，绝对地址原样返回', () {
      const String rel = '/api/attachment/file/202609/a.png';
      expect(AuthedImage.fullUrl(rel), startsWith('http'));
      expect(AuthedImage.fullUrl(rel), endsWith(rel));

      const String abs = 'https://cdn.example.com/x/a.png';
      expect(AuthedImage.fullUrl(abs), abs);
    });
  });

  group('AuthedImage.authHeaders', () {
    test('已登录：给出 Bearer token', () {
      AuthStore.instance.token = 'T0KEN';
      expect(AuthedImage.authHeaders(), <String, String>{
        'Authorization': 'Bearer T0KEN',
      });
    });

    test('未登录 / 空 token：不给头（由后端回 401，交给上层提示）', () {
      AuthStore.instance.token = null;
      expect(AuthedImage.authHeaders(), isEmpty);
      AuthStore.instance.token = '';
      expect(AuthedImage.authHeaders(), isEmpty);
    });
  });

  testWidgets('渲染出的 Image 必须带 Authorization，且地址已补成绝对路径',
      (WidgetTester tester) async {
    AuthStore.instance.token = 'T0KEN';
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AuthedImage(
          path: '/api/attachment/file/202609/a.png',
          // 测试环境里网络请求一律被拦成 400，用 errorBuilder 收掉噪声。
          errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 100));

    final Image img = tester.widget<Image>(find.byType(Image));
    final NetworkImage provider = img.image as NetworkImage;
    expect(provider.url, endsWith('/api/attachment/file/202609/a.png'));
    expect(provider.url, startsWith('http'));
    expect(provider.headers, isNotNull);
    expect(provider.headers!['Authorization'], 'Bearer T0KEN');
  });

  test('源码扫描：lib/ 下不得出现裸 Image.network / NetworkImage', () {
    // AuthedImage 内部本来就是 Image.network —— 它是唯一合法实现。
    const String allowFile = 'authed_image.dart';

    final List<String> hits = <String>[];
    final Directory lib = Directory('lib');
    expect(lib.existsSync(), isTrue,
        reason: '测试须在包根目录运行（flutter test 默认如此）');

    for (final FileSystemEntity f in lib.listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      if (f.uri.pathSegments.last == allowFile) continue;

      // 先剥注释：文档里举例说明「为什么不能用」不该被判成违规，
      // 否则会逼后来者删注释，反而丢掉解释。
      String src = f.readAsStringSync();
      src = src.replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '');
      src = src.replaceAll(RegExp(r'(^|[^:])//.*$', multiLine: true), r'$1');

      final List<String> lines = src.split('\n');
      for (int i = 0; i < lines.length; i++) {
        if (RegExp(r'\bImage\.network\(').hasMatch(lines[i]) ||
            RegExp(r'\bNetworkImage\(').hasMatch(lines[i])) {
          hits.add('${f.path}:${i + 1}  ${lines[i].trim()}');
        }
      }
    }

    expect(hits, isEmpty,
        reason: '这些位置没有带 Authorization，会 401 裂图；'
            '请改用 lib/shared/authed_image.dart 的 AuthedImage：\n${hits.join('\n')}');
  });
}
