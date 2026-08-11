import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teacher_app/data/providers.dart';

/// 评估填写（演示：选项可点选，保存草稿为接口预留）。
class AssessmentFormScreen extends ConsumerStatefulWidget {
  const AssessmentFormScreen({super.key, required this.assessmentId});

  final String assessmentId;

  @override
  ConsumerState<AssessmentFormScreen> createState() => _AssessmentFormState();
}

class _AssessmentFormState extends ConsumerState<AssessmentFormScreen> {
  final Map<int, String> _selected = <int, String>{};

  @override
  Widget build(BuildContext context) {
    final Assessment? a = ref.watch(assessmentByIdProvider(widget.assessmentId));
    if (a == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('评估填写')),
        body: const Center(child: Text('未找到评估任务')),
      );
    }
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(a.name),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('草稿已保存（接口预留）')),
              );
            },
            child: const Text('保存草稿'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Text('章节：${a.chapter}',
              style: textTheme.bodyMedium),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: a.total == 0 ? 0 : a.progress / a.total,
            borderRadius: BorderRadius.circular(8),
          ),
          const SizedBox(height: 16),
          for (final q in a.questions) ...<Widget>[
            Text(q.title, style: textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: <Widget>[
                for (final opt in q.options)
                  ChoiceChip(
                    label: Text(opt),
                    selected: _selected[q.id] == opt,
                    onSelected: (_) =>
                        setState(() => _selected[q.id] = opt),
                  ),
              ],
            ),
            const SizedBox(height: 18),
          ],
          if (a.questions.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('该评估尚未开始，点击“保存草稿”即创建初始记录（接口预留）。'),
              ),
            ),
        ],
      ),
    );
  }
}
