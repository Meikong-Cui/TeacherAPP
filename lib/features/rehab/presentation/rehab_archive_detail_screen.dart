import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:teacher_app/data/models/rehab.dart';
import 'package:teacher_app/features/ai_lesson_plan/data/ai_lesson_plan_repository.dart';
import 'package:teacher_app/features/rehab/presentation/hearing_record_tab.dart';
import 'package:teacher_app/features/rehab/presentation/widgets/export_pdf_button.dart';
import 'package:teacher_app/features/rehab/presentation/widgets/hearing_symbol.dart';
import 'package:teacher_app/features/rehab/provider/rehab_provider.dart';

// ════════════════════════════════════════════════════════════════
//  全局工具组件
// ════════════════════════════════════════════════════════════════

/// 信息行（只读）。
Widget _infoRow(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 100, child: Text(label, style: const TextStyle(color: Colors.black54, fontSize: 13))),
        Expanded(child: Text(value.isEmpty ? '—' : value, style: const TextStyle(fontSize: 14))),
      ]),
    );

/// 日期选择字段。
class _DateField extends StatefulWidget {
  const _DateField({required this.label, this.value, required this.onChanged});
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  @override
  State<_DateField> createState() => _DateFieldState();
}

class _DateFieldState extends State<_DateField> {
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: InkWell(
          onTap: () async {
            final DateTime? picked = await showDatePicker(
              context: context, initialDate: widget.value ?? DateTime.now(),
              firstDate: DateTime(2000), lastDate: DateTime(2030),
            );
            if (picked != null) widget.onChanged(picked);
          },
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: widget.label,
              labelStyle: const TextStyle(fontSize: 13),
              border: InputBorder.none,
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade300)),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Theme.of(context).colorScheme.primary)),
              contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 0),
              suffixIcon: const Icon(Icons.calendar_today, size: 18),
            ),
            child: Text(widget.value == null ? '选择日期' : DateFormat('yyyy-MM-dd').format(widget.value!),
                style: const TextStyle(fontSize: 14)),
          ),
        ),
      );
}

// ════════════════════════════════════════════════════════════════
//  档案详情主页面
// ════════════════════════════════════════════════════════════════

class RehabArchiveDetailScreen extends ConsumerStatefulWidget {
  const RehabArchiveDetailScreen({required this.archiveId, super.key});
  final String archiveId;

  @override
  ConsumerState<RehabArchiveDetailScreen> createState() =>
      _RehabArchiveDetailScreenState();
}

class _RehabArchiveDetailScreenState
    extends ConsumerState<RehabArchiveDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    Future.microtask(
        () => ref.read(rehabArchiveDetailProvider(widget.archiveId).notifier).load(widget.archiveId));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final RehabArchiveDetailState state =
        ref.watch(rehabArchiveDetailProvider(widget.archiveId));

    if (state.error != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(state.error!)));
        ref
            .read(rehabArchiveDetailProvider(widget.archiveId).notifier)
            .clearError();
      });
    }
    if (state.message != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(state.message!)));
        ref
            .read(rehabArchiveDetailProvider(widget.archiveId).notifier)
            .clearMessage();
      });
    }

    // 听障档案详情固定为 5 Tab（首次评估 / 持续评估 / 教学计划 / 听能管理 / 手写照片）。
    // OFFLINE / VB 等孤独症模板已独立到 /rehab-autism/:id，不再在此路由展示。
    return Scaffold(
      appBar: AppBar(
        title: Text(state.detail?.archive.childName ?? '档案详情'),
        actions: <Widget>[
          // 整档导出：首次 + 持续 + 听能 + 计划合订本，与 OA 网页同一份官方表单。
          ExportPdfButton(
            iconOnly: true,
            tooltip: '导出整档 PDF',
            filename:
                '听障康复档案_${state.detail?.archive.childName ?? widget.archiveId}.pdf',
            fetchBytes: () => ref
                .read(rehabRepositoryProvider)
                .exportHearingArchivePdf(widget.archiveId),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const <Widget>[
            Tab(text: '首次评估'),
            Tab(text: '持续评估'),
            Tab(text: '教学计划'),
            Tab(text: '听能管理'),
            Tab(text: '手写照片'),
          ],
        ),
      ),
      body: state.loading && state.detail == null
          ? const Center(child: CircularProgressIndicator())
          : state.detail == null
              ? const Center(child: Text('未找到档案'))
              : TabBarView(
                  controller: _tabController,
                  children: <Widget>[
                    _FirstEvalTab(archiveId: widget.archiveId),
                    _ContEvalTab(archiveId: widget.archiveId),
                    _PlanTab(archiveId: widget.archiveId),
                    HearingRecordTab(archiveId: widget.archiveId),
                    _PhotoTab(archiveId: widget.archiveId),
                  ],
                ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  首次评估 Tab — 三段式无边框 UI（按听障模板 1.1.1 截图逐行）
// ════════════════════════════════════════════════════════════════

class _FirstEvalTab extends ConsumerStatefulWidget {
  const _FirstEvalTab({required this.archiveId});
  final String archiveId;
  @override
  ConsumerState<_FirstEvalTab> createState() => _FirstEvalTabState();
}

class _FirstEvalTabState extends ConsumerState<_FirstEvalTab> {
  @override
  Widget build(BuildContext context) {
    final RehabArchiveDetailState state =
        ref.watch(rehabArchiveDetailProvider(widget.archiveId));
    final RehabFirstEval? fe = state.detail?.firstEval;

    // ── 始终只读；编辑走独立页面 ──
    if (fe == null) {
      return Center(child: FilledButton(
        onPressed: () => context.push('/rehab/${widget.archiveId}/first-eval-edit'),
        child: const Text('填写首次评估'),
      ));
    }
    return Stack(children: [
      _ReadOnlyView(fe: fe, onEdit: () {}),
      Positioned(bottom: 16, right: 16,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ExportPdfButton(
            fab: true,
            heroTag: 'export_first_eval',
            tooltip: '导出首次评估 PDF',
            filename: '听障首次评估_${fe.name.isEmpty ? widget.archiveId : fe.name}.pdf',
            // 后端按 firstEvalId 出 PDF，未保存的记录没有 id。
            enabled: fe.id != null && fe.id!.isNotEmpty,
            fetchBytes: () => ref
                .read(rehabRepositoryProvider)
                .exportHearingFirstEvalPdf(fe.id!),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.small(
            onPressed: () => context.push('/rehab/${widget.archiveId}/first-eval-edit'),
            heroTag: 'edit_first_eval',
            child: const Icon(Icons.edit, size: 18),
          ),
        ]),
      ),
    ]);
  }
}


// ════════════════════════════════════════════════════════════════
//  首次评估只读展示（三段式，带编辑入口）
// ════════════════════════════════════════════════════════════════

class _ReadOnlyView extends ConsumerWidget {
  const _ReadOnlyView({required this.fe, required this.onEdit});
  final RehabFirstEval fe;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(length: 3, child: Column(children: [
      TabBar(labelColor: Theme.of(context).colorScheme.primary, unselectedLabelColor: Colors.grey,
        tabs: const [Tab(text: '基础资料'), Tab(text: '评估内容'), Tab(text: '综合建议')]),
      Expanded(child: TabBarView(children: [
        _roPart1(context), _roPart2(context), _roPart3(context),
      ])),
    ]));
  }

  Widget _ro(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 150, child: Text(label, style: const TextStyle(color: Colors.black54, fontSize: 13))),
          Expanded(child: Text(value.isEmpty ? '—' : value, style: const TextStyle(fontSize: 14))),
        ]),
      );

  Widget _sect(BuildContext context, String t) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 14, 0, 8),
        child: Row(children: [
          Container(width: 4, height: 16, decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Text(t, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14,
              color: Theme.of(context).colorScheme.primary)),
        ]),
      );

  /// 小节内的次级标题。
  Widget _sub(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 10, 0, 2),
        child: Text(t, style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
      );

  /// 从领域 Map 取值：List 用「、」连接，其余直接字符串化。
  /// 修复前这里是整个 Map 的 toString()，页面上显示成 {k: v} 原始 JSON。
  String _v(Map<String, dynamic>? m, String key) {
    final dynamic x = m?[key];
    if (x == null) return '';
    if (x is List) return x.join('、');
    return x.toString();
  }

  /// 领域内一题。
  Widget _q(Map<String, dynamic>? m, String label, String key) => _ro(label, _v(m, key));

  String _fmt(DateTime? d) => d == null ? '' : DateFormat('yyyy-MM-dd').format(d);

  /// 助听后听阈表（左右耳 × 6 个频率）。
  Widget _thresholdTable(BuildContext ctx) {
    const freqs = <String>['250', '500', '1k', '2k', '3k', '4k'];
    Widget cell(String t, {bool head = false}) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300, width: .5)),
            child: Text(t.isEmpty ? '—' : t, textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12,
                    fontWeight: head ? FontWeight.w600 : FontWeight.normal)),
          ),
        );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(children: [
        Row(children: [cell('频率(Hz)', head: true), ...freqs.map((f) => cell(f, head: true))]),
        Row(children: [cell('左耳', head: true), ...freqs.map((f) => cell(fe.threshold('left', f)))]),
        Row(children: [cell('右耳', head: true), ...freqs.map((f) => cell(fe.threshold('right', f)))]),
      ]),
    );
  }

  /// 自理能力一项：出现 / 尚未出现。
  Widget _selfCare(String label, String key) {
    final m = fe.selfCareNote;
    final appeared = _v(m, '${key}_appeared');
    final notYet = _v(m, '${key}_notYet');
    String val = '';
    if (appeared.isNotEmpty) {
      val = '出现';
    } else if (notYet.isNotEmpty) {
      val = '尚未出现';
    }
    return _ro(label, val);
  }

  Widget _roPart1(BuildContext ctx) => ListView(padding: const EdgeInsets.all(16), children: [
        _sect(ctx, '一、基本情况'),
        _ro('姓名', fe.name), _ro('性别', fe.gender),
        _ro('出生年月', _fmt(fe.birthDate)),
        _ro('民族', fe.ethnicity), _ro('户口所在地', fe.hukouLocation),
        _ro('身份证号', fe.idNumber),
        _ro('入园时间', _fmt(fe.enrollmentDate)),
        _ro('班级', fe.className),

        _sect(ctx, '二、听力状况'),
        _ro('听障确诊时间', _fmt(fe.diagnosisConfirmDate)),
        _ro('左耳 dB(HL)', fe.leftEarDb), _ro('右耳 dB(HL)', fe.rightEarDb),
        _ro('左耳补偿方式', fe.leftCompensationType), _ro('左耳设备型号', fe.leftDeviceModel),
        _ro('右耳补偿方式', fe.rightCompensationType), _ro('右耳设备型号', fe.rightDeviceModel),
        _ro('左耳验配/开机', _fmt(fe.leftFittingDate)),
        _ro('右耳验配/开机', _fmt(fe.rightFittingDate)),
        _sub('助听后听阈（dB HL）'),
        _thresholdTable(ctx),
        _ro('听力刺激策略', fe.hearingStimStrategy),

        _sect(ctx, '三、沟通与康复史'),
        _ro('沟通模式', fe.commMode),
        _ro('发现问题年龄', fe.problemFoundAge),
        _ro('开始康复年龄', fe.rehabStartAge),
        _ro('既往康复经历', fe.pastRehabExp),

        _sect(ctx, '四、家庭资料'),
        _sub('父亲'),
        _ro('姓名', fe.father('name')), _ro('年龄', fe.father('age')),
        _ro('民族', fe.father('ethnicity')), _ro('文化程度', fe.father('education')),
        _ro('职业', fe.father('occupation')), _ro('联系方式', fe.father('contact')),
        _sub('母亲'),
        _ro('姓名', fe.mother('name')), _ro('年龄', fe.mother('age')),
        _ro('民族', fe.mother('ethnicity')), _ro('文化程度', fe.mother('education')),
        _ro('职业', fe.mother('occupation')), _ro('联系方式', fe.mother('contact')),
        _sub('家庭情况'),
        _ro('家庭状况', fe.familyStatus),
        _ro('主要输入语言类型', fe.familyInputLangType),
        _ro('家庭语言环境', fe.familyLangEnv),
        _ro('主要照顾者', fe.caregiver),
        _ro('照顾者与儿童关系', fe.caregiverRelation),
        _ro('照顾者联系方式', fe.caregiverContact),
        _ro('现居住地址', fe.homeAddress),
        _ro('家庭对听障认知', fe.familyAwareness),
        _ro('家庭配合度', fe.familyCooperation),
        const SizedBox(height: 20),
      ]);

  Widget _roPart2(BuildContext ctx) {
    final hm = fe.domainHearingMgmt;
    final ha = fe.domainHearingAbility;
    final lg = fe.domainLanguage;
    final sp = fe.domainSpeech;
    final cg = fe.domainCognition;
    final cm = fe.domainCommunication;
    final bh = fe.behaviorNote;
    final pt = fe.parentTrainingNote;
    return ListView(padding: const EdgeInsets.all(16), children: [
      _sect(ctx, '听能管理'),
      _q(hm, '家长了解助听设备保养及检查程序', 'deviceCareProgram'),
      _q(hm, '除睡觉洗澡游泳外均配戴设备', 'alwaysWear'),
      _q(hm, '家中听觉环境', 'homeEnv'),
      _q(hm, '幼儿的听觉习惯', 'hearingHabit'),
      _q(hm, '已有助听设备保养工具', 'careTools'),
      _q(hm, '配戴后对声音反应的改变', 'reactionChange'),

      _sect(ctx, '听觉能力'),
      _q(ha, '对环境声音的反应', 'envSoundReaction'),
      _q(ha, '对语音的反应', 'voiceReaction'),
      _q(ha, '对名字/家人称谓的反应', 'nameCallReaction'),
      _q(ha, '对林氏六音的反应', 'lingSixReaction'),
      _ro('听觉记忆（项）', fe.d('hearingAbility', 'auditoryMemory.count')),
      _ro('听觉描述阶段', fe.d('hearingAbility', 'auditoryDesc.stages')),
      _ro('言语识别平均得分', fe.d('hearingAbility', 'evalScore')),
      _ro('CAP 听觉行为分级', fe.d('hearingAbility', 'capLevel')),

      _sect(ctx, '语言能力'),
      _q(lg, '沟通模式', 'commMode'),
      _q(lg, '理解性语言程度', 'understandingLevel'),
      _q(lg, '表达性语言程度', 'expressingNone'),
      _ro('模仿复述', fe.d('language', 'expressImitate')),
      _ro('主动表达', fe.d('language', 'expressActive')),
      _sub('表征性语言发展阶段'),
      _q(lg, '咿呀期（简发音）', 'stageBabbling'),
      _q(lg, '儿语期（连续音节）', 'stageCooing'),
      _q(lg, '模仿期（学语萌芽）', 'stageImitate'),
      _q(lg, '单词期（单词句）', 'stageWord'),
      _q(lg, '胡语期（乱语）', 'stageJargon'),
      _q(lg, '电报期（双词句）', 'stageTelegraphic'),
      _q(lg, '完整句阶段', 'stageComplete'),
      _sub('问句能力'),
      _q(lg, '理解并回答问句', 'questionUnderstand'),
      _q(lg, '会表达问句', 'questionExpress'),
      _ro('平均语言年龄水平', fe.d('language', 'evalScore')),
      _ro('SIR 言语可懂度分级', fe.d('language', 'sirLevel')),

      _sect(ctx, '言语能力'),
      _q(sp, '能否发出声音', 'canVoice'),
      _q(sp, '超音段', 'supraSegmental'),
      _ro('模仿发音', fe.d('speech', 'imitationNote')),

      _sect(ctx, '认知能力'),
      for (final f in const ['分类', '配对', '颜色', '形状', '质感', '数学概念', '排序'])
        _q(cg, f, f.toLowerCase()),
      _q(cg, '其他思维能力', 'otherThinking'),
      _q(cg, '格雷费斯发育商', 'griffiths'),
      _q(cg, '希-内智商/学习能力商', 'binet'),

      _sect(ctx, '沟通能力'),
      _q(cm, '表达需求的方式', 'expressMode'),
      _q(cm, '等待能力、轮替', 'turnTaking'),
      _q(cm, '眼神交流', 'eyeContact'),
      _q(cm, '主动提问', 'activeQuestion'),
      _q(cm, '主动互动', 'activeInteraction'),
      _q(cm, '维持话题', 'maintainTopic'),
      _q(cm, '开启话题', 'openTopic'),

      _sect(ctx, '行为表现'),
      _q(bh, '好奇心', 'curiosity'),
      _q(bh, '稳定性', 'stability'),
      _ro('行为问题', fe.d('behavior', 'problemNote')),

      _sect(ctx, '自理能力'),
      _sub('入厕'),
      _selfCare('有需求时能自己入厕', 'toiletSelf'),
      _selfCare('提醒下便后会冲洗', 'toiletRemind'),
      _sub('进餐'),
      _selfCare('能使用小勺独立进餐', 'eatingSelf'),
      _selfCare('餐后主动漱口擦嘴', 'eatingWipe'),
      _sub('穿衣'),
      _selfCare('能自己穿脱衣裤鞋袜', 'dressingSelf'),
      _sub('卫生习惯'),
      _selfCare('能自己擦鼻涕', 'hygieneNose'),
      _selfCare('饭前便后手脏时洗手', 'hygieneWash'),
      _selfCare('提醒下能早晚刷牙', 'hygieneBrush'),
      _sub('安全'),
      _selfCare('外出跟随成人不乱跑', 'safetyFollow'),
      _selfCare('游戏时不做危险动作', 'safetyGame'),

      _sect(ctx, '家长受训经验及教育能力'),
      _q(pt, '已参加家长培训', 'trained'),
      _q(pt, '与孩子互动与游戏', 'interaction'),
      _q(pt, '对孩子耳聋的情绪阶段', 'emotionStage'),
      _q(pt, '家长参与课堂表现', 'classPresence'),
      _q(pt, '技巧学习能力', 'skillLearn'),
      _q(pt, '教养观念与信念', 'parentBelief'),
      _q(pt, '对孩子的期望值', 'expectation'),
      _q(pt, '对孩子的敏感度', 'sensitivity'),
      _q(pt, '对幼儿发展的认知', 'devCognition'),
      _q(pt, '阅读习惯', 'readingHabit'),
      _q(pt, '作息规律性', 'routine'),
      _q(pt, '资料收集能力', 'dataCollect'),
      _q(pt, '回应孩子需求', 'respondNeed'),
      const SizedBox(height: 20),
    ]);
  }

  Widget _roPart3(BuildContext ctx) => ListView(padding: const EdgeInsets.all(16), children: [
        _sect(ctx, '综合分析与康复建议'),
        _ro('1. 简要描述、判断', fe.briefDesc),
        _ro('2. 分析', fe.analysis),
        _ro('3. 康复建议', fe.suggestion),
        _sect(ctx, '评估信息'),
        _ro('评估人', fe.evaluatorName),
        _ro('评估日期', _fmt(fe.evalDate)),
        const SizedBox(height: 20),
      ]);
}

