import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:teacher_app/core/auth_store.dart';
import 'package:teacher_app/data/models/autism_eval_item.dart';
import 'package:teacher_app/data/models/campus.dart';
import 'package:teacher_app/data/models/child.dart';
import 'package:teacher_app/data/models/rehab.dart';
import 'package:teacher_app/features/clock_in/provider/clock_in_provider.dart';
import 'package:teacher_app/features/rehab/provider/autism_eval_provider.dart';
import 'package:teacher_app/features/rehab/provider/rehab_provider.dart';
import 'package:teacher_app/shared/ui.dart';

/// 新增孩子：先录入共用的儿童/家长信息，再选择特殊教育类型创建对应模板档案。
class AddChildScreen extends ConsumerStatefulWidget {
  final String initialType; // 'HEARING' | 'AUTISM'，由主页卡片路由 ?type= 传入
  const AddChildScreen({super.key, this.initialType = 'HEARING'});

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
  /// 第二位家长（点家长卡片右上角「+」后展开录入，均为选填）。
  final TextEditingController _g2NameCtrl = TextEditingController();
  final TextEditingController _g2RelCtrl = TextEditingController();
  final TextEditingController _g2PhoneCtrl = TextEditingController();
  /// 区、县残联意见（选填）。
  final TextEditingController _fedCtrl = TextEditingController();

  String _gender = '男';
  DateTime? _birthDate;
  DateTime? _enrollDate;
  String _templateType = 'HEARING'; // HEARING / AUTISM
  /// 孤独症档案的评测量表：STANDARD（残联标准）/ OFFLINE（线下模板）/ VB，三套相互独立。
  String _evalFormCode = 'STANDARD';
  /// 听障业务的新生/老生标记：新生需先做首次评估，老生可直接填持续评估。
  /// 唯一真相在后端 rehab_child.student_type，这里只在建档时写入初值。
  String _studentType = 'NEW'; // NEW / OLD
  bool _submitting = false;

  /// 第二位家长区域的展开状态。默认收起（只用于录入一位家长的场景）。
  bool _showSecondGuardian = false;

  /// 可选校区列表（`GET /api/system/campuses`）。
  List<Campus> _campuses = const <Campus>[];
  /// 已选校区 id。取不到用户所属校区时为 null，**不静默选第一个** ——
  /// 免得儿童被挂到用户没留意的园区上。
  int? _campusId;
  bool _loadingCampuses = false;
  String? _campusError;

  /// 本次提交已建好的儿童主档 id。
  ///
  /// 两段式提交（先主档、再档案）里第二段可能失败（网络抖动等），
  /// 用户点重试时**必须复用**这个 id，否则会重复建出第二个儿童。
  int? _createdChildId;

