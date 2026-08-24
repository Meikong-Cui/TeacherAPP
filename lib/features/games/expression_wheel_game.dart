import 'dart:math';

import 'package:flutter/material.dart';
import 'package:teacher_app/features/games/game_shell.dart';

class _Face {
  const _Face(this.emoji, this.label);
  final String emoji;
  final String label;
}

const List<_Face> _kFaces = <_Face>[
  _Face('😊', '开心'),
  _Face('😢', '难过'),
  _Face('😠', '生气'),
  _Face('😲', '惊讶'),
  _Face('😨', '害怕'),
  _Face('🤢', '厌恶'),
  _Face('😴', '困了'),
  _Face('🤩', '兴奋'),
];

/// 表情大转盘（情绪表达）：旋转后指针指向的表情即为要做出的表情。
class ExpressionWheelGame extends StatefulWidget {
  const ExpressionWheelGame({super.key});

  @override
  State<ExpressionWheelGame> createState() => _ExpressionWheelGameState();
}

class _ExpressionWheelGameState extends State<ExpressionWheelGame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  final Random _rand = Random();
  double _angle = 0;
  double _targetAngle = 0;
  int? _result;
  bool _spinning = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 3));
    _ctrl.addListener(() {
      if (mounted) setState(() => _angle = _ctrl.value * _targetAngle);
    });
    _ctrl.addStatusListener((AnimationStatus s) {
      if (s == AnimationStatus.completed) {
        setState(() {
          _spinning = false;
          _result = _indexAtTop();
        });
      }
    });
  }

  int _indexAtTop() {
    final int n = _kFaces.length;
    final double seg = 2 * pi / n;
    final int raw = (-_angle / seg - 0.5).round().toInt();
    return ((raw % n) + n) % n;
  }

  void _spin() {
    if (_spinning) return;
    setState(() {
      _spinning = true;
      _result = null;
    });
    final int turns = 4 + _rand.nextInt(3);
    final double extra = _rand.nextDouble() * 2 * pi;
    _targetAngle = turns * 2 * pi + extra;
    _ctrl.reset();
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GameShell(
      title: '表情大转盘',
      instructions: '玩法：\n'
          '1. 转盘上分布着各种表情 emoji。\n'
          '2. 点击「转一转」，转盘停下后指针指向哪个表情。\n'
          '3. 请做出对应的表情，训练情绪表达。',
      body: Column(
        children: <Widget>[
          const SizedBox(height: 16),
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1,
                child: Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    Transform.rotate(
                      angle: _angle,
                      child: CustomPaint(
                        size: const Size.square(320),
                        painter: _WheelPainter(),
                      ),
                    ),
                    const Positioned(
                      top: 0,
                      child: Icon(Icons.play_arrow, size: 38, color: Colors.red),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_result != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: <Widget>[
                  Text(_kFaces[_result!].emoji, style: const TextStyle(fontSize: 48)),
                  Text('请做出「${_kFaces[_result!].label}」的表情',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: FilledButton.icon(
              onPressed: _spinning ? null : _spin,
              icon: const Icon(Icons.casino),
              label: const Text('转一转'),
            ),
          ),
        ],
      ),
    );
  }
}

class _WheelPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final int n = _kFaces.length;
    final double seg = 2 * pi / n;
    final double r = size.width / 2;
    final Offset c = Offset(r, r);
    for (int i = 0; i < n; i++) {
      final double a0 = -pi / 2 + i * seg;
      final double a1 = a0 + seg;
      final Paint paint = Paint()
        ..color = i.isEven ? Colors.orange.shade200 : Colors.amber.shade100;
      canvas.drawArc(Rect.fromCircle(center: c, radius: r), a0, seg, true, paint);
      final double mid = (a0 + a1) / 2;
      final double tr = r * 0.66;
      final Offset p = Offset(c.dx + tr * cos(mid), c.dy + tr * sin(mid));
      final TextPainter tp = TextPainter(
        text: TextSpan(text: _kFaces[i].emoji, style: const TextStyle(fontSize: 30)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(p.dx - tp.width / 2, p.dy - tp.height / 2));
    }
    canvas.drawCircle(c, 24, Paint()..color = Colors.white);
    canvas.drawCircle(
      c,
      24,
      Paint()
        ..color = Colors.black38
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
