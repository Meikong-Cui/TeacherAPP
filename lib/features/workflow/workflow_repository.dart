import 'package:teacher_app/core/api_client.dart';

/// 流程中心数据通道：模板查询、发起实例、按业务查询实例、待办/我发起、审批/驳回。
/// 对应后端 oa-workflow 模块（/api/workflow/*）。
class WorkflowTemplate {
  const WorkflowTemplate({
    required this.id,
    required this.name,
    this.nodes = const <dynamic>[],
  });

  final int id;
  final String name;
  final List<dynamic> nodes;

  factory WorkflowTemplate.fromJson(Map<String, dynamic> j) => WorkflowTemplate(
        id: (j['id'] as num?)?.toInt() ?? 0,
        name: (j['name'] as String?) ?? '',
        nodes: (j['nodes'] as List?) ?? const <dynamic>[],
      );
}

class WorkflowInstance {
  const WorkflowInstance({
    required this.id,
    this.instanceNo,
    this.status,
    this.currentNodeName,
    this.logs = const <dynamic>[],
  });

  final int id;
  final String? instanceNo;
  final int? status; // 1 审批中 2 已通过 3 已驳回
  final String? currentNodeName;
  final List<dynamic> logs;

  factory WorkflowInstance.fromJson(Map<String, dynamic> j) => WorkflowInstance(
        id: (j['id'] as num?)?.toInt() ?? 0,
        instanceNo: j['instanceNo'] as String?,
        status: (j['status'] as num?)?.toInt(),
        currentNodeName: j['currentNodeName'] as String?,
        logs: (j['logs'] as List?) ?? const <dynamic>[],
      );

  String get statusLabel {
    switch (status) {
      case 2:
        return '已通过';
      case 3:
        return '已驳回';
      case 1:
        return '审批中';
      default:
        return '未知';
    }
  }

  bool get pending => status == 1;
}

class WorkflowRepository {
  WorkflowRepository({ApiClient? client}) : _client = client ?? apiClient;
  final ApiClient _client;

  Future<List<WorkflowTemplate>> listTemplates() async {
    final dynamic data = await _client.get('/api/workflow/templates');
    final List<dynamic> raw = (data is List) ? data : <dynamic>[];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(WorkflowTemplate.fromJson)
        .toList();
  }

  /// 按名称查找模板（先精确匹配，再按包含匹配）。
  Future<WorkflowTemplate?> findTemplateByName(String name) async {
    final List<WorkflowTemplate> all = await listTemplates();
    for (final WorkflowTemplate t in all) {
      if (t.name == name) return t;
    }
    for (final WorkflowTemplate t in all) {
      if (t.name.contains(name)) return t;
    }
    return null;
  }

  /// 发起流程实例，返回实例主键。
  Future<int> startInstance({
    required int templateId,
    required Map<String, dynamic> formValues,
    String? businessType,
    int? businessId,
  }) async {
    final Map<String, dynamic> payload = <String, dynamic>{
      'templateId': templateId,
      'formValues': formValues,
    };
    if (businessType != null) payload['businessType'] = businessType;
    if (businessId != null) payload['businessId'] = businessId;
    final dynamic data = await _client.post('/api/workflow/instances', payload);
    return (data is num) ? data.toInt() : 0;
  }

  /// 按关联业务查询其审批流程实例（如某条 oa_record）。
  Future<WorkflowInstance?> findByBusiness(String businessType, int businessId) async {
    final dynamic data = await _client.get(
      '/api/workflow/instances/by-business',
      params: <String, dynamic>{
        'businessType': businessType,
        'businessId': businessId.toString(),
      },
    );
    if (data == null) return null;
    if (data is Map<String, dynamic>) return WorkflowInstance.fromJson(data);
    return null;
  }

  Future<List<WorkflowInstance>> listTodo() async {
    final dynamic data = await _client.get('/api/workflow/instances/todo');
    final List<dynamic> raw = (data is List) ? data : <dynamic>[];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(WorkflowInstance.fromJson)
        .toList();
  }

  Future<List<WorkflowInstance>> listMine() async {
    final dynamic data = await _client.get('/api/workflow/instances/mine');
    final List<dynamic> raw = (data is List) ? data : <dynamic>[];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(WorkflowInstance.fromJson)
        .toList();
  }

  Future<void> approve(int id, [String? comment]) async {
    await _client.post('/api/workflow/instances/$id/approve',
        <String, dynamic>{'comment': comment});
  }

  Future<void> reject(int id, [String? comment]) async {
    await _client.post('/api/workflow/instances/$id/reject',
        <String, dynamic>{'comment': comment});
  }
}
