import 'package:flutter/material.dart';
import 'package:teacher_app/app/design_tokens.dart';

/// 附件画廊：缩略图横排 + 全屏查看器（双指缩放 / 左右翻页 / 点击空白关闭）。
///
/// 请款单与报销单的**金额只存在于凭证图片里**，审批人必须能放大看清，
/// 所以这里不能只放一个小缩略图了事 —— 全屏查看器是审批的必要条件。
/// 申请页与审批详情页共用这一份实现，避免两处各写一套。
class AttachmentGallery extends StatelessWidget {
  const AttachmentGallery({
    super.key,
    required this.urls,
    this.label = '附件',
    this.emptyText = '无附件',
    this.thumbSize = 96,
  });

  final List<String> urls;
  final String label;
  final String emptyText;
  final double thumbSize;

  /// 仅按扩展名判断能否当图片展示；非图片走文件图标 + 仍可放大（浏览器/系统查看器）。
  static bool looksLikeImage(String url) {
    final String u = url.toLowerCase().split('?').first;
    return <String>['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp', '.heic']
        .any(u.endsWith);
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    if (urls.isEmpty) {
      return Text(
        emptyText,
        style: textTheme.bodySmall?.copyWith(color: AppPalette.inkMute),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '$label（共 ${urls.length} 张）· 点击图片放大核对',
          style: textTheme.bodySmall?.copyWith(color: AppPalette.inkMute),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: thumbSize,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: urls.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (BuildContext ctx, int i) => _Thumb(
              url: urls[i],
              index: i,
              size: thumbSize,
              onTap: () => showAttachmentViewer(context, urls, i),
            ),
          ),
        ),
      ],
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({
    required this.url,
    required this.index,
    required this.size,
    required this.onTap,
  });

  final String url;
  final int index;
  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Container(
          width: size,
          height: size,
          color: dark ? const Color(0xFF1E2A29) : const Color(0xFFEDF3F2),
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              if (AttachmentGallery.looksLikeImage(url))
                Image.network(
                  url,
                  fit: BoxFit.cover,
                  loadingBuilder: (BuildContext c, Widget child,
                          ImageChunkEvent? progress) =>
                      progress == null
                          ? child
                          : const Center(
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                  errorBuilder: (_, __, ___) => const Icon(
                      Icons.broken_image_outlined,
                      color: AppPalette.inkMute),
                )
              else
                const Icon(Icons.insert_drive_file_outlined,
                    size: 30, color: AppPalette.inkMute),
              Positioned(
                right: 4,
                bottom: 4,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 打开全屏附件查看器。黑色背景与白字是刻意硬编码的：查看器与 App 明暗主题无关，
/// 图片在深色底上比在浅色底上更容易看清凭证上的数字。
Future<void> showAttachmentViewer(
  BuildContext context,
  List<String> urls,
  int initialIndex,
) {
  if (urls.isEmpty) return Future<void>.value();
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black,
    builder: (BuildContext ctx) => _AttachmentViewer(
      urls: urls,
      initialIndex: initialIndex.clamp(0, urls.length - 1),
    ),
  );
}

class _AttachmentViewer extends StatefulWidget {
  const _AttachmentViewer({required this.urls, required this.initialIndex});

  final List<String> urls;
  final int initialIndex;

  @override
  State<_AttachmentViewer> createState() => _AttachmentViewerState();
}

class _AttachmentViewerState extends State<_AttachmentViewer> {
  late final PageController _controller =
      PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black,
      child: SafeArea(
        child: Stack(
          children: <Widget>[
            PageView.builder(
              controller: _controller,
              itemCount: widget.urls.length,
              onPageChanged: (int i) => setState(() => _index = i),
              itemBuilder: (BuildContext ctx, int i) => InteractiveViewer(
                minScale: 0.8,
                maxScale: 6,
                child: Center(child: _viewerImage(widget.urls[i])),
              ),
            ),
            Positioned(
              top: 4,
              left: 4,
              right: 4,
              child: Row(
                children: <Widget>[
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    tooltip: '关闭',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Spacer(),
                  Text(
                    '${_index + 1} / ${widget.urls.length}',
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
            Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: Text(
                widget.urls.length > 1
                    ? '双指缩放 · 左右滑动切换 · 点击左上角关闭'
                    : '双指缩放查看细节 · 点击左上角关闭',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _viewerImage(String url) {
    if (!AttachmentGallery.looksLikeImage(url)) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.insert_drive_file_outlined,
              size: 64, color: Colors.white54),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              url,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
          const SizedBox(height: 8),
          const Text('该附件不是图片格式，请在电脑端打开',
              style: TextStyle(color: Colors.white38, fontSize: 12)),
        ],
      );
    }
    return Image.network(
      url,
      fit: BoxFit.contain,
      loadingBuilder:
          (BuildContext c, Widget child, ImageChunkEvent? progress) =>
              progress == null
                  ? child
                  : const SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    ),
      errorBuilder: (_, __, ___) => const Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.broken_image_outlined, size: 56, color: Colors.white54),
          SizedBox(height: 10),
          Text('图片加载失败，请检查网络后重试',
              style: TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }
}