// ════════════════════════════════════════════════════════════════
//  持续评估 Tab — 三段式无边框 UI（按听障模板 1.1.2 截图）
// ════════════════════════════════════════════════════════════════

class _ContEvalTab extends ConsumerStatefulWidget {
  const _ContEvalTab({required this.archiveId});
  final String archiveId;
  @override
  ConsumerState<_ContEvalTab> createState() => _ContEvalTabState();
}

class _ContEvalTabState extends ConsumerState<_ContEvalTab> {
  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(rehabArchiveDetailProvider(widget.archiveId)).detail;
    final list = detail?.contEvals ?? <RehabContEval>[];
    final fe = detail?.firstEval;

    if (list.isEmpty && fe == null) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Text('请先填写首次评估', style: TextStyle(color: Colors.black45, fontSize: 14)),
        const SizedBox(height: 12),
        FilledButton.tonal(
          onPressed: () => context.push('/rehab/${widget.archiveId}/first-eval-edit'),
          child: const Text('去填写首次评估'),
        ),
      ]));
    }

    return ListView(padding: const EdgeInsets.all(16), children: [
      // ── 已有持续评估记录 ──
      if (list.isNotEmpty) ...[
        Text('历史持续评估', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15,
            color: Theme.of(context).colorScheme.primary)),
        const SizedBox(height: 8),
        ...list.map((c) => Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('第 ${(c.evalSeq ?? list.indexOf(c) + 1)} 次',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                _statusChip(c.status),
              ]),
              const SizedBox(height: 6),
              _infoRow('评估日期', c.evalDate == null ? '未填' : DateFormat('yyyy-MM-dd').format(c.evalDate!)),
              _infoRow('应完成日期', c.dueDate == null ? '—' : DateFormat('yyyy-MM-dd').format(c.dueDate!)),
              _infoRow('生理年龄', c.physiologicalAge.isEmpty ? '—' : c.physiologicalAge),
              _infoRow('听觉年龄', c.hearingAge.isEmpty ? '—' : c.hearingAge),
              if (c.evaluatorName.isNotEmpty)
                _infoRow('评估者', c.evaluatorName),
              if (c.teacherNotes.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text('教师评语: ${c.teacherNotes}', style: const TextStyle(fontSize: 13, color: Colors.black54)),
              ],
              const SizedBox(height: 8),
              Align(alignment: Alignment.centerRight,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  ExportPdfButton(
                    label: '导出 PDF',
                    enabled: c.id != null && c.id!.isNotEmpty,
                    filename: '听障持续评估_${detail?.archive.childName ?? ''}_'
                        '${c.evalDate == null ? '' : DateFormat('yyyyMMdd').format(c.evalDate!)}.pdf',
                    fetchBytes: () => ref
                        .read(rehabRepositoryProvider)
                        .exportHearingContEvalPdf(c.id!),
                  ),
                  TextButton.icon(
                    // 带上 evalId 才会加载这条记录进行编辑，否则会新建一条。
                    onPressed: () => context.push(
                        '/rehab/${widget.archiveId}/cont-eval-edit?evalId=${c.id ?? ''}'),
                    icon: const Icon(Icons.edit, size: 16), label: const Text('编辑')),
                ])),
            ],
          ),
        ),
      )),
        const Divider(),
      ],

      // ── 新建/编辑按钮 ──
      Center(child: FilledButton.icon(
        onPressed: () => context.push('/rehab/${widget.archiveId}/cont-eval-edit'),
        icon: const Icon(Icons.add, size: 18),
        label: Text(list.isEmpty ? '填写首次持续评估' : '新建持续评估'),
      )),
    ]);
  }

  /// 状态标签。
  Widget _statusChip(ContEvalStatus s) {
    Color bg, fg;
    switch (s) {
      case ContEvalStatus.done:
        bg = Colors.green.shade100; fg = Colors.green.shade800;
      case ContEvalStatus.overdue:
        bg = Colors.red.shade100; fg = Colors.red.shade800;
      case ContEvalStatus.pending:
        bg = Colors.orange.shade100; fg = Colors.orange.shade800;
    }
    return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Text(s.label, style: TextStyle(fontSize: 11, color: fg, fontWeight: FontWeight.w500)));
  }
}


// ════════════════════════════════════════════════════════════════
//  教学计划 Tab（保持不变）
// ════════════════════════════════════════════════════════════════

class _PlanTab extends ConsumerStatefulWidget {
  const _PlanTab({required this.archiveId});
  final String archiveId;
  @override
  ConsumerState<_PlanTab> createState() => _PlanTabState();
}

class _PlanTabState extends ConsumerState<_PlanTab> {
  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(rehabArchiveDetailProvider(widget.archiveId)).detail;
    final plans = detail?.plans ?? <RehabTeachingPlan>[];

