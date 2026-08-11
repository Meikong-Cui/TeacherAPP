import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:teacher_app/data/providers.dart';
import 'package:teacher_app/shared/ui.dart';

/// 评估任务列表（演示数据为全局评估任务）。
class AssessmentTasksScreen extends ConsumerWidget {
  const AssessmentTasksScreen({super.key, required this.childId});

  final String childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('评估任务')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          for (final a in ref.watch(assessmentsProvider))
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(a.name,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700)),
                        ),
                        StatusChip(a.status),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text('${a.child} · ${a.date} · ${a.version}'),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: a.total == 0 ? 0 : a.progress / a.total,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    const SizedBox(height: 6),
                    Text('进度 ${a.progress}/${a.total} 项'
                        '${a.autoSave != null ? ' · 自动保存 $a.autoSave' : ''}'),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => context.push('/assessment/${a.id}'),
                        child: const Text('继续填写'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
