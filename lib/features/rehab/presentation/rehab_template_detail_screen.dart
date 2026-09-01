import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:teacher_app/shared/ui.dart';

/// 残联标准模板下钻页：从儿童中枢页「残联标准模板」卡片进入。
/// 按档案类型（孤独症 / 听障）列出该标准模板下属的模块入口，保持卡片 UI。
/// 点击任一模块直达对应的既有功能页，避免把月计划 / IEP 等直接堆在中枢页。
class RehabTemplateDetailScreen extends StatelessWidget {
  const RehabTemplateDetailScreen({
    required this.archiveId,
    required this.isAutism,
    super.key,
  });
  final String archiveId;
  final bool isAutism;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme colors = Theme.of(context).colorScheme;
    final List<_ModuleEntry> modules = isAutism ? _autismModules() : _hearingModules();

    return Scaffold(
      appBar: AppBar(
        title: Text(isAutism ? '残联标准模板（孤独症）' : '残联标准模板（听障）'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Card(
            color: colors.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: <Widget>[
                  Icon(Icons.folder_special_outlined,
                      color: colors.onPrimaryContainer, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '残联标准康复模板：按月计划、IEP、评估等标准模块组织，'
                      '点击进入各模块详情。',
                      style: textTheme.bodyMedium
                          ?.copyWith(color: colors.onPrimaryContainer),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.25,
            children: modules
                .map((e) => _ModuleCard(entry: e, archiveId: archiveId))
                .toList(),
          ),
        ],
      ),
    );
  }

  List<_ModuleEntry> _autismModules() => <_ModuleEntry>[
        const _ModuleEntry(
          icon: Icons.assignment_outlined,
          title: '评测量表',
          subtitle: '选择量表逐题评分',
          // 残联标准模板内直接进入 STANDARD 量表，跳过量表选择页（无需选模板）。
          route: '/rehab-autism/{id}/items?form=STANDARD',
          colorKey: 'rose',
        ),
        const _ModuleEntry(
          icon: Icons.history_outlined,
          title: '评估历史',
          subtitle: 'VB 与线下模板记录',
          route: '/rehab-autism/{id}/eval-history',
          colorKey: 'rose',
        ),
        const _ModuleEntry(
          icon: Icons.auto_awesome_outlined,
          title: 'IEP 干预计划',
          subtitle: 'AI 推荐目标',
          route: '/rehab-autism/{id}/iep',
          colorKey: 'purple',
        ),
        const _ModuleEntry(
          icon: Icons.calendar_month_outlined,
          title: '月教学计划',
          subtitle: '六领域 × 4 周',
          route: '/rehab-autism/{id}/monthly-plan-ai',
          colorKey: 'amber',
        ),
        const _ModuleEntry(
          icon: Icons.insights_outlined,
          title: '训练效果评估表',
          subtitle: '年度效果',
          route: '/rehab-autism/{id}/effect',
          colorKey: 'blue',
        ),
        const _ModuleEntry(
          icon: Icons.pie_chart,
          title: '评估图表',
          subtitle: '饼图 / 折线图',
          route: '/rehab-autism/{id}/charts',
          colorKey: 'green',
        ),
      ];

  List<_ModuleEntry> _hearingModules() => <_ModuleEntry>[
        const _ModuleEntry(
          icon: Icons.assignment_outlined,
          title: '首次评估',
          subtitle: '录入/查看听障评估表',
          route: '/rehab/{id}/first-eval-edit',
          colorKey: 'teal',
        ),
        const _ModuleEntry(
          icon: Icons.assessment_outlined,
          title: '持续评估',
          subtitle: '待填写 / 历次评估',
          route: '/rehab/{id}/cont-eval-edit',
          colorKey: 'amber',
        ),
        const _ModuleEntry(
          icon: Icons.hearing_outlined,
          title: '听能管理',
          subtitle: '听力图 / 诊断记录',
          route: '/rehab/{id}/hearing',
          colorKey: 'blue',
        ),
        const _ModuleEntry(
          icon: Icons.edit_calendar_outlined,
          title: '教学计划',
          subtitle: '每节课计划 / AI 生成',
          route: '/rehab/{id}/plan',
          colorKey: 'purple',
        ),
        const _ModuleEntry(
          icon: Icons.event_note_outlined,
          title: '评估待办',
          subtitle: '查看提醒',
          route: '/rehab/{id}/tasks',
          colorKey: 'rose',
        ),
      ];
}

class _ModuleEntry {
  const _ModuleEntry({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
    required this.colorKey,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final String route;
  final String colorKey;
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({required this.entry, required this.archiveId});
  final _ModuleEntry entry;
  final String archiveId;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme colors = Theme.of(context).colorScheme;
    final Color accent = iconColor(entry.colorKey);
    final String route = entry.route.replaceAll('{id}', archiveId);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(route),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(entry.icon, color: accent, size: 22),
              ),
              const SizedBox(height: 10),
              Text(
                entry.title,
                style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Expanded(
                child: Text(
                  entry.subtitle,
                  style: textTheme.bodySmall
                      ?.copyWith(color: colors.onSurfaceVariant),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
