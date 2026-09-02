import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:teacher_app/data/models/autism_archive.dart';
import 'package:teacher_app/features/rehab/provider/autism_provider.dart';
import 'package:teacher_app/features/rehab/provider/rehab_provider.dart';
import 'package:teacher_app/features/rehab/data/rehab_repository.dart';
import 'package:teacher_app/shared/handwritten_uploader.dart';
import 'package:teacher_app/shared/ui.dart';

/// 孤独症月教学计划：调用 DeepSeek LLM 智能生成（参考历史最新 5 份）。
///
/// 点击「AI 生成」调用后端 /monthly-plan/ai-generate：
/// - 历史月计划 ≥ 5 份时，后端以最新 5 份为参考调用 DeepSeek 生成下一个月的下月计划草稿
///   （仅教学内容，不含姓名/班级/教师姓名，teacher 留空）。
/// - 历史不足 5 份时，后端直接返回失败提示「生成失败数据不足」，不调用任何 AI。
/// 生成后教师可编辑，保存时后端会记录相对 AI 草稿的字段级 diff（editDiff）。
class AutismMonthlyPlanAiScreen extends ConsumerStatefulWidget {
  const AutismMonthlyPlanAiScreen({required this.archiveId, super.key});

  final String archiveId;

  @override
  ConsumerState<AutismMonthlyPlanAiScreen> createState() =>
      _AutismMonthlyPlanAiScreenState();
}

