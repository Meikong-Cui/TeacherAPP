import 'package:teacher_app/data/models/rehab.dart';

export 'package:teacher_app/data/models/rehab.dart' show SealStatus;

DateTime? _dt(dynamic v) =>
    v == null ? null : DateTime.tryParse(v.toString());

/// 公章使用申请（教师申请 → 园长/管理员/财务审批）。
/// 字段对齐后端 SealApproval：用途、使用日期、状态、审批人/意见等。
class SealApproval {
  const SealApproval({
    required this.id,
    this.applicantName = '',
    this.purpose = '',
    this.useDate,
    this.filePath,
    this.status = SealStatus.pending,
    this.reviewerName,
    this.reviewComment,
    this.reviewedAt,
    this.campusName,
    this.createTime,
  });

  final String id;
  final String applicantName;
  final String purpose;
  final DateTime? useDate;
  final String? filePath;
  final SealStatus status;
  final String? reviewerName;
  final String? reviewComment;
  final DateTime? reviewedAt;
  final String? campusName;
  final DateTime? createTime;

  factory SealApproval.fromJson(Map<String, dynamic> j) => SealApproval(
        id: j['id']?.toString() ?? '',
        applicantName: (j['applicantName'] as String?) ?? '',
        purpose: (j['purpose'] as String?) ?? '',
        useDate: _dt(j['useDate']),
        filePath: j['filePath'] as String?,
        status: SealStatus.fromCode(j['status'] as int?),
        reviewerName: j['reviewerName'] as String?,
        reviewComment: j['reviewComment'] as String?,
        reviewedAt: _dt(j['reviewedAt']),
        campusName: j['campusName'] as String?,
        createTime: _dt(j['createTime']),
      );

  /// 提交申请时的请求体（申请人/审批人由后端按 JWT 填充）。
  Map<String, dynamic> toApplyJson() => <String, dynamic>{
        'purpose': purpose,
        if (useDate != null)
          'useDate': useDate!.toIso8601String().split('T').first,
        if (filePath != null && filePath!.isNotEmpty) 'filePath': filePath,
      };
}

/// 待我审批列表的精简视图（复用 SealApproval）。
extension SealApprovalCopy on SealApproval {
  SealApproval copyWith({
    String? applicantName,
    String? purpose,
    DateTime? useDate,
    String? filePath,
    SealStatus? status,
    String? reviewerName,
    String? reviewComment,
  }) =>
      SealApproval(
        id: id,
        applicantName: applicantName ?? this.applicantName,
        purpose: purpose ?? this.purpose,
        useDate: useDate ?? this.useDate,
        filePath: filePath ?? this.filePath,
        status: status ?? this.status,
        reviewerName: reviewerName ?? this.reviewerName,
        reviewComment: reviewComment ?? this.reviewComment,
        reviewedAt: reviewedAt,
        campusName: campusName,
        createTime: createTime,
      );
}
