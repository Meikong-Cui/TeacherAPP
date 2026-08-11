import 'package:teacher_app/core/api_client.dart';
import 'package:teacher_app/core/constants.dart';
import 'package:teacher_app/data/models/reimbursement.dart';

/// 财务报销数据层（真实对接后端 oa-reimbursement 模块）。
///
/// 教师提交（POST /api/reimbursement），查看我的申请（GET /api/reimbursement/mine）。
/// 审批由财务/园长在 OA 后台完成。
class ReimbursementRepository {
  const ReimbursementRepository();

  /// 我的报销列表（按创建时间倒序由后端返回）。
  Future<List<Reimbursement>> listMine() async {
    final dynamic data =
        await apiClient.get('${AppConstants.reimbursementPath}/mine');
    if (data is! List) return const <Reimbursement>[];
    return data
        .whereType<Map<String, dynamic>>()
        .map((Map<String, dynamic> e) => Reimbursement.fromJson(e))
        .toList();
  }

  /// 按 id 查询单条。
  Future<Reimbursement?> getById(String id) async {
    final dynamic data =
        await apiClient.get('${AppConstants.reimbursementPath}/$id');
    if (data is! Map<String, dynamic>) return null;
    return Reimbursement.fromJson(data);
  }

  /// 提交一条新报销申请（真实后端）。返回带后端 id 的报销单。
  Future<Reimbursement> apply(Reimbursement draft) async {
    final dynamic data = await apiClient.post(
      AppConstants.reimbursementPath,
      draft.toApplyJson(),
    );
    final String id = data?.toString() ?? '';
    return draft.copyWith(id: id);
  }
}

/// 报销相关异常（携带中文提示）。
class ReimbursementException implements Exception {
  const ReimbursementException(this.message);
  final String message;
  @override
  String toString() => message;
}
