import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:teacher_app/data/models/rehab.dart';

String _fmtDate(DateTime? d) => d == null ? '' : DateFormat('yyyy-MM-dd').format(d);

/// 导出「听能管理记录」为 PDF 并触发系统分享。
///
/// 说明：为了正确显示中文，需要在 `assets/fonts/NotoSansSC-Regular.otf`
/// 放置中文字体文件（如 NotoSansCJKsc-Regular.otf）。若未放置，会回退到
/// pdf 内置字体，中文将显示为 tofu/方框，但版式与数字仍可正常导出。
Future<void> exportHearingRecordToPdf(RehabHearingRecord record) async {
  final pw.Document pdf = pw.Document();
  final pw.Font? font = await _loadFont();

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),
      build: (pw.Context context) => _buildContent(record, font),
    ),
  );

  await Printing.sharePdf(
    bytes: await pdf.save(),
    filename:
        '听能管理记录_${record.name ?? ""}_${DateFormat('yyyyMMdd').format(record.evalDate ?? DateTime.now())}.pdf',
  );
}

Future<pw.Font?> _loadFont() async {
  try {
    final ByteData data =
        await rootBundle.load('assets/fonts/NotoSansSC-Regular.otf');
    return pw.Font.ttf(data);
  } catch (_) {
    return null;
  }
}

pw.TextStyle _ts(pw.Font? font, {double size = 9, pw.FontWeight? weight}) =>
    pw.TextStyle(font: font, fontSize: size, fontWeight: weight);

List<pw.Widget> _buildContent(RehabHearingRecord r, pw.Font? font) {
  return <pw.Widget>[
    pw.Center(
      child: pw.Text('听障儿童听能管理记录——诊断记录',
          style: _ts(font, size: 14, weight: pw.FontWeight.bold)),
    ),
    pw.SizedBox(height: 8),
    pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
      pw.Text('档案编号：${r.recordNo ?? ""}', style: _ts(font)),
    ]),
    pw.SizedBox(height: 8),

    // 基本资料
    _sectionTitle('基本资料', font),
    _infoTable([
      ['姓名', r.name ?? '', '性别', r.gender ?? '', '出生年月', _fmtDate(r.birthDate)],
      ['听障确诊时间', _fmtDate(r.diagnosisDate), '首次佩戴助听设备时间',
       '左耳 ${_fmtDate(r.leftFirstDeviceDate)}', '', '右耳 ${_fmtDate(r.rightFirstDeviceDate)}'],
    ], font),
    _deviceTable(r, font),
    pw.SizedBox(height: 8),

    // 听力测试
    _sectionTitle('一、听力测试', font),
    pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Expanded(child: _methodTable(r, font)),
      pw.SizedBox(width: 8),
      pw.Expanded(child: _symbolTable(font)),
    ]),
    pw.SizedBox(height: 8),
    _audiogramSection(r, font),
    pw.SizedBox(height: 8),

    // 检查项目
    _sectionTitle('二、检查项目与结果', font),
    _inspectionTable(r, font),
    pw.SizedBox(height: 8),

    // 诊断
    _sectionTitle('三、诊断', font),
    _linedBox(r.diagnosis ?? '', font),
    pw.SizedBox(height: 8),

    // 听力师评语
    _sectionTitle('四、听力师评语', font),
    _linedBox(r.audiologistComment ?? '', font),
    pw.SizedBox(height: 16),
    pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
      pw.Text('填写日期：${_fmtDate(r.fillDate)}', style: _ts(font)),
      pw.Text('听力师签名：${r.audiologistSignature ?? ""}', style: _ts(font)),
    ]),
  ];
}

pw.Widget _sectionTitle(String text, pw.Font? font) {
  return pw.Container(
    width: double.infinity,
    color: PdfColors.grey300,
    padding: const pw.EdgeInsets.all(4),
    margin: const pw.EdgeInsets.only(bottom: 4),
    child: pw.Text(text, style: _ts(font, size: 10, weight: pw.FontWeight.bold)),
  );
}

pw.Widget _infoTable(List<List<String?>> rows, pw.Font? font) {
  return pw.Table(
    border: pw.TableBorder.all(),
    children: rows.map((row) {
      return pw.TableRow(
        children: row.asMap().entries.map((e) {
          final bool isLabel = e.key % 2 == 0;
          return pw.Container(
            padding: const pw.EdgeInsets.all(4),
            color: isLabel ? PdfColors.grey100 : PdfColors.white,
            child: pw.Text(e.value ?? '', style: _ts(font)),
          );
        }).toList(),
      );
    }).toList(),
  );
}

