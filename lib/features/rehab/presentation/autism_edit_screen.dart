import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:teacher_app/data/models/autism_archive.dart';
import 'package:teacher_app/features/rehab/provider/autism_provider.dart';

/// 孤独症档案各类文档的统一编辑页。
/// [doc] 取值：first-eval / cont-eval / semester-plan / monthly-plan /
/// lesson-plan / family-guide / effect-record；[docId] 非空表示编辑已有记录。
class AutismEditScreen extends ConsumerStatefulWidget {
  const AutismEditScreen({
    required this.archiveId,
    required this.doc,
    this.docId,
    super.key,
  });
  final String archiveId;
  final String doc;
  final String? docId;

  @override
  ConsumerState<AutismEditScreen> createState() => _AutismEditScreenState();
}

class _AutismEditScreenState extends ConsumerState<AutismEditScreen> {
  final Map<String, TextEditingController> _c = <String, TextEditingController>{};
  final Map<String, DateTime?> _dates = <String, DateTime?>{};
  final Map<String, String> _init = <String, String>{};
  final Map<String, DateTime?> _dateInit = <String, DateTime?>{};
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _saving = false;
  String? _halfMonth;

  @override
  void initState() {
    super.initState();
    _preload();
  }

  void _preload() {
    final AutismArchiveDetail? detail =
        ref.read(autismArchiveDetailProvider(widget.archiveId)).detail;
    if (detail == null || widget.docId == null) return;
    switch (widget.doc) {
      case 'first-eval':
        final e = detail.firstEval;
        if (e != null) _fillFirstEval(e);
        break;
      case 'cont-eval':
        final e = detail.contEvals.where((x) => x.id == widget.docId).firstOrNull;
        if (e != null) _fillContEval(e);
        break;
      case 'semester-plan':
        final e =
            detail.semesterPlans.where((x) => x.id == widget.docId).firstOrNull;
        if (e != null) _fillSemester(e);
        break;
      case 'monthly-plan':
        final e =
            detail.monthlyPlans.where((x) => x.id == widget.docId).firstOrNull;
        if (e != null) _fillMonthly(e);
        break;
      case 'lesson-plan':
        final e =
            detail.lessonPlans.where((x) => x.id == widget.docId).firstOrNull;
        if (e != null) _fillLesson(e);
        break;
      case 'family-guide':
        final e =
            detail.familyGuides.where((x) => x.id == widget.docId).firstOrNull;
        if (e != null) _fillFamily(e);
        break;
      case 'effect-record':
        final e =
            detail.effectRecords.where((x) => x.id == widget.docId).firstOrNull;
        if (e != null) _fillEffect(e);
        break;
    }
  }

  void _set(String key, String v) => _init[key] = v;
  void _setD(String key, DateTime? v) => _dateInit[key] = v;

  void _fillFirstEval(AutismFirstEval e) {
    _set('name', e.name); _set('gender', e.gender);
    _setD('birthDate', e.birthDate);
    _set('clinicalDiagnosis', e.clinicalDiagnosis);
    _setD('diagnosisDate', e.diagnosisDate);
    _set('diagnosisHospital', e.diagnosisHospital);
    _setD('enrollmentDate', e.enrollmentDate);
    _set('className', e.className);
    _set('idNumber', e.idNumber); _set('ethnicity', e.ethnicity);
    _set('hukouLocation', e.hukouLocation); _set('homeAddress', e.homeAddress);
    _set('familyPhone', e.familyPhone); _set('guardianName', e.guardianName);
    _set('guardianRelation', e.guardianRelation);
    _set('disabilityCertNo', e.disabilityCertNo);
    _set('familyData', e.familyData); _set('selfStatus', e.selfStatus);
    _set('domainPerception', e.domainPerception);
    _set('domainGrossMotor', e.domainGrossMotor);
    _set('domainFineMotor', e.domainFineMotor);
    _set('domainLanguageComm', e.domainLanguageComm);
    _set('domainCognition', e.domainCognition);
    _set('domainSocial', e.domainSocial);
    _set('domainSelfCare', e.domainSelfCare);
    _set('domainEmotionBehavior', e.domainEmotionBehavior);
    _set('evalCountJson', e.evalCountJson);
    _set('iepPlanner', e.iepPlanner);
    _setD('iepStartDate', e.iepStartDate);
    _setD('iepEndDate', e.iepEndDate);
    _set('iepDomainSensory', e.iepDomainSensory);
    _set('iepDomainGross', e.iepDomainGross);
    _set('iepDomainFine', e.iepDomainFine);
    _set('iepDomainLanguage', e.iepDomainLanguage);
    _set('iepDomainCognition', e.iepDomainCognition);
    _set('iepDomainSocial', e.iepDomainSocial);
    _set('iepDomainSelfcare', e.iepDomainSelfcare);
    _set('iepDomainEmotion', e.iepDomainEmotion);
    _setD('evalDate', e.evalDate);
    _set('evaluatorName', e.evaluatorName);
    _set('physiologicalAge', e.physiologicalAge);
    _set('developmentalAge', e.developmentalAge);
  }

