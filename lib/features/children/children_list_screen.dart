import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:teacher_app/data/models/rehab.dart';
import 'package:teacher_app/features/rehab/provider/rehab_provider.dart';
import 'package:teacher_app/shared/ui.dart';

/// 儿童目录：列出当前教师带的所有孩子（来自康复档案）。
class ChildrenListScreen extends ConsumerWidget {
  const ChildrenListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<RehabArchive>> archivesAsync =
        ref.watch(rehabArchivesProvider);
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('我的儿童',
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        actions: const <Widget>[ThemeToggleButton()],
      ),
      body: archivesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
        data: (archives) => archives.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(Icons.diversity_1_outlined,
                        size: 56, color: colors.onSurfaceVariant),
                    const SizedBox(height: 12),
                    Text('还没有孩子档案',
                        style: textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text('点击主页「新增孩子」开始录入',
                        style: textTheme.bodySmall
                            ?.copyWith(color: colors.onSurfaceVariant)),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: archives.length,
                itemBuilder: (ctx, i) {
                  final RehabArchive a = archives[i];
                  final Color accent =
                      a.isAutism ? iconColor('rose') : iconColor('green');
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      onTap: () => context.push('/children/${a.id}'),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: <Widget>[
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: accent.withOpacity(0.16),
                              child: Text(
                                a.childName.isNotEmpty ? a.childName[0] : '?',
                                style: textTheme.titleMedium
                                    ?.copyWith(color: accent),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(a.childName,
                                      style: textTheme.titleMedium
                                          ?.copyWith(fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 2),
                                  Text('${a.archiveNo} · ${a.campusName}',
                                      style: textTheme.bodySmall?.copyWith(
                                          color: colors.onSurfaceVariant)),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: accent.withOpacity(0.14),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(a.typeLabel,
                                  style: TextStyle(
                                      color: accent,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
