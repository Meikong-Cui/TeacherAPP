import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:teacher_app/app/design_tokens.dart';
import 'package:teacher_app/core/auth_store.dart';
import 'package:teacher_app/features/office/leave_repository.dart';

/// 「办公」→「请假」→「新增请假」页。
/// 直接调用 `/api/oa/record` (category='hr-leave')，与 OA 网页共用同一份数据。
class LeaveApplyScreen extends ConsumerStatefulWidget {
  const LeaveApplyScreen({super.key});

  @override
  ConsumerState<LeaveApplyScreen> createState() => _LeaveApplyScreenState();
}

class _LeaveApplyScreenState extends ConsumerState<LeaveApplyScreen> {
  static const List<String> _leaveTypes = <String>[
    '事假',
    '病假',
    '年假',
    '调休',
  ];

  String _type = '事假';
  DateTime? _start;
  DateTime? _end;
  final TextEditingController _reasonCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  double get _days {
    if (_start == null || _end == null) return 0;
    final int diff = _end!.difference(_start!).inDays + 1;
    return diff < 0 ? 0 : diff.toDouble();
  }

  bool get _canSubmit =>
      !_submitting &&
      _start != null &&
      _end != null &&
      !_end!.isBefore(_start!);

  Future<void> _pickDate(bool isStart) async {
    final DateTime initial = (isStart ? _start : _end) ?? DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _start = picked;
        if (_end == null || _end!.isBefore(picked)) _end = picked;
      } else {
        _end = picked;
      }
    });
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    final String employee = AuthStore.instance.userName ?? '未知教师';
    final LeaveRecord r = LeaveRecord(
      employee: employee,
      leaveType: _type,
      startDate: DateFormat('yyyy-MM-dd').format(_start!),
      endDate: DateFormat('yyyy-MM-dd').format(_end!),
      days: _days,
      reason: _reasonCtrl.text.trim(),
      status: 1,
    );
    setState(() => _submitting = true);
    try {
      final LeaveSubmitResult res = await LeaveRepository().submitLeave(r);
      if (!mounted) return;
      if (res.recordId == 0) {
        throw Exception('创建请假记录失败');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.hasWorkflow
              ? '请假已提交，等待直属上级审批'
              : '请假已提交，OA 后台可查看并审批'),
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
        title: const Text('新增请假',
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
                        fontSize: AppFontSize.small,
                        color: AppPalette.inkMute)),
                const SizedBox(height: 4),
                Text(AuthStore.instance.userName ?? '—',
                    style: const TextStyle(
                        fontSize: AppFontSize.title,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text('请假类型',
                    style: TextStyle(
                        fontSize: AppFontSize.small,
                        color: AppPalette.inkMute)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: _leaveTypes.map((String t) {
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
                _DateField(
                  label: '开始日期',
                  value: _start,
                  onTap: () => _pickDate(true),
                ),
                const Divider(height: 1),
                _DateField(
                  label: '结束日期',
                  value: _end,
                  onTap: () => _pickDate(false),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(children: <Widget>[
                    const Text('合计',
                        style: TextStyle(
                            fontSize: AppFontSize.small,
                            color: AppPalette.inkMute)),
                    const Spacer(),
                    Text('${_days.toStringAsFixed(0)} 天',
                        style: const TextStyle(
                          fontSize: AppFontSize.title,
                          fontWeight: FontWeight.bold,
                          color: AppPalette.brandDark,
                        )),
                  ]),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text('事由',
                    style: TextStyle(
                        fontSize: AppFontSize.small,
                        color: AppPalette.inkMute)),
                const SizedBox(height: 8),
                TextField(
                  controller: _reasonCtrl,
                  maxLines: 4,
                  maxLength: 200,
                  decoration: const InputDecoration(
                    hintText: '请简要填写请假事由，便于审批',
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
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.send),
            label: Text(_submitting ? '提交中…' : '提交请假'),
          ),
        ],
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
  });
  final String label;
  final DateTime? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: <Widget>[
            Text(label,
                style: const TextStyle(
                    fontSize: AppFontSize.body,
                    color: AppPalette.inkMute)),
            const Spacer(),
            Text(
              value == null
                  ? '选择日期'
                  : DateFormat('yyyy-MM-dd').format(value!),
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
    );
  }
}
