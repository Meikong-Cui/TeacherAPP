import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 孤独症儿童发展情况剖面图（Flutter 版）
///
/// 严格对照 图表模板/development-profile.html 的视觉与交互：
/// - 8 根领域竖线（感知觉、粗大动作、精细动作、语言沟通、认知、社交、自理、发展分数）
/// - 左右两侧月龄 / 年龄双轴（0–84 月 = 0–7 岁）
/// - 每根竖线上绘制固定参考项目编号点（ellipse + 数字）
/// - 点击竖线放置 / 移动评估点；再次点击已有点附近可删除
/// - 相邻两根竖线都有点时自动连线
/// - 底部 P 得分（8 格）/ E 得分（7 格）：点击方框输入数字
/// - 导出时由外层 RepaintBoundary 统一捕获（黑白样式）
class DevelopmentProfileChart extends StatefulWidget {
  const DevelopmentProfileChart({
    super.key,
    this.value,
    this.onChanged,
    this.editable = true,
    this.minWidth = 820,
  });

  final DevelopmentProfileData? value;
  final ValueChanged<DevelopmentProfileData>? onChanged;
  final bool editable;
  final double minWidth;

  @override
  State<DevelopmentProfileChart> createState() => _DevelopmentProfileChartState();
}

/// 剖面图的可序列化数据。
class DevelopmentProfileData {
  const DevelopmentProfileData({
    this.points = const <double?>[null, null, null, null, null, null, null, null],
    this.scoresP = const <String>['', '', '', '', '', '', '', ''],
    this.scoresE = const <String>['', '', '', '', '', '', ''],
  });

  final List<double?> points; // 8 列，每列一个月龄或 null
  final List<String> scoresP; // 8 格
  final List<String> scoresE; // 7 格

  DevelopmentProfileData copyWith({
    List<double?>? points,
    List<String>? scoresP,
    List<String>? scoresE,
  }) =>
      DevelopmentProfileData(
        points: points ?? this.points,
        scoresP: scoresP ?? this.scoresP,
        scoresE: scoresE ?? this.scoresE,
      );
}

const List<String> _dpDomains = <String>[
  '感知觉',
  '粗大动作',
  '精细动作',
  '语言沟通',
  '认知',
  '社交',
  '自理',
  '发展分数',
];

// 每根竖线上的项目编号及其大致发展年龄（月），与 HTML 模板一致。
const List<List<List<double>>> _dpItems = <List<List<double>>>[
  [
    [55, 68], [52, 57], [47, 49], [44, 43], [40, 38], [37, 34], [36, 32],
    [29, 26], [27, 22], [21, 17], [19, 13], [16, 11], [10, 8], [5, 6],
    [2, 4], [1, 2], [0, 1]
  ],
  [
    [72, 71], [65, 58], [64, 55], [47, 49], [46, 45], [35, 40], [34, 32],
    [24, 29], [22, 23.5], [21, 22], [19, 18], [7, 15], [6, 13.5], [5, 12], [0, 9]
  ],
  [
    [66, 65], [63, 59], [62, 58], [51, 56.5], [50, 55], [49, 50], [48, 47.5],
    [47, 45.5], [39, 43.5], [35, 38], [34, 36], [33, 31], [24, 28], [23, 26],
    [22, 25], [21, 24], [20, 23], [11, 17], [9, 15.5], [4, 14], [3, 13],
    [2, 12], [1, 11], [0, 10], [18, 9], [8, 8], [6, 7], [2, 6], [1, 5], [0, 4]
  ],
  [
    [79, 72], [76, 56], [67, 44], [53, 34], [52, 32], [36, 26], [27, 16],
    [21, 14.5], [18, 9], [8, 8], [6, 7], [1, 6], [0, 5], [6, 4], [2, 3], [0, 1]
  ],
  [
    [55, 71], [50, 67], [42, 57], [30, 45], [20, 34], [10, 26], [9, 23],
    [5, 21], [4, 19], [2, 17.5], [1, 16], [0, 14]
  ],
  [
    [47, 68], [45, 62], [40, 45], [30, 35], [24, 25], [19, 22.5], [15, 19],
    [14, 17], [11, 10], [4, 6], [1, 3.7], [0, 2], [2, 1.5], [1, 1], [0, 0.3]
  ],
  [
    [67, 71], [62, 57], [46, 45], [34, 34], [33, 32], [18, 28.5], [15, 23.5],
    [12, 20.5], [8, 19], [6, 17.5], [5, 16], [3, 14.5], [1, 12.7], [2, 4],
    [1, 2], [0, 0.5]
  ],
  [
    [441, 70], [421, 66], [416, 63], [405, 57], [330, 54], [329, 52],
    [328, 50.5], [323, 47], [312, 44.5], [254, 43], [253, 42], [249, 40.5],
    [248, 39.5], [244, 38.5], [243, 37], [234, 35.5], [192, 34], [167, 32.5],
    [163, 31], [160, 29.5], [153, 28], [152, 27], [149, 25.5], [123, 23],
    [95, 20.5], [93, 19], [79, 17.5], [75, 16], [68, 14.5], [62, 13],
    [58, 11.5], [51, 10], [39, 8.5], [27, 7], [25, 6], [18, 5], [16, 4],
    [9, 3], [8, 2.5], [4, 1.8], [1, 1], [0, 0.3]
  ],
];

