import 'package:flutter/material.dart';
import 'package:teacher_app/features/games/game_shell.dart';

class _Step {
  const _Step(this.emoji, this.label);
  final String emoji;
  final String label;
}

class _Sequence {
  const _Sequence(this.title, this.steps);
  final String title;
  final List<_Step> steps;
}

const List<_Sequence> _kSequences = <_Sequence>[
  _Sequence('洗手步骤', <_Step>[
    _Step('💧', '把手打湿'),
    _Step('🧼', '抹上肥皂'),
    _Step('🤲', '搓洗双手'),
    _Step('🚰', '冲洗干净'),
    _Step('🧻', '擦干双手'),
  ]),
  _Sequence('刷牙步骤', <_Step>[
    _Step('🪥', '挤上牙膏'),
    _Step('🦷', '刷牙 2 分钟'),
    _Step('🚰', '漱口'),
    _Step('🧺', '牙刷归位'),
  ]),
  _Sequence('穿衣服', <_Step>[
    _Step('👕', '穿上衣'),
    _Step('👖', '穿裤子'),
    _Step('🧦', '穿袜子'),
    _Step('👟', '穿鞋子'),
  ]),
];

/// 故事排序（认知）：拖拽把打乱的故事图排回正确顺序。
class SequenceSortGame extends StatefulWidget {
  const SequenceSortGame({super.key});

  @override
  State<SequenceSortGame> createState() => _SequenceSortGameState();
}

class _SequenceSortGameState extends State<SequenceSortGame> {
  int _seqIdx = 0;
  late List<int> _order;
  bool _won = false;

  @override
  void initState() {
    super.initState();
    _shuffle();
  }

  List<_Step> get _steps => _kSequences[_seqIdx].steps;

  void _shuffle() {
    do {
      _order = List<int>.generate(_steps.length, (int i) => i)..shuffle();
    } while (_isSolved());
    _won = false;
  }

  bool _isSolved() {
    for (int i = 0; i < _order.length; i++) {
      if (_order[i] != i) return false;
    }
    return true;
  }

  void _reorder(int oldIndex, int newIndex) {
    if (_won) return;
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final int item = _order.removeAt(oldIndex);
      _order.insert(newIndex, item);
      if (_isSolved()) _won = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<_Step> steps = _steps;
    return GameShell(
      title: '故事排序',
      instructions: '玩法：\n'
          '1. 一组故事图被打乱了顺序。\n'
          '2. 长按并拖动，把图片排回正确顺序（如洗手步骤）。\n'
          '3. 顺序正确即过关，可切换不同故事。',
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(
              children: <Widget>[
                DropdownButton<int>(
                  value: _seqIdx,
                  items: List<DropdownMenuItem<int>>.generate(
                    _kSequences.length,
                    (int i) => DropdownMenuItem<int>(
                      value: i,
                      child: Text(_kSequences[i].title),
                    ),
                  ),
                  onChanged: (int? v) {
                    if (v == null) return;
                    setState(() {
                      _seqIdx = v;
                      _shuffle();
                    });
                  },
                ),
                const Spacer(),
                if (_won)
                  const Text('🎉 顺序正确！',
                      style: TextStyle(fontWeight: FontWeight.w700))
                else
                  TextButton.icon(
                    onPressed: _shuffle,
                    icon: const Icon(Icons.shuffle, size: 18),
                    label: const Text('打乱'),
                  ),
              ],
            ),
          ),
          Expanded(
            child: ReorderableListView(
              padding: const EdgeInsets.all(12),
              onReorder: _reorder,
              children: List<Widget>.generate(_order.length, (int i) {
                final _Step step = steps[_order[i]];
                return Card(
                  key: ValueKey<int>(_order[i]),
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.teal.shade50,
                      child: Text(step.emoji, style: const TextStyle(fontSize: 22)),
                    ),
                    title: Text(step.label),
                    subtitle: Text('第 ${i + 1} 张'),
                    trailing: const Icon(Icons.drag_handle),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
