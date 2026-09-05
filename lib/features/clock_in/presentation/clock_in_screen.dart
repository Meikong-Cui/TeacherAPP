import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:teacher_app/core/constants.dart';
import 'package:teacher_app/data/models/campus.dart';
import 'package:teacher_app/data/models/clock_record.dart';
import 'package:teacher_app/features/clock_in/provider/clock_in_provider.dart';
import 'package:teacher_app/features/clock_in/data/clock_in_repository.dart';
import 'package:teacher_app/shared/ui.dart';

/// 上下班签到页：指定地点 1000 米内方可打卡（使用真实 GPS 定位）。
class ClockInScreen extends ConsumerStatefulWidget {
  const ClockInScreen({super.key});

  @override
  ConsumerState<ClockInScreen> createState() => _ClockInScreenState();
}

class _ClockInScreenState extends ConsumerState<ClockInScreen> {
  @override
  void initState() {
    super.initState();
    // 进入页面即获取一次真实定位，用于围栏可视化。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(clockInProvider.notifier).fetchLocation();
    });
  }

  @override
  Widget build(BuildContext context) {
    final ClockInState state = ref.watch(clockInProvider);
    final ClockInRepository repo = ref.read(clockInRepositoryProvider);
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    // 实时（真实 GPS）距离，用于围栏可视化
    double? liveDistance;
    double? dx;
    double? dy;
    if (state.currentLatitude != null && state.currentLongitude != null) {
      liveDistance = repo.distanceTo(
        campus: state.campus,
        latitude: state.currentLatitude!,
        longitude: state.currentLongitude!,
      );
      dx = state.currentLongitude! - state.campus.longitude;
      dy = state.currentLatitude! - state.campus.latitude;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('上下班签到'),
        actions: const <Widget>[ThemeToggleButton()],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          // 打卡地点
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('打卡地点', style: textTheme.titleSmall),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<Campus>(
                    initialValue: state.campus,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.apartment_outlined),
                    ),
                    items: <DropdownMenuItem<Campus>>[
                      for (final c in Campus.all)
                        DropdownMenuItem<Campus>(
                          value: c,
                          child: Text(c.name),
                        ),
                    ],
                    onChanged: (c) {
                      if (c == null) return;
                      ref.read(clockInProvider.notifier).setCampus(c);
                    },
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '仅在距该地点 ${AppConstants.clockInRadiusMeters.toInt()} 米内允许签到',
                    style: textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // 围栏可视化
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: <Widget>[
                  FenceMap(
                    distanceMeters: liveDistance ?? 0,
                    dx: dx,
                    dy: dy,
                    active: liveDistance != null,
                  ),
                  const SizedBox(height: 12),
                  if (liveDistance != null)
                    StatusChip(
                      liveDistance <= AppConstants.clockInRadiusMeters
                          ? '在围栏内 · ${liveDistance.toStringAsFixed(0)} m'
                          : '超出围栏 · ${liveDistance.toStringAsFixed(0)} m',
                      tone: liveDistance <= AppConstants.clockInRadiusMeters
                          ? colors.primary
                          : Colors.orange,
                    )
                  else
                    const Text('点击下方按钮获取定位并计算距离'),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    icon: state.locating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location),
                    label: Text(state.locating ? '定位中…' : '获取当前位置'),
                    onPressed: state.locating
                        ? null
                        : () =>
                            ref.read(clockInProvider.notifier).fetchLocation(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // 打卡按钮
          Row(
            children: <Widget>[
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.login),
                  label: const Text('上班打卡'),
                  onPressed: state.loading
                      ? null
                      : () => ref
                          .read(clockInProvider.notifier)
                          .doClockIn(ClockType.checkIn),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.tonalIcon(
                  icon: const Icon(Icons.logout),
                  label: const Text('下班打卡'),
                  onPressed: state.loading
                      ? null
                      : () => ref
                          .read(clockInProvider.notifier)
                          .doClockIn(ClockType.checkOut),
                ),
              ),
            ],
          ),
          if (state.loading) const SizedBox(height: 12),
          if (state.loading)
            const Center(child: CircularProgressIndicator()),
          // 阻断性失败（超出围栏 / 定位不可用）：给出原因 + 可操作出口，
          // 不再是「按钮置灰、页面毫无反应」。
          if (state.error != null) ...<Widget>[
            const SizedBox(height: 12),
            MessageBox(
              color: colors.error,
              icon: Icons.error_outline,
              message: state.error!,
              actions: <Widget>[
                TextButton.icon(
                  icon: const Icon(Icons.my_location, size: 16),
                  label: const Text('重新定位'),
                  onPressed: state.locating || state.loading
                      ? null
                      : () => ref
                          .read(clockInProvider.notifier)
                          .fetchLocation(),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.note_alt_outlined, size: 16),
                  label: const Text('申请补卡'),
                  onPressed: () => context.push('/supplement/new'),
                ),
              ],
            ),
          ],
          // 非阻断提示：定位降级 / 后台同步失败但已本地留存。
          if (state.notice != null) ...<Widget>[
            const SizedBox(height: 12),
            MessageBox(
              color: Colors.orange.shade800,
              icon: Icons.info_outline,
              message: state.notice!,
            ),
          ],
          const SizedBox(height: 16),
          const AppSectionTitle('今日打卡记录'),
          if (state.records.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('暂无打卡记录'),
              ),
            )
          else
            for (final r in state.records)
              Card(
                child: ListTile(
                  leading: Icon(r.type.icon, color: colors.primary),
                  title: Text('${r.type.label} · ${r.campusName}'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text('${_fmt(r.time)} · 距打卡点 ${r.distanceText}'),
                      if (!r.synced || r.degradedLocation) ...<Widget>[
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          children: <Widget>[
                            if (!r.synced)
                              const Chip(
                                visualDensity: VisualDensity.compact,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                label: Text('待同步',
                                    style: TextStyle(fontSize: 11)),
                              ),
                            if (r.degradedLocation)
                              const Chip(
                                visualDensity: VisualDensity.compact,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                label: Text('定位降级',
                                    style: TextStyle(fontSize: 11)),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                  trailing: r.synced
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : TextButton(
                          onPressed: state.syncing
                              ? null
                              : () => ref
                                  .read(clockInProvider.notifier)
                                  .retrySync(r),
                          child: const Text('同步'),
                        ),
                ),
              ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  String _fmt(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

/// 提示区块：红色用于阻断性失败（给出补救入口），橙色用于非阻断提示。
///
/// 目的：任何失败都必须「说清原因 + 给出下一步」，不允许出现
/// 只有转圈或按钮置灰、用户无从判断的状态。
class MessageBox extends StatelessWidget {
  const MessageBox({
    required this.color,
    required this.icon,
    required this.message,
    this.actions = const <Widget>[],
    super.key,
  });

  final Color color;
  final IconData icon;
  final String message;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(icon, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(message, style: TextStyle(color: color)),
              ),
            ],
          ),
          if (actions.isNotEmpty)
            Wrap(
              spacing: 4,
              children: actions
                  .map((Widget w) => Theme(
                        data: Theme.of(context)
                            .copyWith(iconButtonTheme: IconButtonThemeData(
                          style: IconButton.styleFrom(foregroundColor: color),
                        )),
                        child: DefaultTextStyle(
                          style: TextStyle(color: color, fontSize: 13),
                          child: w,
                        ),
                      ))
                  .toList(),
            ),
        ],
      ),
    );
  }
}

/// 围栏可视化：中心为打卡点，外圈为 1000 米围栏，圆点为当前位置。
class FenceMap extends StatelessWidget {
  const FenceMap({
    super.key,
    required this.distanceMeters,
    this.dx,
    this.dy,
    this.active = false,
  });

  final double distanceMeters;
  final double? dx;
  final double? dy;
  final bool active;

  @override
  Widget build(BuildContext context) {
    const double size = 240;
    const double fenceRadius = size * 0.42;
    final ColorScheme colors = Theme.of(context).colorScheme;

    final double ratio =
        (distanceMeters / AppConstants.clockInRadiusMeters).clamp(0, 1);
    double angle = 0;
    if (dx != null && dy != null && (dx! != 0 || dy! != 0)) {
      angle = math.atan2(dx!, dy!);
    }
    final double r = ratio * fenceRadius;
    final double dotX = size / 2 + r * math.sin(angle) - 9;
    final double dotY = size / 2 - r * math.cos(angle) - 9;
    final bool within = distanceMeters <= AppConstants.clockInRadiusMeters;

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
      ..color = (within ? colors.primary : Colors.orange).withValues(alpha: 0.12);
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