pw.Widget _deviceTable(RehabHearingRecord r, pw.Font? font) {
  final String leftType = r.leftCompensationType.join(' ');
  final String rightType = r.rightCompensationType.join(' ');
  return pw.Table(
    border: pw.TableBorder.all(),
    children: [
      pw.TableRow(children: [
        pw.Container(padding: const pw.EdgeInsets.all(4), child: pw.Text('补偿/重建方式', style: _ts(font))),
        pw.Container(padding: const pw.EdgeInsets.all(4), child: pw.Text('左耳 $leftType', style: _ts(font))),
        pw.Container(padding: const pw.EdgeInsets.all(4), child: pw.Text('右耳 $rightType', style: _ts(font))),
      ]),
      pw.TableRow(children: [
        pw.Container(padding: const pw.EdgeInsets.all(4), child: pw.Text('设备型号', style: _ts(font))),
        pw.Container(padding: const pw.EdgeInsets.all(4), child: pw.Text(r.leftDeviceModel ?? '', style: _ts(font))),
        pw.Container(padding: const pw.EdgeInsets.all(4), child: pw.Text(r.rightDeviceModel ?? '', style: _ts(font))),
      ]),
      pw.TableRow(children: [
        pw.Container(padding: const pw.EdgeInsets.all(4), child: pw.Text('程序 / 音量', style: _ts(font))),
        pw.Container(padding: const pw.EdgeInsets.all(4), child: pw.Text('${r.leftProgram ?? ""} / ${r.leftVolume ?? ""}', style: _ts(font))),
        pw.Container(padding: const pw.EdgeInsets.all(4), child: pw.Text('${r.rightProgram ?? ""} / ${r.rightVolume ?? ""}', style: _ts(font))),
      ]),
    ],
  );
}

pw.Widget _methodTable(RehabHearingRecord r, pw.Font? font) {
  const List<String> methods = ['BOA', 'VRA', 'PA', 'PTA'];
  const List<String> labels = ['行为观察测听', '视觉强化测听', '游戏测听', '纯音测听'];
  return pw.Table(
    border: pw.TableBorder.all(),
    children: [
      pw.TableRow(children: [
        pw.Container(color: PdfColors.grey100, padding: const pw.EdgeInsets.all(4),
            child: pw.Text('测试方法', style: _ts(font, weight: pw.FontWeight.bold))),
      ]),
      ...List<pw.TableRow>.generate(methods.length, (i) {
        final bool checked = r.hearingTestMethod.contains(methods[i]);
        return pw.TableRow(children: [
          pw.Container(padding: const pw.EdgeInsets.all(4),
              child: pw.Text('${checked ? "☑" : "☐"} ${methods[i]} ${labels[i]}', style: _ts(font))),
        ]);
      }),
    ],
  );
}

pw.Widget _symbolTable(pw.Font? font) {
  return pw.Table(
    border: pw.TableBorder.all(),
    children: [
      pw.TableRow(children: [
        pw.Container(color: PdfColors.grey100, padding: const pw.EdgeInsets.all(4),
            child: pw.Text('符号说明', style: _ts(font, weight: pw.FontWeight.bold))),
      ]),
      pw.TableRow(children: [
        pw.Container(padding: const pw.EdgeInsets.all(4),
            child: pw.Text('左耳：×  右耳：○', style: _ts(font))),
      ]),
      pw.TableRow(children: [
        pw.Container(padding: const pw.EdgeInsets.all(4),
            child: pw.Text('气导：未掩蔽 ○×  掩蔽 △□', style: _ts(font))),
      ]),
    ],
  );
}

