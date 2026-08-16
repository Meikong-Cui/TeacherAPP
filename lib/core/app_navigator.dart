import 'package:flutter/material.dart';

/// 全局 NavigatorKey，用于在 [NotificationService] 等无 BuildContext 处弹出对话框或跳转。
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();
