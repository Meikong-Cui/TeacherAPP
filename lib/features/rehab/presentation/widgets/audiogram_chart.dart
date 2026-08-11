import 'dart:math';
import 'package:flutter/material.dart';
import 'package:teacher_app/data/models/rehab.dart';

/// 可交互听力图。
///
/// * 横轴固定 250/500/1000/2000/4000 Hz（5 个频率）。
/// * 纵轴 0 ~ 120 dB，0 在顶部（听力图惯例）。
/// * 老师点击/拖拽图表即可在最近的频率上落点；dB 取最接近的 5 的倍数。
/// * [editable] 为 true 时允许编辑；只读时仍可点击查看最近点数值。
class AudiogramChart extends StatefulWidget {
  const AudiogramChart({
    super.key,
    required this.leftPoints,
    required this.rightPoints,
    this.onLeftChanged,
    this.onRightChanged,
    this.title = '听力图',
    this.editable = true,
    this.showBothEars = true,
  });

  final List<AudiogramPoint> leftPoints;
  final List<AudiogramPoint> rightPoints;
  final ValueChanged<List<AudiogramPoint>>? onLeftChanged;
  final ValueChanged<List<AudiogramPoint>>? onRightChanged;
  final String title;
  final bool editable;
  final bool showBothEars;

  static const List<int> frequencies = <int>[250, 500, 1000, 2000, 4000];

  @override
  State<AudiogramChart> createState() => _AudiogramChartState();
}

class _AudiogramChartState extends State<AudiogramChart> {
  /// 当前编辑侧：true=左耳，false=右耳。
  bool _editLeft = true;
  Offset? _touchPos;
  String? _tooltipText;

  List<AudiogramPoint> get _currentLeft => List<AudiogramPoint>.from(widget.leftPoints);
  List<AudiogramPoint> get _currentRight => List<AudiogramPoint>.from(widget.rightPoints);

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // 标题与图例
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(widget.title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        if (widget.showBothEars || widget.editable)
          Row(mainAxisSize: MainAxisSize.min, children: [
            _legend(Colors.red, '左耳'),
            const SizedBox(width: 8),
            _legend(Colors.blue, '右耳'),
          ]),
      ]),
      const SizedBox(height: 8),
      // 编辑切换（仅编辑模式）
      if (widget.editable && widget.showBothEars)
        SegmentedButton<bool>(
          segments: const <ButtonSegment<bool>>[
            ButtonSegment<bool>(value: true, label: Text('编辑左耳')),
            ButtonSegment<bool>(value: false, label: Text('编辑右耳')),
          ],
          selected: <bool>{_editLeft},
          onSelectionChanged: (Set<bool> v) => setState(() => _editLeft = v.first),
        ),
      if (widget.editable) const SizedBox(height: 8),
      // 图表主体
      AspectRatio(
        aspectRatio: 1.05,
        child: LayoutBuilder(builder: (context, constraints) {
          return GestureDetector(
            onTapDown: widget.editable ? _handleTap : _handlePreviewTap,
            onPanUpdate: widget.editable ? _handlePan : null,
            onPanEnd: widget.editable ? (_) => setState(() => _touchPos = null) : null,
            child: CustomPaint(
              size: Size(constraints.maxWidth, constraints.maxHeight),
              painter: _AudiogramPainter(
                leftPoints: widget.leftPoints,
                rightPoints: widget.rightPoints,
                touchPos: _touchPos,
                tooltipText: _tooltipText,
              ),
            ),
          );
        }),
      ),
      const SizedBox(height: 4),
      // 提示文字
      Text(
        widget.editable
            ? '点击或拖拽图表放置 ${_editLeft ? '左耳' : '右耳'} 点，长按可删除已有频率点'
            : '点击查看最近点数值',
        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
      ),
    ]);
  }

  Widget _legend(Color color, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 12, height: 3, color: color),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ]);

  void _handleTap(TapDownDetails d) {
    _placePoint(d.localPosition);
  }

  void _handlePan(DragUpdateDetails d) {
    _placePoint(d.localPosition);
  }

  void _placePoint(Offset localPos) {
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final Size size = box.size;
    final _ChartMetrics m = _ChartMetrics(size);

    // 找到最近的频率列
    final int freq = _nearestFreq(m.freqFromX(localPos.dx));
    // 找到最近的 dB（5 的倍数，范围 0-120）
    final int db = _nearestDb(m.dbFromY(localPos.dy));

    // 同一频率只保留一个点（覆盖）
    final List<AudiogramPoint> list = _editLeft ? _currentLeft : _currentRight;
    list.removeWhere((p) => p.freq == freq);
    list.add(AudiogramPoint(freq: freq, db: db));
    list.sort((a, b) => a.freq.compareTo(b.freq));

    if (_editLeft) {
      widget.onLeftChanged?.call(list);
    } else {
      widget.onRightChanged?.call(list);
    }

    setState(() {
      _touchPos = localPos;
      _tooltipText = '${_editLeft ? '左耳' : '右耳'} ${freq}Hz: ${db}dB';
    });
  }

  void _handlePreviewTap(TapDownDetails d) {
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final Size size = box.size;
    final _ChartMetrics m = _ChartMetrics(size);
    final int freq = _nearestFreq(m.freqFromX(d.localPosition.dx));
    final int db = _nearestDb(m.dbFromY(d.localPosition.dy));

    // 找左右耳最近点
    AudiogramPoint? nearestLeft = _findNearest(widget.leftPoints, freq, db);
    AudiogramPoint? nearestRight = _findNearest(widget.rightPoints, freq, db);

    String text = '';
    if (nearestLeft != null && nearestRight != null) {
      final int dl = (nearestLeft.db - db).abs() + (nearestLeft.freq - freq).abs() ~/ 100;
      final int dr = (nearestRight.db - db).abs() + (nearestRight.freq - freq).abs() ~/ 100;
      final AudiogramPoint p = dl <= dr ? nearestLeft : nearestRight;
      text = '${p == nearestLeft ? '左耳' : '右耳'} ${p.freq}Hz: ${p.db}dB';
    } else if (nearestLeft != null) {
      text = '左耳 ${nearestLeft.freq}Hz: ${nearestLeft.db}dB';
    } else if (nearestRight != null) {
      text = '右耳 ${nearestRight.freq}Hz: ${nearestRight.db}dB';
    } else {
      text = '无数据';
    }

    setState(() {
      _touchPos = d.localPosition;
      _tooltipText = text;
    });
  }

  AudiogramPoint? _findNearest(List<AudiogramPoint> points, int freq, int db) {
    if (points.isEmpty) return null;
    AudiogramPoint? best;
    int bestDist = 999999;
    for (final p in points) {
      final int dist = (p.freq - freq).abs() + (p.db - db).abs() * 50;
      if (dist < bestDist) {
        bestDist = dist;
        best = p;
      }
    }
    return best;
  }

  static int _nearestFreq(double f) {
    int best = AudiogramChart.frequencies.first;
    double bestDiff = double.infinity;
    for (final int freq in AudiogramChart.frequencies) {
      final double diff = (freq - f).abs().toDouble();
      if (diff < bestDiff) {
        bestDiff = diff;
        best = freq;
      }
    }
    return best;
  }

  static int _nearestDb(double d) {
    int v = (d / 5).round() * 5;
    if (v < 0) v = 0;
    if (v > 120) v = 120;
    return v;
  }
}

