import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:teacher_app/data/models/campus.dart';
import 'package:teacher_app/data/models/clock_record.dart';
import 'package:teacher_app/features/clock_in/data/clock_in_repository.dart';
import 'package:teacher_app/features/clock_in/domain/attendance.dart';
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
///
/// 2026-10-16 改版（用户需求）：
///   ① 时间精确到秒，显示用后台校准过的时钟（手机时间被改过也不影响判定）；
///   ② 一次只显示一个按钮 —— 没打上班卡只给「上班打卡」，打过只给「下班打卡」；
///   ③ 下班卡**随时可打、可反复刷新**，后台同一天取最晚一次为准；
///   ④ 上班前先取该员工应上班时间，已过点则弹红字「迟到」确认框，确认后才打卡；
///   ⑤ 每次打卡成功都弹「鼓励认真工作」卡片，3 秒自动关闭。
class ClockInScreen extends ConsumerStatefulWidget {
  const ClockInScreen({super.key});

  @override
  ConsumerState<ClockInScreen> createState() => _ClockInScreenState();
}

class _ClockInScreenState extends ConsumerState<ClockInScreen> {
  /// 秒级时钟：每秒触发一次重建，让页面上的时间真的在走（需求①）。
  Timer? _ticker;

  /// 本机时间（仅用于「拿不到后台时间」时兜底显示，见 [ClockInState.now]）。
  DateTime _localNow = DateTime.now();

