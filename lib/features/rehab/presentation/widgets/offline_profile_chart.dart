import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 孤独症儿童发展情况剖面图（线下模板 OFFLINE 专用，Flutter 版）
///
/// 严格对标 OA 网页 OfflineProfileChart（图表模板/offline-profile.html）：
/// - 8 根竖线：模仿 / 知觉 / 精细动作 / 粗大动作 / 手眼协调 / 认知表现 / 口语认知 / 发展评分
/// - 0–84 月（0–7 岁）双侧月龄 / 年龄轴
/// - 每根竖线上的项目编号 + 大致发展月龄（固定参考点）
/// - 评估点：得分比例 → 发展月龄（auto 模式，按 score/fullScore 推算）
/// - 相邻两根竖线都有点时自动连线
class OfflineProfileChart extends StatelessWidget {
  const OfflineProfileChart({
    super.key,
    required this.scores, // 8 元素 [score, fullScore]，null 表示该列无数据
    this.childName,
    this.footer,
    this.minWidth = 820,
  });

  final List<OfflineProfileScore?> scores;
  final String? childName;
  final String? footer;
  final double minWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final double width = math.max(constraints.maxWidth, minWidth);
        final double scale = width / _W;
        final double height = _H * scale;
        final Widget chart = Container(
          color: Colors.white,
          child: CustomPaint(
            size: Size(width, height),
            painter: _OPPainter(scores, childName, footer),
          ),
        );
        return width > constraints.maxWidth
            ? SingleChildScrollView(scrollDirection: Axis.horizontal, child: chart)
            : chart;
      },
    );
  }
}

class OfflineProfileScore {
  const OfflineProfileScore({required this.score, required this.fullScore});
  final double score;
  final double fullScore;
}

const List<String> _opDomains = <String>[
  '模仿',
  '知觉',
  '精细动作',
  '粗大动作',
  '手眼协调',
  '认知表现',
  '口语认知',
  '发展评分',
];

// 每根竖线上的项目编号及其大致发展年龄（月）。发展评分列：85~0 对应 0..76.5 月。
const List<List<List<double>>> _opItems = <List<List<double>>>[
  [
    [12, 75], [10, 39], [9, 37], [8, 34], [7, 32], [6, 29], [5, 27],
    [4, 24], [3, 21], [2, 19], [1, 11], [0, 9]
  ],
  [
    [11, 60], [10, 51], [9, 48.5], [8, 44], [7, 39.5], [6, 35], [5, 32.5],
    [4, 28], [3, 21], [2, 18.5], [1, 13.5], [0, 6]
  ],
  [
    [10, 71.5], [9, 53.5], [8, 44], [7, 41.5], [6, 39], [5, 34.5], [4, 32],
    [3, 29.5], [2, 27], [1, 22], [0, 17]
  ],
  [
    [11, 60], [10, 41.5], [9, 39.5], [8, 37], [7, 34.5], [6, 32], [5, 28],
    [4, 25.5], [3, 20.5], [2, 18], [1, 15.5], [0, 13]
  ],
  [
    [14, 69], [13, 67], [12, 62], [11, 57.5], [10, 53], [9, 48.5], [8, 42],
    [7, 39.5], [6, 34.5], [5, 28], [4, 23], [3, 18], [2, 15.5], [1, 10.5], [0, 8]
  ],
  [
    [20, 75], [19, 71], [18, 68.5], [17, 66], [16, 62], [15, 57.5], [14, 53],
    [13, 48.5], [12, 44], [11, 39.5], [10, 35], [9, 32.5], [8, 28], [7, 25.5],
    [6, 23], [5, 20.5], [4, 15.5], [3, 13], [2, 10.5], [1, 8], [0, 5.5]
  ],
  [
    [19, 77], [18, 72.5], [17, 70.5], [16, 66], [15, 62], [14, 60], [13, 53],
    [12, 48.5], [11, 46], [10, 44], [9, 39.5], [8, 35], [7, 32.5], [6, 28],
    [5, 23], [4, 20.5], [3, 15.5], [2, 13], [1, 10.5], [0, 8]
  ],
];
// 发展评分：85~0 均匀分布在 0..76.5 月高度上
final List<List<double>> _opScoreItems = <List<double>>[
  for (int s = 85; s >= 0; s--) <double>[s.toDouble(), s * 0.9]
];

