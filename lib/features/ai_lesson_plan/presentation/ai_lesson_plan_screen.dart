import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';
import 'package:teacher_app/data/models/rehab.dart';
import 'package:teacher_app/features/ai_lesson_plan/data/ai_lesson_plan_repository.dart';
import 'package:teacher_app/features/ai_lesson_plan/provider/ai_lesson_plan_provider.dart';
import 'package:teacher_app/features/rehab/provider/rehab_provider.dart';
import 'package:teacher_app/shared/ui.dart';

/// AI 写教案：儿童上下文表单 + 5 大领域结果（可编辑）+ 1.1.4 PDF 导出 + 回填教学计划。
///
/// 真实调用后端 /api/ai/lesson-plan（DeepSeek 生成听能→沟通 5 个领域）。
/// 从学生档案「AI 补全」按钮进入时，[launchContext] 携带儿童信息与目标教学计划。
class AiLessonPlanScreen extends ConsumerStatefulWidget {
  const AiLessonPlanScreen({super.key, this.launchContext});

  final AiLessonPlanLaunchContext? launchContext;

  @override
  ConsumerState<AiLessonPlanScreen> createState() => _AiLessonPlanState();
}

class _AiLessonPlanState extends ConsumerState<AiLessonPlanScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _childCtl = TextEditingController();
  final TextEditingController _physCtl = TextEditingController();
  final TextEditingController _hearCtl = TextEditingController();
  final TextEditingController _phonCtl = TextEditingController(text: 'p,b,m');
  final TextEditingController _themeCtl = TextEditingController(text: '食物');
  final TextEditingController _extraCtl = TextEditingController();
  String _gender = '男';
  String _device = '双侧';

  /// 生成后每个领域的可编辑控制器（内容 / 设备材料）。
  final Map<String, TextEditingController> _contentCtl = <String, TextEditingController>{};
  final Map<String, TextEditingController> _materialCtl = <String, TextEditingController>{};
  bool _editableReady = false;

  bool _exporting = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final AiLessonPlanLaunchContext? ctx = widget.launchContext;
    _childCtl.text = ctx?.childName.isNotEmpty == true ? ctx!.childName : '陈予安';
    _physCtl.text =
        ctx?.physiologicalAge.isNotEmpty == true ? ctx!.physiologicalAge : '5岁2个月';
    _hearCtl.text = ctx?.hearingAge.isNotEmpty == true ? ctx!.hearingAge : '0岁6个月';
    if (ctx?.gender.isNotEmpty == true) _gender = ctx!.gender;
    if (ctx?.deviceWear.isNotEmpty == true) _device = ctx!.deviceWear;
  }

  @override
  void dispose() {
    _childCtl.dispose();
    _physCtl.dispose();
    _hearCtl.dispose();
    _phonCtl.dispose();
    _themeCtl.dispose();
    _extraCtl.dispose();
    for (final c in _contentCtl.values) c.dispose();
    for (final c in _materialCtl.values) c.dispose();
    super.dispose();
  }

  void _ensureEditable(AiLessonPlanResult r) {
    if (_editableReady) return;
    for (final (String key, _) in AiLessonPlanResult.orderedDomains) {
      _contentCtl[key] = TextEditingController(text: r.domains[key]?.content ?? '');
      _materialCtl[key] = TextEditingController(text: r.domains[key]?.materials ?? '');
    }
    _editableReady = true;
  }

  Map<String, String> _readContent() {
    final Map<String, String> out = <String, String>{};
    for (final (String key, _) in AiLessonPlanResult.orderedDomains) {
      out[key] = _contentCtl[key]?.text.trim() ?? '';
    }
    return out;
  }

  AiLessonPlanRequest _buildRequest() => AiLessonPlanRequest(
        archiveId: widget.launchContext?.archiveId,
        childId: widget.launchContext?.childId,
        childName: _childCtl.text.trim(),
        gender: _gender,
        physiologicalAge: _physCtl.text.trim(),
        hearingAge: _hearCtl.text.trim(),
        deviceWear: _device,
        targetPhonemes: _phonCtl.text.trim(),
        lessonTheme: _themeCtl.text.trim(),
        extra: _extraCtl.text.trim(),
      );

  Future<void> _generate() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await ref.read(aiLessonPlanProvider.notifier).generate(_buildRequest());
    if (!mounted) return;
    setState(() {}); // 初始化可编辑控制器
    // 限额拦截：后端返回含「额度」的提示时弹窗，其余错误仍按红字展示
    final String? err = ref.read(aiLessonPlanProvider).error;
    if (err != null && err.contains('额度')) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('AI 额度不足'),
          content: Text(err.replaceFirst('生成失败：', '')),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('我知道了'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _exportPdf() async {
    setState(() => _exporting = true);
    try {
      await ref.read(aiLessonPlanProvider.notifier).loadPdf();
      final Uint8List? bytes = ref.read(aiLessonPlanProvider).pdfBytes;
      if (!mounted) return;
      if (bytes == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF 生成失败，请重试')),
        );
        return;
      }
      final int id = ref.read(aiLessonPlanProvider).result?.id ?? 0;
      await Printing.sharePdf(bytes: bytes, filename: 'lesson-plan-$id.pdf');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导出失败：$e')),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  /// 保存定稿（记录与 AI 的 DIFF），并（若从教学计划进入）回填 5 大目标。
  Future<void> _saveAndApply() async {
    final AiLessonPlanResult? r = ref.read(aiLessonPlanProvider).result;
    if (r == null) return;
    setState(() => _saving = true);
    try {
      await ref.read(aiLessonPlanProvider.notifier).saveFinal();
      final AiLessonPlanLaunchContext? ctx = widget.launchContext;
      if (ctx?.plan != null) {
        final Map<String, String> content = _readContent();
        final RehabTeachingPlan updated = ctx!.plan!.copyWith(
          hearingGoal: content['auditoryDevelopment'],
          speechGoal: content['speechDevelopment'],
          languageGoal: content['languageDevelopment'],
          cognitionGoal: content['cognitiveDevelopment'],
          communicationGoal: content['communicationSkills'],
          aiGenerated: true,
        );
        await ref.read(rehabRepositoryProvider).updatePlan(updated);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ctx?.plan != null ? '已保存并应用到教学计划' : '已保存定稿（已记录与 AI 的差异）'),
      ));
      if (ctx?.plan != null && mounted) context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存失败：$e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AiLessonPlanState state = ref.watch(aiLessonPlanProvider);
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final bool hasPlan = widget.launchContext?.plan != null;
    final bool overLimit =
        state.error != null && state.error!.contains('额度');

    if (state.result != null) _ensureEditable(state.result!);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 写教案'),
        actions: const <Widget>[ThemeToggleButton()],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
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
                    hasPlan
                        ? '已带入儿童档案信息，生成后可编辑并「应用到教学计划」。'
                        : '基于 DeepSeek 生成听能发展→沟通技能 5 大领域教案，可导出 1.1.4 日常教学记录 PDF（符号由课堂填写）。',
                    style: textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: <Widget>[
                    TextFormField(
                      controller: _childCtl,
                      decoration: const InputDecoration(labelText: '儿童姓名'),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? '请输入儿童姓名' : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _gender,
                      decoration: const InputDecoration(labelText: '性别'),
                      items: const <DropdownMenuItem<String>>[
                        DropdownMenuItem(value: '男', child: Text('男')),
                        DropdownMenuItem(value: '女', child: Text('女')),
                      ],
                      onChanged: (v) => setState(() => _gender = v ?? '男'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _physCtl,
                      decoration:
                          const InputDecoration(labelText: '生理年龄（如 5岁2个月）'),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? '请输入生理年龄' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _hearCtl,
                      decoration:
                          const InputDecoration(labelText: '听觉年龄（如 0岁6个月）'),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? '请输入听觉年龄' : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _device,
                      decoration:
                          const InputDecoration(labelText: '助听设备佩戴方式'),
                      items: const <DropdownMenuItem<String>>[
                        DropdownMenuItem(value: '单侧', child: Text('单侧')),
                        DropdownMenuItem(value: '双侧', child: Text('双侧')),
                      ],
                      onChanged: (v) => setState(() => _device = v ?? '双侧'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phonCtl,
                      decoration: const InputDecoration(
                          labelText: '目标音位（逗号分隔，如 p,b,m）'),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? '请输入目标音位' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _themeCtl,
                      decoration: const InputDecoration(labelText: '本课主题'),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? '请输入本课主题' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _extraCtl,
                      decoration:
                          const InputDecoration(labelText: '补充要求（可选）'),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        icon: const Icon(Icons.auto_awesome_outlined),
                        label: const Text('生成教案'),
                        onPressed: (state.loading || overLimit) ? null : () => _generate(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (state.loading) ...<Widget>[
            const SizedBox(height: 16),
            const Center(child: CircularProgressIndicator()),
          ],
          if (state.error != null) ...<Widget>[
            const SizedBox(height: 12),
            if (overLimit)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: colors.error.withOpacity(0.4)),
                ),
                child: const Row(
                  children: <Widget>[
                    Icon(Icons.block, color: Colors.red, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '本月 AI 额度已用尽，无法生成。请联系园长 / 管理员，或下月自动恢复。',
                        style: TextStyle(color: Colors.red, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              )
            else
              Text(state.error!, style: TextStyle(color: colors.error)),
          ],
          if (state.result != null) ...<Widget>[
            const SizedBox(height: 20),
            const AppSectionTitle('生成结果（可编辑后保存，符号由课堂填写）'),
            const SizedBox(height: 8),
            for (final (String key, String label)
                in AiLessonPlanResult.orderedDomains)
              _EditableDomainCard(
                label: label,
                contentController: _contentCtl[key]!,
                materialController: _materialCtl[key]!,
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(hasPlan ? '保存并应用到教学计划' : '保存定稿'),
                onPressed: _saving ? null : () => _saveAndApply(),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: _exporting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('导出 1.1.4 PDF'),
                onPressed: _exporting ? null : () => _exportPdf(),
              ),
            ),
            if (state.message != null) ...<Widget>[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(state.message!,
                    style: TextStyle(color: Colors.green.shade800, fontSize: 13)),
              ),
            ],
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _EditableDomainCard extends StatelessWidget {
  const _EditableDomainCard({
    required this.label,
    required this.contentController,
    required this.materialController,
  });

  final String label;
  final TextEditingController contentController;
  final TextEditingController materialController;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.label_outline, size: 18, color: colors.primary),
                const SizedBox(width: 8),
                Text(label,
                    style: textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: contentController,
              decoration: const InputDecoration(
                labelText: '教学内容',
                alignLabelWithHint: true,
              ),
              maxLines: 6,
              minLines: 3,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: materialController,
              decoration: const InputDecoration(
                labelText: '设备/玩具/图书/备注',
                alignLabelWithHint: true,
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
}
