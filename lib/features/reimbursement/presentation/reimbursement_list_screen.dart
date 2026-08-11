import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:teacher_app/data/models/reimbursement.dart';
import 'package:teacher_app/features/reimbursement/provider/reimbursement_provider.dart';
import 'package:teacher_app/shared/ui.dart';

/// 财务报销列表（我的申请）。
class ReimbursementListScreen extends ConsumerStatefulWidget {
  const ReimbursementListScreen({super.key});

  @override
  ConsumerState<ReimbursementListScreen> createState() =>
      _ReimbursementListScreenState();
}

class _ReimbursementListScreenState
    extends ConsumerState<ReimbursementListScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
        () => ref.read(reimbursementListProvider.notifier).load());
  }

  String _dateText(DateTime? t) {
    if (t == null) return '';
    return '${t.year}-${t.month.toString().padLeft(2, '0')}-'
        '${t.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final ReimbursementListState state =
        ref.watch(reimbursementListProvider);
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('财务报销'),
        actions: const <Widget>[ThemeToggleButton()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('申请报销'),
        onPressed: () async {
          await context.push('/reimbursement/new');
          if (mounted) {
            ref.read(reimbursementListProvider.notifier).load();
          }
        },
      ),
      body: state.loading && state.list.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : state.error != null && state.list.isEmpty
              ? Center(
                  child: Text(state.error!,
                      style: textTheme.bodyMedium
                          ?.copyWith(color: colors.error)))
              : state.list.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(Icons.receipt_long_outlined,
                              size: 48,
                              color: colors.onSurfaceVariant
                                  .withOpacity(0.5)),
                          const SizedBox(height: 12),
                          Text('还没有报销申请',
                              style: textTheme.titleMedium),
                          const SizedBox(height: 4),
                          Text('点击右下角「申请报销」发起流程',
                              style: textTheme.bodySmall),
                        ],
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: <Widget>[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            '共 ${state.list.length} 条申请 · 提交后由财务/园长审批',
                            style: textTheme.bodySmall,
                          ),
                        ),
                        ...state.list.map(
                          (Reimbursement r) => Card(
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              leading: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: colors.primary.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(Icons.receipt_long_outlined,
                                    color: colors.primary),
                              ),
                              title: Text(r.title,
                                  style: textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700)),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  '${r.category} · ${r.amountText} · '
                                  '${_dateText(r.createTime)}',
                                  style: textTheme.bodySmall,
                                ),
                              ),
                              trailing: StatusChip(r.status.label),
                              onTap: () =>
                                  context.push('/reimbursement/${r.id}'),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
    );
  }
}
