import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:teacher_app/core/auth_store.dart';
import 'package:teacher_app/data/models/seal.dart';
import 'package:teacher_app/features/seal/provider/seal_provider.dart';
import 'package:teacher_app/shared/ui.dart';

/// 用章记录列表（教师查看自己的申请；审批人可在此通过/驳回）。
class SealListScreen extends ConsumerStatefulWidget {
  const SealListScreen({super.key});

  @override
  ConsumerState<SealListScreen> createState() => _SealListScreenState();
}

class _SealListScreenState extends ConsumerState<SealListScreen> {
  bool get _canReview =>
      AuthStore.instance.hasRole('PRINCIPAL') ||
      AuthStore.instance.hasRole('ADMIN') ||
      AuthStore.instance.hasRole('FINANCE');

  @override
  void initState() {
    super.initState();
    Future.microtask(
        () => ref.read(sealListProvider.notifier).load());
  }

  Future<void> _review(SealApproval item, int status) async {
    String? comment;
    if (status == 2) {
      comment = await _askComment();
      if (comment == null) return;
    }
    if (!mounted) return;
    final bool ok = await ref
        .read(sealListProvider.notifier)
        .review(item.id, status, comment: comment);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? (status == 1 ? '已通过' : '已驳回') : '操作失败')),
      );
    }
  }

  Future<String?> _askComment() async {
    final TextEditingController c = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('驳回意见'),
        content: TextField(
          controller: c,
          decoration: const InputDecoration(hintText: '请填写驳回原因'),
          maxLines: 2,
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(c.text.trim()),
            child: const Text('确认驳回'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final SealListState state = ref.watch(sealListProvider);
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('用章记录'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(sealListProvider.notifier).load(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/seal/apply'),
        icon: const Icon(Icons.add),
        label: const Text('新建申请'),
      ),
      body: _buildBody(state, textTheme),
    );
  }

  Widget _buildBody(SealListState state, TextTheme textTheme) {
    if (state.loading && state.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null && state.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(state.error!, style: textTheme.bodyMedium),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => ref.read(sealListProvider.notifier).load(),
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }
    if (state.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(Icons.gpp_good_outlined,
                size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text('暂无用章记录', style: textTheme.bodyMedium),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => ref.read(sealListProvider.notifier).load(),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: state.items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _SealCard(
          item: state.items[i],
          canReview: _canReview,
          onApprove: () => _review(state.items[i], 1),
          onReject: () => _review(state.items[i], 2),
        ),
      ),
    );
  }
}

class _SealCard extends StatelessWidget {
  const _SealCard({
    required this.item,
    required this.canReview,
    required this.onApprove,
    required this.onReject,
  });

  final SealApproval item;
  final bool canReview;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme colors = Theme.of(context).colorScheme;
    final bool pending = item.status == SealStatus.pending;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(item.purpose,
                      style: textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                ),
                StatusChip(item.status.label),
              ],
            ),
            const SizedBox(height: 8),
            InfoRow(label: '申请人', value: item.applicantName),
            InfoRow(
              label: '用章日期',
              value: item.useDate == null
                  ? '—'
                  : item.useDate!.toIso8601String().split('T').first,
            ),
            if (item.reviewComment != null && item.reviewComment!.isNotEmpty)
              InfoRow(label: '审批意见', value: item.reviewComment!),
            if (pending && canReview) ...<Widget>[
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: FilledButton(
                      onPressed: onApprove,
                      child: const Text('通过'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onReject,
                      child: const Text('驳回'),
                    ),
                  ),
                ],
              ),
            ] else if (!pending) ...<Widget>[
              const SizedBox(height: 8),
              Text('已由 ${item.reviewerName ?? '审批人'} 处理',
                  style: textTheme.bodySmall
                      ?.copyWith(color: colors.onSurfaceVariant)),
            ],
          ],
        ),
      ),
    );
  }
}
