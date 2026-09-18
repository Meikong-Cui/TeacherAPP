import 'package:teacher_app/core/api_client.dart';
import 'package:teacher_app/core/constants.dart';

/// 请款申请单（对应「请款单(2).docx」）。
///
/// **刻意不含金额字段** —— 金额在 [attachments] 的凭证图片里，
/// 审批人看图为唯一依据；因此凭证必填，列表与统计也只按单数/类型/园所归集。
class FinancePaymentApply {
  const FinancePaymentApply({
    required this.id,
    this.applyNo,
    this.campusName,
    this.applicantName,
    this.contactPhone,
    this.applyDate,
    this.feeType,
    this.purpose,
    this.attachments = const <String>[],
    this.attachmentCount = 0,
    this.status = 1,
    this.approverName,
    this.approveComment,
    this.approveTime,
    this.payStatus = 0,
    this.payDate,
    this.createTime,
  });

  final int id;
  final String? applyNo;
  final String? campusName;
  final String? applicantName;
  final String? contactPhone;
  final String? applyDate;
  final String? feeType;
  final String? purpose;
  final List<String> attachments;
  final int attachmentCount;
  final int status;
  final String? approverName;
  final String? approveComment;
  final String? approveTime;
  final int payStatus;
  final String? payDate;
  final String? createTime;

  factory FinancePaymentApply.fromJson(Map<String, dynamic> j) =>
      FinancePaymentApply(
        id: (j['id'] as num?)?.toInt() ?? 0,
        applyNo: j['applyNo'] as String?,
        campusName: j['campusName'] as String?,
        applicantName: j['applicantName'] as String?,
        contactPhone: j['contactPhone'] as String?,
        applyDate: j['applyDate']?.toString(),
        feeType: j['feeType'] as String?,
        purpose: j['purpose'] as String?,
        attachments: _stringList(j['attachments']),
        attachmentCount:
            (j['attachmentCount'] as num?)?.toInt() ?? _stringList(j['attachments']).length,
        status: (j['status'] as num?)?.toInt() ?? 1,
        approverName: j['approverName'] as String?,
        approveComment: j['approveComment'] as String?,
        approveTime: j['approveTime']?.toString(),
        payStatus: (j['payStatus'] as num?)?.toInt() ?? 0,
        payDate: j['payDate']?.toString(),
        createTime: j['createTime']?.toString(),
      );

  String get statusLabel => financeStatusLabel(status);
  bool get paid => payStatus == 1;
  bool get pending => status == 1;
}

/// 开票审批单（对应「申请开票的模板.docx」）。
class FinanceInvoiceApply {
  const FinanceInvoiceApply({
    required this.id,
    this.applyNo,
    this.campusName,
    this.applicantName,
    this.contactPhone,
    this.applyDate,
    this.businessType,
    this.projectName,
    this.contractAmount,
    this.invoicedAmount,
    this.invoiceInfo,
    this.invoiceRemark,
    this.currentAmount,
    this.invoiceKind,
    this.attachments = const <String>[],
    this.status = 1,
    this.approverName,
    this.approveComment,
    this.approveTime,
    this.invoiceNo,
    this.invoiceDate,
    this.createTime,
    this.remainAfter,
    this.duplicateHits = const <Map<String, dynamic>>[],
    this.duplicateRisk = false,
  });

  final int id;
  final String? applyNo;
  final String? campusName;
  final String? applicantName;
  final String? contactPhone;
  final String? applyDate;
  final String? businessType;
  final String? projectName;
  final num? contractAmount;
  final num? invoicedAmount;
  final String? invoiceInfo;
  final String? invoiceRemark;
  final num? currentAmount;
  final String? invoiceKind;
  final List<String> attachments;
  final int status;
  final String? approverName;
  final String? approveComment;
  final String? approveTime;
  final String? invoiceNo;
  final String? invoiceDate;
  final String? createTime;

  /// 剩余可开票额度 = 合同金额 − 累计开票金额 − 本次开票金额（可能为负）。
  final num? remainAfter;

  /// 疑似重复开票的历史记录（同园所 + 同项目名称 + 同本次开票金额，且已通过）。
  final List<Map<String, dynamic>> duplicateHits;

  /// 是否命中重复开票风险。
  final bool duplicateRisk;

  factory FinanceInvoiceApply.fromJson(Map<String, dynamic> j) =>
      FinanceInvoiceApply(
        id: (j['id'] as num?)?.toInt() ?? 0,
        applyNo: j['applyNo'] as String?,
        campusName: j['campusName'] as String?,
        applicantName: j['applicantName'] as String?,
        contactPhone: j['contactPhone'] as String?,
        applyDate: j['applyDate']?.toString(),
        businessType: j['businessType'] as String?,
        projectName: j['projectName'] as String?,
        contractAmount: j['contractAmount'] as num?,
        invoicedAmount: j['invoicedAmount'] as num?,
        invoiceInfo: j['invoiceInfo'] as String?,
        invoiceRemark: j['invoiceRemark'] as String?,
        currentAmount: j['currentAmount'] as num?,
        invoiceKind: j['invoiceKind'] as String?,
        attachments: _stringList(j['attachments']),
        status: (j['status'] as num?)?.toInt() ?? 1,
        approverName: j['approverName'] as String?,
        approveComment: j['approveComment'] as String?,
        approveTime: j['approveTime']?.toString(),
        invoiceNo: j['invoiceNo'] as String?,
        invoiceDate: j['invoiceDate']?.toString(),
        createTime: j['createTime']?.toString(),
        remainAfter: j['remainAfter'] as num?,
        duplicateHits: _mapList(j['duplicateHits']),
        duplicateRisk: j['duplicateRisk'] == true,
      );

