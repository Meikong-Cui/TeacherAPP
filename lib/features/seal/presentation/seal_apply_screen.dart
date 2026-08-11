import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:teacher_app/core/auth_store.dart';
import 'package:teacher_app/data/models/seal.dart';
import 'package:teacher_app/features/seal/provider/seal_provider.dart';

/// 用章申请表单（教师填写用途与用章日期并提交）。
class SealApplyScreen extends ConsumerStatefulWidget {
  const SealApplyScreen({super.key});

  @override
  ConsumerState<SealApplyScreen> createState() => _SealApplyScreenState();
}

class _SealApplyScreenState extends ConsumerState<SealApplyScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _purposeController = TextEditingController();
  DateTime? _useDate;
  bool _submitting = false;

  @override
  void dispose() {
    _purposeController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _useDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 180)),
    );
    if (picked != null) {
      setState(() => _useDate = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_useDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择用章日期')),
      );
      return;
    }
    setState(() => _submitting = true);
    final SealApproval draft = SealApproval(
      id: '',
      purpose: _purposeController.text.trim(),
      useDate: _useDate,
    );
    final bool ok = await ref.read(sealListProvider.notifier).apply(draft);
    if (!mounted) return;
    setState(() => _submitting = false);
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('用章申请已提交，等待审批')),
      );
      context.go('/seal');
    } else {
      final String? err = ref.read(sealListProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err ?? '提交失败')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final String userName = AuthStore.instance.userName ?? '';
    return Scaffold(
      appBar: AppBar(title: const Text('用章申请')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('申请人', style: textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text(userName.isNotEmpty ? userName : '—',
                      style: textTheme.titleMedium),
                  const SizedBox(height: 16),
                  Form(
                    key: _formKey,
                    child: Column(
                      children: <Widget>[
                        TextFormField(
                          controller: _purposeController,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText: '用章用途',
                            hintText: '详细说明本次用章的具体事项',
                            border: OutlineInputBorder(),
                            alignLabelWithHint: true,
                          ),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? '请填写用章用途' : null,
                        ),
                        const SizedBox(height: 16),
                        InkWell(
                          onTap: _pickDate,
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: '用章日期',
                              border: OutlineInputBorder(),
                            ),
                            child: Text(
                              _useDate == null
                                  ? '请选择'
                                  : _useDate!.toIso8601String().split('T').first,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('提交申请'),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '提交后将由园长 / 管理员 / 财务审批，可在「用章记录」中查看进度。',
            style: textTheme.bodySmall
                ?.copyWith(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
