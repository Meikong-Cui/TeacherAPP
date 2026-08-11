import 'package:teacher_app/core/api_client.dart';
import 'package:teacher_app/core/constants.dart';
import 'package:teacher_app/data/models/seal.dart';

/// 公章使用审批数据层（真实对接后端 oa-rehab 模块的 SealApproval）。
class SealRepository {
  const SealRepository();

  /// 提交用章申请（申请人姓名由后端按 JWT 填充）。
  Future<String> apply(SealApproval approval) async {
    final dynamic data =
        await apiClient.post(AppConstants.sealPath, approval.toApplyJson());
    return data?.toString() ?? '';
  }

  /// 申请详情。
  Future<SealApproval> getById(String id) async {
    final dynamic data =
        await apiClient.get('${AppConstants.sealPath}/$id');
    if (data is! Map<String, dynamic>) {
      throw const ApiException('用章申请详情响应异常');
    }
    return SealApproval.fromJson(data);
  }

  /// 分页列表（默认我的申请；可传 status 过滤）。
  Future<List<SealApproval>> list({
    int? status,
    int current = 1,
    int size = 50,
  }) async {
    final StringBuffer sb = StringBuffer(
        '${AppConstants.sealPath}?current=$current&size=$size');
    if (status != null) sb.write('&status=$status');
    final dynamic data = await apiClient.get(sb.toString());
    if (data is Map && data['records'] is List) {
      return (data['records'] as List)
          .whereType<Map<String, dynamic>>()
          .map((e) => SealApproval.fromJson(e))
          .toList();
    }
    if (data is List) {
      return data
          .whereType<Map<String, dynamic>>()
          .map((e) => SealApproval.fromJson(e))
          .toList();
    }
    return const <SealApproval>[];
  }

  /// 审批（通过/驳回）— 仅 PRINCIPAL/ADMIN/FINANCE 角色。
  Future<void> approve(String id, int status, {String? comment}) async {
    final StringBuffer path = StringBuffer(
        '${AppConstants.sealPath}/$id/approve?status=$status');
    if (comment != null && comment.isNotEmpty) {
      path.write('&comment=${Uri.encodeQueryComponent(comment)}');
    }
    await apiClient.put(path.toString());
  }
}
