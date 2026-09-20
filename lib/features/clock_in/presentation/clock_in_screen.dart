import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:teacher_app/data/models/campus.dart';
import 'package:teacher_app/data/models/clock_record.dart';
import 'package:teacher_app/features/clock_in/data/clock_in_repository.dart';
import 'package:teacher_app/features/clock_in/presentation/widgets/fence_map_online.dart';
import 'package:teacher_app/features/clock_in/provider/clock_in_provider.dart';
import 'package:teacher_app/shared/ui.dart';

/// 上下班签到页。
///
/// 打卡地点**可以手动切换**，列表来自后台 `GET /api/system/campuses`
/// （由 OA 网页「学校管理」维护）。App **不内置任何校区**：后台不可达时依次退到
/// 「本地缓存（界面标注拉取时间）」与「明确失败态 + 重试入口」，不会出现
/// 「看起来正常的假校区」。
/// 在各自校区的围栏半径内方可打卡，围栏半径同样由后台按校区配置。
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

    // 当前选中校区。为 null 表示还没拿到任何校区数据（后台不可达且无可用缓存）。
    final Campus? selected = state.campus;

    // 实时（真实 GPS）距离，用于围栏可视化。无选中校区、或校区未配坐标时为 null。
    final bool hasFix =
        state.currentLatitude != null && state.currentLongitude != null;
    final double? liveDistance = (hasFix && selected != null)
        ? repo.distanceTo(
            campus: selected,
            latitude: state.currentLatitude!,
            longitude: state.currentLongitude!,
          )
        : null;
    final double fenceRadius = state.fenceRadiusMeters;
    final bool withinFence =
        liveDistance != null && liveDistance <= fenceRadius;

    // 没有校区就没有打卡点，也就没有围栏 —— 按钮禁用。
    // **但不是静默禁用**：下方有红色区块说明原因并给出「重试」入口。
    final bool canClock = selected != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('上下班签到'),
        actions: const <Widget>[ThemeToggleButton()],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          // 打卡地点（可手动切换）
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Text('打卡地点', style: textTheme.titleSmall),
                      if (state.loadingCampuses) ...<Widget>[
                        const SizedBox(width: 8),
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 6),
                        Text('加载校区列表…', style: textTheme.bodySmall),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (state.campuses.isEmpty)
                    Text(
                      state.loadingCampuses
                          ? '正在从后台获取校区列表…'
                          : '未能获取校区列表。校区与打卡坐标由管理员在 OA 网页'
                              '「学校管理」中维护，请检查网络后重试。',
                      style: textTheme.bodySmall,
                    )
                  else ...<Widget>[
                    DropdownButtonFormField<Campus>(
                      // ⚠️ key 是必需的，不是装饰：`initialValue` 只在挂载时生效，
                      // 不加 key 时「切换校区后下拉框显示的还是旧值」——用户会以为
                      // 选择没生效。绑到 id + 列表长度上，列表加载完或换选后强制重挂载，
                      // 保证显示值与 state 永远一致。
                      key: ValueKey<String>(
                          'campus-dd-${state.campuses.length}-${selected?.id}'),
                      initialValue: selected,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.apartment_outlined),
                      ),
                      items: <DropdownMenuItem<Campus>>[
                        for (final Campus c in state.campuses)
                          DropdownMenuItem<Campus>(
                            value: c,
                            child: Text(
                              c.hasGeo ? c.name : '${c.name}（未配置坐标）',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (Campus? c) {
                        if (c == null) return;
                        ref.read(clockInProvider.notifier).setCampus(c);
                      },
                    ),
                    const SizedBox(height: 4),
                    Text(
                      selected != null && selected.hasGeo
                          ? '仅在距「${selected.name}」打卡点 '
                              '${fenceRadius.toInt()} 米内允许签到'
                          : '「${selected?.name ?? ''}」尚未配置打卡坐标，'
                              '无法判定是否在岗，请在 OA「学校管理」中录入坐标',
                      style: textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ),
          // 校区列表彻底拿不到（后台不可达且本地无缓存）：红色区块 + 重试入口。
          // 与「超出围栏」等打卡失败分开展示 —— 它不是打卡动作引起的，
          // 而是页面压根还没准备好。
          if (state.campusLoadFailed) ...<Widget>[
            const SizedBox(height: 12),
            MessageBox(
              color: colors.error,
              icon: Icons.cloud_off_outlined,
              message: '未能从后台获取校区列表，且本地没有可用缓存，无法判定打卡范围。'
                  '请检查网络后重试。',
              actions: <Widget>[
                TextButton.icon(
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('重试'),
                  onPressed: state.loadingCampuses
                      ? null
                      : () => ref.read(clockInProvider.notifier).loadCampuses(),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.note_alt_outlined, size: 16),
                  label: const Text('申请补卡'),
                  onPressed: () => context.push('/supplement/new'),
                ),
              ],
            ),
          ],
          // 地图：真实底图 + 打卡点 + 围栏圈 + 当前位置；底图不可用时自动退回示意图。
          if (selected != null) ...<Widget>[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: <Widget>[
                    FenceMapOnline(
                      campus: selected,
                      currentLatitude: state.currentLatitude,
                      currentLongitude: state.currentLongitude,
                      distanceMeters: liveDistance,
                    ),
                    const SizedBox(height: 12),
                    if (liveDistance != null)
                      StatusChip(
                        withinFence
                            ? '在围栏内 · ${liveDistance.toStringAsFixed(0)} m'
                            : '超出围栏 · ${liveDistance.toStringAsFixed(0)} m',
                        tone: withinFence ? colors.primary : Colors.orange,
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
          ],
          const SizedBox(height: 16),
          // 打卡按钮
          Row(
            children: <Widget>[
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.login),
                  label: const Text('上班打卡'),
                  onPressed: (state.loading || !canClock)
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
                  onPressed: (state.loading || !canClock)
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
          // 阻断性失败（超出围栏 / 定位不可用 / 校区未配坐标）：给出原因 + 可操作出口，
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
          // 校区列表的来源与可用性（用的是缓存数据还是后台实时数据、哪些校区缺坐标）。
          // 独立于 notice 展示，不会在打卡/同步后被清掉。
          if (state.campusSourceNote != null) ...<Widget>[
            const SizedBox(height: 12),
            MessageBox(
              color: Colors.orange.shade800,
              icon: Icons.location_off_outlined,
              message: state.campusSourceNote!,
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
