import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:teacher_app/core/constants.dart';
import 'package:teacher_app/data/models/campus.dart';
import 'package:teacher_app/features/clock_in/domain/geo.dart';
import 'package:teacher_app/features/clock_in/presentation/widgets/fence_map_schematic.dart';

/// 底图状态：探测中 → 在线底图 / 退回示意图。
enum _MapMode { probing, online, schematic }

/// 打卡页的真实地图：底图 + 打卡点 + 围栏圈 + 当前位置。
///
/// ## 坐标处理（这里是最容易出错的地方）
/// 高德底图是 **GCJ-02**，而校区坐标（后台 `sys_campus`）与 GPS 都是 **WGS-84**，
/// 两系在本地相差 300~600 米。所以**这三个点画之前都要过 `wgs84ToGcj02`**，
/// 否则整张图上的东西会一起偏出去。
///
/// 注意这个转换只影响「画在哪」：围栏判定（[Campus.effectiveRadius] 与距离计算）
/// 全程是纯 WGS-84 的，**不经过这里**。这样即使转换实现有问题，
/// 错的也只是显示，不会把「能不能打卡」判错。
///
/// ## 失败兜底
/// 底图不可用（无网络 / 瓦片不可达 / 编译期关了地图开关）时**静默退回
/// [FenceMap] 示意图**，并在下方写明原因 —— 不留白、不转圈、不阻断打卡。
class FenceMapOnline extends StatefulWidget {
  const FenceMapOnline({
    super.key,
    required this.campus,
    this.currentLatitude,
    this.currentLongitude,
    this.distanceMeters,
    this.height = 260,
  });

  final Campus campus;
  final double? currentLatitude;
  final double? currentLongitude;
  final double? distanceMeters;
  final double height;

  @override
  State<FenceMapOnline> createState() => _FenceMapOnlineState();
}

class _FenceMapOnlineState extends State<FenceMapOnline> {
  /// 地图只读展示，禁用所有手势。
  ///
  /// 本组件嵌在 `ListView` 里，若放开拖动，用户在卡片上滑动会被地图吃掉、
  /// 页面滚不动 —— 这是这类「列表里塞地图」最常见的投诉。缩放也不给，
  /// 视野由初始取景决定（见 [_onlineMap] 的 CameraFit）。
  static const int _interactionFlags = InteractiveFlag.none;

  _MapMode _mode = _MapMode.probing;

  @override
  void initState() {
    super.initState();
    _decideMode();
  }

  @override
  void didUpdateWidget(covariant FenceMapOnline old) {
    super.didUpdateWidget(old);
    // 换了校区就重新探一次：坐标完全不同，能不能拿到瓦片也可能不同。
    if (old.campus.id != widget.campus.id) _decideMode();
  }

  Future<void> _decideMode() async {
    // 关掉地图开关、或该校区没配坐标：直接示意图，**不发任何外部请求**。
    if (!AppConstants.mapEnabled || !widget.campus.hasGeo) {
      if (mounted) setState(() => _mode = _MapMode.schematic);
      return;
    }
    if (mounted) setState(() => _mode = _MapMode.probing);
    final bool reachable = await _probeTiles();
    if (!mounted) return;
    setState(() => _mode = reachable ? _MapMode.online : _MapMode.schematic);
  }

  /// 拉一张真实瓦片探活。
  ///
  /// 不依赖地图库的加载回调，而是自己发一次请求判断 —— 这样「能不能用」
  /// 是一个确定的布尔值，而不是靠猜；探测期间界面已经显示示意图，
  /// 不会出现「空白 + 转圈」这种最难受的中间态。
  Future<bool> _probeTiles() async {
    final Campus c = widget.campus;
    final double? lat = c.latitude;
    final double? lng = c.longitude;
    if (lat == null || lng == null) return false;

    const int zoom = 14;
    final ({double lat, double lng}) gcj = wgs84ToGcj02(lat, lng);
    final ({int x, int y}) tile = _tileXY(gcj.lat, gcj.lng, zoom);
    final String url = AppConstants.mapTileUrlTemplate
        .replaceFirst('{s}', AppConstants.mapTileSubdomains.first)
        .replaceAll('{x}', '${tile.x}')
        .replaceAll('{y}', '${tile.y}')
        .replaceAll('{z}', '$zoom');

    try {
      final http.Response r = await http.get(
        Uri.parse(url),
        headers: <String, String>{
          'User-Agent': AppConstants.mapUserAgentPackageName,
        },
      ).timeout(const Duration(seconds: 5));
      // 真瓦片是几 KB 的 PNG；错误页 / 占位图要么状态码不对，要么只有几百字节。
      return r.statusCode == 200 && r.bodyBytes.length > 512;
    } catch (_) {
      return false;
    }
  }

