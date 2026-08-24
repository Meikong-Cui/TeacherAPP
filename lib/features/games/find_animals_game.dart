import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:teacher_app/features/games/game_shell.dart';

// 占位小动物（美术素材为简单 emoji，后续可替换为真实图片）。
const List<String> _kAnimals = <String>[
  '🐱',
  '🐶',
  '🐰',
  '🐻',
  '🐼',
  '🐯',
];
const Map<String, String> _kAnimalNames = <String, String>{
  '🐱': '小猫，喵',
  '🐶': '小狗，汪',
  '🐰': '小兔',
  '🐻': '小熊',
  '🐼': '熊猫',
  '🐯': '老虎',
};
// 占位正确位置（相对坐标 0..1），后续可替换为真实背景图上的若干点。
const List<Offset> _kPositions = <Offset>[
  Offset(0.16, 0.30),
  Offset(0.64, 0.20),
  Offset(0.40, 0.50),
  Offset(0.82, 0.46),
  Offset(0.24, 0.74),
  Offset(0.72, 0.80),
];
// 装饰物（灌木），制造藏身感。
const List<Offset> _kDecoys = <Offset>[
  Offset(0.40, 0.20),
  Offset(0.58, 0.66),
  Offset(0.12, 0.56),
];

/// 找一找小动物（听觉）：听叫声 → 在画面点出对应动物 → 标红圈。
class FindAnimalsGame extends StatefulWidget {
  const FindAnimalsGame({super.key});

  @override
  State<FindAnimalsGame> createState() => _FindAnimalsGameState();
}

class _FindAnimalsGameState extends State<FindAnimalsGame> {
  late final FlutterTts _tts;
  late List<int> _order;
  int _targetIdx = 0;
  final Set<int> _found = <int>{};
  bool _won = false;
  int? _wrongIndex;

  @override
  void initState() {
    super.initState();
    _tts = FlutterTts();
    _tts.setLanguage('zh-CN');
    _order = List<int>.generate(_kAnimals.length, (int i) => i)..shuffle();
    WidgetsBinding.instance.addPostFrameCallback((_) => _speakTarget());
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  String get _targetEmoji => _kAnimals[_order[_targetIdx]];

  Future<void> _speakTarget() async {
    final String name = _kAnimalNames[_targetEmoji] ?? '小动物';
    await _tts.stop();
    await _tts.speak('请找出$name');
  }

  void _onTap(int i) {
    if (_won) return;
    if (_order[_targetIdx] == i) {
      setState(() {
        _found.add(i);
        _targetIdx++;
        if (_targetIdx >= _order.length) _won = true;
      });
      if (_won) {
        _tts.speak('太棒了，全部找到啦');
      } else {
        _speakTarget();
      }
    } else {
      setState(() => _wrongIndex = i);
      _tts.speak('再找找看');
      Future.delayed(const Duration(milliseconds: 350), () {
        if (mounted) setState(() => _wrongIndex = null);
      });
    }
  }

  void _reset() {
    setState(() {
      _found.clear();
      _targetIdx = 0;
      _won = false;
      _wrongIndex = null;
      _order = List<int>.generate(_kAnimals.length, (int i) => i)..shuffle();
    });
    _speakTarget();
  }

  @override
  Widget build(BuildContext context) {
    return GameShell(
      title: '找一找小动物',
      instructions: '玩法：\n'
          '1. 点击「🔊 听叫声」会播放当前要找的小动物叫声提示。\n'
          '2. 在画面里找出对应小动物并点击它。\n'
          '3. 找对后会出现红色圆圈标注；全部找完即过关。\n'
          '（美术素材为占位，后续可替换为真实背景图与正确位置点。）',
      body: Column(
        children: <Widget>[
          _buildTargetBar(),
          Expanded(child: _buildScene()),
          if (_won) _buildWinBar(),
        ],
      ),
    );
  }

  Widget _buildTargetBar() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: <Widget>[
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.amber.shade100,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(_won ? '🎉' : _targetEmoji,
                  style: const TextStyle(fontSize: 34)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(_won ? '全部找到啦！' : '找一找：$_targetEmoji',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                Text('已找到 ${_found.length}/${_kAnimals.length}',
                    style: const TextStyle(color: Colors.grey)),
              ],
            ),
          ),
          if (!_won)
            ElevatedButton.icon(
              onPressed: _speakTarget,
              icon: const Icon(Icons.volume_up, size: 18),
              label: const Text('听叫声'),
            ),
        ],
      ),
    );
  }

  Widget _buildScene() {
    return LayoutBuilder(
      builder: (BuildContext ctx, BoxConstraints c) {
        final double w = c.maxWidth;
        final double h = c.maxHeight;
        final List<Widget> kids = <Widget>[
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  Colors.lightBlue.shade100,
                  Colors.green.shade100,
                ],
              ),
            ),
          ),
        ];
        for (final Offset p in _kDecoys) {
          kids.add(Positioned(
            left: p.dx * w,
            top: p.dy * h,
            child: const Text('🌳', style: TextStyle(fontSize: 30)),
          ));
        }
        for (int i = 0; i < _kAnimals.length; i++) {
          final Offset p = _kPositions[i];
          final double x = p.dx * w;
          final double y = p.dy * h;
          kids.add(Positioned(
            left: x,
            top: y,
            child: GestureDetector(
              onTap: () => _onTap(i),
              child: Transform.scale(
                scale: _wrongIndex == i ? 1.4 : 1.0,
                child: Text(_kAnimals[i], style: const TextStyle(fontSize: 34)),
              ),
            ),
          ));
          if (_found.contains(i)) {
            kids.add(Positioned(
              left: x - 8,
              top: y - 8,
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.red, width: 3),
                  borderRadius: BorderRadius.circular(26),
                ),
              ),
            ));
          }
        }
        return Stack(children: kids);
      },
    );
  }

  Widget _buildWinBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      child: FilledButton.icon(
        onPressed: _reset,
        icon: const Icon(Icons.replay),
        label: const Text('再玩一次'),
      ),
    );
  }
}
