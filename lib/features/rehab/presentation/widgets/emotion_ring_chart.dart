import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 孤独症儿童情绪行为表现图（同心圆环，Flutter 版）
///
/// 严格对照 图表模板/emotion-ring.html 的视觉与交互：
/// - 外圈 52 格 × 内外两环，共 104 个小格子
/// - 单击格子选中（变深色）/ 取消；按住拖动可连续涂抹
/// - 外圈带 1–52 编号和 7 个分类标签
/// - 导出由外层 RepaintBoundary 统一捕获（黑白样式）
class EmotionRingChart extends StatefulWidget {
  const EmotionRingChart({
    super.key,
    this.value,
    this.onChanged,
    this.editable = true,
    this.minWidth = 560,
  });

  final Set<String>? value; // key: "i-o"(外环) / "i-i"(内环), i 为 1..52
  final ValueChanged<Set<String>>? onChanged;
  final bool editable;
  final double minWidth;

  @override
  State<EmotionRingChart> createState() => _EmotionRingChartState();
}

const int _N = 52;
const double _CX = 500;
const double _CY = 560;
const double _R_OUT = 330;
const double _R_MID = 262;
const double _R_IN = 195;
const double _R_NUM = 296;
const double _R_BRK = 346;
const double _R_LBL = 380;
const double _STEP = 360 / _N;
const double _W = 1000;
const double _H = 1080;

const List<_Cat> _cats = <_Cat>[
  _Cat('依附情绪行为', 52, 3),
  _Cat('情绪理解', 3, 9),
  _Cat('情绪表达与调节', 9, 17),
  _Cat('关系与情感', 17, 25),
  _Cat('对物品的兴趣', 25, 36),
  _Cat('感觉偏好', 36, 42),
  _Cat('特殊行为', 42, 52),
];

class _Cat {
  const _Cat(this.label, this.start, this.end);
  final String label;
  final int start;
  final int end;
}

List<double> _polar(double r, double deg) {
  final double a = deg * math.pi / 180;
  return <double>[_CX + r * math.sin(a), _CY - r * math.cos(a)];
}

/// 返回某个格子的扇形路径（用于 hit-test 不必要，这里仅供绘制）。
Path _sectorPath(double r0, double r1, double a0, double a1) {
  final List<double> p0 = _polar(r1, a0);
  final List<double> p1 = _polar(r1, a1);
  final List<double> p2 = _polar(r0, a1);
  final List<double> p3 = _polar(r0, a0);
  final bool large = (a1 - a0) > 180;
  final Path path = Path();
  path.moveTo(p0[0], p0[1]);
  path.arcToPoint(Offset(p1[0], p1[1]),
      radius: Radius.circular(r1), rotation: 0, largeArc: large, clockwise: true);
  path.lineTo(p2[0], p2[1]);
  path.arcToPoint(Offset(p3[0], p3[1]),
      radius: Radius.circular(r0), rotation: 0, largeArc: large, clockwise: false);
  path.close();
  return path;
}

class _EmotionRingChartState extends State<EmotionRingChart> {
  late Set<String> _selected;
  bool _painting = false;
  bool _paintState = false;

  @override
  void initState() {
    super.initState();
    _selected = Set<String>.from(widget.value ?? <String>{});
  }

  @override
  void didUpdateWidget(covariant EmotionRingChart old) {
    super.didUpdateWidget(old);
    if (widget.value != null && widget.value != old.value) {
      _selected = Set<String>.from(widget.value!);
    }
  }

  void _emit() => widget.onChanged?.call(_selected);

  /// 将点击坐标（viewBox 坐标系）映射到格子 key，返回 null 表示不在环内。
  String? _hitTest(double x, double y) {
    final double dx = x - _CX;
    final double dy = _CY - y;
    final double deg = math.atan2(dx, dy) * 180 / math.pi;
    final double r = math.sqrt(dx * dx + dy * dy);
    if (r < _R_IN - 12 || r > _R_OUT + 12) return null;
    double d = deg;
    while (d < 0) {
      d += 360;
    }
    while (d >= 360) {
      d -= 360;
    }
    final int i = (d / _STEP).floor() + 1;
    final int idx = i.clamp(1, _N);
    final String ring = (r >= _R_MID) ? 'o' : 'i';
    return '$idx-$ring';
  }

  void _setCell(String key, bool on) {
    final bool changed = on ? !_selected.contains(key) : _selected.contains(key);
    if (!changed) return;
    setState(() {
      if (on) {
        _selected.add(key);
      } else {
        _selected.remove(key);
      }
    });
    _emit();
  }

  void _handleDown(Offset local, double scale) {
    if (!widget.editable) return;
    final String? key = _hitTest(local.dx / scale, local.dy / scale);
    if (key == null) return;
    _painting = true;
    _paintState = !_selected.contains(key);
    _setCell(key, _paintState);
  }

  void _handleMove(Offset local, double scale) {
    if (!_painting || !widget.editable) return;
    final String? key = _hitTest(local.dx / scale, local.dy / scale);
    if (key == null) return;
    _setCell(key, _paintState);
  }

