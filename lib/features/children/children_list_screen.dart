import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:teacher_app/app/design_tokens.dart';
import 'package:teacher_app/shared/ui.dart';
import 'package:teacher_app/data/models/rehab.dart';
import 'package:teacher_app/features/rehab/provider/rehab_provider.dart';

/// 「儿童」页面：
/// - 顶部搜索框（按儿童姓名过滤）
/// - 卡片内容扩展：姓名 / 类型 / 性别 / 校区 / 入园建档时间 / 最近评估进度
/// - 右下角悬浮按钮可快速「新增孩子」
class ChildrenListScreen extends ConsumerStatefulWidget {
  const ChildrenListScreen({super.key});

  @override
  ConsumerState<ChildrenListScreen> createState() => _ChildrenListScreenState();
}

class _ChildrenListScreenState extends ConsumerState<ChildrenListScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _keyword = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<RehabArchive> _filter(List<RehabArchive> all) {
    if (_keyword.isEmpty) return all;
    final String k = _keyword.toLowerCase();
    return all
        .where((RehabArchive a) =>
            a.childName.toLowerCase().contains(k) ||
            a.archiveNo.toLowerCase().contains(k))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            _Header(
              keyword: _keyword,
              controller: _searchCtrl,
              onChanged: (String v) => setState(() => _keyword = v),
              onClear: () {
                _searchCtrl.clear();
                setState(() => _keyword = '');
              },
            ),
            Expanded(
              child: Consumer(
                builder: (BuildContext context, WidgetRef ref, _) {
                  final AsyncValue<List<RehabArchive>> archivesAsync =
                      ref.watch(rehabArchivesProvider);
                  return RefreshIndicator(
                    onRefresh: () async => ref.invalidate(rehabArchivesProvider),
                    child: archivesAsync.when(
                      loading: () => const Center(
                          child: CircularProgressIndicator()),
                      error: (Object e, _) => _ErrorView(
                          message: '加载失败：$e',
                          onRetry: () =>
                              ref.invalidate(rehabArchivesProvider)),
                      data: (List<RehabArchive> all) {
                        final List<RehabArchive> filtered = _filter(all);
                        if (all.isEmpty) {
                          return ListView(
                            padding: const EdgeInsets.all(16),
                            children: const <Widget>[
                              SizedBox(height: 80),
                              _EmptyState(),
                            ],
                          );
                        }
                        if (filtered.isEmpty) {
                          return ListView(
                            padding: const EdgeInsets.all(16),
                            children: <Widget>[
                              const SizedBox(height: 60),
                              Center(
                                child: Text('没有匹配「$_keyword」的儿童',
                                    style: const TextStyle(
                                        color: AppPalette.inkMute,
                                        fontSize: AppFontSize.body)),
                              ),
                            ],
                          );
                        }
                        return ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                          itemCount: filtered.length,
                          itemBuilder: (BuildContext ctx, int i) {
                            final RehabArchive a = filtered[i];
                            return _ChildCard(archive: a);
                          },
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/add-child'),
        icon: const Icon(Icons.add),
        label: const Text('新增孩子'),
      ),
    );
  }
}

// ───────────── 顶部 ─────────────

class _Header extends StatelessWidget {
  const _Header({
    required this.keyword,
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });
  final String keyword;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(children: const <Widget>[
            Text('我的儿童',
                style: TextStyle(
                  fontSize: AppFontSize.headline,
                  fontWeight: AppFontWeight.extrabold,
                  color: AppPalette.ink,
                )),
            Spacer(),
            ThemeToggleButton(),
          ]),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            onChanged: onChanged,
            decoration: InputDecoration(
              hintText: '按儿童姓名搜索',
              prefixIcon: const Icon(Icons.search,
                  color: AppPalette.inkMute),
              suffixIcon: keyword.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close,
                          color: AppPalette.inkMute),
                      onPressed: onClear,
                    ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                borderSide:
                    const BorderSide(color: AppPalette.brand, width: 1.2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────── 列表卡片 ─────────────

class _ChildCard extends StatelessWidget {
  const _ChildCard({required this.archive});
  final RehabArchive archive;

  @override
  Widget build(BuildContext context) {
    final bool isAutism = archive.isAutism;
    final Color tone = isAutism ? AppPalette.purple : AppPalette.success;
    final Gradient gradient =
        isAutism ? AppGradients.purple : AppGradients.tealLight;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: SoftCard(
        onTap: () => context.push('/children/${archive.id}'),
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // 第一行：姓名 + 类型标签
            Row(children: <Widget>[
              CircleAvatar(
                radius: 22,
                backgroundColor: tone.withOpacity(0.16),
                child: Text(
                  archive.childName.isNotEmpty ? archive.childName[0] : '?',
                  style: TextStyle(
                    color: tone,
                    fontWeight: AppFontWeight.bold,
                    fontSize: AppFontSize.title,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(archive.childName,
                        style: const TextStyle(
                          fontSize: AppFontSize.title,
                          fontWeight: AppFontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text(
                      '${archive.archiveNo}',
                      style: const TextStyle(
                        fontSize: AppFontSize.small,
                        color: AppPalette.inkMute,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  gradient: gradient,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(archive.typeLabel,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: AppFontSize.caption,
                        fontWeight: AppFontWeight.bold)),
              ),
            ]),
            const SizedBox(height: 12),
            // 第二行：性别 / 校区 / 入园时间
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: <Widget>[
                _MiniTag(
                  icon: Icons.transgender_outlined,
                  label: _genderText(archive),
                ),
                _MiniTag(
                  icon: Icons.location_on_outlined,
                  label: archive.campusName.isEmpty
                      ? '校区未填'
                      : archive.campusName,
                ),
                _MiniTag(
                  icon: Icons.event_outlined,
                  label: _enrollText(archive),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // 第三行：评估进度（最近待办）
            _ProgressStrip(
              archiveId: archive.id,
              tone: tone,
            ),
          ],
        ),
      ),
    );
  }

  static String _genderText(RehabArchive a) {
    // 后端 RehabArchive 没有直接 gender 字段，从 cache 的 firstEval gender 推断；
    // 没有额外来源时给中性提示，避免误导。
    return '性别未填';
  }

  static String _enrollText(RehabArchive a) {
    final DateTime? t = a.createTime;
    if (t == null) return '建档时间未填';
    return '建档 ${DateFormat('yyyy-MM-dd').format(t)}';
  }
}

class _MiniTag extends StatelessWidget {
  const _MiniTag({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppPalette.canvas,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 12, color: AppPalette.inkMute),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                fontSize: AppFontSize.small,
                color: AppPalette.inkMute,
              )),
        ],
      ),
    );
  }
}

/// 评估进度：显示最近的待办；通过 pendingTasksProvider + 自带的 archiveChildName 字段过滤。
class _ProgressStrip extends ConsumerWidget {
  const _ProgressStrip({required this.archiveId, required this.tone});
  final String archiveId;
  final Color tone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<RehabTask>> tasksAsync =
        ref.watch(pendingTasksProvider);
    final List<RehabTask> all = tasksAsync.valueOrNull ?? <RehabTask>[];
    final List<RehabTask> mine = all
        .where((RehabTask t) => t.archiveId == archiveId && !t.completed)
        .toList()
      ..sort((RehabTask a, RehabTask b) => a.dueDate.compareTo(b.dueDate));

    if (mine.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: tone.withOpacity(0.08),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Row(children: const <Widget>[
          Icon(Icons.check_circle_outline,
              size: 14, color: AppPalette.brandDark),
          SizedBox(width: 6),
          Text('评估进行中 · 无截止待办',
              style: TextStyle(
                  fontSize: AppFontSize.small, color: AppPalette.brandDark)),
        ]),
      );
    }

    final RehabTask next = mine.first;
    final bool overdue = next.dueDate.isBefore(DateTime.now());
    final String due =
        DateFormat('MM-dd').format(next.dueDate);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color:
            (overdue ? AppPalette.danger : tone).withOpacity(0.10),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(children: <Widget>[
        Icon(
          overdue ? Icons.warning_amber_outlined : Icons.schedule,
          size: 14,
          color: overdue ? AppPalette.danger : tone,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            '${next.typeLabel} · ${next.title}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: AppFontSize.small,
                color: overdue ? AppPalette.danger : tone,
                fontWeight: AppFontWeight.semibold),
          ),
        ),
        Text(
          overdue ? '已逾期 $due' : '截止 $due',
          style: TextStyle(
              fontSize: AppFontSize.caption,
              color: overdue ? AppPalette.danger : AppPalette.inkMute),
        ),
      ]),
    );
  }
}

// ───────────── 空态 ─────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          const AccentSquare(
              icon: Icons.diversity_1_outlined,
              gradient: AppGradients.tealLight,
              size: 56),
          const SizedBox(height: 12),
          const Text('还没有孩子档案',
              style: TextStyle(
                  fontSize: AppFontSize.title,
                  fontWeight: AppFontWeight.bold)),
          const SizedBox(height: 6),
          const Text('点击右下角「新增孩子」开始录入\n听障或孤独症类型可任选',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppFontSize.small,
                color: AppPalette.inkMute,
              )),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => context.push('/add-child'),
            icon: const Icon(Icons.add),
            label: const Text('新增第一个孩子'),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
        const Icon(Icons.error_outline,
            size: 56, color: AppPalette.danger),
        const SizedBox(height: 12),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('重试'),
        ),
      ]),
    );
  }
}
