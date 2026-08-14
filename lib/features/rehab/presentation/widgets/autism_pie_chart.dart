import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 饼图单个扇区数据。
class AutismPieSlice {
  const AutismPieSlice({
    required this.label,
    required this.pCount,
    required this.total,
    required this.color,
  });
  final String label;
  final int pCount;
  final int total;
  final Color color;

  double get ratio => total == 0 ? 0.0 : pCount / total;
}

/// 可点击涂黑的饼图（剖面图）。点击任一扇区将其标记为「重点缺陷域」（涂黑）。
class AutismPieChart extends StatelessWidget {
  const AutismPieChart({
    required this.slices,
    required this.blackout,
    required this.onTapSlice,
    this.centerText,
    this.size = 260,
    super.key,
  });
  final List<AutismPieSlice> slices;
  final Set<int> blackout;
  final ValueChanged<int> onTapSlice;
  final String? centerText;
  final double size;

  void _handleTap(BuildContext context, Offset local) {
    final double outer = size / 2 - 4;
    final double inner = outer * 0.5;
    final Offset center = Offset(size / 2, size / 2);
    final double dx = local.dx - center.dx;
    final double dy = local.dy - center.dy;
    final double r = math.sqrt(dx * dx + dy * dy);
    if (r < inner || r > outer || slices.isEmpty) return;
    double ang = math.atan2(dy, dx) + math.pi / 2;
    if (ang < 0) ang += 2 * math.pi;
    final int n = slices.length;
    final int idx = (ang / (2 * math.pi / n)).floor() % n;
    onTapSlice(idx);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapUp: (d) => _handleTap(context, d.localPosition),
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _PiePainter(slices, blackout),
          child: Center(
            child: centerText == null
                ? const SizedBox.shrink()
                : Text(centerText!,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }
}

class _PiePainter extends CustomPainter {
  _PiePainter(this.slices, this.blackout);
  final List<AutismPieSlice> slices;
  final Set<int> blackout;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double outer = math.min(size.width, size.height) / 2 - 4;
    final double inner = outer * 0.5;
    final int n = slices.length;
    if (n == 0) return;
    final double sweep = 2 * math.pi / n;
    double start = -math.pi / 2;

    for (int i = 0; i < n; i++) {
      final AutismPieSlice s = slices[i];
      final bool black = blackout.contains(i);
      final Paint paint = Paint()
        ..style = PaintingStyle.fill
        ..color = black ? Colors.black : s.color;

      final Path path = Path();
      path.moveTo(center.dx + inner * math.cos(start),
          center.dy + inner * math.sin(start));
      path.arcTo(Rect.fromCircle(center: center, radius: inner), start, sweep, false);
      path.lineTo(center.dx + outer * math.cos(start + sweep),
          center.dy + outer * math.sin(start + sweep));
      path.arcTo(Rect.fromCircle(center: center, radius: outer), start + sweep, -sweep,
          false);
      path.close();
      canvas.drawPath(path, paint);

      // 边框
      canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..color = Colors.white
            ..strokeWidth = 1.5);

      // 扇区内文字（标签 + P 数）
      final double mid = start + sweep / 2;
      final double tr = (inner + outer) / 2;
      final Offset tp = Offset(center.dx + tr * math.cos(mid),
          center.dy + tr * math.sin(mid));
      final TextSpan span = TextSpan(
        text: '${s.label}\n${s.pCount}/${s.total}',
        style: TextStyle(
          color: black ? Colors.white : Colors.white,
          fontSize: n > 6 ? 10 : 11,
          fontWeight: FontWeight.w600,
        ),
      );
      final TextPainter tp2 = TextPainter(
        text: span,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: sweep * tr * 0.9);
      tp2.paint(canvas, tp - Offset(tp2.width / 2, tp2.height / 2));

      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _PiePainter old) =>
      old.slices != slices || old.blackout != blackout;
}
