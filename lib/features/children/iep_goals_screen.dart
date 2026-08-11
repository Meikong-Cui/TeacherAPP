import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teacher_app/data/providers.dart';
import 'package:teacher_app/shared/ui.dart';

/// IEP 目标列表。
class IepGoalsScreen extends ConsumerWidget {
  const IepGoalsScreen({super.key, required this.childId});

  final String childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Child? child = ref.watch(childByIdProvider(childId));
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('IEP 目标')),
      body: child?.iep == null
          ? const Center(child: Text('该儿童暂无 IEP 周期'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(child!.iep!.title,
                            style: textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(
                            '${child.iep!.start} ~ ${child.iep!.end} · ${child.iep!.status}'),
                        const SizedBox(height: 8),
                        Text(
                            '已完成目标 ${child.iep!.completed}/${child.iep!.total}'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                for (final g in child.iep!.goals)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(g.domain,
                                    style: textTheme.titleSmall
                                        ?.copyWith(fontWeight: FontWeight.w700)),
                              ),
                              if (g.warning) StatusChip('临近截止', tone: Colors.orange),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(g.title, style: textTheme.bodyMedium),
                          const SizedBox(height: 4),
                          Text(g.desc,
                              style: textTheme.bodySmall),
                          const SizedBox(height: 10),
                          LinearProgressIndicator(
                            value: g.progress / 100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          const SizedBox(height: 4),
                          Text('${g.progress}% · 截止 ${g.deadline} · ${g.owner}'),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