  void _handleUp() => _painting = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final double width = math.max(constraints.maxWidth, widget.minWidth);
        final double scale = width / _W;
        final double height = _H * scale;
        final Widget chart = GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanDown: (d) => _handleDown(d.localPosition, scale),
          onPanUpdate: (d) => _handleMove(d.localPosition, scale),
          onPanEnd: (_) => _handleUp(),
          onPanCancel: _handleUp,
          child: CustomPaint(
            size: Size(width, height),
            painter: _RingPainter(_selected),
          ),
        );
        final Widget body = width > constraints.maxWidth
            ? SingleChildScrollView(scrollDirection: Axis.horizontal, child: chart)
            : chart;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (widget.editable)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    TextButton.icon(
                      onPressed: () {
                        setState(() => _selected.clear());
                        _emit();
                      },
                      icon: const Icon(Icons.cleaning_services, size: 16),
                      label: const Text('清除全部选中'),
                    ),
                    Text('已选 ${_selected.length} 格',
                        style: const TextStyle(fontSize: 12)),
                    const Text(
                      '点击小格选中/取消；按住拖动可连续涂抹。',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            Container(color: Colors.white, child: body),
          ],
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.selected);
  final Set<String> selected;

  void _text(Canvas c, double x, double y, String s, double fs,
      {String anchor = 'middle', Color fill = Colors.black, double? rot}) {
    final TextPainter tp = TextPainter(
      text: TextSpan(text: s, style: TextStyle(fontSize: fs, color: fill)),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();
    c.save();
    if (rot != null) c.translate(x, y);
    final double dx = rot != null ? -tp.width / 2 : (anchor == 'middle' ? x - tp.width / 2 : x);
    final double dy = rot != null ? -tp.height / 2 : (y - tp.height);
    if (rot != null) c.rotate(rot * math.pi / 180);
    tp.paint(c, Offset(dx, dy));
    c.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final double scale = size.width / _W;
    canvas.save();
    canvas.scale(scale, scale);

    canvas.drawRect(const Rect.fromLTWH(0, 0, _W, _H),
        Paint()..color = Colors.white);
    _text(canvas, _W / 2, 58, '孤独症儿童情绪行为表现图', 30, anchor: 'middle');

    // 格子
    final Paint cellStroke = Paint()
      ..color = Colors.black38
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (int idx = 0; idx < _N; idx++) {
      final int i = idx + 1;
      final double a0 = (i - 1) * _STEP;
      final double a1 = i * _STEP;
      final String outerKey = '$i-o';
      final String innerKey = '$i-i';
      final Path outer = _sectorPath(_R_MID, _R_OUT, a0, a1);
      canvas.drawPath(
        outer,
        Paint()
          ..color = selected.contains(outerKey) ? Colors.black : Colors.white
          ..style = PaintingStyle.fill,
      );
      canvas.drawPath(outer, cellStroke);
      final Path inner = _sectorPath(_R_IN, _R_MID, a0, a1);
      canvas.drawPath(
        inner,
        Paint()
          ..color = selected.contains(innerKey) ? Colors.black : Colors.white
          ..style = PaintingStyle.fill,
      );
      canvas.drawPath(inner, cellStroke);
    }

    // 编号
    for (int idx = 0; idx < _N; idx++) {
      final int i = idx + 1;
      final double am = (i - 0.5) * _STEP;
      final List<double> p = _polar(_R_NUM, am);
      final bool outerOn = selected.contains('$i-o');
      _text(canvas, p[0], p[1], '$i', 13,
          rot: am, fill: outerOn ? Colors.white : Colors.black);
    }

    // 分类括弧与文字
    final Paint catStroke = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (final _Cat c in _cats) {
      double a0 = (c.start - 1) * _STEP + 0.7;
      double a1 = c.end * _STEP - 0.7;
      if (c.end < c.start) a1 += 360;
      final List<double> b0 = _polar(_R_BRK, a0);
      final List<double> b1 = _polar(_R_BRK, a1);
      final Path arc = Path();
      arc.moveTo(b0[0], b0[1]);
      arc.arcToPoint(Offset(b1[0], b1[1]),
          radius: Radius.circular(_R_BRK), rotation: 0, largeArc: false, clockwise: true);
      canvas.drawPath(arc, catStroke);
      // 括弧端点小横线
      for (final double a in <double>[a0, a1]) {
        final List<double> e0 = _polar(_R_BRK - 7, a);
        final List<double> e1 = _polar(_R_BRK + 7, a);
        canvas.drawLine(Offset(e0[0], e0[1]), Offset(e1[0], e1[1]), catStroke);
      }
      final double am = (a0 + a1) / 2;
      final List<double> lp = _polar(_R_LBL, am);
      final double rot = ((am % 360) + 360) % 360;
      _text(canvas, lp[0], lp[1], c.label, 21, rot: rot);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.selected != selected;
}