  void _fillContEval(AutismContEval e) {
    _set('evalSeq', e.evalSeq?.toString() ?? '');
    _setD('evalDate', e.evalDate); _setD('dueDate', e.dueDate);
    _set('physiologicalAge', e.physiologicalAge);
    _set('developmentalAge', e.developmentalAge);
    _set('domainPerception', e.domainPerception);
    _set('domainGrossMotor', e.domainGrossMotor);
    _set('domainFineMotor', e.domainFineMotor);
    _set('domainLanguageComm', e.domainLanguageComm);
    _set('domainCognition', e.domainCognition);
    _set('domainSocial', e.domainSocial);
    _set('domainSelfCare', e.domainSelfCare);
    _set('domainEmotionBehavior', e.domainEmotionBehavior);
    _set('effectSummary', e.effectSummary);
    _set('parentPerformance', e.parentPerformance);
    _set('teacherNotes', e.teacherNotes);
    _set('evaluatorName', e.evaluatorName);
  }

  void _fillSemester(AutismSemesterPlan e) {
    _set('planNo', e.planNo);
    _set('seqNo', e.seqNo?.toString() ?? '');
    _setD('periodStart', e.periodStart); _setD('periodEnd', e.periodEnd);
    _set('childName', e.childName); _set('className', e.className);
    _set('goalSensory', e.goalSensory); _set('teacherSensory', e.teacherSensory);
    _set('goalFine', e.goalFine); _set('teacherFine', e.teacherFine);
    _set('goalGroup', e.goalGroup); _set('teacherGroup', e.teacherGroup);
    _set('goalCognition', e.goalCognition);
    _set('teacherCognition', e.teacherCognition);
    _set('goalLife', e.goalLife); _set('teacherLife', e.teacherLife);
    _set('goalMusic', e.goalMusic); _set('teacherMusic', e.teacherMusic);
    _set('unitThemes', e.unitThemes);
  }

  void _fillMonthly(AutismMonthlyPlan e) {
    _setD('planMonth', e.planMonth); _set('monthLabel', e.monthLabel);
    _set('theme', e.theme); _set('childName', e.childName);
    _set('className', e.className);
    _set('sensoryGoal', e.sensoryGoal); _set('sensoryWeek1', e.sensoryWeek1);
    _set('sensoryWeek2', e.sensoryWeek2); _set('sensoryWeek3', e.sensoryWeek3);
    _set('sensoryWeek4', e.sensoryWeek4); _set('teacherSensory', e.teacherSensory);
    _set('fineGoal', e.fineGoal); _set('fineWeek1', e.fineWeek1);
    _set('fineWeek2', e.fineWeek2); _set('fineWeek3', e.fineWeek3);
    _set('fineWeek4', e.fineWeek4); _set('teacherFine', e.teacherFine);
    _set('groupGoal', e.groupGoal); _set('groupWeek1', e.groupWeek1);
    _set('groupWeek2', e.groupWeek2); _set('groupWeek3', e.groupWeek3);
    _set('groupWeek4', e.groupWeek4); _set('teacherGroup', e.teacherGroup);
    _set('cognitionGoal', e.cognitionGoal); _set('cognitionWeek1', e.cognitionWeek1);
    _set('cognitionWeek2', e.cognitionWeek2); _set('cognitionWeek3', e.cognitionWeek3);
    _set('cognitionWeek4', e.cognitionWeek4); _set('teacherCognition', e.teacherCognition);
    _set('lifeGoal', e.lifeGoal); _set('lifeWeek1', e.lifeWeek1);
    _set('lifeWeek2', e.lifeWeek2); _set('lifeWeek3', e.lifeWeek3);
    _set('lifeWeek4', e.lifeWeek4); _set('teacherLife', e.teacherLife);
    _set('musicGoal', e.musicGoal); _set('musicWeek1', e.musicWeek1);
    _set('musicWeek2', e.musicWeek2); _set('musicWeek3', e.musicWeek3);
    _set('musicWeek4', e.musicWeek4); _set('teacherMusic', e.teacherMusic);
    _set('parentSignature', e.parentSignature);
  }

