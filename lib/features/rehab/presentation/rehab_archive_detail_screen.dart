import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:teacher_app/data/models/rehab.dart';
import 'package:teacher_app/features/ai_lesson_plan/data/ai_lesson_plan_repository.dart';
import 'package:teacher_app/features/rehab/presentation/widgets/export_pdf_button.dart';
import 'package:teacher_app/features/rehab/presentation/widgets/hearing_symbol.dart';
import 'package:teacher_app/features/rehab/data/cont_eval_catalog.dart';
import 'package:teacher_app/features/rehab/presentation/widgets/cont_eval_catalog_form.dart';
import 'package:teacher_app/features/rehab/presentation/widgets/part_nav_bar.dart';
import 'package:teacher_app/features/rehab/provider/rehab_provider.dart';
import 'package:teacher_app/shared/authed_image.dart';

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
  const RehabArchiveDetailScreen({required this.archiveId, this.initialTab, super.key});
  final String archiveId;

  /// 初始 Tab：'first' / 'cont' / 'plan' / 'photo'，为空或未知则落在首个 Tab。
  final String? initialTab;

  @override
  ConsumerState<RehabArchiveDetailScreen> createState() =>
      _RehabArchiveDetailScreenState();
}

class _RehabArchiveDetailScreenState
    extends ConsumerState<RehabArchiveDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  /// Tab key → index，顺序必须与下面 TabBar 的 tabs 一致。
  static int _tabIndexOf(String? key) {
    switch (key) {
      case 'cont':
        return 1;
      case 'plan':
        return 2;
      case 'photo':
        return 3;
      default:
        return 0;
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: _tabIndexOf(widget.initialTab),
    );
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

    // 听障详情页 4 Tab（首次评估 / 持续评估 / 教学计划 / 手写照片）。
    // 听能管理已按业务要求隐藏（oa.rehab.hearing-mgmt-visible 默认 false），
    // 相关页面（HearingRecordTab / HearingSectionScreen）暂时保留代码，
    // 待业务恢复时把 Tab 与入口加回即可。
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

        // 纸表「家庭资料」列序：姓名 / 民族 / 身份证号 / 受教育程度 / 职业 / 联系方式
        // （没有「年龄」列；旧读法一直在显示空的 age，且漏了身份证号）
        _sect(ctx, '四、家庭资料'),
        _sub('父亲'),
        _ro('姓名', fe.father('name')), _ro('民族', fe.father('ethnicity')),
        _ro('身份证号', fe.father('idNumber')),
        _ro('受教育程度', fe.father('education')),
        _ro('职业', fe.father('occupation')), _ro('联系方式', fe.father('contact')),
        _sub('母亲'),
        _ro('姓名', fe.mother('name')), _ro('民族', fe.mother('ethnicity')),
        _ro('身份证号', fe.mother('idNumber')),
        _ro('受教育程度', fe.mother('education')),
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
    final lg = fe.domainLanguage;
    final sp = fe.domainSpeech;
    final cg = fe.domainCognition;
    final cm = fe.domainCommunication;
    final bh = fe.behaviorNote;
    final pt = fe.parentTrainingNote;
    // 注：听觉能力各题的「真相域」是 domainHearingMgmt（见下方注释），
    // 所以这里不再取 domainHearingAbility，避免有人误用那个空域。
    return ListView(padding: const EdgeInsets.all(16), children: [
      _sect(ctx, '听能管理'),
      _q(hm, '家长了解助听设备保养及检查程序', 'deviceCareProgram'),
      _q(hm, '除睡觉洗澡游泳外均配戴设备', 'alwaysWear'),
      _q(hm, '家中听觉环境', 'homeEnv'),
      _q(hm, '幼儿的听觉习惯', 'hearingHabit'),
      _q(hm, '已有助听设备保养工具', 'careTools'),
      _q(hm, '配戴后对声音反应的改变', 'reactionChange'),

      // ⚠ 听觉能力这几项在**编辑页**写的是 domainHearingMgmt（不是 domainHearingAbility），
      //   键名也没有 Sound / 六音的英文后缀。只读页原来按 domainHearingAbility +
      //   envSoundReaction / nameCallReaction / lingSixReaction 读，永远读到空——
      //   典型的「只读页怎么读」与「编辑页怎么写」脱钩。
      //   这里统一到编辑页的契约（也是导出 HearingExportService 认的契约）。
      _sect(ctx, '听觉能力'),
      _q(hm, '对环境声音的反应', 'envReaction'),
      _q(hm, '对语音的反应', 'voiceReaction'),
      _q(hm, '对名字/家人称谓的反应', 'nameReaction'),
      _q(hm, '对林氏六音的反应（纸表无此栏）', 'lingReaction'),
      _ro('听觉记忆（项）', _v(hm, 'auditoryMemCount')),
      _ro('听觉记忆组合类型', _v(hm, 'auditoryMemType')),
      _ro('听觉描述·闭合式阶段', _v(hm, 'auditoryDescClosed')),
      _ro('听觉描述·开放式阶段', _v(hm, 'auditoryDescOpen')),
      _ro('言语识别平均得分', _v(hm, 'speechIdentifyScore')),
      _ro('CAP 听觉行为分级', _v(hm, 'capLevel')),

      _sect(ctx, '语言能力'),
      _q(lg, '沟通模式', 'commMode'),
      _q(lg, '理解性语言程度', 'understandingLevel'),
      _q(lg, '表达性语言程度', 'expressingNone'),
      _q(lg, '模仿复述', 'expressingImitate'),
      _ro('模仿复述·句子长度', _v(lg, 'imitateLength')),
      _ro('模仿复述·例如', _v(lg, 'imitateExample')),
      _q(lg, '主动表达', 'expressingActive'),
      _ro('主动表达·句子长度', _v(lg, 'activeLength')),
      _ro('主动表达·例如', _v(lg, 'activeExample')),
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
      _ro('问句能力说明', _v(lg, 'questionNote')),
      _ro('平均语言年龄水平', _v(lg, 'avgLanguageAge')),
      _ro('SIR 言语可懂度分级', _v(lg, 'sirLevel')),

      _sect(ctx, '言语能力'),
      _q(sp, '能否发出声音', 'canVoice'),
      _q(sp, '超音段', 'supraSegmental'),
      _q(sp, '模仿发音', 'imitationFlag'),
      _ro('模仿发音说明', _v(sp, 'imitationNote')),

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
      // 说明项：对应纸表「□无 □有 ______」下划线上那一段（导出端会叠上去）
      _q(cm, '眼神交流说明', 'eyeContactNote'),
      _q(cm, '主动提问说明', 'activeQuestionNote'),
      _q(cm, '主动互动说明', 'activeInteractionNote'),
      _q(cm, '维持话题说明', 'maintainTopicNote'),
      _q(cm, '其他表达需求方式', 'expressModeOther'),

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
                    AuthedImage(path: _photos[i].filePath, fit: BoxFit.cover,
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

  /// 当前停留在第几部分（0 基）。PageView 禁用了手势滑动，翻页只能靠底部翻页条，
  /// 这个变量只是为了让翻页条知道当前在哪一部分（决定按钮是否可点、文案是什么）。
  int _pageIdx = 0;

  /// 三个部分的名字，用于「下一部分：xxx →」文案；顺序必须与 build 里
  /// PageView 的 children 一一对应。
  static const List<String> _partNames = <String>['基本资料', '评估内容', '综合建议'];

  /// Checkbox 选中状态：fieldKey → 已选选项集合。
  /// 修复原版 _cbRow onChanged 为空操作导致无法选中的 bug。
  final Map<String, Set<String>> _cbState = <String, Set<String>>{};

  static const List<String> _genders = ['男', '女'];
  static const List<String> _compTypes = ['助听器', '人工耳蜗', '无'];
  static const List<String> _stimStrategies = ['单侧', '双侧同步', '双侧顺次'];
  /// 助听听阈：key 用纯数字（与后端 HearingExportService.aidedVal 的 String.valueOf 一致），
  /// label 写表头；_aidedLegacyKeys 是旧版 App 写入的键，读取时回退兼容，避免历史数据读不出。
  static const List<String> _aidedKeys = ['250', '500', '1000', '2000', '3000', '4000'];
  static const List<String> _aidedLabels = ['250Hz', '500Hz', '1kHz', '2kHz', '3kHz', '4kHz'];
  static const List<String> _aidedLegacyKeys = ['250Hz', '500Hz', '1kHz', '2kHz', '3kHz', '4kHz'];
  static const List<String> _commModes = ['口语', '手势', '手语', 'PECS', '混合'];
  // 注：家庭状况已改为 _familyStatusCb() 的 5 个 □（双亲/单亲/父/母/双亡），
  // 不再是下拉；老数据「单亲-父 / 单亲-母」由 _splitFamily 兼容。
  // 纸表「家庭主要输入语言类型」是**并列的 4 个方框**：手语 / 口语 / 方言 / 普通话
  // （口语与方言、普通话可同时勾）。旧值是合并项「口语-方言 / 口语-普通话」，
  // 一个下拉只能选一个 → 既对不上纸表的框，也无法表达「口语 + 普通话」。
  static const List<String> _inputLangTypes = ['手语', '口语', '方言', '普通话'];
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

  /// 翻到第 i 部分。先 setState 让翻页条立刻反映目标状态，再动画滚过去
  /// （PageView.onPageChanged 随后会把同一个值再设一次，幂等）。
  void _goPage(int i) {
    setState(() => _pageIdx = i);
    _pageController.animateToPage(i,
        duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
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
          // 输入即时写回草稿：本页是 PageView 分 part，翻走的 part 会被销毁、
          // 其 FormField 从 Form 注销，只靠 onSaved 会导致「翻页后再保存，前面 part 填的内容全丢」
          // （表现为「填了保存不上」）。
          onChanged: (v) => onSaved(v),
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

  /// 通用「一行多选 □」控件（纸表上就是并列的几个方框）：值以顿号连接存储。
  /// family_status / family_input_lang_type 这类多选都复用它。
  Widget _multiCb(String label, List<String> opts, String value,
      void Function(String) onChanged) {
    final Set<String> cur = value
        .split(RegExp(r'[、,，]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Colors.black54)),
        const SizedBox(height: 2),
        Wrap(spacing: 12, children: opts.map((o) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: 18, height: 18,
              child: Checkbox(
                value: cur.contains(o),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onChanged: (c) {
                  final Set<String> s = Set<String>.from(cur);
                  if (c == true) {
                    s.add(o);
                  } else {
                    s.remove(o);
                  }
                  setState(() => onChanged(s.join('、')));
                },
              )),
            Text(o, style: const TextStyle(fontSize: 13)),
          ],
        )).toList()),
      ]),
    );
  }

  /// 家庭主要输入语言类型（手语 / 口语 / 方言 / 普通话，可多选）。
  Widget _inputLangCb() => _multiCb('家庭主要输入语言类型', _inputLangTypes,
      _draft.familyInputLangType,
      (v) => _draft = _draft.copyWith(familyInputLangType: v));

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

  /// 首次评估通用「往某个 JSON 域里写一个文字 key」的输入框。
  /// 认知/听觉能力/语言能力等领域的补充说明项都走它，省得每加一项都手写一遍
  /// `<String, dynamic>{...?_draft.xxx, key: v}` 的展开。
  Widget _domainText(String label, String key,
      {Map<String, dynamic>? Function()? get, void Function(Map<String, dynamic>)? set,
       int maxLines = 1, String hint = ''}) {
    final Map<String, dynamic>? cur = get != null ? get() : _draft.domainHearingMgmt;
    return _tf(
      hint.isEmpty ? label : '$label（$hint）',
      (cur?[key] ?? '').toString(),
      (v) {
        final Map<String, dynamic> nm = <String, dynamic>{...?cur, key: v};
        setState(() => set != null ? set(nm)
            : _draft = _draft.copyWith(domainHearingMgmt: nm));
      },
      maxLines: maxLines,
    );
  }

  /// 听能管理/听觉能力的文字填空（careTools、reactionChange、听觉记忆…）→ domainHearingMgmt。
  Widget _hm(String label, String key, {int maxLines = 1, String hint = ''}) =>
      _domainText(label, key, maxLines: maxLines, hint: hint);

  /// 语言能力的文字填空（模仿复述长度与例句、平均语言年龄水平、SIR…）→ domainLanguage。
  Widget _lang(String label, String key, {int maxLines = 1, String hint = ''}) =>
      _domainText(label, key,
          get: () => _draft.domainLanguage,
          set: (m) => _draft = _draft.copyWith(domainLanguage: m),
          maxLines: maxLines, hint: hint);

  /// 沟通能力的说明填空（眼神交流/主动提问/主动互动/维持话题/其他表达方式…）→ domainCommunication。
  ///
  /// 纸表这几行是「□无 □有 ______」，导出端 HearingExportService 会把
  /// `*Note` / `expressModeOther` 叠到下划线上。网页端一直有这些输入框，
  /// App 端此前**没有** —— 老师用 App 就填不了，PDF 上自然一直空着。
  ///
  /// ⚠「开启话题」纸表**没有**说明横线，openTopicNote 不导出（保留作内部备注）。
  Widget _cm(String label, String key, {int maxLines = 1, String hint = ''}) =>
      _domainText(label, key,
          get: () => _draft.domainCommunication,
          set: (m) => _draft = _draft.copyWith(domainCommunication: m),
          maxLines: maxLines, hint: hint);

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
    // ⚠ 频点 key 用**纯数字**（'250'/'1000'…）：后端 HearingExportService.aidedVal
    //   用 String.valueOf(freq) 取键。早期这里写的是 '250Hz'/'1kHz' 形态，
    //   于是 App 填的助听听阈在导出 PDF 里**读不到**（网页端写的是纯数字，一直正常）。
    //   保存一律写数字键；读取按索引回退兼容旧键，避免历史数据丢失。
    final at = _draft.aidedThresholds ?? <String, dynamic>{};
    // ✅ 修复：这些格子原本只有 onSaved 空函数、没有 onChanged，且本页是
    // PageView 分 part，翻走该 part 时格子被销毁——保存时值根本没写回 _draft，
    // 老师填的助听听阈「保存不上」。改为 onChanged 即时写回
    // _draft.aidedThresholds[ear][freq]。
    void setAided(String ear, String freq, String v) {
      final next = Map<String, dynamic>.from(_draft.aidedThresholds ?? {});
      final earMap = Map<String, dynamic>.from((next[ear] as Map?) ?? {});
      final val = v.trim();
      if (val.isEmpty) {
        earMap.remove(freq);
      } else {
        earMap[freq] = val;
      }
      next[ear] = earMap;
      setState(() => _draft = _draft.copyWith(aidedThresholds: next));
    }

    Widget cell(String ear, int i) {
      final earMap = (at[ear] as Map?) ?? const <String, dynamic>{};
      final init = (earMap[_aidedKeys[i]] ?? earMap[_aidedLegacyKeys[i]] ?? '').toString();
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: TextFormField(
            initialValue: init,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              border: UnderlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(vertical: 8),
            ),
            onChanged: (v) => setAided(ear, _aidedKeys[i], v),
          ),
        ),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('助听听阈', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      const SizedBox(height: 6),
      Row(children: [
        const SizedBox(width: 50, child: Text('')),
        for (int i = 0; i < _aidedKeys.length; i++)
          Expanded(child: Center(child: Text(_aidedLabels[i],
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)))),
      ]),
      Row(children: [
        const SizedBox(width: 50, child: Text('左耳 dB(HL)', style: const TextStyle(fontSize: 12))),
        for (int i = 0; i < _aidedKeys.length; i++) cell('left', i),
      ]),
      Row(children: [
        const SizedBox(width: 50, child: Text('右耳 dB(HL)', style: const TextStyle(fontSize: 12))),
        for (int i = 0; i < _aidedKeys.length; i++) cell('right', i),
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
          onPageChanged: (int i) => setState(() => _pageIdx = i),
          children: [
            _buildPart1Basic(),
            _buildPart2Eval(),
            _buildPart3Advice(),
          ])),
        SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
            // 翻页条**钉在底部**、不随内容滚动：原来它挂在每部分 ListView 的
            // 第一个子项（即内容顶部），「评估内容」一页几十个字段，滑到底就得
            // 滚回顶部才能翻页 —— 用户直接卡住。
            PartNavBar(
              index: _pageIdx,
              count: _partNames.length,
              onPrev: _pageIdx > 0 ? () => _goPage(_pageIdx - 1) : null,
              onNext: _pageIdx < _partNames.length - 1
                  ? () => _goPage(_pageIdx + 1) : null,
              nextLabel: _pageIdx < _partNames.length - 1
                  ? '下一部分：${_partNames[_pageIdx + 1]} →' : null,
            ),
            const SizedBox(height: 8),
            FilledButton.icon(onPressed: _save,
              icon: const Icon(Icons.save, size: 18), label: const Text('保存首次评估')),
          ]),
        )),
      ])),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      // 修复前：静默 return，点了保存毫无反应，用户以为「保存不上」。
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('有必填项未通过校验，请检查标红的字段'),
        backgroundColor: Colors.orange));
      return;
    }
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
    _sectionTitle('三、家庭资料'),
    _sub('父亲'),
    // 纸表家庭资料列：姓名 / 民族 / 身份证号 / 受教育程度 / 职业 / 联系方式
    // （原「年龄」不在纸表上，已移除；历史 JSON 里残留的 age 键不显示也不清除）
    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: _tf('姓名', _parent('father', 'name'), (v) => _setParent('father', 'name', v))),
      Expanded(child: _tf('民族', _parent('father', 'ethnicity'), (v) => _setParent('father', 'ethnicity', v))),
    ]),
    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: _tf('身份证号', _parent('father', 'idNumber'), (v) => _setParent('father', 'idNumber', v))),
      Expanded(child: _dd('受教育程度', _parent('father', 'education'), (v) => _setParent('father', 'education', v ?? ''), _eduLevels)),
    ]),
    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: _tf('职业', _parent('father', 'occupation'), (v) => _setParent('father', 'occupation', v))),
      Expanded(child: _tf('联系方式', _parent('father', 'contact'), (v) => _setParent('father', 'contact', v))),
    ]),
    _sub('母亲'),
    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: _tf('姓名', _parent('mother', 'name'), (v) => _setParent('mother', 'name', v))),
      Expanded(child: _tf('民族', _parent('mother', 'ethnicity'), (v) => _setParent('mother', 'ethnicity', v))),
    ]),
    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: _tf('身份证号', _parent('mother', 'idNumber'), (v) => _setParent('mother', 'idNumber', v))),
      Expanded(child: _dd('受教育程度', _parent('mother', 'education'), (v) => _setParent('mother', 'education', v ?? ''), _eduLevels)),
    ]),
    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: _tf('职业', _parent('mother', 'occupation'), (v) => _setParent('mother', 'occupation', v))),
      Expanded(child: _tf('联系方式', _parent('mother', 'contact'), (v) => _setParent('mother', 'contact', v))),
    ]),
    _sub('家庭情况'),
    // 纸表 1.1.1 上「家庭状况」是 5 个 □（可多选，如「单亲 + 父」＝单亲随父），
    // 不是下拉单选。仍存 family_status 一列，多选以顿号连接。
    _familyStatusCb(),
    _inputLangCb(),
    _dd('家庭语言环境', _draft.familyLangEnv, (v) => _draft = _draft.copyWith(familyLangEnv: v ?? ''), _familyLangEnvs),
    _dd('主要照顾者', _draft.caregiver, (v) => _draft = _draft.copyWith(caregiver: v ?? ''), _caregivers),
    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: _tf('照顾者与儿童关系', _draft.caregiverRelation, (v) => _draft = _draft.copyWith(caregiverRelation: v))),
      Expanded(child: _tf('照顾者联系方式', _draft.caregiverContact, (v) => _draft = _draft.copyWith(caregiverContact: v))),
    ]),
    _tf('现居住地址', _draft.homeAddress, (v) => _draft = _draft.copyWith(homeAddress: v), maxLines: 2),
    // 纸表「家庭资料」到「现居住地家庭地址」为止。原先挂在这里的
    // 综合建议 / 评估者姓名 / 评估日期与 Part 3 重复，已移除；
    // 「康复意识 / 配合程度」属家长受训范畴，已并入 Part 2 的家长受训领域。
  ]);

  // ═══ Part 2 — 评估内容（从原 _FirstEvalTabState 复制，checkbox 用修复版）═══
  Widget _buildPart2Eval() => ListView(padding: const EdgeInsets.all(16), children: [
    _sectionTitle('听能管理'),
    _cbRow('确定家长了解保养及检查助听设备程序', ['是', '否'], _draft.domainHearingMgmt, 'deviceCareProgram'),
    _cbRow('除睡觉及洗澡、游泳外是否都给儿童配戴助听设备', ['是', '否'], _draft.domainHearingMgmt, 'alwaysWear'),
    _cbRow('家中听觉环境', ['安静', '有噪音'], _draft.domainHearingMgmt, 'homeEnv'),
    _cbRow('幼儿的听觉习惯', ['完全聆听', '依赖视觉', '两者都有'], _draft.domainHearingMgmt, 'hearingHabit'),
    // 纸表第 1 页「听能管理」最后两行是**填空**，原先只放了两个静态 Text 标题，
    // 没有输入框 → domainHearingMgmt 里永远没有 careTools / reactionChange，
    // 导出 PDF 也就无从落笔。补成真正的输入项。
    _hm('已有助听设备保养工具', 'careTools'),
    _hm('配戴助听设备后幼儿对声音的反应有何改变？', 'reactionChange', maxLines: 2),
    _sectionTitle('听觉能力'),
    const Text('环境声音反应', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
    _cbRow('幼儿对环境声音的反应', ['无反应', '察觉', '辨识'], _draft.domainHearingMgmt, 'envReaction'),
    _cbRow('幼儿对语音的反应', ['无反应', '察觉', '辨识'], _draft.domainHearingMgmt, 'voiceReaction'),
    _cbRow('幼儿对名字、家人称谓的反应', ['无反应', '察觉', '辨识'], _draft.domainHearingMgmt, 'nameReaction'),
    // 纸表第 2 页第 4 行**没有**复选框（结果记在紧随其后的「林氏六音」表格里），
    // 导出端有意不写这一项；保留输入是作总体判断/内部沟通用。六音明细见 _lingTable()。
    _cbRow('幼儿对林氏(Ling\'s)六音的反应（纸表无此栏，不导出）', ['无反应', '察觉', '辨识'], _draft.domainHearingMgmt, 'lingReaction'),
    const Text('林氏(Ling\'s)六音反应（点击单元格选择符号）', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
    _lingTable(context),
    // 纸表「听觉能力」末尾的评估标准栏。原先 App 连输入框都没有（只读页读的又是
    // 另一套不存在的 key），导出 PDF 自然也写不出东西。键名与
    // HearingExportService.overlayFirstEval 第 2 页那段一一对应。
    _hm('听觉记忆（项）', 'auditoryMemCount'),
    _hm('听觉记忆组合类型', 'auditoryMemType'),
    _hm('听觉描述·闭合式第几阶段', 'auditoryDescClosed'),
    _hm('听觉描述·开放式第几阶段', 'auditoryDescOpen'),
    _hm('言语识别平均得分', 'speechIdentifyScore'),
    _hm('CAP 听觉行为分级（级别）', 'capLevel'),
    _sectionTitle('语言能力'),
    const Text('沟通模式', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
    _cbRow('沟通模式', ['非口语', '口语'], _draft.domainLanguage, 'commMode'),
    _dd('主要沟通模式', _draft.commMode, (v) => _draft = _draft.copyWith(commMode: v ?? ''), _commModes),
    const Text('理解性语言程度', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
    _cbRow('理解能力', ['无', '初级词汇', '中级词汇', '高级词汇'], _draft.domainLanguage, 'understandingLevel'),
    const Text('表达性语言程度', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
    _cbRow('无', ['无'], _draft.domainLanguage, 'expressingNone'),
    _cbRow('模仿复述', ['有'], _draft.domainLanguage, 'expressingImitate'),
    // 纸表「模仿复述（句子长度__个字，例如____）」这一行的两个填空
    _lang('模仿复述·句子长度', 'imitateLength', hint: '如 1~2 个字'),
    _lang('模仿复述·例如', 'imitateExample'),
    _cbRow('主动表达', ['有'], _draft.domainLanguage, 'expressingActive'),
    _lang('主动表达·句子长度', 'activeLength', hint: '如 7~9 个字'),
    _lang('主动表达·例如', 'activeExample'),
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
    // 纸表「语言能力」评估标准栏：平均语言年龄水平 / SIR 言语可懂度分级（导出会写）
    _lang('问句能力说明', 'questionNote', maxLines: 2),
    _lang('平均语言年龄水平', 'avgLanguageAge'),
    _lang('SIR 言语可懂度分级（级别）', 'sirLevel'),
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
    _cbRow('眼神交流', ['无', '有'], _draft.domainCommunication, 'eyeContact'),
    _cbRow('主动提问', ['无', '有'], _draft.domainCommunication, 'activeQuestion'),
    _cbRow('主动互动', ['无', '有'], _draft.domainCommunication, 'activeInteraction'),
    _cbRow('维持话题', ['无', '有'], _draft.domainCommunication, 'maintainTopic'),
    _cbRow('开启话题', ['无', '有'], _draft.domainCommunication, 'openTopic'),
    // 与纸表下划线一一对应的说明（导出端会叠在「有 ______」的线上）
    _cm('眼神交流说明', 'eyeContactNote'),
    _cm('主动提问说明', 'activeQuestionNote'),
    _cm('主动互动说明', 'activeInteractionNote'),
    _cm('维持话题说明', 'maintainTopicNote'),
    // 纸表「开启话题：□无 □有」后面没有横线，此项无处落纸，仅作内部备注
    _cm('开启话题说明（纸表无此栏，仅内部备注）', 'openTopicNote'),
    _cm('其他表达需求方式', 'expressModeOther'),
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
    // 由 Part 1「家庭资料」移来：属家长受训/配合范畴，纸表上无对应勾选行。
    _dd('康复意识', _draft.familyAwareness, (v) => _draft = _draft.copyWith(familyAwareness: v ?? ''), _awarenessLevels),
    _dd('配合程度', _draft.familyCooperation, (v) => _draft = _draft.copyWith(familyCooperation: v ?? ''), _coopLevels),
  ]);

  // ═══ Part 3 — 综合建议 ═══
  Widget _buildPart3Advice() => ListView(padding: const EdgeInsets.all(16), children: [
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

/// 持续评估页顶部的「历史记录」入口。
///
/// 老师从儿童中枢页的「持续评估」卡片进来时直接是填写新表，之前表现是看不到历史、
/// 也无从修改以前的记录（历史只在「档案详情 → 持续评估 Tab」里）。这里给出明确入口，
/// 点进去落在档案详情页的「持续评估」Tab——那里是完整历史，可查看、导出 PDF、逐条编辑。
class _ContEvalHistoryBanner extends ConsumerWidget {
  const _ContEvalHistoryBanner({required this.archiveId});
  final String archiveId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<RehabContEval> list =
        ref.watch(rehabArchiveDetailProvider(archiveId)).detail?.contEvals ??
            const <RehabContEval>[];
    // 还没填过就没有历史可看，不占位置。
    if (list.isEmpty) return const SizedBox.shrink();
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final int done =
        list.where((RehabContEval e) => e.status == ContEvalStatus.done).length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Material(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => context.push('/rehab/$archiveId?tab=cont'),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(children: <Widget>[
              Icon(Icons.history, size: 20, color: colors.onPrimaryContainer),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('历史持续评估（${list.length} 次）',
                          style: text.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: colors.onPrimaryContainer)),
                      const SizedBox(height: 2),
                      Text('已完成 $done 次 · 点这里查看或修改以前的记录',
                          style: text.bodySmall
                              ?.copyWith(color: colors.onPrimaryContainer)),
                    ]),
              ),
              Icon(Icons.chevron_right, color: colors.onPrimaryContainer),
            ]),
          ),
        ),
      ),
    );
  }
}

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

  /// 纸表 1.1.2 各 JSON 域的**可变**草稿（domain → {key: 1..4}）。
  ///
  /// 表单按目录 data/cont_eval_catalog.dart 渲染，直接改这里的 Map，
  /// 保存时再整体回写到 _draft（见 _syncMapsToDraft）——避免每点一格就 copyWith 37 个域。
  late final Map<String, Map<String, dynamic>> _maps;

  /// 是否编辑已有记录（决定保存走 PUT 还是 POST）。
  bool _isEditing = false;

  /// 当前停留在第几部分（只用于 AppBar 的页码提示）。
  int _pageIdx = 0;

  /// 纸表页数（目录里的页数）+ 首页（基本资料）+ 末页（总结）。
  int get _partCount => contEvalCatalog.length + 2;

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
    // ② 每个域取一份可变副本；域为 null 时补空 Map，否则勾选无处可写（旧实现曾因此丢数据）。
    _maps = <String, Map<String, dynamic>>{
      for (final String d in contEvalDomains)
        d: Map<String, dynamic>.from(
            _draft.domainMapOf(d) ?? const <String, dynamic>{}),
    };
    _autoFillFromFirstEval();
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

  /// 把目录表单改过的所有域回写到草稿（保存前调用）。
  void _syncMapsToDraft() {
    RehabContEval d = _draft;
    for (final MapEntry<String, Map<String, dynamic>> e in _maps.entries) {
      d = d.withDomain(e.key, e.value);
    }
    _draft = d;
  }

  /// 已填符号数 / 总符号数（进度提示用）。
  (int, int) _progress() {
    int n = 0;
    for (final ContPage p in contEvalCatalog) {
      for (final ContSection s in p.sections) {
        if (s.domain == ContEvalCatalogPageView.topLevelDomain) continue;
        final List<(String, List<ContItem>)> pairs = <(String, List<ContItem>)>[];
        if (s.rows != null && s.rows!.isNotEmpty) {
          for (final ContRow r in s.rows!) {
            pairs.add((r.domain ?? s.domain ?? '', r.items));
          }
        } else if (s.cells != null && s.cells!.isNotEmpty) {
          pairs.add((s.domain ?? '', s.cells!.expand((List<ContItem> x) => x).toList()));
        } else {
          pairs.add((s.domain ?? '', s.items ?? const <ContItem>[]));
        }
        for (final (String d, List<ContItem> items) in pairs) {
          final Map<String, dynamic>? m = _maps[d];
          if (m == null) continue;
          for (final ContItem it in items) {
            final dynamic v = m[it.key];
            if (v != null && v.toString().isNotEmpty) n++;
          }
        }
      }
    }
    return (n, contEvalSymCount);
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
          // 输入即时写回草稿：本页是 PageView 分 part，翻走的 part 会被销毁、
          // 其 FormField 从 Form 注销，只靠 onSaved 会导致「翻页后再保存，前面 part 填的内容全丢」
          // （表现为持续评估「保存不上」）。
          onChanged: (v) => onSaved(v),
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
  /// 翻到第 i 部分。
  ///
  /// 注意：翻页条本身已换成共用的 [PartNavBar]（放在底部、不随内容滚动），
  /// 原来这里的 `_partNav(int idx)` 只挂在「基本资料」和「总结」两页上，
  /// 中间 7 个目录页**一个翻页入口都没有** —— 老师填完第 1 页就卡死出不去。
  void _goPage(int i) {
    setState(() => _pageIdx = i);
    _pageController.animateToPage(i,
        duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  @override
  Widget build(BuildContext context) {
    final (int filled, int total) = _progress();
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing
            ? '编辑持续评估（第${_seqStr.isEmpty ? "?" : _seqStr}次）'
            : '新建持续评估'),
        leading: IconButton(
            icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
        // 纸表有 512 个符号格，不给进度提示老师根本不知道填到哪了。
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(22),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 6, left: 16, right: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                  '第 ${_pageIdx + 1}/$_partCount 部分 · 按纸表 1.1.2 逐项录入 · 符号已填 $filled / $total',
                  style: const TextStyle(fontSize: 11.5)),
            ),
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: Column(children: <Widget>[
          // 新建时给一个通往「历史持续评估」的入口：老师从中枢页「持续评估」卡片进来是直接填新表，
          // 看不到以前填过什么、也改不了。编辑模式下当前这条就是历史记录，不再重复提示。
          if (!_isEditing) _ContEvalHistoryBanner(archiveId: widget.archiveId),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (int i) => setState(() => _pageIdx = i),
              children: <Widget>[
                _buildBasicPage(),
                // 纸表 7 页：条目与顺序完全由目录驱动（勿手写字段清单，手写必漏项）。
                for (final ContPage p in contEvalCatalog)
                  ContEvalCatalogPageView(
                    page: p,
                    maps: _maps,
                    onChanged: () => setState(() {}),
                  ),
                _buildSummaryPage(),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
                // 翻页条钉在底部（纸表 7 页每页都是长列表，放在内容开头等于没有）。
                PartNavBar(
                  index: _pageIdx,
                  count: _partCount,
                  onPrev: _pageIdx > 0 ? () => _goPage(_pageIdx - 1) : null,
                  onNext: _pageIdx < _partCount - 1
                      ? () => _goPage(_pageIdx + 1) : null,
                  nextLabel: _pageIdx == _partCount - 2
                      ? '下一部分：总结 →' : '下一部分 →',
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save, size: 18),
                  label: const Text('保存持续评估'),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      // 修复前：静默 return，点了保存毫无反应，用户以为「保存不上」。
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('有必填项未通过校验，请检查标红的字段'),
        backgroundColor: Colors.orange));
      return;
    }
    _formKey.currentState!.save();
    // 目录表单改的是 _maps，保存前必须整体回写到草稿，否则一页都存不上。
    _syncMapsToDraft();
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

  // ═══ 第 0 部分：基本资料（纸表首页，对应实体顶层列，不在目录里）═══
  Widget _buildBasicPage() {
    final detail = ref.watch(rehabArchiveDetailProvider(widget.archiveId)).detail;
    final a = detail?.archive;
    final fe = detail?.firstEval;
    final comp = <String>[];
    if (fe != null) {
      if (fe.leftCompensationType.isNotEmpty) comp.add('左：${fe.leftCompensationType}');
      if (fe.rightCompensationType.isNotEmpty) comp.add('右：${fe.rightCompensationType}');
    }
    return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 8), children: [
      _sectionTitle('基本资料'),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(flex: 2, child: _tf('姓名', a?.childName ?? '', (v) {})),
        Expanded(child: _dd('性别', fe?.gender ?? '', (v) {}, ['男', '女'])),
      ]),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: _tf('生理年龄', _draft.physiologicalAge,
            (v) => _draft = _draft.copyWith(physiologicalAge: v))),
        Expanded(child: _tf('听觉年龄', _draft.hearingAge,
            (v) => _draft = _draft.copyWith(hearingAge: v))),
      ]),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: _df('第一次评估时间', _draft.evalTime1,
            (d) => _draft = _draft.copyWith(evalTime1: d))),
        Expanded(child: _df('第二次评估时间', _draft.evalTime2,
            (d) => _draft = _draft.copyWith(evalTime2: d))),
        Expanded(child: _df('第三次评估时间', _draft.evalTime3,
            (d) => _draft = _draft.copyWith(evalTime3: d))),
      ]),
      _sectionTitle('本次评估信息'),
      _tf('评估序号', _seqStr, (v) => _seqStr = v, keyboard: TextInputType.number),
      _df('评估时间', _draft.evalDate, (d) => _draft = _draft.copyWith(evalDate: d)),
      _tf('评估者姓名', _draft.evaluatorName,
          (v) => _draft = _draft.copyWith(evaluatorName: v)),
      if (comp.isNotEmpty) ...[
        const SizedBox(height: 6),
        Text('补偿/重建方式：${comp.join(" / ")}',
            style: const TextStyle(fontSize: 13, color: Colors.black87)),
      ],
    ]);
  }

  // ═══ 最后一部分：总结（教师评语 / 家长表现备注）═══
  Widget _buildSummaryPage() => ListView(padding: const EdgeInsets.all(16), children: [
    _sectionTitle('总结'),
    _tf('教师评语', _draft.teacherNotes,
        (v) => _draft = _draft.copyWith(teacherNotes: v), maxLines: 4),
    _tf('家长表现备注', _draft.parentPerformance,
        (v) => _draft = _draft.copyWith(parentPerformance: v), maxLines: 3),
  ]);
}