  @override
  void initState() {
    super.initState();
    // 依据主页卡片路由 ?type= 预设评测类型（HEARING / AUTISM），避免始终默认听障。
    _templateType = widget.initialType;
    _loadCampuses();
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

  /// 拉取可选校区。复用打卡页那套来源（后台实时 → 本地缓存），
  /// 不在这里内置假校区：校区列表写错会让儿童被挂到不存在的园区。
  Future<void> _loadCampuses() async {
    setState(() {
      _loadingCampuses = true;
      _campusError = null;
    });
    try {
      final List<Campus>? list =
          await ref.read(clockInRepositoryProvider).listCampuses();
      if (!mounted) return;
      final List<Campus> all = list ?? const <Campus>[];
      final int? mine = int.tryParse(AuthStore.instance.campusId ?? '');
      setState(() {
        _campuses = all;
        _loadingCampuses = false;
        // 只有一个可选项时直接选中，省掉用户一次点击；多个则要求用户显式选。
        _campusId = mine ?? (all.length == 1 ? all.first.id : null);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingCampuses = false;
        _campusError = '校区列表加载失败：$e';
      });
    }
  }

  /// 当前用户是否可以给儿童选任意校区。
  ///
  /// 与后端 `RehabChildService.canCrossCampus` 同一口径：只有园长/管理员。
  /// 其余角色在后端会被硬拒 403（不是静默回落），所以这里也不给出误导性的可选项。
  bool get _canChooseCampus =>
      AuthStore.instance.hasRole('PRINCIPAL') || AuthStore.instance.hasRole('ADMIN');

  /// 界面上真正可点的校区。
  ///
  /// 不可跨校区时只留「所属校区」一项 —— 仍旧用卡片呈现，
  /// 让用户看到自己建的儿童会落在哪个园区，而不是面对一个空的选择区。
  List<Campus> get _selectableCampuses {
    if (_canChooseCampus) return _campuses;
    final int? mine = int.tryParse(AuthStore.instance.campusId ?? '');
    if (mine == null) return _campuses; // 账号没绑校区时不设限，交由后端裁决
    return _campuses.where((Campus c) => c.id == mine).toList();
  }

  String _campusNameOf(int? id) {
    if (id == null) return '';
    for (final Campus c in _campuses) {
      if (c.id == id) return c.name;
    }
    return '';
  }

  /// 「归属校区」步骤。
  ///
  /// 与「特殊教育类型」共用同一套卡片视觉语言（[_TypeChoice]），
  /// 让「选校区」和「选类型」在观感上是同一件事，而不是一个突兀的下拉框。
  Widget _campusStep() {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme colors = Theme.of(context).colorScheme;
    final List<Campus> options = _selectableCampuses;

    Widget body;
    if (_loadingCampuses) {
      body = const Row(
        children: <Widget>[
          SizedBox(
              width: 16, height: 16,
              child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 10),
          Text('正在加载校区…'),
        ],
      );
    } else if (_campusError != null) {
      // 失败必须给重试入口：留一片空白会让用户以为「本校没有校区」。
      body = Row(
        children: <Widget>[
          Expanded(
            child: Text(_campusError!,
                style: textTheme.bodySmall?.copyWith(color: colors.error)),
          ),
          TextButton(onPressed: _loadCampuses, child: const Text('重试')),
        ],
      );
    } else if (options.isEmpty) {
      // 区分「后台确实没建校区」和「账号没绑校区」—— 两者的处理人不同。
      body = Text(
        _canChooseCampus
            ? '后台还没有校区，请先在 OA 网页「学校管理」中建立校区。'
            : '你的账号尚未绑定校区，请联系管理员在 OA 网页中设置后再建档。',
        style: textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
      );
    } else {
      body = Wrap(
        spacing: 12,
        runSpacing: 12,
        children: <Widget>[
          for (final Campus c in options)
            SizedBox(
              width: 220,
              child: _TypeChoice(
                selected: _campusId == c.id,
                title: c.name,
                desc: _canChooseCampus
                    ? (c.hasGeo ? '已配置打卡点' : '未配置打卡点')
                    : '你的所属校区',
                icon: Icons.location_on_outlined,
                color: iconColor('blue'),
                onTap: () => setState(() => _campusId = c.id),
              ),
            ),
        ],
      );
    }

    return _StepCard(
      index: 2,
      title: '归属校区',
      subtitle: _canChooseCampus ? '可选任意校区' : '仅能选择你所属的校区',
      child: body,
    );
  }

  /// 「区、县残联意见」步骤（选填，自由文本）。
  ///
  /// 单独成步而不是塞进「儿童基本信息」：它是行政意见，不是儿童自身属性，
  /// 混在一起会让录入者以为必填。
  Widget _fedStep() {
    return _StepCard(
      index: 4,
      title: '区、县残联意见',
      subtitle: '选填。记录区/县残疾人联合会对该儿童的评估或安置意见',
      child: TextFormField(
        controller: _fedCtrl,
        minLines: 3,
        maxLines: 5,
        decoration: const InputDecoration(
          hintText: '如：经评估符合康复救助条件，同意安排入训。',
          border: OutlineInputBorder(),
          alignLabelWithHint: true,
        ),
      ),
    );
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
      _toast('请填写儿童姓名');
      return;
    }
    if (_birthDate == null) {
      _toast('请选择出生日期');
      return;
    }
    setState(() => _submitting = true);
    final repo = ref.read(rehabRepositoryProvider);
    try {
      // ── ① 先建儿童主档 ────────────────────────────────────────────
      // 家长信息 / 第二位家长 / 出生日期 / 身份证 / 班级 / 区、县残联意见 /
      // 归属校区都只存在 rehab_child 上。本页以前**只提交了档案对象**，
      // 这些输入全部被静默丢弃（后端还会顺手补一个只有姓名的儿童），
      // 用户看到「创建成功」却在 OA 里查不到 —— 这是本次修复的核心缺陷。
      int? childId = _createdChildId;
      // 复用上一次建好的 childId：第二段（建档案）失败后用户点重试时，
      // 绝不能再建一个儿童 —— 否则会凭空多出一条儿童主档。
      childId ??= await repo.createChildProfile(ChildProfile(
        name: _nameCtrl.text.trim(),
        childType: _templateType,
        studentType: _templateType == 'AUTISM' ? 'NEW' : _studentType,
        gender: _gender,
        birthDate: _birthDate,
        idNumber: _idCtrl.text.trim(),
        className: _classCtrl.text.trim(),
        admissionDate: _enrollDate,
        guardianName: _guardianCtrl.text.trim(),
        guardianRelation: _relationCtrl.text.trim(),
        familyPhone: _phoneCtrl.text.trim(),
        homeAddress: _addressCtrl.text.trim(),
        // 未展开第二位家长时提交空串 ⇒ 后端存 NULL，
        // 与「填了又清空」是同一个终态，不会留下空壳行。
        guardian2Name: _showSecondGuardian ? _g2NameCtrl.text.trim() : '',
        guardian2Relation: _showSecondGuardian ? _g2RelCtrl.text.trim() : '',
        guardian2Phone: _showSecondGuardian ? _g2PhoneCtrl.text.trim() : '',
        federationOpinion: _fedCtrl.text.trim(),
        campusId: _campusId,
      ));
      if (!mounted) return;
      if (childId == null) {
        // 主档建不出来就**绝不能**继续去建档案：后端在 childId 为空时会自动
        // 补建一个只有姓名的儿童，界面照样提示「创建成功」，家长信息却已经丢了。
        _toast('创建儿童档案失败，请检查网络或后台后重试');
        setState(() => _submitting = false);
        return;
      }
      _createdChildId = childId; // 第二段若失败，用户重试时复用，避免建出两个儿童

      // ── ② 再建康复档案，用 childId 与主档建立关联 ──────────────────
      final RehabArchive archive = RehabArchive(
        id: '',
        childName: _nameCtrl.text.trim(),
        templateType: _templateType,
        status: ArchiveStatus.draft,
        campusName: _campusNameOf(_campusId),
        // 听障档案不使用孤独症量表，统一回落 STANDARD 由后端忽略。
        evalFormCode: _templateType == 'AUTISM' ? _evalFormCode : 'STANDARD',
        // 新生=需先做首次评估（完成后自动排 1 个月后的持续评估提醒）；
        // 老生=可不做首评，建档即排一条「今天」的持续评估待填提醒。
        studentType: _templateType == 'AUTISM' ? 'NEW' : _studentType,
        childId: childId,
        campusId: _campusId,
      );
      final String id = await repo.createArchive(archive);
      if (!mounted) return;
      if (id.isEmpty) {
        // 主档已落库，所以措辞要说清「不是全丢了」，避免用户重复录入。
        _toast('儿童信息已保存，但档案创建失败，请重试或到 OA 儿童管理中补建档案');
        setState(() => _submitting = false);
        return;
      }
      // 跳转儿童中枢，从那里进入对应模板的首次评估/评测录入。
      // 用 pushReplacement 保留主页栈，使中枢 AppBar 拥有返回按钮。
      context.pushReplacement('/children/$id');
    } catch (e) {
      if (!mounted) return;
      _toast(_createdChildId == null ? '创建失败：$e' : '儿童信息已保存，档案创建失败：$e');
      setState(() => _submitting = false);
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    // 量表清单来自后端 /api/rehab/autism/forms；加载中或异常时用内置三套兜底，
    // 保证「新建孤独症儿童」始终能看到三套可选模板。
    final AsyncValue<List<AutismEvalForm>> formsAsync =
        ref.watch(evalFormsProvider);
    final List<_FormOption> formOptions = formsAsync.maybeWhen(
      data: (List<AutismEvalForm> list) {
        if (list.isEmpty) return _builtinForms;
        final List<_FormOption> opts = list
            .map((AutismEvalForm f) {
              String name = f.formName.isEmpty ? f.formCode : f.formName;
              String desc = (f.description ?? '').trim();
              // 纯前端文案约定：避免依赖后端种子，便于独立调整。
              if (f.formCode == 'OFFLINE') name = 'C-PEP3';
              if (f.formCode == 'PEP3') name = 'PEP-3';
              return _FormOption(f.formCode, name, desc);
            })
            .toList();
        // 注入 PEP-3（不答题、只填月龄；与 C-PEP3 报告同构但完全独立模板）。
        // 后端种子暂未包含该 code（2026-09-01 引入），前端固定追加以便后续
        // 模板继续按此模式独立接入。后端将来补种后此注入为幂等。
        if (!opts.any((_FormOption o) => o.code == 'PEP3')) {
          opts.add(const _FormOption(
            'PEP3',
            'PEP-3',
            '教师为 9 个领域填预估月龄，按年龄反查档位直接出报告（不答题）。',
          ));
        }
        return opts;
      },
      orElse: () => _builtinForms,
    );

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
                    decoration: const InputDecoration(labelText: '儿童姓名 *'),
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
                              decoration: const InputDecoration(
                                labelText: '出生日期 *',
                                errorText: null,
                              ),
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
            _campusStep(),
            const SizedBox(height: 16),
            _StepCard(
              index: 3,
              title: '家长信息',
              // 右上角「+」：展开第二位家长（选填）。收起时不提交那两个字段，
              // 库里落 NULL，与「填了又清空」终态一致。
              trailing: IconButton(
                icon: Icon(_showSecondGuardian
                    ? Icons.remove_circle_outline
                    : Icons.add_circle_outline),
                tooltip: _showSecondGuardian ? '收起第二位家长' : '添加第二位家长',
                onPressed: () =>
                    setState(() => _showSecondGuardian = !_showSecondGuardian),
              ),
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
                  // 「+」展开的第二位家长。收起时这些字段不参与提交（落 NULL）。
                  if (_showSecondGuardian) ...<Widget>[
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 16),
                    Row(
                      children: <Widget>[
                        Icon(Icons.person_add_alt_1_outlined,
                            size: 18,
                            color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 6),
                        Text('第二位家长',
                            style: textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700)),
                        const Spacer(),
                        Text('选填',
                            style: textTheme.bodySmall?.copyWith(
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
                      style: textTheme.bodySmall?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            _fedStep(),
            const SizedBox(height: 16),
            _StepCard(
              index: 5,
              title: '选择特殊教育类型',
              subtitle: '将按类型创建对应的评估与干预模板',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: _TypeChoice(
                          selected: _templateType == 'HEARING',
                          title: '听障',
                          // 听障业务已收敛为三项：首次评估 / 持续评估 / 教学计划。
                          desc: '首次评估 / 持续评估 / 教学计划',
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
                  // 听障专属：新生/老生决定后续流程起点（首评 → 持续评估 → 教学计划）。
                  if (_templateType == 'HEARING') ...<Widget>[
                    const SizedBox(height: 20),
                    const Divider(height: 1),
                    const SizedBox(height: 16),
                    Text(
                      '学生类型',
                      style: textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '新生：先做首次评估，完成后自动排 1 个月后的持续评估提醒'
                      '（此后每 2 个月一次）。\n'
                      '老生：可直接填写持续评估，建档后即可开始。',
                      style: textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SegmentedButton<String>(
                      expandedInsets: EdgeInsets.zero,
                      segments: const <ButtonSegment<String>>[
                        ButtonSegment<String>(
                          value: 'NEW',
                          label: Text('新生'),
                          icon: Icon(Icons.fiber_new_outlined),
                        ),
                        ButtonSegment<String>(
                          value: 'OLD',
                          label: Text('老生'),
                          icon: Icon(Icons.person_outline),
                        ),
                      ],
                      selected: <String>{_studentType},
                      onSelectionChanged: (Set<String> s) =>
                          setState(() => _studentType = s.first),
                    ),
                  ],
                  if (_templateType == 'AUTISM') ...<Widget>[
                    const SizedBox(height: 20),
                    const Divider(height: 1),
                    const SizedBox(height: 16),
                    Row(
                      children: <Widget>[
                        Text(
                          '选择评测量表',
                          style: textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(width: 8),
                        if (formsAsync.isLoading)
                          const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '三套量表相互独立，请按儿童实际情况选择；建档后仍可在档案的「评测量表」页切换。',
                      style: textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (final _FormOption o in formOptions)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _FormChoice(
                          selected: _evalFormCode == o.code,
                          title: o.name,
                          desc: o.desc,
                          onTap: () => setState(() => _evalFormCode = o.code),
                        ),
                      ),
                  ],
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
    this.trailing,
    required this.child,
  });
  final int index;
  final String title;
  final String? subtitle;
  /// 标题行右侧的操作区（如家长卡片的「+ 添加第二位家长」）。
  final Widget? trailing;
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
                if (trailing != null) trailing!,
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

/// 量表候选项（后端 /forms 未就绪时的展示兜底）。
class _FormOption {
  const _FormOption(this.code, this.name, this.desc);
  final String code;
  final String name;
  final String desc;
}

/// 内置量表兜底（后端 /forms 未就绪时使用）。文案与显示名保持与运行时一致：
/// OFFLINE 渲染为 C-PEP3、注入 PEP-3。PEP-3 与 C-PEP3 是两套独立模板，
/// 不要共用 code，未来若新增其他模板请按此模式独立追加。
const List<_FormOption> _builtinForms = <_FormOption>[
  _FormOption('STANDARD', '残联标准',
      '8 大领域 + 情绪与行为共 493 题；普通领域 P/E/F/X，情绪行为 A/M/S。'),
  _FormOption('OFFLINE', 'C-PEP3',
      '适用于线下 A/B 卷评估；老师用纸质题本评估后录入题号对应选项。'),
  _FormOption('VB', 'VB（言语行为评估）',
      '含总项目 / 子项目层级结构；按 P（通过）/ A（辅助）评级。'),
  _FormOption('PEP3', 'PEP-3',
      '教师为 9 个领域填预估月龄，按年龄反查档位直接出报告（不答题）。'),
];

/// 量表单选行：与 [_TypeChoice] 同一视觉语言，改为纵向列表以容纳说明文字。
class _FormChoice extends StatelessWidget {
  const _FormChoice({
    required this.selected,
    required this.title,
    required this.desc,
    required this.onTap,
  });
  final bool selected;
  final String title;
  final String desc;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? colors.primary : colors.outlineVariant,
            width: selected ? 2 : 1,
          ),
          color: selected ? colors.primaryContainer : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 20,
              color: selected ? colors.primary : colors.onSurfaceVariant,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: textTheme.bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  if (desc.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(
                      desc,
                      style: textTheme.bodySmall
                          ?.copyWith(color: colors.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
            ),
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
