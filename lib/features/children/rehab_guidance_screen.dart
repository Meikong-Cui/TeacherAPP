import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teacher_app/data/providers.dart';
import 'package:teacher_app/shared/ui.dart';

/// 康复指导（下发到家庭的在家练习方案）。
class RehabGuidanceScreen extends ConsumerWidget {
  const RehabGuidanceScreen({super.key, required this.childId});

  final String childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final Guidance g = ref.watch(guidanceProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('康复指导')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(g.title,
                      style: textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(g.relation, style: textTheme.bodySmall),
                ],
              ),
            ),
          ),
          const AppSectionTitle('训练目标'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(g.target),
            ),
          ),
          const AppSectionTitle('练习步骤'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: <Widget>[
                  for (int i = 0; i < g.steps.length; i++)
                    ListTile(
                      leading: CircleAvatar(
                        child: Text('${i + 1}'),
                      ),
                      title: Text(g.steps[i]),
                    ),
                ],
              ),
            ),
          ),
          const AppSectionTitle('注意事项'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(g.notice),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
