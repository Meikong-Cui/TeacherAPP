import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:teacher_app/features/games/game_shell.dart';

/// 对对碰（记忆力）：先展示 emoji 数秒供记忆，随后翻牌找出相同成对。
class MatchPairsGame extends StatefulWidget {
  const MatchPairsGame({super.key});

  @override
  State<MatchPairsGame> createState() => _MatchPairsGameState();
}

class _MatchPairsGameState extends State<MatchPairsGame> {
  static const List<String> _emojiPool = <String>[
    '🍎', '🍌', '🍉', '🍇', '🍒', '🍓', '🍑', '🍍',
    '🐶', '🐱', '🐭', '🐹', '🐰', '🦊', '🐻', '🐼',
    '🐨', '🐯', '🦁', '🐮', '🐷', '🐸', '🐵', '🦄',
    '🚗', '🚌', '🚀', '⚽', '🌟', '🌈', '🎈', '🍔',
  ];

  int _score = 0;
  int _rows = 2;
  int _cols = 2;
  List<String> _emojis = <String>[];
  Set<int> _matched = <int>{};
  List<int> _revealed = <int>[];
  String _phase = 'memory'; // memory | input
  double _memLeft = 0;
  bool _locked = true;

  Timer? _memTimer;
  Timer? _hideTimer;
  Timer? _levelTimer;

  @override
  void initState() {
    super.initState();
    _resetBoard();
  }

  @override
  void dispose() {
    _memTimer?.cancel();
    _hideTimer?.cancel();
    _levelTimer?.cancel();
    super.dispose();
  }

  void _computeGrid() {
    final int pairs = (2 + (_score ~/ 10)).clamp(2, 12);
    final int total = pairs * 2;
    int bestR = 1;
    int bestC = total;
    int bestDiff = total - 1;
    for (int r = 1; r * r <= total; r++) {
      if (total % r == 0) {
        final int c = total ~/ r;
        final int diff = (c - r).abs();
        if (diff < bestDiff) {
          bestDiff = diff;
          bestR = r;
          bestC = c;
        }
      }
    }
    _rows = bestR;
    _cols = bestC;
  }

  void _resetBoard() {
    _memTimer?.cancel();
    _hideTimer?.cancel();
    _levelTimer?.cancel();
    _computeGrid();
    final int pairs = (_rows * _cols) ~/ 2;
    final List<String> pool = List<String>.from(_emojiPool)..shuffle();
    final List<String> picked = <String>[];
    for (int i = 0; i < pairs; i++) {
      picked.add(pool[i]);
      picked.add(pool[i]);
    }
    picked.shuffle();
    _emojis = picked;
    _matched = <int>{};
    _revealed = <int>[];
    _phase = 'memory';
    _locked = true;
    _memLeft = (0.6 + pairs * 0.3).clamp(2.0, 6.0);
    _startMemory();
  }

  void _startMemory() {
    _memTimer?.cancel();
    _memTimer = Timer.periodic(const Duration(milliseconds: 100), (Timer t) {
      if (!mounted) return;
      setState(() => _memLeft -= 0.1);
      if (_memLeft <= 0) {
        _memTimer?.cancel();
        if (!mounted) return;
        setState(() {
          _memLeft = 0;
          _phase = 'input';
          _locked = false;
        });
      }
    });
  }

  void _tap(int index) {
    if (_locked || _phase != 'input') return;
    if (_matched.contains(index)) return;
    if (_revealed.contains(index)) return;
    if (_revealed.length >= 2) return;
    setState(() => _revealed.add(index));
    if (_revealed.length == 2) _checkMatch();
  }

  void _checkMatch() {
    final int a = _revealed[0];
    final int b = _revealed[1];
    if (_emojis[a] == _emojis[b]) {
      _matched.add(a);
      _matched.add(b);
      _revealed = <int>[];
      _score += 2;
      if (_matched.length == _rows * _cols) {
        // 全部配对成功，进入下一难度。
        _locked = true;
        _levelTimer = Timer(const Duration(milliseconds: 700), () {
          if (!mounted) return;
          _resetBoard();
        });
      }
    } else {
      _hideTimer = Timer(const Duration(milliseconds: 600), () {
        if (!mounted) return;
        setState(() => _revealed = <int>[]);
      });
    }
  }

  String _display(int index) {
    if (_matched.contains(index)) return _emojis[index];
    if (_phase == 'memory') return _emojis[index];
    if (_revealed.contains(index)) return _emojis[index];
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return GameShell(
      title: '对对碰',
      instructions: '玩法：\n'
          '1. 一开始会展示所有图案，请记住它们的位置（倒计时结束前都可看）。\n'
          '2. 倒计时结束后图案隐藏，轮流翻开两张。\n'
          '3. 两张相同就配对成功并留在原地；不同会重新盖住。\n'
          '4. 全部配对成功进入更难的一关。这是记忆力训练小游戏。',
      body: Column(
        children: <Widget>[
          _buildHeader(),
          Expanded(
            child: LayoutBuilder(
              builder: (BuildContext ctx, BoxConstraints c) {
                final double cell =
                    min(c.maxWidth / _cols, c.maxHeight / _rows);
                final double w = cell * _cols;
                final double h = cell * _rows;
                return Center(
                  child: SizedBox(
                    width: w,
                    height: h,
                    child: GridView.count(
                      crossAxisCount: _cols,
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: List<Widget>.generate(_rows * _cols, (int i) {
                        return _cell(i, cell);
                      }),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final String memText = _phase == 'memory'
        ? '记忆倒计时 ${_memLeft.toStringAsFixed(1)}s'
        : '翻牌配对中';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: <Widget>[
          Chip(label: Text('得分 $_score')),
          const SizedBox(width: 8),
          Chip(label: Text('${_rows}×${_cols}')),
          const Spacer(),
          Text(memText),
          const SizedBox(width: 8),
          TextButton(onPressed: _resetBoard, child: const Text('重来')),
        ],
      ),
    );
  }

  Widget _cell(int index, double cell) {
    final String text = _display(index);
    final bool matched = _matched.contains(index);
    final bool revealed = _revealed.contains(index);
    Color bg = Colors.white;
    if (matched) bg = Colors.green.shade100;
    if (revealed && !matched) bg = Colors.amber.shade100;
    return Container(
      margin: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        onTap: () => _tap(index),
        borderRadius: BorderRadius.circular(8),
        child: Center(
          child: Text(
            text,
            style: TextStyle(fontSize: cell * 0.5),
          ),
        ),
      ),
    );
  }
}