/// 图表几何计算。
class _ChartMetrics {
  _ChartMetrics(this.size);
  final Size size;

  final EdgeInsets padding = const EdgeInsets.fromLTRB(42, 16, 16, 32);

  Rect get plotRect => Rect.fromLTRB(
        padding.left,
        padding.top,
        size.width - padding.right,
        size.height - padding.bottom,
      );

  double get plotWidth => plotRect.width;
  double get plotHeight => plotRect.height;

  double xForFreq(int freq) {
    final int idx = AudiogramChart.frequencies.indexOf(freq);
    if (idx < 0) return plotRect.left;
    return plotRect.left + plotWidth * idx / (AudiogramChart.frequencies.length - 1);
  }

  double yForDb(int db) {
    // 0 dB 在顶部，120 在底部
    return plotRect.top + plotHeight * (db / 120.0);
  }

  double freqFromX(double x) {
    final double t = (x - plotRect.left) / plotWidth;
    final double clamped = t.clamp(0.0, 1.0);
    final int maxIdx = AudiogramChart.frequencies.length - 1;
    final double idx = clamped * maxIdx;
    final int lower = idx.floor();
    final int upper = idx.ceil();
    if (lower == upper) return AudiogramChart.frequencies[lower].toDouble();
    final double frac = idx - lower;
    return AudiogramChart.frequencies[lower] +
        (AudiogramChart.frequencies[upper] - AudiogramChart.frequencies[lower]) * frac;
  }

  double dbFromY(double y) {
    final double t = (y - plotRect.top) / plotHeight;
    final double clamped = t.clamp(0.0, 1.0);
    return clamped * 120.0;
  }
}

class _AudiogramPainter extends CustomPainter {
  const _AudiogramPainter({
    required this.leftPoints,
    required this.rightPoints,
    this.touchPos,
    this.tooltipText,
  });

  final List<AudiogramPoint> leftPoints;
  final List<AudiogramPoint> rightPoints;
  final Offset? touchPos;
  final String? tooltipText;

