import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teacher_app/data/models/autism_eval_item.dart';
import 'package:teacher_app/features/rehab/data/rehab_repository.dart';
import 'package:teacher_app/features/rehab/provider/rehab_provider.dart';

/// 全部可用评测量表（残联标准 / OFFLINE / VB …）。
final evalFormsProvider =
    FutureProvider<List<AutismEvalForm>>(
  (ref) => ref.watch(rehabRepositoryProvider).listEvalForms(),
);

/// 某量表的题项定义（树形：group 总项目 / item 作答项）。
final evalFormItemsProvider =
    FutureProvider.family<List<AutismEvalFormItem>, String>(
  (ref, formCode) =>
      ref.watch(rehabRepositoryProvider).listEvalFormItems(formCode),
);

/// 某档案在指定量表（key = "$archiveId|$formCode"）下的评估轮次列表。
final evalRoundsProvider =
    FutureProvider.family<List<AutismEvalRound>, String>(
  (ref, key) {
    final List<String> parts = key.split('|');
    final String archiveId = parts.isNotEmpty ? parts[0] : '';
    final String? formCode = parts.length > 1 ? parts[1] : null;
    return ref.watch(rehabRepositoryProvider).listEvalRounds(archiveId, formCode);
  },
);

/// 轮次逐题作答 + 保存状态。
class EvalRoundItemsState {
  const EvalRoundItemsState({
    this.items = const <AutismEvalItem>[],
    this.loading = false,
    this.saving = false,
    this.error,
    this.message,
  });

  final List<AutismEvalItem> items;
  final bool loading;
  final bool saving;
  final String? error;
  final String? message;

  EvalRoundItemsState copyWith({
    List<AutismEvalItem>? items,
    bool? loading,
    bool? saving,
    String? error,
    String? message,
  }) =>
      EvalRoundItemsState(
        items: items ?? this.items,
        loading: loading ?? this.loading,
        saving: saving ?? this.saving,
        error: error,
        message: message,
      );
}

class EvalRoundItemsNotifier extends StateNotifier<EvalRoundItemsState> {
  EvalRoundItemsNotifier(this._repo, this.roundId)
      : super(const EvalRoundItemsState());

  final RehabRepository _repo;
  final String roundId;

  Future<void> load() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final List<AutismEvalItem> items = await _repo.listRoundItems(roundId);
      state = state.copyWith(items: items, loading: false);
    } catch (e) {
      state = state.copyWith(loading: false, error: '加载作答失败：$e');
    }
  }

  Future<bool> save(List<AutismEvalItem> items) async {
    state = state.copyWith(saving: true);
    try {
      await _repo.saveRoundItems(roundId, items);
      state = state.copyWith(saving: false, message: '已保存 ${items.length} 题');
      return true;
    } catch (e) {
      state = state.copyWith(saving: false, error: '保存失败：$e');
      return false;
    }
  }
}

/// key = roundId
final evalRoundItemsProvider = StateNotifierProvider.family<
    EvalRoundItemsNotifier, EvalRoundItemsState, String>(
  (ref, roundId) =>
      EvalRoundItemsNotifier(ref.watch(rehabRepositoryProvider), roundId),
);

/// 轮次统计（按领域聚合）。key = roundId
final evalRoundStatsProvider =
    FutureProvider.family<EvalRoundStats, String>(
  (ref, roundId) =>
      ref.watch(rehabRepositoryProvider).getRoundStats(roundId),
);

/// VB 计分：对某轮次计分并保存各维度得分（key = roundId）。
final vbScoreProvider = FutureProvider.family<Map<String, dynamic>, String>(
  (ref, roundId) =>
      ref.watch(rehabRepositoryProvider).vbScore(roundId),
);

/// VB 多次评估趋势（按维度折线序列）。key = "$archiveId|$formCode"。
final vbTrendProvider = FutureProvider.family<Map<String, dynamic>, String>(
  (ref, key) {
    final List<String> parts = key.split('|');
    final String archiveId = parts.isNotEmpty ? parts[0] : '';
    final String formCode = parts.length > 1 ? parts[1] : 'VB_PARENT';
    return ref.watch(rehabRepositoryProvider).vbTrend(archiveId, formCode);
  },
);
