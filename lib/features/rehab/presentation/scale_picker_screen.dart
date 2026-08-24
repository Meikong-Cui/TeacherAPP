import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:teacher_app/data/models/autism_eval_item.dart';
import 'package:teacher_app/features/rehab/provider/autism_eval_provider.dart';

/// 量表选择页（孤独症评测入口）。
///
/// 在 OA「量表管理」/ 教师 APP「评测录入」统一入口使用：
/// 列出后端 `/api/rehab/autism/forms` 返回的全部可用量表（STANDARD / OFFLINE / VB_TEACHER / VB_PARENT），
/// 用户选一套再进编辑器。这样：
/// - 标题根据所选量表动态切换（不再固定"残联标准评估录入"）；
/// - 编辑器 URL 始终带 `?form=...`，无需 fallback；
/// - 已有档案的 `evalFormCode=null` 不再触发连锁 500。
class ScalePickerScreen extends ConsumerWidget {
  const ScalePickerScreen({required this.archiveId, super.key});

  final String archiveId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<AutismEvalForm>> formsAsync =
        ref.watch(evalFormsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('选择评测量表')),
      body: formsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 12),
                Text('加载量表失败：$e', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () => ref.invalidate(evalFormsProvider),
                  child: const Text('重试'),
                ),
              ],
            ),
          ),
        ),
        data: (forms) {
          if (forms.isEmpty) {
            return const Center(child: Text('暂无可用量表'));
          }
          // VB 教师/家长两卷合并为一张「VB 评估」卡片，进入 VB 专属首页（作答 + 趋势）。
          // OFFLINE 进入线下模板专属首页（A/B 卷答题 + 自动生成报告）。
          final List<_ScaleCardData> cards = <_ScaleCardData>[];
          bool hasVb = false;
          for (final AutismEvalForm f in forms) {
            if (f.formCode == 'VB_TEACHER' || f.formCode == 'VB_PARENT') {
              hasVb = true;
              continue;
            }
            final String desc = f.description ?? '';
            cards.add(_ScaleCardData(
              formCode: f.formCode,
              title: f.formName.isEmpty ? f.formCode : f.formName,
              description: desc,
            ));
          }
          if (hasVb) {
            cards.add(_ScaleCardData(
              formCode: 'VB',
              title: 'Vanderbilt（VB）',
              description: '教师卷 + 家长卷两套题，自动计分与多维度趋势分析',
            ));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: cards.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final _ScaleCardData c = cards[i];
              final String target = c.formCode == 'OFFLINE'
                  ? '/rehab-autism/$archiveId/offline-home'
                  : c.formCode == 'VB'
                      ? '/rehab-autism/$archiveId/vb-home'
                      : '/rehab-autism/$archiveId/items?form=${c.formCode}';
              return _ScaleCard(
                data: c,
                onTap: () => context.push(target),
              );
            },
          );
        },
      ),
    );
  }
}

class _ScaleCardData {
  const _ScaleCardData({
    required this.formCode,
    required this.title,
    required this.description,
  });
  final String formCode;
  final String title;
  final String description;
}

class _ScaleCard extends StatelessWidget {
  const _ScaleCard({required this.data, required this.onTap});
  final _ScaleCardData data;
  final VoidCallback onTap;

  IconData get _icon {
    switch (data.formCode) {
      case 'STANDARD':
        return Icons.assignment_outlined;
      case 'OFFLINE':
        return Icons.fact_check_outlined;
      case 'VB':
        return Icons.assessment_outlined;
      default:
        return Icons.description_outlined;
    }
  }

  Color get _color {
    switch (data.formCode) {
      case 'STANDARD':
        return Colors.indigo;
      case 'OFFLINE':
        return Colors.teal;
      case 'VB':
        return Colors.deepOrange;
      default:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: <Widget>[
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_icon, color: _color, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(data.title,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                    if (data.description.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(data.description,
                          style: TextStyle(
                              fontSize: 13, color: Colors.grey.shade700)),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

