import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:teacher_app/data/models/rehab.dart';
import 'package:teacher_app/features/rehab/presentation/widgets/audiogram_chart.dart';
import 'package:teacher_app/features/rehab/presentation/widgets/export_pdf_button.dart';
import 'package:teacher_app/features/rehab/provider/rehab_provider.dart';
import 'package:teacher_app/features/rehab/services/chart_export.dart';

/// 听能管理记录 Tab（位于教学计划右侧）。
class HearingRecordTab extends ConsumerStatefulWidget {
  const HearingRecordTab({required this.archiveId, super.key});
  final String archiveId;

  @override
  ConsumerState<HearingRecordTab> createState() => _HearingRecordTabState();
}

class _HearingRecordTabState extends ConsumerState<HearingRecordTab> {
  RehabHearingRecord? _draft;
  bool _isEditing = false;

  /// 听力图导出用的边界键（按记录 ID 区分）。
  final Map<String, GlobalKey> _audiogramKeys = <String, GlobalKey>{};

  @override
  Widget build(BuildContext context) {
    final RehabArchiveDetailState state =
        ref.watch(rehabArchiveDetailProvider(widget.archiveId));
    final List<RehabHearingRecord> records = state.detail?.hearingRecords ?? <RehabHearingRecord>[];

    if (_isEditing && _draft != null) {
      return _HearingRecordEditForm(
        draft: _draft!,
        onSave: (RehabHearingRecord saved) async {
          final bool ok = await ref
              .read(rehabArchiveDetailProvider(widget.archiveId).notifier)
              .saveHearingRecord(saved);
          if (ok && mounted) setState(() => _isEditing = false);
        },
        onCancel: () => setState(() => _isEditing = false),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ...records.map((r) => _recordCard(r)),
        if (records.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Text('暂无听能管理记录'),
            ),
          ),
        const SizedBox(height: 12),
        Center(
          child: FilledButton.tonal(
            onPressed: () => setState(() {
              _draft = RehabHearingRecord(
                id: '',
                archiveId: widget.archiveId,
                evalDate: DateTime.now(),
                fillDate: DateTime.now(),
              );
              _isEditing = true;
            }),
            child: const Text('+ 新建听能管理记录'),
          ),
        ),
      ],
    );
  }

  Widget _recordCard(RehabHearingRecord r) {
    String fmt(DateTime? d) => d == null ? '' : DateFormat('yyyy-MM-dd').format(d);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('评估日期：${fmt(r.evalDate)}',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            Row(mainAxisSize: MainAxisSize.min, children: [
              // 后端生成：1.2.1 听障儿童听能诊断记录扫描件 + 叠字，与 OA 网页同一份。
              ExportPdfButton(
                iconOnly: true,
                tooltip: '导出记录 PDF',
                enabled: r.id.isNotEmpty,
                filename: '听能管理记录_${r.name ?? ''}_${fmt(r.evalDate)}.pdf',
                fetchBytes: () => ref
                    .read(rehabRepositoryProvider)
                    .exportHearingRecordPdf(r.id),
              ),
              IconButton(
                icon: const Icon(Icons.image, size: 20),
                tooltip: '导出听力图',
                onPressed: () async {
                  final GlobalKey? key = _audiogramKeys[r.id];
                  if (key == null) return;
                  try {
                    await exportBoundaryToPdf(
                      key,
                      filename: '听力图_${r.name ?? ""}.pdf',
                      title: '听力测试（助听听阈）',
                    );
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('导出失败: $e')),
                      );
                    }
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.edit, size: 20),
                tooltip: '编辑',
                onPressed: () => setState(() {
                  _draft = r;
                  _isEditing = true;
                }),
              ),
              IconButton(
                icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                tooltip: '删除',
                onPressed: () => _confirmDelete(r.id),
              ),
            ]),
          ]),
          const SizedBox(height: 8),
          _infoRow('姓名', r.name ?? ''),
          _infoRow('性别', r.gender ?? ''),
          _infoRow('出生年月', fmt(r.birthDate)),
          _infoRow('评估人员', r.evaluatorName ?? ''),
          const SizedBox(height: 8),
          RepaintBoundary(
            key: _audiogramKeys.putIfAbsent(r.id, () => GlobalKey()),
            child: Container(
              color: Colors.white,
              child: AudiogramChart(
                leftPoints: r.leftAudiogram,
                rightPoints: r.rightAudiogram,
                editable: false,
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _infoRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          SizedBox(width: 80, child: Text(label, style: const TextStyle(color: Colors.black54, fontSize: 13))),
          Expanded(child: Text(value.isEmpty ? '—' : value, style: const TextStyle(fontSize: 14))),
        ]),
      );

  Future<void> _confirmDelete(String id) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('删除记录'),
        content: const Text('确定删除这条听能管理记录吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('删除')),
        ],
      ),
    );
    if (ok == true) {
      await ref
          .read(rehabArchiveDetailProvider(widget.archiveId).notifier)
          .deleteHearingRecord(id);
    }
  }
}