  @override
  void initState() {
    super.initState();
    // 进入页面即获取一次真实定位，用于围栏可视化；同时拉取今日考勤（应上班时间）。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(clockInProvider.notifier).fetchLocation();
      ref.read(clockInProvider.notifier).loadAttendance();
    });
    _ticker = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      if (!mounted) return;
      setState(() => _localNow = DateTime.now());
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ClockInState state = ref.watch(clockInProvider);
    final ClockInRepository repo = ref.read(clockInRepositoryProvider);
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    // 当前选中校区。为 null 表示还没拿到任何校区数据（后台不可达且无可用缓存）。
    final Campus? selected = state.campus;

    // 后台校准后的「现在」：打卡按钮的迟到提示与页面时钟都以它为准。
    final DateTime now = state.attendance?.now ?? _localNow;

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

    // 下一步该打哪种卡（需求②）：没打上班卡 → 上班；打过 → 下班（可反复刷新）。
    final ClockType next = state.nextClockType;
    final bool updatingOff = next == ClockType.checkOut && state.hasCheckedOut;

    return Scaffold(
      appBar: AppBar(
        title: const Text('上下班签到'),
        actions: const <Widget>[ThemeToggleButton()],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          // ── 秒级时钟 + 今日班次（需求①④的判定依据）──
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Text(
                        _hhmmss(now),
                        style: textTheme.displaySmall?.copyWith(
                          fontFeatures: const <FontFeature>[
                            FontFeature.tabularFigures(),
                          ],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(_dateLine(now), style: textTheme.bodySmall),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    state.attendance == null
                        ? '未能获取后台班次（不影响打卡，但暂不做迟到判定）'
                        : '上班 ${state.attendance!.start} · 下班 ${state.attendance!.end}',
                    style: textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      StatusChip(
                        state.hasCheckedIn
                            ? '上班 ${state.attendance?.onTime ?? _localTimeOf(ClockType.checkIn, state) ?? "已打"}'
                            : '上班 未打卡',
                        tone: state.hasCheckedIn ? colors.primary : colors.outline,
                      ),
                      StatusChip(
                        state.hasCheckedOut
                            ? '下班 ${state.attendance?.offTime ?? _localTimeOf(ClockType.checkOut, state) ?? "已打"}'
                            : '下班 未打卡',
                        tone:
                            state.hasCheckedOut ? colors.primary : colors.outline,
                      ),
                      if (state.attendance?.statusLabel != null)
                        StatusChip(
                          state.attendance!.statusLabel!,
                          tone: state.attendance!.statusLabel == '正常'
                              ? colors.primary
                              : Colors.orange,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // 打卡地点（可手动切换）
          const SizedBox(height: 16),
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
          // ── 打卡按钮：一次只显示该打的那一个（需求②③）──
          FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              textStyle: textTheme.titleMedium,
            ),
            icon: state.loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(next.icon),
            label: Text(
              state.loading
                  ? '提交中…'
                  : next == ClockType.checkIn
                      ? '上班打卡'
                      : (updatingOff ? '更新下班打卡' : '下班打卡'),
            ),
            onPressed:
                (state.loading || !canClock) ? null : () => _onClock(next),
          ),
          const SizedBox(height: 6),
          Text(
            next == ClockType.checkIn
                ? (state.lateNow
                    ? '已过上班时间 ${state.attendance?.start ?? ""}，打卡将记为「迟到」'
                    : '打过上班卡后，这里会变成「下班打卡」')
                : '下班卡可随时重打，同一天以最晚一次为准',
            style: textTheme.bodySmall,
          ),
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
                      : () =>
                          ref.read(clockInProvider.notifier).fetchLocation(),
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

  /// 一次打卡的完整交互：迟到先确认 → 打卡 → 成功弹鼓励卡片。
  Future<void> _onClock(ClockType type) async {
    final ClockInState s = ref.read(clockInProvider);
    // 需求④：上班前先拿该员工应上班时间，已过点则弹红字「迟到」确认框。
    // 拿不到后台班次时不弹 —— 宁可少打扰，也不能凭本机时间误报迟到。
    if (type == ClockType.checkIn && s.lateNow) {
      final bool ok = await _confirmLate(s.attendance!.start, s.now);
      if (!ok || !mounted) return;
    }

    final ClockSubmitResult? result =
        await ref.read(clockInProvider.notifier).doClockIn(type);
    // 失败原因（越界 / 定位不可用 / 无校区）已由页面红色区块给出，这里不重复弹窗。
    if (result == null || !mounted) return;
    await _showEncouragement(result);
  }

  /// 已过上班时间的确认框：红字标出「迟到」，确认后才打卡。
  Future<bool> _confirmLate(String start, DateTime now) async {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        icon: Icon(Icons.schedule_outlined, color: colors.error, size: 32),
        title: const Text('已过上班时间'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text.rich(
              TextSpan(
                children: <InlineSpan>[
                  const TextSpan(text: '现在打卡将记为'),
                  TextSpan(
                    text: '迟到',
                    style: TextStyle(
                      color: colors.error,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const TextSpan(text: '。'),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text('应上班时间：$start'),
            Text('当前时间：${_hhmmss(now)}'),
            const SizedBox(height: 8),
            Text(
              '确实已迟到就直接确认；若是外勤等原因未能按时打卡，'
              '打卡后仍可提交「补卡申请」说明。',
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('确认打卡'),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  /// 需求⑤：每次打卡成功后弹「鼓励认真工作」卡片，3 秒自动关闭（也可点任意处关掉）。
  Future<void> _showEncouragement(ClockSubmitResult result) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext ctx) => _EncouragementCard(result: result),
    );
  }

  /// 本地未同步记录的打卡时刻（后台还没回结果时用它兜底展示）。
  String? _localTimeOf(ClockType type, ClockInState state) {
    for (final ClockRecord r in state.records) {
      if (r.type == type) return _hhmm(r.time);
    }
    return null;
  }

  String _fmt(DateTime t) => _hhmm(t);

  static String _hhmm(DateTime t) =>
      '${_t(t.hour)}:${_t(t.minute)}';

  static String _hhmmss(DateTime t) =>
      '${_t(t.hour)}:${_t(t.minute)}:${_t(t.second)}';

  /// 2026年10月16日 星期五
  static String _dateLine(DateTime t) {
    const List<String> week = <String>['一', '二', '三', '四', '五', '六', '日'];
    return '${t.year}年${t.month}月${t.day}日 星期${week[t.weekday - 1]}';
  }

  static String _t(int n) => n.toString().padLeft(2, '0');
}

/// 打卡结果的鼓励卡片：3 秒自动关闭。
///
/// 为什么不只用 SnackBar：打卡是老师们一天里最在意的一步，需要一个能看清
/// 「记的是上班还是下班、几点、什么状态」的确认，而不是一闪而过的提示条。
class _EncouragementCard extends StatefulWidget {
  const _EncouragementCard({required this.result});

  final ClockSubmitResult result;

  @override
  State<_EncouragementCard> createState() => _EncouragementCardState();
}

class _EncouragementCardState extends State<_EncouragementCard> {
  static const List<String> _words = <String>[
    '认真工作的人最踏实，今天也辛苦了！',
    '每一份用心，孩子和家长都看得见。',
    '又准时到岗，为你点赞！',
    '愿你今天顺利，心情舒畅。',
    '坚持守时，就是给孩子最好的示范。',
  ];

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 3), _close);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _close() {
    if (!mounted) return;
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ClockSubmitResult r = widget.result;
    final String word = _words[math.Random().nextInt(_words.length)];

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.emoji_events_outlined, size: 48, color: colors.primary),
            const SizedBox(height: 12),
            Text('${r.type.label}打卡成功', style: textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              r.displayTime,
              style: textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w600,
                fontFeatures: const <FontFeature>[
                  FontFeature.tabularFigures(),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              alignment: WrapAlignment.center,
              children: <Widget>[
                if (r.statusLabel != null)
                  StatusChip(
                    r.statusLabel!,
                    tone: r.statusLabel == '正常' ? colors.primary : Colors.orange,
                  ),
                StatusChip(
                  r.synced ? '已同步' : '待同步',
                  tone: r.synced ? colors.primary : Colors.orange,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              word,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium,
            ),
            if (!r.synced) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                '打卡已记录在本地，网络恢复后会自动重发，不会丢失。',
                textAlign: TextAlign.center,
                style: textTheme.bodySmall?.copyWith(color: Colors.orange.shade800),
              ),
            ],
            const SizedBox(height: 12),
            Text('3 秒后自动关闭', style: textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
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
