import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:teacher_app/app/design_tokens.dart';
import 'package:teacher_app/shared/ui.dart';

/// 办公页：行政 / 行政类功能入口（签到、用章、报销、请假、消息）。
/// 「我的」页只保留个人设置，办公功能全部移至此处。
class OfficeScreen extends StatelessWidget {
  const OfficeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<_OfficeEntry> entries = <_OfficeEntry>[
      const _OfficeEntry(
        icon: Icons.login_outlined,
        label: '上下班签到',
        subtitle: '围栏内打卡',
        route: '/clock-in',
        gradient: AppGradients.tealLight,
      ),
      const _OfficeEntry(
        icon: Icons.event_busy_outlined,
        label: '请假申请',
        subtitle: '事假 / 病假 / 年假',
        route: '/office/leave',
        gradient: AppGradients.rose,
      ),
      const _OfficeEntry(
        icon: Icons.gpp_good_outlined,
        label: '用章申请',
        subtitle: '提交审批',
        route: '/seal',
        gradient: AppGradients.sky,
      ),
      const _OfficeEntry(
        icon: Icons.fact_check_outlined,
        label: '补卡申请',
        subtitle: '漏打卡补记',
        route: '/supplement',
        gradient: AppGradients.amber,
      ),
      const _OfficeEntry(
        icon: Icons.receipt_long_outlined,
        label: '财务报销',
        subtitle: '提交审批',
        route: '/reimbursement/list',
        gradient: AppGradients.amber,
      ),
      const _OfficeEntry(
        icon: Icons.notifications_outlined,
        label: '消息通知',
        subtitle: '站内消息',
        route: '/messages',
        gradient: AppGradients.purple,
      ),
    ];

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: <Widget>[
            GradientCard(
              gradient: AppGradients.tealLight,
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              radius: AppRadius.lg,
              child: Row(
                children: <Widget>[
                  const AccentSquare(
                    icon: Icons.work_outline_rounded,
                    gradient: AppGradients.teal,
                    size: 52,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const <Widget>[
                        Text('行政办公',
                            style: TextStyle(
                              fontSize: AppFontSize.headline,
                              fontWeight: FontWeight.w800,
                            )),
                        SizedBox(height: 4),
                        Text('签到 / 请假 / 用章 / 报销 / 消息',
                            style: TextStyle(
                                fontSize: AppFontSize.small,
                                color: AppPalette.inkMute)),
                      ],
                    ),
                  ),
                  const ThemeToggleButton(),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const AppSectionTitle('常用功能'),
            GridView.builder(
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.45,
              ),
              itemCount: entries.length,
              itemBuilder: (BuildContext ctx, int i) {
                final _OfficeEntry e = entries[i];
                return _OfficeCard(entry: e);
              },
            ),
          ],
        ),
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
    required this.gradient,
  });
  final IconData icon;
  final String label;
  final String subtitle;
  final String route;
  final Gradient gradient;
}

class _OfficeCard extends StatelessWidget {
  const _OfficeCard({required this.entry});
  final _OfficeEntry entry;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      onTap: () => context.push(entry.route),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          AccentSquare(icon: entry.icon, gradient: entry.gradient),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(entry.label,
                  style: const TextStyle(
                      fontSize: AppFontSize.body,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(entry.subtitle,
                  style: const TextStyle(
                      fontSize: AppFontSize.small,
                      color: AppPalette.inkMute),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ],
      ),
    );
  }
}
