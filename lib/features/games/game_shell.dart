import 'package:flutter/material.dart';

/// 小游戏通用外壳：统一顶部栏 + 进入即弹出玩法说明。
class GameShell extends StatefulWidget {
  const GameShell({
    super.key,
    required this.title,
    required this.instructions,
    required this.body,
    this.actions,
  });

  final String title;
  final String instructions;
  final Widget body;
  final List<Widget>? actions;

  @override
  State<GameShell> createState() => _GameShellState();
}

class _GameShellState extends State<GameShell> {
  @override
  void initState() {
    super.initState();
    // 进入游戏先弹一次玩法说明。
    WidgetsBinding.instance.addPostFrameCallback((_) => _showIntro());
  }

  void _showIntro() {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(widget.title),
        content: SingleChildScrollView(
          child: Text(widget.instructions, style: const TextStyle(height: 1.6)),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('开始游戏'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: '玩法说明',
            onPressed: _showIntro,
          ),
          if (widget.actions != null) ...widget.actions!,
        ],
      ),
      body: widget.body,
    );
  }
}
