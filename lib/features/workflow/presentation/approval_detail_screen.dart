import 'package:flutter/material.dart';
import 'package:teacher_app/app/design_tokens.dart';
import 'package:teacher_app/data/models/reimbursement.dart';
import 'package:teacher_app/features/finance_apply/data/finance_apply_repository.dart';
import 'package:teacher_app/features/reimbursement/data/reimbursement_repository.dart';
import 'package:teacher_app/features/workflow/workflow_repository.dart';
import 'package:teacher_app/shared/attachment_gallery.dart';
import 'package:teacher_app/shared/ui.dart';

/// 审批详情页（审批人视角）。
///
/// 为什么必须单独有这一页：原来审批列表卡片上直接放「通过 / 驳回」两个按钮，
/// 审批人**看不到附件图片**就按了通过 —— 而请款单、报销单的金额恰恰只在凭证图里。
/// 所以现在卡片只留一个「查看详情」，进来后能看到：
///   业务单据全字段 → 凭证/材料大图（可双指放大）→ 流程轨迹 → 才决定通过还是驳回。
///
/// 业务详情按 `instance.businessType` 分派；未接入的类型降级展示发起时填的表单值，
/// 不会出现"什么都没有"的空页。
class ApprovalDetailScreen extends StatefulWidget {
  const ApprovalDetailScreen({
    super.key,
    required this.instance,
    this.canApprove = true,
  });

  final WorkflowInstance instance;

  /// 是否显示底部审批条（待办列表进来时为 true；已办/查看历史时为 false）。
  final bool canApprove;

  @override
  State<ApprovalDetailScreen> createState() => _ApprovalDetailScreenState();
}

class _ApprovalDetailScreenState extends State<ApprovalDetailScreen> {
  final WorkflowRepository _wf = WorkflowRepository();
  final FinanceApplyRepository _finance = const FinanceApplyRepository();
  final ReimbursementRepository _reimb = const ReimbursementRepository();

