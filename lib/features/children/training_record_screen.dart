import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teacher_app/data/providers.dart';

/// 训练记录（演示数据 + 新增接口预留）。
class TrainingRecordScreen extends ConsumerWidget {
  const TrainingRecordScreen({super.key, required this.childId});

  final String childId;

  static const List<Map<String, String>> _demoRecords = <Map<String, String>>[
    <String, String>{
      'date': '今天 10:36',
      'course': '语言沟通图片训练',
      'rate': '70%',
      'note': '能跟读 3 字短句，主动性一般',
    },
    <String, String>{
      'date': '昨天 15:10',
      'course': '感知认知配对',
      'rate': '85%',
      'note': '分类准确率提升明显',
    },
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Child? child = ref.watch(childByIdProvider(childId));
    return Scaffold(
      appBar: AppBar(title: const Text('训练记录')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('新增训练记录（接口预留）')),
        ),
        icon: const Icon(Icons.add),
        label: const Text('新增记录'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          if (child != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('儿童：${child.name}',
                  style: Theme.of(context).textTheme.titleMedium),
            ),
          for (final r in _demoRecords)
            Card(
              child: ListTile(
                leading: const Icon(Icons.fitness_center_outlined),
                title: Text(r['course']!),
                subtitle: Text('${r['date']} · 完成度 ${r['rate']}\n${r['note']}'),
                isThreeLine: true,
              ),
            ),
        ],
      ),
    );
  }
}