// 各列参考题号圈的月龄区间（min, max）。评估点按本列得分比例映射到此区间内，
// 满分即落在最顶端题号圈（对齐参考刻度），而非统一按 84 月百分比，避免浮在列顶之上。
// 顺序：模仿 / 知觉 / 精细动作 / 粗大动作 / 手眼协调 / 认知表现 / 口语认知 / 发展评分
const List<List<double>> _opAgeRange = <List<double>>[
  <double>[9, 75], // 模仿
  <double>[6, 60], // 知觉
  <double>[17, 71.5], // 精细动作
  <double>[13, 60], // 粗大动作
  <double>[8, 69], // 手眼协调
  <double>[5.5, 75], // 认知表现
  <double>[8, 77], // 口语认知
  <double>[0, 76.5], // 发展评分
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

double _colX(int i) => _COL0 + i * _COLSTEP;
double _m2y(double m) => _BOTTOM - (m / _MAXM) * (_BOTTOM - _TOP);

/// 把某列得分比例映射到该列的参考月龄区间（min..max），
/// 使满分落在该列最顶端题号圈（对齐参考刻度），部分得分在列内月龄区间插值。
double _ratioToAge(double score, double fullScore, int col) {
  final List<double> range =
      col >= 0 && col < _opAgeRange.length ? _opAgeRange[col] : const <double>[0, _MAXM];
  if (fullScore <= 0) return range[0];
  final double r = math.max(0, math.min(1, score / fullScore));
  return range[0] + r * (range[1] - range[0]);
}

const Map<String, List<String>> _opHeadSplit = <String, List<String>>{
  '精细动作': <String>['精细', '动作'],
  '粗大动作': <String>['粗大', '动作'],
  '手眼协调': <String>['手眼', '协调'],
  '认知表现': <String>['认知', '表现'],
  '口语认知': <String>['口语', '认知'],
};

class _OPPainter extends CustomPainter {
  _OPPainter(this.scores, this.childName, this.footer);
  final List<OfflineProfileScore?> scores;
  final String? childName;
  final String? footer;

  static const Color _black = Colors.black;

  void _text(Canvas c, double x, double y, String s, double fs,
      {String anchor = 'start'}) {
    final TextPainter tp = TextPainter(
      text: TextSpan(text: s, style: TextStyle(fontSize: fs, color: _black)),
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

  /// 计算 8 列最终评估点（月龄），null 表示该列无点。
  List<double?> _finalPoints() {
    final List<double?> pts = <double?>[];
    for (int i = 0; i < 8; i++) {
      final OfflineProfileScore? s = i < scores.length ? scores[i] : null;
      if (s == null) {
        pts.add(null);
      } else {
        pts.add(_ratioToAge(s.score, s.fullScore, i));
      }
    }
    return pts;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final double scale = size.width / _W;
    canvas.save();
    canvas.scale(scale, scale);

    canvas.drawRect(const Rect.fromLTWH(0, 0, _W, _H),
        Paint()..color = Colors.white);

    // 标题
    _text(canvas, _W / 2, 55, '心理教育评估剖面图', 30, anchor: 'middle');
    if (childName != null && childName!.isNotEmpty) {
      _text(canvas, _W / 2, 82, '姓名：$childName', 14, anchor: 'middle');
    }

    // 表头：左右年龄 / 8 列名
    for (final double ax in const <double>[_AXIS_L, _AXIS_R]) {
      _text(canvas, ax, 92, '年龄', 16, anchor: 'middle');
      _text(canvas, ax, 122, '（岁）', 14, anchor: 'middle');
    }
    for (int i = 0; i < _opDomains.length; i++) {
      final String d = _opDomains[i];
      if (_opHeadSplit.containsKey(d)) {
        _text(canvas, _colX(i), 92, _opHeadSplit[d]![0], 16, anchor: 'middle');
        _text(canvas, _colX(i), 122, _opHeadSplit[d]![1], 16, anchor: 'middle');
      } else {
        _text(canvas, _colX(i), 108, d, 16, anchor: 'middle');
      }
    }

    // 左右月龄轴
    final Paint axisPaint = Paint()..color = _black..strokeWidth = 1;
    for (final double ax in const <double>[_AXIS_L, _AXIS_R]) {
      canvas.drawLine(Offset(ax, _TOP), Offset(ax, _BOTTOM), axisPaint);
      for (int m = 0; m <= _MAXM; m++) {
        final double len = m % 12 == 0 ? 15 : 7;
        final double dir = ax == _AXIS_L ? 1 : -1;
        canvas.drawLine(Offset(ax, _m2y(m.toDouble())),
            Offset(ax + dir * len, _m2y(m.toDouble())), axisPaint);
      }
    }
    for (int y = 0; y <= 7; y++) {
      final double yy = _m2y(y * 12) + 5;
      _text(canvas, _AXIS_L - 18, yy, '$y', 15, anchor: 'end');
      _text(canvas, _AXIS_R + 18, yy, '$y', 15, anchor: 'start');
    }

    // 8 根竖线 + 题号圈
    final Paint linePaint = Paint()..color = _black..strokeWidth = 1;
    for (int i = 0; i < 8; i++) {
      canvas.drawLine(
          Offset(_colX(i), _TOP), Offset(_colX(i), _BOTTOM), linePaint);
      final List<List<double>> items = i == 7 ? _opScoreItems : _opItems[i];
      for (final List<double> it in items) {
        final double cy = _m2y(it[1]);
        final bool isScore = i == 7;
        canvas.drawOval(
          Rect.fromCenter(
              center: Offset(_colX(i), cy),
              width: 9,
              height: isScore ? 11 : 16),
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.fill,
        );
        canvas.drawOval(
          Rect.fromCenter(
              center: Offset(_colX(i), cy),
              width: 9,
              height: isScore ? 11 : 16),
          Paint()
            ..color = _black
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
        _text(canvas, _colX(i) + 10, cy + 4, it[0].toInt().toString(),
            isScore ? 10 : 11);
      }
    }

    final List<double?> pts = _finalPoints();

    // 折线（相邻两根都有点时连线）
    final Paint connectPaint = Paint()
      ..color = _black
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    for (int i = 0; i < 7; i++) {
      if (pts[i] != null && pts[i + 1] != null) {
        canvas.drawLine(
          Offset(_colX(i), _m2y(pts[i]!)),
          Offset(_colX(i + 1), _m2y(pts[i + 1]!)),
          connectPaint,
        );
      }
    }

    // 评估点
    for (int i = 0; i < 8; i++) {
      if (pts[i] == null) continue;
      final double y = _m2y(pts[i]!);
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(_colX(i), y), width: 22, height: 28),
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill,
      );
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(_colX(i), y), width: 22, height: 28),
        Paint()
          ..color = _black
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
      canvas.drawCircle(Offset(_colX(i), y), 4.5,
          Paint()..color = _black);
    }

    // 底部说明
    if (footer != null && footer!.isNotEmpty) {
      _text(canvas, _W / 2, _BOTTOM + 30, footer!, 12,
          anchor: 'middle');
    }
    _text(canvas, _W / 2, _BOTTOM + 60,
        '评估点位置 = 各列得分比例 × 该列月龄区间（对齐题号圈）；发展评分列 = 总分比例 × 0–76.5 月', 11,
        anchor: 'middle');

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _OPPainter old) =>
      old.scores != scores ||
      old.childName != childName ||
      old.footer != footer;
}
