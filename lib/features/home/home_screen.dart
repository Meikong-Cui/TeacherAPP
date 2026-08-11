import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:teacher_app/data/providers.dart';
import 'package:teacher_app/data/models/rehab.dart';
import 'package:teacher_app/features/rehab/provider/rehab_provider.dart';
import 'package:teacher_app/shared/ui.dart';

/// 首页：待办概览 + 快捷入口 + 真实待办任务 + 真实康复档案儿童列表。
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TeacherUser user = ref.watch(currentUserProvider);
    final AsyncValue<List<RehabTask>> tasksAsync =
        ref.watch(pendingTasksProvider);
    final AsyncValue<List<RehabArchive>> archivesAsync =
        ref.watch(rehabArchivesProvider);
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('你好，${user.name}',
                style: textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            Text(user.center,
                style: textTheme.bodySmall
                    ?.copyWith(color: colors.onSurfaceVariant)),
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
          // 待办概览（真实待办任务数）
          tasksAsync.when(
            loading: () => Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
            error: (e, _) => Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('待办加载失败：$e'),
              ),
            ),
            data: (tasks) {
              final int count = tasks.length;
              return Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Row(
                    children: <Widget>[
                      ProgressRing(
                        value: count / 10,
                        size: 64,
                        center: Text(
                          '$count',
                          style: textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text('我的待办',
                                style: textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700)),
                            SizedBox(height: 4),
                            Text(
                              '$count 项待办任务',
                              style: textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          SizedBox(height: 16),
          // 快捷入口
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.92,
            children: <Widget>[
              _QuickAction(
                icon: Icons.location_on_outlined,
                label: '上下班签到',
                subtitle: '围栏内打卡',
                onTap: () => context.push('/clock-in'),
              ),
              _QuickAction(
                icon: Icons.receipt_long_outlined,
                label: '财务报销',
                subtitle: '提交审批',
                onTap: () => context.push('/reimbursement/list'),
              ),
              _QuickAction(
                icon: Icons.folder_open_outlined,
                label: '康复档案',
                subtitle: '评估与计划',
                onTap: () => context.push('/rehab'),
              ),
              _QuickAction(
                icon: Icons.gpp_good_outlined,
                label: '用章申请',
                subtitle: '提交审批',
                onTap: () => context.push('/seal/apply'),
              ),
            ],
          ),
          // 真实待办任务列表
          AppSectionTitle('待办任务'),
          tasksAsync.when(
            loading: () => SizedBox.shrink(),
            error: (e, _) => Text('加载失败：$e'),
            data: (tasks) {
              if (tasks.isEmpty) {
                return Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('暂无待办任务，辛苦了！'),
                  ),
                );
              }
              // 只显示前 5 条
              final List<RehabTask> show = tasks.take(5).toList();
              return Column(
                children: show
                    .map(
                      (t) => Card(
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
                          subtitle: Text(
                            '${t.typeLabel} · 截止 ${t.dueDate.toIso8601String().split('T').first}',
                          ),
                          trailing: t.completed
                              ? Icon(Icons.check_circle,
                                  color: Color(0xFF0EA5A4))
                              : TextButton(
                                  onPressed: () => _complete(ref, t),
                                  child: Text('完成'),
                                ),
                          onTap: () => context.push('/rehab/${t.archiveId}'),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
          // 真实康复档案 = 今日儿童
          AppSectionTitle('我的儿童（来自康复档案）'),
          archivesAsync.when(
            loading: () => Center(child: Padding(
              padding: EdgeInsets.all(20), child: CircularProgressIndicator())),
            error: (e, _) => Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('档案加载失败：$e（后端可能未启动）'),
              ),
            ),
            data: (archives) {
              if (archives.isEmpty) {
                return Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('暂无康复档案，请先在"康复档案"中新建。'),
                  ),
                );
              }
              return Column(
                children: archives
                    .map((a) => _ArchiveCard(archive: a))
                    .toList(),
              );
            },
          ),
          SizedBox(height: 16),
        ],
      ),
    );
  }

  Future<void> _complete(WidgetRef ref, RehabTask t) async {
    await ref.read(rehabRepositoryProvider).completeTask(t.id);
    ref.invalidate(pendingTasksProvider);
    ref.invalidate(rehabArchivesProvider);
  }
}

/// 康复档案卡片（替代原来的 mock 儿童卡片）。
class _ArchiveCard extends StatelessWidget {
  const _ArchiveCard({required this.archive});
  final RehabArchive archive;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: colors.primaryContainer,
          foregroundColor: colors.onPrimaryContainer,
          child: Text(archive.childName.isNotEmpty ? archive.childName[0] : '?'),
        ),
        title: Text(archive.childName),
        subtitle: Text('${archive.archiveNo} · ${archive.campusName} · ${archive.status.label}'),
        trailing: StatusChip(archive.status.label),
        onTap: () => context.push('/children/${archive.id}'),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: colors.primary),
              ),
              SizedBox(height: 12),
              Text(label,
                  style: textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              SizedBox(height: 2),
              Text(subtitle,
                  style: textTheme.bodySmall
                      ?.copyWith(color: colors.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}
