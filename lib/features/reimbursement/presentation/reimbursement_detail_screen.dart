import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teacher_app/data/models/reimbursement.dart';
import 'package:teacher_app/features/reimbursement/provider/reimbursement_provider.dart';
import 'package:teacher_app/shared/ui.dart';

/// 报销单详情。
class ReimbursementDetailScreen extends ConsumerWidget {
  const ReimbursementDetailScreen({super.key, required this.id});

  final String id;

  String _dateText(DateTime? t) {
    if (t == null) return '—';
    return '${t.year}-${t.month.toString().padLeft(2, '0')}-'
        '${t.day.toString().padLeft(2, '0')} '
        '${t.hour.toString().padLeft(2, '0')}:'
        '${t.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Reimbursement?> detail =
        ref.watch(reimbursementDetailProvider(id));
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('报销详情'),
        actions: const <Widget>[ThemeToggleButton()],
      ),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
        data: (Reimbursement? r) {
          if (r == null) {
            return const Center(child: Text('未找到该报销单'));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(r.title,
                                style: textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w800)),
                          ),
                          StatusChip(r.status.label),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('${r.category} · ${r.amountText}',
                          style: textTheme.bodyMedium
                              ?.copyWith(color: colors.primary)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const AppSectionTitle('基本信息'),
                      InfoRow(label: '申请人', value: r.applicantName),
                      InfoRow(label: '所属校区', value: r.campusName),
                      InfoRow(label: '报销类别', value: r.category),
                      InfoRow(label: '申请金额', value: r.amountText),
                      InfoRow(label: '提交时间', value: _dateText(r.createTime)),
                      const Divider(height: 20),
                      Text('事由说明',
                          style: textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(r.reason.isEmpty ? '—' : r.reason,
                          style: textTheme.bodyMedium),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      AppSectionTitle('费用明细（${r.items.length} 项）'),
                      ...r.items.map(
                        (ReimbursementItem item) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(item.name,
                                        style: textTheme.bodyMedium
                                            ?.copyWith(
                                                fontWeight: FontWeight.w600)),
                                    if (item.remark != null &&
                                        item.remark!.isNotEmpty)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(top: 2),
                                        child: Text(item.remark!,
                                            style: textTheme.bodySmall),
                                      ),
                                  ],
                                ),
                              ),
                              Text('¥${item.amount.toStringAsFixed(2)}',
                                  style: textTheme.bodyMedium
                                      ?.copyWith(fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ),
                      const Divider(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Text('合计',
                              style: textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w700)),
                          Text(r.amountText,
                              style: textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: colors.primary)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (r.status == ReimbursementStatus.pending)
                Card(
                  color: const Color(0xFF9A6A00).withOpacity(0.08),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: <Widget>[
                        const Icon(Icons.hourglass_top_outlined,
                            color: Color(0xFF9A6A00)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '已提交至 OA 后台，等待财务/园长审批。',
                            style: textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        InfoRow(
                            label: '审批人', value: r.approverName ?? '—'),
                        InfoRow(
                            label: '审批时间', value: _dateText(r.approveTime)),
                        const Divider(height: 20),
                        Text(
                            r.status == ReimbursementStatus.approved
                                ? '审批意见'
                                : '驳回原因',
                            style: textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(r.approveComment ?? '—',
                            style: textTheme.bodyMedium),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),
            ],
          );
        },
      ),
    );
  }
}
