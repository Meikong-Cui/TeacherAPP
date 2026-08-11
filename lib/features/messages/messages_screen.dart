import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teacher_app/data/providers.dart';
import 'package:teacher_app/shared/ui.dart';

/// 消息提醒。
class MessagesScreen extends ConsumerWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('消息'),
        actions: const <Widget>[ThemeToggleButton()],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          for (final m in ref.watch(messagesProvider))
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: iconColor(m.icon).withOpacity(0.14),
                  child: Icon(Icons.notifications, color: iconColor(m.icon)),
                ),
                title: Text(m.title),
                subtitle: Text(m.desc),
                trailing: Text(m.time,
                    style: Theme.of(context).textTheme.bodySmall),
              ),
            ),
        ],
      ),
    );
  }
}
