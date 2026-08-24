import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:teacher_app/app/design_tokens.dart';
import 'package:teacher_app/core/auth_store.dart';
import 'package:teacher_app/features/supplement/supplement_repository.dart';

/// 「办公」→「补卡」→「新增补卡」页。提交后走通用流程引擎「补卡申请」模板，
/// 由直属上级审批；审批通过后后端自动写入一条「员工打卡」记录。
class SupplementApplyScreen extends ConsumerStatefulWidget {
  const SupplementApplyScreen({super.key});

  @override
  ConsumerState<SupplementApplyScreen> createState() =>
      _SupplementApplyScreenState();
}

class _SupplementApplyScreenState extends ConsumerState<SupplementApplyScreen> {
  static const List<String> _types = <String>['上班漏卡', '下班漏卡'];

  String _type = '上班漏卡';
  DateTime? _date;
  final TextEditingController _reasonCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      !_submitting && _date != null && _reasonCtrl.text.trim().isNotEmpty;

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _date ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 60)),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    final String employee = AuthStore.instance.userName ?? '未知教师';
    final SupplementRecord r = SupplementRecord(
      employee: employee,
      supplementType: _type,
      supplementDate: DateFormat('yyyy-MM-dd').format(_date!),
      reason: _reasonCtrl.text.trim(),
      status: 1,
    );
    setState(() => _submitting = true);
    try {
      final SupplementSubmitResult res =
          await SupplementRepository().submitSupplement(r);
      if (!mounted) return;
      if (res.recordId == 0) throw Exception('创建补卡记录失败');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.hasWorkflow
              ? '补卡申请已提交，等待直属上级审批'
              : '补卡申请已提交，OA 后台可查看并审批'),
        ),
      );
      context.pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('提交失败：$e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('补卡申请',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppPalette.ink)),
        actions: <Widget>[
          TextButton(
            onPressed: _canSubmit ? _submit : null,
            child: const Text('提交'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text('申请人',
                    style: TextStyle(
                        fontSize: AppFontSize.small, color: AppPalette.inkMute)),
                const SizedBox(height: 4),
                Text(AuthStore.instance.userName ?? '—',
                    style: const TextStyle(
                        fontSize: AppFontSize.title, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text('补卡类型',
                    style: TextStyle(
                        fontSize: AppFontSize.small, color: AppPalette.inkMute)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: _types.map((String t) {
                    final bool selected = t == _type;
                    return ChoiceChip(
                      label: Text(t),
                      selected: selected,
                      onSelected: (_) => setState(() => _type = t),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SoftCard(
            child: Column(
              children: <Widget>[
                InkWell(
                  onTap: _pickDate,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Row(
                      children: <Widget>[
                        const Text('补卡日期',
                            style: TextStyle(
                                fontSize: AppFontSize.body,
                                color: AppPalette.inkMute)),
                        const Spacer(),
                        Text(
                          _date == null
                              ? '选择日期'
                              : DateFormat('yyyy-MM-dd').format(_date!),
                          style: const TextStyle(
                            fontSize: AppFontSize.body,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.calendar_today,
                            size: 16, color: AppPalette.inkMute),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text('原因说明',
                    style: TextStyle(
                        fontSize: AppFontSize.small, color: AppPalette.inkMute)),
                const SizedBox(height: 8),
                TextField(
                  controller: _reasonCtrl,
                  maxLines: 4,
                  maxLength: 200,
                  decoration: const InputDecoration(
                    hintText: '请说明漏卡原因，便于直属上级审批',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _canSubmit ? _submit : null,
            icon: _submitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.send),
            label: Text(_submitting ? '提交中…' : '提交补卡'),
          ),
          const SizedBox(height: 8),
          Text(
            '提交后由直属上级（园长 / 管理员）审批，审批通过后系统自动补记打卡。',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