const double _W = 1140;
const double _H = 1340;
const double _AXIS_L = 150;
const double _AXIS_R = 990;
const double _TOP = 180;
const double _BOTTOM = 1130;
const double _MAXM = 84;
const double _COL0 = 280;
const double _COLSTEP = (860 - 280) / 7;
const double _P_Y = 1210;
const double _E_Y = 1285;
const double _BOX = 44;

double _colX(int i) => _COL0 + i * _COLSTEP;
double _m2y(double m) => _BOTTOM - (m / _MAXM) * (_BOTTOM - _TOP);
double _y2m(double y) =>
    math.max(0, math.min(_MAXM, (_BOTTOM - y) * _MAXM / (_BOTTOM - _TOP)));

const Map<String, List<String>> _headSplit = <String, List<String>>{
  '粗大动作': <String>['粗大', '动作'],
  '精细动作': <String>['精细', '动作'],
  '语言沟通': <String>['语言', '沟通'],
  '发展分数': <String>['发展', '分数'],
};

class _DevelopmentProfileChartState extends State<DevelopmentProfileChart> {
  late DevelopmentProfileData _data;
  final GlobalKey _paintKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _data = widget.value ??
        const DevelopmentProfileData();
  }

  @override
  void didUpdateWidget(covariant DevelopmentProfileChart old) {
    super.didUpdateWidget(old);
    if (widget.value != null && widget.value != old.value) {
      _data = widget.value!;
    }
  }

  void _emit() => widget.onChanged?.call(_data);

  void _handleTap(Offset local, double scale) {
    if (!widget.editable) return;
    final double x = local.dx / scale;
    final double y = local.dy / scale;

    // 优先判断是否点中 P/E 得分框
    for (int i = 0; i < 8; i++) {
      if (_near(x, y, _colX(i), _P_Y)) {
        _editBox('P', i);
        return;
      }
    }
    for (int i = 0; i < 7; i++) {
      if (_near(x, y, _colX(i), _E_Y)) {
        _editBox('E', i);
        return;
      }
    }

    // 否则按列放置 / 移动 / 删除评估点
    int best = -1;
    double bestDist = 36;
    for (int i = 0; i < 8; i++) {
      final double d = (x - _colX(i)).abs();
      if (d < bestDist) {
        bestDist = d;
        best = i;
      }
    }
    if (best < 0 || y < _TOP - 20 || y > _BOTTOM + 20) return;

    final List<double?> pts = List<double?>.from(_data.points);
    if (pts[best] != null && (_m2y(pts[best]!) - y).abs() < 14) {
      pts[best] = null; // 删除
    } else {
      pts[best] = _y2m(y).roundToDouble(); // 放置 / 移动
    }
    setState(() => _data = _data.copyWith(points: pts));
    _emit();
  }

  bool _near(double x, double y, double cx, double cy) =>
      (x - cx).abs() < _BOX * 0.6 && (y - cy).abs() < _BOX * 0.6;

  Future<void> _editBox(String kind, int idx) async {
    final TextEditingController ctl = TextEditingController(
      text: kind == 'P' ? _data.scoresP[idx] : _data.scoresE[idx],
    );
    final String? res = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(kind == 'P' ? 'P 得分（${_dpDomains[idx]}）' : 'E 得分'),
        content: TextField(
          controller: ctl,
          keyboardType: TextInputType.number,
          maxLength: 4,
          autofocus: true,
          decoration: const InputDecoration(hintText: '输入数字'),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctl.text),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (res == null) return;
    final String cleaned = res.replaceAll(RegExp(r'[^0-9]'), '');
    if (kind == 'P') {
      final List<String> p = List<String>.from(_data.scoresP);
      p[idx] = cleaned;
      setState(() => _data = _data.copyWith(scoresP: p));
    } else {
      final List<String> e = List<String>.from(_data.scoresE);
      e[idx] = cleaned;
      setState(() => _data = _data.copyWith(scoresE: e));
    }
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final double width = math.max(constraints.maxWidth, widget.minWidth);
        final double scale = width / _W;
        final double height = _H * scale;
        final Widget chart = GestureDetector(
          onTapDown: (d) => _handleTap(d.localPosition, scale),
          child: CustomPaint(
            key: _paintKey,
            size: Size(width, height),
            painter: _DPPainter(_data),
          ),
        );
        final Widget body = width > constraints.maxWidth
            ? SingleChildScrollView(
                scrollDirection: Axis.horizontal, child: chart)
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
                        setState(() => _data = const DevelopmentProfileData());
                        _emit();
                      },
                      icon: const Icon(Icons.cleaning_services, size: 16),
                      label: const Text('清除所有点'),
                    ),
                    const Text(
                      '单击竖线放置/移动评估点，再次点击已有点可删除；点击下方方框填写 P/E 得分。',
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

class _DPPainter extends CustomPainter {
  _DPPainter(this.data);
  final DevelopmentProfileData data;

  static final Paint _black = Paint()..color = Colors.black;
  static final Paint _blackFill = Paint()..color = Colors.black;
  static final Paint _whiteFill = Paint()..color = Colors.white;

  void _text(Canvas c, double x, double y, String s, double fs,
      {String anchor = 'start', Color fill = Colors.black}) {
    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(fontSize: fs, color: fill),
      ),
      textDirection: TextDirection.ltr,
      textAlign: anchor == 'middle'
          ? TextAlign.center
          : (anchor == 'end' ? TextAlign.right : TextAlign.left),
    )..layout();
    final double dx = anchor == 'middle'
        ? x - tp.width / 2
        : (anchor == 'end' ? x - tp.width : x);
    tp.paint(c, Offset(dx, y - tp.height));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final double scale = size.width / _W;
    canvas.save();
    canvas.scale(scale, scale);

    // 白底
    canvas.drawRect(const Rect.fromLTWH(0, 0, _W, _H), _whiteFill);

    // 标题
    _text(canvas, _W / 2, 55, '孤独症儿童发展情况剖面图', 30,
        anchor: 'middle');

    // 表头
    _text(canvas, 120, 92, '发展年龄', 16, anchor: 'middle');
    _text(canvas, 122, 122, '月', 14, anchor: 'middle');
    _text(canvas, 170, 122, '年', 14, anchor: 'middle');
    _text(canvas, 1020, 92, '发展年龄', 16, anchor: 'middle');
    _text(canvas, 968, 122, '年', 14, anchor: 'middle');
    _text(canvas, 1020, 122, '月', 14, anchor: 'middle');

    for (int i = 0; i < _dpDomains.length; i++) {
      final String d = _dpDomains[i];
      if (_headSplit.containsKey(d)) {
        _text(canvas, _colX(i), 92, _headSplit[d]![0], 16, anchor: 'middle');
        _text(canvas, _colX(i), 122, _headSplit[d]![1], 16, anchor: 'middle');
      } else {
        _text(canvas, _colX(i), 108, d, 16, anchor: 'middle');
      }
    }

    // 左右年龄轴
    final Paint axisPaint = Paint()..color = Colors.black..strokeWidth = 1;
    for (final double ax in const <double>[_AXIS_L, _AXIS_R]) {
      canvas.drawLine(Offset(ax, _TOP), Offset(ax, _BOTTOM), axisPaint);
      for (int m = 0; m <= _MAXM; m += 2) {
        final double len = (m % 12 == 0) ? 15 : 8;
        final double dir = (ax == _AXIS_L) ? -1 : 1;
        canvas.drawLine(Offset(ax, _m2y(m.toDouble())),
            Offset(ax + dir * len, _m2y(m.toDouble())), axisPaint);
      }
    }
    for (int m = 12; m <= 72; m += 12) {
      _text(canvas, _AXIS_L - 22, _m2y(m.toDouble()) + 5, '$m', 14,
          anchor: 'end');
      _text(canvas, _AXIS_L + 22, _m2y(m.toDouble()) + 5, '${m / 12}', 14,
          anchor: 'start');
      _text(canvas, _AXIS_R + 22, _m2y(m.toDouble()) + 5, '$m', 14,
          anchor: 'start');
      _text(canvas, _AXIS_R - 22, _m2y(m.toDouble()) + 5, '${m / 12}', 14,
          anchor: 'end');
    }
    _text(canvas, _AXIS_L + 22, _TOP - 8, '7', 14, anchor: 'start');
    _text(canvas, _AXIS_R - 22, _TOP - 8, '7', 14, anchor: 'end');

    // 8 根竖线与项目编号
    final Paint linePaint = Paint()..color = Colors.black..strokeWidth = 1;
    for (int i = 0; i < 8; i++) {
      canvas.drawLine(
          Offset(_colX(i), _TOP), Offset(_colX(i), _BOTTOM), linePaint);
      for (final List<double> it in _dpItems[i]) {
        final double cy = _m2y(it[1]);
        canvas.drawOval(
          Rect.fromCenter(
              center: Offset(_colX(i), cy), width: 9, height: 16),
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.fill,
        );
        canvas.drawOval(
          Rect.fromCenter(
              center: Offset(_colX(i), cy), width: 9, height: 16),
          Paint()
            ..color = Colors.black
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
        _text(canvas, _colX(i) + 10, cy + 4, it[0].toInt().toString(), 11);
      }
    }

    // 底部得分框
    _text(canvas, _AXIS_L - 25, _P_Y + 6, 'P得分', 16, anchor: 'end');
    _text(canvas, _AXIS_R + 25, _P_Y + 6, 'P得分', 16, anchor: 'start');
    _text(canvas, _AXIS_L - 25, _E_Y + 6, 'E得分', 16, anchor: 'end');

    final Paint boxPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (int i = 0; i < 8; i++) {
      canvas.drawRect(
        Rect.fromCenter(center: Offset(_colX(i), _P_Y), width: _BOX, height: _BOX),
        boxPaint,
      );
      _text(canvas, _colX(i), _P_Y + 7, data.scoresP[i], 18, anchor: 'middle');
    }
    for (int i = 0; i < 7; i++) {
      canvas.drawRect(
        Rect.fromCenter(center: Offset(_colX(i), _E_Y), width: _BOX, height: _BOX),
        boxPaint,
      );
      _text(canvas, _colX(i), _E_Y + 7, data.scoresE[i], 18, anchor: 'middle');
    }

    // 评估点与折线
    final Paint connectPaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    for (int i = 0; i < 7; i++) {
      if (data.points[i] != null && data.points[i + 1] != null) {
        canvas.drawLine(
          Offset(_colX(i), _m2y(data.points[i]!)),
          Offset(_colX(i + 1), _m2y(data.points[i + 1]!)),
          connectPaint,
        );
      }
    }
    for (int i = 0; i < 8; i++) {
      if (data.points[i] == null) continue;
      final double y = _m2y(data.points[i]!);
      canvas.drawOval(
        Rect.fromCenter(center: Offset(_colX(i), y), width: 22, height: 28),
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill,
      );
      canvas.drawOval(
        Rect.fromCenter(center: Offset(_colX(i), y), width: 22, height: 28),
        Paint()
          ..color = Colors.black
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
      canvas.drawCircle(Offset(_colX(i), y), 4.5, _blackFill);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _DPPainter old) => old.data != data;
}
