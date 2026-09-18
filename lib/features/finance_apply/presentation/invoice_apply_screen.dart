import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:teacher_app/app/design_tokens.dart';
import 'package:teacher_app/core/api_client.dart';
import 'package:teacher_app/core/auth_store.dart';
import 'package:teacher_app/features/finance_apply/data/finance_apply_repository.dart';
import 'package:teacher_app/shared/attachment_gallery.dart';
import 'package:teacher_app/shared/ui.dart';

/// 开票申请与管理（教师端）。
///
/// 两个 Tab：**我要申请** / **我的开票**。
/// 审批链：申请人 → 财务审批 → 园长审批，通过后由会计登记发票号与开票日期。
///
/// 系统会在**审批页面**自动比对已通过的开票记录，命中「同园所 + 同项目名称 +
/// 同本次开票金额」时给审批人红色醒目提示（疑似重复开票），本页只做本人的历史查看。
class InvoiceApplyScreen extends StatefulWidget {
  const InvoiceApplyScreen({super.key});

  @override
  State<InvoiceApplyScreen> createState() => _InvoiceApplyScreenState();
}

class _InvoiceApplyScreenState extends State<InvoiceApplyScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 2, vsync: this);
  final FinanceApplyRepository _repo = const FinanceApplyRepository();
  final ImagePicker _picker = ImagePicker();

  static const List<String> _businessTypes = <String>[
    '学员收费',
    '政府补助',
    '服务项目',
    '其他',
  ];
  static const List<String> _invoiceKinds = <String>[
    '增值税专用发票',
    '增值税普通发票',
    '电子发票',
    '收据',
  ];

  final TextEditingController _projectController = TextEditingController();
  final TextEditingController _contractController = TextEditingController();
  final TextEditingController _invoicedController = TextEditingController();
  final TextEditingController _currentController = TextEditingController();
  final TextEditingController _invoiceInfoController = TextEditingController();
  final TextEditingController _remarkController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  bool _booting = true;
  List<CampusOption> _campusOptions = <CampusOption>[];
  int? _campusId;
  String _businessType = _businessTypes.first;
  String _invoiceKind = _invoiceKinds.first;
  DateTime _applyDate = DateTime.now();
  final List<String> _attachments = <String>[];
  bool _uploading = false;
  bool _submitting = false;

  bool _mineLoading = true;
  String? _mineError;
  List<FinanceInvoiceApply> _mine = <FinanceInvoiceApply>[];

  @override
  void initState() {
    super.initState();
    _bootstrap();
    // 金额输入时实时刷新「剩余可开票额度」提示
    _currentController.addListener(_onAmountChanged);
    _contractController.addListener(_onAmountChanged);
    _invoicedController.addListener(_onAmountChanged);
  }

  @override
  void dispose() {
    _tab.dispose();
    _currentController.removeListener(_onAmountChanged);
    _contractController.removeListener(_onAmountChanged);
    _invoicedController.removeListener(_onAmountChanged);
    _projectController.dispose();
    _contractController.dispose();
    _invoicedController.dispose();
    _currentController.dispose();
    _invoiceInfoController.dispose();
    _remarkController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _onAmountChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _bootstrap() async {
    List<CampusOption> campuses = <CampusOption>[];
    try {
      campuses = await _repo.listCampuses();
    } catch (_) {
      // 静默降级：拉不到校区列表时用登录态 campusId
    }
    final int? myCampus = int.tryParse(AuthStore.instance.campusId ?? '');
    if (!mounted) return;
    setState(() {
      _campusOptions = campuses;
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
      final List<FinanceInvoiceApply> list = await _repo.listMyInvoices();
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

  /// 剩余可开票额度 = 合同金额 − 累计开票金额 − 本次开票金额（可能为负）。
  double? get _remainAfter {
    final double? contract = double.tryParse(_contractController.text.trim());
    if (contract == null) return null;
    final double invoiceBefore =
        double.tryParse(_invoicedController.text.trim()) ?? 0;
    final double current = double.tryParse(_currentController.text.trim()) ?? 0;
    return contract - invoiceBefore - current;
  }

  Future<void> _submit() async {
    if (_campusId == null) {
      _toast('未获取到所属园所，请检查网络后重试');
      return;
    }
    final String project = _projectController.text.trim();
    if (project.isEmpty) {
      _toast('请填写项目名称');
      return;
    }
    final double? current = double.tryParse(_currentController.text.trim());
    if (current == null || current <= 0) {
      _toast('请填写本次开票金额（需大于 0）');
      return;
    }
    final double? contract = double.tryParse(_contractController.text.trim());
    if (contract != null && contract < current) {
      final bool go = await _confirm(
        '本次开票金额大于合同金额，确认继续提交？',
        '合同金额 ${moneyText(contract)}，本次开票 ${moneyText(current)}。',
      );
      if (!go) return;
    }

    setState(() => _submitting = true);
    try {
      await _repo.applyInvoice(<String, dynamic>{
        'campusId': _campusId,
        'applyDate': _fmtDate(_applyDate),
        'contactPhone': _phoneController.text.trim(),
        'businessType': _businessType,
        'projectName': project,
        'contractAmount': contract,
        'invoicedAmount': double.tryParse(_invoicedController.text.trim()),
        'invoiceInfo': _invoiceInfoController.text.trim(),
        'invoiceRemark': _remarkController.text.trim(),
        'currentAmount': current,
        'invoiceKind': _invoiceKind,
        'attachments': _attachments,
      });
      if (!mounted) return;
      _toast('已提交，等待财务审批 → 园长审批');
      _projectController.clear();
      _contractController.clear();
      _invoicedController.clear();
      _currentController.clear();
      _invoiceInfoController.clear();
      _remarkController.clear();
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

  Future<bool> _confirm(String title, String content) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('再改改'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确认提交'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('开票申请'),
        actions: const <Widget>[ThemeToggleButton()],
        bottom: TabBar(
          controller: _tab,
          tabs: const <Widget>[
            Tab(text: '我要申请'),
            Tab(text: '我的开票'),
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
    final double? remain = _remainAfter;
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
                const AppSectionTitle('开票信息'),
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
                  initialValue: _businessType,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: '对应业务'),
                  items: _businessTypes
                      .map((String t) => DropdownMenuItem<String>(
                            value: t,
                            child: Text(t),
                          ))
                      .toList(),
                  onChanged: (String? v) {
                    if (v != null) setState(() => _businessType = v);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _invoiceKind,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: '发票类型'),
                  items: _invoiceKinds
                      .map((String t) => DropdownMenuItem<String>(
                            value: t,
                            child: Text(t),
                          ))
                      .toList(),
                  onChanged: (String? v) {
                    if (v != null) setState(() => _invoiceKind = v);
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _projectController,
                  decoration: const InputDecoration(
                    labelText: '项目名称',
                    hintText: '如：2026 年春季感统课程服务费',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _contractController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: '合同金额',
                    hintText: '选填；填了会实时算剩余可开票额度',
                    prefixText: '¥ ',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _invoicedController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: '累计开票金额（不含本次）',
                    hintText: '选填',
                    prefixText: '¥ ',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _currentController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: '本次开票金额',
                    prefixText: '¥ ',
                  ),
                ),
                if (remain != null) ...<Widget>[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: (remain < 0 ? AppPalette.danger : AppPalette.success)
                          .withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Text(
                      remain < 0
                          ? '本次开票后累计开票金额将超出合同金额 ${moneyText(remain.abs())}，请核实后再提交'
                          : '本次开票后剩余可开票额度：${moneyText(remain)}',
                      style: textTheme.bodySmall?.copyWith(
                        color: remain < 0
                            ? AppPalette.danger
                            : AppPalette.success,
                      ),
                    ),
                  ),
                ],
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
                const AppSectionTitle('开票信息与备注'),
                TextFormField(
                  controller: _invoiceInfoController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: '开票信息',
                    hintText: '抬头、纳税人识别号、开户行及账号等',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _remarkController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: '开票备注',
                    hintText: '选填',
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
                  '合同信息等材料',
                  action: Text('${_attachments.length} 张',
                      style: textTheme.bodySmall
                          ?.copyWith(color: AppPalette.inkMute)),
                ),
                Row(
                  children: <Widget>[
                    OutlinedButton.icon(
                      onPressed: _uploading
                          ? null
                          : () => _pickAttachment(ImageSource.camera),
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
                if (_attachments.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: AttachmentGallery(
                      urls: _attachments,
                      label: '已上传材料',
                      thumbSize: 88,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '提交后系统会与已通过的开票记录自动比对（同园所 + 同项目名称 + 同本次开票金额），'
          '审批人会在审批页看到是否疑似重复开票。',
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
        child: Text('还没有开票记录', style: TextStyle(color: AppPalette.inkMute)),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadMine,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: _mine.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (BuildContext ctx, int i) {
          final FinanceInvoiceApply it = _mine[i];
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
                        it.projectName ?? '开票申请',
                        style: textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    StatusChip(it.statusLabel),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '本次开票 ${moneyText(it.currentAmount)} · ${it.invoiceKind ?? '—'}',
                  style: textTheme.bodySmall
                      ?.copyWith(color: AppPalette.inkMute),
                ),
                const SizedBox(height: 4),
                Text(
                  it.invoiceNo == null || it.invoiceNo!.isEmpty
                      ? '发票号：待会计开票登记'
                      : '发票号：${it.invoiceNo}',
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

  Future<void> _showDetail(FinanceInvoiceApply it) async {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final double? remain = it.remainAfter?.toDouble();
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
                      '开票单 ${it.applyNo ?? ''}',
                      style: textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  StatusChip(it.statusLabel),
                ],
              ),
              const SizedBox(height: 8),
              InfoRow(label: '项目名称', value: it.projectName ?? '—'),
              InfoRow(label: '对应业务', value: it.businessType ?? '—'),
              InfoRow(label: '发票类型', value: it.invoiceKind ?? '—'),
              InfoRow(label: '合同金额', value: moneyText(it.contractAmount)),
              InfoRow(
                label: '累计开票',
                value: moneyText(it.invoicedAmount),
              ),
              InfoRow(label: '本次开票', value: moneyText(it.currentAmount)),
              if (remain != null)
                InfoRow(
                  label: '剩余额度',
                  value: remain < 0
                      ? '已超额 ${moneyText(remain.abs())}'
                      : moneyText(remain),
                ),
              InfoRow(label: '发票号', value: it.invoiceNo ?? '待会计开票登记'),
              InfoRow(label: '开票日期', value: it.invoiceDate ?? '—'),
              if (it.approveComment != null && it.approveComment!.isNotEmpty)
                InfoRow(label: '审批意见', value: it.approveComment!),
              if (it.invoiceInfo != null && it.invoiceInfo!.isNotEmpty) ...<Widget>[
                const Divider(height: 24),
                Text('开票信息',
                    style: textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(it.invoiceInfo!, style: textTheme.bodyMedium),
              ],
              if (it.attachments.isNotEmpty) ...<Widget>[
                const Divider(height: 24),
                AttachmentGallery(urls: it.attachments, label: '合同材料'),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
