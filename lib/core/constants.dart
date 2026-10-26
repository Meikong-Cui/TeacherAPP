/// 应用级常量与共享配置。
class AppConstants {
  const AppConstants._();

  /// 品牌主色（与演示原型 / OA 后台一致）。
  static const String brandName = '哈哈龙康复';

  /// 品牌拉丁文（登录页品牌标识下方的小字，全大写宽字距）。
  static const String brandLatin = 'HA HA LONG';

  /// **APP 备案号**（工信部移动互联网应用程序备案，2026-10-26 取得）。
  ///
  /// ⚠️ 与网站 ICP 备案号**不是同一个**，两者不可混用：
  ///   · 网站：`黑ICP备2026013178号-1`（在 OA 网页底部展示，`BeianFooter.tsx`）
  ///   · APP ：`黑ICP备2026013178号-2A`（本常量，App 内「我的 → 关于」展示）
  /// 后缀 `-2A` 表示第 2 个互联网信息服务的 APP 形态。
  ///
  /// 备案信息（腾讯云/管局侧）：服务名称「哈哈龙」、域名 hrblk.cn、服务内容「儿童教育」。
  /// 依据《移动互联网应用程序备案》，APP 须在显著位置标注备案编号；
  /// 应用商店提交时也要在「App 备案信息」栏填写同一编号。
  static const String appRecordNo = '黑ICP备2026013178号-2A';

  /// 后端基础地址（App 复用 OA 后台同一套 API）。
  ///
  /// 生产环境走 HTTPS 域名：证书由腾讯云签发、在 nginx 终结，http 一律 301 跳 https。
  /// 所以默认值必须是 https —— iOS 端 ATS 按系统默认策略校验证书，Android 端 release
  /// 已关闭明文流量（usesCleartextTraffic=false），生产包里任何 http 地址都会被拦。
  ///
  /// 本地联调时用编译参数覆盖，无需改动源码（debug/profile 构建放行明文流量）：
  ///   flutter build apk --dart-define=API_BASE_URL=http://<本机IP>:8099
  ///   flutter run      --dart-define=API_BASE_URL=http://10.0.2.2:8099   (安卓模拟器)
  /// Android Studio：Run → Edit Configurations → 选中 main.dart →
  ///   “Additional run args” 填入 --dart-define=API_BASE_URL=http://192.168.x.x:8099
  /// 未传参即连生产环境，默认值保持不变。
  static const String apiBaseUrl =
      String.fromEnvironment('API_BASE_URL', defaultValue: 'https://hrblk.cn');

  /// AI 教案生成接口路径（后端 oa-ai 模块已存在，角色门禁 TEACHER,PRINCIPAL）。
  /// 当前为预留接口，AI 能力后续接入 DeepSeek。
  static const String aiLessonPlanPath = '/api/ai/lesson-plan';

  /// 教学计划（7 项目标）AI 接口路径前缀。
  /// 生成 / 对话式修改都在 oa-ai：配额与模型客户端只有一份，
  /// 后端会按新生首评或老生最新一期持续评估自动取依据。
  static const String aiTeachingPlanPath = '/api/ai/teaching-plan';

  /// 考勤打卡保存接口路径（预留，后端接入时实现）。
  static const String attendanceClockInPath = '/api/attendance/clock-in';

  /// 财务报销接口路径（后端 oa-reimbursement 模块已存在，角色门禁
  /// TEACHER 提交、FINANCE/PRINCIPAL 审批）。
  static const String reimbursementPath = '/api/reimbursement';

  /// 请款申请接口路径（后端 oa-fund 模块；审批链 申请人 → 财务 → 园长 → 出纳付款）。
  /// 请款单不设金额字段，金额在购买凭证图片里，所以凭证必填。
  static const String paymentApplyPath = '/api/finance/payment-apply';

  /// 开票申请接口路径（后端 oa-fund 模块；审批链同上）。
  /// 审批时后端会实时比对已通过的同名同额开票记录用于重复开票提示。
  static const String invoiceApplyPath = '/api/finance/invoice-apply';

  /// 康复档案接口路径（后端 oa-rehab 模块；教师提交/查看，园长可审批）。
  static const String rehabPath = '/api/rehab';

  /// 儿童主档接口路径（后端 oa-system 模块的 RehabChildController）。
  ///
  /// ⚠️ 与 [rehabPath] **不是同一个模块**：儿童主档（rehab_child）是
  /// 「家长信息 / 第二位家长 / 出生日期 / 身份证 / 班级 / 区县残联意见 / 归属校区」
  /// 的唯一真相，与档案 1:1 但独立。App「新增孩子」必须先 POST 这里拿到 childId，
  /// 再拿它去建档案 —— 否则这些字段会被后端静默丢弃（只补建一个只有姓名的儿童）。
  static const String childPath = '/api/children';

  /// 公章使用审批接口路径（后端 oa-rehab 模块的 SealApproval；
  /// TEACHER 申请，PRINCIPAL/ADMIN/FINANCE 审批）。
  static const String sealPath = '/api/seal';

  /// 打卡围栏半径的**全局默认值**（米）。
  ///
  /// 自 2026-09-20 起每个校区可以有自己的半径（后台 `sys_campus.clock_radius`，
  /// 在 OA 网页「学校管理」里维护），本常量是校区未配置时的兜底。
  /// 取用时走 `Campus.effectiveRadius`，不要直接读这里。
  static const double clockInRadiusMeters = 1000.0;

  // ── 真实地图底图 ──────────────────────────────────────────────────

  /// 是否启用真实地图底图。关掉则打卡页只画抽象围栏示意图，不请求任何外部瓦片。
  ///
  /// 编译期开关，用于离线演示或合规审查（中国区上架展示地图需要审图号，
  /// 直连第三方瓦片属灰色用法）：
  ///   flutter build apk --dart-define=CLOCK_IN_MAP=false
  static const bool mapEnabled =
      bool.fromEnvironment('CLOCK_IN_MAP', defaultValue: true);

  /// 底图瓦片地址模板（高德「路网图」瓦片）。
  ///
  /// 选型依据（2026-09-20 在国内网络实测）：
  ///   · OSM 官方 `tile.openstreetmap.org` / `a.tile...` —— **超时不可达**（HTTP 000）；
  ///   · Google Maps —— 国内本就打不开，且需 API key + 计费；
  ///   · 高德 `webrd0x.is.autonavi.com` —— 200 / 0.43s，返回真实地图 PNG。
  ///
  /// ⚠️ 瓦片是 **GCJ-02**，而 GPS 与后台存的打卡点坐标都是 **WGS-84**，
  /// 所以绘制前必须过 `domain/geo.dart` 的 `wgs84ToGcj02`，否则整体偏 300~600 米。
  /// 将来换合规底图（官方 SDK / 自建瓦片代理）时只改这一个常量。
  static const String mapTileUrlTemplate =
      'https://webrd0{s}.is.autonavi.com/appmaptile'
      '?lang=zh_cn&size=1&scale=1&style=8&x={x}&y={y}&z={z}';

  /// 瓦片子域，对应模板里的 `{s}`。
  static const List<String> mapTileSubdomains = <String>['1', '2', '3', '4'];

  /// 地图初始缩放级别（园区尺度：能同时看见围栏圈与附近街区）。
  static const double mapInitialZoom = 15.5;

  /// 瓦片请求附带的包名标识（flutter_map 要求设，便于瓦片方识别来源）。
  static const String mapUserAgentPackageName = 'com.meikongcui.teacherapp';
}
