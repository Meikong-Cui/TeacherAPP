import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:teacher_app/data/models/autism_archive.dart';
import 'package:teacher_app/data/models/rehab.dart';
import 'package:teacher_app/features/rehab/provider/rehab_provider.dart';

/// 编辑儿童信息：从儿童中枢页 AppBar「编辑」按钮进入。
///
/// 按 archiveId 加载档案，按 archive 类型（听障 / 孤独症）选择对应的 FirstEval 模型：
/// - HEARING → `RehabFirstEval`（基础字段）
/// - AUTISM → `AutismFirstEval`（基础 + 家长信息 / 联系电话 / 家庭住址）
///
/// 已有 FirstEval 则更新；没有则创建。姓名为必填。
class EditChildScreen extends ConsumerStatefulWidget {
  const EditChildScreen({required this.archiveId, super.key});
  final String archiveId;

  @override
  ConsumerState<EditChildScreen> createState() => _EditChildScreenState();
}

class _EditChildScreenState extends ConsumerState<EditChildScreen> {
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
  bool _loading = true;
  bool _saving = false;
  bool _isAutism = false;
  String? _firstEvalId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

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

  Future<void> _pickDate(bool enroll) async {
    final DateTime initial = enroll
        ? (_enrollDate ?? DateTime.now().subtract(const Duration(days: 365)))
        : (_birthDate ?? DateTime.now().subtract(const Duration(days: 365 * 3)));
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => enroll ? _enrollDate = picked : _birthDate = picked);
    }
  }

  Future<void> _load() async {
    try {
      final repo = ref.read(rehabRepositoryProvider);
      final rehabDetail = await repo.getArchive(widget.archiveId);
      _isAutism = rehabDetail.archive.isAutism;

      if (_isAutism) {
        final AutismArchiveDetail autism =
            await repo.getAutismArchive(widget.archiveId);
        final AutismFirstEval? eval = autism.firstEval;
        if (eval != null) {
          _firstEvalId = eval.id;
          _nameCtrl.text = eval.name;
          _gender = eval.gender.isEmpty ? '男' : eval.gender;
          _birthDate = eval.birthDate;
          _idCtrl.text = eval.idNumber;
          _classCtrl.text = eval.className;
          _enrollDate = eval.enrollmentDate;
          _guardianCtrl.text = eval.guardianName;
          _relationCtrl.text = eval.guardianRelation;
          _phoneCtrl.text = eval.familyPhone;
          _addressCtrl.text = eval.homeAddress;
        }
      } else {
        final RehabFirstEval? eval = rehabDetail.firstEval;
        if (eval != null) {
          _firstEvalId = eval.id;
          _nameCtrl.text = eval.name;
          _gender = eval.gender.isEmpty ? '男' : eval.gender;
          _birthDate = eval.birthDate;
          _idCtrl.text = eval.idNumber;
          _classCtrl.text = eval.className;
          _enrollDate = eval.enrollmentDate;
        }
      }
    } catch (e) {
      _error = '加载失败：$e';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content:Text('请填写儿童姓名')));
      return;
    }
    setState(() => _saving = true);
    try {
      final repo = ref.read(rehabRepositoryProvider);
      if (_isAutism) {
        final eval = AutismFirstEval(
          id: _firstEvalId,
          archiveId: widget.archiveId,
          name: _nameCtrl.text.trim(),
          gender: _gender,
          birthDate: _birthDate,
          idNumber: _idCtrl.text.trim(),
          enrollmentDate: _enrollDate,
          className: _classCtrl.text.trim(),
          guardianName: _guardianCtrl.text.trim(),
          guardianRelation: _relationCtrl.text.trim(),
          familyPhone: _phoneCtrl.text.trim(),
          homeAddress: _addressCtrl.text.trim(),
        );
        await repo.saveAutismFirstEval(eval);
      } else {
        final eval = RehabFirstEval(
          id: _firstEvalId,
          archiveId: widget.archiveId,
          name: _nameCtrl.text.trim(),
          gender: _gender,
          birthDate: _birthDate,
          idNumber: _idCtrl.text.trim(),
          enrollmentDate: _enrollDate,
          className: _classCtrl.text.trim(),
        );
        if (_firstEvalId == null || _firstEvalId!.isEmpty) {
          await repo.createFirstEval(eval);
        } else {
          await repo.updateFirstEval(eval);
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('已保存')));
        context.pop(true); // 返回上一页并提示刷新
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('保存失败：$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('编辑儿童信息'),
        actions: <Widget>[
          if (_saving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(
                  width: 18,
                  height: 18,
                child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: TextButton(
                onPressed: _loading ? null : _save,
                style: TextButton.styleFrom(
                  textStyle: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15),
                ),
                child: const Text('保存'),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _buildForm(),
    );
  }

  Widget _buildForm() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _row('1', '儿童基本信息'),
                TextFormField(
                  controller: _nameCtrl,
                  decoration:
                      const InputDecoration(labelText: '儿童姓名 *'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: SegmentedButton<String>(
                        segments: const <ButtonSegment<String>>[
                          ButtonSegment<String>(
                              value: '男', label: Text('男')),
                          ButtonSegment<String>(
                              value: '女', label: Text('女')),
                        ],
                        selected: <String>{_gender},
                        onSelectionChanged: (s) =>
                            setState(() => _gender = s.first),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: () => _pickDate(false),
                        child: InputDecorator(
                          decoration:
                              const InputDecoration(labelText: '出生日期 *'),
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
                  decoration:
                      const InputDecoration(labelText: '身份证号'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: TextFormField(
                        controller: _classCtrl,
                        decoration:
                            const InputDecoration(labelText: '班级/组别'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: () => _pickDate(true),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                              labelText: '入园/入学日期'),
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
        ),
        // 孤独症档案额外显示家长/电话/住址。
        if (_isAutism) ...<Widget>[
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _row('2', '家长信息'),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: TextFormField(
                          controller: _guardianCtrl,
                          decoration:
                              const InputDecoration(labelText: '家长姓名'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _relationCtrl,
                          decoration:
                              const InputDecoration(labelText: '与家长关系'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration:
                        const InputDecoration(labelText: '联系电话'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _addressCtrl,
                    decoration:
                        const InputDecoration(labelText: '家庭住址'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _row(String idx, String title) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: <Widget>[
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(idx,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 10),
            Text(title,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700)),
          ],
        ),
      );
}