  /// 经纬度 → Web Mercator 瓦片编号（与高德/OSM 的编号规则一致）。
  static ({int x, int y}) _tileXY(double lat, double lng, int zoom) {
    final int n = 1 << zoom;
    final double latRad = lat * math.pi / 180.0;
    final int x = ((lng + 180.0) / 360.0 * n).floor();
    final int y =
        ((1 - math.log(math.tan(latRad) + 1 / math.cos(latRad)) / math.pi) /
                2 *
                n)
            .floor();
    return (x: x, y: y);
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    final Widget area;
    final String? note;
    switch (_mode) {
      case _MapMode.probing:
        area = _schematic(context);
        note = '正在加载地图底图…（先按示意图显示，不影响打卡）';
      case _MapMode.schematic:
        area = _schematic(context);
        note = _schematicNote();
      case _MapMode.online:
        area = _onlineMap(context, colors);
        note = '绿色为当前位置，圆圈内为可打卡范围'
            '（半径 ${widget.campus.effectiveRadius.toInt()} 米）。'
            '底图 © 高德地图。';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: widget.height,
            width: double.infinity,
            child: area,
          ),
        ),
        if (note != null) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            note,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }

  Widget _schematic(BuildContext context) {
    final Campus c = widget.campus;
    double? dx;
    double? dy;
    if (c.hasGeo &&
        widget.currentLatitude != null &&
        widget.currentLongitude != null) {
      dx = widget.currentLongitude! - c.longitude!;
      dy = widget.currentLatitude! - c.latitude!;
    }
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Center(
        child: FenceMap(
          distanceMeters: widget.distanceMeters ?? 0,
          dx: dx,
          dy: dy,
          active: widget.currentLatitude != null &&
              widget.currentLongitude != null &&
              c.hasGeo,
          radiusMeters: c.effectiveRadius,
        ),
      ),
    );
  }

  String? _schematicNote() {
    final Campus c = widget.campus;
    if (!c.hasGeo) {
      return '「${c.name}」尚未配置打卡坐标，无法计算距离与绘制围栏。'
          '请联系管理员在 OA 网页「学校管理」中录入该校区坐标。';
    }
    if (!AppConstants.mapEnabled) {
      return '已按配置关闭真实地图底图，当前为示意图（距离判定不受影响）。';
    }
    return '底图暂时取不到，已切换为示意图（距离判定不受影响）。'
        '若长期如此，多半是网络无法访问瓦片服务。';
  }

  Widget _onlineMap(BuildContext context, ColorScheme colors) {
    final Campus c = widget.campus;
    final ({double lat, double lng}) campusGcj =
        wgs84ToGcj02(c.latitude!, c.longitude!);
    final LatLng campusPoint = LatLng(campusGcj.lat, campusGcj.lng);

    LatLng? currentPoint;
    if (widget.currentLatitude != null && widget.currentLongitude != null) {
      final ({double lat, double lng}) cur =
          wgs84ToGcj02(widget.currentLatitude!, widget.currentLongitude!);
      currentPoint = LatLng(cur.lat, cur.lng);
    }

    final double effectiveRadius = c.effectiveRadius;
    final bool within = (widget.distanceMeters ?? 0) <= effectiveRadius;
    final Color fenceColor = within ? colors.primary : Colors.orange;

    // 有当前位置就取景到「打卡点 + 当前位置」两点，否则对准打卡点定焦。
    final MapOptions options = currentPoint == null
        ? MapOptions(
            initialCenter: campusPoint,
            initialZoom: AppConstants.mapInitialZoom,
            interactionOptions:
                const InteractionOptions(flags: _interactionFlags),
          )
        : MapOptions(
            initialCameraFit: CameraFit.bounds(
              bounds:
                  LatLngBounds.fromPoints(<LatLng>[campusPoint, currentPoint]),
              padding: const EdgeInsets.all(44),
            ),
            interactionOptions:
                const InteractionOptions(flags: _interactionFlags),
          );

    return Stack(
      children: <Widget>[
        FlutterMap(
          // 定位从未知变为已知时重挂载一次，让 CameraFit 按新范围重新取景
          // （initial* 系列只在首次挂载生效）。手势已禁用，重挂载无副作用。
          key: ValueKey<String>(
              'fence-map-${c.id}-${currentPoint == null ? 'n' : 'y'}'),
          options: options,
          children: <Widget>[
            TileLayer(
              urlTemplate: AppConstants.mapTileUrlTemplate,
              subdomains: AppConstants.mapTileSubdomains,
              userAgentPackageName: AppConstants.mapUserAgentPackageName,
            ),
            CircleLayer(
              circles: <CircleMarker>[
                CircleMarker(
                  point: campusPoint,
                  radius: effectiveRadius,
                  useRadiusInMeter: true,
                  color: fenceColor.withValues(alpha: 0.14),
                  borderColor: fenceColor.withValues(alpha: 0.85),
                  borderStrokeWidth: 2,
                ),
              ],
            ),
            MarkerLayer(
              markers: <Marker>[
                Marker(
                  point: campusPoint,
                  width: 30,
                  height: 30,
                  child: _pin(colors.primary, Icons.apartment_outlined),
                ),
                if (currentPoint != null)
                  Marker(
                    point: currentPoint,
                    width: 26,
                    height: 26,
                    child: _pin(
                      within ? Colors.green : Colors.orange,
                      Icons.my_location,
                    ),
                  ),
              ],
            ),
          ],
        ),
        Positioned(
          right: 6,
          bottom: 4,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              child: Text(
                '© 高德地图',
                style: TextStyle(fontSize: 10, color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _pin(Color color, IconData icon) => Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Icon(icon, size: 13, color: Colors.white),
      );
}
