import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:teacher_app/data/providers.dart';
import 'package:teacher_app/features/reimbursement/data/reimbursement_repository.dart';
import 'package:teacher_app/features/reimbursement/provider/reimbursement_provider.dart';
import 'package:teacher_app/shared/ui.dart';

/// 申请报销表单页。
class ReimbursementNewScreen extends ConsumerStatefulWidget {
  const ReimbursementNewScreen({super.key});

  @override
  ConsumerState<ReimbursementNewScreen> createState() =>
      _ReimbursementNewScreenState();
}

/// 单行明细的临时编辑态（含三个输入框控制器）。
class _DraftItem {
  _DraftItem()
      : name = TextEditingController(),
        amount = TextEditingController(),
        remark = TextEditingController();

  final TextEditingController name;
  final TextEditingController amount;
  final TextEditingController remark;

  void dispose() {
    name.dispose();
    amount.dispose();
    remark.dispose();
  }
}

class _ReimbursementNewScreenState
    extends ConsumerState<ReimbursementNewScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();
  String _category = _categories.first;
  final List<_DraftItem> _items = <_DraftItem>[_DraftItem()];
  bool _submitting = false;

  static const List<String> _categories = <String>[
    '教学用品',
    '差旅交通',
    '办公用品',
    '培训费',
    '其他',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _reasonController.dispose();
    for (final _DraftItem item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  void _addItem() => setState(() => _items.add(_DraftItem()));

  void _removeItem(int index) {
    if (_items.length <= 1) return;
    final _DraftItem removed = _items.removeAt(index);
    removed.dispose();
    setState(() {});
  }

  double _computedTotal() {
    double sum = 0;
    for (final _DraftItem item in _items) {
      sum += double.tryParse(item.amount.text) ?? 0;
    }
    return sum;
  }

  Future<void> _submit() async {
    final String title = _titleController.text.trim();
    if (title.isEmpty) {
      _toast('请填写报销标题');
      return;
    }
    final List<ReimbursementItem> items = <ReimbursementItem>[];
    for (final _DraftItem item in _items) {
      final String name = item.name.text.trim();
      final double? amount = double.tryParse(item.amount.text);
      if (name.isEmpty || amount == null || amount <= 0) {
        _toast('请完善每项明细的名称与金额（金额需大于 0）');
        return;
      }
      items.add(ReimbursementItem(
        name: name,
        amount: amount,
        remark: item.remark.text.trim(),
      ));
    }

    final TeacherUser user = ref.read(currentUserProvider);
    final Reimbursement draft = Reimbursement(
      id: '',
      applicantName: user.name,
      campusName: user.center,
      title: title,
      category: _category,
      amount: _computedTotal(),
      reason: _reasonController.text.trim(),
      status: ReimbursementStatus.pending,
      createTime: DateTime.now(),
      items: items,
    );

    setState(() => _submitting = true);
    try {
      await ref.read(reimbursementListProvider.notifier).apply(draft);
      if (mounted) {
        _toast('已提交，等待财务审批');
        context.pop();
      }
    } on ReimbursementException catch (e) {
      if (mounted) _toast(e.message);
    } catch (e) {
      if (mounted) _toast('提交失败：$e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('申请报销'),
        actions: const <Widget>[ThemeToggleButton()],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const AppSectionTitle('报销信息'),
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: '报销标题',
                      hintText: '如：个训教具采购',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _category,
                    decoration: const InputDecoration(labelText: '报销类别'),
                    items: _categories
                        .map((String c) => DropdownMenuItem<String>(
                              value: c,
                              child: Text(c),
                            ))
                        .toList(),
                    onChanged: (String? v) {
                      if (v != null) setState(() => _category = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _reasonController,
                    decoration: const InputDecoration(
                      labelText: '事由说明',
                      hintText: '简要说明报销用途',
                    ),
                    maxLines: 3,
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
                    '费用明细',
                    action: TextButton.icon(
                      onPressed: _addItem,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('添加一项'),
                    ),
                  ),
                  ..._items.asMap().entries.map(
                    (MapEntry<int, _DraftItem> entry) {
                      final int index = entry.key;
                      final _DraftItem item = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                controller: item.name,
                                decoration: const InputDecoration(
                                  hintText: '名称',
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: item.amount,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                decoration: const InputDecoration(
                                  hintText: '金额',
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                controller: item.remark,
                                decoration: const InputDecoration(
                                  hintText: '备注',
                                  isDense: true,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => _removeItem(index),
                              icon: const Icon(Icons.remove_circle_outline),
                              color: colors.error,
                              tooltip: '删除',
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Text('合计',
                          style: textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      Text('¥${_computedTotal().toStringAsFixed(2)}',
                          style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: colors.primary)),
                    ],
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
            '提交后将上传至 OA 后台，由财务/园长在网页端审批。',
            style: textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