class _AutismMonthlyPlanAiScreenState
    extends ConsumerState<AutismMonthlyPlanAiScreen> {
  final Map<String, TextEditingController> _c =
      <String, TextEditingController>{};
  final Map<String, DateTime?> _dates = <String, DateTime?>{};
  final Map<String, String> _init = <String, String>{};
  final Map<String, DateTime?> _dateInit = <String, DateTime?>{};

  bool _generating = false;
  bool _saving = false;
  AutismMonthlyPlan? _plan;
  String? _error;
  String? _message;

  RehabRepository get _repo => ref.read(rehabRepositoryProvider);

  @override
  void dispose() {
    for (final c in _c.values) c.dispose();
    super.dispose();
  }

  void _resetControllers() {
    for (final c in _c.values) c.dispose();
    _c.clear();
    _dates.clear();
    _init.clear();
    _dateInit.clear();
  }

  void _initFromPlan(AutismMonthlyPlan p) {
    _resetControllers();
    _init['theme'] = p.theme;
    _init['childName'] = p.childName;
    _init['className'] = p.className;
    _init['sensoryGoal'] = p.sensoryGoal;
    _init['sensoryWeek1'] = p.sensoryWeek1;
    _init['sensoryWeek2'] = p.sensoryWeek2;
    _init['sensoryWeek3'] = p.sensoryWeek3;
    _init['sensoryWeek4'] = p.sensoryWeek4;
    _init['teacherSensory'] = p.teacherSensory;
    _init['fineGoal'] = p.fineGoal;
    _init['fineWeek1'] = p.fineWeek1;
    _init['fineWeek2'] = p.fineWeek2;
    _init['fineWeek3'] = p.fineWeek3;
    _init['fineWeek4'] = p.fineWeek4;
    _init['teacherFine'] = p.teacherFine;
    _init['groupGoal'] = p.groupGoal;
    _init['groupWeek1'] = p.groupWeek1;
    _init['groupWeek2'] = p.groupWeek2;
    _init['groupWeek3'] = p.groupWeek3;
    _init['groupWeek4'] = p.groupWeek4;
    _init['teacherGroup'] = p.teacherGroup;
    _init['cognitionGoal'] = p.cognitionGoal;
    _init['cognitionWeek1'] = p.cognitionWeek1;
    _init['cognitionWeek2'] = p.cognitionWeek2;
    _init['cognitionWeek3'] = p.cognitionWeek3;
    _init['cognitionWeek4'] = p.cognitionWeek4;
    _init['teacherCognition'] = p.teacherCognition;
    _init['lifeGoal'] = p.lifeGoal;
    _init['lifeWeek1'] = p.lifeWeek1;
    _init['lifeWeek2'] = p.lifeWeek2;
    _init['lifeWeek3'] = p.lifeWeek3;
    _init['lifeWeek4'] = p.lifeWeek4;
    _init['teacherLife'] = p.teacherLife;
    _init['musicGoal'] = p.musicGoal;
    _init['musicWeek1'] = p.musicWeek1;
    _init['musicWeek2'] = p.musicWeek2;
    _init['musicWeek3'] = p.musicWeek3;
    _init['musicWeek4'] = p.musicWeek4;
    _init['teacherMusic'] = p.teacherMusic;
    _init['parentSignature'] = p.parentSignature;
    // 姓名/班级：若历史计划为空，则回退到档案真实信息（仅展示，不属 AI 生成内容）
    final AutismArchiveDetail? detail =
        ref.read(autismArchiveDetailProvider(widget.archiveId)).detail;
    if ((_init['childName'] ?? '').isEmpty && detail?.firstEval != null) {
      _init['childName'] = detail!.firstEval!.name;
      _init['className'] = detail.firstEval!.className;
    }
    _dateInit['planMonth'] = p.planMonth;
  }

  TextEditingController _tc(String key) =>
      _c.putIfAbsent(key, () => TextEditingController(text: _init[key] ?? ''));
  String _v(String key) => _tc(key).text;

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

  Future<void> _generate() async {
    setState(() {
      _generating = true;
      _error = null;
      _message = null;
      _plan = null;
    });
    try {
      final AutismMonthlyPlanGenerateResult res =
          await _repo.aiGenerateAutismMonthlyPlan(widget.archiveId);
      if (res.success && res.plan != null) {
        _initFromPlan(res.plan!);
        _plan = res.plan;
        _message = '已调用 DeepSeek 参考历史最新 5 份月计划生成草稿，请检查并保存。';
      } else {
        _error = res.message ?? '生成失败';
      }
    } catch (e) {
      _error = '生成失败：$e';
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  List<Widget> _buildMonthlyFields() => <Widget>[
        _df('planMonth', '计划月份'),
        _tf('theme', '月主题'),
        _section('基础信息（取自档案，非 AI 生成）', <Widget>[
          _tf('childName', '儿童姓名'),
          _tf('className', '班级'),
        ]),
        _section('感觉统合', <Widget>[
          _tf('sensoryGoal', '目标'),
          _tf('sensoryWeek1', '第1周'),
          _tf('sensoryWeek2', '第2周'),
          _tf('sensoryWeek3', '第3周'),
          _tf('sensoryWeek4', '第4周'),
          _tf('teacherSensory', '任课教师'),
        ]),
        _section('精细动作', <Widget>[
          _tf('fineGoal', '目标'),
          _tf('fineWeek1', '第1周'),
          _tf('fineWeek2', '第2周'),
          _tf('fineWeek3', '第3周'),
          _tf('fineWeek4', '第4周'),
          _tf('teacherFine', '任课教师'),
        ]),
        _section('集体课', <Widget>[
          _tf('groupGoal', '目标'),
          _tf('groupWeek1', '第1周'),
          _tf('groupWeek2', '第2周'),
          _tf('groupWeek3', '第3周'),
          _tf('groupWeek4', '第4周'),
          _tf('teacherGroup', '任课教师'),
        ]),
        _section('认知', <Widget>[
          _tf('cognitionGoal', '目标'),
          _tf('cognitionWeek1', '第1周'),
          _tf('cognitionWeek2', '第2周'),
          _tf('cognitionWeek3', '第3周'),
          _tf('cognitionWeek4', '第4周'),
          _tf('teacherCognition', '任课教师'),
        ]),
        _section('生活自理', <Widget>[
          _tf('lifeGoal', '目标'),
          _tf('lifeWeek1', '第1周'),
          _tf('lifeWeek2', '第2周'),
          _tf('lifeWeek3', '第3周'),
          _tf('lifeWeek4', '第4周'),
          _tf('teacherLife', '任课教师'),
        ]),
        _section('音乐律动', <Widget>[
          _tf('musicGoal', '目标'),
          _tf('musicWeek1', '第1周'),
          _tf('musicWeek2', '第2周'),
          _tf('musicWeek3', '第3周'),
          _tf('musicWeek4', '第4周'),
          _tf('teacherMusic', '任课教师'),
        ]),
        _tf('parentSignature', '家长签字'),
      ];

  Future<void> _save() async {
    if (_plan == null) return;
    setState(() => _saving = true);
    try {
      final DateTime? pm = _date('planMonth');
      final AutismMonthlyPlan plan = AutismMonthlyPlan(
        archiveId: widget.archiveId,
        planMonth: pm,
        monthLabel: pm == null
            ? ''
            : '${pm.year}-${pm.month.toString().padLeft(2, '0')}',
        theme: _v('theme'),
        childName: _v('childName'),
        className: _v('className'),
        sensoryGoal: _v('sensoryGoal'),
        sensoryWeek1: _v('sensoryWeek1'),
        sensoryWeek2: _v('sensoryWeek2'),
        sensoryWeek3: _v('sensoryWeek3'),
        sensoryWeek4: _v('sensoryWeek4'),
        teacherSensory: _v('teacherSensory'),
        fineGoal: _v('fineGoal'),
        fineWeek1: _v('fineWeek1'),
        fineWeek2: _v('fineWeek2'),
        fineWeek3: _v('fineWeek3'),
        fineWeek4: _v('fineWeek4'),
        teacherFine: _v('teacherFine'),
        groupGoal: _v('groupGoal'),
        groupWeek1: _v('groupWeek1'),
        groupWeek2: _v('groupWeek2'),
        groupWeek3: _v('groupWeek3'),
        groupWeek4: _v('groupWeek4'),
        teacherGroup: _v('teacherGroup'),
        cognitionGoal: _v('cognitionGoal'),
        cognitionWeek1: _v('cognitionWeek1'),
        cognitionWeek2: _v('cognitionWeek2'),
        cognitionWeek3: _v('cognitionWeek3'),
        cognitionWeek4: _v('cognitionWeek4'),
        teacherCognition: _v('teacherCognition'),
        lifeGoal: _v('lifeGoal'),
        lifeWeek1: _v('lifeWeek1'),
        lifeWeek2: _v('lifeWeek2'),
        lifeWeek3: _v('lifeWeek3'),
        lifeWeek4: _v('lifeWeek4'),
        teacherLife: _v('teacherLife'),
        musicGoal: _v('musicGoal'),
        musicWeek1: _v('musicWeek1'),
        musicWeek2: _v('musicWeek2'),
        musicWeek3: _v('musicWeek3'),
        musicWeek4: _v('musicWeek4'),
        teacherMusic: _v('teacherMusic'),
        parentSignature: _v('parentSignature'),
        aiBaseline: _plan?.aiBaseline ?? '',
        status: 0,
      );
      final bool ok = await ref
          .read(autismArchiveDetailProvider(widget.archiveId).notifier)
          .submitMonthlyPlan(plan);
      if (!mounted) return;
      if (ok) {
        context.pop();
      } else {
        _error = '保存失败，请重试';
      }
    } catch (e) {
      if (!mounted) return;
      _error = '保存失败：$e';
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final bool hasPlan = _plan != null;

    return Scaffold(
      appBar: AppBar(title: const Text('AI 生成月计划')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          HandwrittenUploader(
            archiveId: widget.archiveId,
            section: 'STANDARD_MONTHLY',
            title: '月教学计划 · 手写板',
            compact: true,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.primary.withOpacity(0.3)),
            ),
            child: Row(
              children: <Widget>[
                Icon(Icons.auto_awesome_outlined, color: colors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '调用 DeepSeek 生成：参考该儿童数据库「最新 5 份」历史月计划，'
                    '生成下一个月的下月计划草稿（仅教学内容，不含姓名/班级/教师姓名）。'
                    '历史不足 5 份时直接提示「生成失败数据不足」。生成后可编辑，保存时记录相对于 AI 草稿的修改。',
                    style: textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: _generating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome_outlined),
              label: Text(_generating ? '生成中…' : 'AI 生成'),
              onPressed: _generating ? null : () => _generate(),
            ),
          ),
          if (_generating) ...<Widget>[
            const SizedBox(height: 16),
            const Center(child: CircularProgressIndicator()),
          ],
          if (_error != null) ...<Widget>[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colors.error.withOpacity(0.4)),
              ),
              child: Row(
                children: <Widget>[
                  const Icon(Icons.block, color: Colors.red, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_error!,
                        style: const TextStyle(color: Colors.red, fontSize: 13)),
                  ),
                ],
              ),
            ),
          ],
          if (_message != null) ...<Widget>[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(_message!,
                  style: TextStyle(color: Colors.green.shade800, fontSize: 13)),
            ),
          ],
          if (hasPlan) ...<Widget>[
            const SizedBox(height: 20),
            const AppSectionTitle('生成结果（可编辑后保存）'),
            const SizedBox(height: 8),
            ..._buildMonthlyFields(),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: const Text('保存月计划'),
                onPressed: _saving ? null : () => _save(),
              ),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
