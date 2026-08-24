import 'package:flutter/material.dart';
import 'package:teacher_app/features/rehab/presentation/hearing_record_tab.dart';

/// 听障档案 - 听能管理独立页。
/// 直接复用 [HearingRecordTab]（原本嵌在档案详情里的 Tab），作为全屏页使用。
class HearingSectionScreen extends StatelessWidget {
  const HearingSectionScreen({required this.archiveId, super.key});
  final String archiveId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('听能管理',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF102A27))),
      ),
      body: HearingRecordTab(archiveId: archiveId),
    );
  }
}