  void _fillLesson(AutismLessonPlan e) {
    _setD('planMonth', e.planMonth); _set('halfMonth', e.halfMonth);
    _set('courseDomain', e.courseDomain); _set('unitTheme', e.unitTheme);
    _set('lessonTitle', e.lessonTitle); _set('teacher', e.teacher);
    _set('classGroup', e.classGroup);
    _setD('teachingDateStart', e.teachingDateStart);
    _setD('teachingDateEnd', e.teachingDateEnd);
    _set('teachingForm', e.teachingForm);
    _set('obstacleTypeDegree', e.obstacleTypeDegree);
    _set('cognitiveLevel', e.cognitiveLevel); _set('currentAbility', e.currentAbility);
    _set('knowledgeGoal', e.knowledgeGoal); _set('abilityGoal', e.abilityGoal);
    _set('emotionGoal', e.emotionGoal); _set('keyPoints', e.keyPoints);
    _set('difficultPoints', e.difficultPoints); _set('preparation', e.preparation);
    _set('introduction', e.introduction); _set('process', e.process);
    _set('summary', e.summary); _set('extension', e.extension);
    _set('learningAttitude', e.learningAttitude);
    _set('learningEffect', e.learningEffect);
    _set('existingProblems', e.existingProblems);
    _set('teachingSuggestion', e.teachingSuggestion);
    _set('parentSignature', e.parentSignature);
  }

  void _fillFamily(AutismFamilyGuide e) {
    _setD('weekStart', e.weekStart); _setD('weekEnd', e.weekEnd);
    _set('weekLabel', e.weekLabel); _set('childName', e.childName);
    _set('courseName', e.courseName); _set('teacher', e.teacher);
    _set('guideTarget', e.guideTarget); _set('homework', e.homework);
    _set('completionStatus', e.completionStatus);
    _set('parentFeedback', e.parentFeedback);
    _set('teacherComment', e.teacherComment);
    _set('parentSignature', e.parentSignature);
  }

  void _fillEffect(AutismEffectRecord e) {
    _set('recordYear', e.recordYear?.toString() ?? '');
    _set('orgName', e.orgName); _set('childName', e.childName);
    _set('gender', e.gender); _setD('birthDate', e.birthDate);
    _set('fillPerson', e.fillPerson); _set('reviewer', e.reviewer);
    _setD('fillDate', e.fillDate);
    _setD('trainingStart', e.trainingStart); _setD('trainingEnd', e.trainingEnd);
    _set('effectStats', e.effectStats); _set('effectiveRate', e.effectiveRate);
    _set('parentTrainingCount', e.parentTrainingCount?.toString() ?? '');
    _set('satisfaction', e.satisfaction); _set('trainingOutcome', e.trainingOutcome);
    _set('guardianSignature', e.guardianSignature);
  }

  TextEditingController _tc(String key) =>
      _c.putIfAbsent(key, () => TextEditingController(text: _init[key] ?? ''));
  String _v(String key) => _tc(key).text;
  int? _vi(String key) {
    final String s = _v(key).trim();
    return s.isEmpty ? null : int.tryParse(s);
  }

  DateTime? _date(String key) =>
      _dates.putIfAbsent(key, () => _dateInit[key]);

  Widget _tf(String key, String label, {int maxLines = 1}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: TextFormField(
          controller: _tc(key),
          maxLines: maxLines,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
        ),
      );

