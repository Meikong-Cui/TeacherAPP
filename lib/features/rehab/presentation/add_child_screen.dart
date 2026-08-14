import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:teacher_app/data/models/rehab.dart';
import 'package:teacher_app/features/rehab/provider/rehab_provider.dart';
import 'package:teacher_app/shared/ui.dart';

/// 新增孩子：先录入共用的儿童/家长信息，再选择特殊教育类型创建对应模板档案。
class AddChildScreen extends ConsumerStatefulWidget {
  const AddChildScreen({super.key});

  @override
  ConsumerState<AddChildScreen> createState() => _AddChildScreenState();
}

class _AddChildScreenState extends ConsumerState<AddChildScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _idCtrl = TextEditingController();
  final TextEditingController _classCtrl = TextEditingController();
  final TextEditingController _guardianCtrl = TextEditingController();
  final TextEditingController _relationCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _addressCtrl = TextEditingController();

  String _gender = '男';
  DateTime? _birthDate;
  DateTime? _enrollDate;
  String _templateType = 'HEARING'; // HEARING / AUTISM
  bool _submitting = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _idCtrl.dispose();
    _classCtrl.dispose();
    _guardianCtrl.dispose();
    _relationCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool birth) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 3)),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => birth ? _birthDate = picked : _enrollDate = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请填写儿童姓名')));
      return;
    }
    setState(() => _submitting = true);
    try {
      final RehabArchive archive = RehabArchive(
        id: '',
        childName: _nameCtrl.text.trim(),
        templateType: _templateType,
        status: ArchiveStatus.draft,
        campusName: '',
      );
      final String id =
          await ref.read(rehabRepositoryProvider).createArchive(archive);
      if (!mounted) return;
      if (id.isEmpty) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('创建失败，请检查网络或后台')));
        setState(() => _submitting = false);
        return;
      }
      // 跳转儿童中枢，从那里进入对应模板的首次评估/评测录入。
      // 用 pushReplacement 保留主页栈，使中枢 AppBar 拥有返回按钮。
      context.pushReplacement('/children/$id');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('创建失败：$e')));
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('新增孩子'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            _StepCard(
              index: 1,
              title: '儿童基本信息',
              child: Column(
                children: <Widget>[
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(labelText: '儿童姓名'),
                    validator: (v) => v == null || v.trim().isEmpty ? '必填' : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: SegmentedButton<String>(
                          segments: const <ButtonSegment<String>>[
                            ButtonSegment(value: '男', label: Text('男')),
                            ButtonSegment(value: '女', label: Text('女')),
                          ],
                          selected: <String>{_gender},
                          onSelectionChanged: (s) => setState(() => _gender = s.first),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: () => _pickDate(true),
                          child: InputDecorator(
                            decoration: const InputDecoration(labelText: '出生日期'),
                            child: Text(_birthDate == null
                                ? '请选择'
                                : DateFormat('yyyy-MM-dd').format(_birthDate!)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _idCtrl,
                    decoration: const InputDecoration(labelText: '身份证号'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: TextFormField(
                          controller: _classCtrl,
                          decoration: const InputDecoration(labelText: '班级/组别'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: () => _pickDate(false),
                          child: InputDecorator(
                            decoration: const InputDecoration(labelText: '入园/入学日期'),
                            child: Text(_enrollDate == null
                                ? '请选择'
                                : DateFormat('yyyy-MM-dd').format(_enrollDate!)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _StepCard(
              index: 2,
              title: '家长信息',
              child: Column(
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: TextFormField(
                          controller: _guardianCtrl,
                          decoration: const InputDecoration(labelText: '家长姓名'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _relationCtrl,
                          decoration: const InputDecoration(labelText: '与家长关系'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: '联系电话'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _addressCtrl,
                    decoration: const InputDecoration(labelText: '家庭住址'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _StepCard(
              index: 3,
              title: '选择特殊教育类型',
              subtitle: '将按类型创建对应的评估与干预模板',
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: _TypeChoice(
                      selected: _templateType == 'HEARING',
                      title: '听障',
                      desc: '听能管理 / 听觉语言评估',
                      icon: Icons.hearing_outlined,
                      color: iconColor('green'),
                      onTap: () => setState(() => _templateType = 'HEARING'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TypeChoice(
                      selected: _templateType == 'AUTISM',
                      title: '孤独症',
                      desc: '八大领域评估 / IEP',
                      icon: Icons.psychology_outlined,
                      color: iconColor('rose'),
                      onTap: () => setState(() => _templateType = 'AUTISM'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check_circle_outline),
              label: Text(_submitting ? '正在创建…' : '创建档案并继续'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.index,
    required this.title,
    this.subtitle,
    required this.child,
  });
  final int index;
  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: colors.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text('$index',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(title,
                          style: textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      if (subtitle != null)
                        Text(subtitle!,
                            style: textTheme.bodySmall
                                ?.copyWith(color: colors.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _TypeChoice extends StatelessWidget {
  const _TypeChoice({
    required this.selected,
    required this.title,
    required this.desc,
    required this.icon,
    required this.color,
    required this.onTap,
  });
  final bool selected;
  final String title;
  final String desc;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? colors.primary : colors.outline,
            width: selected ? 2 : 1,
          ),
          color: selected ? colors.primaryContainer : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 10),
            Text(title,
                style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(desc,
                style: textTheme.bodySmall
                    ?.copyWith(color: colors.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
