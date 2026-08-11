import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teacher_app/features/ai_lesson_plan/data/ai_lesson_plan_repository.dart';

final Provider<AiLessonPlanRepository> aiLessonPlanRepositoryProvider =
    Provider<AiLessonPlanRepository>((ref) => const AiLessonPlanRepository());

final StateNotifierProvider<AiLessonPlanNotifier, AiLessonPlanState>
    aiLessonPlanProvider =
    StateNotifierProvider<AiLessonPlanNotifier, AiLessonPlanState>(
  (ref) => AiLessonPlanNotifier(ref.watch(aiLessonPlanRepositoryProvider)),
);

class AiLessonPlanState {
  const AiLessonPlanState({
    this.loading = false,
    this.result,
    this.error,
    this.message,
    this.pdfBytes,
  });

  final bool loading;
  final AiLessonPlanResult? result;
  final String? error;
  final String? message;
  final Uint8List? pdfBytes;

  AiLessonPlanState copyWith({
    bool? loading,
    AiLessonPlanResult? result,
    String? error,
    bool clearError = false,
    String? message,
    bool clearMessage = false,
    Uint8List? pdfBytes,
  }) =>
      AiLessonPlanState(
        loading: loading ?? this.loading,
        result: result ?? this.result,
        error: clearError ? null : (error ?? this.error),
        message: clearMessage ? null : (message ?? this.message),
        pdfBytes: pdfBytes ?? this.pdfBytes,
      );
}

class AiLessonPlanNotifier extends StateNotifier<AiLessonPlanState> {
  AiLessonPlanNotifier(this._repository)
      : super(const AiLessonPlanState());

  final AiLessonPlanRepository _repository;

  Future<void> generate(AiLessonPlanRequest req) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final AiLessonPlanResult result = await _repository.generate(req);
      state = state.copyWith(loading: false, result: result, pdfBytes: null);
    } catch (e) {
      state = state.copyWith(loading: false, error: '生成失败：$e');
    }
  }

  /// 拉取教案 PDF 字节（1.1.4 格式），存于 [AiLessonPlanState.pdfBytes]。
  Future<void> loadPdf() async {
    if (state.result == null) return;
    state = state.copyWith(loading: true, clearError: true);
    try {
      final Uint8List bytes = await _repository.downloadPdf(state.result!.id);
      state = state.copyWith(loading: false, pdfBytes: bytes);
    } catch (e) {
      state = state.copyWith(loading: false, error: '导出失败：$e');
    }
  }

  /// 保存教师最终定稿（记录与 AI 生成内容的 DIFF，用于学习教师风格）。
  Future<void> saveFinal() async {
    final AiLessonPlanResult? r = state.result;
    if (r == null) return;
    state = state.copyWith(loading: true, clearError: true, clearMessage: true);
    try {
      final AiLessonPlanResult updated =
          await _repository.saveFinal(r.id, r.domainsJson);
      state = state.copyWith(
        loading: false,
        result: updated,
        message: '已保存定稿，已记录您与 AI 的差异用于风格学习',
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: '保存失败：$e');
    }
  }
}
