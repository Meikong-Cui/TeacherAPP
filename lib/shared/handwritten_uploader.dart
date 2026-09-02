import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:teacher_app/core/api_client.dart';
import 'package:teacher_app/core/constants.dart';
import 'package:teacher_app/data/models/rehab.dart';
import 'package:teacher_app/features/rehab/data/rehab_repository.dart';
import 'package:teacher_app/features/rehab/provider/rehab_provider.dart';

/// 残联标准模板各部分「上传手写板」可复用组件。
///
/// 用法：
/// ```dart
/// HandwrittenUploader(
///   archiveId: '12',
///   section: 'STANDARD_FORM',   // 后端 rehab_photo.relatedFormType
///   title: '评测量表 · 手写板',
/// )
/// ```
///
/// 行为：
/// - 点 + 按钮从相册/拍照选图 → 上传到 `/api/attachment/upload` → 保存到 `rehab_photo`
/// - 已上传图片以缩略图网格展示，点击看大图，长按删除
class HandwrittenUploader extends ConsumerStatefulWidget {
  const HandwrittenUploader({
    super.key,
    required this.archiveId,
    required this.section,
    required this.title,
    this.subtitle,
    this.compact = false,
  });

  final String archiveId;

  /// 后端 rehab_photo.relatedFormType，建议用「STANDARD_xxx」常量便于检索。
  final String section;

  /// 顶部标题（如「评测量表 · 手写板」）。
  final String title;

  /// 可选副标题/提醒文案。
  final String? subtitle;

  /// true = 紧凑模式（仅显示缩略图行 + 「+ 上传」按钮），用于模块内嵌。
  /// false = 默认模式（顶部标题 + 副标题 + 网格 + 上传按钮），用于入口页或独立区块。
  final bool compact;

  @override
  ConsumerState<HandwrittenUploader> createState() => _HandwrittenUploaderState();
}

class _HandwrittenUploaderState extends ConsumerState<HandwrittenUploader> {
  final ImagePicker _picker = ImagePicker();
  List<RehabPhoto> _photos = <RehabPhoto>[];
  bool _loading = false;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final List<RehabPhoto> list = await const RehabRepository()
          .listPhotos(widget.archiveId, formType: widget.section);
      if (mounted) setState(() => _photos = list);
    } on ApiException catch (e) {
      _toast('加载手写照片失败：${e.message}');
    } catch (_) {
      // 网络/超时：保持空列表
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pick(ImageSource source) async {
    try {
      final XFile? file =
          await _picker.pickImage(source: source, maxWidth: 2048, maxHeight: 2048);
      if (file == null) return;
      if (!mounted) return;
      setState(() => _uploading = true);
      final String url = await apiClient.uploadImage(file.path);
      await const RehabRepository().savePhotoRecord(
        archiveId: widget.archiveId,
        relatedFormType: widget.section,
        filePath: url,
        fileSize: await File(file.path).length(),
        mimeType: file.mimeType ?? 'image/jpeg',
        remark: widget.title,
      );
      await _load();
      _toast('上传成功');
    } on ApiException catch (e) {
      _toast('上传失败：${e.message}');
    } catch (e) {
      _toast('上传失败：$e');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _delete(RehabPhoto p) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('删除手写照片？'),
        content: const Text('删除后无法恢复，确认删除？'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await const RehabRepository().removePhoto(p.id);
      await _load();
      _toast('已删除');
    } on ApiException catch (e) {
      _toast('删除失败：${e.message}');
    } catch (e) {
      _toast('删除失败：$e');
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _fullUrl(String path) =>
      path.startsWith('http') ? path : '${AppConstants.apiBaseUrl}$path';

  @override
  Widget build(BuildContext context) {
    if (widget.compact) return _buildCompact();
    return _buildCard();
  }

  Widget _buildCompact() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.edit_note, color: Colors.amber, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '⚠ 残联标准模板已改版 — ${widget.title}请上传手写板',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, color: Colors.brown),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_loading)
            const LinearProgressIndicator(minHeight: 2)
          else
            _buildThumbStrip(),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: _uploading ? null : () => _pick(ImageSource.camera),
                icon: const Icon(Icons.camera_alt, size: 16),
                label: const Text('拍照'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _uploading ? null : () => _pick(ImageSource.gallery),
                icon: const Icon(Icons.photo_library, size: 16),
                label: const Text('从相册'),
              ),
              if (_uploading) ...<Widget>[
                const SizedBox(width: 12),
                const SizedBox(
                    width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCard() {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Card(
      color: Colors.amber.withValues(alpha: 0.10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.amber.withValues(alpha: 0.6), width: 1.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.edit_note, color: Colors.amber, size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(widget.title,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 15)),
                      const SizedBox(height: 2),
                      Text(
                        widget.subtitle ??
                            '残联标准模板已改版，本模块必须提交手写板（拍照或上传照片）。',
                        style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()))
            else
              _buildGrid(),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                FilledButton.icon(
                  onPressed: _uploading ? null : () => _pick(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt, size: 18),
                  label: const Text('拍照上传'),
                ),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  onPressed: _uploading ? null : () => _pick(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library, size: 18),
                  label: const Text('从相册选择'),
                ),
                if (_uploading) ...<Widget>[
                  const SizedBox(width: 12),
                  const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: 6),
                  const Text('上传中…'),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbStrip() {
    if (_photos.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text('暂未上传',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      );
    }
    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _photos.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (BuildContext ctx, int i) {
          final RehabPhoto p = _photos[i];
          return GestureDetector(
            onTap: () => _openFull(p),
            onLongPress: () => _delete(p),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(_fullUrl(p.filePath),
                  width: 72, height: 72, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 72, height: 72,
                    color: Colors.black12,
                    child: const Icon(Icons.broken_image),
                  )),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGrid() {
    if (_photos.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: <Widget>[
          const Icon(Icons.photo_library_outlined, size: 20, color: Colors.black38),
          const SizedBox(width: 8),
          Text('暂无手写照片，点击下方按钮上传',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ]),
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemCount: _photos.length,
      itemBuilder: (BuildContext ctx, int i) {
        final RehabPhoto p = _photos[i];
        return Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              onTap: () => _openFull(p),
              onLongPress: () => _delete(p),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(_fullUrl(p.filePath), fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: Colors.black12,
                      child: const Icon(Icons.broken_image),
                    )),
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: IconButton.filledTonal(
                onPressed: () => _delete(p),
                icon: const Icon(Icons.delete_outline, size: 18),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black54,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(4),
                  minimumSize: const Size(28, 28),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _openFull(RehabPhoto p) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (BuildContext ctx) => Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: Center(child: Image.network(_fullUrl(p.filePath))),
      ),
    ));
  }
}