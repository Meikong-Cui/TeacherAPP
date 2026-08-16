import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// 将 [RepaintBoundary] 的内容导出为 PNG 图片并触发系统分享。
Future<void> exportBoundaryToPng(
  GlobalKey boundaryKey, {
  String filename = 'chart.png',
  double pixelRatio = 2.0,
}) async {
  final RenderRepaintBoundary? boundary =
      boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
  if (boundary == null) return;

  final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
  final ByteData? byteData =
      await image.toByteData(format: ui.ImageByteFormat.png);
  if (byteData == null) return;

  await Printing.sharePdf(
    bytes: await _pngToPdf(byteData),
    filename: filename.replaceAll('.png', '.pdf'),
  );
}

/// 将 [RepaintBoundary] 的内容导出为 PDF 并触发系统分享。
Future<void> exportBoundaryToPdf(
  GlobalKey boundaryKey, {
  String filename = 'chart.pdf',
  double pixelRatio = 2.0,
  String? title,
}) async {
  final RenderRepaintBoundary? boundary =
      boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
  if (boundary == null) return;

  final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
  final ByteData? byteData =
      await image.toByteData(format: ui.ImageByteFormat.png);
  if (byteData == null) return;

  final Uint8List pdfBytes = await _pngToPdf(byteData, title: title);
  await Printing.sharePdf(bytes: pdfBytes, filename: filename);
}

/// 将 PNG 字节数据嵌入 PDF 页面。
Future<Uint8List> _pngToPdf(ByteData pngData, {String? title}) async {
  final pw.Document pdf = pw.Document();

  final Uint8List pngBytes = pngData.buffer.asUint8List();
  final pw.MemoryImage image = pw.MemoryImage(pngBytes);

  // 根据图片宽高比选择页面方向
  final double imgW = image.width?.toDouble() ?? 800;
  final double imgH = image.height?.toDouble() ?? 600;
  final bool isLandscape = imgW > imgH;

  final PdfPageFormat format =
      isLandscape ? PdfPageFormat.a4.landscape : PdfPageFormat.a4;

  // 计算缩放以适应页面
  final double pageW = format.width - 48;
  final double pageH = format.height - 48 - (title != null ? 30 : 0);
  final double scale = pageW / imgW < pageH / imgH ? pageW / imgW : pageH / imgH;
  final double scaledW = imgW * scale;
  final double scaledH = imgH * scale;

  // 尝试加载字体
  pw.Font? font;
  try {
    font = pw.Font.helvetica();
  } catch (_) {
    font = null;
  }

  pdf.addPage(
    pw.Page(
      pageFormat: format,
      margin: const pw.EdgeInsets.all(24),
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            if (title != null)
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 12),
                child: pw.Text(
                  title,
                  style: pw.TextStyle(font: font, fontSize: 16),
                ),
              ),
            pw.Center(
              child: pw.Container(
                width: scaledW,
                height: scaledH,
                child: pw.Image(image),
              ),
            ),
          ],
        );
      },
    ),
  );

  return pdf.save();
}
