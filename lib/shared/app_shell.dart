import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 底部 Tab 导航壳（由 GoRouter StatefulShellRoute 驱动）。
class AppShell extends StatelessWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  static const List<_Tab> _tabs = <_Tab>[
    _Tab('首页', Icons.home_outlined, Icons.home, '/'),
    _Tab('儿童', Icons.diversity_1_outlined, Icons.diversity_1_rounded, '/children'),
    _Tab('消息', Icons.notifications_outlined, Icons.notifications, '/messages'),
    _Tab('我的', Icons.person_outline, Icons.person, '/profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (int i) => navigationShell.goBranch(i),
        destinations: <Widget>[
          for (int i = 0; i < _tabs.length; i++)
            NavigationDestination(
              icon: Icon(_tabs[i].icon),
              selectedIcon: Icon(_tabs[i].selectedIcon),
              label: _tabs[i].label,
            ),
        ],
      ),
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
