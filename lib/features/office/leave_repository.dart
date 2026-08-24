import 'package:teacher_app/core/api_client.dart';
import 'package:teacher_app/features/workflow/workflow_repository.dart';

/// OA 请假 (hr-leave) 数据通道。
/// 与 oa-admin-web 共用同一份数据：调用 /api/oa/record
///   POST category='hr-leave' 创建 / PUT /:id 修改 / DELETE /:id 删除。
/// OA 网页在 src/config/oaRecordConfig.ts 已定义 hr-leave 的字段：
///   employee / leaveType(事假/病假/年假/调休) / startDate / endDate /
///   days / reason / status(0草稿/1待审批/2已完成/3已驳回)
class LeaveRecord {
  const LeaveRecord({
    this.id,
    required this.employee,
    required this.leaveType,
    required this.startDate,
    required this.endDate,
    required this.days,
    required this.reason,
    this.status = 1,
    this.createTime,
  });

  final int? id;
  final String employee; // 员工姓名（OA 后端 `usr()` 选择器写的是 name）
  final String leaveType; // '事假' | '病假' | '年假' | '调休'
  final String startDate; // yyyy-MM-dd
  final String endDate;
  final num? days;
  final String? reason;
  final int status; // 0草稿/1待审批/2已完成/3已驳回
  final String? createTime;

  String get statusLabel {
    switch (status) {
      case 0:
        return '草稿';
      case 1:
        return '待审批';
      case 2:
        return '已通过';
      case 3:
        return '已驳回';
      default:
        return '未知';
    }
  }

  factory LeaveRecord.fromJson(Map<String, dynamic> j) {
    return LeaveRecord(
      id: (j['id'] as num?)?.toInt(),
      employee: (j['employee'] as String?) ??
          (j['content'] is Map
              ? ((j['content']['employee'] ?? '') as String)
              : ''),
      leaveType:
          (j['leaveType'] as String?) ?? _fromContent(j, 'leaveType') ?? '',
      startDate: (j['startDate'] as String?) ?? _fromContent(j, 'startDate') ?? '',
      endDate: (j['endDate'] as String?) ?? _fromContent(j, 'endDate') ?? '',
      days: (j['days'] as num?) ?? num.tryParse(_fromContent(j, 'days') ?? ''),
      reason: (j['reason'] as String?) ?? _fromContent(j, 'reason'),
      status: (j['status'] as num?)?.toInt() ?? 1,
      createTime: j['createTime'] as String?,
    );
  }

  static String? _fromContent(Map<String, dynamic> j, String key) {
    final dynamic c = j['content'];
    if (c is Map && c[key] != null) return c[key].toString();
    return null;
  }
}

class LeaveRepository {
  LeaveRepository({ApiClient? client}) : _client = client ?? apiClient;
  final ApiClient _client;

  /// 列出当前教师提交的所有请假。OA 端通过 employee 字段保存提交者姓名。
  /// 这里同时透传当前用户名，确保能看到自己的记录；admin/principal 可看全部。
  Future<List<LeaveRecord>> listLeaves({String? keyword}) async {
    final Map<String, dynamic> params = <String, dynamic>{
      'category': 'hr-leave',
      'size': 50,
    };
    if (keyword != null && keyword.isNotEmpty) params['keyword'] = keyword;
    final dynamic data = await _client.get('/api/oa/record',
        params: params);
    final List<dynamic> records = (data is Map<String, dynamic>)
        ? (data['records'] as List? ?? <dynamic>[])
        : <dynamic>[];
    return records
        .whereType<Map<String, dynamic>>()
        .map((Map<String, dynamic> e) => LeaveRecord.fromJson(e))
        .toList();
  }

  /// 提交一条请假（创建草稿后立即提交 OA 走 hr-leave 流程）。
  /// 返回新建记录的主键（后端 data 可能是数字或含 id 的对象）。
  Future<int> createLeave(LeaveRecord r) async {
    final Map<String, dynamic> payload = <String, dynamic>{
      'category': 'hr-leave',
      'recordTitle': '${r.employee} · ${r.leaveType}',
      'content': <String, dynamic>{
        'employee': r.employee,
        'leaveType': r.leaveType,
        'startDate': r.startDate,
        'endDate': r.endDate,
        'days': r.days,
        'reason': r.reason ?? '',
      },
      'status': 1,
    };
    final dynamic data = await _client.post('/api/oa/record', payload);
    if (data is num) return data.toInt();
    if (data is Map<String, dynamic> && data['id'] is num) {
      return (data['id'] as num).toInt();
    }
    return 0;
  }

  /// 两步走提交请假：
  /// 1) 写入 oa_record（category=hr-leave）；
  /// 2) 若不存在则忽略，存在则发起「请假审批」流程实例，关联到该记录（businessType=oa_record）。
  /// 返回记录主键；hasWorkflow 标识是否成功挂上了审批流。
  Future<LeaveSubmitResult> submitLeave(LeaveRecord r) async {
    final int recordId = await createLeave(r);
    bool hasWorkflow = false;
    if (recordId > 0) {
      final WorkflowRepository wf = WorkflowRepository();
      final WorkflowTemplate? tpl = await wf.findTemplateByName('请假审批');
      if (tpl != null) {
        await wf.startInstance(
          templateId: tpl.id,
          formValues: <String, dynamic>{
            '请假类型': r.leaveType,
            '开始日期': r.startDate,
            '结束日期': r.endDate,
            '请假事由': r.reason ?? '',
          },
          businessType: 'oa_record',
          businessId: recordId,
        );
        hasWorkflow = true;
      }
    }
    return LeaveSubmitResult(recordId: recordId, hasWorkflow: hasWorkflow);
  }
}

class LeaveSubmitResult {
  const LeaveSubmitResult({required this.recordId, required this.hasWorkflow});
  final int recordId;
  final bool hasWorkflow;
}
