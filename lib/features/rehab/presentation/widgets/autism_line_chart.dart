import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 折线图单条序列。
class AutismLineSeries {
  const AutismLineSeries({
    required this.label,
    required this.color,
    required this.values,
  });
  final String label;
  final Color color;
  final List<num> values; // 与 xLabels 对齐
}

/// 通用折线图（自绘，无第三方依赖）。
class AutismLineChart extends StatelessWidget {
  const AutismLineChart({
    required this.xLabels,
    required this.series,
    this.height = 260,
    super.key,
  });
  final List<String> xLabels;
  final List<AutismLineSeries> series;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: CustomPaint(
        painter: _LinePainter(xLabels, series),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter(this.xLabels, this.series);
  final List<String> xLabels;
  final List<AutismLineSeries> series;

  @override
  void paint(Canvas canvas, Size size) {
    final double padL = 40;
    final double padR = 12;
    final double padT = 12;
    final double padB = 28;
    final double w = size.width - padL - padR;
    final double h = size.height - padT - padB;
    if (w <= 0 || h <= 0 || xLabels.isEmpty) return;

    num maxY = 1;
    for (final s in series) {
      for (final v in s.values) {
        if (v > maxY) maxY = v;
      }
    }
    maxY = (maxY * 1.1).ceilToDouble();

    final Paint axis = Paint()
      ..color = Colors.grey.shade400
      ..strokeWidth = 1;
    canvas.drawLine(Offset(padL, padT), Offset(padL, padT + h), axis);
    canvas.drawLine(Offset(padL, padT + h), Offset(padL + w, padT + h), axis);

    // y 轴刻度
    const int ticks = 5;
    for (int i = 0; i <= ticks; i++) {
      final double yv = maxY * i / ticks;
      final double y = padT + h - (h * i / ticks);
      canvas.drawLine(Offset(padL - 3, y), Offset(padL + w, y),
          Paint()..color = Colors.grey.shade200..strokeWidth = 1);
      final TextPainter tp = TextPainter(
        text: TextSpan(
            text: yv.round().toString(),
            style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(padL - tp.width - 6, y - tp.height / 2));
    }

    final double stepX = xLabels.length > 1 ? w / (xLabels.length - 1) : 0;
    // x 标签
    for (int i = 0; i < xLabels.length; i++) {
      final double x = padL + stepX * i;
      final TextPainter tp = TextPainter(
        text: TextSpan(
            text: xLabels[i],
            style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, padT + h + 6));
    }

    // 折线
    for (final AutismLineSeries s in series) {
      if (s.values.isEmpty) continue;
      final Paint line = Paint()
        ..color = s.color
        ..strokeWidth = s.label == '全部题目' ? 3 : 1.8
        ..style = PaintingStyle.stroke;
      final Path path = Path();
      for (int i = 0; i < s.values.length; i++) {
        final double x = padL + stepX * i;
        final double y = padT + h - (h * (s.values[i] / maxY));
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, line);
      // 数据点
      for (int i = 0; i < s.values.length; i++) {
        final double x = padL + stepX * i;
        final double y = padT + h - (h * (s.values[i] / maxY));
        canvas.drawCircle(Offset(x, y), s.label == '全部题目' ? 3.5 : 2.5,
            Paint()..color = s.color);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LinePainter old) =>
      old.xLabels != xLabels || old.series != series;
}
