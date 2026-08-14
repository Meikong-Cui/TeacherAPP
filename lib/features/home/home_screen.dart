import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:teacher_app/data/models/rehab.dart';
import 'package:teacher_app/features/rehab/provider/rehab_provider.dart';
import 'package:teacher_app/shared/ui.dart';
import 'package:teacher_app/data/providers.dart';

/// 主页：教师仪表盘。儿童相关入口集中于此；办公类入口移至「办公」页。
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TeacherUser user = ref.watch(currentUserProvider);
    final AsyncValue<List<RehabArchive>> archivesAsync =
        ref.watch(rehabArchivesProvider);
    final AsyncValue<List<RehabTask>> tasksAsync =
        ref.watch(pendingTasksProvider);
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme colors = Theme.of(context).colorScheme;
    final DateFormat fmt = DateFormat('yyyy-MM-dd');

    final List<RehabTask> allTasks = tasksAsync.valueOrNull ?? <RehabTask>[];
    final List<RehabTask> plans = allTasks
        .where((t) => t.reminderType == 'TEACHING_PLAN')
        .toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    final List<RehabTask> todos = allTasks
        .where((t) => t.reminderType != 'TEACHING_PLAN')
        .toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('你好，${user.name}',
                style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            Text(user.center,
                style: textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
          ],
        ),
        actions: <Widget>[
          const ThemeToggleButton(),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: CircleAvatar(
              backgroundColor: colors.primaryContainer,
              foregroundColor: colors.onPrimaryContainer,
              child: Text(user.avatar),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          // 新增孩子 CTA
          FilledButton.icon(
            onPressed: () => context.push('/add-child'),
            icon: const Icon(Icons.add),
            label: const Text('新增孩子'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              textStyle: textTheme.titleMedium,
            ),
          ),
          const SizedBox(height: 16),

          // 我的儿童
          AppSectionTitle('我的儿童'),
          archivesAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text('档案加载失败：$e（后端可能未启动）'),
              ),
            ),
            data: (archives) {
              if (archives.isEmpty) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text('还没有孩子档案，点击上方「新增孩子」开始录入。',
                        style: textTheme.bodyMedium
                            ?.copyWith(color: colors.onSurfaceVariant)),
                  ),
                );
              }
              return Column(
                children: archives
                    .map((a) => _ChildCard(archive: a))
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 16),

          // 即将上课的教学计划（置顶）
          AppSectionTitle('即将上课的教学计划'),
          if (plans.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text('暂无即将开始的教学计划。',
                    style: textTheme.bodyMedium
                        ?.copyWith(color: colors.onSurfaceVariant)),
              ),
            )
          else
            Column(
              children: plans.take(3).map((t) {
                final bool soon = t.dueDate
                    .isBefore(DateTime.now().add(const Duration(days: 7)));
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0EA5A4).withOpacity(0.14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.event_available_outlined,
                          color: Color(0xFF0E8C84)),
                    ),
                    title: Row(
                      children: <Widget>[
                        Expanded(child: Text(t.title)),
                        if (soon)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0EA5A4).withOpacity(0.14),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text('即将上课',
                                style: TextStyle(
                                    color: Color(0xFF0E8C84),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700)),
                          ),
                      ],
                    ),
                    subtitle: Text('截止 ${fmt.format(t.dueDate)}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/children/${t.archiveId}'),
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 16),

          // 待办任务
          AppSectionTitle('待办任务（${todos.length}）'),
          if (todos.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text('暂无其他待办，辛苦了！',
                    style: textTheme.bodyMedium
                        ?.copyWith(color: colors.onSurfaceVariant)),
              ),
            )
          else
            Column(
              children: todos.take(4).map((t) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: colors.primaryContainer,
                      foregroundColor: colors.onPrimaryContainer,
                      child: Icon(
                        t.reminderType == 'TEACHING_PLAN'
                            ? Icons.edit_calendar_outlined
                            : Icons.assessment_outlined,
                        size: 20,
                      ),
                    ),
                    title: Text(t.title),
                    subtitle: Text('${t.typeLabel} · 截止 ${fmt.format(t.dueDate)}'),
                    trailing: TextButton(
                      onPressed: () async {
                        await ref
                            .read(rehabRepositoryProvider)
                            .completeTask(t.id);
                        ref.invalidate(pendingTasksProvider);
                        ref.invalidate(rehabArchivesProvider);
                      },
                      child: const Text('完成'),
                    ),
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _ChildCard extends StatelessWidget {
  const _ChildCard({required this.archive});
  final RehabArchive archive;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final Color accent =
        archive.isAutism ? iconColor('rose') : iconColor('green');
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => context.push('/children/${archive.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: <Widget>[
              CircleAvatar(
                radius: 24,
                backgroundColor: accent.withOpacity(0.16),
                child: Text(
                  archive.childName.isNotEmpty ? archive.childName[0] : '?',
                  style: textTheme.titleMedium?.copyWith(color: accent),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(archive.childName,
                        style: textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text('${archive.archiveNo} · ${archive.campusName}',
                        style: textTheme.bodySmall
                            ?.copyWith(color: colors.onSurfaceVariant)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(archive.typeLabel,
                    style: TextStyle(
                        color: accent, fontWeight: FontWeight.w700, fontSize: 12)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
