import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:teacher_app/features/games/game_shell.dart';

/// 舒尔特方格（专注力）：按数字从小到大依次点击，过关后网格变大。
class SchulteGridGame extends StatefulWidget {
  const SchulteGridGame({super.key});

  @override
  State<SchulteGridGame> createState() => _SchulteGridGameState();
}

class _SchulteGridGameState extends State<SchulteGridGame> {
  int _level = 1;
  int _gridSize = 3;
  List<int> _cells = <int>[];
  List<int> _remaining = <int>[];
  Set<int> _done = <int>{};
  int _wrongIndex = -1;
  Timer? _wrongTimer;
  int _roundMs = 0;
  Timer? _roundTimer;

  @override
  void initState() {
    super.initState();
    _buildBoard();
    _startRoundTimer();
  }

  @override
  void dispose() {
    _wrongTimer?.cancel();
    _roundTimer?.cancel();
    super.dispose();
  }

  void _startRoundTimer() {
    _roundMs = 0;
    _roundTimer?.cancel();
    _roundTimer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      if (!mounted) return;
      setState(() => _roundMs += 1);
    });
  }

  void _buildBoard() {
    final int n = _gridSize * _gridSize;
    final List<int> nums = <int>[];
    if (_gridSize >= 5 && _level > 4) {
      // 高关卡用 1~99 随机不重复数字，难度更高。
      final Set<int> set = <int>{};
      while (set.length < n) {
        set.add(Random().nextInt(99) + 1);
      }
      nums.addAll(set);
    } else {
      nums.addAll(List<int>.generate(n, (int i) => i + 1));
    }
    nums.shuffle();
    _cells = nums;
    _remaining = List<int>.from(nums)..sort();
    _done = <int>{};
    _wrongIndex = -1;
  }

  void _nextLevel() {
    _level += 1;
    if (_gridSize < 5) _gridSize += 1;
    _buildBoard();
    _startRoundTimer();
  }

  void _tap(int index) {
    if (_wrongIndex != -1) return;
    final int num = _cells[index];
    if (_done.contains(index)) return;
    if (num == _remaining.first) {
      setState(() {
        _done.add(index);
        _remaining.removeAt(0);
      });
      if (_remaining.isEmpty) {
        Future<void>.delayed(const Duration(milliseconds: 450), () {
          if (!mounted) return;
          _nextLevel();
        });
      }
    } else if (num > _remaining.first) {
      // 点错：红色闪烁后恢复。
      setState(() => _wrongIndex = index);
      _wrongTimer?.cancel();
      _wrongTimer = Timer(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        setState(() => _wrongIndex = -1);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GameShell(
      title: '舒尔特方格',
      instructions: '玩法：\n'
          '1. 网格里散落着数字，请按照从小到大的顺序依次点击。\n'
          '2. 点错会变成红色提示，点对已完成的数字不会重复计分。\n'
          '3. 全部点完即过关，网格会变大、数字更多。\n'
          '这是专注力训练小游戏，慢慢来，不用着急。',
      body: Column(
        children: <Widget>[
          _buildHeader(),
          Expanded(
            child: LayoutBuilder(
              builder: (BuildContext ctx, BoxConstraints c) {
                final double size = min(c.maxWidth, c.maxHeight);
                final double cell = size / _gridSize;
                return Center(
                  child: SizedBox(
                    width: size,
                    height: size,
                    child: GridView.count(
                      crossAxisCount: _gridSize,
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: List<Widget>.generate(_cells.length, (int i) {
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: <Widget>[
          Chip(label: Text('第 $_level 关')),
          const SizedBox(width: 8),
          Chip(label: Text('${_gridSize}×${_gridSize}')),
          const Spacer(),
          Text('本轮 ${(_roundMs ~/ 60).toString().padLeft(2, '0')}:'
              '${(_roundMs % 60).toString().padLeft(2, '0')}'),
          const SizedBox(width: 8),
          TextButton(onPressed: _restart, child: const Text('重来')),
        ],
      ),
    );
  }

  void _restart() {
    _level = 1;
    _gridSize = 3;
    _buildBoard();
    _startRoundTimer();
    if (mounted) setState(() {});
  }

  Widget _cell(int index, double cell) {
    final int num = _cells[index];
    final bool done = _done.contains(index);
    final bool wrong = _wrongIndex == index;
    Color bg = Colors.white;
    if (done) bg = Colors.grey.shade300;
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
            num.toString(),
            style: TextStyle(
              fontSize: cell * 0.4,
              fontWeight: FontWeight.w700,
              color: done ? Colors.grey.shade600 : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }
}