    if (plans.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.school_outlined, size: 48, color: Colors.black26),
        const SizedBox(height: 12),
        const Text('暂无教学计划', style: TextStyle(color: Colors.black45, fontSize: 14)),
        const SizedBox(height: 12),
        FilledButton.tonal(
          onPressed: () => _createPlan(),
          child: const Text('新建教学计划'),
        ),
      ]));
    }

    return ListView(padding: const EdgeInsets.all(16), children: [
      ...plans.map((p) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: InkWell(
          onTap: () => _showPlanEditDialog(context, p),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Expanded(child: Text(
                  p.planPeriodStart == null ? '教学计划'
                      : '${DateFormat('yyyy-MM-dd').format(p.planPeriodStart!)} ~ ${p.planPeriodEnd == null ? "" : DateFormat("yyyy-MM-dd").format(p.planPeriodEnd!)}',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
                if (p.aiGenerated) Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.purple.shade50, borderRadius: BorderRadius.circular(8)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.auto_awesome, size: 12, color: Colors.purple),
                    const SizedBox(width: 2),
                    const Text('AI', style: TextStyle(fontSize: 10, color: Colors.purple)),
                  ])),
              ]),
              const SizedBox(height: 8),
              if (p.hearingGoal.isNotEmpty) _goalRow('听能', p.hearingGoal),
              if (p.speechGoal.isNotEmpty) _goalRow('言语', p.speechGoal),
              if (p.languageGoal.isNotEmpty) _goalRow('语言', p.languageGoal),
              if (p.cognitionGoal.isNotEmpty) _goalRow('认知', p.cognitionGoal),
              if (p.communicationGoal.isNotEmpty) _goalRow('沟通', p.communicationGoal),
              if (p.familyGuidance.isNotEmpty) _goalRow('家庭指导', p.familyGuidance),
              if (p.otherGoal.isNotEmpty) _goalRow('其他', p.otherGoal),
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                if (p.id != null && p.id!.isNotEmpty)
                  ExportPdfButton(
                    label: '导出 PDF',
                    filename: '听障教学计划_${detail?.archive.childName ?? ''}_'
                        '${p.planPeriodStart == null ? '' : DateFormat('yyyyMMdd').format(p.planPeriodStart!)}.pdf',
                    fetchBytes: () => ref
                        .read(rehabRepositoryProvider)
                        .exportHearingPlanPdf(p.id!),
                  ),
                if (p.id != null && p.id!.isNotEmpty)
                  TextButton.icon(
                    onPressed: () => _confirmDelete(p.id!, context),
                    icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                    label: const Text('删除', style: TextStyle(color: Colors.red, fontSize: 12)),
                    style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 6)),
                  ),
                if (!p.aiGenerated && p.id != null)
                  TextButton.icon(onPressed: () => _openAiLessonPlan(detail, p),
                    icon: const Icon(Icons.auto_awesome, size: 16), label: const Text('AI 补全')),
                TextButton.icon(onPressed: () => _createPlan(),
                  icon: const Icon(Icons.add, size: 16), label: const Text('新建计划')),
              ]),
            ]),
          ),
        ),
      )),
      Center(child: FilledButton.tonal(
        onPressed: () => _createPlan(),
        child: const Text('+ 新建教学计划'),
      )),
    ]);
  }

  Widget _goalRow(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 56, child: Text('$label：', style: const TextStyle(fontSize: 13, color: Colors.black54))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ]));

  Future<void> _createPlan() async {
    final now = DateTime.now();
    final plan = RehabTeachingPlan(
      archiveId: widget.archiveId,
      planPeriodStart: now,
      planPeriodEnd: now.add(const Duration(days: 60)),
      teacherName: '教师',
    );
    await ref.read(rehabArchiveDetailProvider(widget.archiveId).notifier).createPlan(plan);
  }

  /// 打开 AI 写教案（5 大领域生成器），带入该儿童档案信息与目标教学计划。
  void _openAiLessonPlan(RehabArchiveDetail? detail, RehabTeachingPlan plan) {
    if (detail == null) return;
    final RehabFirstEval? fe = detail.firstEval;
    final RehabContEval? latestCont =
        detail.contEvals.isNotEmpty ? detail.contEvals.last : null;
    final String phys = (latestCont != null && latestCont.physiologicalAge.isNotEmpty)
        ? latestCont.physiologicalAge
        : _ageFromBirth(fe?.birthDate);
    final String hear = (latestCont != null && latestCont.hearingAge.isNotEmpty)
        ? latestCont.hearingAge
        : '';
    final String device = _deviceWearFrom(fe);

    context.push('/ai-lesson-plan', extra: AiLessonPlanLaunchContext(
      archiveId: int.tryParse(widget.archiveId),
      childName: detail.archive.childName,
      gender: fe?.gender ?? '',
      physiologicalAge: phys,
      hearingAge: hear,
      deviceWear: device,
      plan: plan,
    ));
  }

  String _ageFromBirth(DateTime? birth) {
    if (birth == null) return '';
    final DateTime now = DateTime.now();
    int months = (now.year - birth.year) * 12 +
        now.month -
        birth.month -
        (now.day < birth.day ? 1 : 0);
    if (months < 0) months = 0;
    return '${months ~/ 12}岁${months % 12}个月';
  }

  String _deviceWearFrom(RehabFirstEval? fe) {
    if (fe == null) return '双侧';
    final bool left = fe.leftCompensationType.isNotEmpty;
    final bool right = fe.rightCompensationType.isNotEmpty;
    if (left && right) return '双侧';
    if (left || right) return '单侧';
    return '双侧';
  }

  Future<void> _confirmDelete(String planId, BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除教学计划'),
        content: const Text('确定要删除这条教学计划吗？此操作不可撤销。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ref.read(rehabArchiveDetailProvider(widget.archiveId).notifier).deletePlan(planId);
    }
  }

  void _showPlanEditDialog(BuildContext context, RehabTeachingPlan plan) {
    final TextEditingController hearCtrl = TextEditingController(text: plan.hearingGoal);
    final TextEditingController speechCtrl = TextEditingController(text: plan.speechGoal);
    final TextEditingController langCtrl = TextEditingController(text: plan.languageGoal);
    final TextEditingController cognCtrl = TextEditingController(text: plan.cognitionGoal);
    final TextEditingController commCtrl = TextEditingController(text: plan.communicationGoal);
    final TextEditingController familyCtrl = TextEditingController(text: plan.familyGuidance);
    final TextEditingController otherCtrl = TextEditingController(text: plan.otherGoal);
    DateTime? start = plan.planPeriodStart;
    DateTime? end = plan.planPeriodEnd;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setDlg) => AlertDialog(
          title: const Text('教学计划详情'),
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                _planDateRow('开始日期', start, (v) => setDlg(() => start = v)),
                const SizedBox(height: 8),
                _planDateRow('结束日期', end, (v) => setDlg(() => end = v)),
                const SizedBox(height: 12),
                _planField('听能目标', hearCtrl),
                _planField('言语目标', speechCtrl),
                _planField('语言目标', langCtrl),
                _planField('认知目标', cognCtrl),
                _planField('沟通目标', commCtrl),
                _planField('家庭指导', familyCtrl),
                _planField('其他目标', otherCtrl),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            FilledButton.tonal(
              onPressed: () async {
                final updated = plan.copyWith(
                  planPeriodStart: start,
                  planPeriodEnd: end,
                  hearingGoal: hearCtrl.text.trim(),
                  speechGoal: speechCtrl.text.trim(),
                  languageGoal: langCtrl.text.trim(),
                  cognitionGoal: cognCtrl.text.trim(),
                  communicationGoal: commCtrl.text.trim(),
                  familyGuidance: familyCtrl.text.trim(),
                  otherGoal: otherCtrl.text.trim(),
                );
                if (mounted) {
                  await ref.read(rehabArchiveDetailProvider(widget.archiveId).notifier).updatePlan(updated);
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _planDateRow(String label, DateTime? value, ValueChanged<DateTime?> onChanged) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2040),
        );
        if (picked != null) onChanged(picked);
      },
      child: Row(children: [
        SizedBox(width: 72, child: Text(label, style: const TextStyle(fontSize: 14, color: Colors.black54))),
        Expanded(child: Text(
          value == null ? '请选择' : DateFormat('yyyy-MM-dd').format(value),
          style: TextStyle(fontSize: 14, color: value == null ? Colors.black38 : Colors.black87))),
        const Icon(Icons.calendar_today, size: 18, color: Colors.black38),
      ]),
    );
  }

  Widget _planField(String label, TextEditingController ctrl) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(
      controller: ctrl,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
      minLines: 2,
      maxLines: 4,
      style: const TextStyle(fontSize: 14),
    ),
  );
}

// ════════════════════════════════════════════════════════════════
//  手写照片 Tab（保持不变）
// ════════════════════════════════════════════════════════════════

class _PhotoTab extends ConsumerStatefulWidget {
  const _PhotoTab({required this.archiveId});
  final String archiveId;
  @override
  ConsumerState<_PhotoTab> createState() => _PhotoTabState();
}

class _PhotoTabState extends ConsumerState<_PhotoTab> {
  final ImagePicker _picker = ImagePicker();
  List<RehabPhoto> _photos = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadPhotos();
  }

  Future<void> _loadPhotos() async {
    try {
      final repo = ref.read(rehabRepositoryProvider);
      _photos = await repo.listPhotos(widget.archiveId);
      if (mounted) setState(() {});
    } catch (_) { /* 静默失败，显示空列表 */ }
  }

  Future<void> _pickImage(ImageSource source) async {
    final XFile? file = await _picker.pickImage(source: source, maxWidth: 2048, maxHeight: 2048);
    if (file == null) return;
    setState(() => _loading = true);
    try {
      final bytes = await file.readAsBytes();
      final dataUrl = 'data:${file.mimeType};base64,${base64Encode(bytes)}';
      await ref.read(rehabArchiveDetailProvider(widget.archiveId).notifier).uploadPhoto(
        archiveId: widget.archiveId,
        filePath: dataUrl,
        mimeType: file.mimeType ?? 'image/jpeg',
        fileSize: bytes.length,
        remark: '手写照片',
      );
      await _loadPhotos();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('上传失败，请重试'), backgroundColor: Colors.red));
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return Column(children: [
      Expanded(child: _photos.isEmpty
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.photo_library_outlined, size: 48, color: Colors.black26),
              const SizedBox(height: 12),
              const Text('暂无手写照片', style: TextStyle(color: Colors.black45, fontSize: 14)),
              const SizedBox(height: 4),
              const Text('可上传儿童手写作业、绘画作品等', style: TextStyle(color: Colors.black38, fontSize: 12)),
            ]))
          : GridView.builder(padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 0.75,
              ),
              itemCount: _photos.length,
              itemBuilder: (c, i) => Card(
                clipBehavior: Clip.antiAlias,
                child: Stack(fit: StackFit.expand, children: [
                  // 尝试显示图片（filePath 可能是 base64 dataURL 或远程 URL）
                  if (_photos[i].filePath.startsWith('data:'))
                    Image.memory(base64Decode(_photos[i].filePath.split(',').last), fit: BoxFit.cover)
                  else
                    Image.network(_photos[i].filePath, fit: BoxFit.cover,
                      errorBuilder: (_,__,___) => const Center(child: Icon(Icons.broken_image, color: Colors.black26))),
                  Positioned(bottom: 0, left: 0, right: 0,
                    child: Container(decoration: BoxDecoration(
                        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.6)])),
                      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        child: Text(_photos[i].remark ?? '${_photos[i].uploadTime != null ? DateFormat('MM-dd').format(_photos[i].uploadTime!) : ""}',
                            style: const TextStyle(color: Colors.white, fontSize: 10))))),
                ]),
              ),
            )),
      SafeArea(child: Padding(padding: const EdgeInsets.all(12),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          FilledButton.tonal(onPressed: () => _pickImage(ImageSource.camera),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.camera_alt, size: 18), const SizedBox(width: 4), const Text('拍照'),
            ])),
          FilledButton.tonal(onPressed: () => _pickImage(ImageSource.gallery),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.photo_library, size: 18), const SizedBox(width: 4), const Text('相册'),
            ])),
        ]))),
    ]);
  }
}

// ════════════════════════════════════════════════════════════════
//  概览 Tab（保持不变）
// ════════════════════════════════════════════════════════════════

class _OverviewTab extends ConsumerStatefulWidget {
  const _OverviewTab({required this.archiveId});
  final String archiveId;
  @override
  ConsumerState<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends ConsumerState<_OverviewTab> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(rehabArchiveDetailProvider(widget.archiveId));
    final detail = state.detail;
    if (detail == null) return const Center(child: Text('加载中…'));
    final archive = detail.archive;
    final fe = detail.firstEval;
    final contEvals = detail.contEvals;
    final plans = detail.plans;
    final tasks = detail.tasks;

    return ListView(padding: const EdgeInsets.all(16), children: [
      // ── 儿童基本信息卡 ──
      _infoCard('儿童信息', Icons.child_care, [
        _infoRow('姓名', archive.childName),
        _infoRow('档案编号', archive.archiveNo.isEmpty ? '—' : archive.archiveNo),
        if (fe != null) ...[
          _infoRow('性别', fe.gender.isEmpty ? '—' : fe.gender),
          _infoRow('出生日期', fe.birthDate == null ? '—' : DateFormat('yyyy-MM-dd').format(fe.birthDate!)),
          _infoRow('民族', fe.ethnicity.isEmpty ? '—' : fe.ethnicity),
          _infoRow('入园日期', fe.enrollmentDate == null ? '—' : DateFormat('yyyy-MM-dd').format(fe.enrollmentDate!)),
          _infoRow('班级', fe.className.isEmpty ? '—' : fe.className),
        ],
        _infoRow('校区', archive.campusName.isEmpty ? '—' : archive.campusName),
        _infoRow('状态', archive.status.label),
      ]),

      // ── 首次评估摘要 ──
      if (fe != null) _infoCard('首次评估', Icons.assignment,
        [_infoRow('评估日期', fe.evalDate == null ? '未评估' : DateFormat('yyyy-MM-dd').format(fe.evalDate!)),
         _infoRow('评估者', fe.evaluatorName.isEmpty ? '—' : fe.evaluatorName),
         _infoRow('诊断确认日期', fe.diagnosisConfirmDate == null ? '—' : DateFormat('yyyy-MM-dd').format(fe.diagnosisConfirmDate!)),
         _infoRow('左耳 dB', fe.leftEarDb.isEmpty ? '—' : fe.leftEarDb),
         _infoRow('右耳 dB', fe.rightEarDb.isEmpty ? '—' : fe.rightEarDb),
         _infoRow('左补偿方式', fe.leftCompensationType.isEmpty ? '—' : fe.leftCompensationType),
         _infoRow('右补偿方式', fe.rightCompensationType.isEmpty ? '—' : fe.rightCompensationType),
         if (fe.briefDesc.isNotEmpty) ...[
           const SizedBox(height: 4),
           Text('综合建议: ${fe.briefDesc}', style: const TextStyle(fontSize: 13, color: Colors.black54)),
         ],
        ], actionLabel: '编辑', action: () => context.push('/rehab/${widget.archiveId}/first-eval-edit')),

      // ── 持续评估进度 ──
      _infoCard('持续评估进度', Icons.timeline,
        contEvals.isEmpty
          ? [const Padding(padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('暂无持续评估记录', style: TextStyle(color: Colors.black45, fontSize: 13)))]
          : contEvals.map((c) => ListTile(
              dense: true, contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(radius: 14,
                backgroundColor: c.status == ContEvalStatus.done ? Colors.green.shade100
                  : c.status == ContEvalStatus.overdue ? Colors.red.shade100 : Colors.orange.shade100,
                child: Text('${c.evalSeq ?? (contEvals.indexOf(c) + 1)}',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                      color: c.status == ContEvalStatus.done ? Colors.green.shade800
                        : c.status == ContEvalStatus.overdue ? Colors.red.shade800 : Colors.orange.shade800))),
              title: Text(c.evalDate == null ? '未填写' : DateFormat('yyyy-MM-dd').format(c.evalDate!),
                  style: const TextStyle(fontSize: 13)),
              subtitle: Text(c.status.label, style: TextStyle(fontSize: 11, color: Colors.black54)),
              trailing: c.status == ContEvalStatus.done ? const Icon(Icons.check_circle, color: Colors.green, size: 18)
                : c.status == ContEvalStatus.overdue ? const Icon(Icons.warning, color: Colors.red, size: 18)
                : const Icon(Icons.pending, color: Colors.orange, size: 18),
            )).toList(),
        actionLabel: contEvals.isEmpty ? '开始评估' : '新建',
        action: () => context.push('/rehab/${widget.archiveId}/cont-eval-edit')),

      // ── 教学计划 ──
      _infoCard('教学计划', Icons.school,
        plans.isEmpty
          ? [const Padding(padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('暂无教学计划', style: TextStyle(color: Colors.black45, fontSize: 13)))]
          : plans.map((p) => ListTile(
              dense: true, contentPadding: EdgeInsets.zero,
              title: Text(p.planPeriodStart == null ? '计划'
                  : '${DateFormat('yyyy-MM-dd').format(p.planPeriodStart!)} ~ ${p.planPeriodEnd == null ? "" : DateFormat("yyyy-MM-dd").format(p.planPeriodEnd!)}',
                  style: const TextStyle(fontSize: 13)),
              subtitle: Text(p.aiGenerated ? 'AI 补全' : '手动创建', style: const TextStyle(fontSize: 11, color: Colors.black54)),
              trailing: p.aiGenerated ? const Icon(Icons.auto_awesome, size: 16, color: Colors.purple) : null,
            )).toList(),
        // 跳转到教学计划独立页（PlanSectionScreen），完整查看各领域目标。
        actionLabel: '查看计划',
        action: () => context.push('/rehab/${widget.archiveId}/plan')),

      // ── 任务提醒 ──
      if (tasks.isNotEmpty) ...[
        const SizedBox(height: 8),
        Text('待办任务', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15,
            color: Theme.of(context).colorScheme.primary)),
        const SizedBox(height: 6),
        ...tasks.map((t) => Card(
          margin: const EdgeInsets.only(bottom: 6),
          child: ListTile(
            dense: true,
            leading: Icon(t.reminderType == 'TEACHING_PLAN' ? Icons.school : Icons.assignment,
                color: t.completed ? Colors.grey : Theme.of(context).colorScheme.primary),
            title: Text(t.title, style: TextStyle(
                fontSize: 13, decoration: t.completed ? TextDecoration.lineThrough : null)),
            subtitle: Text(DateFormat('yyyy-MM-dd').format(t.dueDate), style: const TextStyle(fontSize: 11)),
            trailing: t.completed
                ? const Icon(Icons.check_circle, color: Colors.green, size: 18)
                : FilledButton.tonal(
                    onPressed: () => _completeTask(t.id),
                    child: const Text('完成', style: TextStyle(fontSize: 11)),
                  ),
          ),
        )),
      ],

