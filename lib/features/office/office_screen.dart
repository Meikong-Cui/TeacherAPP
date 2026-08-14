import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:teacher_app/shared/ui.dart';

/// 办公页：从主页移出的行政/办公类功能入口。
class OfficeScreen extends StatelessWidget {
  const OfficeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme colors = Theme.of(context).colorScheme;

    final List<_OfficeEntry> entries = <_OfficeEntry>[
      const _OfficeEntry(
        icon: Icons.login_outlined,
        label: '上下班签到',
        subtitle: '围栏内打卡',
        route: '/clock-in',
        colorKey: 'green',
      ),
      const _OfficeEntry(
        icon: Icons.gpp_good_outlined,
        label: '用章申请',
        subtitle: '提交审批',
        route: '/seal/apply',
        colorKey: 'blue',
      ),
      const _OfficeEntry(
        icon: Icons.receipt_long_outlined,
        label: '财务报销',
        subtitle: '提交审批',
        route: '/reimbursement/list',
        colorKey: 'orange',
      ),
      const _OfficeEntry(
        icon: Icons.notifications_outlined,
        label: '消息通知',
        subtitle: '站内消息',
        route: '/messages',
        colorKey: 'purple',
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text('办公', style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        actions: const <Widget>[ThemeToggleButton()],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: <Widget>[
                Icon(Icons.work_outline_rounded, size: 32, color: colors.onPrimaryContainer),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('行政办公',
                          style: textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800, color: colors.onPrimaryContainer)),
                      const SizedBox(height: 2),
                      Text('签到、用章、报销、消息统一入口',
                          style: textTheme.bodySmall
                              ?.copyWith(color: colors.onPrimaryContainer)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AppSectionTitle('常用功能'),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.25,
            children: entries
                .map((e) => _OfficeCard(entry: e))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _OfficeEntry {
  const _OfficeEntry({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.route,
    required this.colorKey,
  });
  final IconData icon;
  final String label;
  final String subtitle;
  final String route;
  final String colorKey;
}

class _OfficeCard extends StatelessWidget {
  const _OfficeCard({required this.entry});
  final _OfficeEntry entry;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final Color accent = iconColor(entry.colorKey);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(entry.route),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(entry.icon, color: accent, size: 24),
              ),
              const SizedBox(height: 14),
              Text(entry.label,
                  style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(entry.subtitle,
                  style: textTheme.bodySmall
                      ?.copyWith(color: colors.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}
