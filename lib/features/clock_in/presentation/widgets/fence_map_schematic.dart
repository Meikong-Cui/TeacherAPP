import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:teacher_app/core/constants.dart';

/// 围栏示意图（**无底图**）：中心为打卡点，外圈为围栏，圆点为当前位置。
///
/// 这是离线兜底视图：真实地图底图用不了时（无网络 / 瓦片不可达 /
/// 编译期关掉了地图开关）由 `FenceMapOnline` 退回这里，
/// 保证打卡页永远有东西可看，不会留白也不会一直转圈。
///
/// 注意它**不是按真实比例**画的：圆点到中心的距离按「距离 / 围栏半径」归一化，
/// 只看「在圈内还是圈外」，不表示真实方位与米数。要真实比例请用在线地图。
class FenceMap extends StatelessWidget {
  const FenceMap({
    super.key,
    required this.distanceMeters,
    this.dx,
    this.dy,
    this.active = false,
    this.radiusMeters = AppConstants.clockInRadiusMeters,
  });

  final double distanceMeters;

  /// 当前位置与打卡点的经度差、纬度差（用于决定圆点落在哪个方向）。
  final double? dx;
  final double? dy;
  final bool active;

  /// 围栏半径（米）。取当前校区的实际半径，不要写死全局默认值。
  final double radiusMeters;

  @override
  Widget build(BuildContext context) {
    const double size = 240;
    const double fenceRadius = size * 0.42;
    final ColorScheme colors = Theme.of(context).colorScheme;

    final double safeRadius =
        radiusMeters > 0 ? radiusMeters : AppConstants.clockInRadiusMeters;
    final double ratio = (distanceMeters / safeRadius).clamp(0, 1);
    double angle = 0;
    if (dx != null && dy != null && (dx! != 0 || dy! != 0)) {
      angle = math.atan2(dx!, dy!);
    }
    final double r = ratio * fenceRadius;
    final double dotX = size / 2 + r * math.sin(angle) - 9;
    final double dotY = size / 2 - r * math.cos(angle) - 9;
    final bool within = distanceMeters <= safeRadius;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: <Widget>[
          CustomPaint(
            size: const Size(size, size),
            painter: _FencePainter(colors: colors, within: within),
          ),
          // 打卡点（中心）
          Positioned(
            left: size / 2 - 6,
            top: size / 2 - 6,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: colors.primary,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
          // 当前位置
          if (active)
            Positioned(
              left: dotX,
              top: dotY,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: within ? Colors.green : Colors.orange,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FencePainter extends CustomPainter {
  const _FencePainter({required this.colors, required this.within});
  final ColorScheme colors;
  final bool within;

  @override
  void paint(Canvas canvas, Size size) {
    final double fenceRadius = size.width * 0.42;
    final Offset center = Offset(size.width / 2, size.height / 2);

    // 围栏填充
    final Paint fill = Paint()
      ..color =
          (within ? colors.primary : Colors.orange).withValues(alpha: 0.12);
    canvas.drawCircle(center, fenceRadius, fill);

    // 围栏描边（虚线感：用半透明双环）
    final Paint stroke = Paint()
      ..color = (within ? colors.primary : Colors.orange).withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, fenceRadius, stroke);
    canvas.drawCircle(center, fenceRadius * 0.6, stroke);
  }

  @override
  bool shouldRepaint(covariant _FencePainter old) =>
      old.within != within || old.colors != colors;
}
