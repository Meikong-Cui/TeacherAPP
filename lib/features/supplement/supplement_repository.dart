import 'package:teacher_app/core/api_client.dart';
import 'package:teacher_app/features/workflow/workflow_repository.dart';

/// 补卡申请 (supplement-card) 数据通道（走通用流程引擎：补卡申请模板 + 直属上级审批）。
/// 与 oa-admin-web 共用同一份数据：调用 /api/oa/record
///   POST category='supplement-card' 创建 / GET 列表。
class SupplementRecord {
  const SupplementRecord({
    this.id,
    required this.employee,
    required this.supplementType,
    required this.supplementDate,
    required this.reason,
    this.status = 1,
    this.createTime,
  });

  final int? id;
  final String employee; // 员工姓名
  final String supplementType; // '上班漏卡' | '下班漏卡'
  final String supplementDate; // yyyy-MM-dd
  final String reason;
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

  factory SupplementRecord.fromJson(Map<String, dynamic> j) {
    return SupplementRecord(
      id: (j['id'] as num?)?.toInt(),
      employee: (j['employee'] as String?) ??
          (j['content'] is Map ? ((j['content']['employee'] ?? '') as String) : ''),
      supplementType:
          (j['supplementType'] as String?) ?? _fromContent(j, 'supplementType') ?? '',
      supplementDate:
          (j['supplementDate'] as String?) ?? _fromContent(j, 'supplementDate') ?? '',
      reason: (j['reason'] as String?) ?? _fromContent(j, 'reason') ?? '',
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

class SupplementRepository {
  SupplementRepository({ApiClient? client}) : _client = client ?? apiClient;
  final ApiClient _client;

  Future<List<SupplementRecord>> listSupplements({String? keyword}) async {
    final Map<String, dynamic> params = <String, dynamic>{
      'category': 'supplement-card',
      'size': 50,
    };
    if (keyword != null && keyword.isNotEmpty) params['keyword'] = keyword;
    final dynamic data = await _client.get('/api/oa/record', params: params);
    final List<dynamic> records = (data is Map<String, dynamic>)
        ? (data['records'] as List? ?? <dynamic>[])
        : <dynamic>[];
    return records
        .whereType<Map<String, dynamic>>()
        .map((Map<String, dynamic> e) => SupplementRecord.fromJson(e))
        .toList();
  }

  Future<int> createSupplement(SupplementRecord r) async {
    final Map<String, dynamic> payload = <String, dynamic>{
      'category': 'supplement-card',
      'recordTitle': '${r.employee} · ${r.supplementType}',
      'content': <String, dynamic>{
        'employee': r.employee,
        'supplementType': r.supplementType,
        'supplementDate': r.supplementDate,
        'reason': r.reason,
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

  /// 两步走提交补卡申请：
  /// 1) 写入 oa_record（category=supplement-card）；
  /// 2) 发起「补卡申请」流程实例（直属上级审批），审批通过后后端自动写入打卡记录。
  /// 返回记录主键；hasWorkflow 标识是否成功挂上了审批流。
  Future<SupplementSubmitResult> submitSupplement(SupplementRecord r) async {
    final int recordId = await createSupplement(r);
    bool hasWorkflow = false;
    if (recordId > 0) {
      final WorkflowRepository wf = WorkflowRepository();
      final WorkflowTemplate? tpl = await wf.findTemplateByName('补卡申请');
      if (tpl != null) {
        await wf.startInstance(
          templateId: tpl.id,
          formValues: <String, dynamic>{
            '补卡类型': r.supplementType,
            '补卡日期': r.supplementDate,
            '原因说明': r.reason,
          },
          businessType: 'oa_record',
          businessId: recordId,
        );
        hasWorkflow = true;
      }
    }
    return SupplementSubmitResult(recordId: recordId, hasWorkflow: hasWorkflow);
  }
}

class SupplementSubmitResult {
  const SupplementSubmitResult(
      {required this.recordId, required this.hasWorkflow});
  final int recordId;
  final bool hasWorkflow;
}
