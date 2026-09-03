import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:teacher_app/features/workflow/approval_badge.dart';

/// 底部 Tab 导航壳（由 GoRouter StatefulShellRoute 驱动）。
///
/// 「办公」Tab 图标右上角有红点角标 = 审批待办 + 未读通知合计数，
/// 数据来自 [approvalBadgeProvider]（全局 60 秒轮询，不依赖停留在哪个页面）。
class AppShell extends ConsumerWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  static const List<_Tab> _tabs = <_Tab>[
    _Tab('主页', Icons.home_outlined, Icons.home, '/'),
    _Tab('儿童', Icons.diversity_1_outlined, Icons.diversity_1_rounded, '/children'),
    _Tab('办公', Icons.work_outline_outlined, Icons.work_outline, '/office'),
    _Tab('我的', Icons.person_outline, Icons.person, '/profile'),
  ];

  /// 「办公」Tab 的下标（红点挂在这一项上）。
  static const int _officeTabIndex = 2;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int badge = ref.watch(approvalBadgeProvider);
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (int i) => navigationShell.goBranch(i),
        destinations: <Widget>[
          for (int i = 0; i < _tabs.length; i++)
            NavigationDestination(
              icon: _tabIcon(_tabs[i].icon, i, badge),
              selectedIcon: _tabIcon(_tabs[i].selectedIcon, i, badge),
              label: _tabs[i].label,
            ),
        ],
      ),
    );
  }

  /// 办公 Tab 包一层 Badge（有角标时显示数字，超过 99 显示 99+）；
  /// 其余 Tab 原样返回。
  Widget _tabIcon(IconData icon, int index, int badge) {
    if (index != _officeTabIndex || badge <= 0) {
      return Icon(icon);
    }
    return Badge(
      label: Text(badge > 99 ? '99+' : '$badge'),
      child: Icon(icon),
    );
  }
}

class _Tab {
  const _Tab(this.label, this.icon, this.selectedIcon, this.path);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String path;
}
