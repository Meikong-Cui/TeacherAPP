import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:teacher_app/data/models/autism_archive.dart';
import 'package:teacher_app/data/models/campus.dart';
import 'package:teacher_app/data/models/child.dart';
import 'package:teacher_app/data/models/rehab.dart';
import 'package:teacher_app/features/clock_in/provider/clock_in_provider.dart';
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
  /// 第二位家长（由家长卡片右上角「+」展开）。
  final TextEditingController _g2NameCtrl = TextEditingController();
  final TextEditingController _g2RelCtrl = TextEditingController();
  final TextEditingController _g2PhoneCtrl = TextEditingController();
  /// 区、县残联意见。
  final TextEditingController _fedCtrl = TextEditingController();

  String _gender = '男';
  DateTime? _birthDate;
  DateTime? _enrollDate;
  bool _loading = true;
  bool _saving = false;
  bool _isAutism = false;
  String? _firstEvalId;
  String? _error;

  /// 第二位家长区域的展开状态。
  bool _showSecondGuardian = false;

  /// 关联的儿童主档 id（取自档案的 childId）。为 null 时本页退化为只编辑评估表。
  int? _childId;

  /// 从主档读回的**原始记录**。
  ///
  /// 保存时必须把「本页不编辑的字段」原样带回：后端 update 是逐字段 set 的
  /// **全量覆盖**语义，漏传等于清空 —— 不带上它就会在「只改一个电话」时
  /// 顺手把状态、组别、负责教师、备注全部抹掉。
  ChildProfile? _profile;
  int? _campusId;
  List<Campus> _campuses = const <Campus>[];

  /// 主档读取失败时的非阻断提示（档案字段仍可正常编辑）。
  String? _profileWarn;

  @override
  void initState() {
    super.initState();
    _loadCampuses();
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
    _g2NameCtrl.dispose();
    _g2RelCtrl.dispose();
    _g2PhoneCtrl.dispose();
    _fedCtrl.dispose();
    super.dispose();
  }

  /// 拉校区列表，仅用于把儿童的 campusId 显示成中文名。
  ///
  /// 失败不影响编辑本身（校区归属不在本页修改），所以只吞掉异常 ——
  /// 但会保留 `_campusId`，保存时原样回传，不会因为列表拉不到就把校区清掉。
  Future<void> _loadCampuses() async {
    try {
      final List<Campus>? list =
          await ref.read(clockInRepositoryProvider).listCampuses();
      if (!mounted) return;
      setState(() => _campuses = list ?? const <Campus>[]);
    } catch (_) {
      // 展示性数据，拿不到就不显示校区名。
    }
  }

  String _campusLabel() {
    if (_campusId == null) return '';
    for (final Campus c in _campuses) {
      if (c.id == _campusId) return c.name;
    }
    // 列表还没回来 / 校区已被删除时，至少让用户知道它挂着某个园区。
    return '校区 #$_campusId';
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
      final RehabArchiveDetail rehabDetail = await repo.getArchive(widget.archiveId);
      _isAutism = rehabDetail.archive.isAutism;
      _childId = rehabDetail.archive.childId;

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

      // 儿童主档才是「家长 / 第二位家长 / 区、县残联意见 / 归属校区」的唯一真相：
      // 上面按档案类型回填的只是评估表字段。不读主档的话，用户在录入页填的家长信息
      // 在编辑页会显示成空白（两边写的是不同的表），让人以为「填了没保存」。
      final int? childId = _childId;
      if (childId != null) {
        try {
          final ChildProfile p = await repo.getChildProfile(childId);
          _profile = p;
          _childId = p.id ?? childId;
          _campusId = p.campusId;
          _guardianCtrl.text = p.guardianName;
          _relationCtrl.text = p.guardianRelation;
          _phoneCtrl.text = p.familyPhone;
          _addressCtrl.text = p.homeAddress;
          _g2NameCtrl.text = p.guardian2Name;
          _g2RelCtrl.text = p.guardian2Relation;
          _g2PhoneCtrl.text = p.guardian2Phone;
          _showSecondGuardian = p.hasSecondGuardian;
          _fedCtrl.text = p.federationOpinion;
          // 评估表没有的字段用主档兜底，免得看起来「本来就是空的」。
          _birthDate ??= p.birthDate;
          if (_idCtrl.text.isEmpty) _idCtrl.text = p.idNumber;
          if (_classCtrl.text.isEmpty) _classCtrl.text = p.className;
          _enrollDate ??= p.admissionDate;
        } catch (e) {
          // 主档读不到不该让整页崩掉：评估表部分继续可编辑。
          _profileWarn = '未能读取儿童主档，家长 / 残联意见 / 校区可能显示不全：$e';
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

      // 出生日期没被改动时保留主档里的原 age：它可能是人工填的，
      // 不能被「按出生日期推算」的值悄悄覆盖（后端 deriveAge 的取舍口径一致）。
      bool sameDate(DateTime? a, DateTime? b) =>
          a?.year == b?.year && a?.month == b?.month && a?.day == b?.day;

      // ① 儿童主档：家长 ×2 / 区、县残联意见 / 出生日期 / 身份证 / 班级 /
      //    入园日期 / 归属校区。
      //    ⚠️ 后端 update 是逐字段 set 的**全量覆盖**语义，所以「本页不编辑的
      //    字段」（状态 / 组别 / 负责教师 / 备注 / 新生老生 / 儿童类型 / age）
      //    必须从读到的原始记录里原样带回 —— 漏传即等于清空，
      //    会造成「只改了一个电话，回去发现负责教师没了」。
      final int? childId = _childId;
      if (childId != null) {
        final ChildProfile origin =
            _profile ?? ChildProfile(name: _nameCtrl.text.trim());
        await repo.updateChildProfile(
          childId,
          ChildProfile(
            id: childId,
            name: _nameCtrl.text.trim(),
            childType: origin.childType,
            studentType: origin.studentType,
            gender: _gender,
            age: sameDate(_birthDate, origin.birthDate) ? origin.age : null,
            birthDate: _birthDate,
            idNumber: _idCtrl.text.trim(),
            className: _classCtrl.text.trim(),
            groupName: origin.groupName,
            status: origin.status,
            admissionDate: _enrollDate,
            teacherId: origin.teacherId,
            teacherName: origin.teacherName,
            remark: origin.remark,
            guardianName: _guardianCtrl.text.trim(),
            guardianRelation: _relationCtrl.text.trim(),
            familyPhone: _phoneCtrl.text.trim(),
            homeAddress: _addressCtrl.text.trim(),
            // 收起第二位家长时提交空串 ⇒ 主档落 NULL，
            // 这样「展开填了一下又收起来」不会留下半条记录。
            guardian2Name: _showSecondGuardian ? _g2NameCtrl.text.trim() : '',
            guardian2Relation:
                _showSecondGuardian ? _g2RelCtrl.text.trim() : '',
            guardian2Phone: _showSecondGuardian ? _g2PhoneCtrl.text.trim() : '',
            federationOpinion: _fedCtrl.text.trim(),
            campusId: _campusId,
          ),
        );
      }

      // ② 首次评估表：评估表 PDF 的「基本情况」栏位取自它，故保持原有逻辑不动。
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
        // 家长信息挂在**儿童主档**上，与档案类型无关，所以听障 / 孤独症都要显示。
        // 以前它只在孤独症分支里出现，听障孩子的家长在 App 中根本没有入口。
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    _row('2', '家长信息'),
                    const Spacer(),
                    IconButton(
                      icon: Icon(_showSecondGuardian
                          ? Icons.remove_circle_outline
                          : Icons.add_circle_outline),
                      tooltip: _showSecondGuardian ? '收起第二位家长' : '添加第二位家长',
                      onPressed: () => setState(
                          () => _showSecondGuardian = !_showSecondGuardian),
                    ),
                  ],
                ),
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
                if (_showSecondGuardian) ...<Widget>[
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  Row(
                    children: <Widget>[
                      Icon(Icons.person_add_alt_1_outlined,
                          size: 18, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 6),
                      const Text('第二位家长',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700)),
                      const Spacer(),
                      Text('选填',
                          style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: TextFormField(
                          controller: _g2NameCtrl,
                          decoration: const InputDecoration(labelText: '姓名'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _g2RelCtrl,
                          decoration: const InputDecoration(labelText: '关系'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _g2PhoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: '联系电话'),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '家庭住址为全家共用，无需重复填写。',
                    style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),
        ),
        // 区、县残联意见（选填）
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _row('4', '区、县残联意见'),
                TextFormField(
                  controller: _fedCtrl,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    hintText: '选填。如：经评估符合康复救助条件，同意安排入训。',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
          ),
        ),
        // 归属校区（只读）：校区归属由 OA 端园长/管理员维护，
        // App 编辑页不提供修改入口（后端也只允许园长/管理员改），
        // 这里明确展示出来，免得老师不知道孩子挂在哪个园区。
        if (_campusLabel().isNotEmpty) ...<Widget>[
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.location_on_outlined),
              title: const Text('归属校区'),
              subtitle: Text(_campusLabel()),
              trailing: const Icon(Icons.lock_outline, size: 16),
            ),
          ),
        ],
        if (_profileWarn != null) ...<Widget>[
          const SizedBox(height: 12),
          Card(
            color: Theme.of(context).colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                _profileWarn!,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer),
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