import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:teacher_app/features/games/games_data.dart';

/// 小游戏大厅：以卡片网格展示各游戏入口。
class GamesHubScreen extends StatelessWidget {
  const GamesHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('康复小游戏')),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 0.95,
        ),
        itemCount: kGames.length,
        itemBuilder: (BuildContext ctx, int i) {
          final GameMeta g = kGames[i];
          final Color accent = _accent(g.category);
          return Card(
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => context.push(g.route),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(g.icon, color: accent, size: 30),
                    ),
                    const SizedBox(height: 12),
                    Text(g.title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 4),
                    Expanded(
                      child: Text(g.desc,
                          style: TextStyle(
                              color: colors.onSurfaceVariant, fontSize: 12)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(g.category,
                          style: TextStyle(
                              color: accent, fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Color _accent(String category) {
    switch (category) {
      case '听觉':
        return Colors.green;
      case '发音':
        return Colors.orange;
      case '认知':
        return Colors.blue;
      case '情绪表达':
        return Colors.purple;
      default:
        return Colors.teal;
    }
  }
}