  bool _loading = true;
  bool _acting = false;
  String? _error;
  Object? _detail;
  String? _detailKind;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final String? type = widget.instance.businessType;
    final int? id = widget.instance.businessId;
    if (type == null || type.isEmpty || id == null || id <= 0) {
      setState(() {
        _loading = false;
        _detail = null;
        _detailKind = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      Object? d;
      switch (type) {
        case 'finance_payment_apply':
          d = await _finance.getPayment(id);
          break;
        case 'finance_invoice_apply':
          d = await _finance.getInvoice(id);
          break;
        case 'reimbursement':
          d = await _reimb.getById('$id');
          break;
        default:
          d = null;
      }
      if (!mounted) return;
      setState(() {
        _detail = d;
        _detailKind = d == null ? null : type;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '业务单据加载失败：$e';
        _loading = false;
      });
    }
  }

  /// 弹出审批意见；[required] 为 true 时不允许空内容（驳回必须写原因）。
  /// 返回 null 表示用户取消。
  Future<String?> _askComment({required bool required}) async {
    final TextEditingController ctl = TextEditingController();
    final String? result = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(required ? '驳回原因（必填）' : '审批意见（选填）'),
        content: TextField(
          controller: ctl,
          maxLines: 3,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '请输入…',
            border: OutlineInputBorder(),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final String v = ctl.text.trim();
              if (required && v.isEmpty) return;
              Navigator.pop(ctx, v.isEmpty ? '' : v);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
    ctl.dispose();
    return result;
  }

  Future<void> _act({required bool pass}) async {
    final String? comment = await _askComment(required: !pass);
    if (comment == null) return; // 用户取消
    if (!mounted) return;
    setState(() => _acting = true);
    try {
      if (pass) {
        await _wf.approve(widget.instance.id, comment.isEmpty ? null : comment);
      } else {
        await _wf.reject(widget.instance.id, comment);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(pass ? '已通过' : '已驳回')),
      );
      Navigator.of(context).pop(true); // 通知列表刷新
    } catch (e) {
      if (!mounted) return;
      setState(() => _acting = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('操作失败：$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final WorkflowInstance it = widget.instance;
    final bool showBar = widget.canApprove && it.pending;

    return Scaffold(
      appBar: AppBar(
        title: Text(it.templateName ?? '审批详情'),
        actions: const <Widget>[ThemeToggleButton()],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: <Widget>[
                _headerCard(textTheme),
                const SizedBox(height: 12),
                _businessCard(textTheme),
                const SizedBox(height: 12),
                _traceCard(textTheme),
                const SizedBox(height: 16),
              ],
            ),
      bottomNavigationBar: !showBar
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _acting
                            ? null
                            : () => _act(pass: false),
                        child: const Text('驳回'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        onPressed: _acting ? null : () => _act(pass: true),
                        child: _acting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('通过'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  // ══════════════ 顶部流程信息 ══════════════

  Widget _headerCard(TextTheme textTheme) {
    final WorkflowInstance it = widget.instance;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    it.summaryText,
                    style: textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                StatusChip(it.statusLabel),
              ],
            ),
            const SizedBox(height: 10),
            InfoRow(label: '流程', value: it.templateName ?? '—'),
            InfoRow(label: '申请人', value: it.applicantName ?? '—'),
            InfoRow(label: '当前节点', value: it.currentNodeName ?? '—'),
            InfoRow(label: '单号', value: it.instanceNo ?? '—'),
            InfoRow(label: '提交时间', value: _short(it.createTime)),
          ],
        ),
      ),
    );
  }

  // ══════════════ 业务单据详情 ══════════════

  Widget _businessCard(TextTheme textTheme) {
    if (widget.instance.businessType == null ||
        widget.instance.businessType!.isEmpty) {
      return const SizedBox.shrink();
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            AppSectionTitle(
              '单据详情（${_kindLabel(widget.instance.businessType)}）',
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_error!,
                    style: textTheme.bodySmall
                        ?.copyWith(color: AppPalette.danger)),
              ),
            if (!_loading && _detail == null && _error == null) ...<Widget>[
              Text(
                '该审批未接入业务单据详情，以下为发起时填写的内容：',
                style: textTheme.bodySmall
                    ?.copyWith(color: AppPalette.inkMute),
              ),
              const SizedBox(height: 8),
              ..._formValueRows(textTheme),
            ],
            if (_detailKind == 'finance_payment_apply')
              _paymentDetail(_detail! as FinancePaymentApply, textTheme),
            if (_detailKind == 'finance_invoice_apply')
              _invoiceDetail(_detail! as FinanceInvoiceApply, textTheme),
            if (_detailKind == 'reimbursement')
              _reimbursementDetail(_detail! as Reimbursement, textTheme),
          ],
        ),
      ),
    );
  }

  String _kindLabel(String? type) {
    switch (type) {
      case 'finance_payment_apply':
        return '请款申请单';
      case 'finance_invoice_apply':
        return '开票审批单';
      case 'reimbursement':
        return '报销单';
      case 'salary_approval':
        return '月度工资表';
      case 'child_fee_refund':
        return '退费单';
      default:
        return type ?? '单据';
    }
  }

  List<Widget> _formValueRows(TextTheme textTheme) {
    final Map<String, dynamic> fv = widget.instance.formValues;
    if (fv.isEmpty) {
      return <Widget>[
        Text('—', style: textTheme.bodySmall),
      ];
    }
    return fv.entries
        .map((MapEntry<String, dynamic> e) =>
            InfoRow(label: e.key, value: '${e.value ?? '—'}'))
        .toList();
  }

  /// 请款单：**凭证图置顶**，因为金额只在图里。
  Widget _paymentDetail(FinancePaymentApply d, TextTheme textTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppPalette.info.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Icon(Icons.info_outline, size: 18, color: AppPalette.info),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '请款单不设金额字段 —— 金额以「购买凭证 / 支付记录」图片为准，'
                  '请点开下方凭证放大核对后再审批。',
                  style: textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
        InfoRow(label: '费用类型', value: d.feeType ?? '—'),
        InfoRow(label: '所属园所', value: d.campusName ?? '—'),
        InfoRow(label: '联系电话', value: d.contactPhone ?? '—'),
        InfoRow(label: '申请日期', value: d.applyDate ?? '—'),
        InfoRow(
          label: '付款状态',
          value: d.paid ? '已付款 ${d.payDate ?? ''}' : '待付款',
        ),
        const Divider(height: 24),
        Text('请款用途详细说明',
            style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(d.purpose ?? '—', style: textTheme.bodyMedium),
        const Divider(height: 24),
        AttachmentGallery(
          urls: d.attachments,
          label: '购买凭证 / 支付记录',
          emptyText: '本单没有上传凭证（异常，建议驳回并让申请人补充）',
        ),
      ],
    );
  }

  /// 开票单：**重复开票告警放在最顶部**，审批人往下看之前就该看到。
  Widget _invoiceDetail(FinanceInvoiceApply d, TextTheme textTheme) {
    final double? remain = d.remainAfter?.toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _duplicateAlert(d, textTheme),
        if (remain != null && remain < 0)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppPalette.warning.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Text(
              '本次开票后累计开票金额将超出合同金额 ${moneyText(remain.abs())}，请核实',
              style: textTheme.bodySmall
                  ?.copyWith(color: AppPalette.warning),
            ),
          ),
        InfoRow(label: '所属园所', value: d.campusName ?? '—'),
        InfoRow(label: '对应业务', value: d.businessType ?? '—'),
        InfoRow(label: '发票类型', value: d.invoiceKind ?? '—'),
        InfoRow(label: '项目名称', value: d.projectName ?? '—'),
        InfoRow(label: '合同金额', value: moneyText(d.contractAmount)),
        InfoRow(label: '累计开票（不含本次）', value: moneyText(d.invoicedAmount)),
        InfoRow(label: '本次开票金额', value: moneyText(d.currentAmount)),
        if (remain != null)
          InfoRow(
            label: '剩余可开票',
            value: remain < 0 ? '已超额 ${moneyText(remain.abs())}' : moneyText(remain),
          ),
        InfoRow(label: '发票号', value: d.invoiceNo ?? '待会计开票登记'),
        InfoRow(label: '开票日期', value: d.invoiceDate ?? '—'),
        if (d.invoiceInfo != null && d.invoiceInfo!.isNotEmpty) ...<Widget>[
          const Divider(height: 24),
          Text('开票信息',
              style:
                  textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(d.invoiceInfo!, style: textTheme.bodyMedium),
        ],
        if (d.invoiceRemark != null && d.invoiceRemark!.isNotEmpty) ...<Widget>[
          const SizedBox(height: 8),
          InfoRow(label: '开票备注', value: d.invoiceRemark!),
        ],
        const Divider(height: 24),
        AttachmentGallery(
          urls: d.attachments,
          label: '合同信息等材料',
          emptyText: '无材料附件',
        ),
      ],
    );
  }

  Widget _duplicateAlert(FinanceInvoiceApply d, TextTheme textTheme) {
    if (!d.duplicateRisk || d.duplicateHits.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppPalette.success.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Icon(Icons.verified_outlined,
                size: 18, color: AppPalette.success),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '重复开票校验通过：已通过的开票记录中，没有与本单「园所 + 项目名称 + 本次开票金额」一致的单据。',
                style: textTheme.bodySmall,
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppPalette.danger.withValues(alpha: 0.12),
        border: Border.all(color: AppPalette.danger, width: 1.2),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.warning_amber_rounded,
                  color: AppPalette.danger, size: 20),
              const SizedBox(width: 6),
              Text(
                '疑似重复开票 · 请核实后再审批',
                style: textTheme.bodyMedium?.copyWith(
                  color: AppPalette.danger,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '已通过的开票记录中有 ${d.duplicateHits.length} 条与本单'
            '同园所、同项目名称、同本次开票金额：',
            style: textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          ...d.duplicateHits.map((Map<String, dynamic> hit) => Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '原单 ${hit['applyNo'] ?? '—'} · ${moneyText(hit['currentAmount'] as num?)}',
                      style: textTheme.bodySmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${hit['campusName'] ?? '—'} · ${hit['applicantName'] ?? '—'} · '
                      '发票号 ${hit['invoiceNo'] ?? '未登记'} · '
                      '通过于 ${_short(hit['approveTime']?.toString())}',
                      style: textTheme.bodySmall
                          ?.copyWith(color: AppPalette.inkMute),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _reimbursementDetail(Reimbursement d, TextTheme textTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        InfoRow(label: '申请人', value: d.applicantName),
        InfoRow(label: '所属校区', value: d.campusName),
        InfoRow(label: '报销类别', value: d.category),
        InfoRow(label: '报销金额', value: d.amountText),
        if (d.items.isNotEmpty) ...<Widget>[
          const Divider(height: 24),
          Text('费用明细（${d.items.length} 项）',
              style:
                  textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          ...d.items.asMap().entries.map((MapEntry<int, ReimbursementItem> e) =>
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${e.key + 1}. ${e.value.name} —— ¥${e.value.amount.toStringAsFixed(2)}'
                  '${e.value.remark == null || e.value.remark!.isEmpty ? '' : '（${e.value.remark}）'}',
                  style: textTheme.bodySmall,
                ),
              )),
        ],
        const Divider(height: 24),
        Text('事由说明',
            style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(d.reason.isEmpty ? '—' : d.reason, style: textTheme.bodyMedium),
        const Divider(height: 24),
        AttachmentGallery(
          urls: d.photos,
          label: '原始凭证',
          emptyText: '本单没有上传凭证',
        ),
      ],
    );
  }

  // ══════════════ 流程轨迹 ══════════════

  Widget _traceCard(TextTheme textTheme) {
    final List<dynamic> logs = widget.instance.logs;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const AppSectionTitle('流程轨迹'),
            if (logs.isEmpty)
              Text('暂无流程轨迹', style: textTheme.bodySmall)
            else
              ...logs.map((dynamic raw) {
                final Map<String, dynamic> m = raw is Map
                    ? Map<String, dynamic>.from(raw)
                    : <String, dynamic>{};
                final String action = '${m['action'] ?? ''}';
                final bool rejected = action.contains('拒') || action.contains('驳回');
                final Color dot =
                    rejected ? AppPalette.danger : AppPalette.success;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: dot,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              '${m['node'] ?? '—'} · ${action.isEmpty ? '—' : action}'
                              '（${m['by'] ?? '—'}）',
                              style: textTheme.bodySmall
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            if (m['comment'] != null &&
                                m['comment'].toString().isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text('意见：${m['comment']}',
                                    style: textTheme.bodySmall),
                              ),
                            if (m['time'] != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  '${m['time']}',
                                  style: textTheme.bodySmall?.copyWith(
                                      color: AppPalette.inkMute),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  String _short(String? t) {
    if (t == null || t.isEmpty) return '—';
    if (t.length < 16 || !t.contains('T')) return t;
    return t.replaceFirst('T', ' ').substring(0, 16);
  }
}
