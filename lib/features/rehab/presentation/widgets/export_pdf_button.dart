import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import 'package:teacher_app/core/api_client.dart';

/// 导出 PDF 按钮（从后端拉取字节流 → 调系统分享/打印面板）。
///
/// 后端要按扫描件模板逐页叠字再合成 PDF（首次评估 5 页、持续评估 8 页），
/// 单次常常要几秒。按钮自带 busy 态：导出期间禁用并显示小菊花，
/// 防止教师连点把同一份文件重复生成多次。
///
/// 用法：
/// ```dart
/// ExportPdfButton(
///   filename: '首次评估_小明.pdf',
///   fetchBytes: () => repo.exportHearingFirstEvalPdf(id),
/// )
/// ```
class ExportPdfButton extends StatefulWidget {
  const ExportPdfButton({
    required this.fetchBytes,
    required this.filename,
    super.key,
    this.label = '导出 PDF',
    this.tooltip = '导出 PDF',
    this.icon = Icons.picture_as_pdf,
    this.iconOnly = false,
    this.fab = false,
    this.heroTag,
    this.enabled = true,
  });

  /// 真正拉 PDF 字节流的函数（见 RehabRepository 的 exportHearing*Pdf）。
  final Future<Uint8List> Function() fetchBytes;

  /// 分享出去的文件名（含 .pdf 后缀）。
  final String filename;

  /// 文字按钮模式下的文案。
  final String label;

  /// 图标模式 / FAB 模式下的长按提示。
  final String tooltip;

  final IconData icon;

  /// 只显示图标（塞进卡片右上角那排小按钮时用）。
  final bool iconOnly;

  /// 渲染成 FloatingActionButton（浮在只读页右下角时用）。
  final bool fab;

  /// FAB 模式必填（同一页面多个 FAB 会撞 hero 动画）。
  final String? heroTag;

  /// false 时按钮置灰（如记录尚未保存、拿不到 id）。
  final bool enabled;

  @override
  State<ExportPdfButton> createState() => _ExportPdfButtonState();
}

class _ExportPdfButtonState extends State<ExportPdfButton> {
  bool _busy = false;

  Future<void> _run() async {
    if (_busy || !widget.enabled) return;
    setState(() => _busy = true);
    // 先抓住 messenger，避免 await 之后 context 已卸载导致跨帧使用报错。
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      final Uint8List bytes = await widget.fetchBytes();
      if (bytes.isEmpty) throw const ApiException('导出内容为空');
      await Printing.sharePdf(bytes: bytes, filename: widget.filename);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text('导出失败：${e is ApiException ? e.message : e}'),
        backgroundColor: Colors.red,
      ));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget child = _busy
        ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Icon(widget.icon, size: 18);
    final VoidCallback? onPressed = (_busy || !widget.enabled) ? null : _run;

    if (widget.fab) {
      return FloatingActionButton.small(
        heroTag: widget.heroTag ?? 'export_pdf_fab',
        tooltip: _busy ? '导出中…' : widget.tooltip,
        onPressed: onPressed,
        child: child,
      );
    }
    if (widget.iconOnly) {
      return IconButton(
        icon: child,
        tooltip: _busy ? '导出中…' : widget.tooltip,
        onPressed: onPressed,
      );
    }
    return TextButton.icon(
      onPressed: onPressed,
      icon: child,
      label: Text(_busy ? '导出中…' : widget.label,
          style: const TextStyle(fontSize: 12)),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 6),
      ),
    );
  }
}