  String get statusLabel => financeStatusLabel(status);
  bool get pending => status == 1;
}

String financeStatusLabel(int? status) {
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

/// 金额展示：¥1,234.00。
String moneyText(num? v) {
  final double d = (v ?? 0).toDouble();
  final String fixed = d.toStringAsFixed(2);
  final int dot = fixed.indexOf('.');
  final String intPart = fixed.substring(0, dot);
  final String decPart = fixed.substring(dot);
  final StringBuffer buf = StringBuffer();
  for (int i = 0; i < intPart.length; i++) {
    if (i > 0 && (intPart.length - i) % 3 == 0) buf.write(',');
    buf.write(intPart[i]);
  }
  return '¥$buf$decPart';
}

List<String> _stringList(dynamic raw) {
  if (raw is! List) return const <String>[];
  return raw
      .map((dynamic e) => e?.toString() ?? '')
      .where((String e) => e.isNotEmpty)
      .toList();
}

List<Map<String, dynamic>> _mapList(dynamic raw) {
  if (raw is! List) return const <Map<String, dynamic>>[];
  return raw
      .whereType<Map>()
      .map((Map e) => Map<String, dynamic>.from(e))
      .toList();
}

/// 校区选项（请款/开票都要选所属园所，后端 campusId 为必填）。
class CampusOption {
  const CampusOption({required this.id, required this.name});

  final int id;
  final String name;
}

/// 请款 / 开票数据层（真实对接后端 oa-fund 模块的
/// /api/finance/payment-apply 与 /api/finance/invoice-apply）。
class FinanceApplyRepository {
  const FinanceApplyRepository();

  static const String _paymentBase = AppConstants.paymentApplyPath;
  static const String _invoiceBase = AppConstants.invoiceApplyPath;

  // ───────────── 请款 ─────────────

  Future<List<FinancePaymentApply>> listMyPayments() async {
    final dynamic data = await apiClient.get('$_paymentBase/mine');
    if (data is! List) return const <FinancePaymentApply>[];
    return data
        .whereType<Map<String, dynamic>>()
        .map(FinancePaymentApply.fromJson)
        .toList();
  }

  Future<FinancePaymentApply?> getPayment(int id) async {
    final dynamic data = await apiClient.get('$_paymentBase/$id');
    if (data is! Map<String, dynamic>) return null;
    return FinancePaymentApply.fromJson(data);
  }

  /// 提交请款申请，返回后端主键（失败抛 [ApiException]）。
  Future<int> applyPayment(Map<String, dynamic> payload) async {
    final dynamic data = await apiClient.post(_paymentBase, payload);
    return (data is num) ? data.toInt() : int.tryParse('$data') ?? 0;
  }

  /// 费用类型候选（后端为准；失败时返回内置 8 类，保证下拉始终可用）。
  Future<List<String>> paymentFeeTypes() async {
    try {
      final dynamic data = await apiClient.get('$_paymentBase/fee-types');
      if (data is List && data.isNotEmpty) {
        return data.map((dynamic e) => e.toString()).toList();
      }
    } catch (_) {
      // 静默降级：离线或后端未就绪时仍能填表
    }
    return const <String>[
      '办公用品采购',
      '教学用品采购',
      '后勤物品采购',
      '食堂用品采购',
      '固定资产采购',
      '劳务费用',
      '活动经费',
      '其他未分类',
    ];
  }

  // ───────────── 开票 ─────────────

  Future<List<FinanceInvoiceApply>> listMyInvoices() async {
    final dynamic data = await apiClient.get('$_invoiceBase/mine');
    if (data is! List) return const <FinanceInvoiceApply>[];
    return data
        .whereType<Map<String, dynamic>>()
        .map(FinanceInvoiceApply.fromJson)
        .toList();
  }

  Future<FinanceInvoiceApply?> getInvoice(int id) async {
    final dynamic data = await apiClient.get('$_invoiceBase/$id');
    if (data is! Map<String, dynamic>) return null;
    return FinanceInvoiceApply.fromJson(data);
  }

  Future<int> applyInvoice(Map<String, dynamic> payload) async {
    final dynamic data = await apiClient.post(_invoiceBase, payload);
    return (data is num) ? data.toInt() : int.tryParse('$data') ?? 0;
  }

  // ───────────── 公共 ─────────────

  /// 所属园所列表（后端 /api/system/campuses 返回分页体 {records, total}）。
  Future<List<CampusOption>> listCampuses() async {
    final dynamic data = await apiClient
        .get('/api/system/campuses', params: <String, dynamic>{'current': 1, 'size': 200});
    final dynamic records = (data is Map) ? data['records'] : data;
    if (records is! List) return const <CampusOption>[];
    return records
        .whereType<Map>()
        .map((Map e) => CampusOption(
              id: (e['id'] as num?)?.toInt() ?? 0,
              name: (e['name'] ?? '').toString(),
            ))
        .where((CampusOption c) => c.id > 0)
        .toList();
  }
}
