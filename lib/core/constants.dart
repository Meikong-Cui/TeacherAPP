/// 应用级常量与共享配置。
class AppConstants {
  const AppConstants._();

  /// 品牌主色（与演示原型 / OA 后台一致）。
  static const String brandName = '语亦丰康复';

  /// 后端基础地址（App 复用 OA 后台同一套 API）。
  /// 当前指向腾讯云生产环境（nginx :8080 反向代理 /api 到 backend:8099）。
  /// 本地模拟器调试请改回 'http://10.0.2.2:8099'；启用 HTTPS 后改用 'https://<域名或IP>'。
  static const String apiBaseUrl = 'http://62.234.141.250:8080';

  /// AI 教案生成接口路径（后端 oa-ai 模块已存在，角色门禁 TEACHER,PRINCIPAL）。
  /// 当前为预留接口，AI 能力后续接入 DeepSeek。
  static const String aiLessonPlanPath = '/api/ai/lesson-plan';

  /// 考勤打卡保存接口路径（预留，后端接入时实现）。
  static const String attendanceClockInPath = '/api/attendance/clock-in';

  /// 财务报销接口路径（后端 oa-reimbursement 模块已存在，角色门禁
  /// TEACHER 提交、FINANCE/PRINCIPAL 审批）。
  static const String reimbursementPath = '/api/reimbursement';

  /// 康复档案接口路径（后端 oa-rehab 模块；教师提交/查看，园长可审批）。
  static const String rehabPath = '/api/rehab';

  /// 公章使用审批接口路径（后端 oa-rehab 模块的 SealApproval；
  /// TEACHER 申请，PRINCIPAL/ADMIN/FINANCE 审批）。
  static const String sealPath = '/api/seal';

  /// 打卡围栏半径（米）。要求在指定打卡地点 1000 米内才可签到。
  static const double clockInRadiusMeters = 1000.0;
}