  @override
  void paint(Canvas canvas, Size size) {
    final _ChartMetrics m = _ChartMetrics(size);
    final Paint gridPaint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 0.8;
    final Paint axisPaint = Paint()
      ..color = Colors.black54
      ..strokeWidth = 1.0;

    // 背景
    canvas.drawRect(m.plotRect, Paint()..color = Colors.white);

    // 横轴网格线：每 10 dB 一条
    for (int db = 0; db <= 120; db += 10) {
      final double y = m.yForDb(db);
      final Paint linePaint = Paint()
        ..color = Colors.grey.shade300
        ..strokeWidth = db % 20 == 0 ? 1.0 : 0.6;
      canvas.drawLine(
        Offset(m.plotRect.left, y),
        Offset(m.plotRect.right, y),
        linePaint,
      );
    }

    // 纵轴网格线：5 个频率
    for (final int freq in AudiogramChart.frequencies) {
      final double x = m.xForFreq(freq);
      canvas.drawLine(
        Offset(x, m.plotRect.top),
        Offset(x, m.plotRect.bottom),
        gridPaint..strokeWidth = 1.0,
      );
    }

    // 边框
    canvas.drawRect(m.plotRect, axisPaint..style = PaintingStyle.stroke);

    // 折线
    _drawLine(canvas, m, leftPoints, Colors.red);
    _drawLine(canvas, m, rightPoints, Colors.blue);

    // 点
    for (final p in leftPoints) {
      _drawPoint(canvas, m.xForFreq(p.freq), m.yForDb(p.db), Colors.red, '×');
    }
    for (final p in rightPoints) {
      _drawPoint(canvas, m.xForFreq(p.freq), m.yForDb(p.db), Colors.blue, '○');
    }

    // 坐标轴标签
    _drawLabels(canvas, m);

    // 触摸提示
    if (touchPos != null && tooltipText != null) {
      _drawTooltip(canvas, touchPos!, tooltipText!);
    }
  }

  void _drawLine(Canvas canvas, _ChartMetrics m, List<AudiogramPoint> points, Color color) {
    if (points.length < 2) return;
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    final Path path = Path();
    bool first = true;
    for (final p in points..sort((a, b) => a.freq.compareTo(b.freq))) {
      final Offset o = Offset(m.xForFreq(p.freq), m.yForDb(p.db));
      if (first) {
        path.moveTo(o.dx, o.dy);
        first = false;
      } else {
        path.lineTo(o.dx, o.dy);
      }
    }
    canvas.drawPath(path, paint);
  }

  void _drawPoint(Canvas canvas, double x, double y, Color color, String label) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(Offset(x, y), 5, paint);

    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(canvas, Offset(x - tp.width / 2, y - 14));
  }

  void _drawLabels(Canvas canvas, _ChartMetrics m) {
    // 纵轴 dB 标签（每 20 dB）
    for (int db = 0; db <= 120; db += 20) {
      final TextPainter tp = TextPainter(
        text: TextSpan(
          text: db.toString(),
          style: TextStyle(color: Colors.grey.shade700, fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, Offset(m.plotRect.left - tp.width - 4, m.yForDb(db) - tp.height / 2));
    }
    // 横轴 Hz 标签
    for (final int freq in AudiogramChart.frequencies) {
      final TextPainter tp = TextPainter(
        text: TextSpan(
          text: freq >= 1000 ? '${freq ~/ 1000}K' : freq.toString(),
          style: TextStyle(color: Colors.grey.shade700, fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas,
          Offset(m.xForFreq(freq) - tp.width / 2, m.plotRect.bottom + 4));
    }
    // 单位标签
    final TextPainter unitTp = TextPainter(
      text: TextSpan(
        text: 'dB',
        style: TextStyle(color: Colors.grey.shade700, fontSize: 10),
      ),
      textDirection: TextDirection.ltr,
    );
    unitTp.layout();
    unitTp.paint(canvas, Offset(4, m.plotRect.top - 4));
  }

  void _drawTooltip(Canvas canvas, Offset pos, String text) {
    const TextStyle style = TextStyle(color: Colors.white, fontSize: 12);
    final TextPainter tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    final Rect rect = Rect.fromLTWH(
      pos.dx + 8,
      pos.dy - 28,
      tp.width + 12,
      tp.height + 8,
    );
    final RRect rrect = RRect.fromRectAndRadius(rect, const Radius.circular(4));
    canvas.drawRRect(rrect, Paint()..color = Colors.black87);
    tp.paint(canvas, Offset(rect.left + 6, rect.top + 4));
  }

  @override
  bool shouldRepaint(covariant _AudiogramPainter oldDelegate) => true;
}
