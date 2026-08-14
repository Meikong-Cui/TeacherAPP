import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teacher_app/data/models/autism_eval_item.dart';
import 'package:teacher_app/features/rehab/data/rehab_repository.dart';
import 'package:teacher_app/features/rehab/provider/rehab_provider.dart';

/// 逐题评分（按档案 + source）状态。
class AutismEvalItemsState {
  const AutismEvalItemsState({
    this.items = const <AutismEvalItem>[],
    this.loading = false,
    this.error,
    this.message,
  });

  final List<AutismEvalItem> items;
  final bool loading;
  final String? error;
  final String? message;

  AutismEvalItemsState copyWith({
    List<AutismEvalItem>? items,
    bool? loading,
    String? error,
    String? message,
  }) =>
      AutismEvalItemsState(
        items: items ?? this.items,
        loading: loading ?? this.loading,
        error: error,
        message: message,
      );
}

class AutismEvalItemsNotifier extends StateNotifier<AutismEvalItemsState> {
  AutismEvalItemsNotifier(this._repo, this.archiveId, this.source)
      : super(const AutismEvalItemsState());

  final RehabRepository _repo;
  final String archiveId;
  final String source;

  Future<void> load() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final List<AutismEvalItem> items = await _repo.listEvalItems(archiveId, source);
      state = state.copyWith(items: items, loading: false);
    } catch (e) {
      state = state.copyWith(loading: false, error: '加载评分失败：$e');
    }
  }

  /// 批量保存逐题评分。
  Future<bool> save(List<AutismEvalItem> items) async {
    try {
      await _repo.saveEvalItems(items);
      state = state.copyWith(message: '已保存 ${items.length} 题评分');
      return true;
    } catch (e) {
      state = state.copyWith(error: '保存失败：$e');
      return false;
    }
  }
}

/// key = "$archiveId|$source"
final StateNotifierProviderFamily<AutismEvalItemsNotifier, AutismEvalItemsState,
    String> autismEvalItemsProvider = StateNotifierProvider.family<
    AutismEvalItemsNotifier, AutismEvalItemsState, String>(
  (ref, key) {
    final List<String> parts = key.split('|');
    return AutismEvalItemsNotifier(
      ref.watch(rehabRepositoryProvider),
      parts.isNotEmpty ? parts[0] : '',
      parts.length > 1 ? parts[1] : 'FIRST',
    );
  },
);

/// 评估统计（剖面图 + 折线）状态。
class AutismEvalStatsState {
  const AutismEvalStatsState({
    this.stats,
    this.loading = false,
    this.error,
  });

  final AutismEvalStats? stats;
  final bool loading;
  final String? error;

  AutismEvalStatsState copyWith({
    AutismEvalStats? stats,
    bool? loading,
    String? error,
  }) =>
      AutismEvalStatsState(
        stats: stats ?? this.stats,
        loading: loading ?? this.loading,
        error: error,
      );
}

class AutismEvalStatsNotifier extends StateNotifier<AutismEvalStatsState> {
  AutismEvalStatsNotifier(this._repo, this.archiveId, this.source)
      : super(const AutismEvalStatsState());

  final RehabRepository _repo;
  final String archiveId;
  final String source;

  Future<void> load() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final AutismEvalStats stats = await _repo.getEvalStats(archiveId, source);
      state = state.copyWith(stats: stats, loading: false);
    } catch (e) {
      state = state.copyWith(loading: false, error: '加载统计失败：$e');
    }
  }
}

/// key = "$archiveId|$source"
final StateNotifierProviderFamily<AutismEvalStatsNotifier, AutismEvalStatsState,
    String> autismEvalStatsProvider = StateNotifierProvider.family<
    AutismEvalStatsNotifier, AutismEvalStatsState, String>(
  (ref, key) {
    final List<String> parts = key.split('|');
    return AutismEvalStatsNotifier(
      ref.watch(rehabRepositoryProvider),
      parts.isNotEmpty ? parts[0] : '',
      parts.length > 1 ? parts[1] : 'FIRST',
    );
  },
);
