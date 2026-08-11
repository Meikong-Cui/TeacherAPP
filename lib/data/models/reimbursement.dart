// 财务报销领域模型（教师发起 → 财务/园长审批）。
// 字段与后端 oa-reimbursement 模块的 Reimbursement / ReimbursementItem 对齐。

/// 报销单状态。
enum ReimbursementStatus {
  pending(1, '待审批'),
  approved(2, '已通过'),
  rejected(3, '已驳回');

  const ReimbursementStatus(this.code, this.label);

  final int code;
  final String label;

  static ReimbursementStatus fromCode(int? code) {
    for (final ReimbursementStatus s in ReimbursementStatus.values) {
      if (s.code == code) return s;
    }
    return ReimbursementStatus.pending;
  }
}

/// 报销明细项（一条报销单可含多项消费）。
class ReimbursementItem {
  const ReimbursementItem({
    this.id,
    required this.name,
    required this.amount,
    this.remark,
  });

  final String? id;
  final String name;
  final double amount;
  final String? remark;

  ReimbursementItem copyWith({
    String? id,
    String? name,
    double? amount,
    String? remark,
  }) =>
      ReimbursementItem(
        id: id ?? this.id,
        name: name ?? this.name,
        amount: amount ?? this.amount,
        remark: remark ?? this.remark,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name,
        'amount': amount,
        if (remark != null && remark!.isNotEmpty) 'remark': remark,
      };

  factory ReimbursementItem.fromJson(Map<String, dynamic> json) =>
      ReimbursementItem(
        id: json['id']?.toString(),
        name: (json['name'] as String?) ?? '',
        amount: (json['amount'] as num? ?? 0).toDouble(),
        remark: json['remark'] as String?,
      );
}

/// 一条报销单。
class Reimbursement {
  const Reimbursement({
    required this.id,
    this.applicantName = '',
    this.campusName = '',
    required this.title,
    this.category = '',
    required this.amount,
    this.reason = '',
    this.status = ReimbursementStatus.pending,
    this.approverName,
    this.approveComment,
    this.approveTime,
    this.createTime,
    this.items = const <ReimbursementItem>[],
  });

  final String id;
  final String applicantName;
  final String campusName;
  final String title;
  final String category;
  final double amount;
  final String reason;
  final ReimbursementStatus status;
  final String? approverName;
  final String? approveComment;
  final DateTime? approveTime;
  final DateTime? createTime;
  final List<ReimbursementItem> items;

  String get amountText => '¥${amount.toStringAsFixed(2)}';

  /// 申请提交时的请求体（仅含教师填写部分）。
  Map<String, dynamic> toApplyJson() => <String, dynamic>{
        'title': title,
        'category': category,
        'reason': reason,
        'items': items.map((ReimbursementItem e) => e.toJson()).toList(),
      };

  Reimbursement copyWith({
    String? id,
    String? applicantName,
    String? campusName,
    String? title,
    String? category,
    double? amount,
    String? reason,
    ReimbursementStatus? status,
    String? approverName,
    String? approveComment,
    DateTime? approveTime,
    DateTime? createTime,
    List<ReimbursementItem>? items,
  }) =>
      Reimbursement(
        id: id ?? this.id,
        applicantName: applicantName ?? this.applicantName,
        campusName: campusName ?? this.campusName,
        title: title ?? this.title,
        category: category ?? this.category,
        amount: amount ?? this.amount,
        reason: reason ?? this.reason,
        status: status ?? this.status,
        approverName: approverName ?? this.approverName,
        approveComment: approveComment ?? this.approveComment,
        approveTime: approveTime ?? this.approveTime,
        createTime: createTime ?? this.createTime,
        items: items ?? this.items,
      );

  factory Reimbursement.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawItems = (json['items'] as List?) ?? <dynamic>[];
    final List<ReimbursementItem> items = rawItems
        .map((dynamic e) =>
            ReimbursementItem.fromJson(e as Map<String, dynamic>))
        .toList();
    final double sum = items.fold<double>(
      0,
      (double acc, ReimbursementItem e) => acc + e.amount,
    );
    return Reimbursement(
      id: json['id']?.toString() ?? '',
      applicantName: json['applicantName'] as String? ?? '',
      campusName: json['campusName'] as String? ?? '',
      title: (json['title'] as String?) ?? '',
      category: (json['category'] as String?) ?? '',
      amount: (json['amount'] as num? ?? sum).toDouble(),
      reason: json['reason'] as String? ?? '',
      status: ReimbursementStatus.fromCode(json['status'] as int?),
      approverName: json['approverName'] as String?,
      approveComment: json['approveComment'] as String?,
      approveTime: json['approveTime'] == null
          ? null
          : DateTime.tryParse(json['approveTime'].toString()),
      createTime: json['createTime'] == null
          ? null
          : DateTime.tryParse(json['createTime'].toString()),
      items: items,
    );
  }
}