/// 听能管理记录编辑表单。
class _HearingRecordEditForm extends StatefulWidget {
  const _HearingRecordEditForm({
    required this.draft,
    required this.onSave,
    required this.onCancel,
  });

  final RehabHearingRecord draft;
  final ValueChanged<RehabHearingRecord> onSave;
  final VoidCallback onCancel;

  @override
  State<_HearingRecordEditForm> createState() => _HearingRecordEditFormState();
}

class _HearingRecordEditFormState extends State<_HearingRecordEditForm> {
  late RehabHearingRecord _draft;

  @override
  void initState() {
    super.initState();
    _draft = widget.draft;
  }

  @override
  Widget build(BuildContext context) {
    // 直接渲染表单（无内层 Scaffold，避免与外层 HearingSectionScreen 嵌套出双 AppBar）。
    // 保存/取消按钮置于表单底部，由 onSave/onCancel 回调回传主列表状态。
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
          _section('基本资料'),
          _textField('档案编号', _draft.recordNo, (v) => _draft = _draft.copyWith(recordNo: v)),
          _textField('姓名', _draft.name, (v) => _draft = _draft.copyWith(name: v)),
          _textField('性别', _draft.gender, (v) => _draft = _draft.copyWith(gender: v)),
          _dateField('出生年月', _draft.birthDate, (v) => _draft = _draft.copyWith(birthDate: v)),
          _dateField('听障确诊时间', _draft.diagnosisDate, (v) => _draft = _draft.copyWith(diagnosisDate: v)),
          _dateField('左耳首次佩戴助听设备时间', _draft.leftFirstDeviceDate,
              (v) => _draft = _draft.copyWith(leftFirstDeviceDate: v)),
          _dateField('右耳首次佩戴助听设备时间', _draft.rightFirstDeviceDate,
              (v) => _draft = _draft.copyWith(rightFirstDeviceDate: v)),

          _section('补偿/重建方式'),
          _earCompensationRow('左耳', _draft.leftCompensationType,
              (v) => _draft = _draft.copyWith(leftCompensationType: v)),
          _earCompensationRow('右耳', _draft.rightCompensationType,
              (v) => _draft = _draft.copyWith(rightCompensationType: v)),
          _textField('左耳设备型号', _draft.leftDeviceModel,
              (v) => _draft = _draft.copyWith(leftDeviceModel: v)),
          _textField('右耳设备型号', _draft.rightDeviceModel,
              (v) => _draft = _draft.copyWith(rightDeviceModel: v)),
          _textField('左耳程序 / 音量', _draft.leftProgram,
              (v) => _draft = _draft.copyWith(leftProgram: v)),
          _textField('右耳程序 / 音量', _draft.rightProgram,
              (v) => _draft = _draft.copyWith(rightProgram: v)),

          _section('听力测试'),
          _methodCheckboxes(),
          _textField('测量单位', _draft.unit,
              (v) => _draft = _draft.copyWith(unit: v.isEmpty ? 'dB HL' : v)),

          _section('听力图'),
          AudiogramChart(
            leftPoints: _draft.leftAudiogram,
            rightPoints: _draft.rightAudiogram,
            onLeftChanged: (v) => setState(() => _draft = _draft.copyWith(leftAudiogram: v)),
            onRightChanged: (v) => setState(() => _draft = _draft.copyWith(rightAudiogram: v)),
            editable: true,
          ),
          const SizedBox(height: 8),
          _textField('左耳裸耳平均听阈', _draft.leftAverageHearing,
              (v) => _draft = _draft.copyWith(leftAverageHearing: v)),
          _textField('右耳裸耳平均听阈', _draft.rightAverageHearing,
              (v) => _draft = _draft.copyWith(rightAverageHearing: v)),
          _textField('左耳助听器效果', _draft.leftAidEffect,
              (v) => _draft = _draft.copyWith(leftAidEffect: v)),
          _textField('右耳助听器效果', _draft.rightAidEffect,
              (v) => _draft = _draft.copyWith(rightAidEffect: v)),
          _dateField('评估日期', _draft.evalDate, (v) => _draft = _draft.copyWith(evalDate: v)),
          _textField('评估人员', _draft.evaluatorName,
              (v) => _draft = _draft.copyWith(evaluatorName: v)),

          _section('检查项目与结果'),
          _multilineField('电生理测试 / 言语测听 / 辅助检查', _draft.inspectionItems,
              (v) => _draft = _draft.copyWith(inspectionItems: v)),

          _section('诊断'),
          _multilineField('诊断', _draft.diagnosis,
              (v) => _draft = _draft.copyWith(diagnosis: v)),

          _section('听力师评语'),
          _multilineField('听力师评语', _draft.audiologistComment,
              (v) => _draft = _draft.copyWith(audiologistComment: v)),
          _dateField('填写日期', _draft.fillDate, (v) => _draft = _draft.copyWith(fillDate: v)),
          _textField('听力师签名', _draft.audiologistSignature,
              (v) => _draft = _draft.copyWith(audiologistSignature: v)),

          const SizedBox(height: 24),

          // 底部：保存 / 取消按钮（替代原 AppBar 右上角 TextButton）。
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: widget.onCancel,
                child: const Text('取消'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                icon: const Icon(Icons.save_outlined),
                label: const Text('保存'),
                onPressed: () => widget.onSave(_draft),
              ),
            ),
          ]),
          const SizedBox(height: 24),
        ],
      );
  }

  Widget _section(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 20, 0, 8),
        child: Text(t, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      );

  Widget _textField(String label, String? value, ValueChanged<String> onChanged) =>
      TextFormField(
        initialValue: value ?? '',
        decoration: InputDecoration(labelText: label),
        onChanged: onChanged,
      );

  Widget _multilineField(String label, String? value, ValueChanged<String> onChanged) =>
      TextFormField(
        initialValue: value ?? '',
        decoration: InputDecoration(labelText: label, alignLabelWithHint: true),
        maxLines: 4,
        onChanged: onChanged,
      );

  Widget _dateField(String label, DateTime? value, ValueChanged<DateTime?> onChanged) =>
      _DateField(label: label, value: value, onChanged: onChanged);

  Widget _earCompensationRow(
      String label, List<String> selected, ValueChanged<List<String>> onChanged) {
    const List<String> opts = ['无', '助听器', '电子耳蜗', '其他'];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 13, color: Colors.black54)),
      Wrap(
        spacing: 8,
        children: opts.map((o) {
          final bool checked = selected.contains(o);
          return FilterChip(
            label: Text(o),
            selected: checked,
            onSelected: (v) {
              final List<String> next = List<String>.from(selected);
              if (v) {
                if (o == '无') {
                  next.clear();
                  next.add('无');
                } else {
                  next.remove('无');
                  next.add(o);
                }
              } else {
                next.remove(o);
              }
              onChanged(next);
              setState(() {});
            },
          );
        }).toList(),
      ),
    ]);
  }

  Widget _methodCheckboxes() {
    const List<String> methods = ['BOA', 'VRA', 'PA', 'PTA'];
    const List<String> labels = ['行为观察测听', '视觉强化测听', '游戏测听', '纯音测听'];
    return Wrap(
      spacing: 8,
      children: List<Widget>.generate(methods.length, (i) {
        final bool checked = _draft.hearingTestMethod.contains(methods[i]);
        return FilterChip(
          label: Text('${methods[i]} ${labels[i]}'),
          selected: checked,
          onSelected: (v) {
            final List<String> next = List<String>.from(_draft.hearingTestMethod);
            if (v) {
              next.add(methods[i]);
            } else {
              next.remove(methods[i]);
            }
            setState(() => _draft = _draft.copyWith(hearingTestMethod: next));
          },
        );
      }),
    );
  }
}

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
              context: context,
              initialDate: widget.value ?? DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime(2030),
            );
            if (picked != null) widget.onChanged(picked);
          },
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: widget.label,
              labelStyle: const TextStyle(fontSize: 13),
              border: InputBorder.none,
              enabledBorder:
                  UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade300)),
              focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Theme.of(context).colorScheme.primary)),
              contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 0),
              suffixIcon: const Icon(Icons.calendar_today, size: 18),
            ),
            child: Text(
              widget.value == null ? '选择日期' : DateFormat('yyyy-MM-dd').format(widget.value!),
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ),
      );
}
