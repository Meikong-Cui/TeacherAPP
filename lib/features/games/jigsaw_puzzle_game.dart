import 'package:flutter/material.dart';
import 'package:teacher_app/features/games/game_shell.dart';

/// 拼图小游戏（认知）：点击两块交换，拼回完整渐变图。
class JigsawPuzzleGame extends StatefulWidget {
  const JigsawPuzzleGame({super.key});

  @override
  State<JigsawPuzzleGame> createState() => _JigsawPuzzleGameState();
}

class _JigsawPuzzleGameState extends State<JigsawPuzzleGame> {
  static const int _n = 9; // 3x3
  late List<int> _order;
  int? _selected;
  bool _won = false;

  @override
  void initState() {
    super.initState();
    _shuffle();
  }

  void _shuffle() {
    do {
      _order = List<int>.generate(_n, (int i) => i)..shuffle();
    } while (_isSolved());
    _selected = null;
    _won = false;
  }

  bool _isSolved() {
    for (int i = 0; i < _n; i++) {
      if (_order[i] != i) return false;
    }
    return true;
  }

  Color _tileColor(int correctIndex) {
    final int row = correctIndex ~/ 3;
    final int col = correctIndex % 3;
    final double hue = (col * 40 + row * 30) % 360;
    return HSLColor.fromAHSL(1, hue.toDouble(), 0.55, 0.55).toColor();
  }

  void _tap(int pos) {
    if (_won) return;
    setState(() {
      if (_selected == null) {
        _selected = pos;
      } else if (_selected == pos) {
        _selected = null;
      } else {
        final int a = _order[_selected!];
        _order[_selected!] = _order[pos];
        _order[pos] = a;
        _selected = null;
        if (_isSolved()) _won = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GameShell(
      title: '拼图小游戏',
      instructions: '玩法：\n'
          '1. 图块已被打乱，目标把它拼回完整画面。\n'
          '2. 点击一块选中（高亮），再点击另一块即可交换位置。\n'
          '3. 全部归位即过关；可点「预览」偷看正确样子。',
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: <Widget>[
                if (_won)
                  const Text('🎉 拼好啦！',
                      style: TextStyle(fontWeight: FontWeight.w700))
                else
                  const Text('点击两块交换，拼回原图',
                      style: TextStyle(color: Colors.grey)),
                const Spacer(),
                TextButton.icon(
                  onPressed: _won ? null : _shuffle,
                  icon: const Icon(Icons.shuffle, size: 18),
                  label: const Text('打乱'),
                ),
                TextButton.icon(
                  onPressed: _won ? null : _showPreview,
                  icon: const Icon(Icons.visibility, size: 18),
                  label: const Text('预览'),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: GridView.count(
                crossAxisCount: 3,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
                children: List<Widget>.generate(_n, (int i) {
                  final int correct = _order[i];
                  return GestureDetector(
                    onTap: () => _tap(i),
                    child: Container(
                      decoration: BoxDecoration(
                        color: _tileColor(correct),
                        border: Border.all(
                          color: _selected == i ? Colors.white : Colors.black26,
                          width: _selected == i ? 3 : 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPreview() {
    showDialog(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('正确样子'),
        content: SizedBox(
          width: 240,
          height: 240,
          child: GridView.count(
            crossAxisCount: 3,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            children: List<Widget>.generate(_n, (int i) {
              return Container(
                decoration: BoxDecoration(
                  color: _tileColor(i),
                  borderRadius: BorderRadius.circular(6),
                ),
              );
            }),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
}