      const SizedBox(height: 40),
    ]);
  }

  Future<void> _completeTask(String taskId) async {
    await ref.read(rehabArchiveDetailProvider(widget.archiveId).notifier).completeTask(taskId);
  }

  /// 信息卡片。
  Widget _infoCard(String title, IconData icon, List<Widget> children,
      {String? actionLabel, VoidCallback? action}) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Row(children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 6),
          Text(title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14,
              color: Theme.of(context).colorScheme.primary)),
        ]),
        if (actionLabel != null && action != null)
          TextButton(onPressed: action, child: Text(actionLabel, style: const TextStyle(fontSize: 12))),
      ]),
      const SizedBox(height: 8),
      ...children,
    ])),
  );
}

// ════════════════════════════════════════════════════════════════
//  首次评估 — 独立编辑页面（全屏 Scaffold，禁止左右滑动切 tab）
// ════════════════════════════════════════════════════════════════

class FirstEvalEditScreen extends ConsumerStatefulWidget {
  const FirstEvalEditScreen({required this.archiveId, super.key});
  final String archiveId;
  @override
  ConsumerState<FirstEvalEditScreen> createState() => _FirstEvalEditScreenState();
}

class _FirstEvalEditScreenState extends ConsumerState<FirstEvalEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late RehabFirstEval _draft;
  late final PageController _pageController;

  /// Checkbox 选中状态：fieldKey → 已选选项集合。
  /// 修复原版 _cbRow onChanged 为空操作导致无法选中的 bug。
  final Map<String, Set<String>> _cbState = <String, Set<String>>{};

  static const List<String> _genders = ['男', '女'];
  static const List<String> _compTypes = ['助听器', '人工耳蜗', '无'];
  static const List<String> _stimStrategies = ['单侧', '双侧同步', '双侧顺次'];
  static const List<String> _commModes = ['口语', '手势', '手语', 'PECS', '混合'];
  // 注：家庭状况已改为 _familyStatusCb() 的 5 个 □（双亲/单亲/父/母/双亡），
  // 不再是下拉；老数据「单亲-父 / 单亲-母」由 _splitFamily 兼容。
  static const List<String> _inputLangTypes = ['手语', '口语-方言', '口语-普通话'];
  static const List<String> _awarenessLevels = ['高', '中', '低'];
  static const List<String> _coopLevels = ['好', '一般', '差'];
  static const List<String> _eduLevels = ['文盲', '小学', '初中', '高中/中专', '大专', '本科', '硕士及以上'];
  static const List<String> _familyLangEnvs = ['口语为主', '手语为主', '混合'];
  static const List<String> _caregivers = ['父亲', '母亲', '祖父母', '外祖父母', '其他'];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _loadDraft();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _loadDraft() {
    final s = ref.read(rehabArchiveDetailProvider(widget.archiveId));
    _draft = s.detail?.firstEval ?? RehabFirstEval(archiveId: widget.archiveId);
    _ensureDomainMaps();
    _initCbState();
  }

  /// 确保各领域 JSON Map 非 null，否则 checkbox 勾选无处可写、保存后丢失。
  void _ensureDomainMaps() {
    Map<String, dynamic> m(Map<String, dynamic>? x) => x ?? <String, dynamic>{};
    _draft = _draft.copyWith(
      domainHearingMgmt: m(_draft.domainHearingMgmt),
      domainHearingAbility: m(_draft.domainHearingAbility),
      domainLanguage: m(_draft.domainLanguage),
      domainSpeech: m(_draft.domainSpeech),
      domainCognition: m(_draft.domainCognition),
      domainCommunication: m(_draft.domainCommunication),
      behaviorNote: m(_draft.behaviorNote),
      selfCareNote: m(_draft.selfCareNote),
      parentTrainingNote: m(_draft.parentTrainingNote),
      comprehensiveAdvice: m(_draft.comprehensiveAdvice),
      familyData: m(_draft.familyData),
      aidedThresholds: m(_draft.aidedThresholds),
    );
  }

  /// 读取父亲/母亲字段（familyData[who][key]）。
  String _parent(String who, String key) => jsonStr(_draft.familyData, [who, key]);

  /// 写入父亲/母亲字段，确保嵌套 Map 存在后写回 draft。
  void _setParent(String who, String key, String v) {
    final fd = Map<String, dynamic>.from(_draft.familyData ?? {});
    final sub = Map<String, dynamic>.from((fd[who] as Map<String, dynamic>?) ?? {});
    sub[key] = v;
    fd[who] = sub;
    _draft = _draft.copyWith(familyData: fd);
  }

  /// 次级小标题（与只读展示风格一致）。
  Widget _sub(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 10, 0, 2),
        child: Text(t, style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
      );

  /// 从 draft 的各 domain map 初始化 checkbox 状态。
  void _initCbState() {
    _cbState.clear();
    void initFrom(Map<String, dynamic>? domain) {
      if (domain == null) return;
      for (final e in domain.entries) {
        if (e.value is List) {
          _cbState[e.key] = Set<String>.from(e.value as Iterable);
        }
      }
    }
    initFrom(_draft.domainHearingMgmt);
    initFrom(_draft.domainHearingAbility);
    initFrom(_draft.domainLanguage);
    initFrom(_draft.domainSpeech);
    initFrom(_draft.domainCognition);
    initFrom(_draft.domainCommunication);
    initFrom(_draft.behaviorNote);
    initFrom(_draft.selfCareNote);
    initFrom(_draft.parentTrainingNote);
    // 林氏六音的「察觉/辨识」已改为符号表格，存为 Map 而非 List，不走 checkbox 状态。
    _cbState.remove('lingDetect');
    _cbState.remove('lingIdentify');
  }

  // ── 表单组件（同 _FirstEvalTabState，但 checkbox 有真实状态）──

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
        child: Row(children: [
          Container(width: 4, height: 18,
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15,
              color: Theme.of(context).colorScheme.primary)),
        ]),
      );

  Widget _tf(String label, String initial, ValueChanged<String> onSaved,
      {int maxLines = 1, TextInputType? keyboardType}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: TextFormField(initialValue: initial, maxLines: maxLines, minLines: 1,
          keyboardType: keyboardType,
          decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(fontSize: 13),
            border: InputBorder.none,
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade300)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Theme.of(context).colorScheme.primary)),
            contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 0)),
          onSaved: (v) => onSaved(v ?? ''),
        ),
      );

  Widget _df(String label, DateTime? value, ValueChanged<DateTime?> onChanged) =>
      Padding(padding: const EdgeInsets.symmetric(vertical: 5),
        child: _DateField(label: label, value: value, onChanged: onChanged));

  Widget _dd(String label, String value, ValueChanged<String?> onChanged,
      List<String> options) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: DropdownButtonFormField<String>(
          value: options.contains(value) ? value : null,
          decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(fontSize: 13),
            border: InputBorder.none,
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade300)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Theme.of(context).colorScheme.primary)),
            contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 0)),
          items: options.map((o) => DropdownMenuItem<String>(value: o,
              child: Text(o, style: const TextStyle(fontSize: 14)))).toList(),
          onChanged: onChanged,
        ),
      );

  /// ✅ 修复后的 Checkbox 行：onChanged 真正切换状态。
  Widget _cbRow(String label, List<String> options, Map<String, dynamic>? domain,
      String fieldKey) {
    final selected = _cbState[fieldKey] ?? <String>{};
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 10, child: Text('●', style: TextStyle(fontSize: 13,
            color: Theme.of(context).colorScheme.primary))),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
        ...options.map((o) => Padding(padding: const EdgeInsets.only(right: 12),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(width: 18, height: 18,
              child: Checkbox(
                value: selected.contains(o),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onChanged: (checked) {
                  setState(() {
                    final set = _cbState.putIfAbsent(fieldKey, () => <String>{});
                    if (checked == true) { set.add(o); } else { set.remove(o); }
                    // 关键：立即写回所属域 Map。否则保存时 _syncCbStateToDraft
                    // 的 containsKey 判断会把新勾选的项全部丢弃。
                    if (domain != null) domain[fieldKey] = set.toList();
                  });
                },
              ),
            ),
            Text(o, style: const TextStyle(fontSize: 13)),
          ]))),
        ]),
      );
    }

  /// 家庭状况：5 个 □ 可多选，多选以顿号连接存进 `family_status`。
  ///
  /// 老数据（'双亲' / '单亲-父' 等）依然能正确回显：下方 `_splitFamily` 会
  /// 把 '单亲-父' 归一成 {'单亲','父'}。
  Widget _familyStatusCb() {
    const List<String> opts = <String>['双亲', '单亲', '父', '母', '双亡'];
    final Set<String> cur = _splitFamily(_draft.familyStatus);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('家庭状况', style: TextStyle(fontSize: 13, color: Colors.black54)),
        const SizedBox(height: 2),
        Wrap(spacing: 12, children: opts.map((o) {
          final bool on = cur.contains(o);
          return Row(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(width: 18, height: 18,
              child: Checkbox(
                value: on,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onChanged: (c) {
                  final Set<String> s = _splitFamily(_draft.familyStatus);
                  if (c == true) {
                    s.add(o);
                  } else {
                    s.remove(o);
                  }
                  setState(() => _draft = _draft.copyWith(familyStatus: s.join('、')));
                },
              )),
            Text(o, style: const TextStyle(fontSize: 13)),
          ]);
        }).toList()),
      ]),
    );
  }

  /// 把 family_status 拆成选项集合，兼容老的「单亲-父 / 单亲-母」写法。
  static Set<String> _splitFamily(String v) {
    final Set<String> out = <String>{};
    for (final String part in v.split(RegExp(r'[、,，]'))) {
      final String p = part.trim();
      if (p.isEmpty) continue;
      if (p == '单亲-父') {
        out..add('单亲')..add('父');
      } else if (p == '单亲-母') {
        out..add('单亲')..add('母');
      } else {
        out.add(p);
      }
    }
    return out;
  }

  /// 认知能力填空：写入 `domainCognition[key]`。
  ///
  /// key 用的是中文（'分类'/'配对'/…），与只读页 `_roPart2` 里
  /// `_q(cg, f, f.toLowerCase())` 的读法保持一致——中文 toLowerCase 就是原串。
  Widget _cog(String label, String key) => _tf(
        label,
        (_draft.domainCognition?[key] ?? '').toString(),
        (v) => _draft = _draft.copyWith(
            domainCognition: <String, dynamic>{...?_draft.domainCognition, key: v}),
      );

  /// 自理能力一项：纸表是「口尚未出现 / 口出现」二选一。
  ///
  /// 数据契约沿用只读页 `_selfCare` 的读法：写 `selfCareNote` 的
  /// `{key}_notYet` / `{key}_appeared`（**非空即视为选中**），互斥。
  Widget _sc(String label, String key) {
    final Map<String, dynamic> m = _draft.selfCareNote ?? <String, dynamic>{};
    final bool notYet = (m['${key}_notYet'] ?? '').toString().isNotEmpty;
    final bool appeared = (m['${key}_appeared'] ?? '').toString().isNotEmpty;

    void pick(String which, bool on) {
      final Map<String, dynamic> nm = <String, dynamic>{...m};
      nm.remove('${key}_notYet');
      nm.remove('${key}_appeared');
      if (on) nm['${key}_$which'] = '1';
      setState(() => _draft = _draft.copyWith(selfCareNote: nm));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
        for (final e in const [['尚未出现', 'notYet'], ['出现', 'appeared']])
          Row(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(width: 18, height: 18,
              child: Checkbox(
                value: e[1] == 'notYet' ? notYet : appeared,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onChanged: (c) => pick(e[1], c == true),
              )),
            Text(e[0], style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 6),
          ]),
      ]),
    );
  }

  Widget _aidedThresholdGrid() {
    const freqs = ['250Hz', '500Hz', '1kHz', '2kHz', '3kHz', '4kHz'];
    final at = _draft.aidedThresholds ?? <String, dynamic>{};
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('助听听阈', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      const SizedBox(height: 6),
      Row(children: [
        const SizedBox(width: 50, child: Text('')),
        ...freqs.map((f) => Expanded(child: Center(child: Text(f, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600))))),
      ]),
      Row(children: [
        const SizedBox(width: 50, child: Text('左耳 dB(HL)', style: const TextStyle(fontSize: 12))),
        ...freqs.map((f) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 2),
          child: TextFormField(initialValue: jsonStr(at, ['left', f]),
            textAlign: TextAlign.center, keyboardType: TextInputType.number,
            decoration: const InputDecoration(border: UnderlineInputBorder(), contentPadding: EdgeInsets.symmetric(vertical: 8)),
            onSaved: (v) { /* handled in save */ }),
        ))),
      ]),
      Row(children: [
        const SizedBox(width: 50, child: Text('右耳 dB(HL)', style: const TextStyle(fontSize: 12))),
        ...freqs.map((f) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 2),
          child: TextFormField(initialValue: jsonStr(at, ['right', f]),
            textAlign: TextAlign.center, keyboardType: TextInputType.number,
            decoration: const InputDecoration(border: UnderlineInputBorder(), contentPadding: EdgeInsets.symmetric(vertical: 8)),
            onSaved: (v) { /* handled in save */ }),
        ))),
      ]),
    ]);
  }

  Widget _lingTable(BuildContext context) {
    const sounds = ['a', 'i', 'u', 'sh', 's', 'm'];
    Map<String, dynamic> lingMap(String key) =>
        Map<String, dynamic>.from((_draft.domainHearingMgmt![key] as Map?) ?? {});
    int? currentSym(String key, String sound) =>
        HearingSymbol.indexFromValue(lingMap(key)[sound]);
    Widget header(String t) => Expanded(
          child: Center(child: Text(t, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
        );
    Widget cell(String sound, String key) {
      final val = currentSym(key, sound);
      return Expanded(
        child: GestureDetector(
          onTap: () => _pickLingSymbol(sound, key),
          child: Container(
            height: 40,
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300, width: .5),
              borderRadius: BorderRadius.circular(4),
            ),
            child: val == null
                ? const Center(child: Text('—', style: TextStyle(color: Colors.grey)))
                : Center(child: Image.asset(HearingSymbol.assets[val - 1], height: 30)),
          ),
        ),
      );
    }
    return Column(children: [
      Row(children: [
        const SizedBox(width: 36, child: Center(child: Text('六音', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)))),
        header('察觉'), header('辨识'),
      ]),
      for (final s in sounds)
        Row(children: [
          SizedBox(width: 36, child: Center(child: Text(s, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)))),
          cell(s, 'lingDetect'), cell(s, 'lingIdentify'),
        ]),
    ]);
  }

  /// 底部弹窗：为某个六音的「察觉/辨识」选择一种符号（再次点击已选符号即清除）。
  void _pickLingSymbol(String sound, String key) {
    final cur = HearingSymbol.indexFromValue(
        (_draft.domainHearingMgmt![key] as Map?)?.containsKey(sound) == true
            ? (_draft.domainHearingMgmt![key] as Map)[sound]
            : null);
    showModalBottomSheet(
      context: context,
      builder: (bctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('六音「$sound」— ${key == 'lingDetect' ? '察觉' : '辨识'}',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            const SizedBox(height: 14),
            Row(children: [
              for (int i = 1; i <= 4; i++)
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        final map = Map<String, dynamic>.from(
                            (_draft.domainHearingMgmt![key] as Map?) ?? {});
                        if (cur == i) {
                          map.remove(sound);
                        } else {
                          map[sound] = i;
                        }
                        _draft.domainHearingMgmt![key] = map;
                      });
                      Navigator.pop(bctx);
                    },
                    child: Container(
                      margin: const EdgeInsets.all(4),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: cur == i ? Theme.of(context).colorScheme.primary : Colors.grey.shade300,
                          width: cur == i ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Column(children: [
                        Image.asset(HearingSymbol.assets[i - 1], height: 36),
                        const SizedBox(height: 4),
                        Text(HearingSymbol.labels[i - 1], style: const TextStyle(fontSize: 12)),
                      ]),
                    ),
                  ),
                ),
            ]),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                setState(() {
                  final map = Map<String, dynamic>.from(
                      (_draft.domainHearingMgmt![key] as Map?) ?? {});
                  map.remove(sound);
                  _draft.domainHearingMgmt![key] = map;
                });
                Navigator.pop(bctx);
              },
              child: const Text('清除'),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _partNav({int? prevPage, int? nextPage, String? nextLabel}) => Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8)),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          if (prevPage != null)
            TextButton.icon(onPressed: () => _pageController.animateToPage(prevPage,
                duration: const Duration(milliseconds: 300), curve: Curves.easeInOut),
              icon: const Icon(Icons.arrow_back, size: 16), label: const Text('上一部分'))
          else const SizedBox(width: 80),
          if (nextPage != null)
            FilledButton.tonal(onPressed: () => _pageController.animateToPage(nextPage,
                duration: const Duration(milliseconds: 300), curve: Curves.easeInOut),
              child: Text(nextLabel ?? '下一部分 →'))
          else const SizedBox(width: 80),
        ]),
      );

  // ── 将 _cbState 回写到 draft 的 domain map（保存前调用）──
  void _syncCbStateToDraft() {
    void syncTo(Map<String, dynamic>? domain) {
      if (domain == null) return;
      for (final e in _cbState.entries) {
        if (domain.containsKey(e.key)) {
          domain[e.key] = e.value.toList();
        }
      }
    }
    syncTo(_draft.domainHearingMgmt);
    syncTo(_draft.domainHearingAbility);
    syncTo(_draft.domainLanguage);
    syncTo(_draft.domainSpeech);
    syncTo(_draft.domainCognition);
    syncTo(_draft.domainCommunication);
    syncTo(_draft.behaviorNote);
    syncTo(_draft.selfCareNote);
    syncTo(_draft.parentTrainingNote);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('编辑首次评估'), leading: IconButton(
        icon: const Icon(Icons.arrow_back), onPressed: () => context.pop(),
      )),
      body: Form(key: _formKey, child: Column(children: [
        Expanded(child: PageView(controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildPart1Basic(),
            _buildPart2Eval(),
            _buildPart3Advice(),
          ])),
        SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: FilledButton.icon(onPressed: _save,
            icon: const Icon(Icons.save, size: 18), label: const Text('保存首次评估')),
        )),
      ])),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    _syncCbStateToDraft();
    final bool ok = await ref
        .read(rehabArchiveDetailProvider(widget.archiveId).notifier)
        .submitFirstEval(_draft);
    if (!mounted) return;
    // 修复前：失败也 pop，用户以为已保存。
    if (ok) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('首次评估已保存')));
      context.pop();
    } else {
      final err = ref.read(rehabArchiveDetailProvider(widget.archiveId)).error;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err ?? '保存失败，请重试'), backgroundColor: Colors.red));
    }
  }

  // ═══ Part 1 — 基本资料 ═══
  Widget _buildPart1Basic() => ListView(padding: const EdgeInsets.all(16), children: [
    _partNav(nextPage: 1, nextLabel: '下一部分：评估内容 →'),
    _sectionTitle('一、基本情况'),
    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(flex: 2, child: _tf('姓名', _draft.name, (v) => _draft = _draft.copyWith(name: v))),
      Expanded(flex: 1, child: _dd('性别', _draft.gender, (v) => _draft = _draft.copyWith(gender: v ?? ''), _genders)),
      Expanded(flex: 2, child: _df('出生年月', _draft.birthDate, (v) => _draft = _draft.copyWith(birthDate: v))),
    ]),
    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: _tf('民族', _draft.ethnicity, (v) => _draft = _draft.copyWith(ethnicity: v))),
      Expanded(child: _tf('户口所在地', _draft.hukouLocation, (v) => _draft = _draft.copyWith(hukouLocation: v))),
      Expanded(child: _tf('身份证号', _draft.idNumber, (v) => _draft = _draft.copyWith(idNumber: v))),
    ]),
    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: _df('入园时间', _draft.enrollmentDate, (v) => _draft = _draft.copyWith(enrollmentDate: v))),
      Expanded(child: _tf('班级', _draft.className, (v) => _draft = _draft.copyWith(className: v))),
    ]),
    _sectionTitle('二、听力状况'),
    _df('听障确诊时间', _draft.diagnosisConfirmDate, (v) => _draft = _draft.copyWith(diagnosisConfirmDate: v)),
    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: _tf('左耳 dB(HL)', _draft.leftEarDb, (v) => _draft = _draft.copyWith(leftEarDb: v))),
      Expanded(child: _tf('右耳 dB(HL)', _draft.rightEarDb, (v) => _draft = _draft.copyWith(rightEarDb: v))),
    ]),
    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(flex: 1, child: _dd('左耳方式', _draft.leftCompensationType,
          (v) => _draft = _draft.copyWith(leftCompensationType: v ?? ''), _compTypes)),
      Expanded(flex: 2, child: _tf('左耳型号', _draft.leftDeviceModel, (v) => _draft = _draft.copyWith(leftDeviceModel: v))),
    ]),
    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(flex: 1, child: _dd('右耳方式', _draft.rightCompensationType,
          (v) => _draft = _draft.copyWith(rightCompensationType: v ?? ''), _compTypes)),
      Expanded(flex: 2, child: _tf('右耳型号', _draft.rightDeviceModel, (v) => _draft = _draft.copyWith(rightDeviceModel: v))),
    ]),
    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: _df('左耳验配日期', _draft.leftFittingDate, (v) => _draft = _draft.copyWith(leftFittingDate: v))),
      Expanded(child: _df('右耳验配日期', _draft.rightFittingDate, (v) => _draft = _draft.copyWith(rightFittingDate: v))),
    ]),
    _aidedThresholdGrid(),
    _dd('听觉刺激策略', _draft.hearingStimStrategy, (v) => _draft = _draft.copyWith(hearingStimStrategy: v ?? ''), _stimStrategies),
    _sectionTitle('三、家庭情况'),
    _sub('父亲'),
    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: _tf('姓名', _parent('father', 'name'), (v) => _setParent('father', 'name', v))),
      Expanded(child: _tf('年龄', _parent('father', 'age'), (v) => _setParent('father', 'age', v))),
    ]),
    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: _tf('民族', _parent('father', 'ethnicity'), (v) => _setParent('father', 'ethnicity', v))),
      Expanded(child: _dd('文化程度', _parent('father', 'education'), (v) => _setParent('father', 'education', v ?? ''), _eduLevels)),
    ]),
    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: _tf('职业', _parent('father', 'occupation'), (v) => _setParent('father', 'occupation', v))),
      Expanded(child: _tf('联系方式', _parent('father', 'contact'), (v) => _setParent('father', 'contact', v))),
    ]),
    _sub('母亲'),
    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: _tf('姓名', _parent('mother', 'name'), (v) => _setParent('mother', 'name', v))),
      Expanded(child: _tf('年龄', _parent('mother', 'age'), (v) => _setParent('mother', 'age', v))),
    ]),
    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: _tf('民族', _parent('mother', 'ethnicity'), (v) => _setParent('mother', 'ethnicity', v))),
      Expanded(child: _dd('文化程度', _parent('mother', 'education'), (v) => _setParent('mother', 'education', v ?? ''), _eduLevels)),
    ]),
    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: _tf('职业', _parent('mother', 'occupation'), (v) => _setParent('mother', 'occupation', v))),
      Expanded(child: _tf('联系方式', _parent('mother', 'contact'), (v) => _setParent('mother', 'contact', v))),
    ]),
    _sub('家庭情况'),
    // 纸表 1.1.1 上「家庭状况」是 5 个 □（可多选，如「单亲 + 父」＝单亲随父），
    // 不是下拉单选。仍存 family_status 一列，多选以顿号连接。
    _familyStatusCb(),
    _dd('主要输入语言类型', _draft.familyInputLangType, (v) => _draft = _draft.copyWith(familyInputLangType: v ?? ''), _inputLangTypes),
    _dd('家庭语言环境', _draft.familyLangEnv, (v) => _draft = _draft.copyWith(familyLangEnv: v ?? ''), _familyLangEnvs),
    _dd('主要照顾者', _draft.caregiver, (v) => _draft = _draft.copyWith(caregiver: v ?? ''), _caregivers),
    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: _tf('照顾者与儿童关系', _draft.caregiverRelation, (v) => _draft = _draft.copyWith(caregiverRelation: v))),
      Expanded(child: _tf('照顾者联系方式', _draft.caregiverContact, (v) => _draft = _draft.copyWith(caregiverContact: v))),
    ]),
    _tf('现居住地址', _draft.homeAddress, (v) => _draft = _draft.copyWith(homeAddress: v), maxLines: 2),
    _sub('家长意识与配合'),
    _dd('康复意识', _draft.familyAwareness, (v) => _draft = _draft.copyWith(familyAwareness: v ?? ''), _awarenessLevels),
    _dd('配合程度', _draft.familyCooperation, (v) => _draft = _draft.copyWith(familyCooperation: v ?? ''), _coopLevels),
    // comprehensiveAdvice 是 JSON Map；此处编辑其 briefDesc 分量
    _tf('综合建议', _draft.briefDesc, (v) => _draft = _draft.copyWith(
          comprehensiveAdvice: {...?_draft.comprehensiveAdvice, 'briefDesc': v}), maxLines: 3),
    _tf('评估者姓名', _draft.evaluatorName, (v) => _draft = _draft.copyWith(evaluatorName: v)),
    _df('评估日期', _draft.evalDate, (v) => _draft = _draft.copyWith(evalDate: v)),
  ]);

  // ═══ Part 2 — 评估内容（从原 _FirstEvalTabState 复制，checkbox 用修复版）═══
  Widget _buildPart2Eval() => ListView(padding: const EdgeInsets.all(16), children: [
    _partNav(prevPage: 0, nextPage: 2, nextLabel: '下一部分：综合建议 →'),
    _sectionTitle('听能管理'),
    _cbRow('确定家长了解保养及检查助听设备程序', ['是', '否'], _draft.domainHearingMgmt, 'deviceCareProgram'),
    _cbRow('除睡觉及洗澡、游泳外是否都给儿童配戴助听设备', ['是', '否'], _draft.domainHearingMgmt, 'alwaysWear'),
    _cbRow('家中听觉环境', ['安静', '有噪音'], _draft.domainHearingMgmt, 'homeEnv'),
    _cbRow('幼儿的听觉习惯', ['完全聆听', '依赖视觉', '两者都有'], _draft.domainHearingMgmt, 'hearingHabit'),
    const Text('已有助听设备保养工具', style: TextStyle(fontSize: 13, color: Colors.black54)),
    const SizedBox(height: 12),
    const Text('配戴助听设备后幼儿对声音的反应有何改变？', style: TextStyle(fontSize: 13)),
    _sectionTitle('听觉能力'),
    const Text('环境声音反应', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
    _cbRow('幼儿对环境声音的反应', ['无反应', '察觉', '辨识'], _draft.domainHearingMgmt, 'envReaction'),
    _cbRow('幼儿对语音的反应', ['无反应', '察觉', '辨识'], _draft.domainHearingMgmt, 'voiceReaction'),
    _cbRow('幼儿对名字、家人称谓的反应', ['无反应', '察觉', '辨识'], _draft.domainHearingMgmt, 'nameReaction'),
    _cbRow('幼儿对林氏(Ling\'s)六音的反应', ['无反应', '察觉', '辨识'], _draft.domainHearingMgmt, 'lingReaction'),
    const Text('林氏(Ling\'s)六音反应（点击单元格选择符号）', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
    _lingTable(context),
    _sectionTitle('语言能力'),
    const Text('沟通模式', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
    _cbRow('沟通模式', ['非口语', '口语'], _draft.domainLanguage, 'commMode'),
    _dd('主要沟通模式', _draft.commMode, (v) => _draft = _draft.copyWith(commMode: v ?? ''), _commModes),
    const Text('理解性语言程度', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
    _cbRow('理解能力', ['无', '初级词汇', '中级词汇', '高级词汇'], _draft.domainLanguage, 'understandingLevel'),
    const Text('表达性语言程度', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
    _cbRow('无', ['无'], _draft.domainLanguage, 'expressingNone'),
    _cbRow('模仿复述', ['有'], _draft.domainLanguage, 'expressingImitate'),
    _cbRow('主动表达', ['有'], _draft.domainLanguage, 'expressingActive'),
    // 纸表 1.1.1 上这 7 行各自只有一个「□」，勾中即表示「处于该阶段」，
    // 所以每项只给一个选项「有」；此前传的是空数组，界面连框都不渲染，
    // 老师根本无从勾选 → domain_language 里永远没有这几个 key。
    const Text('表达性语言发展阶段', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
    _cbRow('咿呀期（简单发音阶段）', ['有'], _draft.domainLanguage, 'stageBabbling'),
    _cbRow('儿语期（连续音节阶段）', ['有'], _draft.domainLanguage, 'stageCooing'),
    _cbRow('模仿期（学话萌芽阶段）', ['有'], _draft.domainLanguage, 'stageImitate'),
    _cbRow('单字期（单词句阶段）', ['有'], _draft.domainLanguage, 'stageWord'),
    _cbRow('胡语期（乱语阶段）', ['有'], _draft.domainLanguage, 'stageJargon'),
    _cbRow('简单语词、电报期（双词句阶段）', ['有'], _draft.domainLanguage, 'stageTelegraphic'),
    _cbRow('片语、句子和段落（完整句阶段）', ['有'], _draft.domainLanguage, 'stageComplete'),
    const Text('问句能力', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
    _cbRow('问句理解', ['不能理解', '理解，会回答'], _draft.domainLanguage, 'questionUnderstand'),
    _cbRow('问句表达', ['会表达问句'], _draft.domainLanguage, 'questionExpress'),
    _sectionTitle('言语能力'),
    const Text('发声能力', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
    _cbRow('能否发出声音', ['有', '无'], _draft.domainSpeech, 'canVoice'),
    _cbRow('超音段', ['音长短', '音高低', '音大小', '四声'], _draft.domainSpeech, 'supraSegmental'),
    // 纸表 1.1.1 第 2 页言语能力下是「模仿发音：口不会 / 口会（说明____）」，
    // 没有「构音清晰度」这一栏（详细评估在持续评估里）。两处都保留：
    // 模仿发音会被导出，清晰度说明只作 App 内部备注、不进 PDF。
    _cbRow('模仿发音', ['不会', '会'], _draft.domainSpeech, 'imitationFlag'),
    _tf('模仿发音说明', (_draft.domainSpeech?['imitationNote'] ?? '').toString(),
        (v) => _draft = _draft.copyWith(
            domainSpeech: <String, dynamic>{...?_draft.domainSpeech, 'imitationNote': v}),
        maxLines: 2),
    const Text('构音清晰度（纸表无此栏，仅内部备注，不导出）',
        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
    _tf('清晰度说明', (_draft.domainSpeech?['clarityNote'] ?? '').toString(),
        (v) => _draft = _draft.copyWith(
            domainSpeech: <String, dynamic>{...?_draft.domainSpeech, 'clarityNote': v}),
        maxLines: 2),
    // ── 认知能力：纸表第 3 页是「标签：____」的填空，不是打勾 ──
    _sectionTitle('认知能力'),
    _cog('分类', '分类'),
    _cog('配对', '配对'),
    _cog('颜色', '颜色'),
    _cog('形状', '形状'),
    _cog('质感', '质感'),
    _cog('数学概念', '数学概念'),
    _cog('排序', '排序'),
    _cog('其他思维能力', 'otherThinking'),
    _cog('格雷费斯发育商', 'griffiths'),
    _cog('希-内智商/学习能力商', 'binet'),
    _sectionTitle('沟通能力'),
    _cbRow('表达需求的方式', ['口语', '肢体', '其他__________'], _draft.domainCommunication, 'expressMode'),
    _cbRow('等待能力、轮替', ['可以', '不可以', '偶尔发生'], _draft.domainCommunication, 'turnTaking'),
    _cbRow('眼神交流', ['无', '有__________'], _draft.domainCommunication, 'eyeContact'),
    _cbRow('主动提问', ['无', '有__________'], _draft.domainCommunication, 'activeQuestion'),
    _cbRow('主动互动', ['无', '有__________'], _draft.domainCommunication, 'activeInteraction'),
    _cbRow('维持话题', ['无', '有__________'], _draft.domainCommunication, 'maintainTopic'),
    _cbRow('开启话题', ['无', '有__________'], _draft.domainCommunication, 'openTopic'),
    _sectionTitle('行为表现'),
    _cbRow('好奇心', ['主动', '被动'], _draft.behaviorNote, 'curiosity'),
    _cbRow('稳定性', ['稳定', '不稳定'], _draft.behaviorNote, 'stability'),
    _cbRow('行为问题', ['无', '有'], _draft.behaviorNote, 'problemFlag'),
    _tf('行为问题说明', (_draft.behaviorNote?['problemNote'] ?? '').toString(),
        (v) => _draft = _draft.copyWith(
            behaviorNote: <String, dynamic>{...?_draft.behaviorNote, 'problemNote': v}),
        maxLines: 2),
    // ── 自理能力：纸表第 3 页每项「口尚未出现 / 口出现」二选一 ──
    _sectionTitle('自理能力'),
    const Text('入厕', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
    _sc('有大小便需求时，能自己入厕', 'toiletSelf'),
    _sc('在成人提醒下便后会用水冲洗', 'toiletRemind'),
    const Text('进餐', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
    _sc('能使用小勺独立进餐', 'eatingSelf'),
    _sc('餐后能主动漱口和擦嘴', 'eatingWipe'),
    const Text('穿衣', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
    _sc('能自己穿脱简单的衣裤和鞋袜，不依赖成人', 'dressingSelf'),
    const Text('卫生习惯', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
    _sc('能自己擦鼻涕', 'hygieneNose'),
    _sc('饭前、便后、手脏时知道洗手', 'hygieneWash'),
    _sc('在成人提醒下能早晚刷牙', 'hygieneBrush'),
    const Text('安全', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
    _sc('外出时跟随成人、不乱跑', 'safetyFollow'),
    _sc('游戏时不做危险动作', 'safetyGame'),
    _sectionTitle('家长受训经验及教育能力'),
    _cbRow('受训经验: 已参加家长培训', ['是', '否'], _draft.parentTrainingNote, 'trained'),
    _cbRow('家长与孩子互动与游戏', ['主动', '被动'], _draft.parentTrainingNote, 'interaction'),
    _cbRow('对于孩子耳聋事件的情绪阶段', ['否认', '接受', '悲伤', '缓和'], _draft.parentTrainingNote, 'emotionStage'),
    _cbRow('家长参与课堂表现', ['主动', '被动'], _draft.parentTrainingNote, 'classPresence'),
    _cbRow('家长技巧学习能力', ['佳', '1-2次引导即可', '需3次以上引导'], _draft.parentTrainingNote, 'skillLearn'),
    _cbRow('对孩子教养观念与信念', ['佳', '有概念但须提醒', '无概念'], _draft.parentTrainingNote, 'parentBelief'),
    _cbRow('对孩子的期望值', ['高', '低'], _draft.parentTrainingNote, 'expectation'),
    _cbRow('对孩子的敏感度', ['高', '低'], _draft.parentTrainingNote, 'sensitivity'),
    _cbRow('对幼儿发展的认知', ['有', '无', '部分理解'], _draft.parentTrainingNote, 'devCognition'),
    _cbRow('阅读习惯', ['有', '无', '有时间就做'], _draft.parentTrainingNote, 'readingHabit'),
    _cbRow('作息规律性', ['规律', '不规律'], _draft.parentTrainingNote, 'routine'),
    _cbRow('资料收集能力', ['主动', '被动'], _draft.parentTrainingNote, 'dataCollect'),
    _cbRow('家长回应孩子需求', ['主动', '不理会', '需提醒'], _draft.parentTrainingNote, 'respondNeed'),
  ]);

  // ═══ Part 3 — 综合建议 ═══
  Widget _buildPart3Advice() => ListView(padding: const EdgeInsets.all(16), children: [
    _partNav(prevPage: 1),
    _sectionTitle('综合建议'),
    _tf('综合建议', _draft.briefDesc, (v) => _draft = _draft.copyWith(
          comprehensiveAdvice: {...?_draft.comprehensiveAdvice, 'briefDesc': v}), maxLines: 5),
    _tf('评估者姓名', _draft.evaluatorName, (v) => _draft = _draft.copyWith(evaluatorName: v)),
    _df('评估日期', _draft.evalDate, (v) => _draft = _draft.copyWith(evalDate: v)),
  ]);
}

// ════════════════════════════════════════════════════════════════
//  持续评估 — 独立编辑页面（全屏 Scaffold）
// ════════════════════════════════════════════════════════════════

class ContEvalEditScreen extends ConsumerStatefulWidget {
  const ContEvalEditScreen({required this.archiveId, this.evalId, super.key});
  final String archiveId;

  /// 传入已有持续评估 id 时进入「编辑」模式，为空则为「新建」。
  final String? evalId;
  @override
  ConsumerState<ContEvalEditScreen> createState() => _ContEvalEditScreenState();
}

class _ContEvalEditScreenState extends ConsumerState<ContEvalEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final PageController _pageController = PageController();
  late RehabContEval _draft;
  String _seqStr = '';

  /// Checkbox 选中状态。
  final Map<String, Set<String>> _cbState = <String, Set<String>>{};

  /// 是否编辑已有记录（决定保存走 PUT 还是 POST）。
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    // ① 优先加载已有持续评估记录；找不到才新建空白草稿。
    final RehabContEval? existing = _findExisting();
    if (existing != null) {
      _draft = existing;
      _isEditing = true;
      _seqStr = existing.evalSeq?.toString() ?? '';
    } else {
      _draft = RehabContEval(archiveId: widget.archiveId);
    }
    _ensureDomainMaps();
    _autoFillFromFirstEval();
    _initCbState();
  }

  /// 确保所有 JSON 域 Map 非 null。
  /// 修复前这些字段默认是 null，导致 _syncCbStateToDraft 直接 return，
  /// 用户勾选的 checkbox 全部丢失（表现为「保存了但没存上」）。
  void _ensureDomainMaps() {
    Map<String, dynamic> m(Map<String, dynamic>? x) => x ?? <String, dynamic>{};
    _draft = _draft.copyWith(
      hearingData: m(_draft.hearingData),
      auditoryMemoryData: m(_draft.auditoryMemoryData),
      auditoryDescData: m(_draft.auditoryDescData),
      recordingData: m(_draft.recordingData),
      noisyEnvData: m(_draft.noisyEnvData),
      groupListenData: m(_draft.groupListenData),
      phoneSkillData: m(_draft.phoneSkillData),
      activeListenData: m(_draft.activeListenData),
      capLevelData: m(_draft.capLevelData),
      languageVocabData: m(_draft.languageVocabData),
      languageQuestionData: m(_draft.languageQuestionData),
      sirLevelData: m(_draft.sirLevelData),
      speechQualityData: m(_draft.speechQualityData),
      speechSupraSegmentalData: m(_draft.speechSupraSegmentalData),
      speechToneData: m(_draft.speechToneData),
      speechVowelData: m(_draft.speechVowelData),
      speechConsonantData: m(_draft.speechConsonantData),
      cognitionClassifyData: m(_draft.cognitionClassifyData),
      cognitionColorData: m(_draft.cognitionColorData),
      cognitionNumberData: m(_draft.cognitionNumberData),
      cognitionShapeData: m(_draft.cognitionShapeData),
      cognitionTouchData: m(_draft.cognitionTouchData),
      cognitionCompareData: m(_draft.cognitionCompareData),
      cognitionSequenceData: m(_draft.cognitionSequenceData),
      cognitionReasoningData: m(_draft.cognitionReasoningData),
      cognitionAnalogyData: m(_draft.cognitionAnalogyData),
      cognitionSynonymData: m(_draft.cognitionSynonymData),
      cognitionAntonymData: m(_draft.cognitionAntonymData),
      cognitionPunData: m(_draft.cognitionPunData),
      cognitionJokeData: m(_draft.cognitionJokeData),
      cognitionRiddleData: m(_draft.cognitionRiddleData),
      commSequenceData: m(_draft.commSequenceData),
      commBehaviorData: m(_draft.commBehaviorData),
      commStrategyData: m(_draft.commStrategyData),
      parentPerformanceData: m(_draft.parentPerformanceData),
    );
  }

  /// 从已加载的档案详情中查找待编辑的持续评估。
  RehabContEval? _findExisting() {
    final id = widget.evalId;
    if (id == null || id.isEmpty) return null;
    final s = ref.read(rehabArchiveDetailProvider(widget.archiveId));
    final list = s.detail?.contEvals ?? const <RehabContEval>[];
    for (final c in list) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// 从首次评估自动填充基础信息（姓名/性别/补偿方式等）。
  void _autoFillFromFirstEval() {
    final s = ref.read(rehabArchiveDetailProvider(widget.archiveId));
    final fe = s.detail?.firstEval;
    if (fe == null) return;

    // 计算生理年龄和听觉年龄（基于出生日期）
    String? calcAge(DateTime? birth) {
      if (birth == null) return null;
      final now = DateTime.now();
      int months = (now.year - birth.year) * 12 + now.month - birth.month;
      if (now.day < birth.day) months--;
      if (months < 0) return null;
      final years = months ~/ 12;
      final remain = months % 12;
      return '${years}岁${remain}个月';
    }

    _draft = _draft.copyWith(
      // 如果持续评估已有数据则保留，否则从首次评估填充
      physiologicalAge: _draft.physiologicalAge.isEmpty ? (calcAge(fe.birthDate) ?? '') : _draft.physiologicalAge,
      hearingAge: _draft.hearingAge.isEmpty ? (calcAge(fe.diagnosisConfirmDate) ?? '') : _draft.hearingAge,
      evalDate: _draft.evalDate ?? DateTime.now(),
    );
    // 补偿方式等只读展示字段已在 Part1 UI 中直接从 fe 读取，无需存入 draft
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _initCbState() {
    _cbState.clear();
    void initFrom(Map<String, dynamic>? domain) {
      if (domain == null) return;
      for (final e in domain.entries) {
        if (e.value is List) _cbState[e.key] = Set<String>.from(e.value as Iterable);
      }
    }
    initFrom(_draft.hearingData);
    initFrom(_draft.auditoryMemoryData);
    initFrom(_draft.auditoryDescData);
    initFrom(_draft.recordingData);
    initFrom(_draft.noisyEnvData);
    initFrom(_draft.groupListenData);
    initFrom(_draft.phoneSkillData);
    initFrom(_draft.activeListenData);
    initFrom(_draft.capLevelData);
    initFrom(_draft.languageVocabData);
    initFrom(_draft.languageQuestionData);
    initFrom(_draft.sirLevelData);
    initFrom(_draft.speechQualityData);
    initFrom(_draft.speechSupraSegmentalData);
    initFrom(_draft.speechToneData);
    initFrom(_draft.speechVowelData);
    initFrom(_draft.speechConsonantData);
    initFrom(_draft.cognitionClassifyData);
    initFrom(_draft.cognitionColorData);
    initFrom(_draft.cognitionNumberData);
    initFrom(_draft.cognitionShapeData);
    initFrom(_draft.cognitionTouchData);
    initFrom(_draft.cognitionCompareData);
    initFrom(_draft.cognitionSequenceData);
    initFrom(_draft.cognitionReasoningData);
    initFrom(_draft.cognitionAnalogyData);
    initFrom(_draft.cognitionSynonymData);
    initFrom(_draft.cognitionAntonymData);
    initFrom(_draft.cognitionPunData);
    initFrom(_draft.cognitionJokeData);
    initFrom(_draft.cognitionRiddleData);
    initFrom(_draft.commSequenceData);
    initFrom(_draft.commBehaviorData);
    initFrom(_draft.commStrategyData);
    initFrom(_draft.parentPerformanceData);
  }

  void _syncCbStateToDraft() {
    void syncTo(Map<String, dynamic>? domain) {
      if (domain == null) return;
      for (final e in _cbState.entries) {
        if (domain.containsKey(e.key)) domain[e.key] = e.value.toList();
      }
    }
    syncTo(_draft.hearingData); syncTo(_draft.auditoryMemoryData);
    syncTo(_draft.auditoryDescData); syncTo(_draft.recordingData);
    syncTo(_draft.noisyEnvData); syncTo(_draft.groupListenData);
    syncTo(_draft.phoneSkillData); syncTo(_draft.activeListenData);
    syncTo(_draft.capLevelData); syncTo(_draft.languageVocabData);
    syncTo(_draft.languageQuestionData); syncTo(_draft.sirLevelData);
    syncTo(_draft.speechQualityData); syncTo(_draft.speechSupraSegmentalData);
    syncTo(_draft.speechToneData); syncTo(_draft.speechVowelData);
    syncTo(_draft.speechConsonantData); syncTo(_draft.cognitionClassifyData);
    syncTo(_draft.cognitionColorData); syncTo(_draft.cognitionNumberData);
    syncTo(_draft.cognitionShapeData); syncTo(_draft.cognitionTouchData);
    syncTo(_draft.cognitionCompareData);
    syncTo(_draft.cognitionSequenceData);
    syncTo(_draft.cognitionReasoningData); syncTo(_draft.cognitionAnalogyData);
    syncTo(_draft.cognitionSynonymData); syncTo(_draft.cognitionAntonymData);
    syncTo(_draft.cognitionPunData); syncTo(_draft.cognitionJokeData);
    syncTo(_draft.cognitionRiddleData);
    syncTo(_draft.commSequenceData);
    syncTo(_draft.commBehaviorData); syncTo(_draft.commStrategyData);
    syncTo(_draft.parentPerformanceData);
  }

  // ── 表单组件 ──
  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
        child: Row(children: [
          Container(width: 4, height: 18, decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15,
              color: Theme.of(context).colorScheme.primary)),
        ]),
      );
  Widget _tf(String label, String initial, ValueChanged<String> onSaved,
      {int maxLines = 1, TextInputType? keyboard}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: TextFormField(initialValue: initial, maxLines: maxLines, minLines: 1,
          keyboardType: keyboard,
          decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(fontSize: 13),
            border: InputBorder.none,
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade300)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Theme.of(context).colorScheme.primary)),
            contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 0)),
          onSaved: (v) => onSaved(v ?? ''),
        ),
      );
  Widget _df(String label, DateTime? value, ValueChanged<DateTime?> o) =>
      Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: _DateField(label: label, value: value, onChanged: o));
  Widget _dd(String label, String value, ValueChanged<String?> o, List<String> opts) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: DropdownButtonFormField<String>(value: opts.contains(value) ? value : null,
          decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(fontSize: 13),
            border: InputBorder.none,
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade300)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Theme.of(context).colorScheme.primary)),
            contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 0)),
          items: opts.map((o) => DropdownMenuItem<String>(value: o, child: Text(o, style: const TextStyle(fontSize: 14)))).toList(),
          onChanged: o));
  Widget _partNav({int?p,int?n,String?l})=>Container(padding:const EdgeInsets.symmetric(vertical:10),
    decoration:BoxDecoration(color:Colors.grey.shade50,borderRadius:BorderRadius.circular(8)),
    child:Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[
      if(p!=null) TextButton.icon(onPressed:()=>_pageController.animateToPage(p,duration:const Duration(milliseconds:300),curve:Curves.easeInOut),icon:const Icon(Icons.arrow_back,size:16),label:const Text('上一部分')) else const SizedBox(width:80),
      if(n!=null) FilledButton.tonal(onPressed:()=>_pageController.animateToPage(n,duration:const Duration(milliseconds:300),curve:Curves.easeInOut),child:Text(l??'下一部分→')) else const SizedBox(width:80),
    ]));

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title:Text(_isEditing?'编辑持续评估（第${_seqStr.isEmpty?"?":_seqStr}次）':'新建持续评估'),leading:IconButton(icon:const Icon(Icons.arrow_back),onPressed:()=>context.pop())),
    body:Form(key:_formKey,child:Column(children:[
      Expanded(child:PageView(controller:_pageController,physics:const NeverScrollableScrollPhysics(),
        children:[_buildPart1Basic(),_buildPart2Eval(),_buildPart3Advice()])),
      SafeArea(child:Padding(padding:const EdgeInsets.fromLTRB(16,0,16,8),
        child:FilledButton.icon(onPressed:_save,icon:const Icon(Icons.save,size:18),label:const Text('保存持续评估')),
      )),
    ])),
  );

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    _syncCbStateToDraft();
    final seq = int.tryParse(_seqStr);
    final bool ok = await ref
        .read(rehabArchiveDetailProvider(widget.archiveId).notifier)
        .submitContEval(_draft.copyWith(evalSeq: seq));
    if (!mounted) return;
    // 修复前：无论成功失败都 pop，保存失败时用户毫无察觉。
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isEditing ? '持续评估已更新' : '持续评估已保存')));
      context.pop();
    } else {
      final err = ref.read(rehabArchiveDetailProvider(widget.archiveId)).error;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err ?? '保存失败，请重试'), backgroundColor: Colors.red));
    }
  }

  // ═══ Cont Eval Part 1 ═══
  Widget _buildPart1Basic(){final detail=ref.watch(rehabArchiveDetailProvider(widget.archiveId)).detail;final a=detail?.archive;final fe=detail?.firstEval;
    final comp=<String>[];if(fe!=null){if(fe.leftCompensationType.isNotEmpty)comp.add('左：${fe.leftCompensationType}');if(fe.rightCompensationType.isNotEmpty)comp.add('右：${fe.rightCompensationType}');}
    return ListView(padding:const EdgeInsets.fromLTRB(16,12,16,8),children:[
      _partNav(n:1,l:'下一部分：评估内容→'),_sectionTitle('基本资料'),
      Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Expanded(flex:2,child:_tf('姓名',a?.childName??'',(v){})),Expanded(child:_dd('性别',fe?.gender??'',(v){},['男','女'])),
      ]),
      Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Expanded(child:_tf('生理年龄',_draft.physiologicalAge,(v)=>_draft=_draft.copyWith(physiologicalAge:v))),
        Expanded(child:_tf('听觉年龄',_draft.hearingAge,(v)=>_draft=_draft.copyWith(hearingAge:v))),
      ]),
      Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Expanded(child:_df('第一次评估时间',_draft.evalTime1,(d)=>_draft=_draft.copyWith(evalTime1:d))),
        Expanded(child:_df('第二次评估时间',_draft.evalTime2,(d)=>_draft=_draft.copyWith(evalTime2:d))),
        Expanded(child:_df('第三次评估时间',_draft.evalTime3,(d)=>_draft=_draft.copyWith(evalTime3:d))),
      ]),
      _sectionTitle('本次评估信息'),_tf('评估序号',_seqStr,(v)=>_seqStr=v,keyboard:TextInputType.number),
      _df('评估时间',_draft.evalDate,(d)=>_draft=_draft.copyWith(evalDate:d)),
      _tf('评估者姓名',_draft.evaluatorName,(v)=>_draft=_draft.copyWith(evaluatorName:v)),
      if(comp.isNotEmpty)...[const SizedBox(height:6),Text('补偿/重建方式：${comp.join(" / ")}',style:const TextStyle(fontSize:13,color:Colors.black87))],
      _sectionTitle('听觉能力'),
      SymbolField(label:'听觉记忆',value:HearingSymbol.indexFromValue(_draft.hearingData!['auditoryMemScore']),onChanged:(v)=>setState(()=>_draft.hearingData!['auditoryMemScore']=v)),
      SymbolField(label:'察觉: 自己名字 / 语音 / 环境音 / 有声玩具',value:HearingSymbol.indexFromValue(_draft.hearingData!['soundDetect']),onChanged:(v)=>setState(()=>_draft.hearingData!['soundDetect']=v)),
      SymbolField(label:'辨识: 自己名字 / 语音 / 环境音 / 有声玩具',value:HearingSymbol.indexFromValue(_draft.hearingData!['soundIdentify']),onChanged:(v)=>setState(()=>_draft.hearingData!['soundIdentify']=v)),
      _sectionTitle('语言能力'),
      SymbolField(label:'词汇量',value:HearingSymbol.indexFromValue(_draft.capLevelData!['vocabCount']),onChanged:(v)=>setState(()=>_draft.capLevelData!['vocabCount']=v)),
      SymbolField(label:'音节/声韵母区别',value:HearingSymbol.indexFromValue(_draft.languageVocabData!['diffWord']),onChanged:(v)=>setState(()=>_draft.languageVocabData!['diffWord']=v)),
      _sectionTitle('言语能力'),
      SymbolField(label:'音质',value:HearingSymbol.indexFromValue(_draft.speechQualityData!['natural']),onChanged:(v)=>setState(()=>_draft.speechQualityData!['natural']=v)),
      // 纸表 1.1.2 的「音质」是 4 个 □，没有说明文本框；这栏只作 App 内部备注。
      // 原来 onSaved 是空函数，老师填了根本不保存——已改为写 speechQualityData['note']。
      _tf('清晰度说明（内部备注）',jsonStr(_draft.speechQualityData,['note']),
          (v)=>setState(()=>_draft.speechQualityData!['note']=v),maxLines:2),
      _sectionTitle('认知能力'),
      SymbolField(label:'基础颜色辨认',value:HearingSymbol.indexFromValue(_draft.cognitionColorData!['basic']),onChanged:(v)=>setState(()=>_draft.cognitionColorData!['basic']=v)),
      SymbolField(label:'扩展颜色辨认',value:HearingSymbol.indexFromValue(_draft.cognitionColorData!['extended']),onChanged:(v)=>setState(()=>_draft.cognitionColorData!['extended']=v)),
      SymbolField(label:'抽象颜色概念',value:HearingSymbol.indexFromValue(_draft.cognitionColorData!['abstract']),onChanged:(v)=>setState(()=>_draft.cognitionColorData!['abstract']=v)),
      _sectionTitle('沟通能力'),
      SymbolField(label:'沟通策略',value:HearingSymbol.indexFromValue(_draft.commStrategyData!['strategy']),onChanged:(v)=>setState(()=>_draft.commStrategyData!['strategy']=v)),
      SymbolField(label:'轮流/轮替',value:HearingSymbol.indexFromValue(_draft.commBehaviorData!['turnTaking']),onChanged:(v)=>setState(()=>_draft.commBehaviorData!['turnTaking']=v)),
      SymbolField(label:'眼神交流',value:HearingSymbol.indexFromValue(_draft.commBehaviorData!['eyeContact']),onChanged:(v)=>setState(()=>_draft.commBehaviorData!['eyeContact']=v)),
      SymbolField(label:'共同注意力',value:HearingSymbol.indexFromValue(_draft.commBehaviorData!['jointAttn']),onChanged:(v)=>setState(()=>_draft.commBehaviorData!['jointAttn']=v)),
      _sectionTitle('家长执行成效'),
      SymbolField(label:'康复训练执行情况',value:HearingSymbol.indexFromValue(_draft.parentPerformanceData!['trainingExec']),onChanged:(v)=>setState(()=>_draft.parentPerformanceData!['trainingExec']=v)),
      SymbolField(label:'配戴助听设备情况',value:HearingSymbol.indexFromValue(_draft.parentPerformanceData!['deviceWear']),onChanged:(v)=>setState(()=>_draft.parentPerformanceData!['deviceWear']=v)),
      SymbolField(label:'亲子互动质量',value:HearingSymbol.indexFromValue(_draft.parentPerformanceData!['interactionQ']),onChanged:(v)=>setState(()=>_draft.parentPerformanceData!['interactionQ']=v)),
      SymbolField(label:'家庭康复环境支持',value:HearingSymbol.indexFromValue(_draft.parentPerformanceData!['homeSupport']),onChanged:(v)=>setState(()=>_draft.parentPerformanceData!['homeSupport']=v)),
    ]);}

  // ═══ Cont Eval Part 2 ═══
  Widget _buildPart2Eval()=>ListView(padding:const EdgeInsets.all(16),children:[
    _partNav(p:0,n:2,l:'下一部分：总结→'),
    _sectionTitle('听觉能力（详细）'),
    SymbolField(label:'有情景提示下',value:HearingSymbol.indexFromValue(_draft.auditoryDescData!['withCue']),onChanged:(v)=>setState(()=>_draft.auditoryDescData!['withCue']=v)),
    SymbolField(label:'无情景提示下',value:HearingSymbol.indexFromValue(_draft.auditoryDescData!['noCue']),onChanged:(v)=>setState(()=>_draft.auditoryDescData!['noCue']=v)),
    _sectionTitle('言语能力（超音段/声调/韵母/声母）'),
    SymbolField(label:'时间',value:HearingSymbol.indexFromValue(_draft.speechSupraSegmentalData!['time']),onChanged:(v)=>setState(()=>_draft.speechSupraSegmentalData!['time']=v)),
    SymbolField(label:'音量',value:HearingSymbol.indexFromValue(_draft.speechSupraSegmentalData!['volume']),onChanged:(v)=>setState(()=>_draft.speechSupraSegmentalData!['volume']=v)),
    SymbolField(label:'音调',value:HearingSymbol.indexFromValue(_draft.speechSupraSegmentalData!['pitch']),onChanged:(v)=>setState(()=>_draft.speechSupraSegmentalData!['pitch']=v)),
    SymbolField(label:'声调',value:HearingSymbol.indexFromValue(_draft.speechToneData!['tones']),onChanged:(v)=>setState(()=>_draft.speechToneData!['tones']=v)),
    SymbolField(label:'单韵母',value:HearingSymbol.indexFromValue(_draft.speechVowelData!['single']),onChanged:(v)=>setState(()=>_draft.speechVowelData!['single']=v)),
    SymbolField(label:'韵母轮换',value:HearingSymbol.indexFromValue(_draft.speechVowelData!['rotation']),onChanged:(v)=>setState(()=>_draft.speechVowelData!['rotation']=v)),
    SymbolField(label:'复合韵母(尾)',value:HearingSymbol.indexFromValue(_draft.speechVowelData!['compoundEnd']),onChanged:(v)=>setState(()=>_draft.speechVowelData!['compoundEnd']=v)),
    SymbolField(label:'鼻韵母(尾)',value:HearingSymbol.indexFromValue(_draft.speechVowelData!['nasalEnd']),onChanged:(v)=>setState(()=>_draft.speechVowelData!['nasalEnd']=v)),
    SymbolField(label:'鼻韵母(首)',value:HearingSymbol.indexFromValue(_draft.speechVowelData!['nasalStart']),onChanged:(v)=>setState(()=>_draft.speechVowelData!['nasalStart']=v)),
    SymbolField(label:'声母组1',value:HearingSymbol.indexFromValue(_draft.speechConsonantData!['group1']),onChanged:(v)=>setState(()=>_draft.speechConsonantData!['group1']=v)),
    SymbolField(label:'声母组2',value:HearingSymbol.indexFromValue(_draft.speechConsonantData!['group2']),onChanged:(v)=>setState(()=>_draft.speechConsonantData!['group2']=v)),
    _sectionTitle('认知能力（详细）'),
    SymbolField(label:'唱数',value:HearingSymbol.indexFromValue(_draft.cognitionNumberData!['countSing']),onChanged:(v)=>setState(()=>_draft.cognitionNumberData!['countSing']=v)),
    SymbolField(label:'认识数字',value:HearingSymbol.indexFromValue(_draft.cognitionNumberData!['countRecognize']),onChanged:(v)=>setState(()=>_draft.cognitionNumberData!['countRecognize']=v)),
    SymbolField(label:'比较数字大小',value:HearingSymbol.indexFromValue(_draft.cognitionNumberData!['compareNum']),onChanged:(v)=>setState(()=>_draft.cognitionNumberData!['compareNum']=v)),
    SymbolField(label:'量的概念',value:HearingSymbol.indexFromValue(_draft.cognitionNumberData!['quantity']),onChanged:(v)=>setState(()=>_draft.cognitionNumberData!['quantity']=v)),
    SymbolField(label:'比较数量多少',value:HearingSymbol.indexFromValue(_draft.cognitionNumberData!['compareQty']),onChanged:(v)=>setState(()=>_draft.cognitionNumberData!['compareQty']=v)),
    SymbolField(label:'币值的概念',value:HearingSymbol.indexFromValue(_draft.cognitionNumberData!['money']),onChanged:(v)=>setState(()=>_draft.cognitionNumberData!['money']=v)),
    SymbolField(label:'触觉1',value:HearingSymbol.indexFromValue(_draft.cognitionTouchData!['texture1']),onChanged:(v)=>setState(()=>_draft.cognitionTouchData!['texture1']=v)),
    SymbolField(label:'触觉2',value:HearingSymbol.indexFromValue(_draft.cognitionTouchData!['texture2']),onChanged:(v)=>setState(()=>_draft.cognitionTouchData!['texture2']=v)),
    // ── 认知第二批（纸表 1.1.2 第 6 页）：顺序/推理/语言游戏 ──
    _sectionTitle('认知能力（顺序与推理）'),
    SymbolField(label:'顺序概念：在家中的一些事情(3岁)',value:HearingSymbol.indexFromValue(_draft.cognitionSequenceData!['homeEvents']),onChanged:(v)=>setState(()=>_draft.cognitionSequenceData!['homeEvents']=v)),
    SymbolField(label:'顺序概念：简单的手指游戏(3岁)',value:HearingSymbol.indexFromValue(_draft.cognitionSequenceData!['fingerGame']),onChanged:(v)=>setState(()=>_draft.cognitionSequenceData!['fingerGame']=v)),
    SymbolField(label:'顺序概念：形状、数量(3岁)',value:HearingSymbol.indexFromValue(_draft.cognitionSequenceData!['shapeQty']),onChanged:(v)=>setState(()=>_draft.cognitionSequenceData!['shapeQty']=v)),
    SymbolField(label:'顺序概念：旅游（相片）(3岁)',value:HearingSymbol.indexFromValue(_draft.cognitionSequenceData!['travelPhotos']),onChanged:(v)=>setState(()=>_draft.cognitionSequenceData!['travelPhotos']=v)),
    SymbolField(label:'顺序概念：有顺序之指令(3岁)',value:HearingSymbol.indexFromValue(_draft.cognitionSequenceData!['seqInstructions']),onChanged:(v)=>setState(()=>_draft.cognitionSequenceData!['seqInstructions']=v)),
    SymbolField(label:'顺序概念：含2~3个段落的故事',value:HearingSymbol.indexFromValue(_draft.cognitionSequenceData!['story23']),onChanged:(v)=>setState(()=>_draft.cognitionSequenceData!['story23']=v)),
    SymbolField(label:'顺序概念：听故事及顺序(4岁)',value:HearingSymbol.indexFromValue(_draft.cognitionSequenceData!['storyListen']),onChanged:(v)=>setState(()=>_draft.cognitionSequenceData!['storyListen']=v)),
    SymbolField(label:'顺序概念：童谣、儿歌(4岁)',value:HearingSymbol.indexFromValue(_draft.cognitionSequenceData!['rhymes']),onChanged:(v)=>setState(()=>_draft.cognitionSequenceData!['rhymes']=v)),
    SymbolField(label:'顺序概念：以不同顺序发展一则故事(5岁)',value:HearingSymbol.indexFromValue(_draft.cognitionSequenceData!['storyDevelop']),onChanged:(v)=>setState(()=>_draft.cognitionSequenceData!['storyDevelop']=v)),
    SymbolField(label:'顺序概念：故事接龙(开始/中间/结局)',value:HearingSymbol.indexFromValue(_draft.cognitionSequenceData!['storyChain']),onChanged:(v)=>setState(()=>_draft.cognitionSequenceData!['storyChain']=v)),
    SymbolField(label:'顺序概念：包含语法的顺序描述(6岁)',value:HearingSymbol.indexFromValue(_draft.cognitionSequenceData!['grammarSeq']),onChanged:(v)=>setState(()=>_draft.cognitionSequenceData!['grammarSeq']=v)),
    SymbolField(label:'推理：事件推理',value:HearingSymbol.indexFromValue(_draft.cognitionReasoningData!['event']),onChanged:(v)=>setState(()=>_draft.cognitionReasoningData!['event']=v)),
    SymbolField(label:'推理：时间推理',value:HearingSymbol.indexFromValue(_draft.cognitionReasoningData!['time']),onChanged:(v)=>setState(()=>_draft.cognitionReasoningData!['time']=v)),
    SymbolField(label:'推理：字词推理',value:HearingSymbol.indexFromValue(_draft.cognitionReasoningData!['word']),onChanged:(v)=>setState(()=>_draft.cognitionReasoningData!['word']=v)),
    SymbolField(label:'推理：找原因',value:HearingSymbol.indexFromValue(_draft.cognitionReasoningData!['cause']),onChanged:(v)=>setState(()=>_draft.cognitionReasoningData!['cause']=v)),
    _sectionTitle('认知能力（词汇与语言游戏）'),
    SymbolField(label:'类推',value:HearingSymbol.indexFromValue(_draft.cognitionAnalogyData!['level']),onChanged:(v)=>setState(()=>_draft.cognitionAnalogyData!['level']=v)),
    SymbolField(label:'同义词',value:HearingSymbol.indexFromValue(_draft.cognitionSynonymData!['level']),onChanged:(v)=>setState(()=>_draft.cognitionSynonymData!['level']=v)),
    SymbolField(label:'相反词',value:HearingSymbol.indexFromValue(_draft.cognitionAntonymData!['level']),onChanged:(v)=>setState(()=>_draft.cognitionAntonymData!['level']=v)),
    SymbolField(label:'双关语',value:HearingSymbol.indexFromValue(_draft.cognitionPunData!['level']),onChanged:(v)=>setState(()=>_draft.cognitionPunData!['level']=v)),
    SymbolField(label:'笑话',value:HearingSymbol.indexFromValue(_draft.cognitionJokeData!['level']),onChanged:(v)=>setState(()=>_draft.cognitionJokeData!['level']=v)),
    SymbolField(label:'谜语',value:HearingSymbol.indexFromValue(_draft.cognitionRiddleData!['level']),onChanged:(v)=>setState(()=>_draft.cognitionRiddleData!['level']=v)),
  ]);

  // ═══ Cont Eval Part 3 ═══
  Widget _buildPart3Advice()=>ListView(padding:const EdgeInsets.all(16),children:[
    _partNav(p:1),_sectionTitle('总结'),
    _tf('教师评语',_draft.teacherNotes,(v)=>_draft=_draft.copyWith(teacherNotes:v),maxLines:4),
    _tf('家长表现备注',_draft.parentPerformance,(v)=>_draft=_draft.copyWith(parentPerformance:v),maxLines:3),
  ]);
}
