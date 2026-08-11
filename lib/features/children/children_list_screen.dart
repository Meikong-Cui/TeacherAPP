import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:teacher_app/data/providers.dart';
import 'package:teacher_app/shared/ui.dart';

/// 儿童列表。
class ChildrenListScreen extends ConsumerWidget {
  const ChildrenListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<Child> children = ref.watch(childrenProvider);
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的儿童'),
        actions: const <Widget>[ThemeToggleButton()],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          for (final Child child in children)
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: colors.primaryContainer,
                  foregroundColor: colors.onPrimaryContainer,
                  child: Text(child.name.isNotEmpty ? child.name[0] : ''),
                ),
                title: Text(child.name),
                subtitle: Text(
                    '${child.gender} · ${child.ageText} · ${child.group}'),
                trailing: StatusChip(child.status),
                onTap: () => context.push('/children/${child.id}'),
              ),
            ),
        ],
      ),
    );
  }
}
