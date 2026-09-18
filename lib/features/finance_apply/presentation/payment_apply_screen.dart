import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:teacher_app/app/design_tokens.dart';
import 'package:teacher_app/core/api_client.dart';
import 'package:teacher_app/core/auth_store.dart';
import 'package:teacher_app/features/finance_apply/data/finance_apply_repository.dart';
import 'package:teacher_app/shared/attachment_gallery.dart';
import 'package:teacher_app/shared/ui.dart';

/// 请款申请与管理（教师端）。
///
/// 两个 Tab：**我要申请** / **我的请款**。
/// 审批链：申请人 → 财务审批 → 园长审批 → 出纳付款（后端 oa-workflow 驱动）。
///
/// 注意：请款单**没有金额字段** —— 金额在「购买凭证 / 支付记录」图片里，
/// 所以凭证是必填项，少了它审批人根本没法判断金额。
class PaymentApplyScreen extends StatefulWidget {
  const PaymentApplyScreen({super.key});

  @override
  State<PaymentApplyScreen> createState() => _PaymentApplyScreenState();
}

class _PaymentApplyScreenState extends State<PaymentApplyScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 2, vsync: this);
  final FinanceApplyRepository _repo = const FinanceApplyRepository();
  final ImagePicker _picker = ImagePicker();

  final TextEditingController _purposeController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  bool _booting = true;
  List<CampusOption> _campusOptions = <CampusOption>[];
  List<String> _feeTypes = <String>[];
  int? _campusId;
  String? _feeType;
  DateTime _applyDate = DateTime.now();
  final List<String> _attachments = <String>[];
  bool _uploading = false;
  bool _submitting = false;

  bool _mineLoading = true;
  String? _mineError;
  List<FinancePaymentApply> _mine = <FinancePaymentApply>[];

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _tab.dispose();
    _purposeController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    List<CampusOption> campuses = <CampusOption>[];
    try {
      campuses = await _repo.listCampuses();
    } catch (_) {
      // 静默降级：园区列表拉不到时仍可用登录态里的 campusId 提交
    }
    final List<String> feeTypes = await _repo.paymentFeeTypes();
    final int? myCampus = int.tryParse(AuthStore.instance.campusId ?? '');
    if (!mounted) return;
    setState(() {
      _campusOptions = campuses;
      _feeTypes = feeTypes;
      _feeType = _feeType ?? (feeTypes.isNotEmpty ? feeTypes.first : null);
      _campusId = _campusId ??
          myCampus ??
          (campuses.isNotEmpty ? campuses.first.id : null);
      _booting = false;
    });
    await _loadMine();
  }

  Future<void> _loadMine() async {
    setState(() {
      _mineLoading = true;
      _mineError = null;
    });
    try {
      final List<FinancePaymentApply> list = await _repo.listMyPayments();
      if (!mounted) return;
      setState(() {
        _mine = list;
        _mineLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _mineError = '加载失败：$e';
        _mineLoading = false;
      });
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _pickAttachment(ImageSource source) async {
    XFile? file;
    try {
      file = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 2200,
      );
    } catch (e) {
      _toast('打开相机/相册失败：$e');
      return;
    }
    if (file == null) return;
    setState(() => _uploading = true);
    try {
      final String url = await apiClient.uploadImage(file.path);
      if (!mounted) return;
      setState(() => _attachments.add(url));
    } catch (e) {
      if (mounted) _toast('上传失败：$e');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _applyDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) setState(() => _applyDate = picked);
  }

  Future<void> _submit() async {
    if (_campusId == null) {
      _toast('未获取到所属园所，请检查网络后重试');
      return;
    }
    if (_feeType == null || _feeType!.isEmpty) {
      _toast('请选择费用类型');
      return;
    }
    final String purpose = _purposeController.text.trim();
    if (purpose.isEmpty) {
      _toast('请填写请款用途详细说明');
      return;
    }
    if (_attachments.isEmpty) {
      _toast('请上传购买凭证 / 支付记录（金额在凭证里，必填）');
      return;
    }

    setState(() => _submitting = true);
    try {
      await _repo.applyPayment(<String, dynamic>{
        'campusId': _campusId,
        'applyDate': _fmtDate(_applyDate),
        'contactPhone': _phoneController.text.trim(),
        'feeType': _feeType,
        'purpose': purpose,
        'attachments': _attachments,
      });
      if (!mounted) return;
      _toast('已提交，等待财务审批 → 园长审批');
      _purposeController.clear();
      setState(() {
        _attachments.clear();
        _submitting = false;
      });
      _tab.animateTo(1);
      await _loadMine();
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _toast('提交失败：$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('请款申请'),
        actions: const <Widget>[ThemeToggleButton()],
        bottom: TabBar(
          controller: _tab,
          tabs: const <Widget>[
            Tab(text: '我要申请'),
            Tab(text: '我的请款'),
          ],
        ),
      ),
      body: _booting
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tab,
              children: <Widget>[
                _buildForm(textTheme),
                _buildMine(textTheme),
              ],
            ),
      // 提交按钮钉在底部：表单较长，不能在末尾还要滚到底才找得到
      bottomNavigationBar: AnimatedBuilder(
        animation: _tab,
        builder: (BuildContext ctx, Widget? _) => _tab.index != 0
            ? const SizedBox.shrink()
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: _submitting ? null : _submit,
                      child: _submitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('提交申请'),
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildForm(TextTheme textTheme) {
    final String campusName = _campusOptions
        .where((CampusOption c) => c.id == _campusId)
        .map((CampusOption c) => c.name)
        .join();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: <Widget>[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const AppSectionTitle('请款信息'),
                if (_campusOptions.isEmpty)
                  InfoRow(
                    label: '所属园所',
                    value: campusName.isEmpty ? '（按登录校区提交）' : campusName,
                  )
                else
                  DropdownButtonFormField<int>(
                    initialValue: _campusId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: '所属园所'),
                    items: _campusOptions
                        .map((CampusOption c) => DropdownMenuItem<int>(
                              value: c.id,
                              child: Text(c.name),
                            ))
                        .toList(),
                    onChanged: (int? v) => setState(() => _campusId = v),
                  ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _feeType,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: '费用类型'),
                  items: _feeTypes
                      .map((String t) => DropdownMenuItem<String>(
                            value: t,
                            child: Text(t),
                          ))
                      .toList(),
                  onChanged: (String? v) => setState(() => _feeType = v),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: _pickDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: '申请日期'),
                    child: Text(_fmtDate(_applyDate)),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: '联系电话',
                    hintText: '选填',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _purposeController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: '请款用途详细说明',
                    hintText: '如：购买感统训练垫 2 张（规格 1.2m×2m）',
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                AppSectionTitle(
                  '购买凭证 / 支付记录（必填）',
                  action: Text('${_attachments.length} 张',
                      style: textTheme.bodySmall
                          ?.copyWith(color: AppPalette.inkMute)),
                ),
                Text(
                  '请款单不设金额字段，金额以凭证图片为准 —— 审批人只能靠这张图核对，请拍清楚。',
                  style: textTheme.bodySmall
                      ?.copyWith(color: AppPalette.inkMute),
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    OutlinedButton.icon(
                      onPressed:
                          _uploading ? null : () => _pickAttachment(ImageSource.camera),
                      icon: const Icon(Icons.photo_camera_outlined, size: 18),
                      label: const Text('拍照'),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: _uploading
                          ? null
                          : () => _pickAttachment(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_outlined, size: 18),
                      label: const Text('相册'),
                    ),
                    const SizedBox(width: 10),
                    if (_uploading)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
                if (_attachments.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 12),
                  AttachmentGallery(
                    urls: _attachments,
                    label: '已上传凭证',
                    thumbSize: 88,
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: _attachments.isEmpty
                          ? null
                          : () => setState(() => _attachments.removeLast()),
                      icon: const Icon(Icons.undo, size: 16),
                      label: const Text('撤销最后一张'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '提交后将依次进入「财务审批 → 园长审批」，通过后由出纳付款。',
          style: textTheme.bodySmall,
        ),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildMine(TextTheme textTheme) {
    if (_mineLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_mineError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(_mineError!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.tonal(onPressed: _loadMine, child: const Text('重试')),
            ],
          ),
        ),
      );
    }
    if (_mine.isEmpty) {
      return const Center(
        child: Text('还没有请款记录', style: TextStyle(color: AppPalette.inkMute)),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadMine,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: _mine.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (BuildContext ctx, int i) {
          final FinancePaymentApply it = _mine[i];
          return SoftCard(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            onTap: () => _showDetail(it),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        it.feeType ?? '请款单',
                        style: textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    StatusChip(it.statusLabel),
                    if (it.paid)
                      const Padding(
                        padding: EdgeInsets.only(left: 6),
                        child: StatusChip('已付款'),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  it.purpose ?? '—',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall,
                ),
                const SizedBox(height: 6),
                Text(
                  '${it.applyNo ?? ''} · ${it.attachmentCount} 张凭证 · '
                  '${_short(it.createTime)}',
                  style: textTheme.bodySmall
                      ?.copyWith(color: AppPalette.inkMute),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _short(String? t) {
    if (t == null || t.length < 16) return t ?? '—';
    return t.replaceFirst('T', ' ').substring(0, 16);
  }

  Future<void> _showDetail(FinancePaymentApply it) async {
    final TextTheme textTheme = Theme.of(context).textTheme;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      '请款单 ${it.applyNo ?? ''}',
                      style: textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  StatusChip(it.statusLabel),
                ],
              ),
              const SizedBox(height: 8),
              InfoRow(label: '费用类型', value: it.feeType ?? '—'),
              InfoRow(label: '所属园所', value: it.campusName ?? '—'),
              InfoRow(label: '申请人', value: it.applicantName ?? '—'),
              InfoRow(label: '申请日期', value: it.applyDate ?? '—'),
              InfoRow(
                label: '付款状态',
                value: it.paid ? '已付款 ${it.payDate ?? ''}' : '待付款',
              ),
              if (it.approveComment != null &&
                  it.approveComment!.isNotEmpty)
                InfoRow(label: '审批意见', value: it.approveComment!),
              const Divider(height: 24),
              Text('请款用途',
                  style: textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(it.purpose ?? '—', style: textTheme.bodyMedium),
              const Divider(height: 24),
              AttachmentGallery(urls: it.attachments, label: '购买凭证'),
            ],
          ),
        ),
      ),
    );
  }
}