  Widget _df(String key, String label) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: InkWell(
          onTap: () async {
            final DateTime? picked = await showDatePicker(
              context: context,
              initialDate: _date(key) ?? DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime(2035),
            );
            if (picked != null) setState(() => _dates[key] = picked);
          },
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: label,
              border: const OutlineInputBorder(),
              isDense: true,
              suffixIcon: const Icon(Icons.calendar_today, size: 18),
            ),
            child: Text(
              _date(key) == null
                  ? '选择日期'
                  : DateFormat('yyyy-MM-dd').format(_date(key)!),
            ),
          ),
        ),
      );

  Widget _section(String title, List<Widget> children) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
            child: Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 15)),
          ),
          ...children,
        ],
      );

  String get _docTitle {
    switch (widget.doc) {
      case 'first-eval': return '入学评估 + IEP';
      case 'cont-eval': return '持续评估';
      case 'semester-plan': return '学期教学计划';
      case 'monthly-plan': return '月教学计划';
      case 'lesson-plan': return '月份教育教案';
      case 'family-guide': return '家庭康复指导';
      case 'effect-record': return '年度康复效果登记';
      default: return '编辑';
    }
  }

  List<Widget> _buildFields() {
    switch (widget.doc) {
      case 'first-eval':
        return <Widget>[
          _section('基础信息', <Widget>[
            _tf('name', '姓名'), _tf('gender', '性别'),
            _df('birthDate', '出生日期'),
            _tf('clinicalDiagnosis', '临床诊断'),
            _df('diagnosisDate', '诊断日期'),
            _tf('diagnosisHospital', '诊断医院'),
            _df('enrollmentDate', '入学日期'),
            _tf('className', '班级'), _tf('idNumber', '身份证号'),
            _tf('ethnicity', '民族'), _tf('hukouLocation', '户籍地'),
            _tf('homeAddress', '家庭住址'), _tf('familyPhone', '联系电话'),
            _tf('guardianName', '监护人'), _tf('guardianRelation', '与儿童关系'),
            _tf('disabilityCertNo', '残疾证号'),
          ]),
          _section('家庭/自身状况（JSON 或文本）', <Widget>[
            _tf('familyData', '家庭情况', maxLines: 3),
            _tf('selfStatus', '儿童自身状况', maxLines: 3),
          ]),
          _section('八大领域评估', <Widget>[
            _tf('domainPerception', '感知觉', maxLines: 2),
            _tf('domainGrossMotor', '粗大动作', maxLines: 2),
            _tf('domainFineMotor', '精细动作', maxLines: 2),
            _tf('domainLanguageComm', '语言与沟通', maxLines: 2),
            _tf('domainCognition', '认知', maxLines: 2),
            _tf('domainSocial', '社会交往', maxLines: 2),
            _tf('domainSelfCare', '生活自理', maxLines: 2),
            _tf('domainEmotionBehavior', '情绪与行为', maxLines: 2),
            _tf('evalCountJson', '领域统计(JSON)', maxLines: 2),
          ]),
          _section('IEP 个别化教育计划', <Widget>[
            _tf('iepPlanner', '制定人'),
            _df('iepStartDate', 'IEP 开始'), _df('iepEndDate', 'IEP 结束'),
            _tf('iepDomainSensory', '感觉统合目标', maxLines: 2),
            _tf('iepDomainGross', '粗大动作目标', maxLines: 2),
            _tf('iepDomainFine', '精细动作目标', maxLines: 2),
            _tf('iepDomainLanguage', '语言沟通目标', maxLines: 2),
            _tf('iepDomainCognition', '认知目标', maxLines: 2),
            _tf('iepDomainSocial', '社会交往目标', maxLines: 2),
            _tf('iepDomainSelfcare', '生活自理目标', maxLines: 2),
            _tf('iepDomainEmotion', '情绪行为目标', maxLines: 2),
          ]),
          _section('评估信息', <Widget>[
            _df('evalDate', '评估日期'), _tf('evaluatorName', '评估人'),
            _tf('physiologicalAge', '生理年龄'),
            _tf('developmentalAge', '发展年龄'),
          ]),
        ];
      case 'cont-eval':
        return <Widget>[
          _tf('evalSeq', '评估次数(第几次)'),
          _df('evalDate', '评估日期'), _df('dueDate', '应完成日期'),
          _tf('physiologicalAge', '生理年龄'),
          _tf('developmentalAge', '发展年龄'),
          _section('八大领域', <Widget>[
            _tf('domainPerception', '感知觉', maxLines: 2),
            _tf('domainGrossMotor', '粗大动作', maxLines: 2),
            _tf('domainFineMotor', '精细动作', maxLines: 2),
            _tf('domainLanguageComm', '语言与沟通', maxLines: 2),
            _tf('domainCognition', '认知', maxLines: 2),
            _tf('domainSocial', '社会交往', maxLines: 2),
            _tf('domainSelfCare', '生活自理', maxLines: 2),
            _tf('domainEmotionBehavior', '情绪与行为', maxLines: 2),
          ]),
          _section('小结', <Widget>[
            _tf('effectSummary', '训练效果小结', maxLines: 3),
            _tf('parentPerformance', '家长表现', maxLines: 2),
            _tf('teacherNotes', '教师备注', maxLines: 2),
            _tf('evaluatorName', '评估人'),
          ]),
        ];
      case 'semester-plan':
        return <Widget>[
          _tf('seqNo', '学期序号'), _tf('planNo', '计划编号'),
          _df('periodStart', '周期开始'), _df('periodEnd', '周期结束'),
          _tf('childName', '儿童姓名'), _tf('className', '班级'),
          _section('六大领域教学总目标 + 任课教师', <Widget>[
            _tf('goalSensory', '感觉统合目标'), _tf('teacherSensory', '任课教师'),
            _tf('goalFine', '精细动作目标'), _tf('teacherFine', '任课教师'),
            _tf('goalGroup', '集体课/社交目标'), _tf('teacherGroup', '任课教师'),
            _tf('goalCognition', '认知目标'), _tf('teacherCognition', '任课教师'),
            _tf('goalLife', '生活自理目标'), _tf('teacherLife', '任课教师'),
            _tf('goalMusic', '音乐律动目标'), _tf('teacherMusic', '任课教师'),
          ]),
          _tf('unitThemes', '学期单元教学主题(JSON)', maxLines: 3),
        ];
      case 'monthly-plan':
        return <Widget>[
          _df('planMonth', '计划月份'), _tf('monthLabel', '月份标签(如 2026-08)'),
          _tf('theme', '月主题'), _tf('childName', '儿童姓名'),
          _tf('className', '班级'),
          _section('感觉统合', <Widget>[
            _tf('sensoryGoal', '目标'), _tf('sensoryWeek1', '第1周'),
            _tf('sensoryWeek2', '第2周'), _tf('sensoryWeek3', '第3周'),
            _tf('sensoryWeek4', '第4周'), _tf('teacherSensory', '任课教师'),
          ]),
          _section('精细动作', <Widget>[
            _tf('fineGoal', '目标'), _tf('fineWeek1', '第1周'),
            _tf('fineWeek2', '第2周'), _tf('fineWeek3', '第3周'),
            _tf('fineWeek4', '第4周'), _tf('teacherFine', '任课教师'),
          ]),
          _section('集体课', <Widget>[
            _tf('groupGoal', '目标'), _tf('groupWeek1', '第1周'),
            _tf('groupWeek2', '第2周'), _tf('groupWeek3', '第3周'),
            _tf('groupWeek4', '第4周'), _tf('teacherGroup', '任课教师'),
          ]),
          _section('认知', <Widget>[
            _tf('cognitionGoal', '目标'), _tf('cognitionWeek1', '第1周'),
            _tf('cognitionWeek2', '第2周'), _tf('cognitionWeek3', '第3周'),
            _tf('cognitionWeek4', '第4周'), _tf('teacherCognition', '任课教师'),
          ]),
          _section('生活自理', <Widget>[
            _tf('lifeGoal', '目标'), _tf('lifeWeek1', '第1周'),
            _tf('lifeWeek2', '第2周'), _tf('lifeWeek3', '第3周'),
            _tf('lifeWeek4', '第4周'), _tf('teacherLife', '任课教师'),
          ]),
          _section('音乐律动', <Widget>[
            _tf('musicGoal', '目标'), _tf('musicWeek1', '第1周'),
            _tf('musicWeek2', '第2周'), _tf('musicWeek3', '第3周'),
            _tf('musicWeek4', '第4周'), _tf('teacherMusic', '任课教师'),
          ]),
          _tf('parentSignature', '家长签字'),
        ];
      case 'lesson-plan':
        return <Widget>[
          _df('planMonth', '教案月份'),
          DropdownButtonFormField<String>(
            value: _halfMonth ?? (_v('halfMonth').isEmpty ? 'FIRST' : _v('halfMonth')),
            decoration: const InputDecoration(
              labelText: '上/下半月', border: OutlineInputBorder(), isDense: true),
            items: const <DropdownMenuItem<String>>[
              DropdownMenuItem(value: 'FIRST', child: Text('上半月')),
              DropdownMenuItem(value: 'SECOND', child: Text('下半月')),
            ],
            onChanged: (v) => setState(() => _halfMonth = v),
          ),
          _tf('courseDomain', '课程领域'),
          _tf('unitTheme', '单元主题'), _tf('lessonTitle', '教案名称'),
          _tf('teacher', '教师'), _tf('classGroup', '班级/小组'),
          _df('teachingDateStart', '教学开始'), _df('teachingDateEnd', '教学结束'),
          _tf('teachingForm', '教学形式(集体/小组/个别)'),
          _section('学生能力分析', <Widget>[
            _tf('obstacleTypeDegree', '障碍类型与程度'),
            _tf('cognitiveLevel', '认知水平'),
            _tf('currentAbility', '现有能力'),
          ]),
          _section('教学目标', <Widget>[
            _tf('knowledgeGoal', '认知目标'), _tf('abilityGoal', '能力目标'),
            _tf('emotionGoal', '情绪目标'), _tf('keyPoints', '重点'),
            _tf('difficultPoints', '难点'),
          ]),
          _section('教学过程', <Widget>[
            _tf('preparation', '教学准备', maxLines: 2),
            _tf('introduction', '导入', maxLines: 2),
            _tf('process', '过程', maxLines: 4),
            _tf('summary', '小结', maxLines: 2),
            _tf('extension', '延伸', maxLines: 2),
          ]),
          _section('教学评鉴', <Widget>[
            _tf('learningAttitude', '学习态度'),
            _tf('learningEffect', '学习效果'),
            _tf('existingProblems', '存在问题', maxLines: 2),
            _tf('teachingSuggestion', '教学建议', maxLines: 2),
            _tf('parentSignature', '家长签字'),
          ]),
        ];
      case 'family-guide':
        return <Widget>[
          _df('weekStart', '本周一'), _df('weekEnd', '本周日'),
          _tf('weekLabel', '周次标签(如 2026 年第 32 周)'),
          _tf('childName', '儿童姓名'), _tf('courseName', '课程名称'),
          _tf('teacher', '教师'),
          _tf('guideTarget', '本周家庭指导目标', maxLines: 3),
          _tf('homework', '家庭作业内容', maxLines: 3),
          _tf('completionStatus', '完成情况(全部/部分辅助/独立完成)'),
          _tf('parentFeedback', '家长反馈', maxLines: 2),
          _tf('teacherComment', '教师点评', maxLines: 2),
          _tf('parentSignature', '家长签字'),
        ];
      case 'effect-record':
        return <Widget>[
          _tf('recordYear', '年度(如 2026)'),
          _tf('orgName', '机构名称'), _tf('childName', '儿童姓名'),
          _tf('gender', '性别'), _df('birthDate', '出生日期'),
          _tf('fillPerson', '填表人'), _tf('reviewer', '审核人'),
          _df('fillDate', '填表日期'),
          _df('trainingStart', '受训开始'), _df('trainingEnd', '受训结束'),
          _tf('effectStats', '各维度三次评估统计(JSON)', maxLines: 3),
          _tf('effectiveRate', '有效率'),
          _tf('parentTrainingCount', '家长培训次数'),
          _tf('satisfaction', '满意度(非常满意/满意/一般/不满意)'),
          _tf('trainingOutcome', '训练后走向'),
          _tf('guardianSignature', '监护人签字'),
        ];
      default:
        return <Widget>[const Text('未知文档类型')];
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final notifier =
        ref.read(autismArchiveDetailProvider(widget.archiveId).notifier);
    bool ok = false;
    try {
      switch (widget.doc) {
        case 'first-eval':
          ok = await notifier.submitFirstEval(AutismFirstEval(
            id: widget.docId, archiveId: widget.archiveId,
            name: _v('name'), gender: _v('gender'),
            birthDate: _date('birthDate'),
            clinicalDiagnosis: _v('clinicalDiagnosis'),
            diagnosisDate: _date('diagnosisDate'),
            diagnosisHospital: _v('diagnosisHospital'),
            enrollmentDate: _date('enrollmentDate'),
            className: _v('className'), idNumber: _v('idNumber'),
            ethnicity: _v('ethnicity'), hukouLocation: _v('hukouLocation'),
            homeAddress: _v('homeAddress'), familyPhone: _v('familyPhone'),
            guardianName: _v('guardianName'),
            guardianRelation: _v('guardianRelation'),
            disabilityCertNo: _v('disabilityCertNo'),
            familyData: _v('familyData'), selfStatus: _v('selfStatus'),
            domainPerception: _v('domainPerception'),
            domainGrossMotor: _v('domainGrossMotor'),
            domainFineMotor: _v('domainFineMotor'),
            domainLanguageComm: _v('domainLanguageComm'),
            domainCognition: _v('domainCognition'),
            domainSocial: _v('domainSocial'),
            domainSelfCare: _v('domainSelfCare'),
            domainEmotionBehavior: _v('domainEmotionBehavior'),
            evalCountJson: _v('evalCountJson'),
            iepPlanner: _v('iepPlanner'),
            iepStartDate: _date('iepStartDate'),
            iepEndDate: _date('iepEndDate'),
            iepDomainSensory: _v('iepDomainSensory'),
            iepDomainGross: _v('iepDomainGross'),
            iepDomainFine: _v('iepDomainFine'),
            iepDomainLanguage: _v('iepDomainLanguage'),
            iepDomainCognition: _v('iepDomainCognition'),
            iepDomainSocial: _v('iepDomainSocial'),
            iepDomainSelfcare: _v('iepDomainSelfcare'),
            iepDomainEmotion: _v('iepDomainEmotion'),
            evalDate: _date('evalDate'),
            evaluatorName: _v('evaluatorName'),
            physiologicalAge: _v('physiologicalAge'),
            developmentalAge: _v('developmentalAge'),
          ));
          break;
        case 'cont-eval':
          ok = await notifier.submitContEval(AutismContEval(
            id: widget.docId, archiveId: widget.archiveId,
            evalSeq: _vi('evalSeq'), evalDate: _date('evalDate'),
            dueDate: _date('dueDate'),
            physiologicalAge: _v('physiologicalAge'),
            developmentalAge: _v('developmentalAge'),
            domainPerception: _v('domainPerception'),
            domainGrossMotor: _v('domainGrossMotor'),
            domainFineMotor: _v('domainFineMotor'),
            domainLanguageComm: _v('domainLanguageComm'),
            domainCognition: _v('domainCognition'),
            domainSocial: _v('domainSocial'),
            domainSelfCare: _v('domainSelfCare'),
            domainEmotionBehavior: _v('domainEmotionBehavior'),
            effectSummary: _v('effectSummary'),
            parentPerformance: _v('parentPerformance'),
            teacherNotes: _v('teacherNotes'),
            evaluatorName: _v('evaluatorName'),
          ));
          break;
        case 'semester-plan':
          ok = await notifier.submitSemesterPlan(AutismSemesterPlan(
            id: widget.docId, archiveId: widget.archiveId,
            planNo: _v('planNo'), seqNo: _vi('seqNo'),
            periodStart: _date('periodStart'), periodEnd: _date('periodEnd'),
            childName: _v('childName'), className: _v('className'),
            goalSensory: _v('goalSensory'), teacherSensory: _v('teacherSensory'),
            goalFine: _v('goalFine'), teacherFine: _v('teacherFine'),
            goalGroup: _v('goalGroup'), teacherGroup: _v('teacherGroup'),
            goalCognition: _v('goalCognition'),
            teacherCognition: _v('teacherCognition'),
            goalLife: _v('goalLife'), teacherLife: _v('teacherLife'),
            goalMusic: _v('goalMusic'), teacherMusic: _v('teacherMusic'),
            unitThemes: _v('unitThemes'),
          ));
          break;
        case 'monthly-plan':
          ok = await notifier.submitMonthlyPlan(AutismMonthlyPlan(
            id: widget.docId, archiveId: widget.archiveId,
            planMonth: _date('planMonth'), monthLabel: _v('monthLabel'),
            theme: _v('theme'), childName: _v('childName'),
            className: _v('className'),
            sensoryGoal: _v('sensoryGoal'), sensoryWeek1: _v('sensoryWeek1'),
            sensoryWeek2: _v('sensoryWeek2'), sensoryWeek3: _v('sensoryWeek3'),
            sensoryWeek4: _v('sensoryWeek4'), teacherSensory: _v('teacherSensory'),
            fineGoal: _v('fineGoal'), fineWeek1: _v('fineWeek1'),
            fineWeek2: _v('fineWeek2'), fineWeek3: _v('fineWeek3'),
            fineWeek4: _v('fineWeek4'), teacherFine: _v('teacherFine'),
            groupGoal: _v('groupGoal'), groupWeek1: _v('groupWeek1'),
            groupWeek2: _v('groupWeek2'), groupWeek3: _v('groupWeek3'),
            groupWeek4: _v('groupWeek4'), teacherGroup: _v('teacherGroup'),
            cognitionGoal: _v('cognitionGoal'),
            cognitionWeek1: _v('cognitionWeek1'),
            cognitionWeek2: _v('cognitionWeek2'),
            cognitionWeek3: _v('cognitionWeek3'),
            cognitionWeek4: _v('cognitionWeek4'),
            teacherCognition: _v('teacherCognition'),
            lifeGoal: _v('lifeGoal'), lifeWeek1: _v('lifeWeek1'),
            lifeWeek2: _v('lifeWeek2'), lifeWeek3: _v('lifeWeek3'),
            lifeWeek4: _v('lifeWeek4'), teacherLife: _v('teacherLife'),
            musicGoal: _v('musicGoal'), musicWeek1: _v('musicWeek1'),
            musicWeek2: _v('musicWeek2'), musicWeek3: _v('musicWeek3'),
            musicWeek4: _v('musicWeek4'), teacherMusic: _v('teacherMusic'),
            parentSignature: _v('parentSignature'),
          ));
          break;
        case 'lesson-plan':
          ok = await notifier.submitLessonPlan(AutismLessonPlan(
            id: widget.docId, archiveId: widget.archiveId,
            planMonth: _date('planMonth'),
            halfMonth: (_halfMonth ?? _v('halfMonth')).isEmpty
                ? 'FIRST'
                : (_halfMonth ?? _v('halfMonth')),
            courseDomain: _v('courseDomain'), unitTheme: _v('unitTheme'),
            lessonTitle: _v('lessonTitle'), teacher: _v('teacher'),
            classGroup: _v('classGroup'),
            teachingDateStart: _date('teachingDateStart'),
            teachingDateEnd: _date('teachingDateEnd'),
            teachingForm: _v('teachingForm'),
            obstacleTypeDegree: _v('obstacleTypeDegree'),
            cognitiveLevel: _v('cognitiveLevel'),
            currentAbility: _v('currentAbility'),
            knowledgeGoal: _v('knowledgeGoal'),
            abilityGoal: _v('abilityGoal'), emotionGoal: _v('emotionGoal'),
            keyPoints: _v('keyPoints'), difficultPoints: _v('difficultPoints'),
            preparation: _v('preparation'), introduction: _v('introduction'),
            process: _v('process'), summary: _v('summary'),
            extension: _v('extension'),
            learningAttitude: _v('learningAttitude'),
            learningEffect: _v('learningEffect'),
            existingProblems: _v('existingProblems'),
            teachingSuggestion: _v('teachingSuggestion'),
            parentSignature: _v('parentSignature'),
          ));
          break;
        case 'family-guide':
          ok = await notifier.submitFamilyGuide(AutismFamilyGuide(
            id: widget.docId, archiveId: widget.archiveId,
            weekStart: _date('weekStart'), weekEnd: _date('weekEnd'),
            weekLabel: _v('weekLabel'), childName: _v('childName'),
            courseName: _v('courseName'), teacher: _v('teacher'),
            guideTarget: _v('guideTarget'), homework: _v('homework'),
            completionStatus: _v('completionStatus'),
            parentFeedback: _v('parentFeedback'),
            teacherComment: _v('teacherComment'),
            parentSignature: _v('parentSignature'),
          ));
          break;
        case 'effect-record':
          ok = await notifier.submitEffectRecord(AutismEffectRecord(
            id: widget.docId, archiveId: widget.archiveId,
            recordYear: _vi('recordYear'), orgName: _v('orgName'),
            childName: _v('childName'), gender: _v('gender'),
            birthDate: _date('birthDate'), fillPerson: _v('fillPerson'),
            reviewer: _v('reviewer'), fillDate: _date('fillDate'),
            trainingStart: _date('trainingStart'),
            trainingEnd: _date('trainingEnd'),
            effectStats: _v('effectStats'),
            effectiveRate: _v('effectiveRate'),
            parentTrainingCount: _vi('parentTrainingCount'),
            satisfaction: _v('satisfaction'),
            trainingOutcome: _v('trainingOutcome'),
            guardianSignature: _v('guardianSignature'),
          ));
          break;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('保存失败：$e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    if (ok && mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(autismArchiveDetailProvider(widget.archiveId));
    return Scaffold(
      appBar: AppBar(title: Text(_docTitle)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            ..._buildFields(),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save),
              label: Text(_saving ? '保存中…' : '保存'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
