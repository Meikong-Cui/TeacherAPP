import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:teacher_app/features/games/game_shell.dart';

/// 顺序记忆（记忆力）：依次高亮若干格子，玩家按顺序点出相同位置。
class SequenceMemoryGame extends StatefulWidget {
  const SequenceMemoryGame({super.key});

  @override
  State<SequenceMemoryGame> createState() => _SequenceMemoryGameState();
}

class _SequenceMemoryGameState extends State<SequenceMemoryGame> {
  int _score = 0;
  int _rows = 3;
  int _cols = 3;
  int _n = 3; // 本关需要记住的格数
  List<int> _sequence = <int>[];
  int _seqPos = 0;
  int _userPos = 0;
  int _highlighted = -1;
  int _wrongIndex = -1;
  bool _inputLocked = true;
  bool _alive = true;

  Timer? _hlTimer;
  Timer? _wrongTimer;
  Timer? _nextTimer;

  @override
  void initState() {
    super.initState();
    _resetBoard();
  }

  @override
  void dispose() {
    _alive = false;
    _hlTimer?.cancel();
    _wrongTimer?.cancel();
    _nextTimer?.cancel();
    super.dispose();
  }

  void _computeDifficulty() {
    final int difficulty = (_score ~/ 10) + 1;
    _rows = (3 + (difficulty ~/ 5)).clamp(3, 6);
    _cols = (3 + (difficulty ~/ 3)).clamp(3, 6);
    _n = (3 + (difficulty - 1)).clamp(3, _rows * _cols - 1);
  }

  void _resetBoard() {
    _hlTimer?.cancel();
    _nextTimer?.cancel();
    _wrongTimer?.cancel();
    _computeDifficulty();
    final int total = _rows * _cols;
    final Set<int> set = <int>{};
    while (set.length < _n) {
      set.add(Random().nextInt(total));
    }
    _sequence = set.toList();
    _startHighlight();
  }

  void _startHighlight() {
    _seqPos = 0;
    _userPos = 0;
    _highlighted = -1;
    _wrongIndex = -1;
    _inputLocked = true;
    if (mounted) setState(() {});
    _scheduleNext();
  }

  void _scheduleNext() {
    if (!mounted || !_alive) return;
    if (_seqPos >= _sequence.length) {
      if (mounted) setState(() => _inputLocked = false);
      return;
    }
    _hlTimer?.cancel();
    _hlTimer = Timer(const Duration(milliseconds: 550), () {
      if (!mounted || !_alive) return;
      setState(() => _highlighted = _sequence[_seqPos]);
      _hlTimer = Timer(const Duration(milliseconds: 450), () {
        if (!mounted || !_alive) return;
        setState(() => _highlighted = -1);
        _seqPos++;
        _scheduleNext();
      });
    });
  }

  void _tap(int index) {
    if (_inputLocked) return;
    if (index == _sequence[_userPos]) {
      setState(() => _userPos += 1);
      if (_userPos >= _sequence.length) {
        // 本关完成，加分并进入下一关。
        _score += 10;
        _inputLocked = true;
        _nextTimer = Timer(const Duration(milliseconds: 600), () {
          if (!mounted || !_alive) return;
          _resetBoard();
        });
      }
    } else {
      // 点错：红色闪烁后重新播放本关序列。
      setState(() => _wrongIndex = index);
      _wrongTimer?.cancel();
      _wrongTimer = Timer(const Duration(milliseconds: 600), () {
        if (!mounted || !_alive) return;
        _startHighlight();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GameShell(
      title: '顺序记忆',
      instructions: '玩法：\n'
          '1. 开始后，会按顺序依次点亮几个格子，请记住点亮的位置和先后。\n'
          '2. 全部亮完后，请按同样的顺序点击这些格子。\n'
          '3. 点错会从头再演示一遍，跟着多练几次就好。\n'
          '4. 全部点对即过关，下一关要记的格子会更多。这是记忆力训练小游戏。',
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
    final String hint = _inputLocked ? '请记住点亮顺序…' : '轮到你来点啦！';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: <Widget>[
          Chip(label: Text('得分 $_score')),
          const SizedBox(width: 8),
          Chip(label: Text('记 ${_sequence.length} 格')),
          const Spacer(),
          Text(hint),
          const SizedBox(width: 8),
          TextButton(onPressed: _resetBoard, child: const Text('重来')),
        ],
      ),
    );
  }

  Widget _cell(int index, double cell) {
    final bool lit = _highlighted == index;
    final bool wrong = _wrongIndex == index;
    Color bg = Colors.white;
    if (lit) bg = Colors.orange.shade300;
    if (wrong) bg = Colors.red.shade300;
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
            (index + 1).toString(),
            style: TextStyle(
              fontSize: cell * 0.32,
              color: Colors.grey.shade400,
            ),
          ),
        ),
      ),
    );
  }
}