pw.Widget _audiogramSection(RehabHearingRecord r, pw.Font? font) {
  const List<int> freqs = [250, 500, 1000, 2000, 4000];

  pw.Widget chart(String title, List<AudiogramPoint> points, PdfColor color) {
    const double plotW = 150;
    const double plotH = 160;

    // dB 标签（左侧）
    final List<pw.Widget> dbLabels = List<pw.Widget>.generate(7, (i) {
      final int db = i * 20;
      return pw.Container(
        height: plotH / 6,
        alignment: pw.Alignment.centerRight,
        child: pw.Text(db.toString(), style: _ts(font, size: 8)),
      );
    });

    // Hz 标签（底部）
    final List<pw.Widget> hzLabels = List<pw.Widget>.generate(freqs.length, (i) {
      final String label = freqs[i] >= 1000 ? '${freqs[i] ~/ 1000}K' : freqs[i].toString();
      return pw.Expanded(
        child: pw.Center(child: pw.Text(label, style: _ts(font, size: 8))),
      );
    });

    return pw.Column(children: [
      pw.Text(title, style: _ts(font, size: 10, weight: pw.FontWeight.bold)),
      pw.SizedBox(height: 4),
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Column(children: dbLabels),
        pw.Column(children: [
          pw.CustomPaint(
            size: const PdfPoint(plotW, plotH),
            painter: (PdfGraphics canvas, PdfPoint size) {
              // 背景
              canvas.setFillColor(PdfColors.white);
              canvas.drawRect(0, 0, plotW, plotH);
              canvas.fillPath();

              // 网格
              canvas.setStrokeColor(PdfColors.grey300);
              canvas.setLineWidth(0.5);
              for (int db = 0; db <= 120; db += 10) {
                final double y = plotH * (db / 120.0);
                canvas.drawLine(0, y, plotW, y);
                canvas.strokePath();
              }
              for (int i = 0; i < freqs.length; i++) {
                final double x = plotW * i / (freqs.length - 1);
                canvas.drawLine(x, 0, x, plotH);
                canvas.strokePath();
              }

              // 边框
              canvas.setStrokeColor(PdfColors.black);
              canvas.setLineWidth(1);
              canvas.drawRect(0, 0, plotW, plotH);
              canvas.strokePath();

              // 折线
              final sorted = List<AudiogramPoint>.from(points)
                ..sort((a, b) => a.freq.compareTo(b.freq));
              if (sorted.length >= 2) {
                canvas.setStrokeColor(color);
                canvas.setLineWidth(1.5);
                for (int i = 0; i < sorted.length - 1; i++) {
                  final int idxA = freqs.indexOf(sorted[i].freq);
                  final int idxB = freqs.indexOf(sorted[i + 1].freq);
                  if (idxA < 0 || idxB < 0) continue;
                  final double x1 = plotW * idxA / (freqs.length - 1);
                  final double y1 = plotH * (sorted[i].db / 120.0);
                  final double x2 = plotW * idxB / (freqs.length - 1);
                  final double y2 = plotH * (sorted[i + 1].db / 120.0);
                  canvas.drawLine(x1, y1, x2, y2);
                  canvas.strokePath();
                }
              }

              // 点
              canvas.setStrokeColor(color);
              canvas.setLineWidth(1.5);
              for (final p in points) {
                final int idx = freqs.indexOf(p.freq);
                if (idx < 0) continue;
                final double x = plotW * idx / (freqs.length - 1);
                final double y = plotH * (p.db / 120.0);
                canvas.drawEllipse(x - 3, y - 3, 6, 6);
                canvas.strokePath();
              }
            },
          ),
          pw.SizedBox(width: plotW, child: pw.Row(children: hzLabels)),
        ]),
      ]),
    ]);
  }

  return pw.Column(children: [
    pw.Center(child: pw.Text('听力图（测量单位：${r.unit}）',
        style: _ts(font, size: 10, weight: pw.FontWeight.bold))),
    pw.SizedBox(height: 4),
    pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceAround, children: [
      chart('左耳', r.leftAudiogram, PdfColors.red),
      chart('右耳', r.rightAudiogram, PdfColors.blue),
    ]),
    pw.SizedBox(height: 4),
    pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceAround, children: [
      pw.Text('左耳裸耳平均听阈：${r.leftAverageHearing ?? ""}', style: _ts(font)),
      pw.Text('右耳裸耳平均听阈：${r.rightAverageHearing ?? ""}', style: _ts(font)),
    ]),
    pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceAround, children: [
      pw.Text('左耳助听器效果：${r.leftAidEffect ?? ""}', style: _ts(font)),
      pw.Text('右耳助听器效果：${r.rightAidEffect ?? ""}', style: _ts(font)),
    ]),
    pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceAround, children: [
      pw.Text('评估日期：${_fmtDate(r.evalDate)}', style: _ts(font)),
      pw.Text('评估人员：${r.evaluatorName ?? ""}', style: _ts(font)),
    ]),
  ]);
}

pw.Widget _inspectionTable(RehabHearingRecord r, pw.Font? font) {
  return pw.Table(
    border: pw.TableBorder.all(),
    children: [
      pw.TableRow(children: [
        pw.Container(color: PdfColors.grey100, padding: const pw.EdgeInsets.all(4),
            child: pw.Text('项目', style: _ts(font, weight: pw.FontWeight.bold))),
        pw.Container(color: PdfColors.grey100, padding: const pw.EdgeInsets.all(4),
            child: pw.Text('结果/备注', style: _ts(font, weight: pw.FontWeight.bold))),
      ]),
      pw.TableRow(children: [
        pw.Container(padding: const pw.EdgeInsets.all(4),
            child: pw.Text('电生理测试 / 言语测听 / 辅助检查', style: _ts(font))),
        pw.Container(padding: const pw.EdgeInsets.all(4),
            child: pw.Text(r.inspectionItems ?? '', style: _ts(font))),
      ]),
    ],
  );
}

pw.Widget _linedBox(String text, pw.Font? font) {
  return pw.Container(
    width: double.infinity,
    height: 60,
    decoration: pw.BoxDecoration(border: pw.Border.all()),
    padding: const pw.EdgeInsets.all(4),
    child: pw.Text(text, style: _ts(font)),
  );
}
